function mdl = build_cemex_model()
% BUILD_CEMEX_MODEL  Create cemex_loco_system.slx: a renamed copy of the GP40 system model (loco_system).
% The plant equations (+locosys) and controls are shared with the GP40 model; every CEMEX difference is a
% parameter in cemex_params.m, read from P at simulation time. Rebuild after build_loco_system changes.
here = fileparts(mfilename('fullpath'));
base = fullfile(fileparts(here), 'loco_system');
addpath(base); addpath(fileparts(here));
src = 'voltify_loco_system';
mdl = 'cemex_loco_system';
if ~isfile(fullfile(base, [src '.slx'])), build_loco_system(); end
for m = {src, mdl}
    if bdIsLoaded(m{1}), close_system(m{1}, 0); end
end
load_system(fullfile(base, [src '.slx']));
save_system(src, fullfile(here, [mdl '.slx']));     % the loaded model is renamed to cemex_loco_system
set_param(mdl, 'Description', sprintf(['CEMEX Victorville six-axle battery locomotive (RFI #13544). ' ...
    'Parallel model of the GP40 proto system model (loco_system/voltify_loco_system, Rev E). ' ...
    'Parameters: cemex/cemex_params.m. Duty: cemex/make_cemex_cycle.m. Run: cemex/run_cemex.m.']));
save_system(mdl);
close_system(mdl, 0);
fprintf('Built %s\n', fullfile(here, [mdl '.slx']));
end
