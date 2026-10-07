function P = loco_system_params(opts)
% LOCO_SYSTEM_PARAMS  Phase 3 parameters: Phase 2 plant parameters plus system-level settings.
%   opts fields as proto_loco_params (T_amb_C = initial ambient, T0_C, soc0, I_chg_bms, bms).
here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));
if nargin < 1, opts = struct(); end
P = proto_loco_params(opts);
P.sys.wn_v = 0.2;
P.sys.zeta_v = 0.8;
P.sys.Ts_ctrl = 1;
P.sys.short_ton_kg = 907.185;
P.sys.states = {'SLEEP','STANDBY','READY','TRACTION','CHARGING','FAULT','ESTOP'};
P.sys.buses = {'750V','72V','24V','12V','220VAC'};
P.sys.fault_channels = {'n_mtm','fan_pe','fan_cd','pump_pe','pump_bat','n_ax_on','n_str','dT_sense_K', ...
                        'blower_ok','comms_ok','aux_ok','chg_derate','estop','classA'};
P.sys.fault_nominal = [4 1 1 1 1 4 12 0 1 1 1 1 0 0];
P.sys.max_step = 1;
end
