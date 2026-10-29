function P = loco_system_params(opts)
% LOCO_SYSTEM_PARAMS  Phase 3 parameters: Phase 2 plant parameters plus system-level settings.
%   opts fields as proto_loco_params (T_amb_C = initial ambient, T0_C, soc0, I_chg_bms, bms), plus
%   baseline: 'poc' (default; aligned with Micah's POC Power Budget Rev B) or 'phase2' (frozen Phase 2
%   thermal parameters, used by run_regression_phase2).
%   regen: true/false. Default = false for 'poc' (prototype has no regen/dynamic brake; all
%   braking is friction), true for 'phase2' (keeps the Phase 2 regression comparable).
%   Rev C drivetrain options ('poc' only; 'phase2' stays frozen):
%   wheel_in:        wheel diameter, in (default 42, per Jonathan 2026-10-15; 40 = GP40/GP38-2 std)
%   chop_loss:       'integral_sim' (default, Integral 1170 A loss table 2026-10-15) | 'deck' (5.25 kW @ 1050 A)
%   chop_loss_scale: multiplier on integral_sim losses (default 1; 2 if Integral confirms per-module basis)
%   motor_cap_kW:    per-motor power cap, kW (default 536 = D77 FRA rating; 373 = 500 hp prototype limit)
%   motor_flux:      'd77_chart' (default, fit to reference/D77-D78.pdf speed lines) | 'legacy' (9.0*(1-exp(-I/600)))
%   Rev E option ('poc' only; 'phase2' stays frozen):
%   r_string:        per-string resistance outside the cells. 'vms' (default, 10.63 mOhm -> 90.5 mOhm per string at 25 C,
%                    the VMS Power_Sequencing 4.8 value) | 'cells' (0, Rev D) | 'bench' (123.42 mOhm -> 177.5 mOhm ohmic,
%                    CO-2 bench close 2026-10-15, VB-11; upper-bound sensitivity until Mitchell confirms the basis)
%   Model revision: P.sys.model_rev. Rev D (2026-10-21) = Rev C drivetrain + restored KULI 2026-10-09 PE loop values.
%   Rev E (2026-10-21) = Rev D + string resistance outside the cells, 7 SPAL pumps, heater coolant pump, budget rows
%   L19b/L21 (load_budget.csv), VMS_LOSS fault (faults/fault_library.csv, run_vms_loss.m). See MODEL_NOTES.md Rev E.
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1, opts = struct(); end
baseline = 'poc';
if isfield(opts, 'baseline') && ~isempty(opts.baseline), baseline = opts.baseline; opts = rmfield(opts, 'baseline'); end
regen = [];
if isfield(opts, 'regen'), regen = opts.regen; opts = rmfield(opts, 'regen'); end
if isempty(regen), regen = ~strcmpi(baseline, 'poc'); end
[wheel_in, opts] = take(opts, 'wheel_in', 42);
[chop_loss, opts] = take(opts, 'chop_loss', 'integral_sim');
[chop_scale, opts] = take(opts, 'chop_loss_scale', 1);
[motor_cap_kW, opts] = take(opts, 'motor_cap_kW', 536);
[motor_flux, opts] = take(opts, 'motor_flux', 'd77_chart');
[r_string, opts] = take(opts, 'r_string', 'vms');
P = proto_loco_params(opts);
% Rev E fields, defined for both baselines ('phase2' keeps 0 = Rev D behaviour)
P.batt.R_ext_str = 0;      % Ohm per string outside the cells (contactors, fuse, shunt, cabling); heat to ambient, not to Qb
P.th.P_hpump = 0;          % W, PTC heater coolant pump while the heater runs (mh)
P.sys.baseline = baseline;
P.sys.model_rev = 'RevE';
P.sys.model_rev_date = '2026-10-21';
% Motor flux as a lookup table (axle.ssc Rev C). Legacy curve reproduces the Phase 2 analytic Kphi.
P.ax.I_kphi = 0:10:2000;
P.ax.Kphi_tab = P.ax.Kphi_sat*(1 - exp(-max(P.ax.I_kphi, P.ax.If_min)/P.ax.I0));
if strcmpi(baseline, 'poc')
    % POC Power Budget Rev B (Micah, 2026-09-22) alignment, decided 2026-10-08:
    P.th.Q_heat_max = 12e3;    % 1 x Webasto HVH120, 12 kW (was 24 kW Maxwell study)
    P.th.Q_mtm = 12e3;         % 12 kW cooling per MTM (was 12.5 kW)
    P.th.k_cop = 0.10;         % COP 4 at 40 C, 3 at 50 C, 1.5 at 65 C condenser supply:
    P.th.COP_min = 1.5;        %   3 kW nominal / 8 kW peak compressor input per module
    P.th.P_pump = 2.58e3/0.93; % 6 SPAL pumps 350 W + 8 MTM internal pumps 60 W, via DCC65M24 (93%)
    % Radiator fans: EMP per KULI reviews (7 kW per 3-fan bank) kept by decision 2026-10-08;
    % POC Power Budget lists SPAL VA117 12 V fans (RSK-NEW-35).
    % PE loop per Vince KULI review 2026-10-09 (3 pumps x 4500 rpm, 223 L/min, 40 C), decided 2026-10-09.
    % Rev D (2026-10-21): restored; these two lines were dropped by commit b2e57d9 (Oct 10).
    P.th.mcp_chop = 1180;      % 19.7 L/min per chopper, 3.4 K rise at 4.02 kW (was 1430)
    P.th.mcp_inv = 1100;       % front inverter 18.1 L/min, 3.1 K rise at 3.41 kW (was 950)
    % Held pending suppliers: chopper loss basis per chopper vs per module (NAT-43, G-06),
    % P_pump vs KULI 1.15 kW (NAT-45), per-device inverter/aux heat split (NAT-46).

    % Rev E (2026-10-21), from VMS Locomotive_Equipment_List (Mitchell 2026-10-20, VB-22/VB-27):
    % Pumps: 4 BTMS + 3 PE SPAL (350 W each, POC Power Budget nominal; bench 220 W at 80 %, VB-14) + 8 MTM internal 60 W,
    %   via DCC65M24 (93 %): 2.93 kW / 0.93 = 3.15 kW (was 6 SPAL, 2.77 kW).
    P.th.P_pump = (7*350 + 8*60)/0.93;
    % Heater coolant pump: Bosch PCE 0392024041, 24 V, on/off by PDM R7 while the heater runs. Rating not in the VMS
    %   sources: 50 W placeholder.
    P.th.P_hpump = 50;
    % String resistance: 12 strings (Bill 2026-10-21: 48 modules, 4 in series per string, 6 positions of 4s2p).
    %   Cells at 25 C: R0 54.08 + R1 25.79 = 79.87 mOhm per string. Bench CO-2 (VB-11): 176-179 mOhm ohmic (basis
    %   unconfirmed: bench cabling, 37 A, cell temperature, BCU offset). Interim (Bill 2026-10-21): match the VMS per-string
    %   value, 90.5 mOhm at 25 C, as resistance outside the cells.
    switch lower(r_string)
        case 'vms'
            P.batt.R_ext_str = 90.5e-3 - P.batt.Ns*(P.batt.R0_cell + P.batt.R1_cell);
        case 'cells'
            P.batt.R_ext_str = 0;
        case 'bench'
            P.batt.R_ext_str = 177.5e-3 - P.batt.Ns*P.batt.R0_cell;
        otherwise
            error('r_string must be ''vms'', ''cells'' or ''bench''');
    end

    % Rev C drivetrain (2026-10-15)
    % Wheel: 42 in per Jonathan (D77/D78 curves review); D77 chart basis is 62:15 / 40 in.
    P.ax.r_w = wheel_in/2*0.0254;
    % Motor flux: D77 curve, 40 in / 62:15 (reference/D77-D78.pdf, Jonathan 2026-10-15). Kphi read from the
    %   40/45/50/55 mph lines with E = V - 0.030*I (stall line: 60 V @ 2000 A), fitted Kphi = 9.488*I/(299+I):
    %   within 1% at 300-1100 A; -6% at 2000 A (above I_max). Legacy exp fit was 10-26% low below 600 A.
    switch lower(motor_flux)
        case 'd77_chart'
            P.ax.Kphi_tab = 9.488*P.ax.I_kphi./(299 + P.ax.I_kphi);
        case 'legacy'
        otherwise
            error('motor_flux must be ''d77_chart'' or ''legacy''');
    end
    P.ax.T_tab = interp1(P.ax.I_kphi, P.ax.Kphi_tab, max(P.ax.I_tab, P.ax.If_min)).*P.ax.I_tab;
    % D77 current ratings (same chart): continuous 1050 A, 15 min 1150 A, 5 min 1500 A (= I_max).
    P.ax.I_cont = 1050;
    P.ax.I_15min = 1150;
    P.ax.I_5min = 1500;
    % Chopper loss: Integral sim, 1170 A, 500 Hz (J. Jankowski 2026-10-15):
    %   switching 996+584 = 1580 W (linear in I, prop. to f); conduction 45+859 / 269+633 = 904 W (duty-independent).
    %   Conduction fitted as a*I + b*I^2 to 904*(I/1170)^1.5 at 600 A and 1500 A. Total 2.47 kW @ 1170 A.
    %   'deck' = previous 5.25 kW @ 1050 A (2.5 V, 2.38 mOhm).
    switch lower(chop_loss)
        case 'integral_sim'
            P.ax.a_loss = chop_scale*(1580/1170 + 0.339);
            P.ax.b_loss = chop_scale*3.57e-4;
        case 'deck'
            P.ax.a_loss = 2.5;
            P.ax.b_loss = 2.38e-3;
        otherwise
            error('chop_loss must be ''integral_sim'' or ''deck''');
    end
    P.th.a_loss = P.ax.a_loss;
    P.th.b_loss = P.ax.b_loss;
    % Motor power cap: 536 kW = D77 FRA input rating; 373 kW = 500 hp prototype limit (Jonathan).
    P.ax.P_ax_max = min(655e3, motor_cap_kW*1e3);
    P.lcc.P_trac_max = 4*motor_cap_kW*1e3;
    % Control latency (Integral): chopper loop 2 ms, CAN 10 ms, LCC 10 ms, worst case ~22 ms end to end.
    % Not modeled: below Ts_ctrl / MaxStep (1 s). Protection trips are local hardware on the ITC board.
    P.sys.ctrl_latency_s = 0.022;
    % OBC (AUX-B002): 55 C max applies to coolant INLET; 2 loops x 30 LPM, 6 C rise, ~21 kW at 3 MW.
    % Existing th.eta_chg 0.9934 and th.mcp_chg 3600 W/K (60 LPM 50/50 EGW) agree; unchanged.
    P.sys.chg_inlet_max_C = 55;
    % Demo charge limit (DR-17, Jonathan 2026-10-12, adopted 2026-10-16): Jacksonville ground ESS 4.2 MWh at 0.5C
    % = 2.1 MW at the wire, and wire current <= 1,666 A (2 x 833 A DPS100). Set by the trace wire_kW (S9 = 2,100 kW);
    % report_loco_run flags any charge above it. Loco side: 2.1 MW / 5.02 MWh = 0.42C (below the Jinko 0.5C rating).
    P.sys.demo_chg_P_max_W = 2.1e6;
    P.sys.demo_chg_I_wire_max_A = 1666;
    P.sys.drivetrain_rev = sprintf('RevC wheel=%gin chop=%s x%g cap=%gkW flux=%s', wheel_in, chop_loss, chop_scale, motor_cap_kW, motor_flux);
    P.sys.string_rev = sprintf('RevE r_string=%s R_ext=%.2f mOhm/string', r_string, 1e3*P.batt.R_ext_str);
end
% Regen gate (2026-10-15): the LCC proxy's regen limit is P_reg = I_chg_max*Vbat/eta_drv, and
% I_chg_max is used nowhere else in the Phase 3 plant (charging uses P.chg.I_hw / P.chg.I_bms).
% Setting it to 0 makes TE_el >= 0; lcc_proxy already routes the remaining braking demand to
% F_fric (friction brake). No rebuild needed: mask parameters are read from P at sim time.
P.sys.regen = logical(regen);
% Brake blending (2026-10-29, lcc_proxy): defaults are inert, identical to Rev E. CEMEX sets them in cemex_params.
%   soc_reg_max/soc_reg_band: regen taper near full SOC (2 = never); P_db_max: dynamic-brake grids, W (0 = none);
%   v_db_blend: grid fade speed; k_tb: train air brake capacity, fraction of trailing weight (0 = none).
P.lcc.soc_reg_max = 2;
P.lcc.soc_reg_band = 0.02;
P.lcc.P_db_max = 0;
P.lcc.v_db_blend = 2.2;
P.lcc.k_tb = 0;
P.lcc.eta_reg = P.lcc.eta_drv;   % regen-limit efficiency (lcc_proxy P_reg); default = eta_drv, identical to Rev E
% Wheel slip (2026-10-30, axle.ssc): model 0 = wheels locked to the vehicle, identical to Rev E (the other fields are then unused).
%   model 1: wheelset speed state + creep law; mode 0 none | 1 per-axle | 2 common slip/slide control; J_w wheelset + armature
%   inertia at the wheel; wt weight transfer per axle (dN = wt x 4 x TE_ref); x_off axle positions from the lead axle, m;
%   mu_rail adhesion at the creep peak; s_tab/mu_tab normalised creep curve (peak 1 at 2 % creep); s_tgt controller creep
%   target; K_sc cut rate, 1/s per unit creep; tau_r recovery, s; x_p0..x_p1 contaminated patch, m; f_patch adhesion factor on it.
P.slip = struct('model', 0, 'mode', 1, 'J_w', 1000, 'wt', [0 0 0 0], 'x_off', [0 -2.1 -12.2 -14.3], 'mu_rail', 0.25, ...
    's_tab', [-1 -0.5 -0.2 -0.1 -0.05 -0.03 -0.02 -0.01 -0.005 0 0.005 0.01 0.02 0.03 0.05 0.1 0.2 0.5 1], ...
    'mu_tab', [-0.6 -0.65 -0.72 -0.8 -0.9 -0.97 -1 -0.75 -0.45 0 0.45 0.75 1 0.97 0.9 0.8 0.72 0.65 0.6], ...
    'v_s0', 1, 's_tgt', 0.02, 'K_sc', 50, 'tau_r', 2, 'x_p0', 1e9, 'x_p1', 1e9, 'f_patch', 1);
if ~P.sys.regen
    P.lcc.I_chg_max = 0;
end
P.sys.wn_v = 0.2;
P.sys.zeta_v = 0.8;
P.sys.Ts_ctrl = 1;
P.sys.short_ton_kg = 907.185;
P.sys.states = {'SLEEP','STANDBY','READY','TRACTION','CHARGING','FAULT','ESTOP'};
P.sys.buses = {'750V','72V','24V_Ctrl','24V_BTMS','12V_BTMS'};
P.sys.fault_channels = {'n_mtm','fan_pe','fan_cd','pump_pe','pump_bat','n_ax_on','n_str','dT_sense_K', ...
                        'blower_ok','comms_ok','aux_ok','chg_derate','estop','classA'};
% n_str = strings online (12 strings of 416S, Bill 2026-10-21; closes NAT-14).
P.sys.fault_nominal = [4 1 1 1 1 4 12 0 1 1 1 1 0 0];
P.sys.max_step = 1;
end

function [v, s] = take(s, name, default)
v = default;
if isfield(s, name)
    if ~isempty(s.(name)), v = s.(name); end
    s = rmfield(s, name);
end
end
