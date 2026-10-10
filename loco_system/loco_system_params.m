function P = loco_system_params(opts)
% LOCO_SYSTEM_PARAMS  Phase 3 parameters: Phase 2 plant parameters plus system-level settings.
%   opts fields as proto_loco_params (T_amb_C = initial ambient, T0_C, soc0, I_chg_bms, bms), plus
%   baseline: 'poc' (default; aligned with Micah's POC Power Budget Rev B) or 'phase2' (frozen Phase 2
%   thermal parameters, used by run_regression_phase2).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1, opts = struct(); end
baseline = 'poc';
if isfield(opts, 'baseline') && ~isempty(opts.baseline), baseline = opts.baseline; opts = rmfield(opts, 'baseline'); end
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
    % PE loop per Vince KULI review 2026-10-09 (3 pumps x 4500 rpm, 223 L/min, 40 C), decided 2026-10-09:
    P.th.mcp_chop = 1180;      % 19.7 L/min per chopper, 3.4 K rise at 4.02 kW (was 1430)
    P.th.mcp_inv = 1100;       % front inverter 18.1 L/min, 3.1 K rise at 3.41 kW (was 950)
    % Held pending suppliers: chopper loss model (NAT-43), charger 55 C limit location (NAT-44),
    % P_pump vs KULI 1.15 kW (NAT-45), per-device inverter/aux heat split (NAT-46).
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