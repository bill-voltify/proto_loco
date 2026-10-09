function run_bench_thermal_plant
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
P = evalin('base','P'); TH = P.th;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

u = [40e3 1000 0 100e3 1 313.15 4 1 1 1 1 1 30e3 10e3 0]';
mdl = 'bench_thermal_plant';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
add_block([lib '/Thermal Plant'],[mdl '/TP'],'Position',[300 50 420 600]);
add_block('simulink/Sources/Constant',[mdl '/U'],'Position',[40 300 100 330],'Value',mat2str(u));
add_block('simulink/Signal Routing/Demux',[mdl '/Du'],'Position',[150 50 155 600],'Outputs','15');
add_line(mdl,'U/1','Du/1');
for k = 1:15, add_line(mdl,sprintf('Du/%d',k),sprintf('TP/%d',k),'autorouting','on'); end
names = {'Tc','Tb','Tcd','Tpe','Tm','Tcs','Tsup','Tchg','Tchop','Tinv','Qpe'};
for k = 1:11
    add_block('simulink/Sinks/To Workspace',[mdl '/log_' names{k}],'Position',[500 30+50*k 560 60+50*k], ...
        'VariableName',names{k},'SaveFormat','Timeseries');
    add_line(mdl,sprintf('TP/%d',k),['log_' names{k} '/1'],'autorouting','on');
end
t_end = 3600;
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime',num2str(t_end),'MaxStep','5');
save_system(mdl,f);
out = sim(mdl,'ReturnWorkspaceOutputs','on');

Qb = u(1); ia = u(2); p_aux = u(4); en = u(5); Ta = u(6); nax = u(7);
Qc = u(13); Pc = u(14); Qh = u(15);
Qpe = nax*(TH.a_loss*abs(ia) + TH.b_loss*ia^2) + TH.k_aux_pe*p_aux + TH.Q_pe_idle*en;
dt = 0.05; t = (0:dt:t_end)'; n = numel(t);
X = zeros(n,5); x = [TH.T0_bat TH.T0_bat TH.T_amb TH.T_amb TH.T_amb];
for k = 1:n
    X(k,:) = x;
    Tc = x(1); Tb = x(2); Tcd = x(3); Tpe = x(4); Tm = x(5);
    dTc  = (Qb - TH.UA_bc*(Tc - Tb) - TH.UA_benv*(Tc - Ta))/TH.C_bat;
    dTb  = (TH.UA_bc*(Tc - Tb) - Qc + Qh)/TH.C_bc;
    dTcd = (Qc + Pc - TH.UA_cd*(Tcd - Ta))/TH.C_cd;
    dTpe = (Qpe - TH.UA_pe*(Tpe - Ta))/TH.C_pe;
    dTm  = (TH.R_m*ia^2 - TH.UA_mot*(Tm - Ta))/TH.C_mot;
    x = x + dt*[dTc dTb dTcd dTpe dTm];
end
Tcs_r = X(:,3) - TH.UA_cd*(X(:,3) - Ta)/TH.mcp_cd;
Tsup_r = X(:,4) - TH.UA_pe*(X(:,4) - Ta)/TH.mcp_pe;

fprintf('\n== Bench: Thermal Plant (40 C ambient, fixed chiller 30 kW) vs Phase 3 thermal.ssc ==\n');
lab = {'Tc cells','Tb coolant','Tcd condenser','Tpe PE loop','Tm motor'};
emax = 0;
for k = 1:5
    ts = out.get(names{k});
    tn = interp1(ts.Time,squeeze(ts.Data),t);
    e = max(abs(tn - X(:,k)));
    emax = max(emax,e);
    fprintf('%-14s  end native %6.2f C  ref %6.2f C   max err %.3f K\n',lab{k},tn(end)-273.15,X(end,k)-273.15,e);
end
ts = out.get('Tcs');  e1 = max(abs(interp1(ts.Time,squeeze(ts.Data),t) - Tcs_r));
ts = out.get('Tsup'); e2 = max(abs(interp1(ts.Time,squeeze(ts.Data),t) - Tsup_r));
fprintf('Tcs max err %.3f K   Tsup max err %.3f K\n',e1,e2);
emax = max([emax e1 e2]);
if emax < 0.05
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end
end