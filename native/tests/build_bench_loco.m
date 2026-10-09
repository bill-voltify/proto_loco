addpath(genpath(fullfile(pwd,'native')));
native_params;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

mdl = 'bench_loco';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);

for k = 1:6
    add_block([lib '/TRB String'],sprintf('%s/S%d',mdl,k),'Position',[200 60+90*(k-1) 320 120+90*(k-1)]);
end
add_block('simulink/Sources/Constant',[mdl '/K_all'],'Position',[20 300 60 330],'Value','ones(6,1)');
add_block('simulink/Signal Routing/Demux',[mdl '/K_demux'],'Position',[110 60 115 600],'Outputs','6');
add_block('fl_lib/Electrical/Electrical Elements/Resistor',[mdl '/R_bus'],'Position',[400 40 460 70],'R','PN.bus.R');
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[mdl '/I_pack_sens'],'Position',[500 30 540 70]);
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor',[mdl '/V_bus_sens'],'Position',[580 120 620 160]);
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference',[mdl '/GND'],'Position',[600 760 640 800]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[mdl '/Solver'],'Position',[480 760 540 800]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_I'],'Position',[600 0 630 20]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_V'],'Position',[660 200 690 220]);
set_param([mdl '/PS2S_I'],'Unit','A');
set_param([mdl '/PS2S_V'],'Unit','V');
add_block([lib '/DC-Link'],[mdl '/DCL'],'Position',[700 40 820 160]);
for k = 1:4
    add_block([lib '/Axle'],sprintf('%s/A%d',mdl,k),'Position',[920 40+150*(k-1) 1040 140+150*(k-1)]);
end
add_block([lib '/Vehicle'],[mdl '/Veh'],'Position',[1200 300 1320 420]);
add_block([lib '/LCC'],[mdl '/LCC'],'Position',[700 620 820 880]);

add_block('simulink/Sources/From Workspace',[mdl '/en_cmd'],'Position',[560 60 620 90],'VariableName','en_bench');
add_block('simulink/Sources/From Workspace',[mdl '/vref_cmd'],'Position',[440 620 500 650],'VariableName','vref_bench');
add_block('simulink/Sources/From Workspace',[mdl '/grade_cmd'],'Position',[1060 280 1120 310],'VariableName','grade_bench');
C = {'k_dis','1';'k_chg','1';'m_trail','PN.veh.m_trail';'trac','1';'n_ax_on','4';'n_str','PN.lcc.N_str_nom'};
for k = 1:size(C,1)
    add_block('simulink/Sources/Constant',[mdl '/c_' C{k,1}],'Position',[440 660+30*k 500 680+30*k],'Value',C{k,2});
end

T = {'v','Veh/1';'I_pack','PS2S_I/1';'V_bus','PS2S_V/1';'v_link','DCL/1';'TE_ax','LCC/1';'F_fric','LCC/3';'ia1','A1/1';'idc1','A1/2'};
for k = 1:size(T,1)
    add_block('simulink/Sinks/To Workspace',[mdl '/log_' T{k,1}],'Position',[1450 40+50*k 1510 70+50*k],'VariableName',T{k,1},'SaveFormat','Timeseries');
    add_line(mdl,T{k,2},['log_' T{k,1} '/1'],'autorouting','on');
end

S = {
 'K_all/1','K_demux/1'
 'en_cmd/1','DCL/1'
 'vref_cmd/1','LCC/1'
 'Veh/1','LCC/2'
 'PS2S_V/1','LCC/3'
 'c_k_dis/1','LCC/4'
 'c_k_chg/1','LCC/5'
 'c_m_trail/1','LCC/6'
 'c_trac/1','LCC/7'
 'c_n_ax_on/1','LCC/8'
 'c_n_str/1','LCC/9'
 'LCC/1','A1/1'
 'LCC/1','A2/1'
 'LCC/1','A3/1'
 'LCC/2','A4/1'
 'LCC/3','Veh/2'
 'grade_cmd/1','Veh/1'
};
for k = 1:6, S(end+1,:) = {sprintf('K_demux/%d',k),sprintf('S%d/1',k)}; end
for k = 1:4, S(end+1,:) = {'Veh/1',sprintf('A%d/2',k)}; end
for k = 1:size(S,1)
    add_line(mdl,S{k,1},S{k,2},'autorouting','on');
end

W = {
 'S1','R',1,'R_bus','L',1
 'R_bus','R',1,'I_pack_sens','L',1
 'I_pack_sens','R',2,'DCL','L',1
 'I_pack_sens','R',2,'V_bus_sens','L',1
 'V_bus_sens','R',2,'GND','L',1
 'S1','R',2,'GND','L',1
 'DCL','L',2,'GND','L',1
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
        add_line(mdl,ph(mdl,W{k,1},W{k,2},W{k,3}),ph(mdl,W{k,4},W{k,5},W{k,6}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('HAND-WIRE: %s %s%d -> %s %s%d  (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
    end
end
fprintf('Physical wires: %d scripted, %d failed\n',size(W,1)-nf,nf);

set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','120','MaxStep','1e-2');
save_system(mdl,f);
open_system(mdl);
fprintf('\nCreated %s\n',f);

function h = ph(mdl,blk,side,k)
    p = get_param([mdl '/' blk],'PortHandles');
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        otherwise
            c = [p.LConn p.RConn];
            h = c(k);
    end
end