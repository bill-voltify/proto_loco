addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
cb = [lib '/TRB String/Contactor'];
try
    fprintf('Contactor: R_closed=%s  G_open=%s  Threshold=%s\n',get_param(cb,'R_closed'),get_param(cb,'G_open'),get_param(cb,'Threshold'));
catch
    fprintf('Contactor params could not be read (check names)\n');
end

mdl = 'bench_trb';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);

add_block('simulink/Sources/From Workspace',[mdl '/K_cmd'],'Position',[20 330 80 370],'VariableName','K_bench');
add_block('simulink/Signal Routing/Demux',[mdl '/K_demux'],'Position',[130 100 135 600],'Outputs','6');
add_block('simulink/Signal Routing/Mux',[mdl '/I_mux'],'Position',[1050 100 1055 600],'Inputs','6');
add_block('simulink/Sinks/To Workspace',[mdl '/I_str'],'Position',[1090 335 1150 365],'VariableName','I_str','SaveFormat','Timeseries');
add_line(mdl,'K_cmd/1','K_demux/1','autorouting','on');
add_line(mdl,'I_mux/1','I_str/1','autorouting','on');

for k = 1:6
    y = 100 + (k-1)*85;
    add_block([lib '/TRB String'],sprintf('%s/S%d',mdl,k),'Position',[200 y 320 y+60]);
    add_line(mdl,sprintf('K_demux/%d',k),sprintf('S%d/1',k),'autorouting','on');
    add_line(mdl,sprintf('S%d/1',k),sprintf('I_mux/%d',k),'autorouting','on');
end
for k = 1:5
    a = conn(sprintf('%s/S%d',mdl,k));
    b = conn(sprintf('%s/S%d',mdl,k+1));
    add_line(mdl,a(1),b(1),'autorouting','on');
    add_line(mdl,a(2),b(2),'autorouting','on');
end

B = {
 'Resistor',                  'R_bus',   [450  50 510  80]
 'Current Sensor',            'I_sensP', [560  45 600  85]
 'Controlled Current Source', 'Load',    [680 150 730 230]
 'Voltage Sensor',            'V_sensP', [560 250 600 290]
 'Electrical Reference',      'GND',     [600 650 640 690]
 'Solver Configuration',      'Solver',  [450 650 510 690]
 'Simulink-PS Converter',     'S2PS_I',  [780 180 810 200]
 'PS-Simulink Converter',     'PS2S_Ip', [650   5 680  25]
 'PS-Simulink Converter',     'PS2S_V',  [650 300 680 320]
};
for k = 1:size(B,1)
    add_block(libpath(B{k,1}),[mdl '/' B{k,2}],'Position',B{k,3});
end
set_param([mdl '/R_bus'],'R','PN.bus.R');
try, set_param([mdl '/S2PS_I'],'Unit','A'); catch, end
try, set_param([mdl '/PS2S_Ip'],'Unit','A'); catch, end
try, set_param([mdl '/PS2S_V'],'Unit','V'); catch, end

add_block('simulink/Sources/From Workspace',[mdl '/I_cmd'],'Position',[840 170 900 210],'VariableName','I_pack_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/I_pack'],'Position',[710 0 770 30],'VariableName','I_pack','SaveFormat','Timeseries');
add_block('simulink/Sinks/To Workspace',[mdl '/V_pack'],'Position',[710 295 770 325],'VariableName','V_pack','SaveFormat','Timeseries');
add_line(mdl,'I_cmd/1','S2PS_I/1','autorouting','on');
add_line(mdl,'PS2S_Ip/1','I_pack/1','autorouting','on');
add_line(mdl,'PS2S_V/1','V_pack/1','autorouting','on');

set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','1800','MaxStep','1');
save_system(mdl,f);
open_system(mdl);
fprintf('\nCreated %s. Wire the 11 connections, then Ctrl+S.\n',f);

function c = conn(blk)
    ph = get_param(blk,'PortHandles');
    c = [ph.LConn ph.RConn];
end

function p = libpath(name)
    known = {
     'Solver Configuration',      sprintf('nesl_utility/Solver\nConfiguration')
     'Simulink-PS Converter',     sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter',     sprintf('nesl_utility/PS-Simulink\nConverter')
     'Electrical Reference',      'fl_lib/Electrical/Electrical Elements/Electrical Reference'
     'Resistor',                  'fl_lib/Electrical/Electrical Elements/Resistor'
     'Current Sensor',            'fl_lib/Electrical/Electrical Sensors/Current Sensor'
     'Voltage Sensor',            'fl_lib/Electrical/Electrical Sensors/Voltage Sensor'
     'Controlled Current Source', 'fl_lib/Electrical/Electrical Sources/Controlled Current Source'
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