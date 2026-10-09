function build_lib_native_plant
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');

ax = [lib '/Axle'];
if getSimulinkBlockHandle([ax '/va']) < 0
    add_block('simulink/Sinks/Out1',[ax '/va'],'Position',[420 420 450 440]);
    set_param([ax '/va'],'Port','3');
    add_line(ax,'FW/1','va/1','autorouting','on');
    fprintf('Axle: added output 3 (va).\n');
end

s = [lib '/Native Plant'];
if getSimulinkBlockHandle(s) > 0
    error('Native Plant already exists. Delete it in the library first to rebuild.');
end
add_block('built-in/Subsystem',s,'Position',[1000 400 1120 640]);

in = {'speed_ref_mph','grade_pct','ambient_C','trailing_tons','cmd','faults'};
for k = 1:6
    add_block('simulink/Sources/In1',[s '/' in{k}],'Position',[20 40+60*(k-1) 50 60+60*(k-1)]);
end
fb(s,'plant_inputs',[100 60 260 380]);
setfcn([s '/plant_inputs'],{
 'function u = plant_inputs(speed_ref_mph, grade_pct, ambient_C, trailing_tons, cmd, flt)'
 'u = zeros(18, 1);'
 'u(1) = max(speed_ref_mph, 0);'
 'u(2) = grade_pct;'
 'u(3) = cmd(5);'
 'u(4) = cmd(6);'
 'u(5) = cmd(2);'
 'u(6) = ambient_C + 273.15;'
 'u(7) = max(trailing_tons, 0)*907.185;'
 'u(8) = cmd(3);'
 'u(9:16) = flt(1:8);'
 'u(17) = flt(9)*flt(11);'
 'u(18) = cmd(4);'
 'end'},{});
add_block('simulink/Signal Routing/Demux',[s '/U'],'Position',[300 40 305 1100],'Outputs','18');
for k = 1:6, add_line(s,[in{k} '/1'],sprintf('plant_inputs/%d',k),'autorouting','on'); end
add_line(s,'plant_inputs/1','U/1','autorouting','on');

el = 'fl_lib/Electrical/';
for k = 1:6
    add_block([lib '/TRB String'],sprintf('%s/S%d',s,k),'Position',[600 60+100*(k-1) 720 140+100*(k-1)]);
end
add_block([el 'Electrical Elements/Resistor'],[s '/R_bus'],'Position',[800 40 860 70],'R','PN.bus.R');
add_block([el 'Electrical Sensors/Current Sensor'],[s '/I_pack_sens'],'Position',[900 30 940 70]);
add_block([el 'Electrical Sensors/Voltage Sensor'],[s '/V_bus_sens'],'Position',[980 120 1020 160]);
add_block([el 'Electrical Elements/Electrical Reference'],[s '/GND'],'Position',[1000 900 1040 940]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[s '/Solver'],'Position',[880 900 940 940]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[s '/PS2S_I'],'Position',[1000 0 1030 20]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[s '/PS2S_V'],'Position',[1060 200 1090 220]);
set_param([s '/PS2S_I'],'Unit','A');
set_param([s '/PS2S_V'],'Unit','V');
add_block([lib '/DC-Link'],[s '/DCL'],'Position',[1100 40 1220 160]);
for k = 1:4
    add_block([lib '/Axle'],sprintf('%s/A%d',s,k),'Position',[1300 40+150*(k-1) 1420 140+150*(k-1)]);
end
add_block([lib '/Vehicle'],[s '/Veh'],'Position',[1550 300 1670 420]);
add_block([lib '/AUX'],[s '/AUX'],'Position',[1100 400 1220 520]);
add_block([lib '/Charger'],[s '/CHG'],'Position',[1100 600 1220 700]);
add_block([lib '/Charger FW'],[s '/CFW'],'Position',[900 600 1020 720]);
add_block([lib '/LCC'],[s '/LCC'],'Position',[1100 1000 1220 1260]);
add_block([lib '/TMS Controller'],[s '/TMS'],'Position',[1400 1000 1520 1300]);
add_block([lib '/Thermal Plant'],[s '/TP'],'Position',[1700 900 1820 1300]);

add_block('simulink/Math Operations/Gain',[s '/mph2ms'],'Position',[400 40 440 60],'Gain','0.44704');
add_block('simulink/Sources/Constant',[s '/idx'],'Position',[400 600 440 620],'Value','(1:6)''');
add_block('simulink/Math Operations/Gain',[s '/half'],'Position',[400 640 440 660],'Gain','0.5');
add_block('simulink/Logic and Bit Operations/Relational Operator',[s '/Kcmp'],'Position',[460 600 490 660],'Operator','<=');
add_block('simulink/Signal Attributes/Data Type Conversion',[s '/Kdbl'],'Position',[500 610 540 640],'OutDataTypeStr','double');
add_block('simulink/Signal Routing/Demux',[s '/Kd'],'Position',[560 60 565 660],'Outputs','6');
add_block('simulink/Discrete/Unit Delay',[s '/T_scan'],'Position',[450 700 480 730],'SampleTime','0.1','InitialCondition','P.th.T0_bat');
add_block('simulink/Signal Routing/Mux',[s '/Qmux'],'Position',[780 300 785 700],'Inputs','6');
add_block('simulink/Math Operations/Sum of Elements',[s '/Qsum'],'Position',[800 720 830 750]);
add_block('simulink/Math Operations/Math Function',[s '/sq'],'Position',[1060 -40 1090 -10],'Operator','square');
add_block('simulink/Math Operations/Gain',[s '/Rloss'],'Position',[1110 -40 1150 -10],'Gain','PN.bus.R');
add_block('simulink/Math Operations/Sum',[s '/Qb_sum'],'Position',[860 740 880 780],'Inputs','++');
add_block('simulink/Discrete/Unit Delay',[s '/Qb_scan'],'Position',[900 750 930 780],'SampleTime','0.1');
add_block('simulink/Signal Routing/Mux',[s '/socmux'],'Position',[780 750 785 1150],'Inputs','6');
fb(s,'pack_soc',[820 1000 900 1060]);
setfcn([s '/pack_soc'],{
 'function soc = pack_soc(s, K)'
 'n = sum(K);'
 'if n > 0'
 '    soc = sum(s(:).*K(:))/n;'
 'else'
 '    soc = mean(s);'
 'end'
 'end'},{});
add_block('simulink/Math Operations/Gain',[s '/ms2mph'],'Position',[1750 300 1790 320],'Gain','1/0.44704');
add_block('simulink/Signal Routing/Mux',[s '/Ymux'],'Position',[1950 40 1955 1300],'Inputs','28');
add_block('simulink/Math Operations/Reshape',[s '/Ycol'],'Position',[1990 640 2030 680],'OutputDimensionality','Column vector (2-D)');
add_block('simulink/Sinks/Out1',[s '/y'],'Position',[2070 650 2100 670]);

L = {
 'U/1','mph2ms/1'; 'mph2ms/1','LCC/1'; 'Veh/1','LCC/2'; 'PS2S_V/1','LCC/3'; 'TMS/5','LCC/4';
 'TMS/6','LCC/5'; 'U/7','LCC/6'; 'U/18','LCC/7'; 'U/14','LCC/8'; 'U/15','LCC/9';
 'LCC/1','A1/1'; 'LCC/1','A2/1'; 'LCC/1','A3/1'; 'LCC/2','A4/1'; 'LCC/3','Veh/2'; 'U/2','Veh/1';
 'U/5','DCL/1'; 'U/3','AUX/1'; 'TMS/4','AUX/2';
 'U/4','CFW/1'; 'TMS/6','CFW/2'; 'pack_soc/1','CFW/3'; 'U/15','CFW/4'; 'PS2S_V/1','CFW/5'; 'CFW/1','CHG/1';
 'Qb_scan/1','TP/1'; 'A1/1','TP/2'; 'CHG/1','TP/3'; 'AUX/1','TP/4'; 'U/5','TP/5'; 'U/6','TP/6';
 'U/14','TP/7'; 'U/10','TP/8'; 'U/11','TP/9'; 'U/12','TP/10'; 'U/13','TP/11'; 'U/17','TP/12';
 'TMS/1','TP/13'; 'TMS/2','TP/14'; 'TMS/3','TP/15';
 'TP/1','TMS/1'; 'TP/6','TMS/2'; 'TP/4','TMS/3'; 'U/16','TMS/4'; 'U/8','TMS/5'; 'U/9','TMS/6';
 'U/5','TMS/7'; 'U/11','TMS/8'; 'U/10','TMS/9';
 'idx/1','Kcmp/1'; 'U/15','half/1'; 'half/1','Kcmp/2'; 'Kcmp/1','Kdbl/1'; 'Kdbl/1','Kd/1';
 'Kdbl/1','pack_soc/2'; 'socmux/1','pack_soc/1'; 'TP/1','T_scan/1';
 'Qmux/1','Qsum/1'; 'Qsum/1','Qb_sum/1'; 'PS2S_I/1','sq/1'; 'sq/1','Rloss/1'; 'Rloss/1','Qb_sum/2';
 'Qb_sum/1','Qb_scan/1'; 'Veh/1','ms2mph/1'; 'Ymux/1','Ycol/1'; 'Ycol/1','y/1'
};
for k = 1:4, L(end+1,:) = {'Veh/1',sprintf('A%d/2',k)}; end
for k = 1:6
    L(end+1,:) = {sprintf('Kd/%d',k),sprintf('S%d/1',k)};
    L(end+1,:) = {'T_scan/1',sprintf('S%d/2',k)};
    L(end+1,:) = {sprintf('S%d/3',k),sprintf('Qmux/%d',k)};
    L(end+1,:) = {sprintf('S%d/2',k),sprintf('socmux/%d',k)};
end
Y = {'ms2mph/1','pack_soc/1','PS2S_V/1','PS2S_I/1','DCL/1','A1/1','A1/3','LCC/1','LCC/3','AUX/1', ...
     'CHG/1','A1/2','TP/1','TP/2','TP/6','TP/3','TP/7','TP/8','TP/9','TP/10','TP/5', ...
     'TMS/4','TMS/1','TMS/3','Qb_sum/1','TP/11','TMS/5','TMS/6'};
for k = 1:28, L(end+1,:) = {Y{k},sprintf('Ymux/%d',k)}; end
nf = 0;
for k = 1:size(L,1)
    try
        add_line(s,L{k,1},L{k,2},'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('SIGNAL FAILED: %s -> %s (%s)\n',L{k,1},L{k,2},e.message);
    end
end
fprintf('Signal lines: %d drawn, %d failed\n',size(L,1)-nf,nf);

W = {
 'S1','R',1,'R_bus','L',1
 'R_bus','R',1,'I_pack_sens','L',1
 'I_pack_sens','R',2,'V_bus_sens','L',1
 'V_bus_sens','R',2,'GND','L',1
 'S1','R',2,'GND','L',1
 'I_pack_sens','R',2,'DCL','L',1
 'DCL','L',2,'GND','L',1
 'I_pack_sens','R',2,'AUX','L',1
 'AUX','L',2,'GND','L',1
 'I_pack_sens','R',2,'CHG','L',1
 'CHG','L',2,'GND','L',1
 'I_pack_sens','R',1,'PS2S_I','L',1
 'V_bus_sens','R',1,'PS2S_V','L',1
 'Solver','*',1,'GND','L',1
 'DCL','R',1,'A1','L',1
 'A1','L',2,'GND','L',1
 'A1','R',1,'Veh','L',1
};
for k = 1:5
    W(end+1,:) = {sprintf('S%d',k),'R',1,sprintf('S%d',k+1),'R',1};
    W(end+1,:) = {sprintf('S%d',k),'R',2,sprintf('S%d',k+1),'R',2};
end
for k = 1:3
    W(end+1,:) = {sprintf('A%d',k),'L',1,sprintf('A%d',k+1),'L',1};
    W(end+1,:) = {sprintf('A%d',k),'L',2,sprintf('A%d',k+1),'L',2};
    W(end+1,:) = {sprintf('A%d',k),'R',1,sprintf('A%d',k+1),'R',1};
end
nf = 0;
for k = 1:size(W,1)
    try
        add_line(s,ph(s,W{k,1},W{k,2},W{k,3}),ph(s,W{k,4},W{k,5},W{k,6}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('WIRE FAILED: %s %s%d -> %s %s%d (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
    end
end
fprintf('Physical wires: %d scripted, %d failed\n',size(W,1)-nf,nf);
save_system(lib);
fprintf('Native Plant added to %s.\n',lib);
end

function fb(s,nm,pos)
    add_block('simulink/User-Defined Functions/MATLAB Function',[s '/' nm],'Position',pos);
end

function setfcn(blk,lines,params)
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',blk);
    ch.Script = strjoin(lines,newline);
    for k = 1:numel(params)
        d = ch.find('-isa','Stateflow.Data','Name',params{k});
        d.Scope = 'Parameter';
    end
end

function h = ph(s,blk,side,k)
    p = get_param([s '/' blk],'PortHandles');
    c = [p.LConn p.RConn];
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        otherwise, h = c(k);
    end
end