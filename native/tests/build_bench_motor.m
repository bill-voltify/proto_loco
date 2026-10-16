addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
load_system('sdl_lib');

mdl = 'bench_motor';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);

add_block([lib '/D77 Motor'],[mdl '/M'],'Position',[400 150 520 270]);
add_block(libpath('Controlled Voltage Source'),[mdl '/Va_src'],'Position',[200 150 250 230]);
add_block(libpath('Electrical Reference'),[mdl '/GND'],'Position',[200 320 240 360]);
add_block(libpath('Solver Configuration'),[mdl '/Solver'],'Position',[60 320 120 360]);
add_block(libpath('Simulink-PS Converter'),[mdl '/S2PS_V'],'Position',[120 170 150 190]);
add_block(libpath('Simple Gear'),[mdl '/Gear'],'Position',[600 180 660 240]);
add_block(libpath('Wheel and Axle'),[mdl '/Wheel'],'Position',[720 180 780 240]);
add_block(libpath('Ideal Force Sensor'),[mdl '/F_sens'],'Position',[840 180 900 240]);
add_block(libpath('Ideal Translational Velocity Source'),[mdl '/Vel_src'],'Position',[960 180 1020 240]);
add_block(libpath('Mechanical Translational Reference'),[mdl '/TransRef'],'Position',[1060 300 1100 340]);
add_block(libpath('Simulink-PS Converter'),[mdl '/S2PS_v'],'Position',[1080 120 1110 140]);
add_block(libpath('PS-Simulink Converter'),[mdl '/PS2S_F'],'Position',[900 300 930 320]);

add_block('simulink/Sources/From Workspace',[mdl '/Va_cmd'],'Position',[20 165 80 195],'VariableName','Va_bench');
add_block('simulink/Sources/From Workspace',[mdl '/v_cmd'],'Position',[1140 115 1200 145],'VariableName','v_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/i_a'],'Position',[600 60 660 90],'VariableName','i_a','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/T_m'],'Position',[600 100 660 130],'VariableName','T_m','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/F_rail'],'Position',[960 295 1020 325],'VariableName','F_rail','SaveFormat','Timeseries');
add_line(mdl,'Va_cmd/1','S2PS_V/1','autorouting','on');
add_line(mdl,'v_cmd/1','S2PS_v/1','autorouting','on');
add_line(mdl,'M/1','i_a/1','autorouting','on');
add_line(mdl,'M/2','T_m/1','autorouting','on');
add_line(mdl,'PS2S_F/1','F_rail/1','autorouting','on');

try, set_param([mdl '/S2PS_V'],'Unit','V'); catch, end
try, set_param([mdl '/S2PS_v'],'Unit','m/s'); catch, end
try, set_param([mdl '/PS2S_F'],'Unit','N'); catch, end
try, set_param([mdl '/S2PS_v'],'FilteringAndDerivatives','filter','SimscapeFilterOrder','1','InputFilterTimeConstant','0.001'); catch e, fprintf('S2PS_v filter: %s\n',e.message); end

g = [mdl '/Gear'];
md = string(enumeration('sdl.enum.shaftOutputDirection'));
mf = string(enumeration('sdl.enum.gear_efficiencies_load'));
jd = find(contains(lower(md),'same'),1);
jf = find(contains(lower(mf),'const'),1);
fprintf('Gear direction options: %s\nGear friction options : %s\n',strjoin(md,', '),strjoin(mf,', '));
set_param(g,'ratio','PN.ax.G', ...
    'rotation_direction',['sdl.enum.shaftOutputDirection.' char(md(jd))], ...
    'friction_model',['sdl.enum.gear_efficiencies_load.' char(mf(jf))], ...
    'efficiency','PN.ax.eta_g','pwr_thr','1e3');
set_param([mdl '/Wheel'],'R','PN.ax.r_w');

set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','20','MaxStep','1e-2');
save_system(mdl,f);
open_system(mdl);
fprintf('\nCreated %s. Wire the 12 connections, then Ctrl+S.\n',f);

function p = libpath(name)
    known = {
     'Solver Configuration',                sprintf('nesl_utility/Solver\nConfiguration')
     'Simulink-PS Converter',               sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter',               sprintf('nesl_utility/PS-Simulink\nConverter')
     'Electrical Reference',                'fl_lib/Electrical/Electrical Elements/Electrical Reference'
     'Controlled Voltage Source',           'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source'
     'Simple Gear',                         'sdl_lib/Gears/Simple Gear'
     'Wheel and Axle',                      'fl_lib/Mechanical/Mechanisms/Wheel and Axle'
     'Ideal Force Sensor',                  'fl_lib/Mechanical/Mechanical Sensors/Ideal Force Sensor'
     'Ideal Translational Velocity Source', 'fl_lib/Mechanical/Mechanical Sources/Ideal Translational Velocity Source'
     'Mechanical Translational Reference',  'fl_lib/Mechanical/Translational Elements/Mechanical Translational Reference'
    };
    i = find(strcmp(known(:,1),name),1);
    if ~isempty(i)
        try
            if getSimulinkBlockHandle(known{i,2},true) > 0
                p = known{i,2};
                return
            end
        catch
        end
    end
    libs = {'fl_lib','sdl_lib','ee_lib','nesl_utility'};
    pat = ['^' strrep(regexptranslate('escape',name),' ','\s') '$'];
    for k = 1:numel(libs)
        try, load_system(libs{k}); catch, continue; end
        h = find_system(libs{k},'LookUnderMasks','all','FollowLinks','on','RegExp','on','Name',pat);
        h = h(~strcmp(h,libs{k}));
        if ~isempty(h)
            [~,j] = min(cellfun(@numel,h));
            p = h{j};
            return
        end
    end
    error('Block not found in libraries: %s',name);
end