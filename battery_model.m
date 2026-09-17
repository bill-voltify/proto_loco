function batt = battery_model(t, P_elec, P_aux, p)
% BATTERY_MODEL  Simple Rint (internal-resistance) equivalent-circuit model.
% OCV(SOC) assumed linear between V_min/V_max — LFP actually has a flat OCV
% curve over most of SOC range; this will overstate voltage sag mid-range.
% Replace with a measured OCV-SOC lookup table as bench data becomes available.
%
% Inputs:
%   t       - time vector [s]
%   P_elec  - DC-link power demand from vehicle_dynamics [W] (+draw / -regen)
%   P_aux   - aux load [W], scalar or vector same size as t
%   p       - params struct
%
% Output struct: t, SOC, V_term, I_batt, P_batt

n = numel(t);
if isscalar(P_aux), P_aux = P_aux * ones(n,1); end

SOC   = zeros(n,1);
V_term = zeros(n,1);
I_batt = zeros(n,1);

SOC(1) = p.batt.SOC_init;
Q_As = p.batt.capacity_Ah * 3600;  % capacity in Amp-seconds

for k = 1:n
    P_batt = P_elec(k) + P_aux(k);              % total power drawn from TRB-BUS

    OCV = p.batt.V_min + (p.batt.V_max - p.batt.V_min) * SOC(k);

    % Solve V*I = P_batt with V = OCV - I*Rint  ->  Rint*I^2 - OCV*I + P_batt = 0
    a = p.batt.Rint_ohm;
    b = -OCV;
    c = P_batt;
    disc = b^2 - 4*a*c;
    disc = max(disc, 0);                         % clamp if infeasible (voltage collapse)
    I = (-b - sqrt(disc)) / (2*a);                % + root = discharge current for P>0

    I = max(min(I, p.batt.peak_discharge_A), -p.batt.peak_discharge_A); % clamp to spec limit

    V = OCV - I*p.batt.Rint_ohm;

    I_batt(k) = I;
    V_term(k) = V;

    if k < n
        dt = t(k+1) - t(k);
        SOC(k+1) = SOC(k) - (I * dt) / Q_As;
        SOC(k+1) = min(max(SOC(k+1), 0), 1);
    end
end

batt.t = t;
batt.SOC = SOC;
batt.V_term = V_term;
batt.I_batt = I_batt;
batt.P_batt = I_batt .* V_term;

end
