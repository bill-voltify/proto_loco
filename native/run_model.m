function out = run_model(which,varargin)
addpath(genpath(fullfile(pwd,'native')));
m = 'loco_native';
if ~bdIsLoaded(m), load_system(fullfile(pwd,'native',[m '.slx'])); end
evalin('base','native_params;');
switch lower(which)
    case 'phase3'
        assignin('base','PLANT_ID',1);
        set_param(m,'SolverType','Variable-step','Solver','daessc','MaxStep','1', ...
            'ZeroCrossControl','DisableAll');
    case 'native'
        assignin('base','PLANT_ID',2);
        evalin('base','PN.ax.Ts_fw = 1e-3;');
        set_param(m,'SolverType','Fixed-step','Solver','ode14x','FixedStep','1e-3');
    otherwise
        error('run_model: use ''phase3'' or ''native''');
end
out = sim(m,'ReturnWorkspaceOutputs','on',varargin{:});
end