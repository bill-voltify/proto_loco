f = fullfile(pwd,'MODEL_NOTES.md');
L = {
''
'## Native Simscape model: thermal approach decision (Oct 9, 2026)'
''
'Branch `native-simscape`, model `loco_native`, library `native/lib/loco_native_lib.slx`.'
''
'**Decision: Option A (parity first).**'
'- Thermal Plant receives heat inputs as signals (`Qb`, `i_a`, `p_chg`, `p_aux`), the same as Phase 3 `thermal.ssc`.'
'- Five thermal masses (cells, battery coolant, condenser loop, PE loop, D77 motor) use Foundation thermal blocks.'
'- TMS control logic (chiller/heater hysteresis, chiller command, fans, BMS derates, Ptms) moves to a sampled'
'  Simulink "TMS Controller" at 10 Hz with a one-sample Unit Delay (native convention NAT-13).'
''
'**Deferred: Option B (native thermal coupling), as a variant after the Step 8 regression passes.**'
'- Battery Table-Based blocks: enable thermal ports so I^2R heat flows physically into the cell thermal mass.'
'- Chopper conduction/switching loss and D77 armature resistor heat delivered through thermal ports.'
'- Effects: temperature-dependent resistance becomes physical; per-motor heating becomes visible'
'  (Phase 3 uses axle 1 current for all four motors).'
''
'**Parameter source:** native uses `P.th`, which differs from `thermal.ssc` defaults:'
'Q_mtm 12.0 vs 12.5 kW, k_cop 0.10 vs 0.05, COP_min 1.5 vs 1.2, Q_heat_max 12 vs 24 kW, P_pump 2.77 vs 1.5 kW.'
'`f_ram = 0.2` (ram-air fraction) is hard-coded in `thermal.ssc` and not in `P`.'
''
'**Native status:** Steps 1-6 pass against Phase 3 (strings, TRB, DC-Link, axle, vehicle, LCC, AUX, charger).'
'Open items and bench log: `native/OPEN_ITEMS.md`.'
};
fid = fopen(f,'a');
if fid < 0, error('Could not open %s',f); end
fprintf(fid,'%s\n',L{:});
fclose(fid);
fprintf('Appended %d lines to %s\n',numel(L),f);