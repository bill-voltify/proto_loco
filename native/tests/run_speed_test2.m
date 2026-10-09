function run_speed_test2
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
evalin('base','PN.ax.Ts_fw = 1e-3;');
src = fullfile(pwd,'native','tests','bench_native_plant.slx');
mdl = 'bench_native_speed';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded('bench_native_plant'), close_system('bench_native_plant',0); end
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
copyfile(src,f);
load_system(f);
n = breakLinks(mdl);
fprintf('Broke %d library links in the test copy.\n',n);
se = [mdl '/NP/Solver'];
st = [mdl '/NP/TP/Solver'];
T = 20; tg = (0:0.1:T)';
cfg = {'A variable-step (baseline)','var'; 'B local Backward Euler 1 ms','be'; 'C local Partitioning 1 ms','part'};
ch = [1 4 5 6 13]; cn = {'v_mph','ib','vlink','ia','Tc'};
Yb = [];
for k = 1:3
    try
        setSolver(se,st,cfg{k,2});
        tic;
        out = sim(mdl,'StopTime',num2str(T),'SimulationMode','accelerator','ReturnWorkspaceOutputs','on');
        w = toc;
        Y = out.get('y'); d = squeeze(Y.Data); if size(d,1) == 28, d = d'; end
        yi = interp1(Y.Time,d(:,ch),tg);
        fprintf('\n%-30s wall %6.1f s   ratio %5.2f x real time   1500 s run ~ %.0f min\n',cfg{k,1},w,w/T,w/T*1500/60);
        if k == 1
            Yb = yi;
        else
            for j = 1:numel(ch)
                fprintf('   %-6s max |diff| vs baseline %10.4f   (baseline end %10.3f)\n',cn{j},max(abs(yi(:,j)-Yb(:,j))),Yb(end,j));
            end
        end
    catch e
        fprintf('\n%-30s FAILED: %s\n',cfg{k,1},e.message);
    end
end
end

function setSolver(se,st,mode)
    switch mode
        case 'var'
            set_param(se,'UseLocalSolver','off');
            set_param(st,'UseLocalSolver','off');
        case 'be'
            set_param(se,'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime','1e-3');
            set_param(st,'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime','0.1');
        case 'part'
            set_param(se,'UseLocalSolver','on','LocalSolverChoice','NE_PARTITIONING_ADVANCER','LocalSolverSampleTime','1e-3');
            set_param(st,'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime','0.1');
    end
end

function n = breakLinks(mdl)
    n = 0;
    while true
        b = find_system(mdl,'LookUnderMasks','all','FollowLinks','on','LinkStatus','resolved');
        b = b(startsWith(get_param(b,'ReferenceBlock'),'loco_native_lib'));
        if isempty(b), break; end
        [~,i] = min(cellfun(@numel,b));
        set_param(b{i},'LinkStatus','inactive');
        n = n + 1;
    end
end