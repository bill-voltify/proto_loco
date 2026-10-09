function disc_thermal_ports
B.TM  = 'fl_lib/Thermal/Thermal Elements/Thermal Mass';
B.TR  = 'fl_lib/Thermal/Thermal Elements/Thermal Reference';
B.TS  = 'fl_lib/Thermal/Thermal Sensors/Temperature Sensor';
B.HS  = 'fl_lib/Thermal/Thermal Sources/Controlled Heat Flow Rate Source';
B.TSR = 'fl_lib/Thermal/Thermal Sources/Controlled Temperature Source';
B.CV  = 'fl_lib/Thermal/Thermal Elements/Convective Heat Transfer';
B.PC  = 'fl_lib/Physical Signals/Sources/PS Constant';
B.P2S = sprintf('nesl_utility/PS-Simulink\nConverter');
B.SC  = sprintf('nesl_utility/Solver\nConfiguration');
load_system('fl_lib'); load_system('nesl_utility');
Pm = perms(1:3);
names = {'L1','R1','R2'};
map = struct();
ws = warning('off','all');

for i = 1:6
    y = trial(B,'sensor',Pm(i,:),[]);
    fprintf('sensor  A=%s B=%s T=%s -> %s\n',names{Pm(i,1)},names{Pm(i,2)},names{Pm(i,3)},num2str(y));
    if abs(y - 350) < 0.5, map.sensor = Pm(i,:); break; end
end
if ~isfield(map,'sensor'), warning(ws); error('Temperature Sensor mapping not found'); end

for i = 1:6
    y = trial(B,'heat',Pm(i,:),map.sensor);
    fprintf('heat    S=%s A=%s B=%s -> %s\n',names{Pm(i,1)},names{Pm(i,2)},names{Pm(i,3)},num2str(y));
    if abs(y - 310) < 0.5, map.heat = Pm(i,:); break; end
end
if ~isfield(map,'heat'), warning(ws); error('Heat Flow Source mapping not found'); end

for i = 1:6
    y = trial(B,'temp',Pm(i,:),map.sensor);
    fprintf('tempsrc S=%s A=%s B=%s -> %s\n',names{Pm(i,1)},names{Pm(i,2)},names{Pm(i,3)},num2str(y));
    if abs(y - 350) < 0.5, map.temp = Pm(i,:); break; end
end
if ~isfield(map,'temp'), warning(ws); error('Temperature Source mapping not found'); end

for i = 1:6
    y = trial(B,'conv',Pm(i,:),map.sensor);
    fprintf('conv    A=%s B=%s H=%s -> %s\n',names{Pm(i,1)},names{Pm(i,2)},names{Pm(i,3)},num2str(y));
    if y > 349.3 && y < 349.7, map.conv = Pm(i,:); break; end
end
warning(ws);
if ~isfield(map,'conv'), error('Variable Convective mapping not found'); end

fprintf('\n== PORT MAP (index into [LConn(1) RConn(1) RConn(2)]) ==\n');
fprintf('Temperature Sensor:      A=%s  B=%s  T=%s\n',names{map.sensor});
fprintf('Ctrl Heat Flow Source:   S=%s  A=%s  B=%s   (+S = heat from A into B)\n',names{map.heat});
fprintf('Ctrl Temperature Source: S=%s  A=%s  B=%s   (T_B = S when A at reference)\n',names{map.temp});
fprintf('Convective (variable):   A=%s  B=%s  H=%s\n',names{map.conv});
assignin('base','TPORTS',map);
end

function y = trial(B,kind,r,sm)
    m = 'tmp_tdisc';
    if bdIsLoaded(m), close_system(m,0); end
    new_system(m);
    y = NaN;
    try
        add_block(B.TR,[m '/Ref'],'Position',[100 300 140 340]);
        add_block(B.SC,[m '/Solver'],'Position',[20 300 80 340]);
        add_block(B.P2S,[m '/P2S'],'Position',[400 100 430 120]);
        add_block('simulink/Sinks/To Workspace',[m '/Y'],'Position',[480 95 540 125], ...
            'VariableName','y','SaveFormat','Array');
        add_line(m,'P2S/1','Y/1');
        set_param([m '/P2S'],'Unit','K');
        cs0 = cp(m,'Solver');
        ln2(m,'Ref',1,cs0(1));
        switch kind
            case 'sensor'
                mass(B,m,'M1',350,1000,[100 100 140 140]);
                add_block(B.TS,[m '/X'],'Position',[250 100 310 160]);
                cx = cp(m,'X');
                ln2(m,'M1',1,cx(r(1)));
                ln2(m,'Ref',1,cx(r(2)));
                ln3(m,cx(r(3)),'P2S');
                stop = '1';
            case 'heat'
                mass(B,m,'M1',300,1000,[100 100 140 140]);
                add_block(B.HS,[m '/X'],'Position',[250 180 310 240]);
                add_block(B.PC,[m '/K'],'Position',[180 200 220 220]);
                set_param([m '/K'],'constant','1000','constant_unit','W');
                cx = cp(m,'X');
                kk = get_param([m '/K'],'PortHandles');
                add_line(m,kk.RConn(1),cx(r(1)));
                ln2(m,'Ref',1,cx(r(2)));
                ln2(m,'M1',1,cx(r(3)));
                sensor(B,m,'M1',sm);
                stop = '10';
            case 'temp'
                mass(B,m,'M1',300,1,[100 100 140 140]);
                add_block(B.TSR,[m '/X'],'Position',[250 180 310 240]);
                add_block(B.PC,[m '/K'],'Position',[180 200 220 220]);
                set_param([m '/K'],'constant','350','constant_unit','K');
                cx = cp(m,'X');
                kk = get_param([m '/K'],'PortHandles');
                add_line(m,kk.RConn(1),cx(r(1)));
                ln2(m,'Ref',1,cx(r(2)));
                ln2(m,'M1',1,cx(r(3)));
                sensor(B,m,'M1',sm);
                stop = '1';
            case 'conv'
                mass(B,m,'M1',350,1000,[100 100 140 140]);
                mass(B,m,'M2',300,1000,[100 180 140 220]);
                add_block(B.CV,[m '/X'],'Position',[250 180 310 240]);
                set_param([m '/X'],'thermal_type','foundation.enum.constant_variable.variable','area','1');
                add_block(B.PC,[m '/K'],'Position',[180 260 220 280]);
                set_param([m '/K'],'constant','10','constant_unit','W/(m^2*K)');
                cx = cp(m,'X');
                kk = get_param([m '/K'],'PortHandles');
                ln2(m,'M1',1,cx(r(1)));
                ln2(m,'M2',1,cx(r(2)));
                add_line(m,kk.RConn(1),cx(r(3)));
                sensor(B,m,'M1',sm);
                stop = '1';
        end
        set_param(m,'StopTime',stop,'SolverType','Variable-step','Solver','daessc');
        out = sim(m,'ReturnWorkspaceOutputs','on');
        yy = out.get('y');
        y = yy(end);
    catch
    end
    close_system(m,0);
end

function mass(B,m,nm,T0,C,pos)
    add_block(B.TM,[m '/' nm],'Position',pos);
    set_param([m '/' nm],'mass',num2str(C),'sp_heat','1','T_specify','on','T',num2str(T0),'T_unit','K');
end

function sensor(B,m,nm,sm)
    add_block(B.TS,[m '/S'],'Position',[250 60 310 120]);
    cs = cp(m,'S');
    ln2(m,nm,1,cs(sm(1)));
    ln2(m,'Ref',1,cs(sm(2)));
    ln3(m,cs(sm(3)),'P2S');
end

function c = cp(m,nm)
    p = get_param([m '/' nm],'PortHandles');
    c = [p.LConn p.RConn];
end

function ln2(m,a,ka,hb)
    pa = get_param([m '/' a],'PortHandles');
    add_line(m,pa.LConn(ka),hb);
end

function ln3(m,ha,b)
    pb = get_param([m '/' b],'PortHandles');
    add_line(m,ha,pb.LConn(1));
end