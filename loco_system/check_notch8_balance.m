function T = check_notch8_balance(trailing_tons, grade_pct, cap_kW)
% CHECK_NOTCH8_BALANCE  Steady balancing speed vs. traction power, from the vehicle.ssc force model.
%   T = check_notch8_balance(3640, 0.5)            % S6 load at 536 and 373 kW/motor
%   T = check_notch8_balance(3640, 0.5, [536 373 560])
if nargin < 1 || isempty(trailing_tons), trailing_tons = 3640; end
if nargin < 2 || isempty(grade_pct), grade_pct = 0.5; end
if nargin < 3 || isempty(cap_kW), cap_kW = [536 373]; end
P = loco_system_params();
g = 9.81; m = P.veh.m_loco + trailing_tons*907.185;
F = @(v) m*g*(grade_pct/100 + P.veh.Crr) + 0.5*1.225*P.veh.CdA*v.^2;
v_mph = zeros(numel(cap_kW), 1);
for k = 1:numel(cap_kW)
    Pw = 4*cap_kW(k)*1e3;
    v_mph(k) = fzero(@(v) F(v).*v - Pw, [0.1 60])/0.44704;
end
v30 = 30*0.44704;
P30_MW = F(v30)*v30/1e6;
T = table(cap_kW(:), 4*cap_kW(:)/1e3, v_mph, repmat(P30_MW, numel(cap_kW), 1), ...
    'VariableNames', {'cap_kW_per_motor','P_trac_MW','balance_mph','P_needed_30mph_MW'});
disp(T);
end
