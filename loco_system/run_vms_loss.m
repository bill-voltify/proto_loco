function T = run_vms_loss(varargin)
% RUN_VMS_LOSS  Rev E scenario E7: VMS loss at peak heat (DVP C-21, FMEA G-33, RSK-NEW-VMS-01/-11).
% VMS crash -> Zekalabs converters stop after 1.5 s CAN silence -> 750 V bus down: SPAL pumps (BTMS 24V PS),
% MTMs (BTMS 12V PS), EMP fans, heater, ACH inverters; LCC drops traction after 200 ms (VB-28).
% Fault rows: VMS_LOSS in faults/fault_library.csv (applied together).
% Onset = time of the peak PE device outlet temperature (chopper, charger, inverter) in the no-fault run.
% The trace is held at its last row so that every run observes Observe_s after onset.
%   T = run_vms_loss()                                   % default run list below
%   T = run_vms_loss('Runs', {'traces/S6_notch8_15min.csv', 40, Inf}, 'RString', 'bench')
% Runs: n x 3 cell {trace, ambient_C, outage_s (Inf = permanent)}. Python mirror: reference/run_vms_loss.py.
here = fileparts(mfilename('fullpath'));
addpath(here); addpath(fileparts(here));
p = inputParser;
p.addParameter('Runs', { ...
    'traces/S6_notch8_15min.csv', 40, Inf; ...
    'traces/S6_notch8_15min.csv', 45, Inf; ...
    'traces/S9_dyncharge_2p1MW_demo.csv', 40, Inf; ...
    'traces/CSX4091_20260826_peak2h.csv', 40, Inf; ...
    'traces/S6_notch8_15min.csv', 40, 10; ...
    'traces/S6_notch8_15min.csv', 40, 60; ...
    'traces/S6_notch8_15min.csv', 40, 300});
p.addParameter('Library', fullfile(here, 'faults', 'fault_library.csv'));
p.addParameter('Observe_s', 3600);
p.addParameter('RString', 'vms');
p.addParameter('Settle_s', 5);
p.parse(varargin{:});
o = p.Results;

L = load_fault_table(o.Library);
F0 = L(L.fault_id == "VMS_LOSS", :);
assert(height(F0) > 0, 'VMS_LOSS rows missing from %s', o.Library);
lim = {'Tchop', 63; 'Tinv', 60; 'Tchg', 55; 'Tc', 45; 'Tcd', 65};
rows = {};
for i = 1:size(o.Runs, 1)
    tf = o.Runs{i, 1}; if ~isfile(tf), tf = fullfile(here, tf); end
    Ta = o.Runs{i, 2}; outage = o.Runs{i, 3};
    Tr = readtable(tf, 'TextType', 'string');
    base = run_loco_system(Tr, 'Ambient_C', Ta, 'T0_C', Ta, 'Plot', false, 'Silent', true, 'RString', o.RString);
    R0 = base.R;
    [~, k] = max(max([R0.Tchop, R0.Tchg, R0.Tinv], [], 2));
    t_on = R0.t(k);
    t_end = max(Tr.time_s(end), t_on + o.Observe_s);
    if t_end > Tr.time_s(end)
        Tr = [Tr; Tr(end, :)]; %#ok<AGROW>
        Tr.time_s(end) = t_end;
    end
    F = F0;
    F.enabled(:) = 1;
    F.t_start_s(:) = t_on;
    if isinf(outage), F.t_end_s(:) = 1e9; else, F.t_end_s(:) = t_on + outage; end
    nf = run_loco_system(Tr, 'Ambient_C', Ta, 'T0_C', Ta, 'Plot', false, 'Silent', true, 'RString', o.RString);
    rf = run_loco_system(Tr, 'Faults', F, 'Ambient_C', Ta, 'T0_C', Ta, 'Plot', false, 'Silent', true, 'RString', o.RString);
    R = rf.R; Rn = nf.R;
    [~, nm] = fileparts(tf);
    r = struct('trace', string(nm), 'T_amb', Ta, 'outage_s', outage, 'onset_s', t_on);
    a = R.t >= t_on + o.Settle_s; an = Rn.t >= t_on + o.Settle_s;
    for j = 1:size(lim, 1)
        s = lim{j, 1};
        r.([s '_at_onset']) = interp1(R.t, R.(s), t_on);
        r.([s '_peak_after']) = max(R.(s)(a));
        r.([s '_peak_after_nofault']) = max(Rn.(s)(an));
        dt = [diff(R.t); 0];
        r.([s '_min_over_limit']) = sum(dt(a & R.(s) > lim{j, 2}))/60;
    end
    r.Tsup_peak_after = max(R.Tsup(a));
    r.verdict = string(rf.metrics.verdict);
    rows{end+1} = r; %#ok<AGROW>
    fprintf('%-28s %2d C outage %8s onset %6.0f s | chop %5.1f -> %5.1f (no fault %5.1f, %4.1f min > 63) inv %5.1f chg %5.1f cell %5.1f -> %5.1f\n', ...
        nm, Ta, num2str(outage), t_on, r.Tchop_at_onset, r.Tchop_peak_after, r.Tchop_peak_after_nofault, ...
        r.Tchop_min_over_limit, r.Tinv_peak_after, r.Tchg_peak_after, r.Tc_at_onset, r.Tc_peak_after);
end
T = struct2table([rows{:}]');
outdir = fullfile(fileparts(here), 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end
stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
writetable(T, fullfile(outdir, ['vms_loss_' o.RString '_' stamp '.csv']));
fprintf('Model limit: LB-1186 / LB-1113 heat is lumped into the PE node (NAT-46); converter heat soak after the stop is not modeled.\n');
end
