addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/AUX'];
if getSimulinkBlockHandle(s) > 0
    error('AUX already exists in %s. Delete it in the library first to rebuild.',lib);
end
add_block('built-in/Subsystem',s,'Position',[100 400 220 520]);

mk = Simulink.Mask.create(s);
mk.addParameter('Name','eta','Prompt','Converter efficiency','Value','P.aux.eta');
mk.addParameter('Name','P_max','Prompt','Max output power (W)','Value','P.aux.P_max');
mk.addParameter('Name','V750','Prompt','AUX bus voltage (V)','Value','750');
mk.addParameter('Name','V_floor','Prompt','Input voltage floor (V)','Value','100');

fl = 'fl_lib/Electrical/';
add_block('nesl_utility/Connection Port',[s '/p'],'Position',[20 80 50 100]);
add_block('nesl_utility/Connection Port',[s '/n'],'Position',[20 380 50 400]);
try, set_param([s '/p'],'Side','Left'); catch, end
try, set_param([s '/n'],'Side','Left'); catch, end

add_block([fl 'Electrical Sources/Controlled Current Source'],[s '/Iin'],'Position',[150 180 200 260]);
add_block([fl 'Electrical Sensors/Voltage Sensor'],[s '/V_dc_sens'],'Position',[260 200 300 240]);
add_block([fl 'Electrical Sources/DC Voltage Source'],[s '/V750'],'Position',[700 180 750 260]);
add_block([fl 'Electrical Sensors/Current Sensor'],[s '/I_out'],'Position',[820 70 860 110]);
add_block([fl 'Electrical Sources/Controlled Current Source'],[s '/Load'],'Position',[960 180 1010 260]);
add_block([fl 'Electrical Sensors/Voltage Sensor'],[s '/V750_sens'],'Position',[820 300 860 340]);
add_block([fl 'Electrical Elements/Electrical Reference'],[s '/Ref750'],'Position',[700 400 740 440]);

ps = 'fl_lib/Physical Signals/';
add_block([ps 'Functions/PS Gain'],[s '/v_buf'],'Position',[340 300 380 330]);
add_block([ps 'Functions/PS Gain'],[s '/v750_buf'],'Position',[900 360 940 390]);
add_block([ps 'Functions/PS Gain'],[s '/i_buf'],'Position',[900 130 940 160]);
add_block([ps 'Functions/PS Product'],[s '/Prod_out'],'Position',[620 480 650 520]);
add_block([ps 'Functions/PS Gain'],[s '/Gain_eta'],'Position',[690 485 730 515]);
add_block([ps 'Sources/PS Constant'],[s '/Vf'],'Position',[380 400 420 420]);
add_block([ps 'Nonlinear Operators/PS Max'],[s '/Max'],'Position',[460 380 490 420]);
add_block([ps 'Functions/PS Divide'],[s '/Div'],'Position',[780 440 810 480]);

add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[s '/S2PS_Il'],'Position',[1000 520 1030 540]);
c2 = sprintf('nesl_utility/PS-Simulink\nConverter');
add_block(c2,[s '/PS2S_pin'],'Position',[860 560 890 580]);
add_block(c2,[s '/PS2S_iin'],'Position',[860 610 890 630]);
add_block(c2,[s '/PS2S_vdc'],'Position',[860 660 890 680]);
add_block(c2,[s '/PS2S_v750'],'Position',[860 710 890 730]);

add_block('simulink/Sources/In1',[s '/P'],'Position',[700 560 730 580]);
add_block('simulink/Sources/In1',[s '/P2'],'Position',[700 600 730 620]);
add_block('simulink/Math Operations/Sum',[s '/Sum'],'Position',[780 560 800 620],'Inputs','++');
add_block('simulink/Discontinuities/Saturation',[s '/Clamp'],'Position',[830 520 870 550], ...
    'UpperLimit','P_max','LowerLimit','0');
add_block('simulink/Math Operations/Gain',[s '/to_A'],'Position',[900 520 950 550],'Gain','1/V750');
out = {'p_in','PS2S_pin';'i_in','PS2S_iin';'vdc','PS2S_vdc';'v750','PS2S_v750'};
for k = 1:4
    add_block('simulink/Sinks/Out1',[s '/' out{k,1}],'Position',[960 560+50*(k-1) 990 580+50*(k-1)]);
    add_line(s,[out{k,2} '/1'],[out{k,1} '/1'],'autorouting','on');
end
add_line(s,'P/1','Sum/1','autorouting','on');
add_line(s,'P2/1','Sum/2','autorouting','on');
add_line(s,'Sum/1','Clamp/1','autorouting','on');
add_line(s,'Clamp/1','to_A/1','autorouting','on');
add_line(s,'to_A/1','S2PS_Il/1','autorouting','on');

trySet([s '/V750'],{'v0','V750'});
trySet([s '/v_buf'],{'gain','1'});
trySet([s '/v750_buf'],{'gain','1'});
trySet([s '/i_buf'],{'gain','1'});
trySet([s '/Gain_eta'],{'gain','1/eta'});
trySet([s '/Vf'],{'constant','V_floor','constant_unit','V'});
trySet([s '/S2PS_Il'],{'Unit','A'});
trySet([s '/PS2S_pin'],{'Unit','W'});
trySet([s '/PS2S_iin'],{'Unit','A'});
trySet([s '/PS2S_vdc'],{'Unit','V'});
trySet([s '/PS2S_v750'],{'Unit','V'});

W = {
 'p','*',1,'Iin','R',2
 'Iin','L',1,'n','*',1
 'V_dc_sens','L',1,'p','*',1
 'V_dc_sens','R',2,'n','*',1
 'V750','T',0,'I_out','L',1
 'I_out','R',2,'Load','R',2
 'Load','L',1,'V750','B',0
 'V750','B',0,'Ref750','L',1
 'V750_sens','L',1,'V750','T',0
 'V750_sens','R',2,'V750','B',0
 'S2PS_Il','R',1,'Load','R',1
 'V_dc_sens','R',1,'v_buf','L',1
 'V750_sens','R',1,'v750_buf','L',1
 'I_out','R',1,'i_buf','L',1
 'Div','R',1,'Iin','R',1
 'v750_buf','R',1,'Prod_out','L',1
 'i_buf','R',1,'Prod_out','L',2
 'Prod_out','R',1,'Gain_eta','L',1
 'v_buf','R',1,'Max','L',1
 'Vf','R',1,'Max','L',2
 'Gain_eta','R',1,'Div','L',1
 'Max','R',1,'Div','L',2
 'Gain_eta','R',1,'PS2S_pin','L',1
 'Div','R',1,'PS2S_iin','L',1
 'v_buf','R',1,'PS2S_vdc','L',1
 'v750_buf','R',1,'PS2S_v750','L',1
};
nf = 0;
for k = 1:size(W,1)
    try
        add_line(s,ph(s,W{k,1},W{k,2},W{k,3}),ph(s,W{k,4},W{k,5},W{k,6}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('HAND-WIRE: %s %s%d -> %s %s%d  (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
    end
end
fprintf('AUX wires: %d scripted, %d to hand-wire\n',size(W,1)-nf,nf);

save_system(lib);
open_system(s);
fprintf('\nAUX block added to %s.\n',lib);

function h = ph(s,blk,side,k)
    p = get_param([s '/' blk],'PortHandles');
    c = [p.LConn p.RConn];
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        case '*', h = c(k);
        otherwise
            y = zeros(size(c));
            for j = 1:numel(c)
                pos = get_param(c(j),'Position');
                y(j) = pos(2);
            end
            if side == 'T', [~,j] = min(y); else, [~,j] = max(y); end
            h = c(j);
    end
end

function trySet(b,pv)
    try
        set_param(b,pv{:});
    catch e
        fprintf('SET FAILED on %s: %s\n',b,e.message);
        dp = fieldnames(get_param(b,'DialogParameters'));
        fprintf('   params: %s\n',strjoin(dp(~endsWith(dp,'_conf') & ~endsWith(dp,'_unit')),', '));
    end
end