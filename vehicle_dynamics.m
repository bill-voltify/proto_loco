function out = vehicle_dynamics(t, v_mph, p)
% VEHICLE_DYNAMICS  Convert speed(t) duty cycle to tractive force, wheel/motor
% torque, and DC-link electrical power demand.
%
% Inputs:
%   t      - time vector [s]
%   v_mph  - speed vector [mph], signed (reverse = negative)
%   p      - params struct from voltify_gp40_params()
%
% Output struct fields: t, v_mps, accel, F_trac, T_wheel_total, T_wheel_per_motor,
%                        omega_wheel, T_motor, omega_motor, P_mech, P_elec

v_mps = v_mph * 0.44704;
accel = gradient(v_mps, t);                      % m/s^2

F_roll  = sign(v_mps) .* p.mass_kg * p.g * p.Crr;
F_roll(v_mps==0) = 0;
F_grade = p.mass_kg * p.g * sin(atan(p.grade_pct/100));
F_aero  = 0.5 * p.rho_air * p.Cd * p.frontal_area_m2 .* v_mps.^2 .* sign(v_mps);
F_accel = p.mass_kg .* accel;

F_trac = F_accel + F_roll + F_grade + F_aero;    % N, total tractive effort at rail

T_wheel_total = F_trac * p.wheel_radius_m;        % N*m, summed across all motors
omega_wheel   = v_mps / p.wheel_radius_m;         % rad/s

T_wheel_per_motor = T_wheel_total / p.n_motors;
T_motor = T_wheel_per_motor / p.gear_ratio;        % N*m at motor shaft
omega_motor = omega_wheel * p.gear_ratio;          % rad/s

P_mech = F_trac .* v_mps;                          % W, mechanical power at rail (signed)

P_elec = zeros(size(P_mech));
motoring = P_mech >= 0;
if p.regen_enabled
    P_elec(motoring)  = P_mech(motoring)  / p.eta_motoring;
    P_elec(~motoring) = P_mech(~motoring) * p.eta_regen;   % negative = power returned to DC-link
else
    P_elec(motoring)  = P_mech(motoring)  / p.eta_motoring;
    P_elec(~motoring) = 0;                                  % dynamic brake / no regen credit
end

out.t = t;
out.v_mps = v_mps;
out.accel = accel;
out.F_trac = F_trac;
out.T_wheel_total = T_wheel_total;
out.T_wheel_per_motor = T_wheel_per_motor;
out.omega_wheel = omega_wheel;
out.T_motor = T_motor;
out.omega_motor = omega_motor;
out.P_mech = P_mech;
out.P_elec = P_elec;   % +ve = drawn from DC-link, -ve = regen returned to DC-link

end
