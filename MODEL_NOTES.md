# Proto Loco v2 — Simscape Model Notes

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
| R0_cell 0.5 mΩ, R1 0.3 mΩ, τ 30 s | — | Generic 314 Ah LFP | **Placeholder; conflicts with 7.5 mΩ in earlier params** |
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
| 3 | **Cell DCIR conflict:** 7.5 mΩ (earlier source) vs ~0.5 mΩ typical for 314 Ah. 7.5 mΩ implies 0.26 Ω pack, a 490 V sag at 1884 A. |
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
