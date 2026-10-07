# Proto Loco v3 — Simscape Model Notes (Phase 2: thermal + scenarios)

## Run
1. Copy this folder into the repo root (keep `+protoloco/` as a package folder).
2. MATLAB R2024b, repo root as current folder: `run_proto_loco`
3. `run_proto_loco` builds `proto_loco.slx` from scratch, simulates, plots, prints checks.

## Architecture
Top level has 6 blocks and 5 lines. All physics and wiring live in Simscape language (`+protoloco/locomotive.ssc`).

| Component | Model |
|---|---|
| `battery` | 416S12P LFP, OCV(SOC) table + R0 + 1 RC, Ah counting |
| `dclink` | Precharge R → main contactor (auto-close at 95 % V_TRB), link capacitance |
| `axle` ×4 | Averaged 2-quadrant chopper + D77 (field = f(\|Ia\|), series-emulated, min field for regen), gear + wheel |
| `vehicle` | Loco + trailing mass, rolling (Crr), aero, grade, friction brake force |
| `auxload` | 750V-PS as constant-power load (η, 250 kW cap) |
| `charger` | ITV/MCS as power-commanded current source into TRB-BUS (3.3 MW / 2500 A caps) |
| `lcc_proxy` | Speed PI → TE; adhesion, power, battery-current limits; regen/friction blend |

**Input `U` columns:** `[t, v_ref mph, grade %, P_aux W, P_chg W, DC-link enable]`.

**Output `Y` columns:** `[v mph, SOC, V_TRB, I_bat, V_link, Ia_ax1, Va_ax1, TE_ax, F_fric, P_aux_in, P_chg, Idc_ax1]`.

## Expected results (independent Python replica, same params)
| Check | Expected |
|---|---|
| V_TRB at rest, SOC 90 % | ~1393 V |
| DC-link after precharge (t≈2.5 s) | ~1393 V |
| Accel 0→10 mph, 1,500 t trailing | I_bat ~650 A, Ia ~770 A, TE ~162 kN total |
| Cruise 10 mph | I_bat ~170 A |
| MCS 2.25 MW | I_bat ~ −1490 A, V_TRB → ~1474 V |
| SOC | 90.0 → ~89.5 (moves) → ~96 % (after 10 min charge) |

A large deviation points to a modeling or porting error, not the physics.

## Provenance and placeholders
| Parameter | Value | Source | Status |
|---|---|---|---|
| Cell config 416S12P, 104S/pack, 314 Ah | derived | 3768 Ah ÷ 12 = 314 Ah; 5016 kWh ÷ 3768 Ah = 1331 V = 416 × 3.2 V; 1476.8/416 = 3.55 V, 1185.6/416 = 2.85 V | **Derived — confirm with Jinko/BOM** |
| 12 strings × 4 packs | 48 packs | Deck combiner slide (2 strings/combiner × 6) | Deck |
| Cell OCV table | generic LFP | — | **Placeholder** |
| R0_cell 0.13 mΩ, R1 0.062 mΩ, R_bus 1.0 mΩ, τ 30 s | pack 7.65 mΩ | Battery Thermal Analysis (Micah, Jul 25): measured full-pack DCIR 7.653 mΩ incl. cables; split R0/R1/bus assumed | **Doc (total); split placeholder** |
| DCIR temperature factor | exp(2257·(1/T − 1/298 K)) | ≈2× at 0 °C, 0.8× at 45 °C | **Placeholder (typical LFP)** |
| R_bus 5 mΩ | — | Estimate | Placeholder |
| Chopper 655 kW, 1500 A cont, loss 5.25 kW @ 1050 A | — | Deck FER Choppers + cooling slides | Deck |
| D77 continuous 1050 A, 13,850 lbf/motor @ 62:15, 65 mph max | — | FRA DOT-FRA-ORD-78-78 Vol IV | **Public** |
| D77 536 kW input rating | — | Same FRA report | **Public** |
| Kφ_sat 9.0 V·s/rad, I0 600 A | fitted | Fitted to 13,850 lbf @ 1050 A | **Placeholder** |
| R_m 35 mΩ, L_a 10 mH, V_mot_max 750 V | — | Estimate; 750 V from deck TE/HP slide label | **Placeholder** |
| Gear 62:15, 40" wheel, η_gear 0.97 | — | GP40 standard; η estimate | Partial |
| Loco 270,000 lb; trailing 1,500 t | — | GP40-V spec; trailing assumed | **Trailing placeholder — need CSX pilot consist** |
| μ_adh 0.25, Crr 0.002, CdA 8 m² | — | Estimates | Placeholder |
| R_pre 4 Ω, C_link 20 mF | — | Sized to 400 A inrush; C unknown | **Placeholder** |
| P_trac_max 2.144 MW | 4 × 536 kW | D77 rating | Public |
| I_dis / I_chg max 1884 A | 0.5C | Arch doc | Doc |

## RSK candidates
| # | Item |
|---|---|
| 1 | **Arch doc topology wrong:** says 6 strings; deck and Ah math say 12 strings × 4 packs. Update arch doc. |
| 2 | **Cell config undocumented:** 416S12P, 314 Ah derived only. Confirm. |
| 3 | **Cell DCIR resolved (v3):** 7.653 mΩ is the measured *pack* value (≈0.22 mΩ/cell). Phase 1 used 32.7 mΩ pack, 4× too high; heat and sag were overstated. |
| 4 | **D77 data:** Integral or donor data needed (magnetization curve, R, L, short-time ratings, max motor voltage). |
| 5 | **Charge acceptance:** 1884 A = 0.5C. Dual MCS Express (4.5 MW ≈ 3.3 kA) and ITV max (2500 A) both exceed it. Express ×1 (≈1.6 kA) is OK. |
| 6 | **Power envelope:** 4 × 655 kW chopper = 2.62 MW > 2.51 MW battery peak > 2.144 MW D77 rating. Which limit LCC enforces is undefined. |
| 7 | **BTMS 12V PS:** 6 kW (deck) vs 3.25 kW (arch doc). |
| 8 | **Blowers:** 42 kW (deck) vs 25 kW (arch doc). |
| 9 | **Chopper-side DC-link capacitance:** not documented. |

## Known limitations (phase 1)
- **Rigid axle coupling:** all four axles share one rigid shaft. No wheel slip, so IAC benefit is not modeled.
- **Direction:** speed magnitude only; reverser/MCO not modeled.
- **Charger:** no CC/CV taper. SOC can exceed the practical limit near V_max.
- **Thermal:** no thermal models (battery, motor, chopper).
- **Dynamic braking grids:** regen-only plus friction; no grid resistor path.
- **Aux:** input profile, not physics.

## Next phases
2. **Per-axle adhesion/slip:** independent axles with IAC.
3. **Aux tree:** 750 V bus with converter models and BTMS thermal.
4. **Charging:** ITV/MCS with CC/CV taper and pantograph path.
5. **Thermal:** battery and D77 thermal derating.


---

# Phase 2 — Thermal network, BMS logic and validation scenarios (2026-10-07)

## Run
- **Single run (default duty):** `run_proto_loco` — now also plots the thermal traces.
- **Full matrix:** `run_thermal_sweep` — 8 scenarios × 5 ambients (0, 10, 20, 40, 50 °C) × 2 start conditions = 80 runs. Logging is off for speed. Results go to `results/thermal_sweep_<stamp>.csv/.mat`, plus a verdict heatmap and traces for `plot_case`.
- **Subset:** set `scn_pick = [2 3]` and/or `ambients = [40 50]` in the settings block.
- **BMS profile:** `bms = 'jinko'` (as-shipped thresholds) or `'cell_spec'` (discharge allowed to −20 °C, charge to 0 °C). Thresholds live in `proto_loco_params.m` (`P.bms`); edit them directly to test other settings.

## What was added
| File | Change |
|---|---|
| `+protoloco/thermal.ssc` | **New.** Lumped network: cell mass ↔ battery coolant; 4 Maxwell MTM chillers rejecting to the condenser radiator (capacity and COP fall with condenser supply temperature); PE loop radiator (choppers, ITV, aux chain); D77 motor (per motor, blower-cooled); BMS cooling/heating modes with hysteresis; BMS charge/discharge derate factors. |
| `+protoloco/battery.ssc` | Temperature input; DCIR(T); heat output `Qh = i²R0 + v1²/R1`. |
| `+protoloco/lcc_proxy.ssc` | Discharge/regen current limits × BMS derate `k_dis`, `k_chg`. |
| `+protoloco/charger.ssc` | BMS charge limit `I_bms × k_chg`; SOC taper to `soc_max` (95 %). |
| `+protoloco/auxload.ssc` | Second input: TMS electrical power (compressors, heaters, fans, pumps) drawn from the 750 V bus. |
| `+protoloco/io_mux.ssc`, `locomotive.ssc` | Output vector 12 → 28 signals. |
| `proto_scenarios.m` | **New.** 8 scenarios tied to DVP v0.4 tests. |
| `run_thermal_sweep.m`, `eval_thermal_run.m`, `proto_unpack.m`, `plot_thermal_run.m` | **New.** Sweep, verdicts, unpack, plots. |
| `reference/` | **New.** Independent Python replica (same equations and parameters) and its expected results. |

**Output `Y` columns 13–28:** `[T_cell, T_bat_coolant, T_cond_supply, T_cond_hot, T_PE_supply, T_charger_out, T_chopper_out, T_inverter_out, T_motor (K); P_TMS, Q_chiller, Q_heater, Q_battery, Q_PE (W); k_dis, k_chg]`. `proto_unpack` converts temperatures to °C.

## Scenarios (DVP v0.4 linkage)
| ID | What | DVP | Trailing | SOC₀ |
|---|---|---|---|---|
| S1 | First move fwd/rev, 3 mph, light engine | H-12/H-13 | 0 | 50 % |
| S2 | Showcase 1: 10 mph × 20 min | J-02B | 0 | 50 % |
| S3 | Dynamic charge 2.5 MW wire, 0.5 mph | J-09 | 0 | 20 % |
| S4 | Dynamic charge 3.0 MW, BMS limit 2328 A (~0.62C) | J-09 (3 MW) | 0 | 20 % |
| S5 | Continuous pull 10 mph × 60 min | J-16/P-02 | LC-3 3,640 t, 0.5 % | 90 % |
| S6 | Notch 8 (full power) ~16 min | J-17/P-01 | LC-3 | 90 % |
| S7 | 8 h switching shift, 2 moves / 30 min | J-18 | LC-1 1,430 t | 90 % |
| S8 | Parked 6 h, TMS on (recovery/preconditioning time) | G6 | 0 | 60 % |

**Start conditions:** `soaked` = pack at ambient (no TMS before the duty). `precond` = pack at 25 °C.

## Verdict ladder (`eval_thermal_run`)
| Verdict | Meaning |
|---|---|
| **OPTIMAL** | Cell 15–35 °C throughout, no derate, every PE/condenser limit with ≥ 3 K margin. "Best-case operation." |
| **OK** | Cell inside BMS L1 band, no derate, no limit exceeded. |
| **DERATED** | BMS derate, speed not held, or cell outside L1. |
| **FAIL** | Hard limit: cell at BMS L2, charger supply > 55 °C, chopper fluid > 63 °C, inverter fluid > 60 °C, condenser loop > 65 °C (check-valve service), motor > 180 °C. |

Limits are in `P.lim`. Sources: ITC charger datasheet 55 °C, ITC chopper 63 °C, Inmotion ACH ≤60 °C (via KULI PE review); TruDesign check valve 65 °C service (KULI condenser review).

## Expected results (Python replica `reference/`, same parameters)
Use as the cross-check: a large MATLAB deviation means a porting/model error.

**Preconditioned start (25 °C):**

| Scenario | 0 °C | 10 °C | 20 °C | 40 °C | 50 °C |
|---|---|---|---|---|---|
| S1 first move | OPT | OPT | OPT | OPT | OPT |
| S2 Showcase 1 | OPT | OPT | OPT | OPT | OPT |
| S3 dyn charge 2.5 MW | OPT | OPT | OPT | OK (2 K margin) | FAIL: charger supply 57.6 °C, condenser 69 °C |
| S4 dyn charge 3.0 MW | OPT | OPT | OPT | OK (2 K margin) | FAIL: charger 58.6, inverter 60.8, condenser 69 °C |
| S5 10 mph pull 60 min | OPT | OPT | OPT | OPT | OK (0.6 K margin, inverter 59.4 °C) |
| S6 Notch 8 | OPT | OPT | OPT | OPT | FAIL: inverter 60.2 °C |
| S7 8 h shift | OPT | OPT | OPT | OK | FAIL: condenser 69 °C |
| S8 park 6 h | OPT | OPT | OPT | OPT | FAIL: condenser 69 °C |

**Soaked start (pack = ambient):** 0 °C fails every motion/charge case (Jinko BMS blocks below 3 °C; heaters need ~1.2 h to reach 3 °C and ~1.9 h to reach 5 °C). 10 °C and 40 °C are OK (cell outside 15–35 °C but inside L1). 50 °C fails everything: cell starts at BMS L2; the TMS needs ~1.2 h to reach 45 °C and ~3.6 h to reach 35 °C.

Key numbers: cell peak 28 °C in every preconditioned case; battery heat 25 kW at 2.5 MW, 36 kW at 3 MW, 25 kW at Notch 8; chiller capacity ~57 kW at 40 °C and ~47 kW at 50 °C ambient; TMS energy 64 kWh (40 °C) and 90 kWh (50 °C) per 8 h shift preconditioned.

## Phase 2 parameter provenance
| Parameter | Value | Unit | Status | Source |
|---|---|---|---|---|
| `T_amb` | o.T_amb_C + 273.15 | K | Input | Sweep variable (ambient) |
| `T0_bat` | o.T0_C + 273.15 | K | Input | Initial cell/coolant temperature (soaked = ambient; preconditioned = 25 C) |
| `C_bat` | 3.01e+07 | J/K | Doc | Battery Thermal Analysis (Micah, 2026-07-25): 3.01e7 J/K |
| `UA_bc` | 5000 | W/K | Placeholder | Battery Thermal Analysis: cell-to-coolant UA placeholder |
| `UA_benv` | 300 | W/K | Placeholder | Enclosure loss to ambient, ~130 m2 x 2.5 W/m2K |
| `C_bc` | 1.28e+06 | J/K | Doc | Battery Thermal Analysis: 345.6 L coolant |
| `N_mtm` | 4 | 1 | Doc | Maxwell Thermal Module power spec: 4 modules |
| `Q_mtm` | 12500 | W | Doc | Maxwell TMS study (2025-11-10): 12.5 kW cooling per MTM |
| `T_cs_ref` | 323.15 | K | Derived | Capacity reference = KULI condenser supply 51.2 C at 40 C ambient |
| `k_cap` | 0.02 | 1/K | Placeholder | Chiller capacity loss per K of condenser supply rise (typical R1234yf/R134a) |
| `T_cs_cut` | 338.15 | K | Placeholder | Capacity fades to 0 at 65 C condenser supply (HP cutout proxy; check-valve 65 C) |
| `dT_cut` | 5 | K | Placeholder | Fade band below T_cs_cut |
| `COP_ref` | 3 | 1 | Placeholder | Chiller COP at T_cs_ref |
| `k_cop` | 0.05 | 1/K | Placeholder | COP loss per K |
| `COP_min` | 1.2 | 1 | Placeholder | COP floor |
| `Kp_chill` | 20000 | W/K | Placeholder | Chiller demand gain on cell temperature |
| `T_cool_set` | 295.15 | K | Doc | Jinko 5MWh BMS manual: refrigeration point 22 C |
| `T_cool_on` | 301.15 | K | Doc | Jinko BMS: cooling on at MaxT >= 28 C |
| `T_cool_off` | 299.65 | K | Doc | Jinko BMS: cooling off at 28 - 1.5 C |
| `Q_heat_max` | 24000 | W | Doc | Maxwell TMS study heating target 24 kW (arch doc says 12 kW; conflict) |
| `T_heat_on` | 285.15 | K | Doc | Jinko BMS: heating on at MinT < 12 C |
| `T_heat_off` | 286.65 | K | Doc | Jinko BMS: heating off at 12 + 1.5 C |
| `C_cd` | 220000 | J/K | Placeholder | Condenser loop coolant ~60 L |
| `UA_cd` | 2810 | W/K | Derived | KULI condenser review 2026-10-05: 60.1 kW / (61.4 - 40.0) K |
| `mcp_cd` | 5880 | W/K | Derived | KULI condenser: 1.68 kg/s x 3.5 kJ/kgK (gives 10.2 K drop at 60 kW) |
| `C_pe` | 500000 | J/K | Placeholder | PE loop coolant + cold plates |
| `UA_pe` | 2834 | W/K | Derived | KULI PE review 2026-10-05: 47.9 kW / (56.9 - 40.0) K |
| `mcp_pe` | 13300 | W/K | Derived | KULI PE: 3.81 kg/s x 3.5 kJ/kgK (gives 3.6 K drop) |
| `mcp_chg` | 3600 | W/K | Derived | KULI PE: charger 58.6 L/min (5.6 K rise at 20 kW) |
| `mcp_chop` | 1430 | W/K | Derived | KULI PE: chopper 23.4 L/min each |
| `mcp_inv` | 950 | W/K | Derived | KULI PE: front inverter 15.6 L/min |
| `N_ax` | 4 | 1 | Doc | 4 choppers / 4 D77 |
| `a_loss` | 2.5 | V | Deck | Chopper loss a|I| + bI^2 (5.25 kW @ 1050 A, Integral PE thermal loads) |
| `b_loss` | 0.00238 | Ohm | Deck | Same |
| `eta_chg` | 0.9934 | 1 | Derived | KULI PE: ITV 20 kW heat at 3 MW |
| `k_aux_pe` | 0.08 | 1 | Placeholder | Aux chain heat to PE loop (DC-DCs + inverters) as fraction of aux input |
| `k_inv` | 0.02 | 1 | Placeholder | Per-inverter heat fraction of aux input (for inverter outlet temperature) |
| `Q_pe_idle` | 1500 | W | Placeholder | PE loop idle heat |
| `R_m` | 0.035 | Ohm | Placeholder | D77 armature + field resistance (same as axle R_m) |
| `C_mot` | 1.5e+06 | J/K | Placeholder | D77 thermal mass per motor (~3 t x 500 J/kgK) |
| `UA_mot` | 276 | W/K | Placeholder | Blower-cooled; calibrated so 1050 A continuous gives ~140 K rise (class H) |
| `P_fan_cd` | 7000 | W | Doc | KULI condenser: 3 EMP fans 6.97 kW at 5400 rpm |
| `P_fan_pe` | 7000 | W | Doc | KULI PE: 3 EMP fans 7.02 kW at 5400 rpm |
| `P_pump` | 1500 | W | Derived | KULI pumps 923 W (PE) + 235 W (condenser) + battery loop |
| `T_fan_on` | 308.15 | K | Placeholder | PE fan ramp start (power only; UA held constant) |
| `dT_fan` | 10 | K | Placeholder | PE fan ramp width |
| `tau_m` | 5 | s | Placeholder | Mode filter time constant |
| `T_hot_L1` | 318.15 | K | Doc | BMS high-temperature alarm L1 (Jinko 45 C) |
| `T_hot_L2` | 323.15 | K | Doc | BMS L2 no charge/discharge (Jinko 50 C) |
| `T_cchg_L1` | 278.15 | K | Doc | BMS low-temp charge L1 (Jinko 5 C) |
| `T_cchg_L2` | 276.15 | K | Doc | BMS low-temp charge L2 = no charge (Jinko 3 C) |
| `T_cdis_L1` | 278.15 | K | Doc | BMS low-temp discharge L1 (Jinko 5 C) |
| `T_cdis_L2` | 276.15 | K | Doc | BMS low-temp discharge L2 = no discharge (Jinko 3 C) |

## New RSK candidates (Phase 2)
| # | Item |
|---|---|
| 10 | **PE loop is the hot-weather limiter, not the battery.** Charger supply crosses 55 °C at ~46–47 °C ambient during charging; inverters reach 60 °C at ~50 °C under Notch 8. |
| 11 | **Maxwell TMS designed for −10 to 45 °C ambient.** 50 °C is outside the design window; condenser loop reaches 69 °C (check valves 65 °C) and chiller capacity drops ~20 %. |
| 12 | **Jinko BMS cold thresholds block operation below 3 °C** (charge and discharge). LFP cells are rated to discharge to −30 °C (Micah thermal deck); decide Voltify BMS settings. |
| 13 | **Cold-soak recovery:** 24 kW heating takes ~1.9 h from 0 °C to 5 °C. **Hot-soak recovery:** ~1.2 h from 50 °C to 45 °C. Defines a preconditioning requirement (wayside power or standby). |
| 14 | **Heating capacity conflict:** Maxwell study 24 kW vs architecture doc 12 kW. At 12 kW, cold recovery time doubles. |
| 15 | **Battery-to-coolant UA (5 kW/K) and chiller performance map are placeholders.** These set cell-coolant gradient and hot-ambient capacity; get Jinko module cold-plate data and the Maxwell MTM map. |

## Fixes after first sweep (2026-10-07)
- **Rollback on grade:** heavy trains on 0.5 % rolled backwards before traction (no holding brake), causing "speed not held" and zero-crossing chatter. `lcc_proxy` now applies a park/anti-rollback brake of 0.1·m·g when v_ref = 0 or the train rolls back.
- **Solver min-step warnings near the end of heavy-train ramps (~312 s):** the speed PI switched its integrator on/off at the adhesion limit, and the gear-efficiency branch switched at v = 0. Replaced with back-calculation anti-windup (T_aw = 2 s) and a smooth tanh blend of η/1/η.
- **Zero-crossing chatter** at traction limits (BMS derate to 0, Va clamp): zero-crossing detection disabled (`ZeroCrossControl = DisableAll`); MaxStep bounds accuracy.

## Known limitations (Phase 2)
- Lumped thermal masses, one node per loop. No cell-to-cell spread (BMS ΔT alarms not modeled).
- Chiller capacity/COP linear in condenser supply temperature (placeholder map). No refrigerant model.
- Radiator UA fixed at the KULI full-fan operating point; fan power modulates but UA does not. Hot ambient is therefore slightly optimistic and fan energy slightly conservative.
- No solar load, no wind/vehicle-speed air flow benefit, no enclosure air node.
- D77 thermal is a single-node placeholder calibrated to a 140 K rise at 1050 A.
- Reverse moves modeled as repeat moves (speed magnitude only).
