needP = ~evalin('base','exist(''P'',''var'')');
if ~needP
    needP = ~isstruct(evalin('base','P')) || ~isfield(evalin('base','P'),'batt');
end
if needP
    fprintf('P missing or overwritten: rebuilding with build_loco_system...\n');
    evalin('base','build_loco_system;');
end
P = evalin('base','P');

PN = struct();
PN.nstr = 6;
PN.str.Ns = P.batt.Ns;
PN.str.Np = P.batt.Np/PN.nstr;
PN.str.Q_Ah = P.batt.Q_cell*PN.str.Np;
PN.str.soc0 = P.batt.soc0;

PN.SOC = P.batt.SOC_tab(:)';
PN.T = [233.15 253.15 273.15 298.15 318.15 333.15];
fT = exp(P.batt.B_R*(1./PN.T - 1/P.batt.T_ref));
nS = numel(PN.SOC); nT = numel(PN.T);

PN.str.V0   = repmat(PN.str.Ns*P.batt.OCV_tab(:),1,nT);
PN.str.R0   = repmat(PN.str.Ns*P.batt.R0_cell/PN.str.Np*fT,nS,1);
PN.str.R1   = repmat(PN.str.Ns*P.batt.R1_cell/PN.str.Np*fT,nS,1);
PN.str.tau1 = P.batt.tau1*ones(nS,nT);
PN.str.AH   = PN.str.Q_Ah*ones(1,nT);

PN.bus.R = P.batt.R_bus;

PN.dcl.R_pre   = P.dcl.R_pre;
PN.dcl.C       = P.dcl.C_link;
PN.dcl.k_close = P.dcl.k_close;
PN.dcl.R_on    = 0.5e-3;
PN.dcl.R_pre_k = 0.1e-3;
PN.dcl.V_guard = 100;

PN.ax.G         = P.ax.G;
PN.ax.r_w       = P.ax.r_w;
PN.ax.eta_g     = P.ax.eta_g;
PN.ax.R_m       = P.ax.R_m;
PN.ax.L_a       = P.ax.L_a;
PN.ax.Kphi_sat  = P.ax.Kphi_sat;
PN.ax.I0        = P.ax.I0;
PN.ax.If_min    = P.ax.If_min;
PN.ax.I_max     = P.ax.I_max;
PN.ax.V_mot_max = P.ax.V_mot_max;
PN.ax.P_ax_max  = P.ax.P_ax_max;
PN.ax.Kp_i      = P.ax.Kp_i;
PN.ax.a_loss    = P.ax.a_loss;
PN.ax.b_loss    = P.ax.b_loss;
PN.ax.I_tab     = P.ax.I_tab;
PN.ax.T_tab     = P.ax.T_tab;
PN.ax.D_max     = 0.95;
PN.ax.w_floor   = 5;
PN.ax.V_floor   = 100;
PN.ax.Ts_fw     = 1e-4;
PN.ax.i_k       = linspace(-2500,2500,401);
PN.ax.kphi_k    = PN.ax.Kphi_sat*(1 - exp(-max(abs(PN.ax.i_k),PN.ax.If_min)/PN.ax.I0));

if evalin('base','exist(''trail_kg'',''var'')')
    trail = evalin('base','trail_kg');
else
    trail = P.veh.m_trail;
end
PN.veh.m_loco      = P.veh.m_loco;
PN.veh.m_trail     = max(trail,0);
PN.veh.k_rot_loco  = P.veh.k_rot_loco;
PN.veh.k_rot_trail = P.veh.k_rot_trail;
PN.veh.m_tot       = PN.veh.m_loco + PN.veh.m_trail;
PN.veh.m_eff       = PN.veh.k_rot_loco*PN.veh.m_loco + PN.veh.k_rot_trail*PN.veh.m_trail;
PN.veh.Crr         = P.veh.Crr;
PN.veh.CdA         = P.veh.CdA;
PN.veh.rho         = 1.225;
PN.veh.g           = 9.81;
PN.veh.v_eps       = 0.1;
PN.veh.F_roll      = PN.veh.Crr*PN.veh.m_tot*PN.veh.g;
PN.veh.k_aero      = 0.5*PN.veh.rho*PN.veh.CdA;
PN.veh.K_grade     = PN.veh.m_tot*PN.veh.g/100;
PN.veh.tanh_x      = linspace(-1,1,201);
PN.veh.tanh_f      = tanh(PN.veh.tanh_x/PN.veh.v_eps);
PN.veh.v0          = 0;

PN.lcc.m_loco      = P.veh.m_loco;
PN.lcc.k_rot_loco  = P.veh.k_rot_loco;
PN.lcc.k_rot_trail = P.veh.k_rot_trail;
PN.lcc.wn          = P.sys.wn_v;
PN.lcc.zeta        = P.sys.zeta_v;
PN.lcc.N_ax        = 4;
PN.lcc.N_str_nom   = P.batt.Np;
PN.lcc.mu_adh      = P.lcc.mu_adh;
PN.lcc.P_trac_max  = P.lcc.P_trac_max;
PN.lcc.I_dis_max   = P.lcc.I_dis_max;
PN.lcc.I_chg_max   = P.lcc.I_chg_max;
PN.lcc.eta_drv     = P.lcc.eta_drv;
PN.lcc.v_floor     = 0.5;
PN.lcc.v_blend     = 1.5;
PN.lcc.mu_park     = 0.1;
PN.lcc.v_rb        = 0.1;
PN.lcc.T_aw        = 2;
PN.lcc.g           = 9.81;
PN.lcc.Ts          = 0.01;

I1C = PN.str.Q_Ah;
PN.bench.I = [0 0; 10 0; 10 I1C; 1810 I1C; 1810 0; 2400 0; 2400 -0.5*I1C; 3000 -0.5*I1C];

assignin('base','PN',PN);
assignin('base','I_bench',PN.bench.I);

ocv0 = interp1(PN.SOC,PN.str.V0(:,4),PN.str.soc0);
kphi1500 = interp1(PN.ax.i_k,PN.ax.kphi_k,1500);
fprintf('\n== Native params ==\n');
fprintf('String: Ns=%d  Np=%g  Q=%g Ah  soc0=%g\n',PN.str.Ns,PN.str.Np,PN.str.Q_Ah,PN.str.soc0);
fprintf('String: OCV@soc0=%.1f V  R0=%.2f mOhm  R1=%.2f mOhm\n',ocv0,PN.str.R0(1,4)*1e3,PN.str.R1(1,4)*1e3);
fprintf('DC-link: R_pre=%g Ohm  C=%g F  k_close=%g\n',PN.dcl.R_pre,PN.dcl.C,PN.dcl.k_close);
fprintf('Axle: G=%.4f  r_w=%.3f m  R_m=%g Ohm  L_a=%g H\n',PN.ax.G,PN.ax.r_w,PN.ax.R_m,PN.ax.L_a);
fprintf('Axle: kphi@1500A=%.2f V*s/rad  FW Ts=%g s\n',kphi1500,PN.ax.Ts_fw);
fprintf('Vehicle: m_loco=%.0f t  m_trail=%.0f t  m_eff=%.0f t\n',PN.veh.m_loco/1e3,PN.veh.m_trail/1e3,PN.veh.m_eff/1e3);
fprintf('LCC: wn=%g  zeta=%g  mu_adh=%g  Ts=%g s\n',PN.lcc.wn,PN.lcc.zeta,PN.lcc.mu_adh,PN.lcc.Ts);