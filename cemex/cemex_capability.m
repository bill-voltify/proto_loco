function [TE, info] = cemex_capability(P, v_mph, varargin)
% CEMEX_CAPABILITY  Tractive / braking effort at the rail vs speed, from the same equations as the plant.
%   [TE, info] = cemex_capability(P, v_mph, 'Mode', 'start', 'Mu', 0.18, 'SOC', 0.2)
% Used for the curves and tables the RFI asks for (D1, C1, C4, C7, D4) without one simulation per point.
% Limits applied (min of):
%   axle.ssc       motor current (Mode: 'start' = I_max, 5 min 1500 A per D77; 'cont' = 1050 A continuous),
%                  armature voltage min(0.95 Vbat, V_mot_max) against back-EMF, motor power cap P_ax_max, gear eta
%   lcc_proxy.ssc  adhesion mu*m_loco*g, battery discharge power I_dis_max*Vbat*eta_drv, traction cap P_trac_max
%   battery.ssc    Vbat = Ns*OCV(SOC) - I*R (25 C resistance)
% Mode 'brake' gives the electric (regen) braking effort: min(adhesion, P_reg/v) with the lcc_proxy fade below
% v_blend; P_reg = min(P_trac_max, I_chg_max*Vbat/eta_drv). Friction makes up the rest (not in this curve).
% v_mph: vector. TE in N (positive). info: Vbat, limiting term per speed.
p = inputParser;
p.addParameter('Mode', 'start');
p.addParameter('Mu', P.lcc.mu_adh);
p.addParameter('SOC', 0.9);
p.parse(varargin{:});
o = p.Results;
g = 9.81;
v = max(v_mph(:)*0.44704, 0);
b = P.batt;
Rpack = b.Ns*(b.R0_cell + b.R1_cell)/b.Np + b.R_bus + b.R_ext_str/b.Np;
OCV = b.Ns*interp1(b.SOC_tab, b.OCV_tab, o.SOC);
ax = P.ax;
N_ax = 4;                                       % modeled axles (each 1.5 D77 motors, see cemex_params)
TE_adh = o.Mu*P.veh.m_loco*g;

switch lower(o.Mode)
    case 'start', I_lim = ax.I_max;
    case 'cont',  I_lim = ax.I_cont;
    case 'brake', I_lim = ax.I_max;
    otherwise, error('Mode must be start, cont or brake');
end
I = linspace(0, I_lim, 400);
kphi = interp1(ax.I_kphi, ax.Kphi_tab, max(I, ax.If_min), 'linear', 'extrap');

TE = zeros(size(v)); lim = strings(size(v)); Vb = zeros(size(v));
for k = 1:numel(v)
    wm = ax.G*v(k)/ax.r_w;
    if strcmpi(o.Mode, 'brake')
        P_reg = min(P.lcc.P_trac_max, P.lcc.I_chg_max*OCV/P.lcc.eta_drv);
        Vb(k) = OCV + P_reg*P.lcc.eta_drv/OCV*Rpack;          % charging raises the terminal voltage
        P_reg = min(P.lcc.P_trac_max, P.lcc.I_chg_max*Vb(k)/P.lcc.eta_drv);
        Tm = min(kphi.*I, ax.P_ax_max/max(wm, 5));
        T_mot = N_ax*ax.G*max(Tm)/ax.eta_g/ax.r_w;
        c = [TE_adh, P_reg/max(v(k), 0.5), T_mot];
        [TE(k), j] = min(c);
        TE(k) = TE(k)*min(v(k)/1.5, 1);
        names = ["adhesion", "battery/regen power", "motor current"];
        lim(k) = names(j);
        continue
    end
    % battery terminal voltage at the drawn power (two fixed-point passes)
    Vb(k) = OCV;
    for it = 1:2
        P_dis = min(P.lcc.P_trac_max, P.lcc.I_dis_max*Vb(k)*P.lcc.eta_drv);
        Vb(k) = OCV - P_dis/P.lcc.eta_drv/Vb(k)*Rpack;
    end
    P_dis = min(P.lcc.P_trac_max, P.lcc.I_dis_max*Vb(k)*P.lcc.eta_drv);
    Vmax = min(0.95*Vb(k), ax.V_mot_max);
    ok = kphi*wm + ax.R_m*I <= Vmax;
    Tcap = ax.P_ax_max/max(wm, 5);
    Tm = min(kphi.*I, Tcap);
    T_mot = N_ax*ax.G*max([Tm(ok), 0])*ax.eta_g/ax.r_w;
    c = [TE_adh, P_dis/max(v(k), 0.5), T_mot];
    [TE(k), j] = min(c);
    names = ["adhesion", "traction power", "motor"];
    if j == 2 && P_dis < P.lcc.P_trac_max - 1, names(2) = "battery current"; end
    if j == 3
        if ~ok(end), names(3) = "motor voltage";
        elseif kphi(end)*I(end) <= Tcap, names(3) = "motor current";
        else, names(3) = "motor power"; end
    end
    lim(k) = names(j);
end
info.Vbat = Vb;
info.limit = lim;
info.TE_adh = TE_adh;
info.R_pack = Rpack;
end
