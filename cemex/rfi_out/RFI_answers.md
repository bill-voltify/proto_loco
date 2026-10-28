# CEMEX Victorville RFI #13544: simulation answers

Generated 2026-10-28 16:41 by `cemex/cemex_rfi_report.m` from the CEMEX parallel model (CEMEX-A, built on GP40 proto RevE).

> **Placeholders, replace before submitting.** CEMEX hasn't provided the Victorville route profile, so the route (9 mi one way, 6 segments, -0.92 % to 1.08 % with curvature), consist (4,000 t loaded, 1,200 t empty) and locomotive weight (420,000 lb) are assumptions. Every number below comes from those inputs. Re-run `cemex_rfi_report('Rerun', true)` once the route arrives.

Locomotive as simulated: 6 axles (6 × D77 DC traction motors, 62:15, 40 in wheels), 3.12 MW traction (4,183 hp) at the rail, battery 14 strings × 416S × 314 Ah LFP = 5,852 kWh, discharge limit 2,928 A (0.67C), charge and regen limit 2,198 A (0.50C), regen on, cooling system CEMEX-sized (6 chiller modules, 3 condenser banks, 2 PE banks). Adhesion 0.25 dry, 0.18 wet.

## B2: Power, speed, weight

| Item | Value | Basis |
|---|---|---|
| Continuous traction power | 3.22 MW motor output, 3.12 MW at the rail (4,183 hp) | 6 × 536 kW D77 rating, gear efficiency 0.97 |
| Peak battery power (simulated) | 3.50 MW | base duty cycle, includes aux and cooling |
| Short-time traction | 3.93 MW (6 × 655 kW, chopper rating) | `MotorCapkW` 655 option, discharge limit 0.81C |
| Full power available up to | 30 mph | armature voltage limit above that (750 V per motor) |
| Route speed limit (placeholder) | 20 mph | route CSV |
| Locomotive weight / axle load | 420,000 lb / 70,000 lb | PLACEHOLDER |
| Dimensions | not in the model | mechanical design |

## C1: Maximum sustained grade

Grade the locomotive can hold at constant speed on the continuous motor rating (1,050 A per D77, thermally unlimited), with the 5-minute rating (1,500 A) for comparison. Curvature counts as grade (0.04 %/degree). Values in %.

| Consist | mph | SOC 90 % | SOC 50 % | SOC 20 % | 5-min rating | Wet (μ 0.18) |
|---|---|---|---|---|---|---|
| Empty (1,200 t) | 5 | 2.73 | 2.73 | 2.73 | 3.52 | 2.48 |
| Empty (1,200 t) | 10 | 2.73 | 2.73 | 2.73 | 3.52 | 2.48 |
| Empty (1,200 t) | 15 | 2.72 | 2.72 | 2.72 | 3.51 | 2.48 |
| Empty (1,200 t) | 20 | 2.58 | 2.58 | 2.58 | 2.58 | 2.48 |
| Loaded (4,000 t) | 5 | 0.78 | 0.78 | 0.78 | 1.05 | 0.70 |
| Loaded (4,000 t) | 10 | 0.78 | 0.78 | 0.78 | 1.05 | 0.70 |
| Loaded (4,000 t) | 15 | 0.78 | 0.78 | 0.78 | 1.04 | 0.70 |
| Loaded (4,000 t) | 20 | 0.73 | 0.73 | 0.73 | 0.73 | 0.70 |
| Loaded +25 % (5,000 t) | 5 | 0.59 | 0.59 | 0.59 | 0.81 | 0.53 |
| Loaded +25 % (5,000 t) | 10 | 0.59 | 0.59 | 0.59 | 0.81 | 0.53 |
| Loaded +25 % (5,000 t) | 15 | 0.59 | 0.59 | 0.59 | 0.80 | 0.53 |
| Loaded +25 % (5,000 t) | 20 | 0.55 | 0.55 | 0.55 | 0.55 | 0.52 |

- **Battery charge doesn't change grade capability** above the 20 % reserve. The discharge limit is sized so full power holds down to 1,248 V, and the loaded pack stays at or above 1,319 V at 20 % SOC.
- **Ambient temperature doesn't change it either, up to 48 °C.** The 46 °C shift ran with no derating: battery discharge factor 1.00, verdict OPTIMAL, condenser 57.2 °C (limit 65 °C).
- The route's steepest loaded grade (0.92 % with curvature, 2.0 mi) is above the loaded continuous-rating limit (0.78 %). The loaded train climbs it on the short-time rating at 16.6 mph. In a 30-minute simulated climb the motors reached 92 °C, against a 180 °C limit. A climb much longer than the placeholder segment would need motor current ratings confirmed for that duty.

## C2: Duty-cycle simulation (Victorville route)

Inputs the simulation covers:

| RFI input | Value used |
|---|---|
| Locomotive weight | 420,000 lb (placeholder) |
| Train consist | 4,000 t loaded, 1,200 t empty (placeholder, 40 cars) |
| Grades / curvature | 6 segments, -1.0 % to +0.8 %, curves 0-6° (placeholder) |
| Speed restrictions | 5-20 mph by segment |
| Acceleration | 0.15 mph/s up, 0.20 mph/s down, within adhesion and power |
| Stops / starts | 3 round trips; 60 min loading, 45 min unloading, stop at each end |
| Ambient | 40 °C (46 °C case below) |
| Auxiliary loads | `cemex_load_budget.csv` (blowers, compressor, cab, controls) plus cooling system from the thermal model |
| Regenerative braking | on, limited to 2,198 A (0.5C) and to the traction power cap |
| Battery limits | discharge 2,928 A, charge 2,198 A, BMS temperature derates (45/50 °C hot) |
| Battery degradation | end-of-life case: 70 % capacity (8,000 cycles, Voltify response), 1.5× resistance (assumed) |
| Charging opportunities | 2000 kW during each plant unload dwell; none at the quarry |

Results, one shift:

| Case | Battery kWh | Out kWh | Regen kWh | Charger kWh | Peak MW | Min SOC % | End SOC % | Max shortfall mph | Condenser °C | Thermal |
|---|---|---|---|---|---|---|---|---|---|---|
| Base: 3 round trips, 2 MW plant charging, 40 C | 5,852 | 2,675 | 506 | 2,498 | 3.50 | 78.2 | 94.8 | 2.6 | 51.9 | OPTIMAL |
| End of life (70 % capacity, 1.5x resistance), base cycle | 4,096 | 2,646 | 511 | 2,393 | 3.50 | 73.1 | 94.9 | 2.6 | 51.9 | OPTIMAL |
| 46 C ambient, base cycle | 5,852 | 2,702 | 499 | 2,540 | 3.55 | 78.0 | 94.9 | 2.6 | 57.2 | OPTIMAL |
| Wet rail, adhesion 0.18, base cycle | 5,852 | 2,597 | 509 | 2,424 | 3.26 | 78.6 | 94.9 | 4.9 | 51.9 | OPTIMAL |
| No charging, 3 trips, 40 C, new battery | 5,852 | 2,705 | 505 | 0 | 3.55 | 53.4 | 53.4 | 2.6 | 51.9 | OPTIMAL |
| No charging, 3 trips, 46 C, new battery | 5,852 | 2,781 | 504 | 0 | 3.51 | 52.2 | 52.2 | 2.6 | 57.2 | OPTIMAL |
| No charging, 3 trips, 40 C, end of life | 4,096 | 2,709 | 511 | 0 | 3.50 | 37.5 | 37.5 | 2.6 | 51.9 | OPTIMAL |
| No charging, 3 trips, 46 C, end of life | 4,096 | 2,778 | 499 | 0 | 3.55 | 35.6 | 35.6 | 2.6 | 57.2 | OPTIMAL |

![Base shift](fig_C2_base_shift.png)

Every shift case finished with the train on schedule within the speed tolerance. The shortfall column is the worst gap below the speed limit; it comes from the heavy pulls being adhesion-limited. Every case was thermally OPTIMAL.

## C3: Acceleration

Full-power start from rest at 40 °C, SOC 90 %. Time (s) and distance (m) to each speed. Blank means the train doesn't reach that speed on that grade.

| Case | t 5 mph | d 5 mph | t 10 mph | d 10 mph | t 15 mph | d 15 mph | t 20 mph | d 20 mph | Balancing mph |
|---|---|---|---|---|---|---|---|---|---|
| Loaded, level | 23 | 26 | 47 | 106 | 70 | 236 | 101 | 483 | 20.0 |
| Loaded, 0.92 % (critical, with curve) | 252 | 289 | 515 | 1166 | 778 | 2631 |  |  | 16.6 |
| Empty, level | 7 | 8 | 14 | 31 | 21 | 71 | 33 | 172 | 20.0 |
| Empty, 1.08 % (critical, with curve) | 11 | 12 | 21 | 48 | 31 | 105 | 47 | 238 | 20.0 |

![Acceleration](fig_C3_acceleration.png)

## C4: Maximum train tonnage

Trailing short tons. Starting uses 467 kN (adhesion-limited; dry μ 0.25, wet 0.18). Continuous means holding 10 mph on the continuous motor rating. Coupler means a 250,000 lbf drawbar limit (assumed AAR knuckle working limit, to be confirmed against the CEMEX fleet).

| Grade % | Starting, dry | Starting, wet | Continuous 10 mph | Coupler limit |
|---|---|---|---|---|
| 0.00 | 26,040 | 18,690 | 20,415 | 62,479 |
| 0.50 | 7,290 | 5,190 | 5,683 | 17,851 |
| 0.92 | 4,477 | 3,165 | 3,473 | 11,157 |
| 1.00 | 4,165 | 2,940 | 3,227 | 10,413 |
| 1.50 | 2,878 | 2,014 | 2,216 | 7,350 |
| 2.00 | 2,176 | 1,508 | 1,665 | 5,680 |

The coupler is never the limit for one locomotive: maximum drawbar pull is 105,036 lbf, against the 250,000 lbf limit. Adhesion is the limit at starting speeds.

## C5: Energy, peak demand and state of charge, one operating cycle

| Metric | Base shift (3 round trips) | Per round trip |
|---|---|---|
| Battery energy out | 2,675 kWh | 892 kWh |
| Regen returned to battery | 506 kWh | 169 kWh |
| Net battery energy (no charging) |  | 705 kWh (no-charging run) |
| Charger energy in (plant dwells) | 2,498 kWh |  |
| Peak demand (battery) | 3.50 MW |  |
| Highest 5-minute average | 2.73 MW |  |
| SOC start / minimum / end | 90 % / 78.2 % / 94.8 % |  |
| Required reserve | 20 %: yes |  |

## C6: Wet, dusty, low-adhesion and high-temperature performance

- **Low adhesion.** At μ 0.18 starting TE drops from 467 to 336 kN. The wet base shift still finished with minimum SOC 78.6 %, but ran 7.6 min more than 2 mph below the speed limit on the heavy pulls (dry: 0.8 min). Sanding and adhesion control are in scope; the model uses one adhesion value for the whole locomotive and has no per-axle slip control.
- **High temperature.** At 46 °C the shift ran with no derating: discharge factor 1.00, cell max 28.0 °C, condenser 57.2 °C, PE margin 6.2 K, verdict OPTIMAL. The cooling system was sized to stay OPTIMAL to 48 °C.
- **Derating logic (as modeled).**
  - Battery: the BMS derates current linearly from 45 °C (L1) to 50 °C (L2) cell temperature hot, and from 5 °C to 3 °C cold. The pack is held at 25 °C while parked.
  - Motors: current limit of 1,500 A for 5 minutes and 1,050 A continuous per motor.
  - Cooling: chiller capacity falls as the condenser supply rises, and cuts out at 65 °C.
  - Adhesion: TE is capped at μ × locomotive weight.
- **Dust.** Dust isn't a model input. In the model it shows up only as reduced adhesion (use the wet case) and radiator fouling (UA margin: the condenser runs 7.8 K under its limit at 46 °C).

![TE vs speed](fig_D1_te_vs_speed.png)

## C7: Steepest grade to start, restart and hold

| Consist | Start / restart, dry % | Start / restart, wet % | Hold, locomotive brake only % |
|---|---|---|---|
| Empty (1,200 t) | 3.52 | 2.48 | 3.9 |
| Loaded (4,000 t) | 1.05 | 0.70 | 1.4 |
| Loaded +25 % (5,000 t) | 0.81 | 0.53 | 1.2 |

**Method.** Starting TE (adhesion-limited) against grade plus rolling resistance, with no acceleration margin. It is checked in simulation with the loaded train:

- at 0.95 %: reaches 5.0 mph.
- at 1.10 %: the train creeps to 0.14 mph and stalls. The anti-rollback brake stops any rollback within 0.03 mph.

Rollback is prevented by the park/anti-rollback brake whenever speed is commanded to zero or the train rolls back. With the locomotive brake alone, the loaded train holds up to 1.45 %.

**Route impact.** The steepest loaded grade (0.92 % with curvature) is above the wet restart limit (0.70 %). A loaded train stopped there in wet conditions needs sand, or a lower trailing load.

## C8: Limitations and assumptions

1. The route, consist and locomotive weight are placeholders until CEMEX provides the Victorville profile.
2. Wet-rail restart of the loaded train is limited to 0.70 %, below the route's 0.92 % (see C7). Keep stop locations off the steepest loaded segment, or sand.
3. Without charging, the battery covers 5 round trips before the 20 % reserve when new, and 4 at end of life (E3). The plant charger is required for longer shifts.
4. The locomotive alone can hold the loaded train on descents up to 1.45 %. Steeper descents need train air brakes.
5. Not modeled:
   - individual-axle slip control (the model uses one adhesion value)
   - dynamic-brake grids
   - regen cut-off at full SOC (the model limits regen on temperature only)
   - battery calendar aging
6. The cell rating at 0.67C continuous discharge needs Jinko confirmation. Victorville's design ambient is assumed to be 46 °C.

## D1: Tractive effort

| Item | Value |
|---|---|
| Starting TE (dry, μ 0.25) | 467 kN (105,036 lbf), adhesion-limited |
| Starting TE, motor current limit | 562 kN (6 × 1,500 A) |
| Continuous TE | 367 kN (82,550 lbf) at 19.0 mph (6 × 1,050 A) |
| Continuous speed at maximum power | 19.0 mph |
| Wet starting TE (μ 0.18) | 336 kN (75,626 lbf) |

| mph | TE max kN | TE continuous kN | TE wet kN | Regen braking kN | TE max limited by |
|---|---|---|---|---|---|
| 0 | 467 | 367 | 336 | 0 | adhesion |
| 2 | 467 | 367 | 336 | 278 | adhesion |
| 5 | 467 | 367 | 336 | 467 | adhesion |
| 8 | 467 | 367 | 336 | 467 | adhesion |
| 10 | 467 | 367 | 336 | 467 | adhesion |
| 12 | 467 | 367 | 336 | 467 | adhesion |
| 15 | 465 | 367 | 336 | 467 | motor power |
| 20 | 349 | 349 | 336 | 360 | motor power |
| 25 | 279 | 279 | 279 | 288 | motor voltage |
| 30 | 220 | 220 | 220 | 240 | motor voltage |
| 40 | 82 | 82 | 82 | 180 | motor voltage |

Full curve: `D1_te_be_vs_speed.csv`.

**Against the reference locomotive.** CEMEX's Victorville fleet has run second-hand EMD SD40-2s and SD60s (and GP39-2s). The RFI's 3,500-3,800 hp reference matches the **SD60 (3,800 hp)**.

Published ratings vary between sources; these are the most-cited values:

- **SD60:** 98,250 lbf starting at 25 % adhesion; 100,000 lbf continuous at 9.8 mph; D87B motors, 77:17; about 368,000 lb
- **SD40-2:** 115,000 lbf starting at 31.5 %; 82,100 lbf continuous at 11 mph; D77 motors, 62:15

Beyond each unit's continuous point, its curve is drawn at the rail power implied by that point: TE × mph / 375. Values below are continuous ratings in lbf.

| Locomotive | Starting TE lbf | Continuous TE lbf | Rail hp at continuous point | 5 mph | 10 mph | 15 mph | 20 mph |
|---|---|---|---|---|---|---|---|
| EMD SD60 (reference, 3,800 hp) | 98,250 (25 % adh.) | 100,000 @ 9.8 mph | 2,613 | 100,000 | 98,000 | 65,333 | 49,000 |
| EMD SD40-2 (3,000 hp) | 115,000 (31.5 % adh.) | 82,100 @ 11.0 mph | 2,408 | 82,100 | 82,100 | 60,207 | 45,155 |
| CEMEX battery loco, 62:15 (as modeled) | 105,036 (0.25 × 420,000 lb) | 82,550 @ 19.0 mph | 4,183 | 82,550 | 82,550 | 82,550 | 78,438 |
| CEMEX battery loco, 77:17 regear | 105,036 (0.25 × 420,000 lb) | 90,460 @ 17.2 mph | 4,161 | 90,460 | 90,460 | 90,460 | 78,438 |

What this shows:

- **Continuous TE at low speed is short of the SD60.** As modeled (SD40-2 drivetrain: D77, 62:15) the locomotive matches the SD40-2 but is 17,450 lbf below the SD60 continuous rating. It equals or exceeds the SD60 from 12.0 to 35 mph, where its higher rail power (4,183 hp vs about 2,613) takes over. Above 35 mph the 750 V-per-motor limit inherited from the GP40 proto cuts power; that is outside the 20 mph route but contradicts the "no high-speed power fall-off" in Voltify's questionnaire answer (B9).
- **A 77:17 regear** (the SD60 ratio) raises continuous TE to 90,460 lbf and crosses the SD60 from 11.0 mph. Full continuous power then starts at 17.2 mph instead of 19.0 mph. The cost is top speed, which falls by the same 8.7 %; that doesn't matter on a 20 mph quarry line.
- **Closing the rest of the gap at 10 mph** takes more current than the D77 continuous rating (1,050 A), or a larger motor (D87/D90). Matching the SD60 low-speed rating is a motor and blower decision, not a battery or power question: the battery locomotive has about 60 % more rail power.
- **Starting TE depends on weight and adhesion, not the motors.** Six D77s at their 5-minute current give 126,328 lbf. The value in the table is adhesion-limited at μ 0.25 on the placeholder weight. The SD60's published figure assumes 25 % on about 393,000 lb. At SD60 weight (368,000 lb) the battery locomotive would start at 92,000 lbf, so it needs its battery ballast (420,000 lb is within the 70,000 lb axle load) or better adhesion from per-axle control (D2) to match.

## D3: Brake blending

As simulated, the speed controller asks for braking effort, and regen supplies it up to the smallest of:

- adhesion
- the traction power cap
- the BMS charge current (2,198 A), scaled by the BMS temperature factor

Below 3.4 mph regen fades out. Friction makes up the difference automatically at every time step.

**Evidence.** On the 10-mile -1.20 % descent, regen hit its power limit and friction took 1 % of the braking energy, with no speed loss (20.0-20.5 mph). The regen-off case in `results_cases.csv` moved all braking to friction (604 kWh per shift) with no change to the trip.

Two things are **not in the model yet**:

- regen cut-off as the battery approaches full charge (the descents start at 60 % SOC for that reason)
- the dynamic-brake grid path

## D4: Braking effort and stopping distance

Regen braking effort vs speed is in the D1 table and figure. The stopping distances below use **locomotive braking only**: regen plus locomotive friction, up to adhesion. Train air brakes are excluded, so these are upper bounds. They need the CEMEX car brake ratios to refine.

| Consist | Grade % | From mph | μ | Time s | Distance m | Distance ft |
|---|---|---|---|---|---|---|
| Empty | 0.00 | 10 | 0.25 | 12 | 27 | 88 |
| Empty | 0.00 | 10 | 0.18 | 16 | 37 | 120 |
| Empty | 0.00 | 15 | 0.25 | 18 | 61 | 199 |
| Empty | 0.00 | 15 | 0.18 | 25 | 83 | 271 |
| Empty | 0.00 | 20 | 0.25 | 24 | 108 | 353 |
| Empty | 0.00 | 20 | 0.18 | 33 | 147 | 481 |
| Empty | -0.68 | 10 | 0.25 | 15 | 33 | 107 |
| Empty | -0.68 | 10 | 0.18 | 21 | 48 | 157 |
| Empty | -0.68 | 15 | 0.25 | 22 | 73 | 240 |
| Empty | -0.68 | 15 | 0.18 | 32 | 108 | 354 |
| Empty | -0.68 | 20 | 0.25 | 29 | 130 | 427 |
| Empty | -0.68 | 20 | 0.18 | 43 | 192 | 630 |
| Loaded | 0.00 | 10 | 0.25 | 33 | 73 | 238 |
| Loaded | 0.00 | 10 | 0.18 | 43 | 96 | 314 |
| Loaded | 0.00 | 15 | 0.25 | 49 | 163 | 536 |
| Loaded | 0.00 | 15 | 0.18 | 64 | 215 | 707 |
| Loaded | 0.00 | 20 | 0.25 | 65 | 291 | 953 |
| Loaded | 0.00 | 20 | 0.18 | 86 | 383 | 1,257 |
| Loaded | -0.92 | 10 | 0.25 | 89 | 199 | 655 |
| Loaded | -0.92 | 10 | 0.18 | 264 | 591 | 1,939 |
| Loaded | -0.92 | 15 | 0.25 | 134 | 449 | 1,472 |
| Loaded | -0.92 | 15 | 0.18 | 396 | 1,328 | 4,358 |
| Loaded | -0.92 | 20 | 0.25 | 178 | 797 | 2,616 |
| Loaded | -0.92 | 20 | 0.18 | 528 | 2,358 | 7,737 |

## D5: Regenerative energy recovery

- **Per shift:** regen returns 506 kWh to the battery, 169 kWh per round trip. That is 100 % of the braking energy; 0 kWh goes to friction.
- **Share of battery output:** 19 %.
- **End of life:** 511 kWh per shift. **Wet rail:** 509 kWh per shift.

Limiting assumptions:

- regen limited to 0.5C charge current and the 3.22 MW traction cap
- fades below 3.4 mph
- drivetrain efficiency 0.88 each way
- regen is not cut off at high SOC; shifts reach at most 95 % (the charger taper), where a real BMS would start limiting regen
- placeholder route descents

## D6: Thermal management on long descents

Loaded train, 10 miles of continuous descent at 20 mph, starting at 60 % SOC, 40 °C:

| Grade % | Speed mph | Peak regen MW | Charge A / limit | Regen kWh | Friction kWh | SOC +% | Motor °C | Condenser °C | Cell °C | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| -0.92 | 20.0-20.4 | 2.68 | 1,940 / 2,198 | 1,080 | 0 | 17.7 | 65 | 40.0 | 26.2 | OPTIMAL |
| -1.20 | 20.0-20.5 | 3.05 | 2,206 / 2,198 | 1,472 | 18 | 24.0 | 79 | 40.0 | 26.8 | OPTIMAL |

Regen braking is continuous: it is set by the battery charge limit and the cooling system, not by a grid duty cycle. The heat goes into the battery as charge and its losses go to the cooling loops, which stay within limits. On long descents the limit is battery capacity: about 1.8 % SOC per mile at -0.92 %. Descents longer than the battery headroom need the dynamic-brake grids or friction.

![Descent](fig_D6_descent.png)

## E1: Battery

| Item | Value |
|---|---|
| Chemistry / supplier | LFP, Jinko 314 Ah prismatic cells |
| Configuration | 14 strings × 416S |
| Installed capacity | 5,852 kWh |
| Usable capacity (90 % → 20 % reserve) | 4,096 kWh |
| Nominal voltage | 1,331 V (416 × 3.2 V) |
| Maximum discharge | 2,928 A (0.67C), about 3.9 MW |
| Maximum charge / regen | 2,198 A (0.50C), about 2.9 MW |

## E2: Cycle completion at beginning and end of life

Base duty cycle (3 round trips, plant charging):

|  | Beginning of life | End of life (70 %) |
|---|---|---|
| Capacity | 5,852 kWh | 4,096 kWh |
| Minimum SOC | 78.2 % | 73.1 % |
| End SOC | 94.8 % | 94.9 % |
| Reserve 20 % held | yes | yes |
| Thermal verdict | OPTIMAL | OPTIMAL |

## E3: Range and operating hours

No charging, starting at 90 % SOC, down to the 20 % reserve. Trips and hours are extrapolated from the SOC used per round trip in a 3-trip run. Hours include a 45 min unload dwell per trip.

| Scenario | kWh per round trip | SOC % per trip | Round trips to reserve | Hours to reserve |
|---|---|---|---|---|
| No charging, 3 trips, 40 C, new battery | 705 | 12.1 | 5.8 | 18.6 |
| No charging, 3 trips, 46 C, new battery | 724 | 12.4 | 5.7 | 18.1 |
| No charging, 3 trips, 40 C, end of life | 711 | 17.4 | 4.0 | 12.9 |
| No charging, 3 trips, 46 C, end of life | 735 | 17.9 | 3.9 | 12.5 |

With plant charging (2000 kW for each 45 min unload dwell) the base shift ends at 95 % SOC, so range is set by charging, not by capacity.

![SOC](fig_E3_soc.png)

## E4: Battery degradation

**Model.** NREL BLAST-Lite `Lfp_Gr_250AhPrismatic`: a semi-empirical model for large-format LFP/graphite prismatic cells, fitted to published aging data (doi:10.1016/j.est.2023.109042), ported to MATLAB in `cemex_degradation.m`. It has two parts:

- **Calendar fade** grows with the square root of time. It speeds up with temperature and with high SOC, through the graphite anode potential.
- **Cycle fade** grows with charge throughput (equivalent full cycles), depth of discharge and C-rate.

**Anchored to the cell.** The cycle term is scaled (×0.82) so the model reproduces the EVE MB31 314 Ah datasheet (PBRI-MB31-D06-01): 8,000 cycles to 70 % at 25 °C, 0.5P/0.5P, 100 % DOD. EVE publishes no calendar-aging curve, so the calendar term is BLAST's, unchanged. Against EVE data not used in the fit:

- **28-day storage at 50 % SOC:** the model keeps 99.7 % at 25 °C and 99.0 % at 45 °C. EVE specifies at least 98 % and 97 % recovery, so the model is consistent.
- **Cycles to 80 % at 0.5C/0.5C:** the model gives 4,649 at 25 °C and 5,835 at 45 °C. The EVE LF304 (same family, earlier cell) is rated 4,000 and 1,800. The model under-predicts heat damage from cycling at 45 °C. The CEMEX pack runs at 25-28 °C, where the anchor applies; the conservative case below covers the cycle-life uncertainty.

**Duty.** The base shift simulated above, using its SOC and cell temperature second by second. That is 0.45 equivalent full cycles per shift, including the plant charging. Between shifts the pack sits on charge at 95 % SOC, held at 25 °C by the cooling system. **The operating schedule is a placeholder**; CEMEX hasn't given shifts per day or days per year.

| Case | Full cycles / yr | SOH 5 y % | 10 y % | 15 y % | 20 y % | Years to 80 % | Years to 70 % | Calendar share of fade % |
|---|---|---|---|---|---|---|---|---|
| Base: 2 shifts/day, 6 days/week, parked on charge at 25 °C | 256 | 93.0 | 89.0 | 85.8 | 82.9 | > 25 | > 25 | 50 |
| 2 shifts/day, 7 days/week | 296 | 92.5 | 88.3 | 84.9 | 81.8 | 23.2 | > 25 | 47 |
| 1 shift/day, 5 days/week | 108 | 94.7 | 92.0 | 89.8 | 87.9 | > 25 | > 25 | 69 |
| Hot: cells at 35 °C all the time (no conditioning) | 246 | 90.6 | 85.8 | 82.0 | 78.6 | 17.8 | > 25 | 68 |
| Conservative cycle life: 4,000 cycles to 80 % (EVE LF304) | 254 | 92.6 | 88.4 | 84.9 | 81.8 | 23.3 | > 25 | 47 |

![Degradation](fig_E4_degradation.png)

**What it means for CEMEX**

- **Replacement threshold: 70 % SOH.** E2 shows the base duty cycle still completes with reserve at 70 % capacity (minimum SOC 73.1 %). In the base case the pack reaches 70 % after more than 25 years.
- **Design life: 20 years**, the Jinko container design life. In the base case, SOH at 20 years is 83 %. The conservative cycle-life case gives 82 %.
- **Calendar aging is about half the fade.** At 256 full cycles a year, the pack is far from its 8,000-cycle rating. Time, temperature and resting SOC matter as much as use.
- **Temperature is the biggest lever.** Without conditioning (35 °C) the pack reaches 80 % at 17.8 instead of > 25. That supports the TMS holding the pack at 25 °C while parked.
- **Proposed warranted retention:** at least 85 % at 10 years. This is the conservative-case value, rounded down 3 points for margin. It is subject to a back-to-back warranty from Jinko/EVE and to the confirmed CEMEX schedule.

Limits:

- capacity only; resistance growth is assumed at 1.5× at end of life (E2) and not modeled
- BLAST fit range 10-45 °C, charge rate up to 0.65C (the regen and charge limit is 0.5C, inside the range)
- placeholder route and schedule
- the EVE MB31 datasheet copy is from a distributor; confirm the revision with EVE

To make E4 a warranted figure, we need from EVE/Jinko:

- calendar aging at 25, 35 and 45 °C and at several SOCs
- cycle life at 35-45 °C
- the pack-level warranty curve

## F2: Charging time

Parked charging, pack preconditioned to 25 °C. The BMS charge limit is 2,198 A (0.5C), about 3.0 MW at the battery, so a 3 MW charger is battery-limited. The "normal window" is from the SOC after a 3-trip shift with no charging (53 %) back to 90 %.

| Condition | Peak MW | 10→80 % min | 20→90 % min | 53→90 % min | Cell max °C | Charger coolant °C | Verdict |
|---|---|---|---|---|---|---|---|
| Maximum: 3.0 MW charger, 25 C | 3.00 | 86 | 86 | 46 | 28.0 | 28.5 | OPTIMAL |
| Maximum power, hot day: 3.0 MW, 46 C | 3.00 | 86 | 86 | 46 | 28.1 | 49.8 | OPTIMAL |
| Nominal: 2.0 MW plant microgrid, 40 C | 2.00 | 129 | 129 | 69 | 28.0 | 42.8 | OPTIMAL |
| Minimum: 1.2 MW (plant PV only), 46 C | 1.20 | 216 | 217 | 116 | 28.0 | 48.1 | OPTIMAL |
| Cold morning: 3.0 MW, 0 C | 3.00 | 86 | 86 | 46 | 28.0 | 3.5 | OPTIMAL |

![Charging](fig_F2_charging.png)

## G5: Heat rejection (normal and emergency conditions)

Heat the locomotive rejects to the surrounding air, rebuilt second by second from the simulated thermal states with the model's own heat-path equations. Seven paths:

1. **Condenser radiators:** battery heat lifted by the chillers, plus compressor power.
2. **PE radiators:** chopper, onboard charger and inverter losses.
3. **Traction motor blowers:** motor copper losses.
4. **Friction brakes:** at the wheels.
5. **Auxiliary loads:** electrical input to the cab, compressor, blowers and controls, all ending as heat.
6. **Battery enclosure:** pack to ambient.
7. **String connection losses.**

Items 6 and 7 are grouped as "other". The pack enclosure runs below ambient on hot days, so it is a small heat *gain*.

| Case | Condenser kW | PE kW | Motors kW | Friction kW | Aux kW | Other kW | Total peak kW | Mean moving kW | Mean charging kW | Shift MWh |
|---|---|---|---|---|---|---|---|---|---|---|
| Base: 3 round trips, 2 MW plant charging, 40 C | 100 | 16 | 9 | 0 | 85 | -1 | **201** | 67 | 35 | 0.46 |
| 46 C ambient, base cycle | 94 | 20 | 9 | 0 | 91 | -3 | **207** | 69 | 71 | 0.54 |
| Maximum heat: 46 C, 655 kW motors, 3 MW plant charging | 94 | 26 | 9 | 0 | 91 | -3 | **202** | 61 | 69 | 0.57 |
| Fault, 46 C: condenser radiator fans failed | 32 | 18 | 9 | 0 | 56 | -3 | **98** | 67 | 70 | 0.55 |
| Fault, 46 C: PE radiator fans failed | 94 | 16 | 9 | 0 | 76 | -3 | **185** | 52 | 55 | 0.38 |
| Fault, 46 C: traction motor blowers failed | 94 | 20 | 4 | 0 | 91 | -3 | **202** | 66 | 67 | 0.51 |
| Fault, 46 C: VMS lost (radiator fans and chillers off) | 0 | 6 | 0 | 0 | 0 | -5 | **1** | -1 | NaN | -0.01 |

Each path's figure is its highest 5-minute average in the shift. The paths peak at different times, so the "Total peak" column is the peak of the sum, not the sum of the peaks.

![Heat rejection](fig_G5_heat_rejection.png)

**Normal operation.** In the base case peak heat rejection is 201 kW, which occurs while pulling. The shift total is 0.46 MWh of heat.

- Under way, about 67 kW goes to air on average.
- Regen covers all the braking on this route, so the friction brakes reject almost nothing.
- At 46 °C with 655 kW motors and 3 MW charging, the peak stays at 202 kW. The radiators reject less per kelvin of coolant temperature, which is why the condenser runs hotter (57.2 °C vs 51.9 °C).

**Emergency (cooling-fault) conditions at 46 °C, base duty cycle:**

| Case | Condenser max °C | PE coolant max °C | Motor max °C | Cell max °C | Discharge derate factor | Min > 2 mph slow | Verdict | Limit reached |
|---|---|---|---|---|---|---|---|---|
| Maximum heat: 46 C, 655 kW motors, 3 MW plant charging | 57.2 | 49.7 | 67 | 28.1 | 1.00 | 0.8 | OPTIMAL |  |
| Fault, 46 C: condenser radiator fans failed | 64.9 | 48.5 | 67 | 28.0 | 1.00 | 0.8 | OK | PE margin 0.1 K |
| Fault, 46 C: PE radiator fans failed | 57.2 | 59.2 | 67 | 28.0 | 1.00 | 0.8 | FAIL | charger supply > 55 C; inverter fluid > 60 C |
| Fault, 46 C: traction motor blowers failed | 57.2 | 48.8 | 106 | 28.0 | 1.00 | 0.8 | OPTIMAL |  |
| Fault, 46 C: VMS lost (radiator fans and chillers off) | 46.0 | 51.4 | 49 | 31.2 | 1.00 | 234.1 | FAIL | chopper fluid > 63 C |

Limits:

- condenser check valve: 65 °C
- charger coolant inlet: 55 °C
- inverter: 60 °C
- chopper: 63 °C
- motor: 180 °C
- BMS hot derate: 45-50 °C cell

A fan or blower failure moves heat into the remaining paths and raises temperatures. Fault by fault:

- **condenser radiator fans failed:** the shift completes, but with almost no margin left (PE margin 0.1 K).
- **PE radiator fans failed:** the shift completes on time, but coolant limits are crossed (charger supply > 55 C; inverter fluid > 60 C). This fault needs a protective response: derate charging and traction, or stop.
- **traction motor blowers failed:** the shift completes inside all limits (motor 106 °C against 180 °C).
- **VMS lost (radiator fans and chillers off):** the locomotive stops (234 min behind the trace) and heat rejection falls to almost nothing, but residual heat still crosses a limit (chopper fluid > 63 C).

**Not modeled:**

- radiator exhaust air temperature and flow (needs the radiator air-side data)
- solar load
- cab HVAC rejection detail (inside the aux total)
- thermal-runaway heat release, which belongs to the battery safety case, not the operating model

**The rest of G5 comes from documents, not the model:** noise, waste, hazardous materials and battery handling. Sources on Drive (not reviewed here):

- *Jinko Batteries SDS*
- *Jinko Batteries Hazard Mitigation Analysis*
- *Jinko Fire Suppression Doc*
- *Jinko 5MWh liquid-cooled ESS User Manual*, which gives ≤ 80 dB(A) at 1 m for the stationary container, not the locomotive

Locomotive noise needs a fan and blower acoustic estimate or a measurement.

## Not answered by the model

The model can't answer these RFI questions:

- **D2:** individual-axle slip and slide control evidence.
- **F3:** utility demand schedule. Peak charger demand is in F2.
- **G5 (non-thermal parts):** noise, waste, hazardous materials, battery handling (documents; see G5).
- **A, B1/B3/B4, E5-E8, F1/F4-F6, G-J:** documentation and commercial items, not simulation.

## Files

The answer pack is written to `cemex/rfi_out/`:

- per-question CSVs: `C1_*.csv`, `C2_C5_E2_*.csv`, `C3_*.csv`, `C4_*.csv`, `C7_*.csv`, `D1_*.csv`, `D4_*.csv`, `D6_*.csv`, `E3_*.csv`, `E4_*.csv`, `F2_*.csv`, `G5_*.csv`
- figures: `fig_*.png`
- cached simulations: `rfi_sims.mat`

To re-run all simulations:

```matlab
cemex_rfi_report('Rerun', true)
```
