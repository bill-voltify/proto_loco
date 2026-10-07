function T = run_regression_phase2(ambients, ic_list, scn_pick)
% RUN_REGRESSION_PHASE2  Phase 3 must reproduce the verified Phase 2 sweep.
% Uses traces/S1..S8 (aux_override = Phase 2 aux, automatic states, no faults) and compares
% with the newest results/thermal_sweep_*.csv from the repo root.
%   T = run_regression_phase2()                       % all 80 cases
%   T = run_regression_phase2([20 50], {'precond'}, [2 5])
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(here); addpath(root);
if nargin < 1 || isempty(ambients), ambients = [0 10 20 40 50]; end
if nargin < 2 || isempty(ic_list), ic_list = {'soaked','precond'}; end
S = proto_scenarios();
if nargin >= 3 && ~isempty(scn_pick), S = S(scn_pick); end
d = dir(fullfile(root, 'results', 'thermal_sweep_*.csv'));
assert(~isempty(d), 'No Phase 2 results in %s', fullfile(root, 'results'));
[~, i] = max([d.datenum]);
ref = readtable(fullfile(d(i).folder, d(i).name), 'TextType', 'string');
build_loco_system();
rows = [];
for ic = 1:numel(ic_list)
    for s = 1:numel(S)
        for a = 1:numel(ambients)
            Ta = ambients(a);
            T0 = Ta; if strcmp(ic_list{ic}, 'precond'), T0 = 25; end
            fprintf('%-20s %3d C %-7s ... ', S(s).name, Ta, ic_list{ic});
            try
                RUN = run_loco_system(fullfile(here, 'traces', [S(s).name '.csv']), 'Ambient_C', Ta, 'T0_C', T0, ...
                    'soc0', S(s).soc0, 'I_chg_bms', S(s).I_chg_bms, 'MaxStep', S(s).max_step, 'Plot', false, 'Silent', true);
                M = RUN.metrics;
                r = ref(ref.scenario == S(s).name & ref.T_amb == Ta & ref.ic == ic_list{ic}, :);
                row = struct('scenario', string(S(s).name), 'ic', string(ic_list{ic}), 'T_amb', Ta, ...
                    'verdict_p3', M.verdict, 'verdict_p2', r.verdict(1), ...
                    'dTcell_max', M.Tcell_max - r.Tcell_max(1), 'dTsup_max', M.Tsup_max - r.Tsup_max(1), ...
                    'dTcond_max', M.Tcond_max - r.Tcond_max(1), 'dsoc_end', M.soc_end - r.soc_end(1));
                row.pass = row.verdict_p3 == row.verdict_p2 && abs(row.dTcell_max) < 0.5 && ...
                    abs(row.dTsup_max) < 1.0 && abs(row.dsoc_end) < 0.01;
            catch ME
                row = struct('scenario', string(S(s).name), 'ic', string(ic_list{ic}), 'T_amb', Ta, ...
                    'verdict_p3', "ERROR", 'verdict_p2', "", 'dTcell_max', NaN, 'dTsup_max', NaN, ...
                    'dTcond_max', NaN, 'dsoc_end', NaN, 'pass', false);
                fprintf('%s\n', ME.message);
            end
            fprintf('%s vs %s  pass=%d\n', row.verdict_p3, row.verdict_p2, row.pass);
            rows = [rows; struct2table(row, 'AsArray', true)]; %#ok<AGROW>
        end
    end
end
T = rows;
fprintf('\nRegression: %d / %d pass\n', sum(T.pass), height(T));
writetable(T, fullfile(root, 'results', ['regression_p3_vs_p2_' datestr(now, 'yyyymmdd_HHMM') '.csv'])); %#ok<TNOW1,DATST>
end
