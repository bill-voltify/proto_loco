function RUN = report_loco_run(out, TR, F, B, P, do_plot, silent)
% REPORT_LOCO_RUN  Standard report for one system-model run: verdict, time in state,
% energy by source and by load, faults applied. Returns RUN struct (R = plant signals).
if nargin < 6, do_plot = true; end
if nargin < 7, silent = false; end
R = proto_unpack(out.Y);
[~, iu] = unique(R.t, 'last');
f = fieldnames(R);
for k = 1:numel(f)
    if numel(R.(f{k})) == numel(R.t) && ~strcmp(f{k}, 't'), R.(f{k}) = R.(f{k})(iu); end
end
R.t = R.t(iu);
t = R.t;
SYS = ts_data(out.SYS, t);
LOADS = ts_data(out.LOADS, t);
BUSES = ts_data(out.BUSES, t);
R.st = SYS(:,1); R.hv = SYS(:,2); R.tms = SYS(:,3); R.trac = SYS(:,4);
R.P_aux_cmd = SYS(:,5); R.P_chg_cmd = SYS(:,6);
R.v_ref = interp1(TR.SCN(:,1), TR.SCN(:,2), t, 'linear', 'extrap');
R.ambient = interp1(TR.SCN(:,1), TR.SCN(:,4), t, 'linear', 'extrap');

% verdict using the Phase 2 rules
U = [t, R.v_ref, interp1(TR.SCN(:,1), TR.SCN(:,3), t), R.P_aux_cmd, R.P_chg_cmd];
scn = struct('name', char(TR.name), 'speed_check', true);
M = eval_thermal_run(R, P, scn, U);

% time in state
dt = [diff(t); 0];
names = P.sys.states;
tis = zeros(numel(names), 1);
for k = 1:numel(names), tis(k) = sum(dt(round(R.st) == k - 1))/3600; end
RUN.time_in_state = table(string(names(:)), tis, 'VariableNames', {'state','hours'});

% energy
E.bat_out_kWh = trapz(t, max(R.p_bat, 0))/3.6e6;
E.bat_in_kWh = trapz(t, -min(R.p_bat, 0))/3.6e6;
E.tms_kWh = trapz(t, R.p_tms)/3.6e6;
E.aux_budget_kWh = trapz(t, R.P_aux_cmd)/3.6e6;
E.charger_kWh = trapz(t, max(R.p_chg, 0))/3.6e6;
E.traction_kWh = max(E.bat_out_kWh - E.bat_in_kWh + E.charger_kWh - E.tms_kWh - E.aux_budget_kWh, 0);
RUN.energy = E;
eload = trapz(t, LOADS, 1)'/3.6e6;
RUN.energy_by_load = table(B.ids, B.names, string(P.sys.buses(B.LBbus))', eload, ...
    'VariableNames', {'load_id','name','bus','kWh'});
RUN.energy_by_bus = table(string(P.sys.buses(:)), (trapz(t, BUSES, 1)/3.6e6)', 'VariableNames', {'bus','kWh'});
RUN.faults = F(F.enabled > 0, :);
RUN.metrics = M;
RUN.R = R;
RUN.trace = TR;

if ~silent
    fprintf('\n=== %s ===\n', TR.name);
    fprintf('Verdict: %s  %s\n', M.verdict, M.limit);
    fprintf('Cell %.1f..%.1f C | PE supply max %.1f C | inverter %.1f C | condenser %.1f C | motor %.1f C\n', ...
        M.Tcell_min, M.Tcell_max, M.Tsup_max, M.Tinv_out_max, M.Tcond_max, M.Tmotor_max);
    fprintf('SOC %.1f%% -> %.1f%% | battery out %.0f kWh, in %.0f kWh | TMS %.0f kWh | aux budget %.0f kWh\n', ...
        100*R.soc(1), 100*R.soc(end), E.bat_out_kWh, E.bat_in_kWh, E.tms_kWh, E.aux_budget_kWh);
    if height(RUN.faults) > 0
        fprintf('Faults applied: %s\n', strjoin(RUN.faults.fault_id, ', '));
    end
    disp(RUN.time_in_state);
end
if do_plot, plot_loco_run(RUN, P); end
end

function D = ts_data(ts, t)
d = squeeze(ts.Data);
if size(d, 1) ~= numel(ts.Time), d = d.'; end
[tt, iu] = unique(ts.Time, 'last');
D = interp1(tt, d(iu, :), t, 'previous', 'extrap');
end
