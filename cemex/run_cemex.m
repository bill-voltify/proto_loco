function RUN = run_cemex(trace, varargin)
% RUN_CEMEX  Run the CEMEX Victorville locomotive model on a duty trace and report the RFI metrics.
%   RUN = run_cemex()                                    default shift: make_cemex_cycle() on the placeholder route
%   RUN = run_cemex('traces/cemex_victorville_shift.csv', 'Ambient_C', 45, 'soc0', 0.8)
%   RUN = run_cemex([], 'Cycle', {'Trips', 4, 'PlantCharge_kW', 0}, 'Strings', 16)
% trace: CSV path, table, or [] to generate one with make_cemex_cycle(Cycle{:}).
% Name-value options (also see run_loco_system):
%   Cycle         cell of make_cemex_cycle options ({})
%   Strings       battery strings (14 -> 5.85 MWh)          ChgCRate     BMS charge/regen limit, C (0.5)
%   DisCRate      BMS discharge limit, C ([] = sized to the traction cap, see cemex_params)
%   LocoLb        locomotive weight, lb (420000)            MotorCapkW   per-motor cap, kW (536)
%   MuAdh         adhesion coefficient (0.25)               Regen        true/false (true)
%   ChargerkW     wayside charger cap, kW (3000)            ReserveSOC   required SOC at all times (0.20)
%   TMS           'cemex' (default) | 'gp40' | struct(n_mtm, k_cd, k_pe), see cemex_params
%   T0_C          initial pack temperature, C (25 = preconditioned; [] = soaked at ambient)
%   Faults, Budget, Ambient_C, AmbientOffset_C, T0_C, soc0, bms, MaxStep, Plot, Build, Silent, RString, ShowWarnings
% RUN.cemex holds the RFI C5 / D5 metrics: energy per cycle, peak power, min / reserve SOC, regen recovered.
here = fileparts(mfilename('fullpath'));
base = fullfile(fileparts(here), 'loco_system');
addpath(here); addpath(base); addpath(fileparts(here));
p = inputParser;
p.addParameter('Cycle', {});
p.addParameter('Strings', 14);
p.addParameter('ChgCRate', 0.5);
p.addParameter('DisCRate', []);
p.addParameter('LocoLb', 420000);
p.addParameter('MotorCapkW', 536);
p.addParameter('MuAdh', 0.25);
p.addParameter('Regen', true);
p.addParameter('ChargerkW', 3000);
p.addParameter('ReserveSOC', 0.20);
p.addParameter('Faults', fullfile(base, 'faults', 'none.csv'));
p.addParameter('Budget', fullfile(here, 'cemex_load_budget.csv'));
p.addParameter('Ambient_C', []);
p.addParameter('AmbientOffset_C', 0);
p.addParameter('T0_C', 25);       % pack held at 25 C while parked (RFI D17); [] = soaked at ambient
p.addParameter('TMS', 'cemex');
p.addParameter('soc0', 0.9);
p.addParameter('bms', 'jinko');
p.addParameter('MaxStep', 1);
p.addParameter('Plot', true);
p.addParameter('Build', false);
p.addParameter('Silent', false);
p.addParameter('RString', 'vms');
p.addParameter('ShowWarnings', false);
p.parse(varargin{:});
o = p.Results;

if nargin < 1 || isempty(trace)
    trace = make_cemex_cycle(o.Cycle{:});
    trace_name = "cemex_cycle(generated)";
elseif ischar(trace) || isstring(trace)
    trace_name = string(trace);
    if ~isfile(trace), trace = fullfile(here, trace); end
    trace_name = string(trace);
else
    trace_name = "table";
end
TR = load_trace(trace, struct('ambient_C', o.Ambient_C, 'ambient_offset_C', o.AmbientOffset_C));
TR.name = trace_name;
ff = o.Faults; if ~istable(ff) && ~isfile(ff), ff = fullfile(base, ff); end
F = load_fault_table(ff);
P = cemex_params(struct('T_amb_C', TR.ambient0_C, 'T0_C', o.T0_C, 'soc0', o.soc0, 'bms', o.bms, ...
    'r_string', o.RString, 'n_str', o.Strings, 'chg_c_rate', o.ChgCRate, 'dis_c_rate', o.DisCRate, 'loco_lb', o.LocoLb, ...
    'motor_cap_kW', o.MotorCapkW, 'mu_adh', o.MuAdh, 'regen', o.Regen, 'chg_P_max_kW', o.ChargerkW, 'tms', o.TMS));
FLT = build_fault_matrix(F, TR.t_end, P);
B = load_budget_table(o.Budget);

mdl = 'cemex_loco_system';
if o.Build || ~isfile(fullfile(here, [mdl '.slx']))
    build_cemex_model();
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
sim_log = '';
if o.ShowWarnings
    out = sim(in);
else
    [sim_log, out] = evalc('sim(in)');
end
if ~isempty(out.ErrorMessage), error(out.ErrorMessage); end
RUN = report_loco_run(out, TR, F, B, P, o.Plot, o.Silent);
RUN.cemex = cemex_metrics(RUN, P, o);
RUN.sim_seconds = toc;
RUN.options = o;
RUN.params = P.sys.cemex;
RUN.sim_log = sim_log;
RUN.sim_warnings = string(cellfun(@(c) strtrim(c{1}), regexp(sim_log, 'Warning: ([^\n]*)', 'tokens'), 'UniformOutput', false))';
if ~o.Silent
    print_cemex(RUN, P);
    if ~isempty(RUN.sim_warnings), fprintf('Solver warnings: %d. Full text: RUN.sim_log\n', numel(RUN.sim_warnings)); end
end
end

function C = cemex_metrics(RUN, P, o)
R = RUN.R; t = R.t;
mps = 0.44704;
wire = R.p_chg > 1e3;
moving = R.v_mph > 0.1;
C.E_nom_kWh = P.sys.cemex.E_nom_kWh;
C.duration_h = (t(end) - t(1))/3600;
C.bat_out_kWh = RUN.energy.bat_out_kWh;
C.bat_in_regen_kWh = trapz(t, -min(R.p_bat, 0).*~wire)/3.6e6;
C.bat_in_charger_kWh = trapz(t, -min(R.p_bat, 0).*wire)/3.6e6;
C.net_bat_kWh = trapz(t, R.p_bat)/3.6e6;
C.friction_brake_kWh = trapz(t, abs(R.f_fric).*R.v_mph*mps)/3.6e6;
C.regen_share = C.bat_in_regen_kWh/max(C.bat_in_regen_kWh + C.friction_brake_kWh, eps);
run_ = t > t(1) + 10;                      % skip DC-link precharge inrush at HV close (t ~ 2 s)
C.peak_discharge_MW = max(R.p_bat(run_))/1e6;
tg = (t(1):1:t(end))';
pg = interp1(t, R.p_bat, tg);
C.sustained_5min_MW = max(movmean(pg, 300))/1e6;        % RFI sheet 2: continuous traction power
C.I_dis_max_A = P.lcc.I_dis_max;
C.peak_ib_A = max(R.ib(run_));
C.peak_regen_MW = -min(R.p_bat.*~wire)/1e6;
C.peak_TE_kN = 4*max(R.te_ax)/1e3;
C.soc_start = R.soc(1);
C.soc_min = min(R.soc);
C.soc_end = R.soc(end);
C.reserve_soc = o.ReserveSOC;
C.reserve_ok = C.soc_min >= o.ReserveSOC;
C.usable_used_kWh = (C.soc_start - C.soc_min)*C.E_nom_kWh;
% Speed shortfall while moving: how far the locomotive falls below the trace speed (grade, power, adhesion limits)
dv = (R.v_ref - R.v_mph).*(R.v_ref > 1);
C.speed_shortfall_max_mph = max(dv);
C.time_below_ref_2mph_min = sum([diff(t); 0].*(dv > 2))/60;
C.moving_h = sum([diff(t); 0].*moving)/3600;
end

function print_cemex(RUN, P)
C = RUN.cemex; c = P.sys.cemex;
fprintf('\n--- CEMEX Victorville (RFI #13544) | %s on %s ---\n', P.sys.model_rev, P.sys.base_rev);
fprintf('Loco: 6 axles, %.2f MW traction cap, %.0f lb, mu %.2f | battery %d strings = %.0f kWh, discharge %.2fC (%.0f A), charge %.2fC | regen %s | charger %.0f kW\n', ...
    c.P_trac_max_MW, c.loco_lb, c.mu_adh, c.n_str, c.E_nom_kWh, c.dis_c_rate, c.I_dis_max_A, c.chg_c_rate, string(c.regen), c.chg_P_max_kW);
fprintf('C5  energy: battery out %.0f kWh, regen in %.0f kWh, charger in %.0f kWh, net %.0f kWh over %.1f h\n', ...
    C.bat_out_kWh, C.bat_in_regen_kWh, C.bat_in_charger_kWh, C.net_bat_kWh, C.duration_h);
fprintf('C5  peak discharge %.2f MW | SOC %.1f%% -> min %.1f%% -> end %.1f%% | reserve %.0f%%: %s\n', ...
    C.peak_discharge_MW, 100*C.soc_start, 100*C.soc_min, 100*C.soc_end, 100*C.reserve_soc, string(C.reserve_ok));
fprintf('D5  regen recovered %.0f kWh, friction braking %.0f kWh -> %.0f%% of braking energy to the battery (peak regen %.2f MW)\n', ...
    C.bat_in_regen_kWh, C.friction_brake_kWh, 100*C.regen_share, C.peak_regen_MW);
fprintf('C4  peak TE %.0f kN (%.0f klbf) | speed shortfall max %.1f mph, %.0f min > 2 mph below trace\n', ...
    C.peak_TE_kN, C.peak_TE_kN/4.448, C.speed_shortfall_max_mph, C.time_below_ref_2mph_min);
end
