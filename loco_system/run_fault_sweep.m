function T = run_fault_sweep(varargin)
% RUN_FAULT_SWEEP  Run every fault in the library, one at a time, against a heavy-duty trace and
% rank faults by effect. Feeds FMEA occurrence/detection review and the RSK register (DVP C-21).
%   T = run_fault_sweep()                                    % defaults below
%   T = run_fault_sweep('Ambients', [40 45], 'Faults', {'PE_FAN_FAIL','MTM_LOSS_1'})
%   T = run_fault_sweep('Parallel', true)                    % parfor (Parallel Computing Toolbox)
% Options: Trace (traces/fault_test_3h.csv), Library (faults/fault_library.csv), Ambients [20 40 45],
%          Onset_s 1800, T0_C 25, soc0 0.9, Faults {} (= all), Parallel false
here = fileparts(mfilename('fullpath'));
addpath(here); addpath(fileparts(here));
p = inputParser;
p.addParameter('Trace', fullfile(here, 'traces', 'fault_test_3h.csv'));
p.addParameter('Library', fullfile(here, 'faults', 'fault_library.csv'));
p.addParameter('Ambients', [20 40 45]);
p.addParameter('Onset_s', 1800);
p.addParameter('T0_C', 25);
p.addParameter('soc0', 0.9);
p.addParameter('Faults', {});
p.addParameter('Parallel', false);
p.parse(varargin{:});
o = p.Results;

L = load_fault_table(o.Library);
if ~isempty(o.Faults), L = L(ismember(L.fault_id, string(o.Faults)), :); end
by_design = ["comms_ok","classA","estop"];
build_loco_system();

% job list: baseline + each fault, per ambient
jobs = struct('fault', {}, 'channel', {}, 'fmea', {}, 'Ta', {}, 'F', {});
for a = o.Ambients
    F0 = L([], :);
    jobs(end+1) = struct('fault', "BASELINE", 'channel', "", 'fmea', "", 'Ta', a, 'F', F0); %#ok<AGROW>
    for k = 1:height(L)
        Fk = L(k, :);
        Fk.enabled = 1;
        Fk.t_start_s = o.Onset_s;
        Fk.t_end_s = 1e9;
        jobs(end+1) = struct('fault', L.fault_id(k), 'channel', L.channel(k), 'fmea', string(L.fmea(k)), 'Ta', a, 'F', Fk); %#ok<AGROW>
    end
end
n = numel(jobs);
res = cell(n, 1);
runone = @(j) sweep_one(j, o);
if o.Parallel
    parfor i = 1:n, res{i} = runone(jobs(i)); end
else
    for i = 1:n
        fprintf('[%2d/%2d] %-18s %2d C ... ', i, n, jobs(i).fault, jobs(i).Ta);
        res{i} = runone(jobs(i));
        fprintf('%s %s\n', res{i}.verdict, res{i}.first_limit);
    end
end
T = struct2table([res{:}]');

T.by_design_stop = ismember(T.channel, by_design);
lvl = containers.Map({'OPTIMAL','OK','DERATED','FAIL','ERROR'}, {4, 3, 2, 1, 0});
T.severity = cellfun(@(v) lvl(char(v)), cellstr(T.verdict));
% deltas vs baseline at the same ambient
for v = {'dSOC_end','dTchop_max','dTinv_max','dTcell_max','dTmotor_max'}, T.(v{1}) = nan(height(T), 1); end
for i = 1:height(T)
    b = T(T.fault == "BASELINE" & T.T_amb == T.T_amb(i), :);
    T.dSOC_end(i) = T.soc_end(i) - b.soc_end(1);
    T.dTchop_max(i) = T.Tchop_max(i) - b.Tchop_max(1);
    T.dTinv_max(i) = T.Tinv_max(i) - b.Tinv_max(1);
    T.dTcell_max(i) = T.Tcell_max(i) - b.Tcell_max(1);
    T.dTmotor_max(i) = T.Tmotor_max(i) - b.Tmotor_max(1);
end

% relative-to-baseline class (v2): judges each fault against the no-fault run at the same ambient
%   WORSE: new limit, lower verdict, or first limit > 0.25 h earlier | WATCH: no new limit but large rise
%   (chopper/inverter > 10 K, cell > 2 K, motor > 30 K) | MASKED: better verdict only because cooling ran less
%   TRADE-OFF: better verdict at a functional cost | SAME | BY-DESIGN: designed stop
masking = ["n_mtm","dT_sense_K","aux_ok"];
T.rel_baseline = strings(height(T), 1);
T.new_limits = strings(height(T), 1);
for i = 1:height(T)
    b = T(T.fault == "BASELINE" & T.T_amb == T.T_amb(i), :);
    nl = setdiff(split_limits(T.limit(i)), split_limits(b.limit(1)));
    tb = b.t_first_limit_h(1); if isnan(tb), tb = inf; end
    tr = T.t_first_limit_h(i); if isnan(tr), tr = inf; end
    if T.by_design_stop(i)
        rel = "BY-DESIGN";
    elseif T.fault(i) == "BASELINE"
        rel = "BASELINE";
    elseif ~isempty(nl) || T.severity(i) < b.severity(1) || tr < tb - 0.25
        rel = "WORSE";
    elseif T.dTchop_max(i) > 10 || T.dTinv_max(i) > 10 || T.dTcell_max(i) > 2 || T.dTmotor_max(i) > 30
        rel = "WATCH";
    elseif T.severity(i) > b.severity(1)
        if ismember(T.channel(i), masking), rel = "MASKED"; else, rel = "TRADE-OFF"; end
    else
        rel = "SAME";
    end
    T.rel_baseline(i) = rel;
    T.new_limits(i) = strjoin(nl, '; ');
end
t_rank = T.t_first_limit_h; t_rank(isnan(t_rank)) = inf;
[~, ord] = sortrows([T.severity, t_rank, -double(T.T_amb)]);
T = T(ord, :);

outdir = fullfile(fileparts(here), 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
writetable(T, fullfile(outdir, ['fault_sweep_' stamp '.csv']));
save(fullfile(outdir, ['fault_sweep_' stamp '.mat']), 'T', 'o');

% heatmap: faults x ambients
faults = unique(T.fault, 'stable');
Z = nan(numel(faults), numel(o.Ambients));
for i = 1:numel(faults)
    for a = 1:numel(o.Ambients)
        r = T(T.fault == faults(i) & T.T_amb == o.Ambients(a), :);
        if ~isempty(r), Z(i, a) = r.severity(1); end
    end
end
figure('Name', 'Fault sweep', 'Position', [100 80 700 60 + 22*numel(faults)]);
imagesc(Z, [0 4]);
colormap([0.5 0.5 0.5; 0.85 0.2 0.2; 0.95 0.65 0.1; 0.6 0.8 0.4; 0.2 0.6 0.3]);
set(gca, 'XTick', 1:numel(o.Ambients), 'XTickLabel', compose('%d C', o.Ambients), ...
         'YTick', 1:numel(faults), 'YTickLabel', strrep(cellstr(faults), '_', '\_'));
cb = colorbar; cb.Ticks = 0:4; cb.TickLabels = {'ERROR','FAIL','DERATED','OK','OPTIMAL'};
title(sprintf('Fault sweep: %s, onset %.1f h', o.Trace, o.Onset_s/3600), 'Interpreter', 'none');
% relative-to-baseline heatmap
rl = containers.Map({'WORSE','WATCH','SAME','MASKED','TRADE-OFF','BY-DESIGN','BASELINE'}, {1, 2, 3, 4, 4, 5, 3});
Z2 = nan(numel(faults), numel(o.Ambients));
for i = 1:numel(faults)
    for a = 1:numel(o.Ambients)
        r = T(T.fault == faults(i) & T.T_amb == o.Ambients(a), :);
        if ~isempty(r), Z2(i, a) = rl(char(r.rel_baseline(1))); end
    end
end
figure('Name', 'Fault sweep vs baseline', 'Position', [820 80 700 60 + 22*numel(faults)]);
imagesc(Z2, [1 5]);
colormap([0.85 0.2 0.2; 0.95 0.65 0.1; 0.75 0.75 0.75; 0.55 0.75 0.95; 0.6 0.6 0.85]);
set(gca, 'XTick', 1:numel(o.Ambients), 'XTickLabel', compose('%d C', o.Ambients), ...
         'YTick', 1:numel(faults), 'YTickLabel', strrep(cellstr(faults), '_', '\_'));
cb = colorbar; cb.Ticks = 1:5; cb.TickLabels = {'WORSE','WATCH','SAME','MASKED / TRADE-OFF','BY-DESIGN'};
title('Fault effect relative to no-fault baseline');
disp(T(:, {'fault','fmea','T_amb','verdict','rel_baseline','new_limits','first_limit','t_first_limit_h','dSOC_end','dTchop_max','dTinv_max','dTcell_max','by_design_stop'}));
end

function L = split_limits(s)
if ismissing(s) || strlength(s) == 0
    L = strings(0, 1);
    return
end
L = strtrim(split(string(s), ';'));
L = L(strlength(L) > 0 & ~startsWith(L, 'PE margin') & ~contains(L, 'outside'));
end

function r = sweep_one(j, o)
r = struct('fault', j.fault, 'channel', j.channel, 'fmea', j.fmea, 'T_amb', j.Ta, 'verdict', "ERROR", ...
    'limit', "", 'first_limit', "", 't_first_limit_h', NaN, 'Tcell_max', NaN, 'Tsup_max', NaN, ...
    'Tchop_max', NaN, 'Tinv_max', NaN, 'Tcond_max', NaN, 'Tmotor_max', NaN, 'k_dis_min', NaN, ...
    'soc_end', NaN, 'E_bat_out_kWh', NaN, 'E_tms_kWh', NaN);
try
    RUN = run_loco_system(o.Trace, 'Faults', j.F, 'Ambient_C', j.Ta, 'T0_C', o.T0_C, 'soc0', o.soc0, ...
        'Plot', false, 'Silent', true);
    M = RUN.metrics; R = RUN.R;
    P = loco_system_params();
    [nm, tf] = first_limit(R, P, o.Onset_s);
    r.verdict = M.verdict; r.limit = M.limit; r.first_limit = nm; r.t_first_limit_h = tf;
    r.Tcell_max = M.Tcell_max; r.Tsup_max = M.Tsup_max; r.Tchop_max = M.Tchop_out_max;
    r.Tinv_max = M.Tinv_out_max; r.Tcond_max = M.Tcond_max; r.Tmotor_max = M.Tmotor_max;
    r.k_dis_min = M.k_dis_min; r.soc_end = M.soc_end;
    r.E_bat_out_kWh = RUN.energy.bat_out_kWh; r.E_tms_kWh = RUN.energy.tms_kWh;
catch ME
    r.limit = string(ME.message);
end
end

function [name, t_h] = first_limit(R, P, t_on)
% First hard limit or derate after fault onset; time in hours after onset.
L = P.lim;
t = R.t;
after = t >= t_on;
chg = R.P_chg_cmd > 1e3 & R.soc < P.chg.soc_max - 0.03;
drv = R.v_ref > 0.2;
tests = {
    'cell >= BMS L2 hot',      R.Tc >= P.bms.T_hot_L2;
    'charger supply > limit',  chg & R.Tsup > L.T_chg_sup;
    'chopper fluid > limit',   R.Tchop > L.T_chop_out;
    'inverter fluid > limit',  R.Tinv > L.T_inv_out;
    'condenser loop > limit',  R.Tcd > L.T_check_valve;
    'motor > limit',           R.Tm > L.T_motor;
    'BMS discharge derate',    drv & R.k_dis < 0.99;
    'BMS charge derate',       chg & R.k_chg < 0.99;
    'speed deficit > 1 mph',   drv & R.v_ref > 0.4 & (R.v_mph < R.v_ref - 1) & movmean(R.v_ref, 5) == R.v_ref;
    'traction blocked (state)', drv & R.trac < 0.5};
name = "none"; t_h = NaN;
for k = 1:size(tests, 1)
    i = find(after & tests{k, 2}, 1);
    if ~isempty(i) && (isnan(t_h) || (t(i) - t_on)/3600 < t_h)
        t_h = (t(i) - t_on)/3600;
        name = string(tests{k, 1});
    end
end
end
