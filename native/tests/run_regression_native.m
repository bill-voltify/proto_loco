function T = run_regression_native(scn_pick, ambients, ic_list, stop_s)
root = pwd;
here = fullfile(root,'loco_system');
addpath(here); addpath(root); addpath(genpath(fullfile(root,'native')));
S = proto_scenarios();

if nargin == 0
    fprintf('\n== Scenarios available (native runs at ~0.5x real time) ==\n');
    fprintf('%3s %-22s %10s %14s %8s\n','#','name','t_end (s)','native est.','soc0');
    for s = 1:numel(S)
        TR = load_trace(fullfile(here,'traces',[S(s).name '.csv']),struct());
        fprintf('%3d %-22s %10.0f %11.1f min %8.2f\n',s,S(s).name,TR.t_end,0.5*TR.t_end/60,S(s).soc0);
    end
    fprintf('\nUsage: T = run_regression_native([scenario #s], [ambients C], {''soaked''|''precond''}, stop_s)\n');
    T = [];
    return
end
if nargin < 2 || isempty(ambients), ambients = 25; end
if nargin < 3 || isempty(ic_list), ic_list = {'soaked'}; end
if nargin < 4, stop_s = []; end

rows = [];
for ic = 1:numel(ic_list)
    for s = scn_pick(:)'
        for a = ambients(:)'
            T0 = a; if strcmp(ic_list{ic},'precond'), T0 = 25; end
            tr = fullfile(here,'traces',[S(s).name '.csv']);
            args = {'Ambient_C',a,'T0_C',T0,'soc0',S(s).soc0,'I_chg_bms',S(s).I_chg_bms, ...
                'MaxStep',S(s).max_step,'Baseline','phase2','StopTime',stop_s};
            fprintf('%-20s %3d C %-7s phase3 ... ',S(s).name,a,ic_list{ic});
            row = struct('scenario',string(S(s).name),'ic',string(ic_list{ic}),'T_amb',a);
            try
                R3 = []; RN = [];
                txt3 = evalc('R3 = run_loco_native(tr,''Plant'',''phase3'',args{:});');
                n3 = count(txt3,'encountering difficulty');
                fprintf('%.0f s (%d solver warn) | native ... ',R3.sim_seconds,n3);
                txtN = evalc('RN = run_loco_native(tr,''Plant'',''native'',args{:});');
                nN = count(txtN,'encountering difficulty');
                fprintf('%.0f s (%d solver warn) | ',RN.sim_seconds,nN);
                M3 = R3.metrics; MN = RN.metrics;
                row.verdict_p3 = string(M3.verdict); row.verdict_nat = string(MN.verdict);
                row.dTcell_max = MN.Tcell_max - M3.Tcell_max;
                row.dTsup_max  = MN.Tsup_max  - M3.Tsup_max;
                row.dTcond_max = MN.Tcond_max - M3.Tcond_max;
                row.dsoc_end   = MN.soc_end   - M3.soc_end;
                [tg,y3] = getY(R3.out); [~,yn] = getY(RN.out,tg);
                row.dv_rms_mph = sqrt(mean((yn(:,1)-y3(:,1)).^2,'omitnan'));
                row.dib_rms_A  = sqrt(mean((yn(:,4)-y3(:,4)).^2,'omitnan'));
                row.p3_solver_warn = n3; row.nat_solver_warn = nN;
                row.wall_p3 = R3.sim_seconds; row.wall_nat = RN.sim_seconds;
                row.pass = row.verdict_p3 == row.verdict_nat && abs(row.dTcell_max) < 0.5 && ...
                    abs(row.dTsup_max) < 1.0 && abs(row.dsoc_end) < 0.01 && row.dv_rms_mph < 0.1;
            catch ME
                row.verdict_p3 = "ERROR"; row.verdict_nat = ""; row.dTcell_max = NaN; row.dTsup_max = NaN;
                row.dTcond_max = NaN; row.dsoc_end = NaN; row.dv_rms_mph = NaN; row.dib_rms_A = NaN;
                row.p3_solver_warn = NaN; row.nat_solver_warn = NaN;
                row.wall_p3 = NaN; row.wall_nat = NaN; row.pass = false;
                fprintf('ERROR: %s\n',ME.message);
            end
            fprintf('%s vs %s  dTcell %.2f  dSOC %.4f  dv_rms %.3f  dib_rms %.1f  pass=%d\n', ...
                row.verdict_p3,row.verdict_nat,row.dTcell_max,row.dsoc_end,row.dv_rms_mph,row.dib_rms_A,row.pass);
            rows = [rows; struct2table(row,'AsArray',true)]; %#ok<AGROW>
        end
    end
end
T = rows;
fprintf('\nNative vs Phase 3: %d / %d pass\n',sum(T.pass),height(T));
rd = fullfile(root,'native','results'); if ~isfolder(rd), mkdir(rd); end
fn = fullfile(rd,['regression_native_vs_p3_' datestr(now,'yyyymmdd_HHMM') '.csv']); %#ok<TNOW1,DATST>
writetable(T,fn);
fprintf('Saved %s\n',fn);
end

function [tg,y] = getY(out,tg)
    d = []; t = [];
    v = out.who;
    for k = 1:numel(v)
        s = out.get(v{k});
        try
            if isa(s,'timeseries')
                dd = squeeze(s.Data);
                if any(size(dd) == 28), d = dd; t = s.Time; break; end
            elseif isa(s,'Simulink.SimulationData.Dataset')
                for j = 1:s.numElements
                    vv = s.getElement(j).Values;
                    if isa(vv,'timeseries')
                        dd = squeeze(vv.Data);
                        if any(size(dd) == 28), d = dd; t = vv.Time; break; end
                    end
                end
                if ~isempty(d), break; end
            end
        catch
        end
    end
    if isempty(d), error('y (28 channels) not found in simulation output'); end
    if size(d,1) == 28 && size(d,2) ~= 28, d = d'; end
    [t,iu] = unique(t,'last'); d = d(iu,:);
    if nargin < 2 || isempty(tg), tg = (0:1:t(end))'; end
    y = interp1(t,d,tg);
end