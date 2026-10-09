addpath(genpath(fullfile(pwd,'native')));
native_params;
P = evalin('base','P');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

mdl = 'bench_aux';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
add_block([lib '/TRB String'],[mdl '/S1'],'Position',[200 100 320 160]);
add_block([lib '/AUX'],[mdl '/AUX'],'Position',[450 100 570 220]);
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference',[mdl '/GND'],'Position',[300 300 340 340]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[mdl '/Solver'],'Position',[150 300 210 340]);
add_block('simulink/Sources/Constant',[mdl '/K1'],'Position',[60 110 90 130],'Value','1');
add_block('simulink/Sources/From Workspace',[mdl '/P_cmd'],'Position',[300 20 360 50],'VariableName','Paux_bench');
add_block('simulink/Sources/Constant',[mdl '/P2_zero'],'Position',[330 200 360 220],'Value','0');
add_line(mdl,'K1/1','S1/1','autorouting','on');
add_line(mdl,'P_cmd/1','AUX/1','autorouting','on');
add_line(mdl,'P2_zero/1','AUX/2','autorouting','on');
T = {'p_in','AUX/1';'i_in','AUX/2';'vdc','AUX/3';'v750','AUX/4';'I_str','S1/1'};
for k = 1:size(T,1)
    add_block('simulink/Sinks/To Workspace',[mdl '/log_' T{k,1}],'Position',[700 40+50*k 760 70+50*k], ...
        'VariableName',T{k,1},'SaveFormat','Timeseries');
    add_line(mdl,T{k,2},['log_' T{k,1} '/1'],'autorouting','on');
end
a = get_param([mdl '/S1'],'PortHandles');
b = get_param([mdl '/AUX'],'PortHandles');
g = get_param([mdl '/GND'],'PortHandles');
sv = get_param([mdl '/Solver'],'PortHandles'); sv = [sv.LConn sv.RConn];
add_line(mdl,a.RConn(1),b.LConn(1),'autorouting','on');
add_line(mdl,a.RConn(2),b.LConn(2),'autorouting','on');
add_line(mdl,a.RConn(2),g.LConn(1),'autorouting','on');
add_line(mdl,sv(1),g.LConn(1),'autorouting','on');
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','10','MaxStep','1e-2');
save_system(mdl,f);

prof = [0 0; 1 0; 1 100e3; 5 100e3; 5 300e3; 10 300e3];
assignin('base','Paux_bench',prof);
out = sim(mdl);
gv = @(n) squeeze(out.get(n).Data); tv = out.get('p_in').Time;
pin = gv('p_in'); iin = gv('i_in'); vdc = gv('vdc'); v750 = gv('v750');
Is = out.get('I_str'); istr = interp1(Is.Time,squeeze(Is.Data),tv);

[tu,iu] = unique(prof(:,1),'last');
Pc = interp1(tu,prof(iu,2),tv,'previous');
Pr = min(max(Pc,0),P.aux.P_max)/P.aux.eta;

fprintf('\n== Bench: AUX block on one TRB string ==\n');
for tq = [3 8]
    k = find(tv >= tq,1);
    fprintf('t=%g s  P_cmd %6.0f W  p_in %8.0f W (ref %8.0f)  i_in %6.1f A  I_str %6.1f A  vdc %6.1f V  v750 %5.1f V\n', ...
        tq,Pc(k),pin(k),Pr(k),iin(k),istr(k),vdc(k),v750(k));
end
m = tv > 1.05;
e_p = max(abs(pin(m) - Pr(m))./max(Pr(m),1))*100;
e_b = max(abs(iin(m).*vdc(m) - pin(m))./max(pin(m),1))*100;
e_s = max(abs(istr(m) - iin(m))./max(abs(iin(m)),1))*100;
e_v = max(abs(v750 - 750));
sign_ok = mean(istr(m)) > 0;
fprintf('Errors: p_in %.3f %%  power balance %.3f %%  string vs i_in %.3f %%  v750 %.3f V\n',e_p,e_b,e_s,e_v);
fprintf('Battery discharging (sign ok): %s\n',string(sign_ok));
if sign_ok && e_p < 0.5 && e_b < 0.5 && e_s < 0.5 && e_v < 1
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end