function P = cemex_params(opts)
% CEMEX_PARAMS  CEMEX Victorville six-axle battery locomotive (RFI #13544), parallel to the GP40 proto.
%   Starts from loco_system_params (GP40 proto, 'poc' baseline, Rev E) and applies the CEMEX changes.
%   The GP40 files are not modified; every CEMEX difference lives here.
%   opts fields as loco_system_params (T_amb_C, T0_C, soc0, bms, wheel_in, chop_loss, motor_flux, r_string),
%   plus:
%   n_str:        battery strings of 416S (default 14 -> 5.85 MWh; Voltify RFI response 3-Battery Capacity: 5.8 MWh)
%   chg_c_rate:   BMS charge current limit (charger and regen), C (default 0.5 = Jinko rating, same basis as the GP40)
%   dis_c_rate:   BMS discharge current limit, C. Default [] = sized to traction: the current that delivers the
%                 traction cap (6 x motor_cap_kW) at V_dis_floor through eta_drv, i.e. full power across the SOC window
%   V_dis_floor:  battery terminal voltage the discharge limit is sized at, V (default 416 x 3.0 V = 1248 V,
%                 loaded pack near the low-SOC end). Cell discharge rating above 0.5C is NOT confirmed (Jinko).
%   loco_lb:      locomotive weight, lb (default 420,000: PLACEHOLDER, six-axle battery loco; no CEMEX weight yet)
%   motor_cap_kW: per-motor power cap, kW (default 536 = D77 FRA rating -> 3.2 MW; 655 = chopper rating -> 3.9 MW)
%   mu_adh:       adhesion coefficient (default 0.25 dry; RFI C6 asks for wet / low adhesion, try 0.18)
%   regen:        true (default; RFI 5-Regenerative Braking requires regen to the battery)
%   chg_P_max_kW: wayside charger cap, kW (default 3000 = Voltify manual charger, RFI B10)
%   tms:          cooling system: 'cemex' (default, sized below) | 'gp40' (unchanged GP40 Rev E system) | struct with
%                 any of n_mtm, k_cd, k_pe to override the CEMEX sizing
%   soh:          battery capacity retention (default 1 = beginning of life; 0.70 = end of life, Voltify RFI response
%                 3-Battery degradation: 8000 cycles to 70 %). BMS current limits stay at the beginning-of-life amps.
%   r_age:        cell resistance multiplier (default 1; 1.5 assumed at end of life, not a Jinko figure)
%
% Six axles on a four-axle plant: the Simscape plant (loco_system/+locosys) has four axle components. Each one
% stands for 1.5 traction motors in parallel (k = 6/4) with the same voltage: current, torque, power cap and
% current limit x k; armature R and L / k; chopper conduction loss b / k (a unchanged); current-loop gain / k;
% coolant flow and motor thermal mass x k. Per-motor behaviour is identical to the GP40 D77 axle, so the verified
% Rev E equations are reused unchanged. Axle cut-out (n_ax_on) therefore removes 1.5 motors, not 1.
if nargin < 1, opts = struct(); end
[n_str, opts] = take(opts, 'n_str', 14);
[chg_c_rate, opts] = take(opts, 'chg_c_rate', 0.5);
[dis_c_rate, opts] = take(opts, 'dis_c_rate', []);
[V_dis_floor, opts] = take(opts, 'V_dis_floor', 416*3.0);
[loco_lb, opts] = take(opts, 'loco_lb', 420000);
[motor_cap_kW, opts] = take(opts, 'motor_cap_kW', 536);
[mu_adh, opts] = take(opts, 'mu_adh', 0.25);
[regen, opts] = take(opts, 'regen', true);
[chg_kW, opts] = take(opts, 'chg_P_max_kW', 3000);
[wheel_in, opts] = take(opts, 'wheel_in', 40);
[tms, opts] = take(opts, 'tms', 'cemex');
[soh, opts] = take(opts, 'soh', 1);
[r_age, opts] = take(opts, 'r_age', 1);
opts.baseline = 'poc';
opts.regen = regen;
opts.motor_cap_kW = motor_cap_kW;
opts.wheel_in = wheel_in;
P = loco_system_params(opts);
n_str0 = P.batt.Np;

% ---------------- Battery: n_str strings of 416S (GP40: 12) ----------------
P.batt.Np = n_str;
P.sys.fault_nominal(strcmp(P.sys.fault_channels, 'n_str')) = n_str;
Ah = P.batt.Q_cell*n_str;
if isempty(dis_c_rate)
    dis_c_rate = 6*motor_cap_kW*1e3/(V_dis_floor*P.lcc.eta_drv)/Ah;
end
P.lcc.I_dis_max = dis_c_rate*Ah;
P.lcc.I_chg_max = regen*chg_c_rate*Ah;
P.chg.I_bms = chg_c_rate*Ah;
ks = n_str/n_str0;                 % pack thermal mass and areas scale with strings
P.th.C_bat = ks*P.th.C_bat;
P.th.UA_bc = ks*P.th.UA_bc;
P.th.UA_benv = ks*P.th.UA_benv;
P.th.C_bc = ks*P.th.C_bc;
E_bol_kWh = P.batt.Ns*3.2*Ah/1e3;
P.batt.Q_cell = soh*P.batt.Q_cell;     % aged pack: capacity and resistance only; current limits above stay
P.batt.R0_cell = r_age*P.batt.R0_cell;
P.batt.R1_cell = r_age*P.batt.R1_cell;

% ---------------- Drivetrain: 6 x D77 on 4 modeled axles ----------------
k = 6/4;
P.ax.I_kphi = k*P.ax.I_kphi;
P.ax.I_tab = k*P.ax.I_tab;
P.ax.T_tab = k*P.ax.T_tab;
P.ax.If_min = k*P.ax.If_min;
P.ax.I_max = k*P.ax.I_max;
P.ax.R_m = P.ax.R_m/k;
P.ax.L_a = P.ax.L_a/k;
P.ax.Kp_i = P.ax.Kp_i/k;
P.ax.b_loss = P.ax.b_loss/k;
P.ax.P_ax_max = k*P.ax.P_ax_max;
P.ax.I_cont = k*P.ax.I_cont;
P.ax.I_15min = k*P.ax.I_15min;
P.ax.I_5min = k*P.ax.I_5min;
P.th.R_m = P.ax.R_m;
P.th.b_loss = P.ax.b_loss;
P.th.mcp_chop = k*P.th.mcp_chop;
P.th.C_mot = k*P.th.C_mot;
P.th.UA_mot = k*P.th.UA_mot;
P.lcc.P_trac_max = 6*motor_cap_kW*1e3;
P.lcc.mu_adh = mu_adh;

% ---------------- Cooling (TMS) ----------------
% The GP40 Rev E system (4 MTMs at 12 kW, one condenser radiator bank UA 2810 W/K with 7 kW EMP fans, one PE
% radiator bank UA 2834 W/K) fails the 65 C condenser check-valve limit at 45 C on this duty: the larger pack at
% 0.67-0.81C needs ~55 kW of chilling, i.e. ~75 kW rejected through the condenser. CEMEX sizing, by the same
% component types scaled per bank (radiator UA, coolant flow, fluid mass and fan power x k):
%   n_mtm  chiller modules (12 kW each)
%   k_cd   condenser radiator banks relative to the GP40 single bank
%   k_pe   PE radiator banks (choppers x 6 motors, 3 MW charger, inverters) relative to the GP40 single bank
tms_n = struct('n_mtm', 4, 'k_cd', 1, 'k_pe', 1);
if isstruct(tms) || strcmpi(tms, 'cemex')
    tms_n = struct('n_mtm', 6, 'k_cd', 3, 'k_pe', 2);
    if isstruct(tms)
        f = fieldnames(tms);
        for i = 1:numel(f), tms_n.(f{i}) = tms.(f{i}); end
    end
elseif ~strcmpi(tms, 'gp40')
    error('tms must be ''cemex'', ''gp40'' or a struct');
end
n_mtm0 = P.th.N_mtm;
P.th.N_mtm = tms_n.n_mtm;
P.sys.fault_nominal(strcmp(P.sys.fault_channels, 'n_mtm')) = tms_n.n_mtm;
P.th.UA_cd = tms_n.k_cd*P.th.UA_cd;
P.th.mcp_cd = tms_n.k_cd*P.th.mcp_cd;
P.th.C_cd = tms_n.k_cd*P.th.C_cd;
P.th.P_fan_cd = tms_n.k_cd*P.th.P_fan_cd;
P.th.UA_pe = tms_n.k_pe*P.th.UA_pe;
P.th.mcp_pe = tms_n.k_pe*P.th.mcp_pe;
P.th.C_pe = tms_n.k_pe*P.th.C_pe;
P.th.P_fan_pe = tms_n.k_pe*P.th.P_fan_pe;
% Pumps (Rev E basis, 350 W SPAL and 60 W MTM internal pumps via DCC65M24 93 %): one more SPAL per added radiator
% bank and per 2 added MTMs, 60 W per added MTM.
n_spal = (tms_n.k_cd - 1) + (tms_n.k_pe - 1) + ceil(max(tms_n.n_mtm - n_mtm0, 0)/2);
P.th.P_pump = P.th.P_pump + (n_spal*350 + (tms_n.n_mtm - n_mtm0)*60)/0.93;
P.sys.tms = tms_n;

% ---------------- Vehicle ----------------
P.veh.m_loco = loco_lb*0.453592;
P.veh.m_tot = P.veh.m_loco + P.veh.m_trail;
P.veh.m_eff = P.veh.k_rot_loco*P.veh.m_loco + P.veh.k_rot_trail*P.veh.m_trail;
P.lcc.Kp_v = 2*P.sys.zeta_v*P.sys.wn_v*P.veh.m_eff;
P.lcc.Ki_v = P.sys.wn_v^2*P.veh.m_eff;

% ---------------- Charging ----------------
P.chg.P_max = chg_kW*1e3;
P.sys = rmfield(P.sys, {'demo_chg_P_max_W', 'demo_chg_I_wire_max_A'});   % Jacksonville DR-17 demo limit: GP40 only

% ---------------- Identity ----------------
P.sys.model = 'CEMEX';
P.sys.model_rev = 'CEMEX-A';
P.sys.model_rev_date = '2026-10-28';
P.sys.base_rev = 'GP40 proto RevE';
P.sys.n_axles = 6;
P.sys.cemex = struct('n_str', n_str, 'E_nom_kWh', soh*E_bol_kWh, 'E_bol_kWh', E_bol_kWh, 'soh', soh, 'r_age', r_age, 'chg_c_rate', chg_c_rate, 'dis_c_rate', dis_c_rate, 'I_dis_max_A', P.lcc.I_dis_max, ...
    'loco_lb', loco_lb, 'motor_cap_kW', motor_cap_kW, 'P_trac_max_MW', P.lcc.P_trac_max/1e6, 'mu_adh', mu_adh, ...
    'regen', logical(regen), 'chg_P_max_kW', chg_kW, 'wheel_in', wheel_in);
end

function [v, s] = take(s, name, default)
v = default;
if isfield(s, name)
    if ~isempty(s.(name)), v = s.(name); end
    s = rmfield(s, name);
end
end
