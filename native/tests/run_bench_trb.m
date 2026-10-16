addpath(genpath(fullfile(pwd,'native')));
native_params;
P = evalin('base','P');
mdl = 'bench_trb';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

Ip = 0.5*PN.str.Q_Ah*PN.nstr;
t_open = 900; t_end = 1800;
I_pack_bench = [0 0; 10 0; 10 Ip; t_end Ip];
K_bench = [0 ones(1,6); t_open ones(1,6); t_open 1 1 1 1 1 0; t_end 1 1 1 1 1 0];
assignin('base','I_pack_bench',I_pack_bench);
assignin('base','K_bench',K_bench);
set_param(mdl,'StopTime',num2str(t_end));

out = sim(mdl);
Vo = out.get('V_pack'); Io = out.get('I_pack'); So = out.get('I_str');

dt = 0.1; t = (0:dt:t_end)';
v  = interp1(Vo.Time,squeeze(Vo.Data),t);
ip = interp1(Io.Time,squeeze(Io.Data),t);
is = interp1(So.Time,squeeze(So.Data),t);

[tu,iu] = unique(I_pack_bench(:,1),'last');
Ic = interp1(tu,I_pack_bench(iu,2),t,'previous');
ns = 12*ones(size(t)); ns(t >= t_open) = 10;
Ns = P.batt.Ns;
ocv = @(s) Ns*interp1(P.batt.SOC_tab,P.batt.OCV_tab,min(max(s,0),1));
z = zeros(size(t)); v1 = z; vr = z; z(1) = P.batt.soc0;
for k = 1:numel(t)
    R0t = Ns*P.batt.R0_cell/ns(k) + P.batt.R_bus;
    R1t = Ns*P.batt.R1_cell/ns(k);
    vr(k) = ocv(z(k)) - Ic(k)*R0t - v1(k);
    if k < numel(t)
        z(k+1)  = z(k) - Ic(k)*dt/(ns(k)*P.batt.Q_cell*3600);
        v1(k+1) = v1(k) + dt/P.batt.tau1*(Ic(k)*R1t - v1(k));
    end
end

sign_ok = mean(ip(t>600 & t<890)) > 0 && v(find(t>=890,1)) < v(find(t>=5,1));
mask = abs(t-10) > 2 & abs(t-t_open) > 2;
err = (v - vr)./vr*100;
emax = max(abs(err(mask)));

pre  = mean(is(t>600 & t<890,:),1);
post = mean(is(t>1500 & t<1790,:),1);
exp_pre  = Ip/6*ones(1,6);
exp_post = [Ip/5*ones(1,5) 0];
share_err = max(abs([pre-exp_pre post-exp_post]))/(Ip/6)*100;

fprintf('\n== Bench: 6 strings, 0.5C pack, string 6 opens at %d s ==\n',t_open);
fprintf('Discharge sign correct : %s\n',string(sign_ok));
fprintf('V start  sim %.1f  ref %.1f V\n',v(1),vr(1));
fprintf('V@890s   sim %.1f  ref %.1f V\n',v(find(t>=890,1)),vr(find(t>=890,1)));
fprintf('V@1790s  sim %.1f  ref %.1f V\n',v(find(t>=1790,1)),vr(find(t>=1790,1)));
fprintf('Voltage error max %.3f %%\n',emax);
fprintf('String A before open: %s\n',mat2str(round(pre,1)));
fprintf('String A after open : %s\n',mat2str(round(post,1)));
fprintf('Expected            : %.1f each, then %.1f x5 and 0\n',Ip/6,Ip/5);
fprintf('Current share error max %.2f %%\n',share_err);
if ~sign_ok
    fprintf('RESULT: SIGN WRONG. Swap the two blue wires on Load and rerun.\n');
elseif emax < 1 && share_err < 1
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_trb vs Phase 3');
subplot(3,1,1); plot(t,v,t,vr,'--'); ylabel('V_{pack} (V)'); legend('native','Phase 3 eq'); grid on;
subplot(3,1,2); plot(t,is); ylabel('I_{string} (A)'); legend('S1','S2','S3','S4','S5','S6'); grid on;
subplot(3,1,3); plot(t,err); ylabel('error (%)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_trb_compare.png'));