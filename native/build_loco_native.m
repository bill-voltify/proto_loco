function build_loco_native
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
assignin('base','PLANT_ID',1);
p3 = 'voltify_loco_system';
src = which([p3 '.slx']);
if isempty(src)
    evalin('base','build_loco_system;');
    src = which([p3 '.slx']);
end
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
m = 'loco_native';
dst = fullfile(pwd,'native',[m '.slx']);
if bdIsLoaded(m), close_system(m,0); end
if bdIsLoaded(p3), close_system(p3,0); end
if isfile(dst), delete(dst); end
copyfile(src,dst);
load_system(dst);

pl = [m '/Plant'];
pos = get_param(pl,'Position');
pc = get_param(pl,'PortConnectivity');
nin = 6;
srcs = cell(nin,1);
for k = 1:nin
    srcs{k} = sprintf('%s/%d',get_param(pc(k).SrcBlock,'Name'),pc(k).SrcPort + 1);
end
dsts = {};
for j = 1:numel(pc(nin+1).DstBlock)
    dsts{end+1} = sprintf('%s/%d',get_param(pc(nin+1).DstBlock(j),'Name'),pc(nin+1).DstPort(j) + 1);
end
ph = get_param(pl,'PortHandles');
for k = 1:nin, delete_line(get_param(ph.Inport(k),'Line')); end
delete_line(get_param(ph.Outport(1),'Line'));

v = [m '/PlantV'];
add_block('simulink/Ports & Subsystems/Variant Subsystem',v,'Position',pos + [0 400 0 400]);
old = find_system(v,'SearchDepth',1,'Type','block');
old = old(~strcmp(old,v));
for k = 1:numel(old), delete_block(old{k}); end
nm = {'speed_ref_mph','grade_pct','ambient_C','trailing_tons','cmd','faults'};
for k = 1:nin
    add_block('simulink/Sources/In1',[v '/' nm{k}],'Position',[20 20+50*(k-1) 50 40+50*(k-1)]);
    set_param([v '/' nm{k}],'Port',num2str(k));
end
add_block('simulink/Sinks/Out1',[v '/y'],'Position',[500 150 530 170]);
add_block(pl,[v '/Phase3'],'Position',[200 20 320 300]);
add_block([lib '/Native Plant'],[v '/Native'],'Position',[200 340 320 620]);
set_param([v '/Phase3'],'VariantControl','PLANT_ID == 1');
set_param([v '/Native'],'VariantControl','PLANT_ID == 2');
delete_block(pl);
set_param(v,'Name','Plant');
set_param([m '/Plant'],'Position',pos);
for k = 1:nin, add_line(m,srcs{k},sprintf('Plant/%d',k),'autorouting','on'); end
for j = 1:numel(dsts), add_line(m,'Plant/1',dsts{j},'autorouting','on'); end

np = [m '/Plant/Native'];
fast(np,[np '/Solver'],'1e-3',true);
fast(np,[np '/TP/Solver'],'0.1',false);
save_system(m);
fprintf('Built %s: Plant is a Variant Subsystem (PLANT_ID 1 = Phase3, 2 = Native).\n',dst);
fprintf('Plant inputs from: %s\n',strjoin(srcs,', '));
fprintf('Plant output to:   %s\n',strjoin(dsts,', '));
end

function fast(np,sb,ts,fixedcost)
    pv = {'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime',ts};
    try
        set_param(sb,pv{:});
    catch
        set_param(np,'LinkStatus','inactive');
        p = fileparts(sb);
        if ~strcmp(p,np)
            try, set_param(p,'LinkStatus','inactive'); catch, end
        end
        set_param(sb,pv{:});
        fprintf('Note: link on %s made inactive to set solver (rebuild loco_native after library changes).\n',np);
    end
    if fixedcost
        try, set_param(sb,'DoFixedCost','on','MaxNonlinIter','3'); catch, end
    end
    fprintf('%s: local Backward Euler, Ts %s s\n',sb,ts);
end