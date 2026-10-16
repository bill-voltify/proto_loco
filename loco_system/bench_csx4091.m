% BENCH_CSX4091  Estimate full-day CSX4091 run time on this machine.
% Reference (old laptop, 2026-10-15): peak2h 102.3 s, full day 3796.2 s.

if ~isfolder('traces') && isfolder('loco_system'), cd loco_system; end
assert(isfolder('traces'), 'Run from the repo root or loco_system');

ref_peak2h_s = 102.3;
ref_full_s   = 3796.2;
f = 'traces/CSX4091_20260826_peak2h.csv';
assert(isfile(f), 'Missing %s', f);

fprintf('MATLAB %s | %d threads | ', version('-release'), maxNumCompThreads);
try
    m = memory; fprintf('%.1f GB RAM available to MATLAB\n', m.MemAvailableAllArrays/1e9);
catch
    fprintf('memory() not available\n');
end

if ~isfile('voltify_loco_system.slx')
    fprintf('Building model (one-time, not timed)...\n');
    build_loco_system
end

fprintf('Warm-up: 10 min slice (not timed)...\n');
T = readtable(f, 'TextType', 'string');
Tw = T(T.time_s <= 600, :);
run_loco_system(Tw, 'soc0', 0.9, 'T0_C', 25, 'Regen', false, 'Plot', false, 'Silent', true);

fprintf('Timed: full 2 h window...\n');
tic
RUN = run_loco_system(f, 'soc0', 0.9, 'T0_C', 25, 'Regen', false, 'Plot', false, 'Silent', true);
t2h = toc;

k = t2h / ref_peak2h_s;
est_full = ref_full_s * k;

fprintf('\n2 h window: %.1f s (old laptop %.1f s) -> speed factor %.2fx %s\n', ...
    t2h, ref_peak2h_s, 1/k, ternary(k < 1, 'faster', 'slower'));
fprintf('Estimated full-day run: %.0f s (%.0f min)\n', est_full, est_full/60);
fprintf('Check: E_bat_in = %.2f kWh (expect 0), verdict %s\n', RUN.metrics.E_bat_in_kWh, RUN.metrics.verdict);

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end