function run_speed_test3
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
evalin('base','PN.ax.Ts_fw = 1e-3;');
src = fullfile(pwd,'native','tests','bench_native_plant.slx');
mdl = 'bench_native_speed';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
for m = {'bench_native_plant',mdl}
    if bdIsLoaded(m{1}), close_system(m{1},0); end
end
if isfile(f), delete(f); end
copyfile(src,f);
load_system(f);
breakLinks(mdl);
se = [mdl '/NP/Solver'];
st = [mdl '/NP/TP/Solver'];
T = 20; tg = (0:0.01:T)';
ch = [1 4 5 6 13]; cn = {'v_mph','ib','vlink','ia','Tc'};
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
bf = fullfile(rd,'baseline_speed.mat');

if isfile(bf)
    S = load(bf); Yb = S.Yb; wb = S.wb;
    fprintf('Baseline loaded from file (wall %.1f s).\n',wb);
else
    set_param(se,'UseLocalSolver','off'); set_param(st,'UseLocalSolver','off');
    set_param(mdl,'SolverType','Variable-step','Solver','daessc','MaxStep','1e-3');
    tic; out = sim(mdl,'StopTime',num2str(T),'SimulationMode','accelerator','ReturnWorkspaceOutputs','on'); wb = toc;
    Yb = getY(out,ch,tg);
    save(bf,'Yb','wb');
    fprintf('Baseline (variable-step, accelerator): wall %.1f s, saved.\n',wb);
end

set_param(se,'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime','1e-3');
set_param(st,'UseLocalSolver','on','LocalSolverChoice','NE_BACKWARD_EULER_ADVANCER','LocalSolverSampleTime','0.1');
try, set_param(se,'DoFixedCost','on','MaxNonlinIter','3'); catch e, fprintf('FixedCost not set: %s\n',e.message); end
set_param(mdl,'SolverType','Fixed-step','Solver','ode14x','FixedStep','1e-3');
fprintf('Global solver: ode14x, fixed 1 ms\n');

try
    [sz,~,xs] = feval(mdl,[],[],[],0);
    nc = sz(1);
    fprintf('\nContinuous states outside local solvers: %d\n',nc);
    if nc > 0
        own = unique(regexprep(xs(1:nc),'\(.*$',''));
        for k = 1:min(20,numel(own)), fprintf('   %s\n',own{k}); end
    end
    feval(mdl,[],[],[],'term');
catch e
    fprintf('State listing failed: %s\n',e.message);
    try, feval(mdl,[],[],[],'term'); catch, end
end

modes = {'D fixed-step 1 ms, normal','normal'; 'E fixed-step 1 ms, accelerator','accelerator'};
for k = 1:2
    try
        tic;
        out = sim(mdl,'StopTime',num2str(T),'SimulationMode',modes{k,2},'ReturnWorkspaceOutputs','on');
        w = toc;
        yi = getY(out,ch,tg);
        fprintf('\n%-32s wall %6.1f s   ratio %5.2f x real time   1500 s run ~ %.1f min   speed-up %.1fx\n', ...
            modes{k,1},w,w/T,w/T*1500/60,wb/w);
        for j = 1:numel(ch)
            fprintf('   %-6s max |diff| %10.4f   rms %10.4f   (baseline end %10.3f)\n',cn{j}, ...
                max(abs(yi(:,j)-Yb(:,j))),sqrt(mean((yi(:,j)-Yb(:,j)).^2)),Yb(end,j));
        end
    catch e
        fprintf('\n%-32s FAILED: %s\n',modes{k,1},e.message);
    end
end
end

function yi = getY(out,ch,tg)
    Y = out.get('y'); d = squeeze(Y.Data); if size(d,1) == 28, d = d'; end
    [tu,iu] = unique(Y.Time,'last');
    yi = interp1(tu,d(iu,ch),tg);
end

function breakLinks(mdl)
    while true
        b = find_system(mdl,'LookUnderMasks','all','FollowLinks','on','LinkStatus','resolved');
        b = b(startsWith(get_param(b,'ReferenceBlock'),'loco_native_lib'));
        if isempty(b), break; end
        [~,i] = min(cellfun(@numel,b));
        set_param(b{i},'LinkStatus','inactive');
    end
end