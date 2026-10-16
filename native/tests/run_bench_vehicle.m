addpath(genpath(fullfile(pwd,'native')));
assignin('base','trail_kg',500*907.185);
native_params;
PN.veh.v0 = 10;
assignin('base','PN',PN);

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

mdl = 'bench_vehicle';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
add_block([lib '/Vehicle'],[mdl '/Veh'],'Position',[300 100 420 220]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[mdl '/Solver'],'Position',[100 260 160 300]);
add_block('simulink/Sources/From Workspace',[mdl '/grade_cmd'],'Position',[80 100 140 130],'VariableName','grade_bench');
add_block('simulink/Sources/From Workspace',[mdl '/Fb_cmd'],'Position',[80 170 140 200],'VariableName','Fb_bench');
add_block('simulink/Sinks/To Workspace',[mdl '/v'],'Position',[500 145 560 175],'VariableName','v','SaveFormat','Timeseries');
add_line(mdl,'grade_cmd/1','Veh/1','autorouting','on');
add_line(mdl,'Fb_cmd/1','Veh/2','autorouting','on');
add_line(mdl,'Veh/1','v/1','autorouting','on');
a = get_param([mdl '/Solver'],'PortHandles'); a = [a.LConn a.RConn];
b = get_param([mdl '/Veh'],'PortHandles');
add_line(mdl,a(1),b.LConn(1),'autorouting','on');
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime','200','MaxStep','0.05');
save_system(mdl,f);

t_gr = 60; t_br = 120; t_end = 200; Fb0 = 100e3; gr0 = 1;
assignin('base','grade_bench',[0 0; t_gr 0; t_gr gr0; t_end gr0]);
assignin('base','Fb_bench',[0 0; t_br 0; t_br Fb0; t_end Fb0]);

out = sim(mdl);
Vo = out.get('v');

V = PN.veh;
dt = 1e-3; t = (0:dt:t_end)'; vr = zeros(size(t)); v = V.v0;
for k = 1:numel(t)
    vr(k) = v;
    gk = gr0*(t(k) >= t_gr);
    Fk = Fb0*(t(k) >= t_br);
    s = tanh(v/V.v_eps);
    F = V.m_tot*V.g*(V.Crr*s + gk/100) + V.k_aero*v*abs(v) + Fk*s;
    v = v - dt*F/V.m_eff;
end
vn = interp1(Vo.Time,squeeze(Vo.Data),t);
emax = max(abs(vn - vr));
dir_ok = vn(find(t>=59,1)) < V.v0;

fprintf('\n== Bench: Vehicle (loco + %.0f t trailing) vs Phase 3 vehicle.ssc ==\n',V.m_trail/1e3);
for tq = [30 60 90 120 125 140 200]
    k = find(t >= tq,1);
    fprintf('t=%4.0f s   v native %7.3f   ref %7.3f m/s\n',t(k),vn(k),vr(k));
end
fprintf('Coast slows down (direction ok): %s\n',string(dir_ok));
fprintf('Speed error max %.4f m/s\n',emax);
if ~dir_ok
    fprintf('RESULT: DIRECTION WRONG - force source sign needs flipping (tell Claude).\n');
elseif emax < 0.02
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_vehicle vs Phase 3');
subplot(2,1,1); plot(t,vn,t,vr,'--'); ylabel('v (m/s)'); legend('native','Phase 3 eq'); grid on;
xline([t_gr t_br],':',{'+1% grade','100 kN brake'});
subplot(2,1,2); plot(t,vn - vr); ylabel('error (m/s)'); xlabel('t (s)'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_vehicle_compare.png'));

evalin('base','clear trail_kg');