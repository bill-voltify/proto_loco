function D = decompose_csx4091(matfile)
% DECOMPOSE_CSX4091  Energy decomposition battery -> wheel -> rail for the CSX4091 baseline runs.
%   D = decompose_csx4091                     newest loco_system/results_csx4091_*.mat
%   D = decompose_csx4091('results_csx4091_20261016_0823.mat')
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(here); addpath(root);
if nargin < 1 || isempty(matfile)
    L = dir(fullfile(here, 'results_csx4091_*.mat'));
    assert(~isempty(L), 'No results_csx4091_*.mat in %s', here);
    [~, k] = max([L.datenum]);
    matfile = fullfile(L(k).folder, L(k).name);
elseif ~isfile(matfile)
    matfile = fullfile(here, matfile);
end
assert(isfile(matfile), 'Missing %s', matfile);
fprintf('Loading %s ...\n', matfile);
S = load(matfile, 'results');
P = loco_system_params(struct('baseline', 'poc'));
rail = struct('peak2h', 78.4, 'yard', 331.1);
cases = fieldnames(S.results);
rows = {};
D = struct();
for c = 1:numel(cases)
    name = cases{c};
    r_kWh = NaN;
    if isfield(rail, name), r_kWh = rail.(name); end
    [d, r] = one_case(S.results.(name), P, name, r_kWh);
    D.(name) = d;
    rows = [rows; r]; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'case','group','item','value','unit','pct_of_source'});
outdir = fullfile(root, 'results');
if ~isfolder(outdir), mkdir(outdir); end
[~, mn] = fileparts(matfile);
csvf = fullfile(outdir, sprintf('decompose_%s.csv', erase(mn, 'results_')));
writetable(T, csvf);
fprintf('\nWrote %s\n', csvf);
D.table = T;
D.source = matfile;
end

function [d, rows] = one_case(RUN, P, name, rail_kWh)
R = RUN.R;
t = R.t(:);
dt = [diff(t); 0];
nax = 4;
if isfield(RUN, 'faults') && height(RUN.faults) > 0
    warning('%s: faults applied (%s); 4 axles assumed', name, strjoin(string(RUN.faults.fault_id), ', '));
end
kWh = @(p) trapz(t, p(:))/3.6e6;
es = @(p, m) sum(p(m).*dt(m))/3.6e6;

p_bat = R.vt(:).*R.ib(:);
q_bat = R.q_bat(:);
p_chem = p_bat + q_bat;
p_chg = R.p_chg(:);
p_aux = R.p_aux(:);
p_tms = R.p_tms(:);
p_auxcmd = R.P_aux_cmd(:);
p_dcl_in = p_bat - p_aux + p_chg;
p_ax_dc = nax*R.vlink(:).*R.idc_ax(:);
ia = R.ia(:);
p_mot_in = nax*R.va(:).*ia;
p_cu = nax*P.ax.R_m*ia.^2;
p_L = nax*P.ax.L_a*ia.*gradient(ia, t);
p_shaft = p_mot_in - p_cu - p_L;
eg = P.ax.eta_g;
p_wheel = p_shaft.*(eg + (1/eg - eg)*0.5*(1 - tanh(p_shaft/nax/1e3)));

E.chem_net = kWh(p_chem);
E.chem_out = kWh(max(p_chem, 0));
E.chg_in = kWh(max(p_chg, 0));
E.wire = E.chg_in/P.th.eta_chg;
E.source = E.chem_net + E.chg_in;
E.bat_loss = kWh(q_bat);
E.aux_loads = kWh(p_auxcmd);
E.tms = kWh(p_tms);
E.aux_conv = kWh(p_aux) - E.aux_loads - E.tms;
E.dcl_loss = kWh(p_dcl_in - p_ax_dc);
E.chop_loss = kWh(p_ax_dc - p_mot_in);
E.mot_cu = kWh(p_cu);
E.gear = kWh(p_shaft - p_wheel);
E.wheel = kWh(p_wheel);
E.wheel_pos = kWh(max(p_wheel, 0));
E.wheel_neg = kWh(min(p_wheel, 0));
E.resid = E.source - (E.bat_loss + E.aux_loads + E.tms + E.aux_conv + E.dcl_loss + E.chop_loss + E.mot_cu + E.gear + E.wheel);

ai = abs(ia);
C.derived = E.chop_loss;
C.integral_sim = kWh(nax*((1580/1170 + 0.339)*ai + 3.57e-4*ia.^2));
C.deck = kWh(nax*(2.5*ai + 2.38e-3*ia.^2));
if abs(C.derived - C.integral_sim) <= abs(C.derived - C.deck), C.basis = 'integral_sim (Rev C)'; else, C.basis = 'deck (pre-Rev C)'; end

v = R.v_mph(:)*0.44704;
SCN = RUN.trace.SCN;
mt = max(interp1(SCN(:,1), SCN(:,5), t, 'linear', 'extrap'), 0)*P.sys.short_ton_kg;
gr = interp1(SCN(:,1), SCN(:,3), t, 'linear', 'extrap');
g = 9.81;
m_tot = P.veh.m_loco + mt;
m_eff = P.veh.k_rot_loco*P.veh.m_loco + P.veh.k_rot_trail*mt;
s = tanh(v/0.1);
V.ke = kWh(m_eff.*v.*gradient(v, t));
V.roll = kWh(m_tot*g*P.veh.Crr.*s.*v);
V.grade = kWh(m_tot*g.*gr/100.*v);
V.aero = kWh(0.5*1.225*P.veh.CdA*abs(v).^3);
V.fric = kWh(R.f_fric(:).*s.*v);
V.resid = E.wheel - (V.ke + V.roll + V.grade + V.aero + V.fric);

mot = p_mot_in > 1e3;
mov = abs(R.v_mph(:)) > 0.1;
idle = ~mot & ~mov;
coast = ~mot & mov;
H.total = (t(end) - t(1))/3600;
H.motoring = sum(dt(mot))/3600;
H.coast_brake = sum(dt(coast))/3600;
H.standstill = sum(dt(idle))/3600;
A.idle_chem = es(p_chem, idle);
A.idle_aux = es(p_aux, idle);
A.mot_chem = es(p_chem, mot);
A.coast_chem = es(p_chem, coast);

eta.battery = es(p_bat, mot)/es(p_chem, mot);
eta.dclink = es(p_ax_dc, mot)/es(p_dcl_in, mot);
eta.chopper = es(p_mot_in, mot)/es(p_ax_dc, mot);
eta.motor = es(p_shaft, mot)/es(p_mot_in, mot);
eta.gear = es(p_wheel, mot)/es(p_shaft, mot);
eta.drivetrain = es(p_wheel, mot)/es(p_ax_dc, mot);
eta.bat_to_wheel_motoring = es(p_wheel, mot)/es(p_chem, mot);
eta.bat_to_wheel_day = E.wheel_pos/E.chem_out;

Ah_int = trapz(t, R.ib(:))/3600;
Ah_soc = (R.soc(1) - R.soc(end))*P.batt.Np*P.batt.Q_cell;

fprintf('\n=================== %s ===================\n', upper(name));
if isfield(RUN, 'options') && isfield(RUN.options, 'WheelIn')
    o = RUN.options;
    fprintf('Run options: wheel %g in | chop %s x%g | cap %g kW | flux %s | regen %s\n', o.WheelIn, o.ChopLoss, o.ChopLossScale, o.MotorCapkW, o.MotorFlux, mat2str(o.Regen));
else
    fprintf('Run options: no Rev C fields saved (run predates Rev C option logging)\n');
end
fprintf('Chopper loss basis inferred from signals: %s (derived %.1f | integral_sim %.1f | deck %.1f kWh)\n', C.basis, C.derived, C.integral_sim, C.deck);
fprintf('Duration %.2f h: motoring %.2f h (%.0f%%) | moving, not motoring %.2f h | standstill %.2f h (%.0f%%)\n', ...
    H.total, H.motoring, 100*H.motoring/H.total, H.coast_brake, H.standstill, 100*H.standstill/H.total);
fprintf('SOC %.1f%% -> %.1f%% | Ah check: integral %.0f Ah vs SOC %.0f Ah (%+.2f%%)\n', ...
    100*R.soc(1), 100*R.soc(end), Ah_int, Ah_soc, 100*(Ah_int - Ah_soc)/max(abs(Ah_soc), eps));

items = {
    'source', 'Battery chemical (net)',      E.chem_net
    'source', 'Charger in (at battery)',     E.chg_in
    'loss',   'Battery I2R',                 E.bat_loss
    'load',   'Aux loads (budget)',          E.aux_loads
    'load',   'TMS',                         E.tms
    'loss',   'Aux converter',               E.aux_conv
    'loss',   'DC-link / precharge',         E.dcl_loss
    'loss',   'Chopper',                     E.chop_loss
    'loss',   'Motor copper',                E.mot_cu
    'loss',   'Gear',                        E.gear
    'check',  'Residual (L, C storage)',     E.resid
    'output', 'Wheel (net)',                 E.wheel
    };
fprintf('\n%-30s %10s %8s\n', 'Battery -> wheel', 'kWh', '% src');
for k = 1:size(items, 1)
    fprintf('%-30s %10.1f %7.1f%%\n', items{k,2}, items{k,3}, 100*items{k,3}/E.source);
end
fprintf('%-30s %10.1f\n', 'Wheel motoring (+)', E.wheel_pos);
fprintf('%-30s %10.1f\n', 'Wheel braking (-)', E.wheel_neg);
if E.chg_in > 0, fprintf('%-30s %10.1f\n', 'Wire energy (charger in)', E.wire); end
if E.aux_conv < 0, fprintf('NOTE: aux converter term negative -> aux clipped at P_aux_max for part of the run\n'); end

vitems = {
    'Kinetic (net)',        V.ke
    'Rolling',              V.roll
    'Grade',                V.grade
    'Aero',                 V.aero
    'Friction brake',       V.fric
    'Residual (interp)',    V.resid
    };
fprintf('\n%-30s %10s %8s\n', 'Wheel -> train', 'kWh', '% wheel');
for k = 1:size(vitems, 1)
    fprintf('%-30s %10.1f %7.1f%%\n', vitems{k,1}, vitems{k,2}, 100*vitems{k,2}/max(abs(E.wheel), eps));
end

fprintf('\nMotoring-window efficiencies: battery %.1f%% | DC-link %.1f%% | chopper %.1f%% | motor %.1f%% | gear %.1f%%\n', ...
    100*eta.battery, 100*eta.dclink, 100*eta.chopper, 100*eta.motor, 100*eta.gear);
fprintf('Drivetrain (DC-link out -> wheel) %.1f%% | battery chem -> wheel while motoring %.1f%% | whole day %.1f%%\n', ...
    100*eta.drivetrain, 100*eta.bat_to_wheel_motoring, 100*eta.bat_to_wheel_day);
fprintf('Standstill: %.1f kWh chem (%.0f%% of chem out), of which aux bus %.1f kWh\n', ...
    A.idle_chem, 100*A.idle_chem/max(E.chem_out, eps), A.idle_aux);
fprintf('Recorder rail energy %.1f kWh vs model wheel motoring %.1f kWh (ratio %.2f)\n', rail_kWh, E.wheel_pos, E.wheel_pos/rail_kWh);
fprintf('kWh per recorder rail kWh: %.2f chem | %.2f incl. aux+TMS share\n', E.chem_out/rail_kWh, E.source/rail_kWh);

lab = [items([1 3:11],2); {'Wheel (net)'}];
vals = [E.bat_loss E.aux_loads E.tms E.aux_conv E.dcl_loss E.chop_loss E.mot_cu E.gear E.resid];
src = E.source;
lev = src - cumsum([0 vals]);
lo = [0, min(lev(1:end-1), lev(2:end)), 0];
hi = [src, abs(vals), E.wheel];
lab{1} = sprintf('Source (chem net + charger)');
figure('Name', ['decompose_' name], 'Color', 'w', 'Position', [100 100 1200 520]);
subplot(1, 2, 1);
b = barh(1:numel(hi), [lo(:) hi(:)], 'stacked');
b(1).FaceColor = 'none'; b(1).EdgeColor = 'none';
b(2).FaceColor = [0.25 0.45 0.75];
set(gca, 'YDir', 'reverse', 'YTick', 1:numel(hi), 'YTickLabel', lab, 'FontSize', 9);
xlabel('kWh'); grid on;
for k = 1:numel(hi)
    text(lo(k) + hi(k), k, sprintf('  %.1f (%.1f%%)', hi(k), 100*hi(k)/src), 'FontSize', 8);
end
xlim([0 1.25*src]);
title(sprintf('%s: battery -> wheel', name), 'Interpreter', 'none');
subplot(1, 2, 2);
vv = cell2mat(vitems(:,2));
barh(1:numel(vv), vv, 'FaceColor', [0.85 0.45 0.2]);
set(gca, 'YDir', 'reverse', 'YTick', 1:numel(vv), 'YTickLabel', vitems(:,1), 'FontSize', 9);
xlabel('kWh'); grid on;
for k = 1:numel(vv)
    text(max(vv(k), 0), k, sprintf('  %.1f', vv(k)), 'FontSize', 8);
end
title(sprintf('wheel -> train | recorder rail %.1f kWh', rail_kWh), 'Interpreter', 'none');

d = struct('E', E, 'V', V, 'eta', eta, 'hours', H, 'standstill', A, 'chop', C, 'rail_kWh', rail_kWh, ...
    'Ah_int', Ah_int, 'Ah_soc', Ah_soc);

rows = {};
for k = 1:size(items, 1)
    rows(end+1, :) = {name, items{k,1}, items{k,2}, items{k,3}, 'kWh', 100*items{k,3}/src}; %#ok<AGROW>
end
rows(end+1, :) = {name, 'output', 'Wheel motoring (+)', E.wheel_pos, 'kWh', 100*E.wheel_pos/src};
rows(end+1, :) = {name, 'output', 'Wheel braking (-)', E.wheel_neg, 'kWh', 100*E.wheel_neg/src};
rows(end+1, :) = {name, 'source', 'Wire energy (charger in)', E.wire, 'kWh', NaN};
for k = 1:size(vitems, 1)
    rows(end+1, :) = {name, 'vehicle', vitems{k,1}, vitems{k,2}, 'kWh', NaN}; %#ok<AGROW>
end
f = fieldnames(eta);
for k = 1:numel(f)
    rows(end+1, :) = {name, 'efficiency', f{k}, 100*eta.(f{k}), '%', NaN}; %#ok<AGROW>
end
f = fieldnames(H);
for k = 1:numel(f)
    rows(end+1, :) = {name, 'time', f{k}, H.(f{k}), 'h', NaN}; %#ok<AGROW>
end
rows(end+1, :) = {name, 'standstill', 'Chem energy at standstill', A.idle_chem, 'kWh', 100*A.idle_chem/src};
rows(end+1, :) = {name, 'standstill', 'Aux bus at standstill', A.idle_aux, 'kWh', 100*A.idle_aux/src};
rows(end+1, :) = {name, 'benchmark', 'Recorder rail energy', rail_kWh, 'kWh', NaN};
rows(end+1, :) = {name, 'benchmark', 'Model wheel / recorder rail', E.wheel_pos/rail_kWh, 'ratio', NaN};
rows(end+1, :) = {name, 'benchmark', 'Chem out per recorder rail kWh', E.chem_out/rail_kWh, 'ratio', NaN};
rows(end+1, :) = {name, 'check', ['Chopper loss basis: ' C.basis], C.derived, 'kWh', NaN};
end
