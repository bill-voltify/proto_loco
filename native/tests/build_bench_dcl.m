addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

src = fullfile(pwd,'native','tests','bench_trb.slx');
mdl = 'bench_dcl';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded('bench_trb'), close_system('bench_trb',0); end
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
copyfile(src,f);
load_system(f);

add_block([lib '/DC-Link'],[mdl '/DCL'],'Position',[700 760 820 880]);
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor',[mdl '/I_dcl_sens'],'Position',[560 760 600 800]);
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source',[mdl '/Load2'],'Position',[900 760 950 840]);
add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[mdl '/S2PS_I2'],'Position',[990 790 1020 810]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_Idcl'],'Position',[620 700 650 720]);
try, set_param([mdl '/S2PS_I2'],'Unit','A'); catch, end
try, set_param([mdl '/PS2S_Idcl'],'Unit','A'); catch, end

add_block('simulink/Sources/From Workspace',[mdl '/I_trac'],'Position',[1060 780 1120 820],'VariableName','I_trac_bench');
add_block('simulink/Sources/From Workspace',[mdl '/en'],'Position',[560 880 620 910],'VariableName','en_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/v_link'],'Position',[880 880 940 910],'VariableName','v_link','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/main_closed'],'Position',[880 930 940 960],'VariableName','main_closed','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/I_dcl'],'Position',[680 695 740 725],'VariableName','I_dcl','SaveFormat','Timeseries');

add_line(mdl,'I_trac/1','S2PS_I2/1','autorouting','on');
add_line(mdl,'en/1','DCL/1','autorouting','on');
add_line(mdl,'DCL/1','v_link/1','autorouting','on');
add_line(mdl,'DCL/2','main_closed/1','autorouting','on');
add_line(mdl,'PS2S_Idcl/1','I_dcl/1','autorouting','on');

set_param(mdl,'StopTime','10','MaxStep','1e-3');
save_system(mdl);
open_system(mdl);
fprintf('\nCreated %s. Wire the 7 connections, then Ctrl+S.\n',f);