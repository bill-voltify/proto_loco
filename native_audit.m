p3 = 'voltify_loco_system'; load_system(p3);
pl = [p3 '/Plant'];
ph = get_param(pl,'PortHandles');

fprintf('\n== Plant inputs (what drives them) ==\n');
ins = find_system(pl,'SearchDepth',1,'BlockType','Inport');
for i = 1:numel(ins)
    ln = get_param(ph.Inport(i),'Line');
    src = '?'; sig = '';
    if ln > 0
        src = [get_param(get_param(ln,'SrcBlockHandle'),'Name') ' port ' num2str(get_param(get_param(ln,'SrcPortHandle'),'PortNumber'))];
        sig = get_param(ln,'Name');
    end
    fprintf('%d  %-20s <- %-30s sig:"%s"\n',i,get_param(ins{i},'Name'),src,sig);
end

fprintf('\n== Blocks inside Plant ==\n');
b = find_system(pl,'SearchDepth',1);
for i = 2:numel(b)
    rb = '';
    try, rb = get_param(b{i},'ReferenceBlock'); catch, end
    sc = '';
    try, sc = get_param(b{i},'SourceFile'); catch, end
    fprintf('%-35s %-15s %s %s\n',get_param(b{i},'Name'),get_param(b{i},'BlockType'),rb,sc);
end

fprintf('\n== Plant output bus ==\n');
set_param(p3,'SimulationCommand','update');
h = get_param(ph.Outport(1),'SignalHierarchy');
printHier(h,'');
set_param(p3,'SimulationCommand','stop');

fprintf('\n== P fields ==\n');
P = evalin('base','P');
printStruct(P,'P');

function printHier(h,pre)
    for k = 1:numel(h)
        fprintf('%s%s\n',pre,h(k).SignalName);
        if ~isempty(h(k).Children), printHier(h(k).Children,[pre '  ']); end
    end
end

function printStruct(s,name)
    f = fieldnames(s);
    for k = 1:numel(f)
        v = s.(f{k});
        if isstruct(v)
            printStruct(v,[name '.' f{k}]);
        else
            fprintf('%-45s %s\n',[name '.' f{k}],mat2str(size(v)));
        end
    end
end