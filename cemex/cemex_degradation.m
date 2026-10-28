function D = cemex_degradation(shift, varargin)
% CEMEX_DEGRADATION  Battery capacity fade over the locomotive's life (RFI E4), driven by the simulated duty.
%   D = cemex_degradation(shift)                       base: 2 shifts/day, 6 days/week, parked at 25 C
%   D = cemex_degradation(shift, 'ParkSOC', 0.5, 'ShiftsPerDay', 1, 'Years', 25)
% shift: one simulated shift, struct with t (s), soc (0-1), Tc (cell temperature, C), e.g. a cemex_rfi_report cache
%   entry or run_cemex(...).R (fields t, soc, Tc).
%
% Model: NREL BLAST-Lite "Lfp_Gr_250AhPrismatic" (large-format LFP/graphite prismatic, > 250 Ah; data
%   doi:10.1016/j.est.2023.109042), ported from blast/models/lfp_gr_250AhPrismatic_2019.py and degradation_model.py:
%   calendar  qLoss_t   = k_cal * t_days^pcal,  k_cal = |p1| exp(p2/T) exp(p3*Ua/T)
%   cycle     qLoss_EFC = k_cyc * EFC^pcyc,     k_cyc = (p4 + p5*DOD + p6*Crate) (exp(p7/T) + exp(-p8/T))
%   q = 1 - qLoss_t - qLoss_EFC; Ua = graphite potential vs SOC (Safari & Delacourt 2011); rates time-averaged
%   over each 1-day step and integrated with BLAST's power-state update.
% Cell anchor: the cycle term is scaled (CycleScale) so the model reproduces the EVE MB31 314 Ah datasheet
%   (PBRI-MB31-D06-01): 8000 cycles to 70 % SOH at 25 C, 0.5P/0.5P, 100 % DOD. The calendar term is BLAST's
%   unchanged: EVE publishes no calendar-aging curve (only 28-day storage retention, checked in D.checks).
% Valid 10-45 C (BLAST fit range). Capacity only; resistance growth is not modeled (cemex_params r_age).
%
% Name-value options:
%   ShiftsPerDay  shifts per operating day (2); the shift profile is repeated, the rest of the day is parked
%   DaysPerWeek   operating days per week (6); other days parked all day
%   Years         horizon (25)
%   ParkSOC       SOC while parked ([] = the shift's end SOC, i.e. left on charge at ~95 %)
%   ParkT_C       cell temperature while parked (25 = TMS conditioning on shore/charger power)
%   ShiftT_C      [] = simulated cell temperature; a number overrides it (sensitivity)
%   CycleScale    [] = fit to the EVE anchor; a number uses it directly
%   Anchor        struct(cycles 8000, soh 0.70, T_C 25, crate 0.5)
p = inputParser;
p.addParameter('ShiftsPerDay', 2);
p.addParameter('DaysPerWeek', 6);
p.addParameter('Years', 25);
p.addParameter('ParkSOC', []);
p.addParameter('ParkT_C', 25);
p.addParameter('ShiftT_C', []);
p.addParameter('CycleScale', []);
p.addParameter('Anchor', struct('cycles', 8000, 'soh', 0.70, 'T_C', 25, 'crate', 0.5));
p.parse(varargin{:});
o = p.Results;
L = blast_params();

% ---------------- cycle-term anchor to the EVE datasheet ----------------
A = o.Anchor;
if isempty(o.CycleScale)
    o.CycleScale = fzero(@(s) cycles_to(A.soh, A.crate, A.T_C, L, s) - A.cycles, [0.2 5]);
end

% ---------------- locomotive day profiles ----------------
dt = 60;
t1 = (shift.t(1):dt:shift.t(end))';
s1 = interp1(shift.t, shift.soc, t1);
T1 = interp1(shift.t, shift.Tc, t1);
if ~isempty(o.ShiftT_C), T1(:) = o.ShiftT_C; end
dur = t1(end) - t1(1);
assert(o.ShiftsPerDay*dur <= 86400, 'ShiftsPerDay x shift length exceeds 24 h');
park_soc = o.ParkSOC; if isempty(park_soc), park_soc = s1(end); end
n_park = round((86400 - o.ShiftsPerDay*dur)/dt);
op.soc = [repmat(s1, o.ShiftsPerDay, 1); park_soc*ones(n_park, 1)];
op.T = [repmat(T1, o.ShiftsPerDay, 1); o.ParkT_C*ones(n_park, 1)];
if ~isempty(o.ParkSOC)       % shift starts from the pre-shift charge: ramp park -> shift start counted as charge
    op.soc(1) = park_soc;
end
op.t = (0:numel(op.soc) - 1)'*dt*86400/(numel(op.soc)*dt);
idle.t = op.t; idle.soc = park_soc*ones(size(op.t)); idle.T = o.ParkT_C*ones(size(op.t));
ndays = round(365.25*o.Years);
isop = mod(0:ndays - 1, 7) < o.DaysPerWeek;
[qc, qe, efc] = run_life({idle, op}, isop + 1, ndays, L, o.CycleScale);

q = 1 - qc - qe;
yrs = (1:ndays)'/365.25;
D.years = yrs;
D.soh = q;
D.q_cal_loss = qc;
D.q_cyc_loss = qe;
D.efc = efc;
D.efc_per_year = efc(end)/o.Years;
D.years_to_80 = cross_year(yrs, q, 0.80);
D.years_to_70 = cross_year(yrs, q, 0.70);
D.soh_at = arrayfun(@(y) interp1(yrs, q, y), [5 10 15 20]);
k_eol = min([find(q <= 0.70, 1); ndays]);                  % 70 % or end of horizon
D.cal_share_at_eol = qc(k_eol)/(qc(k_eol) + qe(k_eol));
D.cycle_scale = o.CycleScale;
D.options = o;
D.park_soc = park_soc;
D.shift_efc = sum(abs(diff(s1)))/2;

% ---------------- checks against EVE data not used in the fit ----------------
% storage (MB31 datasheet): 28 days at 50 % SOC: >= 98 % recovery at 25 C, >= 97 % at 45 C (recoverable + permanent)
st = @(TC) 1 - run_life(struct('t', [0; 86400], 'soc', [0.5; 0.5], 'T', [TC; TC]), 1, 28, L, o.CycleScale);
D.checks.storage_28d_25C = st(25);
D.checks.storage_28d_45C = st(45);
% cycle life to 80 % at 25 C and 45 C, 0.5C/0.5C (EVE LF304 spec, same family: 4000 and 1800 cycles)
D.checks.cycles80_25C = cycles_to(0.80, 0.5, 25, L, o.CycleScale);
D.checks.cycles80_45C = cycles_to(0.80, 0.5, 45, L, o.CycleScale);
D.checks.cycles70_25C = cycles_to(0.70, 0.5, 25, L, o.CycleScale);
end

% ======================================================================
function L = blast_params()
% BLAST-Lite lfp_gr_250AhPrismatic_2019 _params_life
L = struct('p1', 8.37e4, 'p2', -5.21e3, 'p3', -3.56e3, 'pcal', 0.526, ...
    'p4', 4.38e-8, 'p5', 1.55e-8, 'p6', 1.68e-7, 'p7', 2.19e3, 'p8', 1.55e5, 'pcyc', 0.828);
end

function d = eve_day(crate, TC)
% 24 h of continuous full-DOD cycling at crate charge / crate discharge (EVE datasheet cycle test)
per = 2/crate*3600;
t = (0:60:86400)';
ph = mod(t, per)/per;
d.t = t;
d.soc = 1 - abs(2*ph - 1);                   % 0 -> 1 -> 0 triangle
d.T = TC*ones(size(t));
end

function n = cycles_to(soh, crate, TC, L, s)
d = eve_day(crate, TC);
efc_day = 24*crate/2;
[qc, qe, efc] = run_life(d, 1, ceil(30000/efc_day), L, s);
q = 1 - qc - qe;
k = find(q <= soh, 1);
if isempty(k), n = 1e6; elseif k == 1, n = efc(1); else, n = interp1(q(k-1:k), efc(k-1:k), soh); end
end

function [qc, qe, efc] = run_life(days, seq, ndays, L, s)
% Daily BLAST update. days: struct or cell of structs (t s, soc, T C); seq: index into days per day (scalar = same).
if ~iscell(days), days = {days}; end
if isscalar(seq), seq = seq*ones(1, ndays); end
R = cellfun(@(d) day_rates(d, L), days);
qc = zeros(ndays, 1); qe = qc; efc = qc;
yc = 0; ye = 0; e = 0; q = 1;
for k = 1:ndays
    r = R(seq(k));
    yc = yc + pstate(yc, 1, r.kcal, L.pcal);
    de = r.efc*q;
    ye = ye + s*pstate(ye/s, de, r.kcyc_noC + L.p6*r.crate*q*r.fT, L.pcyc);
    e = e + de;
    q = 1 - yc - ye;
    qc(k) = yc; qe(k) = ye; efc(k) = e;
end
end

function r = day_rates(d, L)
TK = d.T + 273.15;
dtd = (d.t(end) - d.t(1))/86400;
Ua = graphite_Ua(d.soc);
r.kcal = trapz(d.t, abs(L.p1)*exp(L.p2./TK).*exp(L.p3*Ua./TK))/(d.t(end) - d.t(1));
dsoc = abs(diff(d.soc));
r.efc = sum(dsoc)/2;
rate = abs(gradient(d.soc, d.t/3600));                     % |dSOC/dt|, 1/h
rate(rate < 0.01) = 0;
r.crate = trapz(d.t/86400, rate)/dtd;
if isnan(r.crate), r.crate = 0; end
dod = max(d.soc) - min(d.soc);
fT_t = exp(L.p7./TK) + exp(-L.p8./TK);
% Cycle-rate temperature weighted by charge throughput, so parked hours don't dilute it (BLAST averages over time
% within a step; with 1-day steps that mixes cycling and parking temperatures). Time average if nothing moves.
if any(rate > 0), r.fT = trapz(d.t, fT_t.*rate)/trapz(d.t, rate);
else, r.fT = trapz(d.t, fT_t)/(d.t(end) - d.t(1)); end
r.kcyc_noC = (L.p4 + L.p5*dod)*r.fT;
end

function dy = pstate(y0, dx, k, p)
% BLAST _update_power_state: y = k x^p integrated with a changing k
if dx == 0, dy = 0; return; end
if y0 == 0
    dy = k*dx^p;
else
    dy = k*p*(y0/k)^((p - 1)/p)*dx;
end
end

function Ua = graphite_Ua(soc)
% Safari & Delacourt, J. Electrochem. Soc. 158(5) A562 (2011), via BLAST-Lite _get_Ua
x = 0.0085 + soc*(0.78 - 0.0085);
Ua = 0.6379 + 0.5416*exp(-305.5309*x) + 0.044*tanh(-(x - 0.1958)/0.1088) - 0.1978*tanh((x - 1.0571)/0.0854) ...
    - 0.6875*tanh((x + 0.0117)/0.0529) - 0.0175*tanh((x - 0.5692)/0.0875);
end

function y = cross_year(yrs, q, lvl)
k = find(q <= lvl, 1);
if isempty(k), y = Inf; else, y = yrs(k); end
end
