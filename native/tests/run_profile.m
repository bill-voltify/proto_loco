function run_profile
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
evalin('base','PN.ax.Ts_fw = 1e-3;');
mdl = 'bench_native_plant';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end
T = 20;
tic;
res = solverprofiler.profileModel(mdl,'StartTime','0','StopTime',num2str(T));
w = toc;
fprintf('\n== Solver Profiler: %s, %g s simulated, wall %.1f s ==\n',mdl,T,w);

fprintf('\n-- summary --\n');
dumpAny(res.summary,'  ');

fprintf('\n-- file: %s --\n',string(res.file));
try
    S = load(res.file);
    fn = fieldnames(S);
    for k = 1:numel(fn)
        fprintf('\n[%s]\n',fn{k});
        dumpAny(S.(fn{k}),'  ');
    end
catch e
    fprintf('  could not load file: %s\n',e.message);
end
end

function dumpAny(x,pre)
    if istable(x)
        disp(x(1:min(15,height(x)),:));
    elseif isstruct(x) && isscalar(x)
        fn = fieldnames(x);
        for k = 1:numel(fn)
            v = x.(fn{k});
            if isnumeric(v) && isscalar(v)
                fprintf('%s%-34s %g\n',pre,fn{k},v);
            elseif ischar(v) || (isstring(v) && isscalar(v))
                fprintf('%s%-34s %s\n',pre,fn{k},char(v));
            elseif isstruct(v) || istable(v)
                fprintf('%s%s:\n',pre,fn{k});
                dumpAny(v,[pre '  ']);
            else
                fprintf('%s%-34s [%s %s]\n',pre,fn{k},class(v),mat2str(size(v)));
            end
        end
    elseif isstruct(x)
        fprintf('%sstruct array %s; first %d:\n',pre,mat2str(size(x)),min(10,numel(x)));
        for k = 1:min(10,numel(x))
            fprintf('%s(%d)\n',pre,k);
            dumpAny(x(k),[pre '  ']);
        end
    elseif ischar(x) || isstring(x)
        fprintf('%s%s\n',pre,char(x));
    else
        fprintf('%s[%s %s]\n',pre,class(x),mat2str(size(x)));
    end
end