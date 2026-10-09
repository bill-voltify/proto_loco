addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
load_system('sdl_lib');

src = fullfile(pwd,'native','tests','bench_dcl.slx');
mdl = 'bench_axle';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded('bench_dcl'), close_system('bench_dcl',0); end
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
copyfile(src,f);
load_system(f);

add_block([lib '/Chopper'],[mdl '/CH'],'Position',[700 1050 820 1170]);
add_block([lib '/Chopper FW'],[mdl '/FW'],'Position',[480 1250 600 1370]);
add_block([lib '/D77 Motor'],[mdl '/M'],'Position',[900 1050 1020 1170]);
add_block('sdl_lib/Gears/Simple Gear',[mdl '/Gear'],'Position',[1080 1080 1140 1140]);
add_block('fl_lib/Mechanical/Mechanisms/Wheel and Axle',[mdl '/Wheel'],'Position',[1200 1080 1260 1140]);
add_block('fl_lib/Mechanical/Mechanical Sensors/Ideal Force Sensor',[mdl '/F_sens'],'Position',[1320 1080 1380 1140]);
add_block('fl_lib/Mechanical/Mechanical Sources/Ideal Translational Velocity Source',[mdl '/Vel_src'],'Position',[1440 1080 1500 1140]);
add_block('fl_lib/Mechanical/Translational Elements/Mechanical Translational Reference',[mdl '/TransRef'],'Position',[1540 1200 1580 1240]);
add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[mdl '/S2PS_v'],'Position',[1560 1020 1590 1040]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_F'],'Position',[1340 1200 1370 1220]);
try, set_param([mdl '/S2PS_v'],'Unit','m/s','FilteringAndDerivatives','filter','SimscapeFilterOrder','1','InputFilterTimeConstant','0.001'); catch e, fprintf('S2PS_v: %s\n',e.message); end
try, set_param([mdl '/PS2S_F'],'Unit','N'); catch, end

g = [mdl '/Gear'];
md = string(enumeration('sdl.enum.shaftOutputDirection'));
mf = string(enumeration('sdl.enum.gear_efficiencies_load'));
set_param(g,'ratio','PN.ax.G', ...
    'rotation_direction',['sdl.enum.shaftOutputDirection.' char(md(find(contains(lower(md),'same'),1)))], ...
    'friction_model',['sdl.enum.gear_efficiencies_load.' char(mf(find(contains(lower(mf),'const'),1)))], ...
    'efficiency','PN.ax.eta_g','pwr_thr','1e3');
set_param([mdl '/Wheel'],'R','PN.ax.r_w');

add_block('simulink/Sources/From Workspace',[mdl '/TE_cmd'],'Position',[300 1240 360 1270],'VariableName','TE_bench');
add_block('simulink/Sources/From Workspace',[mdl '/v_cmd'],'Position',[300 1320 360 1350],'VariableName','v_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/i_a'],'Position',[900 1250 960 1280],'VariableName','i_a','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/Va'],'Position',[900 1300 960 1330],'VariableName','Va','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/i_dc'],'Position',[900 1350 960 1380],'VariableName','i_dc','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/F_rail'],'Position',[1400 1195 1460 1225],'VariableName','F_rail','SaveFormat','Timeseries');

L = {
 'TE_cmd/1','FW/1'
 'CH/1','FW/2'
 'v_cmd/1','FW/3'
 'CH/2','FW/4'
 'FW/1','CH/1'
 'v_cmd/1','S2PS_v/1'
 'CH/1','i_a/1'
 'FW/1','Va/1'
 'CH/3','i_dc/1'
 'PS2S_F/1','F_rail/1'
};
for k = 1:size(L,1)
    add_line(mdl,L{k,1},L{k,2},'autorouting','on');
end

set_param(mdl,'StopTime','20','MaxStep','1e-3');
save_system(mdl);
open_system(mdl);
fprintf('\nCreated %s. Wire the 11 connections (bottom of canvas), then Ctrl+S.\n',f);