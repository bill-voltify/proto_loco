function RUN = run_loco_system(trace, varargin)
% RUN_LOCO_SYSTEM  Run the Phase 3 system model on a duty trace.
%   RUN = run_loco_system('traces/example_yard_day_8h.csv')
%   RUN = run_loco_system(trace, 'Faults', 'faults/example_hot_day_faults.csv', 'Ambient_C', 40)
% Name-value options:
%   Faults          fault table file or table (default faults/none.csv)
%   Budget          load budget file (default load_budget.csv)
%   Ambient_C       constant ambient override (C); [] = use the trace column
%   AmbientOffset_C add to the trace ambient (C)
%   T0_C            initial cell temperature (C); [] = soaked at initial ambient
%   soc0            initial SOC (0.9)
%   I_chg_bms       BMS charge-current limit, A (1884)
%   bms             'jinko' | 'cell_spec'
%   MaxStep         solver max step, s (1)
%   Plot            true/false (true)
%   Build           force rebuild of the model (false)
%   Baseline        'poc' (Micah's POC Power Budget, default) | 'phase2' (regression)
%   UseBudget       true = ignore the trace's aux_override_kW and use load_budget.csv (false)
here = fileparts(mfilename('fullpath'));
addpath(here); addpath(fileparts(here));
p = inputParser;
p.addParameter('Faults', fullfile(here, 'faults', 'none.csv'));
p.addParameter('Budget', fullfile(here, 'load_budget.csv'));
p.addParameter('Ambient_C', []);
p.addParameter('AmbientOffset_C', 0);
p.addParameter('T0_C', []);
p.addParameter('soc0', 0.9);
p.addParameter('I_chg_bms', 1884);
p.addParameter('bms', 'jinko');
p.addParameter('MaxStep', 1);
p.addParameter('Plot', true);
p.addParameter('Build', false);
p.addParameter('Silent', false);
p.addParameter('Baseline', 'poc');
p.addParameter('UseBudget', false);
p.parse(varargin{:});
o = p.Results;

if ischar(trace) || isstring(trace)
    tf = char(trace);
    if ~isfile(tf), tf = fullfile(here, tf); end
    TR = load_trace(tf, struct('ambient_C', o.Ambient_C, 'ambient_offset_C', o.AmbientOffset_C));
else
    TR = load_trace(trace, struct('ambient_C', o.Ambient_C, 'ambient_offset_C', o.AmbientOffset_C));
end
if istable(o.Faults)
    F = load_fault_table(o.Faults);
else
    ff = char(o.Faults); if ~isfile(ff), ff = fullfile(here, ff); end
    F = load_fault_table(ff);
end
P = loco_system_params(struct('T_amb_C', TR.ambient0_C, 'T0_C', o.T0_C, 'soc0', o.soc0, ...
    'I_chg_bms', o.I_chg_bms, 'bms', o.bms, 'baseline', o.Baseline));
if o.UseBudget, TR.SCN(:, 7) = -1; end
FLT = build_fault_matrix(F, TR.t_end, P);
B = load_budget_table(o.Budget);

mdl = 'voltify_loco_system';
if o.Build || ~isfile(fullfile(here, [mdl '.slx']))
    build_loco_system();
end
load_system(fullfile(here, [mdl '.slx']));
in = Simulink.SimulationInput(mdl);
in = in.setVariable('P', P);
in = in.setVariable('SCN', TR.SCN);
in = in.setVariable('SCN_D', TR.SCN_D);
in = in.setVariable('FLT', FLT);
in = in.setVariable('LB', B.LB);
in = in.setVariable('LBmov', B.LBmov);
in = in.setVariable('LBbus', B.LBbus);
in = in.setVariable('LBeff', B.LBeff);
in = in.setModelParameter('StopTime', num2str(TR.t_end), 'MaxStep', num2str(o.MaxStep));
tic;
out = sim(in);
if ~isempty(out.ErrorMessage), error(out.ErrorMessage); end
RUN = report_loco_run(out, TR, F, B, P, o.Plot, o.Silent);
RUN.sim_seconds = toc;
RUN.options = o;
end
