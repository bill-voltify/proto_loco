function notes_step8
f = fullfile(pwd,'MODEL_NOTES.md');
L = {
''
'## Native Simscape model: Step 8 complete, full plant in Phase 3 harness (Oct 9, 2026)'
''
'**How to run**'
'- Model: `native/loco_native.slx` (copy of Phase 3 harness; Plant is a Variant Subsystem).'
'- `PLANT_ID = 1` Phase 3 plant, `PLANT_ID = 2` native plant (`loco_native_lib/Native Plant`).'
'- `RUN = run_loco_native(trace, ''Plant'', ''native''|''phase3'', <run_loco_system options>)`'
'  returns the same `report_loco_run` metrics/verdict as `run_loco_system`.'
'- `T = run_regression_native([scenarios], [ambients], {ic}, stop_s)`; no arguments lists scenarios.'
'- Rebuild after library changes: `build_loco_native` (re-applies fast-solver overrides).'
''
'**Solver decision (system runs).** Native plant uses local Backward-Euler solvers (electrical 1 ms,'
'thermal 0.1 s) with global `ode14x` fixed 1 ms. Variable-step daessc failed one step per 1 kHz'
'chopper-firmware sample (21,049 failed steps / 20 s) and ran 9-13x slower than real time.'
'Fixed-step runs at 0.45-0.95x real time. Accuracy vs variable-step: speed 0.000 mph, i_a 0.02 A,'
'pack current 3.3 A max / 0.12 A rms, V_link 14 V max (precharge transient). Component benches'
'in `native/tests/` keep variable-step.'
''
'**Regression (native vs Phase 3, same harness): 7 / 7 pass.**'
'S1 first move 25 C; S2 showcase 25/40 C; S6 notch 8 25/40 C (DERATED matched);'
'S3 dyn charge 2.5 MW 40 C and S5 continuous pull 40 C (first 3000 s).'
'Max differences: Tcell 0.001 K, Tsup 0.0013 K, SOC_end 0.0001, speed rms 0.016 mph;'
'pack current rms 6-17 A (transition events). Not run: S7 (8 h), S8 (6 h).'
''
'**Finding (NAT-41):** the Phase 3 plant hits solver min-step violations at every traction'
'start/stop/brake transition (6-73 per run; effective tolerance up to 2e4 x requested).'
'Native runs show none. Phase 3 verdicts, temperatures and SOC are unaffected; instantaneous'
'currents near transitions are not reliable in Phase 3.'
''
'**Known native differences by design:** string dropout opens string 6 first with frozen SOC'
'(NAT-39); vehicle mass fixed per run from trace trailing tons (NAT-22/40); controllers sampled'
'(LCC 100 Hz, charger 100 Hz, TMS 10 Hz, chopper FW 1 kHz system / 10 kHz bench) with one-sample'
'delay (NAT-13); battery heat and cell temperature coupled through thermal ports (NAT-31 partial B).'
''
'Full open-items list and bench log: `native/OPEN_ITEMS.md`.'
};
fid = fopen(f,'a');
if fid < 0, error('Could not open %s',f); end
fprintf(fid,'%s\n',L{:});
fclose(fid);
fprintf('Appended %d lines to %s\n',numel(L),f);
end