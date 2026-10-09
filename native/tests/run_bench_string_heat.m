function run_bench_string_heat
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
P = evalin('base','P'); PN = evalin('base','PN');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
mdl = 'bench_string_heat';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
el = 'fl_lib/Electrical/';
add_block([lib '/TRB String'],[mdl '/S1'],'Position',[200 100 320 200]);
add_block([el 'Electrical Sources/Controlled Current Source'],[mdl '/Load'],'Position',[450 100 500 180]);
add_block([el 'Electrical Elements/Electrical Reference'],[mdl '/GND'],'Position',[450 300 490 340]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[mdl '/Solver'],'Position',[300 300 360 340]);
add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[mdl '/S2PS_I'],'Position',[560 130 590 150]);
set_param([mdl '/S2PS_I'],'Unit','A');
add_block('simulink/Sources/Constant',[mdl '/I_cmd'],'Position',[620 125 660 155],'Value','PN.str.Q_Ah');
add_block('simulink/Sources/Constant',[mdl '/K1'],'Position',[60 110 90 130],'Value','1');
add_block('simulink/Sources/Constant',[mdl '/Tcell'],'Position',[60 160 120 180],'Value','T_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/log_Q'],'Position',[400 30 460 60],'VariableName','Qh','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/log_I'],'Position',[400 -20 460 10],'VariableName','Is','SaveFormat','Timeseries');
add_line(mdl,'K1/1','S1/1');
add_line(mdl,'Tcell/1','S1/2');
add_line(mdl,'S1/3','log_Q/1');
add_line(mdl,'S1/1','log_I/1');
add_line(mdl,'I_cmd/1','S2PS_I/1');
a = cpp(mdl,'S1'); L = cpp(mdl,'Load'); g = cpp(mdl,'GND'); sv = cpp(mdl,'Solver'); sp = cpp(mdl,'S2PS_I');
pa = get_param([mdl '/S1'],'PortHandles');
add_line(mdl,pa.RConn(1),L(3),'autorouting','on');
add_line(mdl,L(1),g(1),'autorouting','on');
add_line(mdl,pa.RConn(2),g(1),'autorouting','on');
add_line(mdl,sv(1),g(1),'autorouting','on');
add_line(mdl,sp(end),L(2),'autorouting','on');
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','300','MaxStep','1');
save_system(mdl,f);

Tset = [298.15 318.15]; Q = zeros(1,2); I = Q;
for k = 1:2
    assignin('base','T_bench',Tset(k));
    out = sim(mdl,'ReturnWorkspaceOutputs','on');
    q = out.get('Qh'); i = out.get('Is');
    Q(k) = q.Data(end); I(k) = i.Data(end);
end
fT = exp(P.batt.B_R*(1./Tset - 1/P.batt.T_ref));
R = PN.str.R0(1,4) + PN.str.R1(1,4);
Qr = I.^2*R.*fT;
fprintf('\n== Bench: TRB String heat output and temperature feedback ==\n');
for k = 1:2
    fprintf('T_cell %5.1f C   I %6.1f A   Q_heat native %8.0f W   ref %8.0f W   err %.2f %%\n', ...
        Tset(k)-273.15,I(k),Q(k),Qr(k),abs(Q(k)-Qr(k))/Qr(k)*100);
end
fprintf('Heat ratio 45C/25C   native %.3f   ref %.3f\n',Q(2)/Q(1),fT(2)/fT(1));
e = max(abs(Q - Qr)./Qr)*100;
if Q(1) > 0 && e < 1
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end
end

function c = cpp(m,b)
    p = get_param([m '/' b],'PortHandles');
    c = [p.LConn p.RConn];
end