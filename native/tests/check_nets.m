mdl = 'bench_trb';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end

L = find_system(mdl,'SearchDepth',1,'FindAll','on','Type','line');
E = []; ports = [];
for k = 1:numel(L)
    l = L(k);
    s = get_param(l,'SrcPortHandle'); d = get_param(l,'DstPortHandle');
    pts = [s(:); d(:)]; pts = pts(pts > 0);
    for j = 1:numel(pts)
        if strcmp(get_param(pts(j),'PortType'),'connection')
            E(end+1,:) = [l pts(j)];
            ports(end+1) = pts(j);
        end
    end
    pa = get_param(l,'LineParent');
    if pa > 0, E(end+1,:) = [l pa]; end
    ch = get_param(l,'LineChildren');
    for j = 1:numel(ch), E(end+1,:) = [l ch(j)]; end
end

nodes = unique(E(:));
[~,a] = ismember(E(:,1),nodes); [~,b] = ismember(E(:,2),nodes);
c = conncomp(graph(a,b,[],numel(nodes)));
isPort = ismember(nodes,ports);

fprintf('\n== Physical nets in %s ==\n',mdl);
n = 0;
for k = unique(c)
    m = (c(:) == k) & isPort;
    if ~any(m), continue; end
    n = n + 1;
    names = arrayfun(@plabel,nodes(m),'UniformOutput',false);
    fprintf('NET %d: %s\n',n,strjoin(sort(names),', '));
end

function s = plabel(p)
    b = get_param(p,'Parent');
    ph = get_param(b,'PortHandles');
    nm = strrep(get_param(b,'Name'),newline,' ');
    k = find(ph.LConn == p);
    if ~isempty(k)
        s = sprintf('%s:L%d',nm,k);
    else
        k = find(ph.RConn == p);
        s = sprintf('%s:R%d',nm,k);
    end
    if numel(nm) == 2 && nm(1) == 'S'
        if endsWith(s,'R1'), s = [nm ':pos']; end
        if endsWith(s,'R2'), s = [nm ':neg']; end
    end
end