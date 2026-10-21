function out = export_ops_reference(matfile, run_s9, dt_s)
% EXPORT_OPS_REFERENCE  Read-only export of Simscape reference runs for the Loco Ops Simulator check.
%   export_ops_reference()                      newest loco_system/results_csx4091_*.mat, plus an S9 run
%   export_ops_reference('results_csx4091_20261021_0900.mat')
%   export_ops_reference([], false)             CSX4091 only, skip S9
%   export_ops_reference([], true, 5)           5 s series spacing (default 10 s)
% Run run_csx4091_baseline first. Writes one JSON file next to this script. Does not modify any model file.
if nargin < 1, matfile = []; end
if nargin < 2 || isempty(run_s9), run_s9 = true; end
if nargin < 3 || isempty(dt_s), dt_s = 10; end
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
sysdir = fullfile(root, 'loco_system');
addpath(root);
addpath(sysdir);

if isempty(matfile)
    L = dir(fullfile(sysdir, 'results_csx4091_*.mat'));
    assert(~isempty(L), 'No results_csx4091_*.mat in %s. Run run_csx4091_baseline first.', sysdir);
    [~, k] = max([L.datenum]);
    matfile = fullfile(L(k).folder, L(k).name);
elseif ~isfile(matfile)
    matfile = fullfile(sysdir, matfile);
end
fprintf('Loading %s ...\n', matfile);
S = load(matfile, 'results');

[s1, sha] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
if s1 ~= 0, sha = 'unknown'; end
sha = strtrim(sha);
[~, st] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no', root));
P = loco_system_params(struct('baseline', 'poc'));
mrev = 'pre-RevD';
if isfield(P.sys, 'model_rev'), mrev = P.sys.model_rev; end

cases = {};
names = fieldnames(S.results);
for c = 1:numel(names)
    cases{end+1} = one_case(names{c}, S.results.(names{c}), dt_s); %#ok<AGROW>
end
if run_s9
    fprintf('Running S9_dyncharge_2p1MW_demo (SOC0 0.20, pack 25 C) ...\n');
    old = cd(sysdir);
    c9 = onCleanup(@() cd(old));
    RUN = run_loco_system('traces/S9_dyncharge_2p1MW_demo.csv', 'soc0', 0.2, 'T0_C', 25, 'Plot', false, 'Silent', true);
    clear c9
    cases{end+1} = one_case('S9_dyncharge_2p1MW_demo', RUN, dt_s);
end

out.meta = struct('source', 'export_ops_reference', 'model_commit', sha, 'model_dirty', ~isempty(strtrim(st)), ...
    'model_rev', mrev, 'drivetrain_rev', P.sys.drivetrain_rev, 'results_file', matfile, 'series_dt_s', dt_s, ...
    'exported_at', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), 'matlab', version);
out.cases = cases;

fn = fullfile(here, sprintf('ops_reference_%s.json', sha));
fid = fopen(fn, 'w');
fwrite(fid, jsonencode(out, 'PrettyPrint', true), 'char');
fclose(fid);
d = dir(fn);
fprintf('Wrote %s (%.1f MB), model %s, commit %s, uncommitted tracked changes=%d\n', fn, d.bytes/1e6, mrev, sha, out.meta.model_dirty);
for c = 1:numel(cases)
    m = cases{c}.summary;
    fprintf('  %-26s %6.2f h  bat out %7.1f kWh  in %7.1f kWh  SOC end %.3f  cell %.1f-%.1f C\n', cases{c}.name, ...
        m.duration_h, m.E_bat_out_kWh, m.E_bat_in_kWh, m.soc_end, m.Tc_min_C, m.Tc_max_C);
end
end

function c = one_case(name, RUN, dt_s)
R = RUN.R;
t = R.t(:);
c.name = name;
opts = struct();
if isfield(RUN, 'options'), opts = RUN.options; end
c.options = struct('soc0', getf(opts, 'soc0', NaN), 'T0_C', getf(opts, 'T0_C', NaN), 'regen', getf(opts, 'Regen', NaN));

p_bat = R.vt(:).*R.ib(:);
m.duration_h = (t(end) - t(1))/3600;
m.E_bat_out_kWh = trapz(t, max(p_bat, 0))/3.6e6;
m.E_bat_in_kWh = trapz(t, -min(p_bat, 0))/3.6e6;
m.E_chem_net_kWh = trapz(t, p_bat + R.q_bat(:))/3.6e6;
m.E_aux_budget_kWh = trapz(t, R.P_aux_cmd(:))/3.6e6;
m.E_tms_kWh = trapz(t, R.p_tms(:))/3.6e6;
m.E_charger_kWh = trapz(t, max(R.p_chg(:), 0))/3.6e6;
m.soc_start = R.soc(1);
m.soc_end = R.soc(end);
m.ib_max_A = max(R.ib);
m.ib_min_A = min(R.ib);
m.ia_max_A = max(abs(R.ia));
m.v_max_mph = max(R.v_mph);
m.dist_mi = trapz(t, abs(R.v_mph(:)))/3600;
tf = {'Tc', 'Tb', 'Tcs', 'Tcd', 'Tsup', 'Tchg', 'Tchop', 'Tinv', 'Tm'};
for k = 1:numel(tf)
    if isfield(R, tf{k})
        m.([tf{k} '_max_C']) = max(R.(tf{k}));
        m.([tf{k} '_min_C']) = min(R.(tf{k}));
    end
end
m.k_dis_min = min(R.k_dis);
m.k_chg_min = min(R.k_chg);
if isfield(RUN, 'metrics') && isstruct(RUN.metrics) && isfield(RUN.metrics, 'verdict')
    m.verdict = string(RUN.metrics.verdict);
end
c.summary = m;

tg = (t(1):dt_s:t(end))';
sig = {'v_mph', 'v_ref', 'soc', 'vt', 'ib', 'ia', 'p_aux', 'p_tms', 'p_chg', 'P_aux_cmd', 'f_fric', ...
       'Tc', 'Tb', 'Tcs', 'Tcd', 'Tsup', 'Tchg', 'Tchop', 'Tinv', 'Tm', 'k_dis', 'k_chg', 'st'};
ser.t_s = tg;
for k = 1:numel(sig)
    if isfield(R, sig{k}) && numel(R.(sig{k})) == numel(t)
        x = R.(sig{k})(:);
        if strcmp(sig{k}, 'st')
            ser.(sig{k}) = interp1(t, x, tg, 'previous');
        else
            ser.(sig{k}) = interp1(t, x, tg, 'linear');
        end
    end
end
c.series = ser;
end

function v = getf(s, f, d)
v = d;
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); end
end
