lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
b = [lib '/Chopper/S2PS_Va'];
set_param(b,'FilteringAndDerivatives','filter','SimscapeFilterOrder','1','InputFilterTimeConstant','1e-4');
save_system(lib);
fprintf('S2PS_Va: %s, order %s, tau %s s\n',get_param(b,'FilteringAndDerivatives'),get_param(b,'SimscapeFilterOrder'),get_param(b,'InputFilterTimeConstant'));