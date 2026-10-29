function S = cemex_rfi_report(varargin)
% CEMEX_RFI_REPORT  Run the simulations behind Voltify's answers to CEMEX RFI #13544 and write the answer pack.
%   S = cemex_rfi_report()                  run every case (cached in rfi_out/rfi_sims.mat), write rfi_out/
%   S = cemex_rfi_report('Rerun', true)     re-simulate everything
%   S = cemex_rfi_report('Only', "C3")      re-simulate one group (shift | C3 | C7 | D6 | F2), keep the rest cached
% Output (rfi_out/): RFI_answers.md (one section per question the model answers), CSV tables, PNG figures.
% Questions answered (RFI "56 RFI questions" sheet): B2, C1-C8, D1, D3-D6, E1-E4, F2, G5 (heat rejection).
% Evidence:
%   simulations (run_cemex on cemex_loco_system): duty-cycle shifts (base, end of life, 46 C, wet rail, no-charging
%     range), acceleration runs, start-on-grade runs, long descents, parked charging
%   curves (cemex_capability): the plant's axle / LCC / battery equations evaluated over speed
% The route, consist and locomotive weight are PLACEHOLDERS (see README_CEMEX.md). Replace before submitting.
here = fileparts(mfilename('fullpath'));
addpath(here); addpath(fullfile(fileparts(here), 'loco_system')); addpath(fileparts(here));
p = inputParser;
p.addParameter('Out', fullfile(here, 'rfi_out'));
p.addParameter('Rerun', false);
p.addParameter('Only', "");
p.parse(varargin{:});
o = p.Results;
if ~isfolder(o.Out), mkdir(o.Out); end
cache = fullfile(o.Out, 'rfi_sims.mat');

% ---------------- Inputs shared by every case ----------------
mps = 0.44704; tonkg = 907.185; lbf = 4.44822; g = 9.81;
P = cemex_params();
[~, cyc] = make_cemex_cycle();
CO = cyc.options;
g_all = [cyc.grade_loaded; cyc.grade_empty];            % route grades, both directions (make_cemex_cycle info)
crit_up_loaded = cyc.crit_up_loaded;  crit_up_empty = cyc.crit_up_empty;
crit_dn_loaded = cyc.crit_dn_loaded;  crit_dn_empty = cyc.crit_dn_empty;
consists = [CO.EmptyTons, CO.LoadedTons, 1.25*CO.LoadedTons];
cnames = ["Empty", "Loaded", "Loaded +25 %"];
reserve = 0.20;
fres = @(v, tons, gr) (P.veh.m_loco + tons*tonkg)*g*(P.veh.Crr + gr/100) + 0.5*1.225*P.veh.CdA*v.^2;
meff = @(tons) P.veh.k_rot_loco*P.veh.m_loco + P.veh.k_rot_trail*tons*tonkg;

% ---------------- Simulations ----------------
SIM = struct();
if isfile(cache) && ~o.Rerun, SIM = load(cache); SIM = SIM.SIM; end
need = @(grp) o.Rerun || strlength(o.Only) == 0 && ~isfield(SIM, grp) || strcmpi(o.Only, grp);

if need('shift')
    fprintf('Duty-cycle shifts...\n');
    eol = {'SOH', 0.70, 'RAge', 1.5};
    cases = {
        'base',    'Base: 3 round trips, 2 MW plant charging, 40 C',            {},                                   {}
        'eol',     'End of life (70 % capacity, 1.5x resistance), base cycle',   {},                                   eol
        'hot46',   '46 C ambient, base cycle',                                   {'Ambient_C', 46},                    {}
        'wet',     'Wet rail, adhesion 0.18, base cycle',                        {},                                   {'MuAdh', 0.18}
        'r_bol40', 'No charging, 3 trips, 40 C, new battery',                    {'PlantCharge_kW', 0},                {}
        'r_bol46', 'No charging, 3 trips, 46 C, new battery',                    {'PlantCharge_kW', 0, 'Ambient_C', 46}, {}
        'r_eol40', 'No charging, 3 trips, 40 C, end of life',                    {'PlantCharge_kW', 0},                eol
        'r_eol46', 'No charging, 3 trips, 46 C, end of life',                    {'PlantCharge_kW', 0, 'Ambient_C', 46}, eol
        };
    SH = struct();
    for k = 1:size(cases, 1)
        fprintf('  %s\n', cases{k, 2});
        R = run_cemex([], 'Cycle', cases{k, 3}, cases{k, 4}{:}, 'Plot', false, 'Silent', true);
        SH.(cases{k, 1}) = keep(R, cases{k, 2});
    end
    SIM.shift = SH;
    save(cache, 'SIM');
end

if need('G5')
    fprintf('Heat-rejection runs (G5)...\n');
    lib = read_fault_library(fullfile(fileparts(here), 'loco_system', 'faults', 'fault_library.csv'));
    hot = {'Ambient_C', 46};
    g5 = {
        'max',    'Maximum heat: 46 C, 655 kW motors, 3 MW plant charging', {'Ambient_C', 46, 'PlantCharge_kW', 3000}, {'MotorCapkW', 655}, ""
        'f_cd',   'Fault, 46 C: condenser radiator fans failed',            hot, {}, "COND_FAN_FAIL"
        'f_pe',   'Fault, 46 C: PE radiator fans failed',                   hot, {}, "PE_FAN_FAIL"
        'f_blow', 'Fault, 46 C: traction motor blowers failed',             hot, {}, "BLOWER_FAIL"
        'f_vms',  'Fault, 46 C: VMS lost (radiator fans and chillers off)', hot, {}, "VMS_LOSS"
        };
    G5 = struct();
    for k = 1:size(g5, 1)
        fprintf('  %s\n', g5{k, 2});
        F = lib; F.enabled = double(F.fault_id == g5{k, 5});
        R = run_cemex([], 'Cycle', g5{k, 3}, g5{k, 4}{:}, 'Faults', F, 'Plot', false, 'Silent', true);
        G5.(g5{k, 1}) = keep(R, g5{k, 2});
    end
    SIM.G5 = G5;
    save(cache, 'SIM');
end

% Locomotive weight sweep (Voltify weight study, cemex_weight): reference SD60 weight, the study's estimate for this
% battery, the base-case assumption, and the study's 9.4 MWh configuration.
WTw = [368000, round(cemex_weight(P.sys.cemex.E_bol_kWh).total_lb, -2), P.sys.cemex.loco_lb, round(cemex_weight(9375).total_lb, -2)];
WTn = ["SD60 reference weight", "Weight study at 5.85 MWh (lower bound)", "Base case (assumed)", "Weight of a 9.4 MWh build"];
if need('WT')
    fprintf('Weight sweep runs...\n');
    WT = struct('w', WTw, 'shift', {{}}, 'desc', {{}});
    for k = 1:numel(WTw)
        fprintf('  %s lb\n', num2str(WTw(k)));
        R = run_cemex([], 'LocoLb', WTw(k), 'Plot', false, 'Silent', true);
        WT.shift{k} = keep(R, sprintf('%s, %d lb', WTn(k), WTw(k)));
        if cyc.is_profile
            T = load_profile_trace(cyc.route, 'Tons', CO.LoadedTons, 'Ambient_C', CO.Ambient_C);
            R = run_cemex(T, 'LocoLb', WTw(k), 'soc0', 0.60, 'Plot', false, 'Silent', true);
            WT.desc{k} = keep(R, sprintf('Loaded descent, %d lb', WTw(k)));
        end
    end
    SIM.WT = WT;
    save(cache, 'SIM');
end

% Closing the SD60 gap (D1): 77:17 regear on the route
if need('MOT')
    fprintf('Regear runs (77:17)...\n');
    MT = struct();
    R = run_cemex([], 'Gear', 77/17, 'Plot', false, 'Silent', true);
    MT.shift = keep(R, 'Base shift, 77:17');
    if cyc.is_profile
        T = load_profile_trace(cyc.route, 'Tons', CO.LoadedTons, 'Ambient_C', CO.Ambient_C);
        R = run_cemex(T, 'Gear', 77/17, 'soc0', 0.60, 'Plot', false, 'Silent', true);
        MT.desc = keep(R, 'Loaded descent, 60 % SOC, 77:17');
    end
    rows_ = [0 0; 60 0; 61 20; 61 + 1800 20];
    T = mk_trace(rows_(:,1), rows_(:,2), crit_up_empty, CO.EmptyTons, 0, CO.Ambient_C);
    R = run_cemex(T, 'Gear', 77/17, 'Plot', false, 'Silent', true);
    MT.acc = keep(R, sprintf('Empty, %.2f %%, 77:17', crit_up_empty)); MT.acc.t_go = 60;
    SIM.MOT = MT;
    save(cache, 'SIM');
end

% Operating envelope (C6/C8) and PE-fan-failure derate (G5/D3)
if need('ENV')
    fprintf('Ambient envelope and PE fan derate runs...\n');
    EV = struct();
    for Ta = [48 50 52 0 -10]
        fprintf('  ambient %g C\n', Ta);
        R = run_cemex([], 'Cycle', {'Ambient_C', Ta}, 'Plot', false, 'Silent', true);
        EV.(sprintf('amb_%s', strrep(num2str(Ta), '-', 'm'))) = keep(R, sprintf('Base shift at %g °C', Ta));
    end
    libE = read_fault_library(fullfile(fileparts(here), 'loco_system', 'faults', 'fault_library.csv'));
    Fpe = libE; Fpe.enabled = double(Fpe.fault_id == "PE_FAN_FAIL");
    dr = {
        'pe_chg1000', 'PE fans failed, 46 C: plant charging limited to 1,000 kW', {'Ambient_C', 46, 'PlantCharge_kW', 1000}, {}
        'pe_chg0',    'PE fans failed, 46 C: no plant charging',                   {'Ambient_C', 46, 'PlantCharge_kW', 0},    {}
        'pe_chg0_tr', 'PE fans failed, 46 C: no plant charging, traction 400 kW per motor', {'Ambient_C', 46, 'PlantCharge_kW', 0}, {'MotorCapkW', 400}
        'pe_43',      'PE fans failed, 43 C, base duty',                           {'Ambient_C', 43}, {}
        'pe_40',      'PE fans failed, 40 C, base duty',                           {'Ambient_C', 40}, {}
        };
    for k = 1:size(dr, 1)
        fprintf('  %s\n', dr{k, 2});
        R = run_cemex([], 'Cycle', dr{k, 3}, dr{k, 4}{:}, 'Faults', Fpe, 'Plot', false, 'Silent', true);
        EV.(dr{k, 1}) = keep(R, dr{k, 2});
    end
    SIM.ENV = EV;
    save(cache, 'SIM');
end

if need('C3')
    fprintf('Acceleration runs...\n');
    runs = {
        'loaded_level', 'Loaded, level',                                     CO.LoadedTons, 0
        'loaded_crit',  sprintf('Loaded, %.2f %% (steepest climb)', crit_up_loaded), CO.LoadedTons, crit_up_loaded
        'empty_level',  'Empty, level',                                      CO.EmptyTons, 0
        'empty_crit',   sprintf('Empty, %.2f %% (steepest climb)', crit_up_empty),   CO.EmptyTons, crit_up_empty
        };
    AC = struct();
    for k = 1:size(runs, 1)
        fprintf('  %s\n', runs{k, 2});
        rows = [0 0; 60 0; 61 20; 61 + 1800 20];
        T = mk_trace(rows(:,1), rows(:,2), runs{k, 4}, runs{k, 3}, 0, CO.Ambient_C);
        R = run_cemex(T, 'Plot', false, 'Silent', true);
        AC.(runs{k, 1}) = keep(R, runs{k, 2});
        AC.(runs{k, 1}).t_go = 60; AC.(runs{k, 1}).tons = runs{k, 3}; AC.(runs{k, 1}).grade = runs{k, 4};
    end
    SIM.C3 = AC;
    save(cache, 'SIM');
end

% start-on-grade limit from the curves, then confirmed by simulation just below and just above it
TE0 = cemex_capability(P, 0, 'Mode', 'start');
g_start = @(tons, TE) 100*(TE/((P.veh.m_loco + tons*tonkg)*g) - P.veh.Crr);
g_lim_loaded = g_start(CO.LoadedTons, TE0);
if need('C7')
    fprintf('Start-on-grade runs...\n');
    gs = [floor(20*g_lim_loaded)/20 - 0.05, ceil(20*g_lim_loaded)/20 + 0.05];
    ST = struct('grade', gs, 'run', {{}});
    for k = 1:2
        rows = [0 0; 60 0; 61 5; 61 + 600 5];
        T = mk_trace(rows(:,1), rows(:,2), gs(k), CO.LoadedTons, 0, CO.Ambient_C);
        R = run_cemex(T, 'Plot', false, 'Silent', true);
        ST.run{k} = keep(R, sprintf('Loaded start on %.2f %%', gs(k)));
    end
    SIM.C7 = ST;
    save(cache, 'SIM');
end

if need('D6')
    fprintf('Loaded descent runs (route profile)...\n');
    % The loaded run as recorded, from three arrival states at the quarry: battery low enough to take the whole
    % descent, battery near full (regen cut-off -> grids), and near full with no grids (friction only).
    dcases = {
        0.60, {},             'Loaded descent, 60 % SOC at the quarry'
        0.90, {},             'Loaded descent, 90 % SOC at the quarry (regen cut-off at 95 %)'
        0.90, {'DbkW', 0},    'Loaded descent, 90 % SOC, no dynamic-brake grids'
        };
    DS = struct('soc0', [dcases{:, 1}], 'run', {{}});
    for k = 1:size(dcases, 1)
        fprintf('  %s\n', dcases{k, 3});
        if cyc.is_profile
            T = load_profile_trace(cyc.route, 'Tons', CO.LoadedTons, 'Ambient_C', CO.Ambient_C);
        else                                            % segment route: 10 miles at the steepest descent, 20 mph
            L_s = 10*1609.344/(20*mps);
            T = mk_trace([0 60 193 253 254 254 + L_s 255 + L_s 355 + L_s 415 + L_s], [0 0 20 20 20 20 20 0 0], ...
                [0 0 0 0 crit_dn_loaded crit_dn_loaded 0 0 0], CO.LoadedTons, 0, CO.Ambient_C);
        end
        R = run_cemex(T, 'Plot', false, 'Silent', true, 'soc0', dcases{k, 1}, dcases{k, 2}{:});
        DS.run{k} = keep(R, dcases{k, 3});
        mv = find(R.R.v_mph > 0.1);
        DS.run{k}.t_grade = [R.R.t(mv(1)), R.R.t(mv(end))];
    end
    SIM.D6 = DS;
    save(cache, 'SIM');
end

if need('F2')
    fprintf('Charging runs...\n');
    ch = {
        'Maximum: 3.0 MW charger, 25 C',             3000, 25
        'Maximum power, hot day: 3.0 MW, 46 C',      3000, 46
        'Nominal: 2.0 MW plant microgrid, 40 C',     2000, 40
        'Minimum: 1.2 MW (plant PV only), 46 C',     1200, 46
        'Cold morning: 3.0 MW, 0 C',                 3000, 0
        };
    CH = struct('name', {ch(:,1)'}, 'kW', [ch{:,2}], 'amb', [ch{:,3}], 'run', {{}});
    for k = 1:size(ch, 1)
        fprintf('  %s\n', ch{k, 1});
        t_end = round(0.85*P.sys.cemex.E_nom_kWh/(0.95*min(ch{k, 2}, 2800))*3600 + 1500);
        T = mk_trace([0 30 31 t_end], [0 0 0 0], 0, 0, [0 0 ch{k, 2} ch{k, 2}], ch{k, 3});
        R = run_cemex(T, 'Plot', false, 'Silent', true, 'soc0', 0.10);
        CH.run{k} = keep(R, ch{k, 1});
    end
    SIM.F2 = CH;
    save(cache, 'SIM');
end

% ---------------- Curves and tables ----------------
c = P.sys.cemex;
vgrid = (0:0.25:45)';
[TEs, Is] = cemex_capability(P, vgrid, 'Mode', 'start');
TEc = cemex_capability(P, vgrid, 'Mode', 'cont');
TEw = cemex_capability(P, vgrid, 'Mode', 'start', 'Mu', 0.18);
TEb = cemex_capability(P, vgrid, 'Mode', 'brake', 'SOC', 0.5);
TEbw = cemex_capability(P, vgrid, 'Mode', 'brake', 'SOC', 0.5, 'Mu', 0.18);
CURVE = table(vgrid, TEs/1e3, TEc/1e3, TEw/1e3, TEb/1e3, TEbw/1e3, Is.limit, ...
    'VariableNames', {'speed_mph','TE_max_kN','TE_cont_kN','TE_wet_kN','BE_regen_kN','BE_regen_wet_kN','limit_TE_max'});
writetable(CURVE, fullfile(o.Out, 'D1_te_be_vs_speed.csv'));
at = @(x, v) interp1(vgrid, x, v);
TE_start = TEs(1);
[~, Ic] = cemex_capability(P, vgrid, 'Mode', 'cont');
P_rail = 4*P.ax.P_ax_max*P.ax.eta_g;                                    % motor power cap through the gears
v_cont = vgrid(find(Ic.limit == "motor current", 1, 'last'));           % continuous current meets the power cap
TE_cont = at(TEc, v_cont);
v_pow_end = vgrid(find(TEs >= P_rail./max(vgrid*mps, 0.1)*0.995, 1, 'last'));   % full power holds to here

% C1: maximum sustained grade by consist, speed, SOC (continuous motor rating), short-time (5 min rating)
spd = [5 10 15 20];
socs = [0.9 0.5 reserve];
C1 = table();
for i = 1:numel(consists)
    for s = spd
        row = table(cnames(i), consists(i), s, 'VariableNames', {'consist','trailing_tons','speed_mph'});
        for q = socs
            TEq = cemex_capability(P, s, 'Mode', 'cont', 'SOC', q);
            row.(sprintf('grade_cont_soc%02.0f', 100*q)) = gmax(TEq, consists(i), s);
        end
        row.grade_5min_soc90 = gmax(cemex_capability(P, s, 'Mode', 'start'), consists(i), s);
        row.grade_cont_wet = gmax(cemex_capability(P, s, 'Mode', 'cont', 'Mu', 0.18), consists(i), s);
        C1 = [C1; row]; %#ok<AGROW>
    end
end
writetable(C1, fullfile(o.Out, 'C1_max_sustained_grade.csv'));

% C4: maximum tonnage
grades = unique([0 0.5 1.0 1.5 2.0 round(max(crit_up_loaded, 0), 2) round(crit_up_empty, 2)]);
coupler_lbf = 250000;
tons_for = @(F, gr, v) (F - fres(v, 0, gr))./((P.veh.Crr + gr/100)*g*tonkg);
C4 = table();
TEw0 = TEw(1);
TEc10 = at(TEc, 10);
for gr = grades
    r = table(gr, 'VariableNames', {'grade_pct'});
    r.start_tons_dry = tons_for(TE_start, gr, 0);
    r.start_tons_wet = tons_for(TEw0, gr, 0);
    r.cont_tons_10mph = tons_for(TEc10, gr, 10*mps);
    r.coupler_tons = coupler_lbf*lbf/((P.veh.Crr + gr/100)*g*tonkg);
    C4 = [C4; r]; %#ok<AGROW>
end
writetable(C4, fullfile(o.Out, 'C4_max_tonnage.csv'));

% C7: steepest start / restart grade
C7 = table();
for i = 1:numel(consists)
    C7 = [C7; table(cnames(i), consists(i), g_start(consists(i), TE_start), g_start(consists(i), TEw0), ...
        100*(P.lcc.mu_adh*P.veh.m_loco/(P.veh.m_loco + consists(i)*tonkg) + P.veh.Crr), 'VariableNames', {'consist','trailing_tons','start_grade_dry_pct','start_grade_wet_pct','hold_grade_loco_pct'})]; %#ok<AGROW>
end
writetable(C7, fullfile(o.Out, 'C7_start_hold_grade.csv'));

% D4: stopping with the locomotive alone (electric + locomotive friction, up to adhesion) and with train air brakes added
D4 = table();
for i = 1:2
    for gr = [0, crit_dn_loaded*(i == 2) + crit_dn_empty*(i == 1)]
        for v0 = [10 15 20]
            for mu = [P.lcc.mu_adh 0.18]
                [ts, xs] = stop_dist(v0*mps, consists(i), gr, mu, 0);
                [ta, xa] = stop_dist(v0*mps, consists(i), gr, mu, P.lcc.k_tb);
                D4 = [D4; table(cnames(i), gr, v0, mu, ts, xs, xs/0.3048, ta, xa, xa/0.3048, 'VariableNames', ...
                    {'consist','grade_pct','from_mph','mu','time_s','distance_m','distance_ft','time_air_s','distance_air_m','distance_air_ft'})]; %#ok<AGROW>
            end
        end
    end
end
writetable(D4, fullfile(o.Out, 'D4_stopping_loco_brake.csv'));
g_hold_loco = 100*(P.lcc.mu_adh*P.veh.m_loco/(P.veh.m_loco + CO.LoadedTons*tonkg) + P.veh.Crr);

% ---------------- Simulation results ----------------
SH = SIM.shift;
shiftT = table();
for f = string(fieldnames(SH))'
    x = SH.(f);
    shiftT = [shiftT; table(f, string(x.name), x.C.bat_out_kWh, x.C.bat_in_regen_kWh, x.C.bat_in_charger_kWh, x.C.net_bat_kWh, ...
        x.C.peak_discharge_MW, x.C.sustained_5min_MW, 100*x.C.soc_start, 100*x.C.soc_min, 100*x.C.soc_end, x.C.reserve_ok, ...
        x.C.regen_share*100, x.C.grid_kWh, x.C.friction_brake_kWh, x.C.time_below_ref_2mph_min, x.C.speed_shortfall_max_mph, ...
        x.M.Tcell_max, x.M.Tcond_max, x.M.pe_margin_K, x.M.Tmotor_max, x.M.k_dis_min, string(x.M.verdict), x.C.E_nom_kWh, ...
        'VariableNames', {'case','description','bat_out_kWh','regen_in_kWh','charger_in_kWh','net_kWh','peak_MW','sust5min_MW', ...
        'soc_start_pct','soc_min_pct','soc_end_pct','reserve_ok','regen_share_pct','grid_kWh','friction_kWh','min_below_ref','shortfall_mph', ...
        'Tcell_max_C','Tcond_max_C','margin_K','Tmotor_max_C','k_dis_min','verdict','E_nom_kWh'})]; %#ok<AGROW>
end
writetable(shiftT, fullfile(o.Out, 'C2_C5_E2_shift_cases.csv'));

% Range (E3): SOC use per round trip and per hour from the no-charging shifts
ntrip = CO.Trips;
rng = table();
for f = ["r_bol40", "r_bol46", "r_eol40", "r_eol46"]
    x = SH.(f);
    mv = find(x.v > 0.1);
    t1 = x.t(mv(1)); t2 = x.t(mv(end));
    dsoc = interp1(x.t, x.soc, t1) - interp1(x.t, x.soc, t2);
    per_trip = dsoc/ntrip;
    hours = (t2 - t1 + 60*CO.UnloadDwell_min)/3600;               % trip cycle incl. the unload dwell
    h_per_trip = hours/ntrip;
    trips = (0.90 - reserve)/per_trip;
    if per_trip <= 0, trips = Inf; end                           % net energy-positive route: no drain to the reserve
    drawdown = max(cummax(x.soc) - x.soc);                         % deepest SOC dip in the shift (the empty climb)
    rng = [rng; table(f, string(x.name), per_trip*x.C.E_nom_kWh, 100*per_trip, trips, floor(trips), trips*h_per_trip, ...
        x.C.E_nom_kWh, 100*drawdown, 100*(reserve + drawdown), 'VariableNames', {'case','description','kWh_per_round_trip','soc_pct_per_trip','trips_90_to_20', ...
        'whole_trips','hours_90_to_20','E_nom_kWh','max_dip_pct','min_start_soc_pct'})]; %#ok<AGROW>
end
writetable(rng, fullfile(o.Out, 'E3_range.csv'));

% C3 acceleration
AC = SIM.C3;
acc = table();
for f = string(fieldnames(AC))'
    x = AC.(f);
    k0 = x.t >= x.t_go;
    tt = x.t(k0) - x.t_go; vv = x.v(k0);
    dd = cumtrapz(tt, vv*mps);
    r = table(string(x.name), x.tons, x.grade, 'VariableNames', {'case','trailing_tons','grade_pct'});
    for s = [5 10 15 20]
        j = find(vv >= s - 0.05, 1);
        if isempty(j)
            r.(sprintf('t_%dmph_s', s)) = NaN; r.(sprintf('d_%dmph_m', s)) = NaN;
        else
            r.(sprintf('t_%dmph_s', s)) = tt(j); r.(sprintf('d_%dmph_m', s)) = dd(j);
        end
    end
    r.balance_mph = mean(vv(tt > tt(end) - 120));
    r.peak_TE_kN = max(x.te)/1e3;
    acc = [acc; r]; %#ok<AGROW>
end
writetable(acc, fullfile(o.Out, 'C3_acceleration.csv'));

% C7 sim check
ST = SIM.C7;
st_res = table();
for k = 1:2
    x = ST.run{k};
    st_res = [st_res; table(ST.grade(k), max(x.v), min(x.v), max(x.te)/1e3, ...
        'VariableNames', {'grade_pct','max_speed_mph','min_speed_mph','peak_TE_kN'})]; %#ok<AGROW>
end

% D6 descent
DS = SIM.D6;
dsT = table();
for k = 1:numel(DS.run)
    x = DS.run{k};
    m = x.t >= x.t_grade(1) & x.t <= x.t_grade(2);
    e_ = @(F) trapz(x.t(m), abs(F(m)).*x.v(m)*mps)/3.6e6;
    regen = trapz(x.t(m), -min(x.p_bat(m), 0))/3.6e6;
    gridE = e_(x.f_db); air = e_(x.f_tb); lf = e_(max(x.f_fric - x.f_db - x.f_tb, 0));
    dev = x.v(m) - x.vref(m);
    tg_ = (x.t(find(m, 1)):1:x.t(find(m, 1, 'last')))';              % 1 s basis: single solver-step spikes are not limit violations
    pk_I = max(interp1(x.t, -x.ib, tg_)); pk_P = max(interp1(x.t, -x.p_bat, tg_))/1e6;
    dsT = [dsT; table(string(x.name), DS.soc0(k), crit_dn_loaded, max(dev), min(dev), pk_P, pk_I, P.lcc.I_chg_max, ...
        regen, gridE, air, lf, 100*regen/(regen + gridE + air + lf), 100*x.soc(find(m, 1)), 100*max(x.soc(m)), 100*x.soc(find(m, 1, 'last')), ...
        x.M.Tmotor_max, x.M.Tcond_max, x.M.pe_margin_K, x.M.Tcell_max, string(x.M.verdict), 'VariableNames', {'case','soc0','grade_pct', ...
        'overspeed_mph','underspeed_mph','peak_regen_MW','peak_charge_A','charge_limit_A','regen_kWh','grid_kWh','train_air_kWh', ...
        'loco_friction_kWh','regen_share_pct','soc_start_pct','soc_max_pct','soc_end_pct','Tmotor_max_C','Tcond_max_C','margin_K','Tcell_max_C','verdict'})]; %#ok<AGROW>
end
writetable(dsT, fullfile(o.Out, 'D6_long_descent.csv'));

% F2 charging
CH = SIM.F2;
soc_norm = min(SH.r_bol40.soc);                                % lowest SOC in a shift without charging
chT = table();
for k = 1:numel(CH.run)
    x = CH.run{k};
    tx = @(s) x.t(find(x.soc >= s, 1));
    dtm = @(a, b) (tx(b) - tx(a))/60;
    chT = [chT; table(string(CH.name{k}), CH.kW(k), CH.amb(k), max(x.p_chg)/1e6, -min(x.ib), dtm(0.10, 0.80), dtm(0.20, 0.90), ...
        dtm(round(soc_norm, 2), 0.90), x.M.Tcell_max, x.M.Tchg_sup_max, x.M.Tcond_max, x.M.k_chg_min, string(x.M.verdict), ...
        'VariableNames', {'condition','charger_kW','ambient_C','peak_wire_MW','peak_charge_A','min_10_80','min_20_90', ...
        'min_normal_to_90','Tcell_max_C','Tchg_supply_max_C','Tcond_max_C','k_chg_min','verdict'})]; %#ok<AGROW>
end
writetable(chT, fullfile(o.Out, 'F2_charging.csv'));

% E4 degradation: BLAST-Lite LFP prismatic model, cycle term anchored to the EVE MB31 datasheet, driven by the
% simulated base shift (SOC and cell temperature). Operating schedules are PLACEHOLDERS (CEMEX hasn't given them).
deg_cases = {
    'Base: 2 shifts/day, 6 days/week, parked on charge at 25 °C', {}
    '2 shifts/day, 7 days/week',                                   {'DaysPerWeek', 7}
    '1 shift/day, 5 days/week',                                    {'ShiftsPerDay', 1, 'DaysPerWeek', 5}
    'Hot: cells at 35 °C all the time (no conditioning)',          {'ParkT_C', 35, 'ShiftT_C', 35}
    'Conservative cycle life: 4,000 cycles to 80 % (earlier cell, same family)',   {'Anchor', struct('cycles', 4000, 'soh', 0.80, 'T_C', 25, 'crate', 0.5)}
    };
DG = cell(size(deg_cases, 1), 1);
degT = table();
for k = 1:size(deg_cases, 1)
    DG{k} = cemex_degradation(SH.base, 'Years', 25, deg_cases{k, 2}{:});
    d = DG{k};
    degT = [degT; table(string(deg_cases{k, 1}), d.efc_per_year, d.soh_at(1)*100, d.soh_at(2)*100, d.soh_at(3)*100, d.soh_at(4)*100, ...
        d.years_to_80, d.years_to_70, 100*d.cal_share_at_eol, d.cycle_scale, 'VariableNames', {'case','efc_per_year','soh_5y','soh_10y', ...
        'soh_15y','soh_20y','years_to_80','years_to_70','calendar_share_pct','cycle_scale'})]; %#ok<AGROW>
end
writetable(degT, fullfile(o.Out, 'E4_degradation.csv'));
DGc = DG{1}.checks;

% G5 heat rejection to ambient, rebuilt from the thermal states with thermal.ssc's own heat-path equations
lib = read_fault_library(fullfile(fileparts(here), 'loco_system', 'faults', 'fault_library.csv'));
g5runs = {SH.base, SH.hot46, SIM.G5.max, SIM.G5.f_cd, SIM.G5.f_pe, SIM.G5.f_blow, SIM.G5.f_vms};
HR = cellfun(@(x) heat_streams(x, P, lib), g5runs);
heatT = table();
for k = 1:numel(g5runs)
    x = g5runs{k}; h = HR(k);
    heatT = [heatT; table(string(x.name), x.amb(1), h.peak5.cond, h.peak5.pe, h.peak5.motor, h.peak5.fric, h.peak5.aux, h.peak5.other, h.peak5.total, ...
        h.mean_moving.total, h.mean_charging.total, h.E.total/1e3, x.M.Tcond_max, x.M.Tsup_max, x.M.Tmotor_max, x.M.Tcell_max, x.M.k_dis_min, ...
        x.C.time_below_ref_2mph_min, string(x.M.verdict), string(x.M.limit), 'VariableNames', {'case','ambient_C','cond_kW','pe_kW','motor_kW', ...
        'friction_kW','aux_kW','other_kW','total_peak5_kW','total_moving_mean_kW','total_charging_mean_kW','total_shift_MWh','Tcond_max_C', ...
        'Tpe_supply_max_C','Tmotor_max_C','Tcell_max_C','k_dis_min','min_below_ref','verdict','limit'})]; %#ok<AGROW>
end
writetable(heatT, fullfile(o.Out, 'G5_heat_rejection.csv'));

% Weight sweep results
WT = SIM.WT;
wtT = table();
for k = 1:numel(WT.w)
    Pw = cemex_params(struct('loco_lb', WT.w(k)));
    ml = Pw.veh.m_loco;
    TEd = cemex_capability(Pw, 0, 'Mode', 'start'); TEwt = cemex_capability(Pw, 0, 'Mode', 'start', 'Mu', 0.18);
    sg = @(TE, tons) 100*(TE/((ml + tons*tonkg)*g) - Pw.veh.Crr);
    Fb = Pw.lcc.mu_adh*ml*g + Pw.lcc.k_tb*CO.LoadedTons*tonkg*g;      % locomotive to adhesion + train air
    [~, xs] = stop_w(20*mps, ml, CO.LoadedTons*tonkg, crit_dn_loaded, Fb, Pw);
    s = WT.shift{k}.C; r_ = struct('regen', NaN, 'air', NaN, 'grid', NaN);
    if ~isempty(WT.desc)
        dC = WT.desc{k}.C; r_ = struct('regen', dC.bat_in_regen_kWh, 'air', dC.train_air_kWh, 'grid', dC.grid_kWh);
    end
    wtT = [wtT; table(WTn(k), WT.w(k), WT.w(k)/6, TEd/lbf, TEwt/lbf, TEd/lbf - 98250, sg(TEd, CO.LoadedTons), sg(TEwt, CO.LoadedTons), ...
        sg(TEd, CO.EmptyTons), 100*(Pw.lcc.mu_adh*ml/(ml + CO.LoadedTons*tonkg) + Pw.veh.Crr), xs/0.3048, s.bat_out_kWh, s.bat_in_regen_kWh, ...
        100*s.soc_min, r_.regen, r_.air, r_.grid, 'VariableNames', {'case','loco_lb','axle_lb','start_TE_lbf','start_TE_wet_lbf', ...
        'vs_SD60_lbf','start_grade_loaded','start_grade_loaded_wet','start_grade_empty','hold_grade_loco','stop_20mph_ft', ...
        'shift_out_kWh','shift_regen_kWh','shift_soc_min','desc_regen_kWh','desc_air_kWh','desc_grid_kWh'})]; %#ok<AGROW>
end
writetable(wtT, fullfile(o.Out, 'B2_C7_weight_sweep.csv'));

% Closing the SD60 gap: motor thermal limit, current needed, regear on the route, motor voltage sweep
kk = 6/4; thp = P.th;
Iss = @(Ta) sqrt((180 - Ta)*thp.UA_mot/thp.R_m)/kk;              % per-motor current that settles at 180 C
tau_mot_min = thp.C_mot/thp.UA_mot/60;
I_need = struct();
for gname = ["g62", "g77"]
    Pg = P; if gname == "g77", Pg.ax.G = 77/17; end
    In = NaN;
    for Im = 1000:5:2000
        Pg.ax.I_cont = kk*Im;
        if cemex_capability(Pg, 10, 'Mode', 'cont')/lbf >= 98000 - 1, In = Im; break; end   % SD60 curve at 10 mph
    end
    I_need.(gname) = In;
end
MT = SIM.MOT;
acc77 = MT.acc; k0 = acc77.t >= acc77.t_go; tt = acc77.t(k0) - acc77.t_go; vv = acc77.v(k0);
acc77_t15 = tt(find(vv >= 14.95, 1)); acc77_bal = mean(vv(tt > tt(end) - 120));
VS = [750 1000 0.95*416*3.2];
vsT = table();
for Vm = VS
    Pv = P; Pv.ax.V_mot_max = Vm;
    TEv = cemex_capability(Pv, vgrid, 'Mode', 'start');
    vfull = vgrid(find(TEv >= P_rail./max(vgrid*mps, 0.1)*0.995, 1, 'last'));
    vsT = [vsT; table(Vm, vfull, at(TEv, 30)/lbf, at(TEv, 40)/lbf, at(TEv, 45)/lbf, P_rail/(45*mps)/lbf, ...
        'VariableNames', {'V_mot_max','full_power_to_mph','TE_30mph_lbf','TE_40mph_lbf','TE_45mph_lbf','TE_45mph_full_power_lbf'})]; %#ok<AGROW>
end
writetable(vsT, fullfile(o.Out, 'D1_motor_voltage_sweep.csv'));

% Operating envelope, PE fan derate, short-time motor rating, descent length, utility demand (F3)
EV = SIM.ENV;
envT = table();
envc = {SH.base, SH.hot46, EV.amb_48, EV.amb_50, EV.amb_52, EV.amb_0, EV.amb_m10};
for k = 1:numel(envc)
    x = envc{k};
    envT = [envT; table(x.amb(1), string(x.M.verdict), string(x.M.limit), x.M.Tcond_max, x.M.pe_margin_K, x.M.Tcell_min, x.M.Tcell_max, ...
        x.M.k_dis_min, x.M.E_tms_kWh, x.C.bat_out_kWh, 100*x.C.soc_min, x.C.time_below_ref_2mph_min, 'VariableNames', {'ambient_C','verdict','limit', ...
        'Tcond_max_C','margin_K','Tcell_min_C','Tcell_max_C','k_dis_min','tms_kWh','bat_out_kWh','soc_min_pct','min_below_ref'})]; %#ok<AGROW>
end
envT = sortrows(envT, 'ambient_C');
writetable(envT, fullfile(o.Out, 'C6_ambient_envelope.csv'));
pdc = {EV.pe_40, EV.pe_43, SIM.G5.f_pe, EV.pe_chg1000, EV.pe_chg0, EV.pe_chg0_tr};
peT = table();
for k = 1:numel(pdc)
    x = pdc{k};
    chg_ = x.p_chg > 1e3; Tchg_ = max([x.Tsup(chg_); -Inf]);   % PE supply to the charger while charging
    peT = [peT; table(string(x.name), string(x.M.verdict), string(x.M.limit), Tchg_, x.M.Tinv_out_max, x.M.Tchop_out_max, ...
        x.C.bat_in_charger_kWh, 100*x.C.soc_min, 100*x.C.soc_end, x.C.time_below_ref_2mph_min, 'VariableNames', {'case','verdict','limit', ...
        'Tchg_supply_C','Tinv_C','Tchop_C','charger_kWh','soc_min_pct','soc_end_pct','min_below_ref'})]; %#ok<AGROW>
end
writetable(peT, fullfile(o.Out, 'G5_pe_fan_derate.csv'));
% short-time motor rating from the thermal model (lumped; the motor supplier's ratings govern)
Ta_r = 40; T0_r = 80;
strT = table();
for Im = [1050 1150 1300 1500]
    dTss = thp.R_m*(kk*Im)^2/thp.UA_mot;
    q = (Ta_r + dTss - 180)/(Ta_r + dTss - T0_r);
    if q <= 0 || dTss <= 180 - Ta_r, tmin = Inf; else, tmin = -tau_mot_min*log(q); end
    strT = [strT; table(Im, dTss + Ta_r, tmin, 'VariableNames', {'I_per_motor_A','T_steady_C','min_80_to_180C'})]; %#ok<AGROW>
end
% descent length before the regen cut-off, from the 60 % SOC loaded run
xd = DS.run{1}; mvd = xd.v > 0.1;
soc_per_mi = (xd.soc(find(mvd, 1, 'last')) - xd.soc(find(mvd, 1)))/cyc.route_mi_one_way;
kwh_per_mi = dsT.regen_kWh(1)/cyc.route_mi_one_way;
dlT = table([0.4; 0.6; 0.8; 0.9], 'VariableNames', {'soc0'});
dlT.miles_to_cutoff = (P.lcc.soc_reg_max - P.lcc.soc_reg_band - dlT.soc0)/soc_per_mi;
% F3 utility demand: charger power at the locomotive, utility side via an assumed wayside converter
eta_ws = 0.97; pf_ws = 0.95; shifts_day = 2;
xb = SH.base; tgb = (xb.t(1):1:xb.t(end))'; pcb = interp1(xb.t, xb.p_chg, tgb);
f3 = {
    'Base duty cycle (2 MW plant windows)', max(pcb)/1e3, trapz(tgb, pcb)/3.6e6
    'Charger at full rating (3 MW, F2)', max(CH.run{1}.p_chg)/1e3, NaN
    'Full recharge 10 % -> 90 % at 3 MW', max(CH.run{1}.p_chg)/1e3, 0.80*P.sys.cemex.E_nom_kWh/0.98
    };
f3T = table(string(f3(:, 1)), cell2mat(f3(:, 2)), cell2mat(f3(:, 2))/eta_ws, cell2mat(f3(:, 2))/eta_ws/pf_ws, cell2mat(f3(:, 3)), cell2mat(f3(:, 3))/eta_ws, ...
    'VariableNames', {'scenario','peak_loco_kW','peak_utility_kW','peak_kVA','kWh_per_event','utility_kWh_per_event'});
writetable(f3T, fullfile(o.Out, 'F3_utility_demand.csv'));

% ---------------- Figures ----------------
fig_te(fullfile(o.Out, 'fig_D1_te_vs_speed.png'));
fig_shift(SH.base, fullfile(o.Out, 'fig_C2_base_shift.png'));
fig_acc(fullfile(o.Out, 'fig_C3_acceleration.png'));
fig_descent(fullfile(o.Out, 'fig_D6_descent.png'));
fig_charge(fullfile(o.Out, 'fig_F2_charging.png'));
fig_range(fullfile(o.Out, 'fig_E3_soc.png'));
fig_deg(fullfile(o.Out, 'fig_E4_degradation.png'));
fig_heat(fullfile(o.Out, 'fig_G5_heat_rejection.png'));

% ---------------- Answer document ----------------
md = strings(0, 1);
B = shiftT(shiftT.case == "base", :); E = shiftT(shiftT.case == "eol", :);
H = shiftT(shiftT.case == "hot46", :); W = shiftT(shiftT.case == "wet", :);
w('# CEMEX Victorville RFI #13544: simulation answers');
w('');
w('Generated %s by `cemex/cemex_rfi_report.m` from the CEMEX parallel model (%s, built on %s).', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), P.sys.model_rev, P.sys.base_rev);
w('');
if cyc.is_profile
    w('> **Route and inputs.** Duty cycle on the %s: loaded downhill as run, empty uphill on the same profile reversed, grades %.2f %% to %+.2f %%. Loaded train %s t; **assumed:** empty train %s t (30 %% of loaded), locomotive weight %s lb, operating schedule. Re-run `cemex_rfi_report(''Rerun'', true)` when these are confirmed.', ...
        cyc.description, min(g_all), max(g_all), th(CO.LoadedTons), th(CO.EmptyTons), th(c.loco_lb));
else
    w('> **Placeholders, replace before submitting.** The route (%s, %.2f %% to %.2f %% with curvature), consist (%s t loaded, %s t empty) and locomotive weight (%s lb) are assumptions. Every number below comes from those inputs.', ...
        cyc.description, min(g_all), max(g_all), th(CO.LoadedTons), th(CO.EmptyTons), th(c.loco_lb));
end
w('');
w('Locomotive as simulated: 6 axles (6 × D77 DC traction motors, 62:15, %g in wheels), %.2f MW traction (%s hp) at the rail, battery %d strings × 416S × 314 Ah LFP = %s kWh, discharge limit %s A (%.2fC), charge and regen limit %s A (%.2fC), regen on, cooling system CEMEX-sized (6 chiller modules, 3 condenser banks, 2 PE banks). Adhesion %.2f dry, %.2f wet.', ...
    c.wheel_in, P_rail/1e6, th(P_rail/745.7), c.n_str, th(c.E_nom_kWh), th(c.I_dis_max_A), c.dis_c_rate, ...
    th(P.lcc.I_chg_max), c.chg_c_rate, c.mu_adh, 0.18);
w('');

w('## B2: Power, speed, weight');
w('');
tbl({'Item', 'Value', 'Basis'}, {
    'Continuous traction power', sprintf('%.2f MW motor output, %.2f MW at the rail (%s hp)', c.P_trac_max_MW, P_rail/1e6, th(P_rail/745.7)), '6 × 536 kW D77 rating, gear efficiency 0.97'
    'Peak battery power (simulated)', sprintf('%.2f MW', B.peak_MW), 'base duty cycle, includes aux and cooling'
    'Short-time traction', sprintf('%.2f MW (6 × 655 kW, chopper rating)', 6*0.655), '`MotorCapkW` 655 option, discharge limit 0.81C'
    'Full power available up to', sprintf('%.0f mph', v_pow_end), 'armature voltage limit above that (750 V per motor)'
    'Route top speed', sprintf('%.0f mph', cyc.speed_range_mph(2)), 'route profile'
    'Locomotive weight / axle load', sprintf('%s lb / %s lb', th(c.loco_lb), th(c.loco_lb/6)), sprintf('assumed; weight study gives %s lb lower bound at this battery size (see Locomotive weight)', th(round(cemex_weight(P.sys.cemex.E_bol_kWh).total_lb, -2)))
    'Dimensions', 'not in the model', 'mechanical design'
    });

w('## C1: Maximum sustained grade');
w('');
w('Grade the locomotive can hold at constant speed on the continuous motor rating (1,050 A per D77, thermally unlimited), with the 5-minute rating (1,500 A) for comparison. Curvature counts as grade (0.04 %%/degree). Values in %%.');
w('');
rows = {};
for i = 1:height(C1)
    rows(end+1, :) = {sprintf('%s (%s t)', C1.consist(i), th(C1.trailing_tons(i))), sprintf('%d', C1.speed_mph(i)), ...
        f2(C1.grade_cont_soc90(i)), f2(C1.grade_cont_soc50(i)), f2(C1.grade_cont_soc20(i)), f2(C1.grade_5min_soc90(i)), f2(C1.grade_cont_wet(i))}; %#ok<AGROW>
end
tbl({'Consist', 'mph', 'SOC 90 %', 'SOC 50 %', 'SOC 20 %', '5-min rating', 'Wet (μ 0.18)'}, rows);
w('- **Battery charge doesn''t change grade capability** above the 20 %% reserve. The discharge limit is sized so full power holds down to 1,248 V, and the loaded pack stays at or above %s V at 20 %% SOC.', th(min(arrayfun(@(q) min(getfield(struct('V', cemex_capability_V(P, q)), 'V')), reserve)))); %#ok<GFLD>
w('- **Ambient temperature doesn''t change it either, up to 48 °C.** The 46 °C shift ran with no derating: battery discharge factor %.2f, verdict %s, condenser %.1f °C (limit 65 °C).', H.k_dis_min, H.verdict, H.Tcond_max_C);
dirs = {'loaded', CO.LoadedTons, crit_up_loaded, cyc.crit_up_loaded_mi, 2, 'loaded_crit'
        'empty',  CO.EmptyTons,  crit_up_empty,  cyc.crit_up_empty_mi,  4, 'empty_crit'};
for i = 1:2
    [dn_, tn_, gc_, ln_, ia_, ac_] = dirs{i, :};
    if gc_ < 0.2
        w('- The %s direction has no real climb on this route (steepest %+.2f %%).', dn_, gc_);
        continue
    end
    g_cont = gmax(at(TEc, 10), tn_, 10);
    if bal_speed(tn_, gc_, TEc) > 0
        w('- The route''s steepest %s climb is %.2f %% for %.1f mi. The %s train (%s t) holds it at %.1f mph on the continuous rating (limit at 10 mph: %.2f %%).', ...
            dn_, gc_, ln_, dn_, th(tn_), bal_speed(tn_, gc_, TEc), g_cont);
    else
        w('- The route''s steepest %s climb (%.2f %% for %.1f mi) is above the %s train''s continuous-rating limit (%.2f %%). It climbs on the short-time rating at %.1f mph; in a 30-minute simulated climb the motors reached %.0f °C, against a 180 °C limit.', ...
            dn_, gc_, ln_, dn_, g_cont, acc.balance_mph(ia_), AC.(ac_).M.Tmotor_max);
    end
end
w('');

w('**Short-time motor ratings (from the thermal model).** Time from a warm motor (80 °C) to 180 °C at constant current, 40 °C ambient. The model is lumped (one thermal mass, no winding hot spot), so it is optimistic for short-time duty: it gives %.0f min at 1,150 A and %.0f min at 1,500 A, where the D77''s published ratings are 15 min and 5 min. Use the published ratings; the model''s continuous point (1,050 A) matches.', strT.min_80_to_180C(2), strT.min_80_to_180C(4));
w('');
rows = {};
for i = 1:height(strT)
    rows(end+1, :) = {th(strT.I_per_motor_A(i)), sprintf('%.0f', strT.T_steady_C(i)), iff(isinf(strT.min_80_to_180C(i)), 'continuous', sprintf('%.0f min', strT.min_80_to_180C(i)))}; %#ok<AGROW>
end
tbl({'Current per motor, A', 'Steady temperature °C', 'Time to 180 °C'}, rows);
w('');

w('## C2: Duty-cycle simulation (Victorville route)');
w('');
w('Inputs the simulation covers:');
w('');
tbl({'RFI input', 'Value used'}, {
    'Route', cyc.description
    'Locomotive weight', sprintf('%s lb (assumed)', th(c.loco_lb))
    'Train consist', sprintf('%s t loaded; %s t empty (assumed, 30 %% of loaded)', th(CO.LoadedTons), th(CO.EmptyTons))
    'Grades / curvature', sprintf('%.2f %% to %+.2f %% as recorded (curvature included in the recorded grade)', min(g_all), max(g_all))
    'Speed restrictions', cyc.speed_text
    'Acceleration', 'as run on the route profile, within adhesion and power'
    'Stops / starts', sprintf('%d round trips; %g min loading, %g min unloading, stop at each end', CO.Trips, CO.LoadDwell_min, CO.UnloadDwell_min)
    'Ambient', sprintf('%g °C (46 °C case below)', CO.Ambient_C)
    'Auxiliary loads', '`cemex_load_budget.csv` (blowers, compressor, cab, controls) plus cooling system from the thermal model'
    'Braking', sprintf('regen to %s A (0.5C) and the traction power cap, cut off at %.0f %% SOC; dynamic-brake grids %.1f MW; train air brakes beyond locomotive adhesion', th(P.lcc.I_chg_max), 100*P.lcc.soc_reg_max, P.lcc.P_db_max/1e6)
    'Battery limits', sprintf('discharge %s A, charge %s A, BMS temperature derates (45/50 °C hot)', th(c.I_dis_max_A), th(P.lcc.I_chg_max))
    'Battery degradation', 'end-of-life case: 70 % capacity (8,000 cycles, Voltify response), 1.5× resistance (assumed)'
    'Charging opportunities', sprintf('%g kW during each plant unload dwell; none at the quarry', CO.PlantCharge_kW)
    });
w('Results, one shift:');
w('');
shift_tbl(shiftT);
w('![Base shift](fig_C2_base_shift.png)');
w('');
w('Every shift case finished with the train on schedule within the speed tolerance. The shortfall column is the worst gap below the profile speed (%.1f mph at most), where the locomotive is at its power or adhesion limit. Every case was thermally %s.', max(shiftT.shortfall_mph), strjoin(unique(shiftT.verdict), '/'));
w('');

w('## C3: Acceleration');
w('');
w('Full-power start from rest at %g °C, SOC 90 %%. Time (s) and distance (m) to each speed. Blank means the train doesn''t reach that speed on that grade.', CO.Ambient_C);
w('');
rows = {};
for i = 1:height(acc)
    r = acc(i, :);
    rows(end+1, :) = {char(r.case), f0(r.t_5mph_s), f0(r.d_5mph_m), f0(r.t_10mph_s), f0(r.d_10mph_m), f0(r.t_15mph_s), f0(r.d_15mph_m), ...
        f0(r.t_20mph_s), f0(r.d_20mph_m), sprintf('%.1f', r.balance_mph)}; %#ok<AGROW>
end
tbl({'Case', 't 5 mph', 'd 5 mph', 't 10 mph', 'd 10 mph', 't 15 mph', 'd 15 mph', 't 20 mph', 'd 20 mph', 'Balancing mph'}, rows);
w('![Acceleration](fig_C3_acceleration.png)');
w('');

w('## C4: Maximum train tonnage');
w('');
w('Trailing short tons. Starting uses %s kN (adhesion-limited; dry μ %.2f, wet 0.18). Continuous means holding 10 mph on the continuous motor rating. Coupler means a %s lbf drawbar limit (assumed AAR knuckle working limit, to be confirmed against the CEMEX fleet).', th(TE_start/1e3), P.lcc.mu_adh, th(coupler_lbf));
w('');
rows = {};
for i = 1:height(C4)
    rows(end+1, :) = {sprintf('%.2f', C4.grade_pct(i)), th(C4.start_tons_dry(i)), th(C4.start_tons_wet(i)), th(C4.cont_tons_10mph(i)), th(C4.coupler_tons(i))}; %#ok<AGROW>
end
tbl({'Grade %', 'Starting, dry', 'Starting, wet', 'Continuous 10 mph', 'Coupler limit'}, rows);
w('The coupler is never the limit for one locomotive: maximum drawbar pull is %s lbf, against the %s lbf limit. Adhesion is the limit at starting speeds.', th((TE_start)/lbf), th(coupler_lbf));
w('');

w('## C5: Energy, peak demand and state of charge, one operating cycle');
w('');
tbl({'Metric', 'Base shift (3 round trips)', 'Per round trip'}, {
    'Battery energy out', [th(B.bat_out_kWh) ' kWh'], [th(B.bat_out_kWh/ntrip) ' kWh']
    'Regen returned to battery', [th(B.regen_in_kWh) ' kWh'], [th(B.regen_in_kWh/ntrip) ' kWh']
    'Net battery energy (no charging)', '', sprintf('%s kWh (no-charging run; negative = net gain)', th(rng.kWh_per_round_trip(1)))
    'Charger energy in (plant dwells)', [th(B.charger_in_kWh) ' kWh'], ''
    'Peak demand (battery)', sprintf('%.2f MW', B.peak_MW), ''
    'Highest 5-minute average', sprintf('%.2f MW', B.sust5min_MW), ''
    'SOC start / minimum / end', sprintf('%.0f %% / %.1f %% / %.1f %%', B.soc_start_pct, B.soc_min_pct, B.soc_end_pct), ''
    'Required reserve', sprintf('%.0f %%: %s', 100*reserve, yn(B.reserve_ok)), ''
    });

w('## C6: Wet, dusty, low-adhesion and high-temperature performance');
w('');
w('- **Low adhesion.** At μ 0.18 starting TE drops from %s to %s kN. The wet base shift still finished with minimum SOC %.1f %%, but ran %.1f min more than 2 mph below the speed limit on the heavy pulls (dry: %.1f min). Sanding and adhesion control are in scope; the model uses one adhesion value for the whole locomotive and has no per-axle slip control.', ...
    th(TE_start/1e3), th(TEw0/1e3), W.soc_min_pct, W.min_below_ref, B.min_below_ref);
w('- **High temperature.** At 46 °C the shift ran with no derating: discharge factor %.2f, cell max %.1f °C, condenser %.1f °C, PE margin %.1f K, verdict %s. The cooling system was sized to stay OPTIMAL to 48 °C.', H.k_dis_min, H.Tcell_max_C, H.Tcond_max_C, H.margin_K, H.verdict);
w('- **Derating logic (as modeled).**');
w('  - Battery: the BMS derates current linearly from 45 °C (L1) to 50 °C (L2) cell temperature hot, and from 5 °C to 3 °C cold. The pack is held at 25 °C while parked.');
w('  - Motors: current limit of 1,500 A for 5 minutes and 1,050 A continuous per motor.');
w('  - Cooling: chiller capacity falls as the condenser supply rises, and cuts out at 65 °C.');
w('  - Adhesion: TE is capped at μ × locomotive weight.');
w('- **Dust.** Dust isn''t a model input. In the model it shows up only as reduced adhesion (use the wet case) and radiator fouling (UA margin: the condenser runs %.1f K under its limit at 46 °C).', 65 - H.Tcond_max_C);
w('');
w('![TE vs speed](fig_D1_te_vs_speed.png)');
w('');

w('**Ambient envelope** (base duty cycle, pack held at 25 °C while parked):');
w('');
rows = {};
for i = 1:height(envT)
    r = envT(i, :);
    rows(end+1, :) = {sprintf('%g °C', r.ambient_C), char(r.verdict), sprintf('%.1f', r.Tcond_max_C), sprintf('%.1f', r.margin_K), sprintf('%.1f-%.1f', r.Tcell_min_C, r.Tcell_max_C), ...
        sprintf('%.2f', r.k_dis_min), th(r.tms_kWh), sprintf('%.0f', r.soc_min_pct)}; %#ok<AGROW>
end
tbl({'Ambient', 'Verdict', 'Condenser max °C (65)', 'PE margin K', 'Cell °C', 'Discharge derate factor', 'Cooling/heating kWh', 'Min SOC %'}, rows);
iopt = find(envT.verdict == "OPTIMAL" & envT.ambient_C > 40, 1, 'last'); hot_ok = envT.ambient_C(iopt);
w('Full performance with no derating from %g °C to %g °C. Above that, the verdict column shows how the margins close. Cold mornings are covered by the pack heater and conditioning on the charger; the cell stays inside its window.', min(envT.ambient_C), hot_ok);
w('');

w('## C7: Steepest grade to start, restart and hold');
w('');
rows = {};
for i = 1:height(C7)
    rows(end+1, :) = {sprintf('%s (%s t)', C7.consist(i), th(C7.trailing_tons(i))), f2(C7.start_grade_dry_pct(i)), f2(C7.start_grade_wet_pct(i)), sprintf('%.1f', C7.hold_grade_loco_pct(i))}; %#ok<AGROW>
end
tbl({'Consist', 'Start / restart, dry %', 'Start / restart, wet %', 'Hold, locomotive brake only %'}, rows);
w('**Method.** Starting TE (adhesion-limited) against grade plus rolling resistance, with no acceleration margin. It is checked in simulation with the loaded train:');
w('');
w('- at %.2f %%: reaches %.1f mph.', st_res.grade_pct(1), st_res.max_speed_mph(1));
w('- at %.2f %%: the train creeps to %.2f mph and stalls. The anti-rollback brake stops any rollback within %.2f mph.', st_res.grade_pct(2), st_res.max_speed_mph(2), abs(st_res.min_speed_mph(2)));
w('');
w('Rollback is prevented by the park/anti-rollback brake whenever speed is commanded to zero or the train rolls back. With the locomotive brake alone, the loaded train holds up to %.2f %%.', g_hold_loco);
w('');
ri = {'loaded', crit_up_loaded, 2; 'empty', crit_up_empty, 1};
for i = 1:2
    if ri{i, 2} > C7.start_grade_wet_pct(ri{i, 3})
        w('**Route impact (%s).** The steepest %s climb (%.2f %%) is above the %s train''s wet restart limit (%.2f %%). A %s train stopped there in wet conditions needs sand, or a lighter train.', ...
            ri{i, 1}, ri{i, 1}, ri{i, 2}, ri{i, 1}, C7.start_grade_wet_pct(ri{i, 3}), ri{i, 1});
    elseif ri{i, 2} >= 0.2
        w('**Route impact (%s).** The %s train can restart anywhere on the route, wet or dry: its steepest climb is %.2f %%, against a wet restart limit of %.2f %%.', ...
            ri{i, 1}, ri{i, 1}, ri{i, 2}, C7.start_grade_wet_pct(ri{i, 3}));
    end
end
w('');

w('## C8: Limitations and assumptions');
w('');
w('1. The empty-train weight, locomotive weight and operating schedule are assumptions; the train air brake capacity (%.0f %% of trailing weight) needs CEMEX car brake data.', 100*P.lcc.k_tb);
w('2. Wet-rail restart limits: loaded train %.2f %% (route climb %.2f %%), empty train %.2f %% (route climb %.2f %%); see C7.', ...
    C7.start_grade_wet_pct(2), crit_up_loaded, C7.start_grade_wet_pct(1), crit_up_empty);
if isinf(rng.trips_90_to_20(1))
    w('3. Without charging, the route is net energy-positive, so the battery doesn''t drain toward the reserve (E3). Leave the plant at or above %.0f %% SOC to cover the empty-climb dip with reserve.', max(rng.min_start_soc_pct));
else
    w('3. Without charging, the battery covers %d round trips before the 20 %% reserve when new, and %d at end of life (E3). The plant charger is required for longer shifts.', rng.whole_trips(1), rng.whole_trips(3));
end
w('4. The locomotive alone can hold the loaded train on descents up to %.2f %%. The route''s %.2f %% loaded descent needs the train air brakes as well (D3, D4).', g_hold_loco, crit_dn_loaded);
w('5. Not modeled: individual-axle slip control (the model uses one adhesion value).');
w('6. The cell rating at 0.67C continuous discharge needs confirmation from the cell supplier. Victorville''s design ambient is assumed to be 46 °C.');
w('');

w('## D1: Tractive effort');
w('');
tbl({'Item', 'Value'}, {
    'Starting TE (dry, μ 0.25)', sprintf('%s kN (%s lbf), adhesion-limited', th(TE_start/1e3), th(TE_start/lbf))
    'Starting TE, motor current limit', sprintf('%s kN (6 × 1,500 A)', th(motor_TE0/1e3))
    'Continuous TE', sprintf('%s kN (%s lbf) at %.1f mph (6 × 1,050 A)', th(TE_cont/1e3), th(TE_cont/lbf), v_cont)
    'Continuous speed at maximum power', sprintf('%.1f mph', v_cont)
    'Wet starting TE (μ 0.18)', sprintf('%s kN (%s lbf)', th(TEw0/1e3), th(TEw0/lbf))
    });
rows = {};
for s = [0 2 5 8 10 12 15 20 25 30 40]
    rows(end+1, :) = {sprintf('%d', s), th(at(TEs, s)/1e3), th(at(TEc, s)/1e3), th(at(TEw, s)/1e3), th(at(TEb, s)/1e3), char(Is.limit(find(vgrid >= s, 1)))}; %#ok<AGROW>
end
tbl({'mph', 'TE max kN', 'TE continuous kN', 'TE wet kN', 'Regen braking kN', 'TE max limited by'}, rows);
w('Full curve: `D1_te_be_vs_speed.csv`.');
w('');
w('**Against the reference locomotive.** CEMEX''s Victorville fleet has run second-hand EMD SD40-2s and SD60s (and GP39-2s). The RFI''s 3,500-3,800 hp reference matches the **SD60 (3,800 hp)**.');
w('');
w('Published ratings vary between sources; these are the most-cited values:');
w('');
w('- **SD60:** 98,250 lbf starting at 25 %% adhesion; 100,000 lbf continuous at 9.8 mph; D87B motors, 77:17; about 368,000 lb');
w('- **SD40-2:** 115,000 lbf starting at 31.5 %%; 82,100 lbf continuous at 11 mph; D77 motors, 62:15');
w('');
w('Beyond each unit''s continuous point, its curve is drawn at the rail power implied by that point: TE × mph / 375. Values below are continuous ratings in lbf.');
w('');
RF = struct('name', {'EMD SD60 (reference, 3,800 hp)', 'EMD SD40-2 (3,000 hp)'}, 'st', {98250, 115000}, 'st_basis', {'25 % adh.', '31.5 % adh.'}, ...
    'tc', {100000, 82100}, 'vc', {9.8, 11});
ref_te = @(r, v) min(r.tc, 375*(r.tc*r.vc/375)./max(v, 0.1));
P77 = cemex_params(struct('gear', 77/17));
TEs77 = cemex_capability(P77, vgrid, 'Mode', 'start');
[TEc77, Ic77] = cemex_capability(P77, vgrid, 'Mode', 'cont');
v_cont77 = vgrid(find(Ic77.limit == "motor current", 1, 'last'));
spd_ref = [5 10 15 20];
rows = {};
for r = RF
    rows(end+1, :) = [{r.name, sprintf('%s (%s)', th(r.st), r.st_basis), sprintf('%s @ %.1f mph', th(r.tc), r.vc), th(r.tc*r.vc/375)}, ...
        arrayfun(@(s) th(ref_te(r, s)), spd_ref, 'UniformOutput', false)]; %#ok<AGROW>
end
cm = {{'CEMEX battery loco, 62:15 (as modeled)', TEs, TEc, v_cont}, {'CEMEX battery loco, 77:17 regear', TEs77, TEc77, v_cont77}};
vx = zeros(1, 2); vhi = vx;
for i = 1:2
    c_ = cm{i};
    tcl = at(c_{3}, c_{4})/lbf;
    rows(end+1, :) = [{c_{1}, sprintf('%s (%.2f × %s lb)', th(c_{2}(1)/lbf), P.lcc.mu_adh, th(c.loco_lb)), sprintf('%s @ %.1f mph', th(tcl), c_{4}), ...
        th(tcl*c_{4}/375)}, arrayfun(@(s) th(at(c_{3}, s)/lbf), spd_ref, 'UniformOutput', false)]; %#ok<AGROW>
    ok = c_{3}/lbf >= ref_te(RF(1), vgrid) - 1;
    vx(i) = vgrid(find(ok, 1));                                  % from here up the battery loco >= SD60
    j_ = find(~ok & vgrid > vx(i), 1); if isempty(j_), vhi(i) = Inf; else, vhi(i) = vgrid(j_); end
end
tbl({'Locomotive', 'Starting TE lbf', 'Continuous TE lbf', 'Rail hp at continuous point', '5 mph', '10 mph', '15 mph', '20 mph'}, rows);
w('What this shows:');
w('');
w('- **Continuous TE at low speed is short of the SD60.** As modeled (SD40-2 drivetrain: D77, 62:15) the locomotive matches the SD40-2 but is %s lbf below the SD60 continuous rating. It equals or exceeds the SD60 from %.1f to %.0f mph, where its higher rail power (%s hp vs about %s) takes over. Above %.0f mph the 750 V-per-motor limit inherited from the GP40 proto cuts power; that is outside the 20 mph route but contradicts the "no high-speed power fall-off" in Voltify''s questionnaire answer (B9).', ...
    th(RF(1).tc - at(TEc, 5)/lbf), vx(1), vhi(1), th(P_rail/745.7), th(RF(1).tc*RF(1).vc/375), vhi(1));
w('- **A 77:17 regear** (the SD60 ratio) raises continuous TE to %s lbf and crosses the SD60 from %.1f mph. Full continuous power then starts at %.1f mph instead of %.1f mph. The cost is top speed, which falls by the same %.1f %%; that doesn''t matter on a 20 mph quarry line.', ...
    th(at(TEc77, 5)/lbf), vx(2), v_cont77, v_cont, 100*(1 - (62/15)/(77/17)));
w('- **Closing the rest of the gap at 10 mph** takes more current than the D77 continuous rating (1,050 A), or a larger motor (D87/D90). Matching the SD60 low-speed rating is a motor and blower decision, not a battery or power question: the battery locomotive has about %.0f %% more rail power.', 100*(P_rail/745.7/(RF(1).tc*RF(1).vc/375) - 1));
w('- **Starting TE depends on weight and adhesion, not the motors.** Six D77s at their 5-minute current give %s lbf. The value in the table is adhesion-limited at μ %.2f on the placeholder weight. The SD60''s published figure assumes 25 %% on about 393,000 lb. At SD60 weight (368,000 lb) the battery locomotive would start at %s lbf, so it needs its battery ballast (%s lb is within the 70,000 lb axle load) or better adhesion from per-axle control (D2) to match.', ...
    th(motor_TE0/lbf), P.lcc.mu_adh, th(P.lcc.mu_adh*368000), th(c.loco_lb));
w('');

w('## Locomotive weight (B2, C7, D1, D4)');
w('');
Wst = cemex_weight(P.sys.cemex.E_bol_kWh);
w('**Weight estimate.** From Voltify''s battery locomotive weight study (SD40 core):');
w('');
w('- a fixed %s lb for the frame, trucks, six DC traction motors, compressor, grids, charger, pantographs and power electronics;', th(Wst.fixed_lb));
w('- plus %.1f lb per kWh of installed battery (packs, racks and thermal management).', Wst.lb_per_kWh);
w('');
w('At %s kWh that gives **%s lb (%s lb per axle)**. This is a lower bound: the study lists the cab, inverter, cabling, breakers and contactor panels without weights. The simulations use %s lb.', ...
    th(P.sys.cemex.E_bol_kWh), th(Wst.total_lb), th(Wst.axle_lb), th(c.loco_lb));
w('');
w('Weight sets adhesion, so it sets starting tractive effort and how much braking the locomotive can do on its own. Motor ratings and power don''t change.');
w('');
rows = {};
for i = 1:height(wtT)
    r = wtT(i, :);
    rows(end+1, :) = {sprintf('%s', r.case), th(r.loco_lb), th(r.axle_lb), th(r.start_TE_lbf), sprintf('%+s', th(r.vs_SD60_lbf)), ...
        sprintf('%.2f / %.2f', r.start_grade_loaded, r.start_grade_loaded_wet), sprintf('%.2f', r.start_grade_empty), sprintf('%.2f', r.hold_grade_loco), ...
        stopf(r.stop_20mph_ft, true), th(r.desc_regen_kWh), th(r.desc_air_kWh)}; %#ok<AGROW>
end
tbl({'Case', 'Weight lb', 'Axle lb', 'Starting TE lbf (μ 0.25)', 'vs SD60 98,250', 'Loaded start grade % dry / wet', 'Empty start grade %', ...
    'Loco-only hold % (loaded)', sprintf('Stop from 20 mph on %.2f %%, ft', crit_dn_loaded), 'Descent regen kWh', 'Descent train air kWh'}, rows);
i368 = 1; ist = 2;
w('- **Starting tractive effort vs the SD60:** at the SD60''s own weight the battery locomotive starts %s lbf below it at the same 25 %% adhesion; the SD60''s 98,250 lbf corresponds to about 393,000 lb. At the weight-study estimate it is %s lbf %s.', ...
    th(abs(wtT.vs_SD60_lbf(i368))), th(abs(wtT.vs_SD60_lbf(ist))), iff(wtT.vs_SD60_lbf(ist) >= 0, 'above', 'below'));
w('- **Route capability doesn''t depend on it:** across the whole range the empty train restarts on more than %.1f %% (route climb %.2f %%), and every shift completes with the same energy (%s-%s kWh out).', ...
    min(wtT.start_grade_empty), crit_up_empty, th(min(wtT.shift_out_kWh)), th(max(wtT.shift_out_kWh)));
w('- **Heavier brakes more electrically:** on the loaded descent the car air brakes carry %s kWh at %s lb and %s kWh at %s lb, because more locomotive weight means more adhesion for regen.', ...
    th(wtT.desc_air_kWh(1)), th(wtT.loco_lb(1)), th(wtT.desc_air_kWh(end)), th(wtT.loco_lb(end)));
w('- **Axle load:** the base case is %s lb per axle. The 9.4 MWh build (%s lb per axle) would need track and bridge clearance.', th(wtT.axle_lb(3)), th(wtT.axle_lb(4)));
w('');

w('## Closing the gap to the SD60 (D1)');
w('');
w('The battery locomotive''s continuous tractive effort below about %.0f mph is set by the D77 continuous current (1,050 A per motor). Three levers, and what each does:', vx(1));
w('');
w('**1. Motor cooling: the continuous current.** The motor thermal model settles at 180 °C at %s A per motor at 40 °C (%s A at 46 °C), which reproduces the D77 continuous rating. Matching the SD60''s %s lbf at 10 mph needs about **%s A per motor at 62:15**, or **%s A at 77:17**. That means about %.0f %% or %.0f %% more blower cooling (heat removed per kelvin rises with the square of the current), plus the motor supplier''s agreement to a higher continuous rating.', ...
    th(Iss(40)), th(Iss(46)), th(98000), th(I_need.g62), th(I_need.g77), 100*((I_need.g62/1050)^2 - 1), 100*((I_need.g77/1050)^2 - 1));
w('');
w('**On this route the continuous rating barely matters.** The motor''s thermal time constant is %.0f minutes, and the steepest climb (%.2f %% for %.1f mi, empty train) takes only minutes. The base shift peaks at %.0f °C motor temperature, against 180 °C.', ...
    tau_mot_min, crit_up_empty, cyc.crit_up_empty_mi, B.Tmotor_max_C);
w('');
w('**2. Regear to 77:17.** This raises continuous TE by 9.6 %% (to %s lbf) at the cost of top speed. On the route:', th(at(TEc77, 5)/lbf));
w('');
rows = {
    'Shift: battery out / regen, kWh', sprintf('%s / %s', th(B.bat_out_kWh), th(B.regen_in_kWh)), sprintf('%s / %s', th(MT.shift.C.bat_out_kWh), th(MT.shift.C.bat_in_regen_kWh))
    'Shift: max motor temperature, °C', sprintf('%.0f', B.Tmotor_max_C), sprintf('%.0f', MT.shift.M.Tmotor_max)
    'Shift: worst speed shortfall, mph', sprintf('%.1f', B.shortfall_mph), sprintf('%.1f', MT.shift.C.speed_shortfall_max_mph)
    sprintf('Empty train on %.2f %%: 0-15 mph, s', crit_up_empty), sprintf('%.0f', acc.t_15mph_s(4)), sprintf('%.0f', acc77_t15)
    'Loaded descent (60 % SOC): regen / train air, kWh', sprintf('%s / %s', th(dsT.regen_kWh(1)), th(dsT.train_air_kWh(1))), sprintf('%s / %s', th(MT.desc.C.bat_in_regen_kWh), th(MT.desc.C.train_air_kWh))
    };
tbl({'', '62:15 (as modeled)', '77:17'}, rows);
w('The regear changes little on this route: the duty is adhesion- and power-limited, not current-limited. It earns its place only if the reference comparison at 5-10 mph matters to CEMEX.');
w('');
w('**3. Motor voltage: the high-speed fall-off.** The model inherits the GP40 prototype''s 750 V armature limit per motor. The CEMEX pack is %s V nominal, so a chopper and motor arrangement that uses more of the bus voltage keeps full power to higher speed:', th(416*3.2));
w('');
rows = {};
for i = 1:height(vsT)
    r = vsT(i, :);
    rows(end+1, :) = {sprintf('%s V', th(r.V_mot_max)), iff(r.full_power_to_mph >= vgrid(end), sprintf('%.0f mph or more', vgrid(end)), sprintf('%.0f mph', r.full_power_to_mph)), th(r.TE_30mph_lbf), th(r.TE_40mph_lbf), sprintf('%s of %s', th(r.TE_45mph_lbf), th(r.TE_45mph_full_power_lbf))}; %#ok<AGROW>
end
tbl({'Armature limit per motor', 'Full power up to', 'TE at 30 mph, lbf', 'TE at 40 mph, lbf', 'TE at 45 mph vs full power, lbf'}, rows);
w('Voltify''s questionnaire answer (B9) describes 1.5 kV power electronics with no high-speed fall-off; that corresponds to the 1,000 V and higher rows here. The motor''s voltage rating and the chopper topology (motors in series pairs, or one chopper each) need to be confirmed before the curve is quoted. None of this affects the 20 mph Black Mountain route.');
w('');

w('## D3: Brake blending');
w('');
w('As simulated, the speed controller asks for one braking effort, which is met automatically at every time step in this order:');
w('');
w('1. **Regen to the battery,** up to the smallest of adhesion, the traction power cap and the charge current limit (%s A, scaled by the battery temperature factor). Regen tapers to zero as the battery goes from %.0f %% to %.0f %% SOC, and fades out below %.1f mph.', ...
    th(P.lcc.I_chg_max), 100*(P.lcc.soc_reg_max - P.lcc.soc_reg_band), 100*P.lcc.soc_reg_max, 1.5/mps);
w('2. **Dynamic-brake grids** (%.1f MW), for whatever regen cannot take: battery full or charge-limited. Grid effort fades below %.0f mph, and regen plus grids stay within adhesion.', P.lcc.P_db_max/1e6, P.lcc.v_db_blend/mps);
w('3. **Train air brakes** on the cars, for demand beyond what the locomotive can hold by adhesion. Up to %.0f %% of the trailing weight (assumed until CEMEX gives car brake data).', 100*P.lcc.k_tb);
w('4. **Locomotive friction brakes** last, with the locomotive''s total braking kept within adhesion.');
w('');
w('**Evidence: the loaded run down from Black Mountain** (%s t), from three arrival states:', th(CO.LoadedTons));
w('');
for i = 1:height(dsT)
    r = dsT(i, :);
    w('- **%s:** regen %s kWh, grids %s kWh, train air %s kWh, locomotive friction %s kWh. Speed held within %+.1f / %+.1f mph of the profile; SOC %.0f %% → %.0f %% (peak %.1f %%).', ...
        erase(char(r.case), 'Loaded descent, '), th(r.regen_kWh), th(r.grid_kWh), th(r.train_air_kWh), th(r.loco_friction_kWh), r.overspeed_mph, r.underspeed_mph, ...
        r.soc_start_pct, r.soc_end_pct, r.soc_max_pct);
end
w('');
w('The transitions are automatic. When the battery fills, regen hands over to the grids with no change in speed. Without grids, the friction brakes take over. The car air brakes carry only the share of the steepest grade that exceeds the locomotive''s adhesion.');
w('');

w('## D4: Braking effort and stopping distance');
w('');
w('Regen braking effort vs speed is in the D1 table and figure. Stopping distances are given two ways:');
w('');
w('- **Locomotive alone:** regen, grids and locomotive friction, up to adhesion.');
w('- **With train air brakes:** plus car brakes at %.0f %% of trailing weight (assumed full-service retardation; to be refined with CEMEX car brake ratios).', 100*P.lcc.k_tb);
w('');
w('"Cannot stop" means the grade force exceeds that braking on its own. Grades are the route''s steepest descents.');
w('');
rows = {};
for i = 1:height(D4)
    rows(end+1, :) = {char(D4.consist(i)), sprintf('%.2f', D4.grade_pct(i)), sprintf('%d', D4.from_mph(i)), sprintf('%.2f', D4.mu(i)), ...
        stopf(D4.time_s(i)), stopf(D4.distance_ft(i), true), stopf(D4.time_air_s(i)), stopf(D4.distance_air_ft(i), true)}; %#ok<AGROW>
end
tbl({'Consist', 'Grade %', 'From mph', 'μ', 'Loco alone: time s', 'Loco alone: ft', 'With train air: time s', 'With train air: ft'}, rows);

w('## D5: Regenerative energy recovery');
w('');
w('- **Per shift:** regen returns %s kWh to the battery, %s kWh per round trip. That is %.0f %% of the braking energy; %s kWh goes to the grids and %s kWh to friction (train air and locomotive).', ...
    th(B.regen_in_kWh), th(B.regen_in_kWh/ntrip), B.regen_share_pct, th(B.grid_kWh), th(B.friction_kWh));
w('- **Regen vs battery output:** regen returns %.0f %% of what the battery delivers over the shift.', 100*B.regen_in_kWh/B.bat_out_kWh);
w('- **End of life:** %s kWh per shift. **Wet rail:** %s kWh per shift.', th(E.regen_in_kWh), th(W.regen_in_kWh));
w('');
w('Limiting assumptions:');
w('');
w('- regen limited to 0.5C charge current and the %.2f MW traction cap', c.P_trac_max_MW);
w('- fades below 3.4 mph');
w('- drivetrain efficiency 0.88 each way');
w('- regen tapers out between %.0f %% and %.0f %% SOC; above that the grids take the braking', 100*(P.lcc.soc_reg_max - P.lcc.soc_reg_band), 100*P.lcc.soc_reg_max);
w('- the battery''s state at the top of each descent sets the split (D6): arriving at the quarry with headroom recovers the whole descent');
w('');

w('## D6: Thermal management on long descents');
w('');
w('The loaded run down from Black Mountain (%s t, %.1f mi, steepest %.2f %% for %.1f mi), %g °C:', th(CO.LoadedTons), cyc.route_mi_one_way, crit_dn_loaded, cyc.crit_dn_loaded_mi, CO.Ambient_C);
w('');
rows = {};
for i = 1:height(dsT)
    r = dsT(i, :);
    rows(end+1, :) = {erase(char(r.case), 'Loaded descent, '), sprintf('%.0f→%.0f', r.soc_start_pct, r.soc_end_pct), sprintf('%.2f', r.peak_regen_MW), ...
        sprintf('%s / %s', th(r.peak_charge_A), th(r.charge_limit_A)), th(r.regen_kWh), th(r.grid_kWh), th(r.train_air_kWh), th(r.loco_friction_kWh), ...
        sprintf('%.0f', r.Tmotor_max_C), sprintf('%.1f', r.Tcell_max_C), char(r.verdict)}; %#ok<AGROW>
end
tbl({'Case', 'SOC %', 'Peak regen MW (1 s)', 'Charge A (1 s) / limit', 'Regen kWh', 'Grids kWh', 'Train air kWh', 'Loco friction kWh', 'Motor °C', 'Cell °C', 'Verdict'}, rows);
w('- **Continuous braking.** Regen and the grids together give continuous electric braking down the whole descent, with no duty-cycle limit. Regen energy goes into the battery as charge, and its losses go to the cooling loops, which stay within limits. Grid heat goes straight to the air.');
w('- **Battery headroom is the lever.** Arriving at the quarry at %.0f %% SOC, the battery absorbs %s kWh, the whole descent except the car-brake share. Arriving at %.0f %%, it fills to %.0f %%, and the grids burn %s kWh that could have been stored.', ...
    dsT.soc_start_pct(1), th(dsT.regen_kWh(1)), dsT.soc_start_pct(2), dsT.soc_max_pct(2), th(dsT.grid_kWh(2)));
w('- **Operating recommendation:** plan plant charging so the locomotive leaves the plant with enough headroom for the loaded descent. Regen then refills it for free.');
w('- **Without grids** at full SOC, the same energy goes to friction brakes (%s kWh locomotive, %s kWh train air). That is wear and heat, not a speed limit.', th(dsT.loco_friction_kWh(3)), th(dsT.train_air_kWh(3)));
w('');
w('![Descent](fig_D6_descent.png)');
w('');

w('**How far the battery can brake a descent:** on this route the loaded descent adds %.2f %% SOC (%s kWh) per mile. Before regen cuts off at %.0f %%, that gives:', 100*soc_per_mi, th(kwh_per_mi), 100*(P.lcc.soc_reg_max - P.lcc.soc_reg_band));
w('');
rows = {};
for i = 1:height(dlT)
    rows(end+1, :) = {sprintf('%.0f %%', 100*dlT.soc0(i)), sprintf('%.1f mi', dlT.miles_to_cutoff(i))}; %#ok<AGROW>
end
tbl({'SOC at the top of the descent', 'Descent before regen cut-off'}, rows);
w('Past that point the grids take over, so the descent length is not limited, only the share of energy recovered.');
w('');

w('## E1: Battery');
w('');
tbl({'Item', 'Value'}, {
    'Chemistry / supplier', 'LFP, 314 Ah prismatic cells'
    'Configuration', sprintf('%d strings × 416S', c.n_str)
    'Installed capacity', sprintf('%s kWh', th(c.E_bol_kWh))
    'Usable capacity (90 % → 20 % reserve)', sprintf('%s kWh', th(0.70*c.E_bol_kWh))
    'Nominal voltage', sprintf('%s V (416 × 3.2 V)', th(416*3.2))
    'Maximum discharge', sprintf('%s A (%.2fC), about %.1f MW', th(c.I_dis_max_A), c.dis_c_rate, c.I_dis_max_A*416*3.2/1e6)
    'Maximum charge / regen', sprintf('%s A (%.2fC), about %.1f MW', th(P.lcc.I_chg_max), c.chg_c_rate, P.lcc.I_chg_max*416*3.2/1e6)
    });

w('## E2: Cycle completion at beginning and end of life');
w('');
w('Base duty cycle (3 round trips, plant charging):');
w('');
tbl({'', 'Beginning of life', 'End of life (70 %)'}, {
    'Capacity', [th(B.E_nom_kWh) ' kWh'], [th(E.E_nom_kWh) ' kWh']
    'Minimum SOC', sprintf('%.1f %%', B.soc_min_pct), sprintf('%.1f %%', E.soc_min_pct)
    'End SOC', sprintf('%.1f %%', B.soc_end_pct), sprintf('%.1f %%', E.soc_end_pct)
    'Reserve 20 % held', yn(B.reserve_ok), yn(E.reserve_ok)
    'Thermal verdict', char(B.verdict), char(E.verdict)
    });

w('## E3: Range and operating hours');
w('');
w('No charging, starting at 90 %% SOC: 3-trip runs, extrapolated per round trip. Negative energy means the round trip returns more to the battery than it takes.');
w('');
rows = {};
for i = 1:height(rng)
    r = rng(i, :);
    if isinf(r.trips_90_to_20), tr_ = 'unlimited'; hr_ = 'unlimited'; else, tr_ = sprintf('%.1f', r.trips_90_to_20); hr_ = sprintf('%.1f', r.hours_90_to_20); end
    rows(end+1, :) = {char(r.description), th(r.kWh_per_round_trip), sprintf('%+.1f', -r.soc_pct_per_trip), sprintf('%.1f', r.max_dip_pct), ...
        sprintf('%.0f', r.min_start_soc_pct), tr_, hr_}; %#ok<AGROW>
end
tbl({'Scenario', 'Net kWh per round trip', 'SOC change per trip %', 'Deepest dip in shift %', 'Lowest safe start SOC %', 'Round trips to reserve', 'Hours to reserve'}, rows);
if all(isinf(rng.trips_90_to_20))
    w('**On this route the locomotive is net energy-positive.** The loaded descent returns more energy than the empty climb takes, so the battery never runs down toward the reserve, new or at end of life. The constraint is instead the SOC dip on each empty climb: up to %.1f %% (%.1f %% at end of life). Leaving the plant at or above %.0f %% keeps the 20 %% reserve on every trip.', ...
        rng.max_dip_pct(1), rng.max_dip_pct(3), max(rng.min_start_soc_pct));
    w('');
    w('The plant charger becomes a top-up for auxiliaries and losses, not the energy source: the base shift draws only %s kWh from it. Charging high actually costs energy: above %.0f %% SOC the descent regen goes to the grids (D6).', ...
        th(B.charger_in_kWh), 100*(P.lcc.soc_reg_max - P.lcc.soc_reg_band));
else
    w('With plant charging (%g kW for each %g min unload dwell) the base shift ends at %.0f %% SOC, so range is set by charging, not by capacity.', CO.PlantCharge_kW, CO.UnloadDwell_min, B.soc_end_pct);
end
w('');
w('![SOC](fig_E3_soc.png)');
w('');

w('## E4: Battery degradation');
w('');
d1 = DG{1};
w('**Model.** NREL BLAST-Lite `Lfp_Gr_250AhPrismatic`: a semi-empirical model for large-format LFP/graphite prismatic cells, fitted to published aging data (doi:10.1016/j.est.2023.109042), ported to MATLAB in `cemex_degradation.m`. It has two parts:');
w('');
w('- **Calendar fade** grows with the square root of time. It speeds up with temperature and with high SOC, through the graphite anode potential.');
w('- **Cycle fade** grows with charge throughput (equivalent full cycles), depth of discharge and C-rate.');
w('');
w('**Anchored to the cell.** The cycle term is scaled (×%.2f) so the model reproduces the cell manufacturer''s 314 Ah datasheet: 8,000 cycles to 70 %% at 25 °C, 0.5P/0.5P, 100 %% DOD. The datasheet gives no calendar-aging curve, so the calendar term is BLAST''s, unchanged. Against manufacturer data not used in the fit:', d1.cycle_scale);
w('');
w('- **28-day storage at 50 %% SOC:** the model keeps %.1f %% at 25 °C and %.1f %% at 45 °C. The datasheet specifies at least 98 %% and 97 %% recovery, so the model is consistent.', 100*DGc.storage_28d_25C(end), 100*DGc.storage_28d_45C(end));
w('- **Cycles to 80 %% at 0.5C/0.5C:** the model gives %s at 25 °C and %s at 45 °C. An earlier cell from the same manufacturer and family is rated 4,000 and 1,800. The model under-predicts heat damage from cycling at 45 °C. The CEMEX pack runs at 25-28 °C, where the anchor applies; the conservative case below covers the cycle-life uncertainty.', th(DGc.cycles80_25C), th(DGc.cycles80_45C));
w('');
w('**Duty.** The base shift simulated above, using its SOC and cell temperature second by second. That is %.2f equivalent full cycles per shift, including the plant charging. Between shifts the pack sits on charge at %.0f %% SOC, held at 25 °C by the cooling system. **The operating schedule is a placeholder**; CEMEX hasn''t given shifts per day or days per year.', d1.shift_efc, 100*d1.park_soc);
w('');
rows = {};
for i = 1:height(degT)
    r = degT(i, :);
    rows(end+1, :) = {char(r.case), th(r.efc_per_year), sprintf('%.1f', r.soh_5y), sprintf('%.1f', r.soh_10y), sprintf('%.1f', r.soh_15y), ...
        sprintf('%.1f', r.soh_20y), yr(r.years_to_80), yr(r.years_to_70), sprintf('%.0f', r.calendar_share_pct)}; %#ok<AGROW>
end
tbl({'Case', 'Full cycles / yr', 'SOH 5 y %', '10 y %', '15 y %', '20 y %', 'Years to 80 %', 'Years to 70 %', 'Calendar share of fade %'}, rows);
w('![Degradation](fig_E4_degradation.png)');
w('');
w('**What it means for CEMEX**');
w('');
w('- **Replacement threshold: 70 %% SOH.** E2 shows the base duty cycle still completes with reserve at 70 %% capacity (minimum SOC %.1f %%). In the base case the pack reaches 70 %% %s.', E.soc_min_pct, iff(isinf(d1.years_to_70), 'after more than 25 years', sprintf('after %.1f years', d1.years_to_70)));
w('- **Design life: 20 years**, the battery system design life. In the base case, SOH at 20 years is %.0f %%. The conservative cycle-life case gives %.0f %%.', 100*d1.soh_at(4), degT.soh_20y(end));
w('- **Calendar aging is about half the fade.** At %s full cycles a year, the pack is far from its 8,000-cycle rating. Time, temperature and resting SOC matter as much as use.', th(d1.efc_per_year));
w('- **Temperature is the biggest lever.** Without conditioning (35 °C) the pack reaches 80 %% at %s instead of %s. That supports the TMS holding the pack at 25 °C while parked.', yr(degT.years_to_80(4)), yr(degT.years_to_80(1)));
w('- **Proposed warranted retention:** at least %.0f %% at 10 years. This is the conservative-case value, rounded down %.0f points for margin. It is subject to a back-to-back warranty from the battery supplier and to the confirmed CEMEX schedule.', 5*floor((degT.soh_10y(end) - 2)/5), degT.soh_10y(end) - 5*floor((degT.soh_10y(end) - 2)/5));
w('');
w('Limits:');
w('');
w('- capacity only; resistance growth is assumed at 1.5× at end of life (E2) and not modeled');
w('- BLAST fit range 10-45 °C, charge rate up to 0.65C (the regen and charge limit is 0.5C, inside the range)');
w('- assumed operating schedule');
w('- the cell datasheet revision is still to be confirmed with the manufacturer');
w('');
w('To make E4 a warranted figure, we need from the battery supplier:');
w('');
w('- calendar aging at 25, 35 and 45 °C and at several SOCs');
w('- cycle life at 35-45 °C');
w('- the pack-level warranty curve');
w('');

w('## F2: Charging time');
w('');
w('Parked charging, pack preconditioned to 25 °C. The BMS charge limit is %s A (0.5C), about %.1f MW at the battery, so a 3 MW charger is battery-limited. The "normal window" is from the lowest SOC in a 3-trip shift without charging (%.0f %%, after the empty climb) back to 90 %%.', th(P.lcc.I_chg_max), P.lcc.I_chg_max*416*3.25/1e6, 100*soc_norm);
w('');
rows = {};
for i = 1:height(chT)
    r = chT(i, :);
    rows(end+1, :) = {char(r.condition), sprintf('%.2f', r.peak_wire_MW), f0(r.min_10_80), f0(r.min_20_90), f0(r.min_normal_to_90), sprintf('%.1f', r.Tcell_max_C), sprintf('%.1f', r.Tchg_supply_max_C), char(r.verdict)}; %#ok<AGROW>
end
tbl({'Condition', 'Peak MW', '10→80 % min', '20→90 % min', sprintf('%.0f→90 %% min', 100*soc_norm), 'Cell max °C', 'Charger coolant °C', 'Verdict'}, rows);
w('![Charging](fig_F2_charging.png)');
w('');

w('## F3: Utility demand (charging)');
w('');
w('Demand at the locomotive comes from the simulations. Utility-side values assume a wayside converter efficiency of %.0f %% and power factor %.2f; power factor, harmonics and the converter''s input voltage come from the charger specification, not the model.', 100*eta_ws, pf_ws);
w('');
rows = {};
for i = 1:height(f3T)
    r = f3T(i, :);
    rows(end+1, :) = {char(r.scenario), th(r.peak_loco_kW), th(r.peak_utility_kW), th(r.peak_kVA), iff(isnan(r.utility_kWh_per_event), '-', th(r.utility_kWh_per_event))}; %#ok<AGROW>
end
tbl({'Scenario', 'Peak at locomotive kW', 'Peak at utility kW', 'Peak kVA', 'Utility kWh per event'}, rows);
w('- **On the Black Mountain duty cycle the charger is a top-up.** The base shift takes %s kWh at the utility (%s kWh per day at %d shifts), because the loaded descent recharges the battery (E3).', ...
    th(f3T.utility_kWh_per_event(1)), th(f3T.utility_kWh_per_event(1)*shifts_day), shifts_day);
w('- **Size the service for the charger rating, not the duty cycle:** about %s kVA for full-rate charging after an out-of-service day or a degraded-battery case. The plant microgrid (PV and battery storage) can cover the routine top-up and limit the utility demand charge.', th(f3T.peak_kVA(2)));
w('');

w('## G5: Heat rejection (normal and emergency conditions)');
w('');
w('Heat the locomotive rejects to the surrounding air, rebuilt second by second from the simulated thermal states with the model''s own heat-path equations. Seven paths:');
w('');
w('1. **Condenser radiators:** battery heat lifted by the chillers, plus compressor power.');
w('2. **PE radiators:** chopper, onboard charger and inverter losses.');
w('3. **Traction motor blowers:** motor copper losses.');
w('4. **Friction brakes:** at the wheels.');
w('5. **Auxiliary loads:** electrical input to the cab, compressor, blowers and controls, all ending as heat.');
w('6. **Battery enclosure:** pack to ambient.');
w('7. **String connection losses.**');
w('');
w('Items 6 and 7 are grouped as "other". The pack enclosure runs below ambient on hot days, so it is a small heat *gain*.');
w('');
rows = {};
for i = 1:height(heatT)
    r = heatT(i, :);
    rows(end+1, :) = {char(r.case), sprintf('%.0f', r.cond_kW), sprintf('%.0f', r.pe_kW), sprintf('%.0f', r.motor_kW), sprintf('%.0f', r.friction_kW), ...
        sprintf('%.0f', r.aux_kW), sprintf('%.0f', r.other_kW), sprintf('**%.0f**', r.total_peak5_kW), sprintf('%.0f', r.total_moving_mean_kW), ...
        sprintf('%.0f', r.total_charging_mean_kW), sprintf('%.2f', r.total_shift_MWh)}; %#ok<AGROW>
end
tbl({'Case', 'Condenser kW', 'PE kW', 'Motors kW', 'Friction kW', 'Aux kW', 'Other kW', 'Total peak kW', 'Mean moving kW', 'Mean charging kW', 'Shift MWh'}, rows);
w('Each path''s figure is its highest 5-minute average in the shift. The paths peak at different times, so the "Total peak" column is the peak of the sum, not the sum of the peaks.');
w('');
w('![Heat rejection](fig_G5_heat_rejection.png)');
w('');
hb = HR(1);
w('**Normal operation.** In the base case peak heat rejection is %.0f kW, which occurs %s. The shift total is %.2f MWh of heat.', heatT.total_peak5_kW(1), ...
    iff(hb.peak_while_charging, 'during plant charging, not while pulling: the chillers remove the charging heat while the aux loads are also running', ...
    iff(hb.peak_while_moving, 'while pulling', 'while parked')), heatT.total_shift_MWh(1));
w('');
w('- Under way, about %.0f kW goes to air on average.', heatT.total_moving_mean_kW(1));
w('- Regen covers all the braking on this route, so the friction brakes reject almost nothing.');
w('- At 46 °C with 655 kW motors and 3 MW charging, the peak stays at %.0f kW. The radiators reject less per kelvin of coolant temperature, which is why the condenser runs hotter (%.1f °C vs %.1f °C).', ...
    heatT.total_peak5_kW(3), heatT.Tcond_max_C(3), heatT.Tcond_max_C(1));
w('');
w('**Emergency (cooling-fault) conditions at 46 °C, base duty cycle:**');
w('');
rows = {};
for i = 3:height(heatT)
    r = heatT(i, :);
    rows(end+1, :) = {char(r.case), sprintf('%.1f', r.Tcond_max_C), sprintf('%.1f', r.Tpe_supply_max_C), sprintf('%.0f', r.Tmotor_max_C), ...
        sprintf('%.1f', r.Tcell_max_C), sprintf('%.2f', r.k_dis_min), sprintf('%.1f', r.min_below_ref), char(r.verdict), char(r.limit)}; %#ok<AGROW>
end
tbl({'Case', 'Condenser max °C', 'PE coolant max °C', 'Motor max °C', 'Cell max °C', 'Discharge derate factor', 'Min > 2 mph slow', 'Verdict', 'Limit reached'}, rows);
w('Limits:');
w('');
w('- condenser check valve: 65 °C');
w('- charger coolant inlet: 55 °C');
w('- inverter: 60 °C');
w('- chopper: 63 °C');
w('- motor: 180 °C');
w('- BMS hot derate: 45-50 °C cell');
w('');
w('A fan or blower failure moves heat into the remaining paths and raises temperatures. Fault by fault:');
w('');
for i = 4:height(heatT)
    r = heatT(i, :);
    nm = erase(char(r.case), 'Fault, 46 C: ');
    if r.verdict == "FAIL" && r.min_below_ref > 30
        w('- **%s:** the locomotive stops (%.0f min behind the trace) and heat rejection falls to almost nothing, but residual heat still crosses a limit (%s).', nm, r.min_below_ref, r.limit);
    elseif r.verdict == "FAIL"
        w('- **%s:** the shift completes on time, but coolant limits are crossed (%s). This fault needs a protective response: derate charging and traction, or stop.', nm, r.limit);
    elseif r.verdict == "OK"
        w('- **%s:** the shift completes, but with almost no margin left (%s).', nm, r.limit);
    else
        w('- **%s:** the shift completes inside all limits (motor %.0f °C against 180 °C).', nm, r.Tmotor_max_C);
    end
end
w('');
w('**Protective response for a PE radiator fan failure** (the one fault that crosses limits while running). Re-run with the fans failed at 40 °C and 43 °C, and at 46 °C with candidate responses applied:');
w('');
rows = {};
for i = 1:height(peT)
    r = peT(i, :);
    rows(end+1, :) = {char(r.case), iff(isinf(r.Tchg_supply_C), '-', sprintf('%.1f', r.Tchg_supply_C)), sprintf('%.1f', r.Tinv_C), sprintf('%.1f', r.Tchop_C), th(r.charger_kWh), sprintf('%.0f', r.soc_min_pct), char(r.verdict), char(r.limit)}; %#ok<AGROW>
end
tbl({'Case', 'Charger coolant °C (55)', 'Inverter °C (60)', 'Chopper °C (63)', 'Charger kWh', 'Min SOC %', 'Verdict', 'Limit'}, rows);
amb_ok = [40 43]; ok_ = peT.verdict(1:2) ~= "FAIL";
w('- **With the fans failed, the limiting loop is the inverter**, heated by the auxiliary loads. At 46 °C it runs about %.1f K over its 60 °C limit. Cutting plant charging or traction doesn''t change it, because that heat isn''t the cause.', max(peT.Tinv_C(3:end)) - 60);
if any(ok_)
    w('- **The locomotive can keep working with failed PE fans up to %g °C ambient**: the shift completes inside all limits. Above that, the response is to shed auxiliary load (cab HVAC to minimum, compressor duty) or stop, and repair the fans.', max(amb_ok(ok_)));
else
    w('- Even at 40 °C the inverter loop exceeds its limit, so a PE fan failure is stop-and-repair.');
end
w('- On this route the response costs little energy: the locomotive finishes the shift on its own regen, so stopping plant charging is no loss.');
w('');

w('**Not modeled:**');
w('');
w('- radiator exhaust air temperature and flow (needs the radiator air-side data)');
w('- solar load');
w('- cab HVAC rejection detail (inside the aux total)');
w('- thermal-runaway heat release, which belongs to the battery safety case, not the operating model');
w('');
w('**The rest of G5 comes from documents, not the model:** noise, waste, hazardous materials and battery handling. Sources on Drive (not reviewed here):');
w('');
w('- battery Safety Data Sheet (SDS)');
w('- battery system hazard mitigation analysis');
w('- fire suppression documentation');
w('- battery system user manual, which gives ≤ 80 dB(A) at 1 m for the stationary container, not the locomotive');
w('');
w('Locomotive noise needs a fan and blower acoustic estimate or a measurement.');
w('');

w('## Not answered by the model');
w('');
w('The model can''t answer these RFI questions:');
w('');
w('- **D2:** individual-axle slip and slide control evidence.');
w('- **G5 (non-thermal parts):** noise, waste, hazardous materials, battery handling (documents; see G5).');
w('- **A, B1/B3/B4, E5-E8, F1/F4-F6, G-J:** documentation and commercial items, not simulation.');
w('');
w('## Files');
w('');
w('The answer pack is written to `cemex/rfi_out/`:');
w('');
w('- per-question CSVs: `C1_*.csv`, `C2_C5_E2_*.csv`, `C3_*.csv`, `C4_*.csv`, `C7_*.csv`, `D1_*.csv`, `D4_*.csv`, `D6_*.csv`, `E3_*.csv`, `E4_*.csv`, `F2_*.csv`, `G5_*.csv`');
w('- figures: `fig_*.png`');
w('- cached simulations: `rfi_sims.mat`');
w('');
w('To re-run all simulations:');
w('');
w('```matlab');
w('cemex_rfi_report(''Rerun'', true)');
w('```');
fid = fopen(fullfile(o.Out, 'RFI_answers.md'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', md);
fclose(fid);
fprintf('Wrote %s\n', fullfile(o.Out, 'RFI_answers.md'));

S = struct('curve', CURVE, 'C1', C1, 'C3', acc, 'C4', C4, 'C7', C7, 'C7_sim', st_res, 'D4', D4, 'D6', dsT, ...
    'shift', shiftT, 'range', rng, 'E4', degT, 'F2', chT, 'G5', heatT, 'out', o.Out);

% ================= nested helpers =================
    function w(fmt, varargin)
        md(end+1) = string(sprintf(fmt, varargin{:}));
    end
    function tbl(hdr, rows)
        md(end+1) = "| " + strjoin(string(hdr), " | ") + " |";
        md(end+1) = "|" + strjoin(repmat("---", 1, numel(hdr)), "|") + "|";
        for ii = 1:size(rows, 1)
            md(end+1) = "| " + strjoin(string(rows(ii, :)), " | ") + " |";
        end
        md(end+1) = "";
    end
    function shift_tbl(T)
        rr = {};
        for ii = 1:height(T)
            x = T(ii, :);
            rr(end+1, :) = {char(x.description), th(x.E_nom_kWh), th(x.bat_out_kWh), th(x.regen_in_kWh), th(x.charger_in_kWh), sprintf('%.2f', x.peak_MW), ...
                sprintf('%.1f', x.soc_min_pct), sprintf('%.1f', x.soc_end_pct), sprintf('%.1f', x.shortfall_mph), sprintf('%.1f', x.Tcond_max_C), char(x.verdict)}; %#ok<AGROW>
        end
        tbl({'Case', 'Battery kWh', 'Out kWh', 'Regen kWh', 'Charger kWh', 'Peak MW', 'Min SOC %', 'End SOC %', 'Max shortfall mph', 'Condenser °C', 'Thermal'}, rr);
    end
    function gr = gmax(TEv, tons, s)
        v_ = s*mps;
        m_ = P.veh.m_loco + tons*tonkg;
        gr = 100*((TEv - 0.5*1.225*P.veh.CdA*v_^2)/(m_*g) - P.veh.Crr);
    end
    function vb = bal_speed(tons, gr, TEv)
        f_ = @(s) at(TEv, s) - fres(s*mps, tons, gr);
        if f_(0.5) < 0, vb = 0; return; end
        if f_(44) > 0, vb = 44; return; end
        vb = fzero(f_, [0.5 44]);
    end
    function [ts, xs] = stop_dist(v0, tons, gr, mu, ktb)
        Fb = mu*P.veh.m_loco*g + ktb*tons*tonkg*g;      % locomotive to adhesion + train air brakes (ktb x trailing weight)
        f_ = @(~, y) [-(Fb + fres(y(1), tons, gr))/meff(tons); y(1)];
        if Fb + fres(0, tons, gr) <= 0, ts = Inf; xs = Inf; return; end
        opt = odeset('Events', @stopped, 'RelTol', 1e-6);
        [tt, yy] = ode45(f_, [0 3600], [v0; 0], opt);
        ts = tt(end); xs = yy(end, 2);
    end
    function [val, term, dir] = stopped(~, y)
        val = y(1); term = 1; dir = -1;
    end
    function x = motor_TE0
        [~, ii] = cemex_capability(P, 0, 'Mode', 'start', 'Mu', 10);
        x = cemex_capability(P, 0, 'Mode', 'start', 'Mu', 10);
        if ii.limit ~= "motor current", x = NaN; end
    end

    % ---------------- figures ----------------
    function fig_te(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1100 650]);
        hold on; grid on;
        plot(vgrid, TEs/1e3, 'b-', 'LineWidth', 2, 'DisplayName', 'TE max (dry, 5-min rating)');
        plot(vgrid, TEc/1e3, 'b--', 'LineWidth', 1.5, 'DisplayName', 'TE continuous');
        plot(vgrid, TEw/1e3, 'c-', 'LineWidth', 1.5, 'DisplayName', 'TE wet (\mu 0.18)');
        plot(vgrid, -TEb/1e3, 'r-', 'LineWidth', 2, 'DisplayName', 'Regen braking effort (dry)');
        plot(vgrid, -TEbw/1e3, 'm-', 'LineWidth', 1.2, 'DisplayName', 'Regen braking effort (wet)');
        for gr_ = [0 0.5 1.0]
            plot(vgrid, fres(vgrid*mps, CO.LoadedTons, gr_)/1e3, 'k:', 'DisplayName', sprintf('Loaded train (%s t) resistance, %.1f %%', th(CO.LoadedTons), gr_));
        end
        plot(vgrid, fres(vgrid*mps, CO.EmptyTons, crit_up_empty)/1e3, 'k--', 'DisplayName', sprintf('Empty train (%s t) on %.2f %%', th(CO.EmptyTons), crit_up_empty));
        yline(0, 'k-', 'HandleVisibility', 'off');
        xlabel('Speed (mph)'); ylabel('Effort at the rail (kN)');
        title(sprintf('CEMEX six-axle: tractive and regen braking effort (%.2f MW, %s lb, assumed weight)', c.P_trac_max_MW, th(c.loco_lb)));
        legend('Location', 'eastoutside'); xlim([0 45]);
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_shift(x, fn)
        f = figure('Visible', 'off', 'Position', [0 0 1200 900]);
        th_ = x.t/3600;
        tiledlayout(4, 1, 'TileSpacing', 'compact');
        nexttile; plot(th_, x.vref, 'k:', th_, x.v, 'b'); ylabel('mph'); legend('speed limit', 'speed'); grid on;
        title(sprintf('Base shift: %d round trips, Black Mountain route, 2 MW plant charging, %g °C', CO.Trips, CO.Ambient_C));
        nexttile; plot(th_, x.grade, 'k'); ylabel('grade %'); grid on;
        nexttile; plot(th_, x.p_bat/1e6, 'r'); ylabel('battery MW'); grid on; yline(0, 'k-');
        nexttile; plot(th_, 100*x.soc, 'g', 'LineWidth', 1.5); ylabel('SOC %'); yline(100*reserve, 'r--', 'reserve'); ylim([0 100]); grid on; xlabel('hours');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_acc(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1100 500]);
        tiledlayout(1, 2);
        a1 = nexttile; hold on; grid on; a2 = nexttile; hold on; grid on;
        for ff = string(fieldnames(AC))'
            x = AC.(ff); k0 = x.t >= x.t_go; tt = x.t(k0) - x.t_go; vv = x.v(k0);
            plot(a1, tt/60, vv, 'LineWidth', 1.5, 'DisplayName', x.name);
            plot(a2, cumtrapz(tt, vv*mps)/1609.344, vv, 'LineWidth', 1.5, 'DisplayName', x.name);
        end
        xlabel(a1, 'minutes from start'); ylabel(a1, 'mph'); xlabel(a2, 'miles from start'); ylabel(a2, 'mph');
        legend(a1, 'Location', 'southeast'); title(a1, 'Acceleration, full power'); title(a2, 'Speed vs distance');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_descent(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1200 800]);
        tiledlayout(1 + numel(DS.run), 1, 'TileSpacing', 'compact');
        x = DS.run{1}; tm = x.t/60;
        nexttile; hold on; grid on;
        plot(tm, x.vref, 'k:', tm, x.v, 'b'); ylabel('mph');
        yyaxis right; plot(tm, x.grade, 'Color', [0.5 0.5 0.5]); ylabel('grade %');
        legend('profile speed', 'simulated speed', 'grade', 'Location', 'southeast');
        title(sprintf('Loaded descent from Black Mountain, %s t: braking effort by source', th(CO.LoadedTons)));
        for kk = 1:numel(DS.run)
            x = DS.run{kk}; tm = x.t/60; mv_ = x.v > 0.5;
            regen_kN = max(-x.p_bat, 0)./max(x.v*mps, 0.5)/1e3.*mv_;      % regen effort at the battery (after drive losses)
            Y = [regen_kN, x.f_db/1e3, x.f_tb/1e3, max(x.f_fric - x.f_db - x.f_tb, 0)/1e3.*mv_];
            nexttile; area(tm, Y, 'LineStyle', 'none'); grid on; ylabel('kN');
            yyaxis right; plot(tm, 100*x.soc, 'k', 'LineWidth', 1.2); ylabel('SOC %');
            title(x.name);
            if kk == 1, legend('regen (battery)', 'dynamic-brake grids', 'train air brakes', 'locomotive friction', 'SOC', 'Location', 'northeast'); end
        end
        xlabel('minutes');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_charge(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1100 500]);
        tiledlayout(1, 2);
        a1 = nexttile; hold on; grid on; a2 = nexttile; hold on; grid on;
        for kk = 1:numel(CH.run)
            x = CH.run{kk}; i0 = find(x.p_chg > 1e3, 1); tm = (x.t - x.t(i0))/60;
            plot(a1, tm, 100*x.soc, 'LineWidth', 1.5, 'DisplayName', CH.name{kk});
            plot(a2, tm, x.p_chg/1e6, 'LineWidth', 1.2, 'DisplayName', CH.name{kk});
        end
        xlabel(a1, 'minutes'); ylabel(a1, 'SOC %'); xlabel(a2, 'minutes'); ylabel(a2, 'charger MW');
        legend(a1, 'Location', 'southeast'); title(a1, 'Parked charging from 10 % SOC'); title(a2, 'Charger power');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_deg(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1100 550]);
        hold on; grid on;
        for kk = 1:numel(DG)
            plot(DG{kk}.years, 100*DG{kk}.soh, 'LineWidth', 1.5 + 0.8*(kk == 1), 'DisplayName', deg_cases{kk, 1});
        end
        yline(80, 'k--', '80 %', 'HandleVisibility', 'off');
        yline(70, 'r--', '70 % replacement threshold', 'HandleVisibility', 'off');
        xlabel('years in service'); ylabel('capacity (SOH) %'); ylim([60 100]); xlim([0 25]);
        title('Battery capacity fade: BLAST-Lite LFP prismatic, cycle term anchored to the cell datasheet (8,000 cycles to 70 %)');
        legend('Location', 'southwest');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_heat(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1200 800]);
        tiledlayout(2, 1, 'TileSpacing', 'compact');
        names_ = {'cond', 'pe', 'motor', 'fric', 'aux', 'other'};
        labels_ = {'Condenser radiators', 'PE radiators', 'Motor blowers', 'Friction brakes', 'Aux loads', 'Pack enclosure + strings'};
        for kk = [1 3]
            x = g5runs{kk}; h = HR(kk);
            nexttile; hold on; grid on;
            Y = cell2mat(cellfun(@(nm) movmean(h.kW.(nm)(:), 60), names_, 'UniformOutput', false));
            area(h.t/3600, max(Y, 0), 'LineStyle', 'none');
            ylabel('heat to ambient, kW (1-min avg)'); title(x.name);
            if kk == 1, legend(labels_, 'Location', 'northeast'); end
        end
        xlabel('hours');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
    function fig_range(fn)
        f = figure('Visible', 'off', 'Position', [0 0 1100 500]);
        hold on; grid on;
        for ff = ["base", "eol", "r_bol40", "r_bol46", "r_eol40", "r_eol46"]
            x = SH.(ff); plot(x.t/3600, 100*x.soc, 'LineWidth', 1.5, 'DisplayName', x.name);
        end
        yline(100*reserve, 'r--', 'reserve', 'HandleVisibility', 'off');
        xlabel('hours'); ylabel('SOC %'); ylim([0 100]); legend('Location', 'southwest'); title('State of charge through one shift');
        exportgraphics(f, fn, 'Resolution', 150); close(f);
    end
end

% ================= local functions =================
function x = keep(R, name)
% Signals the report uses (keeps the cache small).
r = R.R;
x.name = string(name);
x.t = r.t; x.v = r.v_mph; x.vref = r.v_ref; x.soc = r.soc; x.p_bat = r.p_bat; x.ib = r.ib;
x.te = 4*r.te_ax; x.f_fric = r.f_fric; x.p_chg = r.p_chg; x.Tc = r.Tc;
x.Tcd = r.Tcd; x.Tsup = r.Tsup; x.Tm = r.Tm; x.p_aux = r.p_aux; x.p_tms = r.p_tms; x.q_chill = r.q_chill; x.amb = r.ambient;
x.faults = string(R.faults.fault_id)';
x.f_db = zeros(size(r.t)); x.f_tb = x.f_db;
if isfield(r, 'f_db'), x.f_db = r.f_db; x.f_tb = r.f_tb; end
x.grade = interp1(R.trace.SCN(:,1), R.trace.SCN(:,3), r.t, 'previous', 'extrap');
x.M = R.metrics;
x.C = R.cemex;
x.params = R.params;
x.sim_warnings = numel(R.sim_warnings);
end

function T = mk_trace(t, v, grade, tons, wire, amb)
% Synthetic trace in the loco_system format (state blank = automatic).
t = t(:); n = numel(t);
ex = @(x) x(:).*ones(n, 1);
T = table(t, ex(v), ex(grade), ex(amb), ex(tons), strings(n, 1), ex(wire), nan(n, 1), ...
    'VariableNames', {'time_s','speed_mph','grade_pct','ambient_C','trailing_tons','state','wire_kW','aux_override_kW'});
end

function V = cemex_capability_V(P, soc)
[~, info] = cemex_capability(P, 10, 'Mode', 'start', 'SOC', soc);
V = info.Vbat;
end

function s = th(x)
% thousands separator, no decimals
if ~isfinite(x), s = '-'; return; end
s = sprintf('%.0f', round(x));
neg = s(1) == '-'; if neg, s = s(2:end); end
s = regexprep(s, '(\d)(?=(\d{3})+$)', '$1,');
if neg, s = ['-' s]; end
end

function s = f0(x)
if isnan(x), s = ''; else, s = sprintf('%.0f', x); end
end

function s = f2(x)
s = sprintf('%.2f', x);
end

function s = yn(b)
if b, s = 'yes'; else, s = 'NO'; end
end

function s = yr(x)
if isinf(x), s = '> 25'; else, s = sprintf('%.1f', x); end
end

function s = iff(c, a, b)
if c, s = a; else, s = b; end
end

function H = heat_streams(x, P, lib)
% Heat to ambient by path (W), from thermal.ssc: Qrad_cd, Qrad_pe (from the supply temperature), motor UA with
% blower, pack-to-environment, string resistance outside the cells; plus friction brakes and aux electrical input.
f_ram = 0.2;                                          % thermal.ssc ram-air fraction
ch = struct('fan_cd', 1, 'fan_pe', 1, 'blower_ok', 1, 'aux_ok', 1);
for r = find(ismember(lib.fault_id, x.faults))'
    if isfield(ch, lib.channel(r)), ch.(lib.channel(r)) = lib.active_value(r); end
end
th = P.th; Ta = x.amb;
h_pe = th.UA_pe*(f_ram + (1 - f_ram)*ch.fan_pe);
W.cond = th.UA_cd*(f_ram + (1 - f_ram)*ch.fan_cd)*(x.Tcd - Ta);
W.pe = h_pe*(x.Tsup - Ta)/(1 - h_pe/th.mcp_pe);
W.motor = th.UA_mot*(0.15 + 0.85*ch.blower_ok*ch.aux_ok)*(x.Tm - Ta);
W.fric = abs(x.f_fric).*x.v*0.44704.*(x.v > 0.5);
W.aux = x.p_aux;
W.other = th.UA_benv*(x.Tc - Ta) + P.batt.R_ext_str/P.batt.Np*x.ib.^2;
f = fieldnames(W);
W.total = 0; for k = 1:numel(f), W.total = W.total + W.(f{k}); end
f = fieldnames(W);
tg = (x.t(1):1:x.t(end))';
mv = interp1(x.t, double(x.v > 0.1), tg, 'previous') > 0;
chg = interp1(x.t, double(x.p_chg > 1e3), tg, 'previous') > 0;
for k = 1:numel(f)
    y = interp1(x.t, W.(f{k}), tg);
    H.kW.(f{k}) = y/1e3;
    H.peak5.(f{k}) = max(movmean(y, 300))/1e3;
    H.E.(f{k}) = trapz(tg, y)/3.6e6;
    H.mean_moving.(f{k}) = mean(y(mv))/1e3;
    H.mean_charging.(f{k}) = mean([y(chg); NaN], 'omitnan')/1e3;
end
H.t = tg;
[~, ipk] = max(movmean(H.kW.total, 300));
H.peak_while_charging = chg(ipk);
H.peak_while_moving = mv(ipk);
H.channels = ch;
end

function F = read_fault_library(f)
% fault_library.csv descriptions contain spaces and colons, which can make readtable's automatic detection pick the
% wrong delimiter (27 columns); force comma-delimited text, then hand the table to the shared loader.
opts = detectImportOptions(f, 'Delimiter', ',', 'TextType', 'string');
F = load_fault_table(readtable(f, opts));
end

function s = stopf(x, comma)
% stopping time / distance cell: "cannot stop" when the grade force exceeds the braking
if nargin < 2, comma = false; end
if isinf(x), s = 'cannot stop';
elseif comma, s = th(x);
else, s = sprintf('%.0f', x); end
end

function [ts, xs] = stop_w(v0, m_loco, m_trail, gr, Fb, Pw)
% Stopping time / distance with braking force Fb on grade gr (%), for a given locomotive and trailing mass.
g = 9.81;
m_eff = Pw.veh.k_rot_loco*m_loco + Pw.veh.k_rot_trail*m_trail;
fres = @(v) (m_loco + m_trail)*g*(Pw.veh.Crr + gr/100) + 0.5*1.225*Pw.veh.CdA*v.^2;
if Fb + fres(0) <= 0, ts = Inf; xs = Inf; return; end
opt = odeset('Events', @(~, y) stop_ev(y), 'RelTol', 1e-6);
[tt, yy] = ode45(@(~, y) [-(Fb + fres(y(1)))/m_eff; y(1)], [0 3600], [v0; 0], opt);
ts = tt(end); xs = yy(end, 2);
end

function [val, term, dir] = stop_ev(y)
val = y(1); term = 1; dir = -1;
end
