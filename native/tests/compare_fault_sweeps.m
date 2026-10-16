function compare_fault_sweeps(iold,inew)
rd = fullfile(pwd,'results');
d = dir(fullfile(rd,'fault_sweep_*.mat'));
if numel(d) < 2, error('Need at least two fault_sweep_*.mat files in %s',rd); end
[~,i] = sort([d.datenum],'descend'); d = d(i);
fprintf('\n== Saved fault sweeps (1 = newest) ==\n');
for k = 1:numel(d)
    fprintf('%2d  %s   %s\n',k,d(k).name,datestr(d(k).datenum,'yyyy-mm-dd HH:MM')); %#ok<DATST>
end
if nargin < 2, inew = 1; end
if nargin < 1, iold = 2; end
fo = pick(d,iold); fn = pick(d,inew);
A = load(fullfile(rd,fo)); B = load(fullfile(rd,fn));
Ta = A.T; Tb = B.T;
fprintf('\nOLD: %s\nNEW: %s\n',fo,fn);

fprintf('\n== PE pump faults (NEW) ==\n');
pe = Tb(ismember(Tb.fault,["PE_PUMP_1OF3","PE_PUMP_FAIL","BASELINE"]),:);
pe = sortrows(pe,{'T_amb','fault'});
for k = 1:height(pe)
    fprintf('%-14s %2d C  %-8s %-10s Tchop %5.1f  Tinv %5.1f  first limit %-24s t %5s h\n', ...
        pe.fault(k),pe.T_amb(k),pe.verdict(k),pe.rel_baseline(k),pe.Tchop_max(k),pe.Tinv_max(k), ...
        string(pe.first_limit(k)),num2str(pe.t_first_limit_h(k),'%.2f'));
end

fprintf('\n== Changes OLD -> NEW (same fault, same ambient) ==\n');
n = 0; dcs = []; dis = [];
for k = 1:height(Tb)
    j = find(Ta.fault == Tb.fault(k) & Ta.T_amb == Tb.T_amb(k),1);
    if isempty(j)
        fprintf('%-18s %2d C  NEW CASE  %s %s\n',Tb.fault(k),Tb.T_amb(k),Tb.verdict(k),Tb.rel_baseline(k));
        n = n + 1;
        continue
    end
    dv = string(Ta.verdict(j)) ~= string(Tb.verdict(k));
    dr = string(Ta.rel_baseline(j)) ~= string(Tb.rel_baseline(k));
    dc = Tb.Tchop_max(k) - Ta.Tchop_max(j);
    di = Tb.Tinv_max(k) - Ta.Tinv_max(j);
    dcs(end+1) = dc; dis(end+1) = di; %#ok<AGROW>
    if dv || dr || abs(dc) > 0.3 || abs(di) > 0.3
        fprintf('%-18s %2d C  verdict %-8s -> %-8s  class %-10s -> %-10s  dTchop %+5.2f  dTinv %+5.2f\n', ...
            Tb.fault(k),Tb.T_amb(k),Ta.verdict(j),Tb.verdict(k),Ta.rel_baseline(j),Tb.rel_baseline(k),dc,di);
        n = n + 1;
    end
end
if n == 0, fprintf('No verdict or class changes, and no chopper/inverter peak moved by more than 0.3 K.\n'); end
if ~isempty(dcs)
    fprintf('\nAcross all matched cases: dTchop median %+.2f K (range %+.2f..%+.2f), dTinv median %+.2f K (range %+.2f..%+.2f)\n', ...
        median(dcs),min(dcs),max(dcs),median(dis),min(dis),max(dis));
end
end

function f = pick(d,x)
    if isnumeric(x)
        f = d(x).name;
    else
        f = char(x);
        if ~endsWith(f,'.mat'), f = [f '.mat']; end
    end
end