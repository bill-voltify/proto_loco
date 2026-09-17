function p = voltify_gp40_params()
% VOLTIFY_GP40_PARAMS  Standard GP40 + Voltify battery/drivetrain params
% Sources: Voltify-System-Architecture.md, GP40-V Spec, memory notes.
% Flagged items are estimates pending confirmation (RSK candidates).

%% Vehicle / mechanical (GP40 standard values — CONFIRM vs actual consist)
p.mass_kg          = 270000 * 0.453592;   % 270,000 lb -> kg (mid of 265-275k lb range)
p.wheel_dia_in     = 40;
p.wheel_radius_m   = (p.wheel_dia_in/2) * 0.0254;
p.gear_ratio       = 4.13;                % EMD 62:15 typical GP40 traction gear ratio [ESTIMATE - confirm]
p.n_motors         = 4;                   % D77 x4 per architecture doc
p.Crr              = 0.002;               % steel wheel/rail rolling resistance coeff [ESTIMATE]
p.Cd               = 0.8;                 % drag coeff, switcher duty [ESTIMATE, likely negligible <30mph]
p.frontal_area_m2  = 10;                  % [ESTIMATE]
p.rho_air          = 1.225;
p.g                = 9.81;
p.grade_pct        = 0;                   % flat yard assumption; override per duty cycle

%% Drivetrain efficiency (Integral choppers + D77 motors)
p.eta_motoring     = 0.92;                % DC-link -> wheel, [ESTIMATE - need Integral data]
p.eta_regen        = 0.85;                % wheel -> DC-link during braking [ESTIMATE]
p.regen_enabled    = true;

%% Traction Battery (from Voltify-System-Architecture.md)
p.batt.V_max          = 1476.8;   % V, ESS Maximum Voltage
p.batt.V_min           = 1185.6;  % V, ESS Minimum Voltage
p.batt.V_nom           = 1300;    % approx nominal
p.batt.capacity_Ah      = 3768;    % ESS Capacity
p.batt.energy_kWh       = 5015.96;
p.batt.peak_discharge_A = 1884;
p.batt.n_strings        = 6;
p.batt.packs_per_string = 4;
p.batt.Rint_ohm         = 0.05;   % PACK-LEVEL LUMPED ESTIMATE — cell DCIR is 7.5 mOhm
                                   % (Jinko LFP @0.5C) but pack/string series-parallel
                                   % count not specified in source docs -> RSK: confirm
                                   % string-level internal resistance from Maxwell/Jinko datasheets.
p.batt.SOC_init         = 0.9;    % initial SOC fraction

%% Aux load (from Auxiliary Power Budget table, Voltify-System-Architecture.md)
% Simple state-based lookup; override with measured data as it becomes available (all flagged stale/estimate in source doc)
p.aux.deep_sleep_W       = 50;
p.aux.standby_idle_W     = 835;
p.aux.standby_btms_maint_W = 2400;
p.aux.standby_btms_active_W = 64000;
p.aux.worst_case_W       = 100000;

end
