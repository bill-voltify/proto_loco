repo = pwd;
assert(isfolder(fullfile(repo,'.git')),'Run from proto_loco root');
d = fullfile(repo,'native');
for p = {'','lib','tests','results'}
    if ~isfolder(fullfile(d,p{1})), mkdir(fullfile(d,p{1})); end
end
addpath(genpath(repo));
mdl = 'loco_native';
if bdIsLoaded(mdl), close_system(mdl,0); end
if ~isfile(fullfile(d,[mdl '.slx']))
    new_system(mdl);
    load_system('nesl_utility');
    add_block('nesl_utility/Solver Configuration',[mdl '/Solver Configuration'],'Position',[40 40 100 80]);
    set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','600');
    set_param(mdl,'SimscapeLogType','all','SimscapeLogName','simlog_native','SimscapeLogDecimation',10);
    save_system(mdl,fullfile(d,[mdl '.slx'])); close_system(mdl);
end
fid = fopen(fullfile(d,'run_model.m'),'w');
fprintf(fid,['function out = run_model(which,varargin)\n' ...
 'switch lower(which)\n case ''phase3'', mdl=''voltify_loco_system'';\n case ''native'', mdl=''loco_native'';\n' ...
 ' otherwise, error(''phase3 | native'');\nend\nout = sim(mdl,varargin{:});\nend\n']);
fclose(fid);

p3 = 'voltify_loco_system'; load_system(p3);
fprintf('\n== PreLoadFcn ==\n%s\n== InitFcn ==\n%s\n',get_param(p3,'PreLoadFcn'),get_param(p3,'InitFcn'));
top = find_system(p3,'SearchDepth',1,'BlockType','SubSystem');
fprintf('\n== Top subsystems ==\n');
for i = 1:numel(top)
    ph = get_param(top{i},'PortHandles');
    fprintf('%-45s in:%d out:%d L:%d R:%d\n',top{i},numel(ph.Inport),numel(ph.Outport),numel(ph.LConn),numel(ph.RConn));
end
v = Simulink.findVars(p3);
fprintf('\n== %d workspace vars ==\n',numel(v));
fprintf('%s | ',v.Name); fprintf('\n');