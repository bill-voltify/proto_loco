function fix_string_tinit
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
c = [lib '/TRB String/Cells'];
set_param(c,'cell_temperature_specify','on','cell_temperature_priority','Low', ...
    'cell_temperature','298.15','cell_temperature_unit','K');
save_system(lib);
fprintf('Cells initial temperature: specify %s, priority %s, value %s K\n', ...
    get_param(c,'cell_temperature_specify'),get_param(c,'cell_temperature_priority'),get_param(c,'cell_temperature'));
end