function run_overnight(mode)
if nargin < 1, mode = 'run'; end
root = pwd;
here = fullfile(root,'loco_system');
addpath(here); addpath(root); addpath(genpath(fullfile(root,'native')));
S = proto_scenarios();
idx = @(n) find(strcmp({S.name},n),1);
rd = fullfile(root,'native','results'); if ~isfolder(rd), mkdir(rd); end

if strcmpi(mode,'check')
    s = idx('S7_switch_shift_8h');
    tr = fullfile(here,'traces',[S(s).name '.csv']);
    T = 600;
    fprintf('\nPre-flight: S7 native, first %d s ...\n',T);
    tic;
    R = run_loco_native(tr,'Plant','native','Ambient_C',25,'T0_C',25,'soc0',S(s).soc0, ...
        'I_chg_bms',S(s).I_chg_bms,'Baseline','phase2','StopTime',T);
    w = toc;
    b = whos('R');
    TR = load_trace(tr,struct());
    f = TR.t_end/T;
    fprintf('Wall %.0f s for %d s simulated (%.2f x real time)\n',w,T,w/T);
    fprintf('Result size %.1f MB -> projected for full S7 (%.0f s): %.2f GB\n',b.bytes/1e6,TR.t_end,b.bytes*f/1e9);
    fprintf('Projected S7 wall time: %.1f h\n',w*f/3600);
    if b.bytes*f > 2e9
        fprintf('WARNING: projected memory > 2 GB. Tell Claude before running overnight.\n');
    else
        fprintf('Memory OK for overnight.\n');
    end
    return
end

cases = {'S4_dyncharge_3p0MW',40; 'S7_switch_shift_8h',25; 'S8_park_6h',40; 'S3_dyncharge_2p5MW',40};
stamp = datestr(now,'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
diary(fullfile(rd,['overnight_' stamp '.log']));
fprintf('\n== Overnight native vs Phase 3 started %s ==\n',datestr(now)); %#ok<TNOW1,DATST>
for k = 1:size(cases,1)
    s = idx(cases{k,1});
    fprintf('\n[%d/%d] %s at %d C  (start %s)\n',k,size(cases,1),cases{k,1},cases{k,2},datestr(now,'HH:MM')); %#ok<TNOW1,DATST>
    try
        run_regression_native(s,cases{k,2},{'soaked'},[]);
    catch e
        fprintf('CASE FAILED: %s\n',e.message);
    end
end
fprintf('\n== Overnight finished %s ==\n',datestr(now)); %#ok<TNOW1,DATST>
diary off
end