addpath(genpath(fullfile(pwd,'native')));
assignin('base','trail_kg',1000*907.185);
native_params;
PN.ax.Ts_fw = 1e-3;
assignin('base','PN',PN);
P = evalin('base','P');
mdl = 'bench_loco';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

t_end = 120; t_en = 1; t_gr = 60; gr0 = 0.5;
assignin('base','en_bench',[0 0; t_en 0; t_en 1; t_end 1]);
assignin('base','vref_bench',[0 0; 5 0; 40 5; 80 5; 110 0; t_end 0]);
assignin('base','grade_bench',[0 0; t_gr 0; t_gr gr0; t_end gr0]);
set_param(mdl,'StopTime',num2str(t_end));

tic; out = sim(mdl); tsim = toc;
gv = @(n) out.get(n);
Vn = gv('v'); In = gv('I_pack'); Bn = gv('V_bus'); Tn = gv('TE_ax');

A = PN.ax; V = PN.veh; L = PN.lcc;
Ns = P.batt.Ns;
R0t = Ns*P.batt.R0_cell/P.batt.Np + P.batt.R_bus;
R1t = Ns*P.batt.R1_cell/P.batt.Np;
Qb = P.batt.Np*P.batt.Q_cell*3600;
Gocv = griddedInterpolant(P.batt.SOC_tab,Ns*P.batt.OCV_tab);
GI = griddedInterpolant(A.T_tab,A.I_tab); Tmax = A.T_tab(end);
[tu,iu] = unique([0 5 40 80 110 t_end]); vrv = [0 0 5 5 0 0]; vrv = vrv(iu);

dt = 1e-4; t = (0:dt:t_end)'; nT = numel(t);
v_r = zeros(nT,1); I_r = v_r; Vb_r = v_r; TE_r = v_r;
z = P.batt.soc0; v1 = 0; vc = 0; vp = Gocv(z); closed = false;
ia = 0; vv = 0; xi = 0;
m_tot = V.m_tot; m_eff = V.m_eff;
Kp = 2*L.zeta*L.wn*m_eff; Ki = L.wn^2*m_eff;
TE_adh = L.mu_adh*L.m_loco*L.g; F_park = L.mu_park*m_tot*L.g;
for k = 1:nT
    tk = t(k);
    Eb = Gocv(z) - v1;
    vref = interp1(tu,vrv,tk);
    e = vref - vv;
    TE_raw = Kp*e + xi;
    vabs = max(abs(vv),L.v_floor);
    P_dis = min(L.P_trac_max, L.I_dis_max*Vb_prev(vp)*L.eta_drv);
    TE_mot_lim = min(TE_adh,P_dis/vabs);
    TE_cmd = min(max(TE_raw,-TE_adh),TE_mot_lim);
    TE_reg_lim = min(TE_adh,min(L.P_trac_max,L.I_chg_max*vp/L.eta_drv)/vabs)*min(abs(vv)/L.v_blend,1);
    TE_el = max(TE_cmd,-TE_reg_lim);
    if vref < 0.01
        F_hold = F_park; dxi = -xi;
    else
        F_hold = F_park*min(max(-vv/L.v_rb,0),1); dxi = Ki*e + (TE_cmd - TE_raw)/L.T_aw;
    end
    F_fric = TE_el - TE_cmd + F_hold;
    TE_each = TE_el/4;

    wm = A.G*vv/A.r_w;
    kph = A.Kphi_sat*(1 - exp(-max(abs(ia),A.If_min)/A.I0));
    E = kph*wm;
    Vmax = min(A.D_max*max(vc,0),A.V_mot_max);
    Tlim = A.P_ax_max/max(abs(wm),A.w_floor);
    Tm_ref = min(max(TE_each*A.r_w/A.G,-Tlim),Tlim);
    Iref = min(max(sign(Tm_ref)*GI(min(abs(Tm_ref),Tmax)),-A.I_max),A.I_max);
    Va = min(max(E + A.R_m*ia + A.Kp_i*(Iref - ia),0),Vmax);
    idc = 4*(Va*ia + A.a_loss*abs(ia) + A.b_loss*ia^2)/max(vc,A.V_floor);

    if tk < t_en
        is = (Eb - vc)/(R0t + 1e6); vp = Eb - R0t*is; vc = vc + dt*(is - idc)/PN.dcl.C;
    elseif ~closed && vc >= PN.dcl.k_close*vp && vc > PN.dcl.V_guard
        closed = true;
    end
    if tk >= t_en && ~closed
        is = (Eb - vc)/(R0t + PN.dcl.R_pre); vp = Eb - R0t*is; vc = vc + dt*(is - idc)/PN.dcl.C;
    elseif closed
        is = idc; vp = Eb - R0t*is; vc = vp - PN.dcl.R_on*is;
    end

    Tm = kph*ia;
    eta = A.eta_g + (1/A.eta_g - A.eta_g)*0.5*(1 - tanh(Tm*wm/1e3));
    Fax = A.G*Tm*eta/A.r_w;
    s = tanh(vv/V.v_eps);
    gk = gr0*(tk >= t_gr);
    Fres = m_tot*V.g*(V.Crr*s + gk/100) + V.k_aero*vv*abs(vv) + F_fric*s;

    v_r(k) = vv; I_r(k) = is; Vb_r(k) = vp; TE_r(k) = TE_each;

    ia = ia + dt*(Va - E - A.R_m*ia)/A.L_a;
    vv = vv + dt*(4*Fax - Fres)/m_eff;
    xi = xi + dt*dxi;
    z  = z - dt*is/Qb;
    v1 = v1 + dt/P.batt.tau1*(is*R1t - v1);
end

vn = interp1(Vn.Time,squeeze(Vn.Data),t);
inn = interp1(In.Time,squeeze(In.Data),t);
bn = interp1(Bn.Time,squeeze(Bn.Data),t);
m = ~(t > t_en & t < t_en + 1);
ev = max(abs(vn - v_r));
eI = max(abs(inn(m) - I_r(m)))/max(abs(I_r))*100;
Ah_n = trapz(t,inn)/3600; Ah_r = trapz(t,I_r)/3600;
eS = abs(Ah_n - Ah_r)/max(abs(Ah_r),1e-6)*100;

fprintf('\n== Bench: full locomotive (4 axles, %.0f t trailing) vs Phase 3 ==\n',V.m_trail/1e3);
fprintf('Native sim time %.0f s\n',tsim);
for tq = [20 40 60 80 100 119]
    k = find(t >= tq,1);
    fprintf('t=%3.0f s  v %5.2f / %5.2f m/s   I_pack %6.0f / %6.0f A   V_bus %6.0f / %6.0f V\n',tq,vn(k),v_r(k),inn(k),I_r(k),bn(k),Vb_r(k));
end
fprintf('(native / ref)\n');
fprintf('Peak pack current  native %.0f A   ref %.0f A\n',max(inn(m)),max(I_r));
fprintf('Ah used            native %.2f Ah  ref %.2f Ah\n',Ah_n,Ah_r);
fprintf('Errors: speed max %.3f m/s   pack current max %.2f %% of peak   Ah %.2f %%\n',ev,eI,eS);
if ev < 0.05 && eI < 3 && eS < 1
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_loco vs Phase 3');
subplot(3,1,1); plot(t,vn,t,v_r,'--',tu,vrv,':'); ylabel('v (m/s)'); legend('native','ref','v_{ref}','Location','north'); grid on;
subplot(3,1,2); plot(t,inn,t,I_r,'--'); ylabel('I_{pack} (A)'); grid on;
subplot(3,1,3); plot(Tn.Time,squeeze(Tn.Data)/1e3,t,TE_r/1e3,'--'); ylabel('TE/axle (kN)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_loco_compare.png'));

evalin('base','clear trail_kg');

function y = Vb_prev(vp)
    y = vp;
end