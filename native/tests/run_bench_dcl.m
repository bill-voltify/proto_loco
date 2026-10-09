addpath(genpath(fullfile(pwd,'native')));
native_params;
P = evalin('base','P');
mdl = 'bench_dcl';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

t_end = 10; t_en = 1; t_tr = 3;
Itr = 0.5*PN.str.Q_Ah*PN.nstr;
assignin('base','I_pack_bench',[0 0; t_end 0]);
assignin('base','K_bench',[0 ones(1,6); t_end ones(1,6)]);
assignin('base','en_bench',[0 0; t_en 0; t_en 1; t_end 1]);
assignin('base','I_trac_bench',[0 0; t_tr 0; t_tr Itr; t_end Itr]);
set_param(mdl,'StopTime',num2str(t_end),'MaxStep','1e-3');

out = sim(mdl);
Vo = out.get('v_link'); Co = out.get('main_closed'); Io = out.get('I_dcl'); Bo = out.get('V_pack');
tn = Io.Time; in_ = squeeze(Io.Data);
tc_n = Co.Time(find(squeeze(Co.Data) > 0.5,1));

Ns = P.batt.Ns;
R0t = Ns*P.batt.R0_cell/P.batt.Np + P.batt.R_bus;
R1t = Ns*P.batt.R1_cell/P.batt.Np;
Q = P.batt.Np*P.batt.Q_cell*3600;
G = griddedInterpolant(P.batt.SOC_tab,Ns*P.batt.OCV_tab);
dt = 1e-5; t = (0:dt:t_end)'; nT = numel(t);
vc_r = zeros(nT,1); is_r = vc_r; cl_r = vc_r;
z = P.batt.soc0; v1 = 0; vc = 0; vp = G(z);
for k = 1:nT
    E = G(z) - v1;
    if t(k) < t_en
        R = 1e6; cl = 0;
    elseif vc >= PN.dcl.k_close*vp && vc > PN.dcl.V_guard
        R = PN.dcl.R_on; cl = 1;
    else
        R = PN.dcl.R_pre; cl = 0;
    end
    is = (E - vc)/(R0t + R);
    vp = E - R0t*is;
    vc_r(k) = vc; is_r(k) = is; cl_r(k) = cl;
    vc = vc + dt*(is - Itr*(t(k) >= t_tr))/PN.dcl.C;
    z  = z - dt*is/Q;
    v1 = v1 + dt/P.batt.tau1*(is*R1t - v1);
end
tc_r = t(find(cl_r > 0.5,1));

pk_n = max(in_(tn > t_en & tn < tc_n - 2e-3));
pk_r = max(is_r(t > t_en & t < tc_r - 2e-3));
sp_n = max(in_(tn > tc_n - 2e-3 & tn < tc_n + 0.05));
sp_r = max(is_r(t > tc_r - 2e-3 & t < tc_r + 0.05));
w = t > 5;
vl_n = interp1(Vo.Time,squeeze(Vo.Data),t(w));
vl_err = max(abs(vl_n - vc_r(w))./vc_r(w))*100;

pass = abs(tc_n - tc_r) < 5e-3 && abs(pk_n - pk_r)/pk_r < 0.02 && vl_err < 1;

fprintf('\n== Bench: DC-link precharge, close, 1884 A traction step ==\n');
fprintf('Main close time   native %.4f s   ref %.4f s   (diff %.1f ms)\n',tc_n,tc_r,(tc_n-tc_r)*1e3);
fprintf('Precharge peak    native %.1f A   ref %.1f A   (spec < 400 A: %s)\n',pk_n,pk_r,string(pk_n < 400));
fprintf('Close spike peak  native %.0f A   ref %.0f A   (info)\n',sp_n,sp_r);
fprintf('V_link @ 9.9 s    native %.1f V   ref %.1f V\n',vl_n(end),vc_r(end));
fprintf('V_link error (5-10 s) max %.3f %%\n',vl_err);
if pass, fprintf('RESULT: PASS\n'); else, fprintf('RESULT: FAIL\n'); end

fig = figure('Name','bench_dcl vs Phase 3');
subplot(3,1,1);
plot(Vo.Time,squeeze(Vo.Data),t,vc_r,'--',Bo.Time,squeeze(Bo.Data),':'); xlim([0.9 1.8]);
ylabel('V'); legend('V_{link} native','V_{link} ref','V_{bus} native','Location','southeast'); grid on;
subplot(3,1,2);
plot(tn,in_,t,is_r,'--'); xlim([0.9 1.8]); ylabel('I_{dcl} (A)'); legend('native','ref'); grid on;
subplot(3,1,3);
plot(tn,in_,t,is_r,'--'); ylabel('I_{dcl} (A)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_dcl_compare.png'));