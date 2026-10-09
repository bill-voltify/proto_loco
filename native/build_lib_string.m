addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
f = fullfile(pwd,'native','lib',[lib '.slx']);
if isfile(f)
    error('Library already exists: %s. Delete it first if you really want to rebuild (this erases your wiring).',f);
end
if bdIsLoaded(lib), close_system(lib,0); end

bench = 'bench_string';
if ~bdIsLoaded(bench), load_system(fullfile(pwd,'native','tests',[bench '.slx'])); end

new_system(lib,'Library');
s = [lib '/TRB String'];
add_block('built-in/Subsystem',s,'Position',[100 100 220 200]);

add_block([bench '/String1'],[s '/Cells'],'Position',[100 150 180 230]);
add_block(libpath('Switch'),[s '/Contactor'],'Position',[380 60 440 110]);
add_block(libpath('Current Sensor'),[s '/I_sens'],'Position',[220 60 260 100]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_K'],'Position',[300 0 330 20]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_I'],'Position',[300 130 330 150]);
add_block('nesl_utility/Connection Port',[s '/pos'],'Position',[560 70 590 90]);
add_block('nesl_utility/Connection Port',[s '/neg'],'Position',[560 260 590 280]);
add_block('simulink/Sources/In1',[s '/K_cmd'],'Position',[200 0 230 20]);
add_block('simulink/Sinks/Out1',[s '/I_str'],'Position',[400 130 430 150]);

try, set_param([s '/pos'],'Side','Right'); catch, end
try, set_param([s '/neg'],'Side','Right'); catch, end
try, set_param([s '/S2PS_K'],'Unit','1'); catch, end
try, set_param([s '/PS2S_I'],'Unit','A'); catch, end

try
    set_param([s '/Contactor'],'R_closed','0.1e-3','G_open','1e-9','Threshold','0.5');
catch e
    fprintf('Could not set Contactor params: %s\nDialog parameters are:\n',e.message);
    dp = fieldnames(get_param([s '/Contactor'],'DialogParameters'));
    fprintf('  %s\n',dp{:});
end

add_line(s,'K_cmd/1','S2PS_K/1','autorouting','on');
add_line(s,'PS2S_I/1','I_str/1','autorouting','on');

set_param(lib,'Lock','off');
save_system(lib,f);
open_system(s);
fprintf('\nCreated %s\nNow wire the 6 physical connections inside TRB String, then Ctrl+S.\n',f);

function p = libpath(name)
    known = {
     'Simulink-PS Converter', sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter', sprintf('nesl_utility/PS-Simulink\nConverter')
     'Current Sensor',        'fl_lib/Electrical/Electrical Sensors/Current Sensor'
     'Switch',                'fl_lib/Electrical/Electrical Elements/Switch'
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
    libs = {'fl_lib','ee_lib','nesl_utility'};
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