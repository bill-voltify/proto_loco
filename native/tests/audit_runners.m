function audit_runners
d = fullfile(pwd,'loco_system');
F = {'run_loco_system.m','run_regression_phase2.m','run_fault_sweep.m','load_trace.m'};
for k = 1:numel(F)
    p = fullfile(d,F{k});
    if ~isfile(p), p = fullfile(pwd,F{k}); end
    if ~isfile(p), fprintf('\n== %s: NOT FOUND ==\n',F{k}); continue; end
    t = splitlines(fileread(p));
    fprintf('\n== %s (%d lines) ==\n',F{k},numel(t));
    n = min(numel(t),120);
    for j = 1:n
        fprintf('%4d  %s\n',j,t{j});
    end
    if numel(t) > n, fprintf('  ... (%d more lines)\n',numel(t)-n); end
end
fprintf('\n== Files mentioning voltify_loco_system ==\n');
f = [dir(fullfile(d,'*.m')); dir(fullfile(pwd,'*.m'))];
for k = 1:numel(f)
    t = fileread(fullfile(f(k).folder,f(k).name));
    if contains(t,'voltify_loco_system')
        fprintf('  %s\n',f(k).name);
    end
end
end