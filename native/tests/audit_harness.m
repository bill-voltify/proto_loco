function audit_harness
p3 = 'voltify_loco_system';
load_system(p3);
P = evalin('base','P');

fprintf('\n== Fault channels (name : nominal) ==\n');
fc = P.sys.fault_channels; fn = P.sys.fault_nominal;
for k = 1:numel(fc)
    if iscell(fc), nm = fc{k}; else, nm = fc(k); end
    fprintf('%2d  %-22s : %g\n',k,string(nm),fn(k));
end

fprintf('\n== Scenario outputs -> destinations ==\n');
showOut(p3,[p3 '/Scenario']);
fprintf('\n== Controls inputs <- sources ==\n');
showIn(p3,[p3 '/Controls']);
fprintf('\n== Controls outputs -> destinations ==\n');
showOut(p3,[p3 '/Controls']);
fprintf('\n== Fault Injection output -> destinations ==\n');
showOut(p3,[p3 '/Fault Injection']);

fprintf('\n== Solver ==\n');
fprintf('Solver %s  StopTime %s  MaxStep %s  ZeroCross %s\n',get_param(p3,'Solver'),get_param(p3,'StopTime'), ...
    get_param(p3,'MaxStep'),get_param(p3,'ZeroCrossControl'));

for v = {'SCN','SCN_D','FLT','LB'}
    fprintf('\n== %s ==\n',v{1});
    try
        x = evalin('base',v{1});
        if isstruct(x)
            fprintf('struct %s, fields: %s\n',mat2str(size(x)),strjoin(fieldnames(x),', '));
        else
            fprintf('class %s, size %s\n',class(x),mat2str(size(x)));
        end
    catch
        fprintf('(not in workspace)\n');
    end
end

fprintf('\n== Scripts in loco_system/ and repo root (run/regression) ==\n');
d1 = dir(fullfile(pwd,'loco_system','*.m'));
d2 = dir(fullfile(pwd,'run*.m'));
for f = [d1; d2]'
    h = '';
    try
        t = splitlines(fileread(fullfile(f.folder,f.name)));
        i = find(startsWith(strtrim(t),'%'),1);
        if ~isempty(i), h = strtrim(t{i}); end
    catch
    end
    fprintf('%-32s %s\n',f.name,h);
end
end

function showOut(m,b)
    ph = get_param(b,'PortHandles');
    for k = 1:numel(ph.Outport)
        ln = get_param(ph.Outport(k),'Line');
        if ln < 0, fprintf('  out %d -> (unconnected)\n',k); continue; end
        db = get_param(ln,'DstBlockHandle'); dp = get_param(ln,'DstPortHandle');
        nm = get_param(ln,'Name');
        for j = 1:numel(db)
            fprintf('  out %d "%s" -> %s in %d\n',k,nm,get_param(db(j),'Name'),get_param(dp(j),'PortNumber'));
        end
    end
end

function showIn(m,b)
    ph = get_param(b,'PortHandles');
    ins = find_system(b,'SearchDepth',1,'BlockType','Inport');
    for k = 1:numel(ph.Inport)
        ln = get_param(ph.Inport(k),'Line');
        nm = get_param(ins{k},'Name');
        if ln < 0, fprintf('  in %d %-12s <- (unconnected)\n',k,nm); continue; end
        sb = get_param(ln,'SrcBlockHandle'); sp = get_param(ln,'SrcPortHandle');
        fprintf('  in %d %-12s <- %s out %d\n',k,nm,get_param(sb,'Name'),get_param(sp,'PortNumber'));
    end
end