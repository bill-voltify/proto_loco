function P = proto_loco_params(opts)
% PROTO_LOCO_PARAMS  Single parameter source for the proto_loco Simscape model.
%   P = proto_loco_params()          defaults (25 C ambient, no trailing load)
%   P = proto_loco_params(opts)      overrides, fields (all optional):
%       T_amb_C   ambient temperature, C                    (25)
%       T0_C      initial cell/coolant temperature, C       (= T_amb_C, soaked)
%       m_trail   trailing mass, kg                         (0)
%       soc0      initial SOC                               (0.9)
%       I_chg_bms BMS charge-current limit, A               (1884 = 0.5C)
%       bms       'jinko' (as-shipped thresholds) or 'cell_spec'
if nargin < 1, opts = struct(); end
o = struct('T_amb_C', 25, 'T0_C', [], 'm_trail', 0, 'soc0', 0.9, 'I_chg_bms', 1884, 'bms', 'jinko');
f = fieldnames(opts);
for k = 1:numel(f), o.(f{k}) = opts.(f{k}); end
if isempty(o.T0_C), o.T0_C = o.T_amb_C; end

P.batt.Ns = 416;
P.batt.Np = 12;
P.batt.Q_cell = 314;
P.batt.R0_cell = 0.13e-3;
P.batt.R1_cell = 0.062e-3;
P.batt.tau1 = 30;
P.batt.R_bus = 1.0e-3;
P.batt.B_R = 2257;
P.batt.T_ref = 298.15;
P.batt.soc0 = o.soc0;
P.batt.SOC_tab = [0 0.05 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 0.95 1];
P.batt.OCV_tab = [2.90 3.10 3.18 3.22 3.25 3.27 3.29 3.30 3.31 3.33 3.35 3.40 3.55];

P.dcl.R_pre = 4;
P.dcl.C_link = 0.02;
P.dcl.k_close = 0.99;

P.ax.G = 62/15;
P.ax.r_w = 20*0.0254;
P.ax.eta_g = 0.97;
P.ax.R_m = 0.035;
P.ax.L_a = 10e-3;
P.ax.Kphi_sat = 9.0;
P.ax.I0 = 600;
P.ax.If_min = 50;
P.ax.I_max = 1500;
P.ax.V_mot_max = 750;
P.ax.P_ax_max = 655e3;
P.ax.Kp_i = 2;
P.ax.a_loss = 2.5;
P.ax.b_loss = 2.38e-3;
P.ax.I_tab = 0:50:1800;
P.ax.T_tab = P.ax.Kphi_sat*(1 - exp(-max(P.ax.I_tab, P.ax.If_min)/P.ax.I0)).*P.ax.I_tab;

P.veh.m_loco = 270000*0.453592;
P.veh.m_trail = o.m_trail;
P.veh.k_rot_loco = 1.08;
P.veh.k_rot_trail = 1.03;
P.veh.m_tot = P.veh.m_loco + P.veh.m_trail;
P.veh.m_eff = P.veh.k_rot_loco*P.veh.m_loco + P.veh.k_rot_trail*P.veh.m_trail;
P.veh.Crr = 0.002;
P.veh.CdA = 8;

P.aux.eta = 0.96;
P.aux.P_max = 250e3;

P.chg.P_max = 3.3e6;
P.chg.I_hw = 2500;
P.chg.I_bms = o.I_chg_bms;
P.chg.soc_max = 0.95;
P.chg.soc_band = 0.02;

P.lcc.mu_adh = 0.25;
P.lcc.P_trac_max = 4*536e3;
P.lcc.I_dis_max = 1884;
P.lcc.I_chg_max = 1884;
P.lcc.eta_drv = 0.88;
wn = 0.2; zeta = 0.8;
P.lcc.Kp_v = 2*zeta*wn*P.veh.m_eff;
P.lcc.Ki_v = wn^2*P.veh.m_eff;

switch lower(o.bms)
    case 'jinko'
        b = struct('T_hot_L1', 45, 'T_hot_L2', 50, 'T_cchg_L1', 5, 'T_cchg_L2', 3, 'T_cdis_L1', 5, 'T_cdis_L2', 3);
    case 'cell_spec'
        b = struct('T_hot_L1', 45, 'T_hot_L2', 50, 'T_cchg_L1', 5, 'T_cchg_L2', 0, 'T_cdis_L1', -10, 'T_cdis_L2', -20);
    otherwise
        error('Unknown bms profile %s', o.bms);
end
P.bms = b;
P.bms.profile = o.bms;
P.th.T_amb = o.T_amb_C + 273.15;
P.th.T0_bat = o.T0_C + 273.15;
P.th.C_bat = 3.01e7;
P.th.UA_bc = 5000;
P.th.UA_benv = 300;
P.th.C_bc = 1.28e6;
P.th.N_mtm = 4;
P.th.Q_mtm = 12.5e3;
P.th.T_cs_ref = 50 + 273.15;
P.th.k_cap = 0.02;
P.th.T_cs_cut = 65 + 273.15;
P.th.dT_cut = 5;
P.th.COP_ref = 3.0;
P.th.k_cop = 0.05;
P.th.COP_min = 1.2;
P.th.Kp_chill = 20e3;
P.th.T_cool_set = 22 + 273.15;
P.th.T_cool_on = 28 + 273.15;
P.th.T_cool_off = 26.5 + 273.15;
P.th.Q_heat_max = 24e3;
P.th.T_heat_on = 12 + 273.15;
P.th.T_heat_off = 13.5 + 273.15;
P.th.C_cd = 2.2e5;
P.th.UA_cd = 2810;
P.th.mcp_cd = 5880;
P.th.C_pe = 5e5;
P.th.UA_pe = 2834;
P.th.mcp_pe = 13300;
P.th.mcp_chg = 3600;
P.th.mcp_chop = 1430;
P.th.mcp_inv = 950;
P.th.N_ax = 4;
P.th.a_loss = 2.5;
P.th.b_loss = 2.38e-3;
P.th.eta_chg = 0.9934;
P.th.k_aux_pe = 0.08;
P.th.k_inv = 0.02;
P.th.Q_pe_idle = 1500;
P.th.R_m = 0.035;
P.th.C_mot = 1.5e6;
P.th.UA_mot = 276;
P.th.P_fan_cd = 7e3;
P.th.P_fan_pe = 7e3;
P.th.P_pump = 1.5e3;
P.th.T_fan_on = 35 + 273.15;
P.th.dT_fan = 10;
P.th.tau_m = 5;
P.th.T_hot_L1 = b.T_hot_L1 + 273.15;
P.th.T_hot_L2 = b.T_hot_L2 + 273.15;
P.th.T_cchg_L1 = b.T_cchg_L1 + 273.15;
P.th.T_cchg_L2 = b.T_cchg_L2 + 273.15;
P.th.T_cdis_L1 = b.T_cdis_L1 + 273.15;
P.th.T_cdis_L2 = b.T_cdis_L2 + 273.15;
P.th.a_loss = P.ax.a_loss;
P.th.b_loss = P.ax.b_loss;
P.th.R_m = P.ax.R_m;

P.lim.Tcell_opt = [15 35];
P.lim.Tcell_L1 = [b.T_cdis_L1 b.T_hot_L1];
P.lim.T_chg_sup = 55;
P.lim.T_chop_out = 63;
P.lim.T_inv_out = 60;
P.lim.T_check_valve = 65;
P.lim.T_motor = 180;
P.lim.margin_opt = 3;
P.opts = o;
end
