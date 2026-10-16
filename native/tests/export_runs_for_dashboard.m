function export_runs_for_dashboard(includeNative)
if nargin < 1, includeNative = false; end
root = pwd;
here = fullfile(root,'loco_system');
addpath(here); addpath(root); addpath(genpath(fullfile(root,'native')));
od = fullfile(root,'native','results','dashboard_runs');
if isfolder(od), rmdir(od,'s'); end
mkdir(od);
S = proto_scenarios();
idx = @(n) find(strcmp({S.name},n),1);
L = load_fault_table(fullfile(here,'faults','fault_library.csv'));

tag = containers.Map();
tag('S1_first_move') = {'H-12','H-13'};
tag('S2_showcase1') = {'J-02B','Showcase 1'};
tag('S3_dyncharge_2p5MW') = {'J-09','Showcase 2'};
tag('S4_dyncharge_3p0MW') = {'J-09','RSK-NEW-39'};
tag('S5_cont_pull_10mph') = {'P-02'};
tag('S6_notch8_15min') = {'P-01'};
tag('S7_switch_shift_8h') = {'J-18'};
tag('S8_park_6h') = {'J-21'};

C = {};
for n = {'S1_first_move','S2_showcase1','S3_dyncharge_2p5MW','S4_dyncharge_3p0MW', ...
         'S5_cont_pull_10mph','S6_notch8_15min','S7_switch_shift_8h','S8_park_6h'}
    C(end+1,:) = {'Scenarios at 40 C',n{1},40,'soaked','',{},'phase3'};
end
for n = {'S2_showcase1','S4_dyncharge_3p0MW','S6_notch8_15min'}
    for a = [25 45]
        C(end+1,:) = {sprintf('Scenarios at %d C',a),n{1},a,'soaked','',{},'phase3'};
    end
end
fc = {'BASELINE',40; 'BASELINE',45; 'PE_FAN_FAIL',40; 'PE_PUMP_1OF3',40; 'AXLE4_CUTOUT',40; 'TSENSE_HIGH_5K',40};
for k = 1:size(fc,1)
    C(end+1,:) = {'Fault cases (3 h trace, onset 0.5 h)','fault_test_3h',fc{k,2},'precond',fc{k,1},{},'phase3'};
end
if includeNative
    C(end+1,:) = {'Native vs Phase 3','S4_dyncharge_3p0MW',40,'soaked','',{},'native'};
end

P0 = loco_system_params(struct('baseline','poc'));
A = struct('baseline','poc','generated',char(datetime('now','Format','yyyy-MM-dd HH:mm')));
for g = {'batt','dcl','ax','veh','chg','aux','lcc','th','lim','bms','sys'}
    if isfield(P0,g{1}), A.(g{1}) = keepSmall(P0.(g{1})); end
end
writeJson(fullfile(od,'assumptions.json'),A);

ix = {};
for k = 1:size(C,1)
    grp = C{k,1}; nm = C{k,2}; Ta = C{k,3}; ic = C{k,4}; fid = C{k,5}; plant = C{k,7};
    if strcmp(nm,'fault_test_3h')
        tr = fullfile(here,'traces','fault_test_3h.csv');
        soc0 = 0.9; Ichg = 1884; T0 = 25; ms = 1;
        if strcmp(fid,'BASELINE')
            F = L([],:); flist = {};
        else
            F = L(L.fault_id == fid,:);
            F.enabled(:) = 1; F.t_start_s(:) = 1800; F.t_end_s(:) = 1e9;
            flist = cell(height(F),1);
            for j = 1:height(F)
                flist{j} = struct('fault_id',char(F.fault_id(j)),'channel',char(F.channel(j)), ...
                    'value',F.active_value(j),'t_start_s',1800);
            end
        end
        title = sprintf('%s, %d C ambient, fault trace', strrep(fid,'_',' '), Ta);
        id = sprintf('F_%s_%dC',fid,Ta);
        tg = {'C-21','FMEA'};
    else
        s = idx(nm);
        tr = fullfile(here,'traces',[nm '.csv']);
        soc0 = S(s).soc0; Ichg = S(s).I_chg_bms; ms = S(s).max_step;
        T0 = Ta; if strcmp(ic,'precond'), T0 = 25; end
        F = L([],:); flist = {};
        title = sprintf('%s, %d C ambient, %s', strrep(nm,'_',' '), Ta, ic);
        id = sprintf('S_%s_%dC_%s',nm,Ta,plant);
        if isKey(tag,nm), tg = tag(nm); else, tg = {}; end
    end
    fprintf('[%2d/%2d] %-48s ... ',k,size(C,1),title);
    args = {'Plant',plant,'Faults',F,'Ambient_C',Ta,'T0_C',T0,'soc0',soc0,'I_chg_bms',Ichg, ...
            'MaxStep',ms,'Baseline','poc'};
    R = [];
    try
        txt = evalc('R = run_loco_native(tr,args{:});');
    catch e
        fprintf('FAILED: %s\n',e.message);
        continue
    end
    nw = count(txt,'encountering difficulty');
    TR = load_trace(tr,struct('ambient_C',Ta));
    [t,y] = getY(R.out);
    tend = t(end);
    dt = 1; if tend > 3600, dt = 5; end
    tg2 = (0:dt:floor(tend))';
    Y = interp1(t,y,tg2);
    ch = struct();
    ch.t = tg2';
    ch.v_ref_mph = r2(interp1(TR.SCN(:,1),TR.SCN(:,2),tg2,'linear','extrap'),2);
    ch.grade_pct = r2(interp1(TR.SCN(:,1),TR.SCN(:,3),tg2,'previous','extrap'),2);
    ch.ambient_C = r2(interp1(TR.SCN(:,1),TR.SCN(:,4),tg2,'linear','extrap'),1);
    ch.wire_kW = r2(interp1(TR.SCN(:,1),TR.SCN(:,6),tg2,'previous','extrap'),0);
    ch.state_req = interp1(TR.SCN_D(:,1),TR.SCN_D(:,2),tg2,'previous','extrap')';
    nm28 = {'v_mph',2,1;'soc',4,1;'vt_V',1,1;'ib_A',0,1;'vlink_V',1,1;'ia_A',0,1;'va_V',1,1; ...
            'te_kN',2,1e-3;'ff_kN',2,1e-3;'pa_kW',1,1e-3;'pc_kW',1,1e-3;'idc_A',0,1; ...
            'Tc_C',2,-1;'Tb_C',2,-1;'Tcs_C',2,-1;'Tcd_C',2,-1;'Tsup_C',2,-1;'Tchg_C',2,-1; ...
            'Tchop_C',2,-1;'Tinv_C',2,-1;'Tm_C',2,-1;'ptms_kW',2,1e-3;'qc_kW',2,1e-3; ...
            'qh_kW',2,1e-3;'qb_kW',2,1e-3;'qpe_kW',2,1e-3;'kd',3,1;'kc',3,1};
    for j = 1:28
        v = Y(:,j);
        if nm28{j,3} < 0, v = v - 273.15; else, v = v*nm28{j,3}; end
        ch.(nm28{j,1}) = r2(v,nm28{j,2});
    end
    meta = struct('id',id,'group',grp,'title',title,'trace',nm,'plant',plant,'baseline','poc', ...
        'ambient_C',Ta,'T0_C',T0,'start',ic,'soc0',soc0,'I_chg_bms_A',Ichg, ...
        'trailing_tons',max(TR.SCN(:,5)),'t_end_s',tend,'dt_s',dt,'tags',{tg}, ...
        'faults',{flist},'solver_warnings',nw,'wall_s',round(R.sim_seconds,1), ...
        'metrics',keepSmall(R.metrics));
    file = [id '.json'];
    writeJson(fullfile(od,file),struct('meta',meta,'ch',ch));
    ix{end+1} = struct('id',id,'group',grp,'title',title,'file',file,'ambient_C',Ta, ...
        'start',ic,'verdict',getf(R.metrics,'verdict'),'tags',{tg},'t_end_s',tend); %#ok<AGROW>
    d = dir(fullfile(od,file));
    fprintf('%s  %.0f kB  (%d solver warn)\n',string(getf(R.metrics,'verdict')),d.bytes/1e3,nw);
end
writeJson(fullfile(od,'index.json'),struct('runs',{ix}));
zf = fullfile(root,'native','results','dashboard_runs.zip');
zip(zf,'*',od);
d = dir(zf);
fprintf('\nWrote %d runs to %s\nZip: %s (%.1f MB)\n',numel(ix),od,zf,d.bytes/1e6);
end

function v = getf(s,f)
    if isstruct(s) && isfield(s,f), v = s.(f); else, v = ''; end
end

function x = r2(v,n)
    x = round(v(:)',n);
end

function o = keepSmall(s)
    o = struct();
    if ~isstruct(s), return; end
    fn = fieldnames(s);
    for k = 1:numel(fn)
        v = s.(fn{k});
        if (isnumeric(v) || islogical(v)) && numel(v) <= 64
            o.(fn{k}) = double(v);
        elseif ischar(v) || (isstring(v) && isscalar(v))
            o.(fn{k}) = char(v);
        elseif iscellstr(v) && numel(v) <= 32
            o.(fn{k}) = v;
        end
    end
end

function writeJson(f,s)
    fid = fopen(f,'w');
    fwrite(fid,jsonencode(s),'char');
    fclose(fid);
end

function [t,y] = getY(out)
    y = []; t = [];
    v = out.who;
    for k = 1:numel(v)
        s = out.get(v{k});
        try
            if isa(s,'timeseries')
                dd = squeeze(s.Data);
                if any(size(dd) == 28), y = dd; t = s.Time; break; end
            elseif isa(s,'Simulink.SimulationData.Dataset')
                for j = 1:s.numElements
                    vv = s.getElement(j).Values;
                    if isa(vv,'timeseries')
                        dd = squeeze(vv.Data);
                        if any(size(dd) == 28), y = dd; t = vv.Time; break; end
                    end
                end
                if ~isempty(y), break; end
            end
        catch
        end
    end
    if isempty(y), error('y (28 channels) not found in simulation output'); end
    if size(y,1) == 28 && size(y,2) ~= 28, y = y'; end
    [t,iu] = unique(t,'last'); y = y(iu,:);
end