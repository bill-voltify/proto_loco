addpath(genpath(fullfile(pwd,'native')));
native_params;
mdl = 'bench_motor';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

A = PN.ax;
t_end = 20;
tt = (0:0.01:t_end)';
v  = 10*tt/t_end;
It = interp1([0 5 15 20],[0 1500 1500 500],tt);
kph = @(i) A.Kphi_sat*(1 - exp(-max(abs(i),A.If_min)/A.I0));
wm = A.G*v/A.r_w;
Va = A.R_m*It + kph(It).*wm;
assignin('base','Va_bench',[tt Va]);
assignin('base','v_bench',[tt v]);
set_param(mdl,'StopTime',num2str(t_end));

out = sim(mdl);
Io = out.get('i_a'); To = out.get('T_m'); Fo = out.get('F_rail');

dt = 1e-4; t = (0:dt:t_end)';
Vt = interp1(tt,Va,t); wt = A.G*(10*t/t_end)/A.r_w;
i = 0; ir = zeros(size(t));
for k = 1:numel(t)
    ir(k) = i;
    i = i + dt*(Vt(k) - kph(i)*wt(k) - A.R_m*i)/A.L_a;
end
Tr = kph(ir).*ir;
eta = A.eta_g + (1/A.eta_g - A.eta_g)*0.5*(1 - tanh(Tr.*wt/1e3));
Fr = A.G*Tr.*eta/A.r_w;

in_ = interp1(Io.Time,squeeze(Io.Data),t);
Tn  = interp1(To.Time,squeeze(To.Data),t);
Fn  = interp1(Fo.Time,squeeze(Fo.Data),t);
m = t > 1 & ir > 100;
ei = max(abs(in_(m) - ir(m))./ir(m))*100;
eT = max(abs(Tn(m) - Tr(m))./Tr(m))*100;
eF = max(abs(abs(Fn(m)) - Fr(m))./Fr(m))*100;
sgnF = sign(mean(Fn(m)));

fprintf('\n== Bench: D77 motor + gear + wheel vs Phase 3 axle equations ==\n');
fprintf('Peak current      native %.0f A    ref %.0f A\n',max(in_),max(ir));
fprintf('Peak motor torque native %.0f N*m  ref %.0f N*m\n',max(Tn),max(Tr));
fprintf('Rail force @10s   native %.0f N    ref %.0f N   (sign %+d)\n',Fn(find(t>=10,1)),Fr(find(t>=10,1)),sgnF);
fprintf('Error max: current %.3f %%   torque %.3f %%   rail force %.3f %%\n',ei,eT,eF);
if ei < 1 && eT < 1 && eF < 2
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_motor vs Phase 3');
subplot(3,1,1); plot(t,in_,t,ir,'--'); ylabel('i_a (A)'); legend('native','ref'); grid on;
subplot(3,1,2); plot(t,Tn,t,Tr,'--'); ylabel('T_m (N*m)'); grid on;
subplot(3,1,3); plot(t,abs(Fn),t,Fr,'--'); ylabel('|F_{rail}| (N)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_motor_compare.png'));