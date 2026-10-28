function [T, info] = make_cemex_cycle(varargin)
% MAKE_CEMEX_CYCLE  Build a duty trace (loco_system trace format) for CEMEX Victorville quarry <-> plant service.
%   T = make_cemex_cycle()                                  shift on routes/victorville_placeholder.csv
%   T = make_cemex_cycle('Trips', 4, 'PlantCharge_kW', 0, 'Out', 'traces/my_case.csv')
% The route file lists segments in the LOADED direction (quarry -> plant): length_mi, grade_pct (+ = uphill for the
% loaded train), curve_deg, speed_limit_mph. The empty leg runs the segments in reverse with the grade negated.
% Curvature is added as equivalent grade (0.04 % per degree, AREMA). Each segment is run at its speed limit with
% linear ramps (Accel_mphps / Decel_mphps), so trace time follows distance at the limit: where the locomotive cannot
% hold the limit the grade arrives later in reality than in the trace (check RUN.cemex.speed_shortfall).
% One trip: plant dwell (charging if PlantCharge_kW > 0) -> empty to quarry -> load dwell (charging if
% QuarryCharge_kW > 0) -> loaded to plant -> unload dwell. Name-value options (defaults are PLACEHOLDERS):
%   Route            route CSV (routes/victorville_placeholder.csv)
%   Trips            round trips per shift (3)
%   LoadedTons       trailing tons loaded, short tons (4000 = 40 cars x 100 t)
%   EmptyTons        trailing tons empty (1200 = 40 cars x 30 t)
%   Ambient_C        ambient (40, Victorville summer design day)
%   LoadDwell_min    loading at the quarry (60)
%   UnloadDwell_min  unloading at the plant (45)
%   PlantCharge_kW   charge power during the plant dwell (2000; plant microgrid 1.2 MWp + 6 MWh BESS, RFI B10)
%   QuarryCharge_kW  charge power during the quarry dwell (0; quarry microgrid 400 kWp / 2 MWh, charger TBD)
%   StartDwell_min   READY time before the first trip (10)
%   EndPark_min      READY time after the last trip (10)
%   Accel_mphps, Decel_mphps  speed ramp rates (0.15, 0.20)
%   Out              CSV path to write ('' = do not write)
here = fileparts(mfilename('fullpath'));
p = inputParser;
p.addParameter('Route', fullfile(here, 'routes', 'victorville_placeholder.csv'));
p.addParameter('Trips', 3);
p.addParameter('LoadedTons', 4000);
p.addParameter('EmptyTons', 1200);
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
rf = char(o.Route); if ~isfile(rf), rf = fullfile(here, rf); end
RT = readtable(rf, 'TextType', 'string');
g_eq = RT.grade_pct + 0.04*RT.curve_deg;          % curve resistance as equivalent grade (both directions)

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
    function leg(order, sgn, tons)
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

dwell(o.StartDwell_min, o.EmptyTons, 0);
for n = 1:o.Trips
    if n > 1, dwell(o.UnloadDwell_min, o.EmptyTons, o.PlantCharge_kW); end
    leg(height(RT):-1:1, -1, o.EmptyTons);                 % empty: plant -> quarry
    dwell(o.LoadDwell_min, o.LoadedTons, o.QuarryCharge_kW);
    leg(1:height(RT), 1, o.LoadedTons);                    % loaded: quarry -> plant
end
dwell(o.UnloadDwell_min, o.EmptyTons, o.PlantCharge_kW);   % last unload, charge for the next shift
dwell(o.EndPark_min, o.EmptyTons, 0);

n = size(rows, 1);
T = table(rows(:,1), rows(:,2), rows(:,3), repmat(o.Ambient_C, n, 1), rows(:,4), strings(n, 1), rows(:,5), nan(n, 1), ...
    'VariableNames', {'time_s','speed_mph','grade_pct','ambient_C','trailing_tons','state','wire_kW','aux_override_kW'});
[~, iu] = unique(T.time_s, 'last');
T = T(iu, :);
info.route = string(rf);
info.route_mi_one_way = sum(RT.length_mi);
info.max_grade_loaded_pct = max(g_eq);
info.max_grade_empty_pct = max(-RT.grade_pct + 0.04*RT.curve_deg);
info.duration_h = T.time_s(end)/3600;
info.options = o;
if ~isempty(o.Out)
    of = char(o.Out); if ~startsWith(of, {'/', '\'}) && ~contains(of, ':'), of = fullfile(here, of); end
    if ~isfolder(fileparts(of)), mkdir(fileparts(of)); end
    writetable(T, of);
    info.file = string(of);
end
end
