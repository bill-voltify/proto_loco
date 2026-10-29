function [T, info] = make_cemex_cycle(varargin)
% MAKE_CEMEX_CYCLE  Build a duty trace (loco_system trace format) for CEMEX Victorville quarry <-> plant service.
%   T = make_cemex_cycle()                       shift on the Black Mountain run profile (routes/mojave_northern_*)
%   T = make_cemex_cycle('Trips', 4, 'PlantCharge_kW', 0, 'Out', 'traces/my_case.csv')
%   T = make_cemex_cycle('Profile', '', 'Route', 'routes/victorville_placeholder.csv', 'LoadedTons', 4000, 'EmptyTons', 1200)
% Two route sources:
%   Profile (default): a run profile CSV (Time_Seconds, Distance_Miles, Speed_MPH, Grade_Percent) recorded in the
%     LOADED direction, Black Mountain Quarry (mile 0) -> Victorville plant (mile 11). The loaded leg replays it as
%     recorded; the empty leg replays it backwards in time (same speed at each location, grade negated).
%     Grade is used as recorded (curvature, if any, is assumed to be included).
%   Route (Profile = ''): segment table in the loaded direction: length_mi, grade_pct, curve_deg, speed_limit_mph;
%     curvature added as 0.04 % per degree; each segment run at its limit with Accel_mphps / Decel_mphps ramps.
% Trace time follows the profile, so where the locomotive cannot hold the speed the grade arrives later in reality
% than in the trace (check RUN.cemex.speed_shortfall).
% One trip: plant dwell (charging if PlantCharge_kW > 0) -> empty to quarry -> load dwell (charging if
% QuarryCharge_kW > 0) -> loaded to plant -> unload dwell. Name-value options:
%   Profile          run profile CSV (routes/mojave_northern_sd40_2_profile.csv); '' = use Route
%   Route            segment route CSV (routes/victorville_placeholder.csv), used when Profile is ''
%   Trips            round trips per shift (3)
%   LoadedTons       trailing tons loaded, short tons (2470, Black Mountain loaded train)
%   EmptyTons        trailing tons empty (740, ASSUMED: 30 % of loaded, same tare ratio as 100 t cars at 30 t)
%   Ambient_C        ambient (40, Victorville summer design day)
%   LoadDwell_min    loading at the quarry (60)
%   UnloadDwell_min  unloading at the plant (45)
%   PlantCharge_kW   charge power during the plant dwell (2000; plant microgrid 1.2 MWp + 6 MWh BESS, RFI B10)
%   QuarryCharge_kW  charge power during the quarry dwell (0; quarry microgrid 400 kWp / 2 MWh, charger TBD)
%   StartDwell_min   READY time before the first trip (10)
%   EndPark_min      READY time after the last trip (10)
%   Accel_mphps, Decel_mphps  speed ramp rates for segment routes (0.15, 0.20)
%   Out              CSV path to write ('' = do not write)
% info: route statistics in the same form for both sources (grade by distance per direction, critical grades and
%   their lengths, speed range, description) for cemex_rfi_report.
here = fileparts(mfilename('fullpath'));
p = inputParser;
p.addParameter('Profile', fullfile(here, 'routes', 'mojave_northern_sd40_2_profile.csv'));
p.addParameter('Route', fullfile(here, 'routes', 'victorville_placeholder.csv'));
p.addParameter('Trips', 3);
p.addParameter('LoadedTons', 2470);
p.addParameter('EmptyTons', 740);
p.addParameter('Ambient_C', 40);
p.addParameter('LoadDwell_min', 60);
p.addParameter('UnloadDwell_min', 45);
p.addParameter('PlantCharge_kW', 2000);
p.addParameter('QuarryCharge_kW', 0);
p.addParameter('StartDwell_min', 10);
p.addParameter('EndPark_min', 10);
p.addParameter('Accel_mphps', 0.15);
p.addParameter('Decel_mphps', 0.20);
p.addParameter('Out', '');
p.parse(varargin{:});
o = p.Results;
use_profile = strlength(string(o.Profile)) > 0;

if use_profile
    pf = char(o.Profile); if ~isfile(pf), pf = fullfile(here, pf); end
    PR = readtable(pf, 'TextType', 'string');
    pt = PR.Time_Seconds - PR.Time_Seconds(1);
    pv = PR.Speed_MPH;
    pg = PR.Grade_Percent;
    pd = PR.Distance_Miles;
    src = string(pf);
    % grade by distance in each direction (for statistics)
    d_load = pd; g_load = pg;
    d_empty = pd(end) - flipud(pd); g_empty = -flipud(pg);
    route_mi = pd(end);
    v_rng = [min(pv(pv > 0)), max(pv)];
    desc = sprintf('Black Mountain Quarry -> Victorville plant run profile (%s, %.1f mi, %.0f min loaded)', ...
        PR.Locomotive(1), route_mi, pt(end)/60);
    speed_txt = sprintf('as run, up to %.1f mph', v_rng(2));
else
    rf = char(o.Route); if ~isfile(rf), rf = fullfile(here, rf); end
    RT = readtable(rf, 'TextType', 'string');
    src = string(rf);
    ge = RT.grade_pct + 0.04*RT.curve_deg;
    edges = [0; cumsum(RT.length_mi)];
    d_load = reshape([edges(1:end-1)'; edges(2:end)'], [], 1); g_load = repelem(ge, 2);
    gm = -RT.grade_pct + 0.04*RT.curve_deg;
    re = [0; cumsum(flipud(RT.length_mi))];
    d_empty = reshape([re(1:end-1)'; re(2:end)'], [], 1); g_empty = repelem(flipud(gm), 2);
    route_mi = sum(RT.length_mi);
    v_rng = [min(RT.speed_limit_mph), max(RT.speed_limit_mph)];
    desc = sprintf('segment route %s (%d segments, %.1f mi)', RT.Properties.Description, height(RT), route_mi);
    speed_txt = sprintf('%g-%g mph by segment', v_rng);
end

rows = zeros(0, 5);                               % time_s, speed_mph, grade_pct, trailing_tons, wire_kW
t = 0;
    function add(v, g, tons, w)
        rows(end+1, :) = [t, v, g, tons, w];
    end
    function dwell(minutes, tons, w)
        add(0, 0, tons, w);
        t = t + 60*minutes;
        add(0, 0, tons, w);
        t = t + 1;
    end
    function leg_profile(loaded, tons)
        if loaded
            tt = pt; vv = pv; gg = pg;
        else                                       % backwards in time: same speed at each location, grade negated
            tt = pt(end) - flipud(pt); vv = flipud(pv); gg = -flipud(pg);
        end
        t0 = t;
        for k = 1:numel(tt)
            t = t0 + tt(k);
            add(vv(k), gg(k), tons, 0);
        end
        if vv(end) > 0, t = t + vv(end)/o.Decel_mphps; add(0, gg(end), tons, 0); end
        t = t + 1;
    end
    function leg_route(order, sgn, tons)
        v = 0;
        for i = order(:)'
            g = sgn*RT.grade_pct(i) + 0.04*RT.curve_deg(i);
            vl = RT.speed_limit_mph(i);
            L = RT.length_mi(i)*1609.344;
            add(v, g, tons, 0);
            ramp = abs(vl - v)/o.Accel_mphps*(vl > v) + abs(vl - v)/o.Decel_mphps*(vl < v);
            t = t + ramp;
            add(vl, g, tons, 0);
            t = t + max(L/(vl*0.44704) - ramp/2, 0);
            v = vl;
        end
        add(v, g, tons, 0);
        t = t + v/o.Decel_mphps;
        add(0, g, tons, 0);
        t = t + 1;
    end
    function leg(loaded, tons)
        if use_profile, leg_profile(loaded, tons);
        elseif loaded, leg_route(1:height(RT), 1, tons);
        else, leg_route(height(RT):-1:1, -1, tons); end
    end

dwell(o.StartDwell_min, o.EmptyTons, 0);
for n = 1:o.Trips
    if n > 1, dwell(o.UnloadDwell_min, o.EmptyTons, o.PlantCharge_kW); end
    leg(false, o.EmptyTons);                               % empty: plant -> quarry
    dwell(o.LoadDwell_min, o.LoadedTons, o.QuarryCharge_kW);
    leg(true, o.LoadedTons);                               % loaded: quarry -> plant
end
dwell(o.UnloadDwell_min, o.EmptyTons, o.PlantCharge_kW);   % last unload, charge for the next shift
dwell(o.EndPark_min, o.EmptyTons, 0);

n = size(rows, 1);
T = table(rows(:,1), rows(:,2), rows(:,3), repmat(o.Ambient_C, n, 1), rows(:,4), strings(n, 1), rows(:,5), nan(n, 1), ...
    'VariableNames', {'time_s','speed_mph','grade_pct','ambient_C','trailing_tons','state','wire_kW','aux_override_kW'});
[~, iu] = unique(T.time_s, 'last');
T = T(iu, :);
info.route = src;
info.is_profile = use_profile;
info.description = desc;
info.speed_text = speed_txt;
info.route_mi_one_way = route_mi;
info.speed_range_mph = v_rng;
info.dist_loaded = d_load; info.grade_loaded = g_load;
info.dist_empty = d_empty; info.grade_empty = g_empty;
[info.crit_up_loaded, info.crit_up_loaded_mi] = crit(d_load, g_load, 1);
[info.crit_up_empty, info.crit_up_empty_mi] = crit(d_empty, g_empty, 1);
[info.crit_dn_loaded, info.crit_dn_loaded_mi] = crit(d_load, g_load, -1);
[info.crit_dn_empty, info.crit_dn_empty_mi] = crit(d_empty, g_empty, -1);
info.max_grade_loaded_pct = info.crit_up_loaded;
info.max_grade_empty_pct = info.crit_up_empty;
info.duration_h = T.time_s(end)/3600;
info.options = o;
if ~isempty(o.Out)
    of = char(o.Out); if ~startsWith(of, {'/', '\'}) && ~contains(of, ':'), of = fullfile(here, of); end
    if ~isfolder(fileparts(of)), mkdir(fileparts(of)); end
    writetable(T, of);
    info.file = string(of);
end
end

function [gc, len] = crit(d, g, sgn)
% Steepest grade in one direction (sgn 1 = up, -1 = down) and the length of the stretch within 0.25 % of it.
[gc, i] = max(sgn*g); gc = sgn*gc;
near = sgn*g >= sgn*gc - 0.25;
a = i; while a > 1 && near(a - 1), a = a - 1; end
b = i; while b < numel(g) && near(b + 1), b = b + 1; end
len = d(b) - d(a);
end
