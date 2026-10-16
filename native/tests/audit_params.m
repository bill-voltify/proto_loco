function audit_params
d = fullfile(pwd,'loco_system');
p = fullfile(d,'loco_system_params.m');
t = splitlines(fileread(p));
fprintf('\n== loco_system_params.m (%d lines) ==\n',numel(t));
for j = 1:numel(t), fprintf('%4d  %s\n',j,t{j}); end

b = splitlines(fileread(fullfile(d,'build_loco_system.m')));
fprintf('\n== build_loco_system.m: lines with th_ / P.th / mcp ==\n');
for j = 1:numel(b)
    if contains(b{j},{'th_','P.th','mcp','set_param'})
        fprintf('%4d  %s\n',j,b{j});
    end
end

f = fullfile(d,'faults','fault_library.csv');
fprintf('\n== fault_library.csv ==\n');
if isfile(f)
    type(f);
else
    fprintf('(not found at %s)\n',f);
end
end