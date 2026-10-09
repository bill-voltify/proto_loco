addpath(genpath(fullfile(pwd,'native')));
native_params;
P = evalin('base','P');
A = PN.ax;
mdl = 'bench_axle';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

t_end = 20; t_en = 1; t_tr = 3; TE0 = 70e3; v_max = 8;
tt = (0:0.01:t_end)';
vv = v_max*max(tt - t_tr,0)/(t_end - t_tr);
assignin('base','I_pack_bench',[0 0; t_end 0]);
assignin('base','K_bench',[0 ones(1,6); t_end ones(1,6)]);
assignin('base','en_bench',[0 0; t_en 0; t_en 1; t_end 1]);
assignin('base','I_trac_bench',[0 0; t_end 0]);
assignin('base','TE_bench',[0 0; t_tr 0; t_tr TE0; t_end TE0]);
assignin('base','v_bench',[tt vv]);
set_param(mdl,'StopTime',num2str(t_end),'MaxStep','1e-3');

out = sim(mdl);
Io = out.get('i_a'); Vo = out.get('Va'); Do = out.get('i_dc'); Fo = out.get('F_rail');

Ns = P.batt.Ns;
R0t = Ns*P.batt.R0_cell/P.batt.Np + P.batt.R_bus;
R1t = Ns*P.batt.R1_cell/P.batt.Np;
Qb = P.batt.Np*P.batt.Q_cell*3600;
Gocv = griddedInterpolant(P.batt.SOC_tab,Ns*P.batt.OCV_tab);
GI = griddedInterpolant(A.T_tab,A.I_tab);
Tmax = A.T_tab(end);

dt = 2e-5; t = (0:dt:t_end)'; nT = numel(t);
ia_r = zeros(nT,1); va_r = ia_r; idc_r = ia_r;
z = P.batt.soc0; v1 = 0; vc = 0; vp = Gocv(z); ia = 0;
for k = 1:nT
    tk = t(k);
    Eb = Gocv(z) - v1;
    if tk < t_en
        R = 1e6;
    elseif vc >= PN.dcl.k_close*vp && vc > PN.dcl.V_guard
        R = PN.dcl.R_on;
    else
        R = PN.dcl.R_pre;
    end
    vk = v_max*max(tk - t_tr,0)/(t_end - t_tr);
    TE = TE0*(tk >= t_tr);
    wm = A.G*vk/A.r_w;
    kph = A.Kphi_sat*(1 - exp(-max(abs(ia),A.If_min)/A.I0));
    E = kph*wm;
    Vmax = min(A.D_max*max(vc,0),A.V_mot_max);
    Tlim = A.P_ax_max/max(abs(wm),A.w_floor);
    Tm = min(max(TE*A.r_w/A.G,-Tlim),Tlim);
    Iref = sign(Tm)*GI(min(abs(Tm),Tmax));
    Iref = min(max(Iref,-A.I_max),A.I_max);
    Va = min(max(E + A.R_m*ia + A.Kp_i*(Iref - ia),0),Vmax);
    idc = (Va*ia + A.a_loss*abs(ia) + A.b_loss*ia^2)/max(vc,A.V_floor);
    is = (Eb - vc)/(R0t + R);
    vp = Eb - R0t*is;
    ia_r(k) = ia; va_r(k) = Va; idc_r(k) = idc;
    vc = vc + dt*(is - idc)/PN.dcl.C;
    ia = ia + dt*(Va - E - A.R_m*ia)/A.L_a;
    z  = z - dt*is/Qb;
    v1 = v1 + dt/P.batt.tau1*(is*R1t - v1);
end

ian = interp1(Io.Time,squeeze(Io.Data),t);
van = interp1(Vo.Time,squeeze(Vo.Data),t);
idn = interp1(Do.Time,squeeze(Do.Data),t);
m = t > t_tr + 0.5;
e_ia  = max(abs(ian(m) - ia_r(m))./max(abs(ia_r(m)),100))*100;
e_va  = max(abs(van(m) - va_r(m))./max(abs(va_r(m)),50))*100;
e_idc = max(abs(idn(m) - idc_r(m))./max(abs(idc_r(m)),50))*100;
k20 = find(t >= t_end - 0.01,1);

fprintf('\n== Bench: DC-Link + Chopper + FW + D77 + gear + wheel vs Phase 3 ==\n');
fprintf('@ %.0f s   i_a  native %.0f A   ref %.0f A\n',t(k20),ian(k20),ia_r(k20));
fprintf('         Va   native %.0f V   ref %.0f V\n',van(k20),va_r(k20));
fprintf('         i_dc native %.0f A   ref %.0f A\n',idn(k20),idc_r(k20));
Fn = interp1(Fo.Time,squeeze(Fo.Data),t(k20));
fprintf('         |F_rail| native %.1f kN (TE_ref %.0f kN)\n',abs(Fn)/1e3,TE0/1e3);
fprintf('Error max (t > %.1f s): i_a %.3f %%   Va %.3f %%   i_dc %.3f %%\n',t_tr+0.5,e_ia,e_va,e_idc);
if e_ia < 2 && e_va < 2 && e_idc < 2
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_axle vs Phase 3');
subplot(3,1,1); plot(t,ian,t,ia_r,'--'); ylabel('i_a (A)'); legend('native','ref','Location','southeast'); grid on;
subplot(3,1,2); plot(t,van,t,va_r,'--'); ylabel('V_a (V)'); grid on;
subplot(3,1,3); plot(t,idn,t,idc_r,'--'); ylabel('i_{dc} (A)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_axle_compare.png'));