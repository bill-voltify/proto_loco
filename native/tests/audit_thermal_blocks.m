load_system('fl_lib');
all = find_system('fl_lib','LookUnderMasks','all','FollowLinks','on','Type','block');
th = all(contains(all,'/Thermal/') & ~contains(all,'Thermal Liquid'));
fprintf('\n== Thermal blocks in fl_lib ==\n');
for k = 1:numel(th)
    fprintf('%s\n',strrep(th{k},newline,' '));
end

want = {'Thermal Mass','Conductive Heat Transfer','Convective Heat Transfer', ...
        'Controlled Heat Flow Rate Source','Controlled Temperature Source', ...
        'Ideal Temperature Sensor','Ideal Heat Flow Sensor','Thermal Reference'};
tmp = 'tmp_thermal_audit';
if bdIsLoaded(tmp), close_system(tmp,0); end
new_system(tmp);
for k = 1:numel(want)
    h = th(endsWith(strrep(th,newline,' '),['/' want{k}]));
    if isempty(h)
        fprintf('\n-- %s: NOT FOUND\n',want{k});
        continue
    end
    b = [tmp '/b' num2str(k)];
    add_block(h{1},b,'Position',[100 100 160 160]);
    p = get_param(b,'PortHandles');
    fprintf('\n-- %s  [%s]\n',want{k},strrep(h{1},newline,' '));
    fprintf('   LConn %d  RConn %d\n',numel(p.LConn),numel(p.RConn));
    side = {'LConn','RConn'};
    for s = 1:2
        c = p.(side{s});
        for j = 1:numel(c)
            pos = get_param(c(j),'Position');
            fprintf('   %s(%d) at x=%d y=%d\n',side{s},j,pos(1),pos(2));
        end
    end
    dp = get_param(b,'DialogParameters'); fn = fieldnames(dp);
    for j = 1:numel(fn)
        if endsWith(fn{j},'_conf') || endsWith(fn{j},'_unit') || endsWith(fn{j},'_priority') ...
                || contains(fn{j},'nominal'), continue; end
        v = ''; try, v = get_param(b,fn{j}); catch, end
        if ~ischar(v), v = '<non-text>'; end
        pr = ''; try, pr = strrep(dp.(fn{j}).Prompt,newline,' '); catch, end
        fprintf('   %-22s | %-40s | %s\n',fn{j},pr,v);
    end
end
close_system(tmp,0);