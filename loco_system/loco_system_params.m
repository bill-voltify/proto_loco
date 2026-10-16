function P = loco_system_params(opts)
% LOCO_SYSTEM_PARAMS  Phase 3 parameters: Phase 2 plant parameters plus system-level settings.
%   opts fields as proto_loco_params (T_amb_C = initial ambient, T0_C, soc0, I_chg_bms, bms), plus
%   baseline: 'poc' (default; aligned with Micah's POC Power Budget Rev B) or 'phase2' (frozen Phase 2
%   thermal parameters, used by run_regression_phase2).
%   regen: true/false. Default = false for 'poc' (prototype has no regen/dynamic brake; all
%   braking is friction), true for 'phase2' (keeps the Phase 2 regression comparable).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1, opts = struct(); end
baseline = 'poc';
if isfield(opts, 'baseline') && ~isempty(opts.baseline), baseline = opts.baseline; opts = rmfield(opts, 'baseline'); end
regen = [];
if isfield(opts, 'regen'), regen = opts.regen; opts = rmfield(opts, 'regen'); end
if isempty(regen), regen = ~strcmpi(baseline, 'poc'); end
P = proto_loco_params(opts);
P.sys.baseline = baseline;
if strcmpi(baseline, 'poc')
    % POC Power Budget Rev B (Micah, 2026-09-22) alignment, decided 2026-10-08:
    P.th.Q_heat_max = 12e3;    % 1 x Webasto HVH120, 12 kW (was 24 kW Maxwell study)
    P.th.Q_mtm = 12e3;         % 12 kW cooling per MTM (was 12.5 kW)
    P.th.k_cop = 0.10;         % COP 4 at 40 C, 3 at 50 C, 1.5 at 65 C condenser supply:
    P.th.COP_min = 1.5;        %   3 kW nominal / 8 kW peak compressor input per module
    P.th.P_pump = 2.58e3/0.93; % 6 SPAL pumps 350 W + 8 MTM internal pumps 60 W, via DCC65M24 (93%)
    % Radiator fans: EMP per KULI reviews (7 kW per 3-fan bank) kept by decision 2026-10-08;
    % POC Power Budget lists SPAL VA117 12 V fans (RSK-NEW-35).
end
% Regen gate (2026-10-15): the LCC proxy's regen limit is P_reg = I_chg_max*Vbat/eta_drv, and
% I_chg_max is used nowhere else in the Phase 3 plant (charging uses P.chg.I_hw / P.chg.I_bms).
% Setting it to 0 makes TE_el >= 0; lcc_proxy already routes the remaining braking demand to
% F_fric (friction brake). No rebuild needed: mask parameters are read from P at sim time.
P.sys.regen = logical(regen);
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
P.sys.fault_nominal = [4 1 1 1 1 4 12 0 1 1 1 1 0 0];
P.sys.max_step = 1;
end