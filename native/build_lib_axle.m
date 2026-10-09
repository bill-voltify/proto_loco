addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
load_system('sdl_lib');
set_param(lib,'Lock','off');
s = [lib '/Axle'];
if getSimulinkBlockHandle(s) > 0
    error('Axle already exists in %s. Delete it in the library first to rebuild.',lib);
end

add_block('built-in/Subsystem',s,'Position',[900 100 1020 220]);
add_block('nesl_utility/Connection Port',[s '/p'],'Position',[20 80 50 100]);
add_block('nesl_utility/Connection Port',[s '/n'],'Position',[20 300 50 320]);
add_block('nesl_utility/Connection Port',[s '/rail'],'Position',[900 180 930 200]);
try, set_param([s '/p'],'Side','Left'); catch, end
try, set_param([s '/n'],'Side','Left'); catch, end
try, set_param([s '/rail'],'Side','Right'); catch, end

add_block([lib '/Chopper'],[s '/CH'],'Position',[150 80 270 200]);
add_block([lib '/Chopper FW'],[s '/FW'],'Position',[150 320 270 440]);
add_block([lib '/D77 Motor'],[s '/M'],'Position',[380 80 500 200]);
add_block('sdl_lib/Gears/Simple Gear',[s '/Gear'],'Position',[580 110 640 170]);
add_block('fl_lib/Mechanical/Mechanisms/Wheel and Axle',[s '/Wheel'],'Position',[720 110 780 170]);

md = string(enumeration('sdl.enum.shaftOutputDirection'));
mf = string(enumeration('sdl.enum.gear_efficiencies_load'));
set_param([s '/Gear'],'ratio','PN.ax.G', ...
    'rotation_direction',['sdl.enum.shaftOutputDirection.' char(md(find(contains(lower(md),'same'),1)))], ...
    'friction_model',['sdl.enum.gear_efficiencies_load.' char(mf(find(contains(lower(mf),'const'),1)))], ...
    'efficiency','PN.ax.eta_g','pwr_thr','1e3');
set_param([s '/Wheel'],'R','PN.ax.r_w');

add_block('simulink/Sources/In1',[s '/TE_ref'],'Position',[20 340 50 360]);
add_block('simulink/Sources/In1',[s '/v'],'Position',[20 400 50 420]);
add_block('simulink/Sinks/Out1',[s '/i_a'],'Position',[420 300 450 320]);
add_block('simulink/Sinks/Out1',[s '/i_dc'],'Position',[420 360 450 380]);

L = {
 'TE_ref/1','FW/1'
 'CH/1','FW/2'
 'v/1','FW/3'
 'CH/2','FW/4'
 'FW/1','CH/1'
 'CH/1','i_a/1'
 'CH/3','i_dc/1'
};
for k = 1:size(L,1)
    add_line(s,L{k,1},L{k,2},'autorouting','on');
end

W = {
 'p','*',1,    'CH','L',1
 'n','*',1,    'CH','L',2
 'CH','R',1,   'M','L',1
 'CH','R',2,   'M','L',2
 'M','R',1,    'Gear','L',1
 'Gear','R',1, 'Wheel','L',1
 'Wheel','R',1,'rail','*',1
};
nf = 0;
for k = 1:size(W,1)
    try
        add_line(s,ph(s,W{k,1},W{k,2},W{k,3}),ph(s,W{k,4},W{k,5},W{k,6}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('HAND-WIRE: %s %s%d -> %s %s%d   (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
    end
end
fprintf('Physical wires: %d scripted, %d to hand-wire\n',size(W,1)-nf,nf);

for b = {'p','n','rail','CH','M','Gear','Wheel'}
    h = get_param([s '/' b{1}],'PortHandles');
    c = [h.LConn h.RConn];
    for j = 1:numel(c)
        if get_param(c(j),'Line') == -1
            fprintf('UNCONNECTED: %s port %d\n',b{1},j);
        end
    end
end

save_system(lib);
open_system(s);
fprintf('\nAxle block added to %s.\n',lib);

function h = ph(s,blk,side,k)
    p = get_param([s '/' blk],'PortHandles');
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        otherwise
            c = [p.LConn p.RConn];
            h = c(k);
    end
end