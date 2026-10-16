function RUN = run_loco_native(trace, varargin)
root = pwd;
here = fullfile(root,'loco_system');
addpath(here); addpath(root); addpath(genpath(fullfile(root,'native')));
p = inputParser;
p.addParameter('Plant','native');
p.addParameter('Faults',fullfile(here,'faults','none.csv'));
p.addParameter('Budget',fullfile(here,'load_budget.csv'));
p.addParameter('Ambient_C',[]);
p.addParameter('AmbientOffset_C',0);
p.addParameter('T0_C',[]);
p.addParameter('soc0',0.9);
p.addParameter('I_chg_bms',1884);
p.addParameter('bms','jinko');
p.addParameter('MaxStep',1);
p.addParameter('Plot',false);
p.addParameter('Silent',true);
p.addParameter('Baseline','poc');
p.addParameter('UseBudget',false);
p.addParameter('StopTime',[]);
p.addParameter('Decimation',100);
p.parse(varargin{:});
o = p.Results;

tf = char(trace); if ~isfile(tf), tf = fullfile(here,tf); end
TR = load_trace(tf,struct('ambient_C',o.Ambient_C,'ambient_offset_C',o.AmbientOffset_C));
if istable(o.Faults), F = load_fault_table(o.Faults);
else, ff = char(o.Faults); if ~isfile(ff), ff = fullfile(here,ff); end, F = load_fault_table(ff); end
P = loco_system_params(struct('T_amb_C',TR.ambient0_C,'T0_C',o.T0_C,'soc0',o.soc0, ...
    'I_chg_bms',o.I_chg_bms,'bms',o.bms,'baseline',o.Baseline));
if o.UseBudget, TR.SCN(:,7) = -1; end
FLT = build_fault_matrix(F,TR.t_end,P);
B = load_budget_table(o.Budget);

tons = TR.SCN(:,5);
if numel(unique(tons)) > 1
    warning('run_loco_native: trailing tons vary in trace (%g..%g); native uses max (NAT-22).',min(tons),max(tons));
end
assignin('base','P',P);
assignin('base','trail_kg',max(tons)*907.185);
evalin('base','native_params;');
PN = evalin('base','PN');
evalin('base','clear trail_kg');
PN.ax.Ts_fw = 1e-3;

m = 'loco_native';
if ~bdIsLoaded(m), load_system(fullfile(root,'native',[m '.slx'])); end
tend = TR.t_end;
if ~isempty(o.StopTime), tend = min(tend,o.StopTime); end
in = Simulink.SimulationInput(m);
in = in.setVariable('P',P);
in = in.setVariable('PN',PN);
in = in.setVariable('SCN',TR.SCN);
in = in.setVariable('SCN_D',TR.SCN_D);
in = in.setVariable('FLT',FLT);
in = in.setVariable('LB',B.LB);
in = in.setVariable('LBmov',B.LBmov);
in = in.setVariable('LBbus',B.LBbus);
in = in.setVariable('LBeff',B.LBeff);
switch lower(o.Plant)
    case 'native'
        id = 2;
        in = in.setModelParameter('SolverType','Fixed-step','Solver','ode14x','FixedStep','1e-3', ...
            'StopTime',num2str(tend));
        if o.Decimation > 1
            ws = warning('off','all');
            tw = find_system(m,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace');
            warning(ws);
            for k = 1:numel(tw)
                try, in = in.setBlockParameter(tw{k},'Decimation',num2str(o.Decimation)); catch, end
            end
        end
    case 'phase3'
        id = 1;
        in = in.setModelParameter('SolverType','Variable-step','Solver','daessc', ...
            'MaxStep',num2str(o.MaxStep),'ZeroCrossControl','DisableAll','StopTime',num2str(tend));
    otherwise
        error('Plant must be ''native'' or ''phase3''');
end
assignin('base','PLANT_ID',id);
in = in.setVariable('PLANT_ID',id);
tic;
out = sim(in);
w = toc;
if ~isempty(out.ErrorMessage), error(out.ErrorMessage); end
RUN = report_loco_run(out,TR,F,B,P,o.Plot,o.Silent);
RUN.sim_seconds = w;
RUN.options = o;
RUN.plant = string(o.Plant);
RUN.out = out;
end