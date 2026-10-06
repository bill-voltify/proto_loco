function P = proto_loco_params()
P.batt.Ns = 416;
P.batt.Np = 12;
P.batt.Q_cell = 314;
P.batt.R0_cell = 0.5e-3;
P.batt.R1_cell = 0.3e-3;
P.batt.tau1 = 30;
P.batt.R_bus = 5e-3;
P.batt.soc0 = 0.9;
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
P.veh.m_trail = 1500e3;
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
P.chg.eta = 0.97;

P.cool.BTMS_W = 60e3;
P.cool.chop_W = 4*5.25e3;
P.cool.PE_W = NaN;

P.lcc.mu_adh = 0.25;
P.lcc.P_trac_max = 4*536e3;
P.lcc.I_dis_max = 1884;
P.lcc.I_chg_max = 1884;
P.lcc.eta_drv = 0.88;
wn = 0.2; zeta = 0.8;
P.lcc.Kp_v = 2*zeta*wn*P.veh.m_eff;
P.lcc.Ki_v = wn^2*P.veh.m_eff;
end
