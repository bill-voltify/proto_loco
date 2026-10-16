p3 = 'voltify_loco_system'; load_system(p3);
pl = [p3 '/Plant'];
ph = get_param(pl,'PortHandles');

fprintf('\n== Plant port widths ==\n');
try
    feval(p3,[],[],[],'compile');
    for i = 1:numel(ph.Inport)
        fprintf('in %d: %s\n',i,mat2str(get_param(ph.Inport(i),'CompiledPortDimensions')));
    end
    fprintf('out y: %s\n',mat2str(get_param(ph.Outport(1),'CompiledPortDimensions')));
    feval(p3,[],[],[],'term');
catch e
    fprintf('compile failed: %s\n',e.message);
    try, feval(p3,[],[],[],'term'); catch, end
end

fprintf('\n== Where y goes ==\n');
ln = get_param(ph.Outport(1),'Line');
db = get_param(ln,'DstBlockHandle'); dp = get_param(ln,'DstPortHandle');
for k = 1:numel(db)
    fprintf('%s port %d\n',get_param(db(k),'Name'),get_param(dp(k),'PortNumber'));
end

fprintf('\n== Inside Plant Inputs ==\n');
b = find_system([pl '/Plant Inputs'],'SearchDepth',1);
for i = 2:numel(b)
    fprintf('%-30s %s\n',get_param(b{i},'Name'),get_param(b{i},'BlockType'));
end

fprintf('\n== locosys .ssc files ==\n');
s = dir(fullfile(pwd,'**','+locosys','*.ssc'));
for k = 1:numel(s)
    n = numel(splitlines(fileread(fullfile(s(k).folder,s(k).name))));
    fprintf('%-35s %4d lines  %s\n',s(k).name,n,s(k).folder);
end

f = s(strcmp({s.name},'locomotive_sys.ssc'));
fprintf('\n== locomotive_sys.ssc ==\n');
type(fullfile(f.folder,f.name));