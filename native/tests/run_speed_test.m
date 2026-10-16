function run_speed_test
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
evalin('base','PN.ax.Ts_fw = 1e-3;');
mdl = 'bench_native_plant';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end
T = 20;
cases = {'normal (cached)','normal'; 'accelerator (1st, builds)','accelerator'; 'accelerator (cached)','accelerator'};
r = zeros(1,3); vend = r;
for k = 1:3
    tic;
    out = sim(mdl,'StopTime',num2str(T),'SimulationMode',cases{k,2},'ReturnWorkspaceOutputs','on');
    r(k) = toc;
    Y = out.get('y'); d = squeeze(Y.Data); if size(d,1) == 28, d = d'; end
    vend(k) = d(end,1);
    fprintf('%-28s  wall %6.1f s   ratio %5.1f x real time   v(20s) %.3f mph\n',cases{k,1},r(k),r(k)/T,vend(k));
end
fprintf('\nProjected 1500 s regression run:  normal %.0f min   accelerator %.0f min\n',r(1)/T*1500/60,r(3)/T*1500/60);
fprintf('Accelerator vs normal speed-up: %.1fx   (results match: %s)\n',r(1)/r(3),string(abs(vend(1)-vend(3)) < 1e-3));
end