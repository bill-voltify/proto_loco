function fix_string_thermal
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
B.TM  = 'fl_lib/Thermal/Thermal Elements/Thermal Mass';
B.TR  = 'fl_lib/Thermal/Thermal Elements/Thermal Reference';
B.HS  = 'fl_lib/Thermal/Thermal Sources/Controlled Heat Flow Rate Source';
B.TSR = 'fl_lib/Thermal/Thermal Sources/Controlled Temperature Source';
B.HFS = 'fl_lib/Thermal/Thermal Sensors/Heat Flow Rate Sensor';
B.PC  = 'fl_lib/Physical Signals/Sources/PS Constant';
B.P2S = sprintf('nesl_utility/PS-Simulink\nConverter');
B.S2P = sprintf('nesl_utility/Simulink-PS\nConverter');
B.SC  = sprintf('nesl_utility/Solver\nConfiguration');
load_system('fl_lib'); load_system('nesl_utility');

Pm = perms(1:3); names = {'L1','R1','R2'}; rq = [];
ws = warning('off','all');
for i = 1:6
    y = trial(B,Pm(i,:));
    fprintf('heatsensor A=%s B=%s Q=%s -> %s\n',names{Pm(i,1)},names{Pm(i,2)},names{Pm(i,3)},num2str(y));
    if abs(y - 1000) < 1, rq = Pm(i,:); break; end
end
warning(ws);
if isempty(rq), error('Heat Flow Rate Sensor mapping not found'); end
fprintf('Heat Flow Rate Sensor: A=%s  B=%s  Q=%s  (+Q = heat from A to B)\n',names{rq});

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/TRB String'];
c = [s '/Cells'];
if getSimulinkBlockHandle([s '/Q_heat']) > 0
    fprintf('TRB String already has Q_heat. Nothing to do.\n');
    return
end
em = string(enumeration('simscape.enum.thermaleffects'));
j = find(~contains(lower(em),'omit'),1);
set_param(c,'thermal_port',['simscape.enum.thermaleffects.' char(em(j))]);
p = get_param(c,'PortHandles'); cp = [p.LConn p.RConn];
hn = [];
for k = 1:numel(cp)
    if get_param(cp(k),'Line') == -1, hn = cp(k); end
end
if isempty(hn), error('Could not find the new thermal port on Cells.'); end

add_block(B.HFS,[s '/Q_sens'],'Position',[300 340 360 400]);
add_block(B.TSR,[s '/T_src'],'Position',[420 340 480 400]);
add_block(B.TR,[s '/T_ref'],'Position',[440 440 480 480]);
add_block(B.S2P,[s '/S2PS_T'],'Position',[360 440 390 460]);
add_block(B.P2S,[s '/PS2S_Q'],'Position',[300 440 330 460]);
set_param([s '/S2PS_T'],'Unit','K');
set_param([s '/PS2S_Q'],'Unit','W');
add_block('simulink/Sources/In1',[s '/T_cell'],'Position',[20 440 50 460]);
set_param([s '/T_cell'],'Port','2');
add_block('simulink/Sources/Constant',[s '/T_default'],'Position',[100 500 160 520],'Value','298.15');
add_block('simulink/Signal Routing/Switch',[s '/T_pick'],'Position',[200 430 240 490], ...
    'Criteria','u2 > Threshold','Threshold','200');
add_block('simulink/Sinks/Out1',[s '/Q_heat'],'Position',[240 540 270 560]);
set_param([s '/Q_heat'],'Port','3');

add_line(s,'T_cell/1','T_pick/1','autorouting','on');
add_line(s,'T_cell/1','T_pick/2','autorouting','on');
add_line(s,'T_default/1','T_pick/3','autorouting','on');
add_line(s,'T_pick/1','S2PS_T/1','autorouting','on');
add_line(s,'PS2S_Q/1','Q_heat/1','autorouting','on');

q = cpp(s,'Q_sens'); t = cpp(s,'T_src'); r = cpp(s,'T_ref');
a = cpp(s,'S2PS_T'); b = cpp(s,'PS2S_Q');
add_line(s,hn,q(rq(1)),'autorouting','on');
add_line(s,q(rq(2)),t(1),'autorouting','on');
add_line(s,t(3),r(1),'autorouting','on');
add_line(s,a(end),t(2),'autorouting','on');
add_line(s,q(rq(3)),b(1),'autorouting','on');
save_system(lib);
fprintf('TRB String: thermal port on; inputs K_cmd, T_cell; outputs I_str, soc, Q_heat.\n');
end

function c = cpp(s,b)
    p = get_param([s '/' b],'PortHandles');
    c = [p.LConn p.RConn];
end

function y = trial(B,r)
    m = 'tmp_hfs';
    if bdIsLoaded(m), close_system(m,0); end
    new_system(m);
    y = NaN;
    try
        add_block(B.TR,[m '/Ref'],'Position',[100 300 140 340]);
        add_block(B.SC,[m '/Solver'],'Position',[20 300 80 340]);
        add_block(B.TM,[m '/M1'],'Position',[100 100 140 140]);
        set_param([m '/M1'],'mass','1000','sp_heat','1','T_specify','on','T','300','T_unit','K');
        add_block(B.HS,[m '/H'],'Position',[250 180 310 240]);
        add_block(B.PC,[m '/K'],'Position',[180 200 220 220]);
        set_param([m '/K'],'constant','1000','constant_unit','W');
        add_block(B.HFS,[m '/X'],'Position',[250 60 310 120]);
        add_block(B.P2S,[m '/P2S'],'Position',[400 100 430 120]);
        set_param([m '/P2S'],'Unit','W');
        add_block('simulink/Sinks/To Workspace',[m '/Y'],'Position',[480 95 540 125], ...
            'VariableName','y','SaveFormat','Array');
        add_line(m,'P2S/1','Y/1');
        sv = cpp(m,'Solver'); rf = cpp(m,'Ref'); h = cpp(m,'H'); k = cpp(m,'K');
        x = cpp(m,'X'); m1 = cpp(m,'M1'); p2 = cpp(m,'P2S');
        add_line(m,sv(1),rf(1));
        add_line(m,k(1),h(2));
        add_line(m,h(3),rf(1));
        add_line(m,h(1),x(r(1)));
        add_line(m,x(r(2)),m1(1));
        add_line(m,x(r(3)),p2(1));
        set_param(m,'StopTime','1','SolverType','Variable-step','Solver','daessc');
        out = sim(m,'ReturnWorkspaceOutputs','on');
        yy = out.get('y'); y = yy(end);
    catch
    end
    close_system(m,0);
end