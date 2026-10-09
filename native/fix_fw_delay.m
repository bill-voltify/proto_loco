lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
fw = [lib '/Chopper FW'];

if getSimulinkBlockHandle([fw '/Scan']) > 0
    try, delete_line(fw,'fw/1','Scan/1'); catch, end
    try, delete_line(fw,'Scan/1','Va/1'); catch, end
    delete_block([fw '/Scan']);
else
    try, delete_line(fw,'fw/1','Va/1'); catch, end
end

add_block('simulink/Discrete/Unit Delay',[fw '/Scan'],'Position',[360 125 390 155],'SampleTime','1e-4');
add_line(fw,'fw/1','Scan/1','autorouting','on');
add_line(fw,'Scan/1','Va/1','autorouting','on');
save_system(lib);
fprintf('Chopper FW: Unit Delay at %s s (10 kHz) between fw and Va.\n',get_param([fw '/Scan'],'SampleTime'));