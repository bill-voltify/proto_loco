% RUN_CSX4091_BASELINE  Replay CSX4091 Jacksonville yard duty (Aug 26-27 2026) in Phase 3.
% Place CSX4091_20260826_peak2h.csv and CSX4091_20260826_yard.csv in loco_system/traces/
% Run from the repo root (proto_loco) or from loco_system.
% Rev 2026-10-15: regen off (prototype has no regen), T0_C = 25, full day enabled.

if ~isfolder('traces') && isfolder('loco_system'), cd loco_system; end
assert(isfolder('traces'), 'Run from proto_loco or proto_loco/loco_system');

cases = {
    'peak2h', 'traces/CSX4091_20260826_peak2h.csv',  78.4
    'yard',   'traces/CSX4091_20260826_yard.csv',   331.1
    };
runFull = true;

soc0  = 0.90;
T0_C  = 25;
regen = false;

if ~isfile('voltify_loco_system.slx')
    build_loco_system
end

results = struct();
for k = 1:size(cases,1)
    name = cases{k,1}; f = cases{k,2}; railTarget_kWh = cases{k,3};
    if k == 2 && ~runFull, break, end
    assert(isfile(f), 'Missing %s', f);

    T = readtable(f, 'TextType', 'string');
    fprintf('\n=== %s: %s ===\n', name, f);
    fprintf('Trace: %.2f h, %d rows, max %.1f mph, grade %.3f..%.3f %%, tons %.0f..%.0f, ambient %.1f..%.1f C\n', ...
        T.time_s(end)/3600, height(T), max(T.speed_mph), min(T.grade_pct), max(T.grade_pct), ...
        min(T.trailing_tons), max(T.trailing_tons), min(T.ambient_C), max(T.ambient_C));

    tic
    RUN = run_loco_system(f, 'soc0', soc0, 'T0_C', T0_C, 'Regen', regen);
    wall = toc;
    fprintf('Wall time %.1f s\n', wall);

    disp(RUN.metrics)
    fprintf('Recorder rail energy (diesel loco) for comparison: %.1f kWh\n', railTarget_kWh);
    fprintf('Regen check: E_bat_in = %.2f kWh (expect ~0 with regen off)\n', RUN.metrics.E_bat_in_kWh);

    if isfield(RUN, 'R') && all(isfield(RUN.R, {'t','te_ax','f_fric','v_mph','v_ref'}))
        t = RUN.R.t(:);
        dt = [diff(t); 0];
        te = sum(RUN.R.te_ax, 2);
        fprintf('Min total axle TE: %.1f kN (expect >= 0)\n', min(te)/1e3);
        fprintf('Friction brake energy: %.1f kWh\n', sum(max(RUN.R.f_fric(:),0) .* abs(RUN.R.v_mph(:))*0.44704 .* dt)/3.6e6);
        fprintf('Speed tracking RMS error: %.2f mph\n', sqrt(mean((RUN.R.v_mph(:) - RUN.R.v_ref(:)).^2)));
    end

    results.(name) = RUN;
end

save(sprintf('results_csx4091_%s.mat', datestr(now,'yyyymmdd_HHMM')), 'results', '-v7.3');
fprintf('\nSaved results. Paste the Command Window output back for the verification pass.\n');