# Voltify Loco System Model (Phase 3)

A team-facing system model built like the MathWorks EV reference examples: visible top-level subsystems, file-driven inputs, an operating-state machine, a per-load power budget and a fault-injection layer. The Phase 2 model (`../proto_loco.slx`) stays untouched as the verified reference; Phase 3 must reproduce it (`run_regression_phase2`).

## Model layout (`voltify_loco_system.slx`)

| Subsystem | Contents | Edit via |
|---|---|---|
| **Scenario** | Duty trace: speed, grade, ambient, trailing tons, wire power, aux override; state requests | `traces/*.csv` |
| **Fault Injection** | 14 fault channels, piecewise constant in time | `faults/*.csv` |
| **Controls** | **State Manager** (Stateflow: SLEEP, STANDBY, READY, TRACTION, CHARGING, FAULT, ESTOP); **Command Arbiter** (permissions × faults); **Power Budget** (per-load kW by state) | Chart; `load_budget.csv` |
| **Plant** | Simscape `locosys.locomotive_sys`: battery (12 strings), DC link, 4 axles (chopper + D77), train dynamics, aux chain, onboard charger, thermal network | `+locosys/*.ssc`, `../proto_loco_params.m` |
| **Dashboard** | Scopes + logging (`Y`, `SYS`, `LOADS`, `BUSES`) | — |

## Run

```matlab
cd loco_system
build_loco_system                                   % once, after editing +locosys, and after this update (Power Budget block changed)
RUN = run_loco_system('traces/example_yard_day_8h.csv');
RUN = run_loco_system('traces/example_yard_day_8h.csv', 'Faults', 'faults/example_hot_day_faults.csv', 'AmbientOffset_C', 8);
RUN = run_loco_system('traces/S3_dyncharge_2p5MW.csv', 'Ambient_C', 40, 'T0_C', 25, 'soc0', 0.2);
RUN = run_loco_system('traces/S8_park_6h.csv', 'Ambient_C', 0, 'UseBudget', true);   % S1-S8 traces on the POC budget
T   = run_regression_phase2([20 50], {'precond'});  % quick regression vs Phase 2
```

`RUN` holds the verdict (`RUN.metrics`), time in each state, energy by source / load / bus, the faults applied and all signals (`RUN.R`).

## Trace format (`traces/*.csv`)

| Column | Unit | Default if missing |
|---|---|---|
| `time_s` | s | required |
| `speed_mph` | mph (speed request) | 0 |
| `grade_pct` | % | 0 |
| `ambient_C` | °C | 25 |
| `trailing_tons` | short tons | 0 |
| `state` | SLEEP / STANDBY / READY / TRACTION / CHARGING | automatic (SLEEP < 2 s; CHARGING if wire_kW > 0; TRACTION if speed > 0; else READY) |
| `wire_kW` | kW available from the wire | 0 |
| `aux_override_kW` | kW; blank = use the load budget (S1–S8 carry Phase 2 values for regression; `UseBudget`, true ignores them) | blank |

Rows are breakpoints; numeric columns are interpolated, `state` holds until the next row. Blank states are evaluated on a 1 s grid from the interpolated speed and wire power. Logged field data (Data Logging tab, H-32) can be converted to this format and replayed.

## Load budget (`load_budget.csv`) — baseline: Micah's POC Power Budget Rev B

One row per auxiliary load, mapped to Micah's IDs (`micah_id`): bus (750V, 72V, 24V_Ctrl, 24V_BTMS, 12V_BTMS), nominal kW in each state, `moving_kW` added while moving in TRACTION/CHARGING, and `peak_kW` for reference. Power drawn at the 750 V bus = load ÷ conversion efficiency (750V 100 %, 72V 95 %, 24V_Ctrl 95 % × 88 %, 24V_BTMS 93 %, 12V_BTMS 93.5 %, per POC Power Budget). Thermal-management loads (MTM compressors, HVH120 heater, SPAL pumps, radiator fans) are computed by the plant thermal model, not the table. An AUX_DCDC_TRIP fault sheds every budget load.

State mapping is ours (Micah's sheet has nominal and peak only): SLEEP = UPS hold + wake circuit; STANDBY = control electronics; READY/TRACTION/CHARGING add cab HVAC, exterior lights, brake compressor and HSCB holding; CHARGING adds charging contactors and raised pantographs; blowers run only while moving.

Plant thermal parameters follow the same baseline (`loco_system_params`, `baseline = 'poc'`): heater 12 kW (1 × HVH120), 12 kW cooling per MTM, compressor COP 4 / 3 / 1.5 at 40 / 50 / 65 °C condenser supply (3 kW nominal, 8 kW peak per module), pumps 2.58 kW. Radiator fans stay EMP (KULI, 7 kW per bank) by decision 2026-10-08; Micah's sheet lists SPAL VA117 (RSK-NEW-35). `run_regression_phase2` uses `baseline = 'phase2'`.

## Fault library (`faults/fault_library.csv`)

Copy rows into a run file and set `enabled = 1`, `t_start_s`, `t_end_s`. Channels: `n_mtm`, `fan_pe`, `fan_cd`, `pump_pe`, `pump_bat`, `n_ax_on`, `n_str`, `dT_sense_K`, `blower_ok`, `comms_ok`, `aux_ok`, `chg_derate`, `estop`, `classA`. `comms_ok = 0`, `classA = 1` → State Manager FAULT (no traction or charging); `estop = 1` → ESTOP (HV and TMS off).

| Fault | Plant effect |
|---|---|
| MTM_LOSS_1/2 | Chiller capacity × 3/4 or 2/4 |
| PE_FAN_FAIL, COND_FAN_FAIL | Radiator UA falls to 20 % (ram/natural air) |
| PE_PUMP_FAIL | PE flow 5 %: device outlet temperatures rise, radiator UA falls |
| BAT_PUMP_FAIL | Cell-to-coolant UA falls to 20 % |
| AXLE4_CUTOUT | 3 axles: adhesion and traction power × 3/4 |
| STRING_OPEN_1, RACK_OPEN | Capacity, resistance and BMS current limits scale with strings |
| TSENSE_HIGH/LOW | BMS reads cell temperature ± 5 K (cooling, heating and derates act on the wrong value) |
| BLOWER_FAIL | Motor cooling UA falls to 15 % |
| AUX_DCDC_TRIP | Aux budget loads and TMS lost |
| CHARGER_DERATE_50 | Charge power × 0.5 |
| BTMS_24V_PS_TRIP (2 rows, one LRU) | All SPAL pumps: PE flow 5 %, battery-loop UA 20 % |
| BTMS_12V_PS_TRIP | MTM ECUs and internal pumps lost: chillers off (LV radiator fans not modeled) |

Rows sharing a `fault_id` are applied together, so one LRU failure can hit several channels.

## Fault sweep (DVP C-21)

```matlab
T = run_fault_sweep();                                   % every library fault x [20 40 45] C on traces/fault_test_3h.csv
T = run_fault_sweep('Ambients', 40, 'Faults', {'PE_FAN_FAIL','MTM_LOSS_1'});
T = run_fault_sweep('Parallel', true);                   % parfor workers
```
Each fault is applied alone from 0.5 h to the end of a 3 h heavy-duty trace (LC-3 / LC-2 pulls at 6–8 mph on 0.3–0.5 % grade, one 30 min 2.5 MW charge), pack preconditioned to 25 °C. Output: `results/fault_sweep_<stamp>.csv` ranked by severity then time to first limit, deltas vs the no-fault baseline, and a heatmap. `by_design_stop = true` marks faults whose expected response is to stop (comms loss, Class A, E-Stop).

## Notes and limits
- Plant equations are the Phase 2 equations plus the fault/ambient inputs; Phase 2 limitations apply (MODEL_NOTES.md).
- Controls run at 1 s (`P.sys.Ts_ctrl`).
- Axle cut-out is modeled on axle 4 only (symmetric single-axle loss).
- Next steps: Simscape Fluids thermal-liquid coolant loops as a Thermal variant; Simscape Battery pack variant.
