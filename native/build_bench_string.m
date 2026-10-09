native_params;

d = fullfile(pwd,'native','tests');
mdl = 'bench_string';
if bdIsLoaded(mdl), close_system(mdl,0); end
f = fullfile(d,[mdl '.slx']);
if isfile(f), delete(f); end
new_system(mdl);

B = {
 'Solver Configuration',      'Solver',     [ 40 380 100 420]
 'Electrical Reference',      'GND',        [330 470 370 510]
 'Battery (Table-Based)',     'String1',    [100 180 180 260]
 'Current Sensor',            'I_sens',     [260 120 300 160]
 'Controlled Current Source', 'Load',       [420 180 470 260]
 'Voltage Sensor',            'V_sens',     [260 300 300 340]
 'Simulink-PS Converter',     'S2PS_I',     [560 210 590 230]
 'PS-Simulink Converter',     'PS2S_I',     [360 60 390 80]
 'PS-Simulink Converter',     'PS2S_V',     [360 360 390 380]
};
for k = 1:size(B,1)
    src = libpath(B{k,1});
    add_block(src,[mdl '/' B{k,2}],'Position',B{k,3});
    fprintf('%-10s <- %s\n',B{k,2},strrep(src,newline,' '));
end

add_block('simulink/Sources/From Workspace',[mdl '/I_cmd'],'Position',[640 200 700 240],'VariableName','I_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/I_meas'],'Position',[440 55 500 85],'VariableName','I_meas','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/V_term'],'Position',[440 355 500 385],'VariableName','V_term','SaveFormat','Timeseries');

try, set_param([mdl '/S2PS_I'],'Unit','A'); catch, end
try, set_param([mdl '/PS2S_I'],'Unit','A'); catch, end
try, set_param([mdl '/PS2S_V'],'Unit','V'); catch, end

set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','3000','MaxStep','1');
save_system(mdl,f);
open_system(mdl);

fprintf('\n== Battery dialog parameters ==\n');
dp = fieldnames(get_param([mdl '/String1'],'DialogParameters'));
fprintf('%s\n',dp{:});

function p = libpath(name)
    known = {
     'Solver Configuration',      sprintf('nesl_utility/Solver\nConfiguration')
     'Simulink-PS Converter',     sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter',     sprintf('nesl_utility/PS-Simulink\nConverter')
     'Electrical Reference',      'fl_lib/Electrical/Electrical Elements/Electrical Reference'
     'Current Sensor',            'fl_lib/Electrical/Electrical Sensors/Current Sensor'
     'Voltage Sensor',            'fl_lib/Electrical/Electrical Sensors/Voltage Sensor'
     'Controlled Current Source', 'fl_lib/Electrical/Electrical Sources/Controlled Current Source'
     'Battery (Table-Based)',     'ee_lib/Sources/Battery (Table-Based)'
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
    libs = {'fl_lib','ee_lib','batt_lib','nesl_utility'};
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