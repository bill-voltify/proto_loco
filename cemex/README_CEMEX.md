# CEMEX Victorville Locomotive Model (parallel to the GP40 proto)

A parallel model of the GP40 proto system model (`../loco_system`, Rev E) for the CEMEX Victorville RFI #13544 (six-axle battery-electric locomotive, quarry ↔ plant service). The GP40 model's files are not modified. `cemex_loco_system.slx` is a renamed copy of `voltify_loco_system.slx` and shares the `+locosys` plant equations. All CEMEX differences are parameters in `cemex_params.m`.

## Run

```matlab
cd cemex
build_cemex_model                                  % once (and after build_loco_system changes)
RUN = run_cemex();                                 % 3 round trips, placeholder route, 40 C, 2 MW plant charging
RUN = run_cemex([], 'Cycle', {'Trips', 6, 'PlantCharge_kW', 0});      % range without opportunity charging
RUN = run_cemex([], 'Strings', 16, 'DisCRate', 1.0, 'MuAdh', 0.18); % capacity / C-rate / wet-rail sensitivity
RUN = run_cemex([], 'DisCRate', 0.5);                               % previous discharge limit (Jinko 0.5C)
RUN = run_cemex('traces/cemex_victorville_shift.csv', 'T0_C', []); % saved trace, pack soaked at ambient (off-design start)
cemex_rfi_report()                                  % RFI answer pack -> rfi_out/RFI_answers.md (+ CSVs, figures), ~10 min
```

`RUN.cemex` holds the metrics RFI C5 and D5 ask for: energy per cycle, peak power, minimum and reserve SOC, regen recovered vs friction braking, peak TE and speed shortfall. `RUN.metrics` holds the GP40 thermal verdict.

## Files

| File | Purpose |
|---|---|
| `cemex_params.m` | GP40 Rev E params + CEMEX overrides (battery, 6 axles, mass, regen, charger, cooling system) |
| `make_cemex_cycle.m` | Route table → time trace (loco_system trace format): trips, consist, dwells, charging windows |
| `routes/victorville_placeholder.csv` | **Placeholder** route (segments, grade, curvature, speed limit) |
| `cemex_load_budget.csv` | GP40 load budget, blowers ×6/4 and BMS electronics ×14/12 |
| `build_cemex_model.m`, `cemex_loco_system.slx` | Renamed copy of the GP40 system model |
| `run_cemex.m` | Runner + RFI metrics |
| `results_cases.csv` | First sensitivity set (2026-10-28) |
| `cemex_rfi_report.m`, `cemex_capability.m` | RFI answer pack (B2, C1-C8, D1, D3-D6, E1-E3, F2) and TE/BE curves from the plant equations |
| `rfi_out/` | `RFI_answers.md`, per-question CSVs, figures (cache `rfi_sims.mat` not tracked) |

## RFI → model mapping

| RFI item (VV_Electrical_Locomotive_RFI_Details) | Model |
|---|---|
| Six axles, six traction motors | 4 modeled axles × 1.5 D77 motors each (current, torque, power ×1.5; R, L ÷1.5); per-motor behaviour is the same as the GP40 |
| 3.0–4.0 MW continuous traction | `MotorCapkW` 536 → 3.22 MW (D77 rating); 655 → 3.93 MW |
| 4–8 MWh, Voltify response 5.8 MWh | 14 strings × 416S × 314 Ah = 5.85 MWh (`Strings`) |
| Battery delivers 3.0–4.0 MW continuous (sheet 2) | Discharge limit sized to the traction cap at 1,248 V (416 × 3.0 V) through η 0.88: 0.67C / 2,928 A for 3.22 MW, 0.81C / 3,578 A for 3.93 MW (`DisCRate` overrides). Charge and regen stay 0.5C (`ChgCRate`) |
| Regenerative braking, friction blend when regen is limited | `Regen` true; LCC proxy limits regen by battery current/SOC and sends the rest to friction |
| Manual charger up to 3 MW, plant microgrid 1.2 MWp + 6 MWh BESS (B10) | `ChargerkW` 3000; `PlantCharge_kW` 2000 during the unload dwell |
| Duty-cycle simulation: weights, grades, curvature, speed limits, stops, ambient, aux, regen, charging (sheet 3, C2) | `make_cemex_cycle` inputs; curvature as 0.04 %/degree equivalent grade |
| Individual axle control (sheet 4) | Not modeled: axles share one rigid shaft (GP40 limitation). Adhesion is a single μ |

## Placeholders (not from CEMEX, replace before quoting results)

The RFI asks for a simulation "using the Victorville route profile," but the RFI workbook doesn't include one, and no route data was found in Drive. These inputs are assumptions:

- **Route:** 9 mi one way, 6 segments, grades −1.0 % to +0.8 % (max 0.92 % loaded and 1.08 % empty with curvature), 5–20 mph.
- **Consist:** 4,000 short tons loaded (40 × 100 t) and 1,200 t empty. **Loco weight:** 420,000 lb.
- **Operation:** 3 round trips per shift, 60 min loading, 45 min unloading, 40 °C ambient, no quarry charger.
- 40 in wheels (EMD six-axle standard), D77 motors. Cooling components are GP40 types (Maxwell MTM, EMP fan radiator banks, SPAL pumps) scaled by count.

## Cooling system (CEMEX sizing)

The GP40 Rev E cooling system fails on this locomotive at 45 °C: the condenser loop goes over the 65 °C check-valve limit, because the larger pack running at 0.67–0.81C needs about 55–75 kW of chilling. The CEMEX system (`TMS`, default `'cemex'`) is sized to stay OPTIMAL with at least 3 K margin at 46 °C on the worst duty: 655 kW motors (0.81C) and 3 MW plant charging.

| | GP40 Rev E | CEMEX |
|---|---|---|
| Chiller modules (Maxwell MTM, 12 kW) | 4 | **6** (72 kW, up to 86 kW at a cool condenser) |
| Condenser radiator banks (EMP fans, 7 kW per bank) | 1 (UA 2,810 W/K) | **3** (UA 8,430 W/K, 21 kW fans) |
| PE radiator banks (choppers, charger, inverters) | 1 (UA 2,834 W/K) | **2** (UA 5,668 W/K, 14 kW fans) |
| Pumps at the 750 V bus | 3.15 kW | 4.78 kW (+4 SPAL: 2 condenser banks, 1 PE bank, 1 per 2 MTMs; +2 MTM internal) |

Sizing sweep at 46 °C, 655 kW motors, 3 MW charging, preconditioned pack:

| Design | Condenser max | Margin | Verdict |
|---|---|---|---|
| GP40 (4 MTM, 1 cd, 1 PE) | 67.1 °C | −2.1 K | FAIL (check valve) |
| 6 MTM, 2 cd, 1.5 PE | 62.2 °C | 2.8 K | OK |
| 6 MTM, 3 cd, 1.5 PE | 57.2 °C | 4.2 K | OPTIMAL |
| **6 MTM, 3 cd, 2 PE (chosen)** | **57.2 °C** | **5.3 K** | **OPTIMAL** |
| 6 MTM, 4 cd, 2 PE | 54.5 °C | 5.3 K | OPTIMAL |

At 48 °C, the chosen design is still OPTIMAL (condenser 58.9 °C). At 46 °C it uses about 90 kWh more cooling energy per shift than the GP40 system (245 vs 153 kWh).

**Pack starting temperature.** Runs start with the pack at 25 °C (`T0_C` 25). The TMS conditions the pack while parked and charging, as in the RFI response (D17). A pack soaked to ambient (`'T0_C', []`) is an off-design start. At 40 °C it pulls down to 35 °C in 45 min (verdict OK). At 46 °C the pack starts above the BMS 45 °C L1 limit, so the first departure gets a 6 % discharge derate and the pack reaches 35 °C after 104 min. Cooling capacity doesn't fix this, only conditioning while parked does: the CEMEX operating plan needs the locomotive on charger or shore power between shifts in summer.

**Faults.** `fault_library.csv` MTM rows are absolute counts written for 4 MTMs (MTM_LOSS_1 = 3, MTM_LOSS_2 = 2). With 6 MTMs those values mean "lose 3" and "lose 4". A CEMEX fault table (5 of 6, 4 of 6) is still to do.

## Results (2026-10-28, placeholder route, CEMEX cooling, pack preconditioned to 25 °C)

| Case | Discharge limit | Peak current | 5 min MW | Peak MW | Battery out kWh | Regen kWh | Min SOC | Peak TE kN | Time > 2 mph slow | Condenser / margin | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0.5C discharge (previous limit) | 2,198 A | 2,186 A (at limit) | 2.65 | 3.01 | 2,652 | 508 | 78.3 % | 483 | 1.8 min | 51.9 °C / 12.7 K | OPTIMAL |
| **Base: 0.67C, 3 trips, 2 MW plant charging, 40 °C** | 2,928 A | 2,560 A | 2.73 | 3.50 | 2,675 | 506 | 78.2 % | 474 | 0.8 min | 51.9 °C / 12.7 K | OPTIMAL |
| No opportunity charging, 3 trips | 2,928 A | 2,614 A | 2.77 | 3.55 | 2,705 | 505 | 53.4 % | 482 | 0.8 min | | OPTIMAL |
| No opportunity charging, 5 trips | 2,928 A | 2,622 A | 2.77 | 3.55 | 4,511 | 845 | 28.8 % | 482 | 1.3 min | | OPTIMAL |
| No opportunity charging, 6 trips | 2,928 A | 2,652 A | 2.77 | 3.55 | 5,406 | 1,012 | **16.3 %** | 482 | 1.5 min | | OPTIMAL, below the 20 % reserve |
| Wet rail μ 0.18 | 2,928 A | 2,379 A | 2.52 | 3.26 | 2,597 | 509 | 78.6 % | 345 | 7.6 min | | OPTIMAL |
| 45 °C ambient | 2,928 A | 2,563 A | 2.74 | 3.51 | 2,696 | 501 | 78.0 % | 476 | 0.8 min | 56.3 °C / 7.2 K | OPTIMAL |
| 46 °C, 655 kW motors (0.81C), 3 MW plant charging | 3,578 A | 3,092 A | 2.75 | 4.22 | 2,722 | 501 | 78.0 % | 477 | 0.8 min | 57.2 °C / 5.3 K | OPTIMAL |
| 655 kW motors (3.9 MW), 0.81C | 3,578 A | 3,089 A | 2.75 | 4.22 | 2,680 | 506 | 78.2 % | 479 | 0.8 min | | OPTIMAL |
| Regen off | 2,928 A | 2,563 A | 2.73 | 3.50 | 2,709 | 0 | 75.2 % | 475 | 0.8 min | | OPTIMAL (604 kWh to friction) |

What this shows (route still a placeholder):
- **Thermal is no longer a limit anywhere in the operating envelope**, up to 48 °C, 0.81C discharge and 3 MW charging. Every case is OPTIMAL: cell 25–28 °C, at least 5 K margin on every PE and condenser limit.
- **The battery isn't the limit either.** Peak current stays below the sized discharge cap. Sustained power (about 2.75 MW) is set by this route: heavy pulls run at 15 mph or less, and wheel grip limits pulling force to about 475 kN (μ 0.25 on 420,000 lb). Showing 3–4 MW *continuous* needs a route with a long climb at higher speed.
- **Energy:** about 735 kWh per round trip net. 5.85 MWh covers 5 round trips with no charging (29 % left); the 6th drops below the 20 % reserve.
- **Regen recovers about 170 kWh per trip**, all of the braking energy on this profile. Regen and charging stay at 0.5C.
- **Unconfirmed:** the Jinko cell rating for 0.67–0.81C continuous discharge (the GP40 uses 0.5C), and Victorville's design ambient (46 °C assumed; checked to 48 °C).

## Limits

GP40 plant limitations apply (see `../MODEL_NOTES.md`, `../loco_system/README_SYSTEM.md`): rigid axle coupling (no per-axle slip/IAC), no dynamic-brake grids, and a time-based trace. The trace runs at the speed limit, so if the loco falls behind, grades arrive early. Check `speed_shortfall_max_mph`. The GP40 shared plant gives about 1 solver warning per 30 s of simulated time on both models (GP40 S7: 873 over 8 h). Battery degradation (RFI E4) is not modeled.
