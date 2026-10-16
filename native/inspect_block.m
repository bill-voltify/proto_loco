blk = 'bench_string/String1';
if ~bdIsLoaded('bench_string'), load_system(fullfile(pwd,'native','tests','bench_string.slx')); end
fprintf('\nBlock: %s\nLibrary: %s\n\n',blk,strrep(get_param(blk,'ReferenceBlock'),newline,' '));
dp = get_param(blk,'DialogParameters');
f = fieldnames(dp);
for k = 1:numel(f)
    pr = '';
    try, pr = strrep(dp.(f{k}).Prompt,newline,' '); catch, end
    v = '';
    try, v = get_param(blk,f{k}); catch, end
    if ~ischar(v), v = '<non-text>'; end
    if numel(v) > 60, v = [v(1:60) '...']; end
    fprintf('%-28s | %-50s | %s\n',f{k},pr,v);
end