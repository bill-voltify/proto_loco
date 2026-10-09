addpath(genpath(fullfile(pwd,'native')));
native_params;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
set_param([lib '/Chopper FW/Scan'],'SampleTime','A.Ts_fw');
save_system(lib);
fprintf('Chopper FW Scan sample time = %s (from mask struct A = PN.ax)\n',get_param([lib '/Chopper FW/Scan'],'SampleTime'));