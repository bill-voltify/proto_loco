function run_smoke_native_plant
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
evalin('base','PN.ax.Ts_fw = 1e-3;');
P = evalin('base','P');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
mdl = 'bench_native_plant';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
add_block([lib '/Native Plant'],[mdl '/NP'],'Position',[300 50 420 350]);
assignin('base','spd_bench',[0 0; 10 0; 50 10; 60 10]);
add_block('simulink/Sources/From Workspace',[mdl '/spd'],'Position',[60 40 120 70],'VariableName','spd_bench');
V = {'grade','0';'amb','25';'trail','0';'cmd','[3 1 1 1 50e3 0]';'flt',mat2str(P.sys.fault_nominal(:)')};
for k = 1:5
    add_block('simulink/Sources/Constant',[mdl '/' V{k,1}],'Position',[60 80+50*k 120 110+50*k],'Value',V{k,2});
    add_line(mdl,[V{k,1} '/1'],sprintf('NP/%d',k+1),'autorouting','on');
end
add_line(mdl,'spd/1','NP/1','autorouting','on');
add_block('simulink/Sinks/To Workspace',[mdl '/log_y'],'Position',[500 185 560 215],'VariableName','y','SaveFormat','Timeseries');
add_line(mdl,'NP/1','log_y/1');
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','60','MaxStep','1e-2');
save_system(mdl,f);
tic; out = sim(mdl,'ReturnWorkspaceOutputs','on'); tr = toc;
Y = out.get('y'); d = squeeze(Y.Data);
if size(d,1) == 28, d = d'; end
yl = d(end,:);
nm = {'v_mph','soc','vt','ib','vlink','ia','va','te','ff','pa','pc','idc','Tc','Tb','Tcs','Tcd', ...
      'Tsup','Tchg','Tchop','Tinv','Tm','ptms','qc','qh','qb','qpe','kd','kc'};
fprintf('\n== Smoke test: Native Plant alone, 60 s (run time %.0f s) ==\n',tr);
fprintf('y width = %d\n',size(d,2));
for k = 1:28
    fprintf('%2d %-6s %12.3f\n',k,nm{k},yl(k));
end
ok = size(d,2) == 28 && yl(1) > 5 && yl(5) > 1000 && all(isfinite(yl));
if ok, fprintf('RESULT: PASS (runs, moves, DC link up)\n'); else, fprintf('RESULT: FAIL\n'); end
end