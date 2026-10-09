function run_bench_tms
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
P = evalin('base','P'); TH = P.th; f_ram = 0.2;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

u = [40e3 1000 0 100e3 1 313.15 4 1 1 1 1 1]';
cin = {'dT_s','0';'tms_en','1';'n_mtm','4';'en','1';'fan_cd','1';'fan_pe','1'};
mdl = 'bench_tms';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
add_block([lib '/Thermal Plant'],[mdl '/TP'],'Position',[300 50 420 650]);
add_block([lib '/TMS Controller'],[mdl '/TMS'],'Position',[600 400 720 700]);
add_block('simulink/Sources/Constant',[mdl '/U'],'Position',[40 300 100 330],'Value',mat2str(u));
add_block('simulink/Signal Routing/Demux',[mdl '/Du'],'Position',[150 50 155 500],'Outputs','12');
add_line(mdl,'U/1','Du/1');
for k = 1:12, add_line(mdl,sprintf('Du/%d',k),sprintf('TP/%d',k),'autorouting','on'); end
add_line(mdl,'TMS/1','TP/13','autorouting','on');
add_line(mdl,'TMS/2','TP/14','autorouting','on');
add_line(mdl,'TMS/3','TP/15','autorouting','on');
add_line(mdl,'TP/1','TMS/1','autorouting','on');
add_line(mdl,'TP/6','TMS/2','autorouting','on');
add_line(mdl,'TP/4','TMS/3','autorouting','on');
for k = 1:6
    add_block('simulink/Sources/Constant',[mdl '/c_' cin{k,1}],'Position',[480 500+40*k 520 520+40*k],'Value',cin{k,2});
    add_line(mdl,['c_' cin{k,1} '/1'],sprintf('TMS/%d',k+3),'autorouting','on');
end
lg = {'Tc','TP/1';'Tb','TP/2';'Tcd','TP/3';'Tpe','TP/4';'Tm','TP/5';'Ptms','TMS/4';'mc','TMS/7';'Qc','TMS/1'};
for k = 1:size(lg,1)
    add_block('simulink/Sinks/To Workspace',[mdl '/log_' lg{k,1}],'Position',[800 30+50*k 860 60+50*k], ...
        'VariableName',lg{k,1},'SaveFormat','Timeseries');
    add_line(mdl,lg{k,2},['log_' lg{k,1} '/1'],'autorouting','on');
end
t_end = 7200;
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime',num2str(t_end),'MaxStep','1');
save_system(mdl,f);
out = sim(mdl,'ReturnWorkspaceOutputs','on');

Qb = u(1); ia = u(2); p_aux = u(4); en = 1; Ta = u(6); nax = u(7);
Qpe = nax*(TH.a_loss*abs(ia) + TH.b_loss*ia^2) + TH.k_aux_pe*p_aux + TH.Q_pe_idle*en;
dt = 0.05; t = (0:dt:t_end)'; n = numel(t);
X = zeros(n,5); Pt = zeros(n,1); MC = Pt;
x = [TH.T0_bat TH.T0_bat TH.T_amb TH.T_amb TH.T_amb]; mc = 0; mh = 0;
for k = 1:n
    Tc = x(1); Tb = x(2); Tcd = x(3); Tpe = x(4); Tm = x(5);
    Tcs = Tcd - TH.UA_cd*(Tcd - Ta)/TH.mcp_cd;
    f1 = min(max(1 - TH.k_cap*(Tcs - TH.T_cs_ref),0),1.2);
    f2 = min(max((TH.T_cs_cut - Tcs)/TH.dT_cut,0),1);
    Qc_av = TH.N_mtm*TH.Q_mtm*f1*f2;
    Qc = mc*min(max(TH.Kp_chill*(Tc - TH.T_cool_set),0),Qc_av);
    COP = max(TH.COP_min, TH.COP_ref - TH.k_cop*(Tcs - TH.T_cs_ref));
    Pc = Qc/COP;
    Qh = mh*TH.Q_heat_max;
    f_pe = min(max((Tpe - TH.T_fan_on)/TH.dT_fan,0.1),1);
    Pt(k) = Pc + Qh + TH.P_pump + TH.P_fan_cd*mc + TH.P_fan_pe*f_pe;
    MC(k) = mc;
    X(k,:) = x;
    tc = double(Tc >= TH.T_cool_on || (mc > 0.5 && Tc > TH.T_cool_off));
    th = double(Tc <= TH.T_heat_on || (mh > 0.5 && Tc < TH.T_heat_off));
    dTc  = (Qb - TH.UA_bc*(Tc - Tb) - TH.UA_benv*(Tc - Ta))/TH.C_bat;
    dTb  = (TH.UA_bc*(Tc - Tb) - Qc + Qh)/TH.C_bc;
    dTcd = (Qc + Pc - TH.UA_cd*(Tcd - Ta))/TH.C_cd;
    dTpe = (Qpe - TH.UA_pe*(Tpe - Ta))/TH.C_pe;
    dTm  = (TH.R_m*ia^2 - TH.UA_mot*(Tm - Ta))/TH.C_mot;
    x = x + dt*[dTc dTb dTcd dTpe dTm];
    mc = mc + dt/TH.tau_m*(tc - mc);
    mh = mh + dt/TH.tau_m*(th - mh);
end

fprintf('\n== Bench: Thermal Plant + TMS Controller, 40 C hot day, 2 h ==\n');
names = {'Tc','Tb','Tcd','Tpe','Tm'};
lab = {'Tc cells','Tb coolant','Tcd condenser','Tpe PE loop','Tm motor'};
emax = 0;
for k = 1:5
    ts = out.get(names{k});
    tn = interp1(ts.Time,squeeze(ts.Data),t);
    e = max(abs(tn - X(:,k)));
    emax = max(emax,e);
    fprintf('%-14s  end native %6.2f C  ref %6.2f C   max err %.3f K\n',lab{k},tn(end)-273.15,X(end,k)-273.15,e);
end
ts = out.get('Ptms'); pn = interp1(ts.Time,squeeze(ts.Data),t);
ts = out.get('mc');   mn = interp1(ts.Time,squeeze(ts.Data),t);
En = trapz(t,pn)/3.6e6; Er = trapz(t,Pt)/3.6e6;
on_n = mean(mn > 0.5)*100; on_r = mean(MC > 0.5)*100;
cyc_n = sum(diff(mn > 0.5) == 1); cyc_r = sum(diff(MC > 0.5) == 1);
eE = abs(En - Er)/Er*100;
fprintf('TMS energy   native %.2f kWh   ref %.2f kWh   (err %.2f %%)\n',En,Er,eE);
fprintf('Chiller on   native %.1f %%   ref %.1f %%   cycles native %d  ref %d\n',on_n,on_r,cyc_n,cyc_r);
if emax < 0.2 && eE < 1 && abs(on_n - on_r) < 1
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_tms vs Phase 3');
subplot(3,1,1); ts = out.get('Tc'); plot(ts.Time/60,squeeze(ts.Data)-273.15,t/60,X(:,1)-273.15,'--');
ylabel('T_{cells} (C)'); legend('native','ref'); grid on;
yline([TH.T_cool_on TH.T_cool_off]-273.15,':',{'chiller on','chiller off'});
subplot(3,1,2); plot(t/60,mn,t/60,MC,'--'); ylabel('chiller mode'); grid on;
subplot(3,1,3); plot(t/60,pn/1e3,t/60,Pt/1e3,'--'); ylabel('P_{tms} (kW)'); xlabel('t (min)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_tms_compare.png'));
end