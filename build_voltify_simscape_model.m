function build_voltify_simscape_model()
% BUILD_VOLTIFY_SIMSCAPE_MODEL
% Programmatically constructs a Simulink model with a real Simscape
% physical-network battery (not a scalar equation) driven by a duty-cycle
% -> vehicle-dynamics signal chain.
%
% RISK NOTE: Physical (PS) port wiring via add_line is the one part of this
% script most likely to need adjustment for R2026a — Foundation library
% block paths ('fl_lib/...') have been stable for many releases, but if
% add_line throws on a physical connection, the try/catch below prints the
% two block names that need manual wiring so you can draw that one line
% by hand in the canvas instead of debugging the script blind.
%
% Run this in MATLAB (not this container) — it builds and opens the model.

p = voltify_gp40_params();

mdl = 'voltify_simscape_model';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl);
open_system(mdl);

%% --- Layout helper ---
xs = 30; ys = 30; dx = 140; dy = 100;
pos = @(col,row,w,h) [xs+col*dx, ys+row*dy, xs+col*dx+w, ys+row*dy+h];

%% --- Signal domain: duty cycle input ---
add_block('simulink/Sources/From Workspace', [mdl '/DutyCycle_v_mph'], ...
    'Position', pos(0,0,80,40), 'VariableName', 'duty_cycle_ts');

%% --- Vehicle dynamics (MATLAB Function block, algebraic, stateless) ---
vd_path = [mdl '/VehicleDynamics'];
add_block('simulink/User-Defined Functions/MATLAB Function', vd_path, ...
    'Position', pos(1,0,120,60));

vd_code = sprintf([...
    'function [P_elec, T_wheel] = vehicle_dynamics_fcn(v_mph, accel)\n' ...
    '%%#codegen\n' ...
    'mass = %.4f; g = 9.81; Crr = %.5f; Cd = %.3f; A = %.3f; rho = 1.225;\n' ...
    'r_wheel = %.5f; gear_ratio = %.4f; eta_m = %.4f; eta_r = %.4f;\n' ...
    'v = v_mph * 0.44704;\n' ...
    'F_roll = sign(v) * mass * g * Crr;\n' ...
    'F_aero = 0.5 * rho * Cd * A * v * abs(v);\n' ...
    'F_acc  = mass * accel;\n' ...
    'F_trac = F_acc + F_roll + F_aero;\n' ...
    'T_wheel = F_trac * r_wheel;\n' ...
    'P_mech = F_trac * v;\n' ...
    'if P_mech >= 0\n' ...
    '    P_elec = P_mech / eta_m;\n' ...
    'else\n' ...
    '    P_elec = P_mech * eta_r;\n' ...
    'end\n' ...
    'end'], p.mass_kg, p.Crr, p.Cd, p.frontal_area_m2, ...
    p.wheel_radius_m, p.gear_ratio, p.eta_motoring, p.eta_regen);

try
    rt = sfroot;
    ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', vd_path);
    ch.Script = vd_code;
catch ME
    warning('Could not auto-populate MATLAB Function block script: %s\nOpen %s and paste the code manually (see vd_code in workspace).', ME.message, vd_path);
    assignin('base', 'vd_code_manual_paste', vd_code);
end

add_block('simulink/Continuous/Derivative', [mdl '/dv_dt'], 'Position', pos(0,2,60,30));

%% --- SOC integration & OCV lookup (signal domain) ---
add_block('simulink/Math Operations/Gain', [mdl '/InvCapacity'], ...
    'Position', pos(4,2,60,30), 'Gain', num2str(-1/(p.batt.capacity_Ah*3600)));
add_block('simulink/Continuous/Integrator', [mdl '/SOC_Integrator'], ...
    'Position', pos(5,2,60,30), 'InitialCondition', num2str(p.batt.SOC_init));
add_block('simulink/Discontinuities/Saturation', [mdl '/SOC_Clamp'], ...
    'Position', pos(6,2,60,30), 'UpperLimit', '1', 'LowerLimit', '0');

ocv_path = [mdl '/OCV_lookup'];
add_block('simulink/User-Defined Functions/MATLAB Function', ocv_path, 'Position', pos(6,0,100,40));
ocv_code = sprintf([...
    'function OCV = ocv_fcn(SOC)\n%%#codegen\n' ...
    'Vmin = %.2f; Vmax = %.2f;\n' ...
    'OCV = Vmin + (Vmax-Vmin)*SOC; %% linear placeholder -- replace with LFP lookup table\n' ...
    'end'], p.batt.V_min, p.batt.V_max);
try
    ch2 = sfroot; ch2 = ch2.find('-isa','Stateflow.EMChart','Path',ocv_path);
    ch2.Script = ocv_code;
catch ME
    warning('Could not auto-populate OCV block: %s', ME.message);
    assignin('base','ocv_code_manual_paste', ocv_code);
end

%% --- Power-to-current command (P/V feedback) ---
add_block('simulink/Math Operations/Divide', [mdl '/P_to_I_cmd'], 'Position', pos(3,1,60,30));

%% --- PS converters (bridge signal <-> physical domain) ---
add_block('nesl_utility/Simulink-PS Converter', [mdl '/SimToPS_OCV'], 'Position', pos(7,0,60,30));
add_block('nesl_utility/Simulink-PS Converter', [mdl '/SimToPS_Icmd'], 'Position', pos(4,1,60,30));
add_block('nesl_utility/PS-Simulink Converter', [mdl '/PSToSim_V'],   'Position', pos(9,1,60,30));
add_block('nesl_utility/PS-Simulink Converter', [mdl '/PSToSim_I'],   'Position', pos(9,2,60,30));

%% --- Physical Simscape network: battery equivalent circuit ---
add_block('nesl_utility/Solver Configuration', [mdl '/SolverConfig'], 'Position', pos(8,3,60,30));
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', [mdl '/Ground'], 'Position', pos(8,4,40,30));
add_block('fl_lib/Electrical/Electrical Sources/Controlled Voltage Source', [mdl '/OCV_Source'], 'Position', pos(8,1,50,50));
add_block('fl_lib/Electrical/Electrical Elements/Resistor', [mdl '/Rint'], 'Position', pos(9,1,50,50));
set_param([mdl '/Rint'], 'R', num2str(p.batt.Rint_ohm));
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', [mdl '/V_sensor'], 'Position', pos(10,1,50,50));
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', [mdl '/I_sensor'], 'Position', pos(9,2,50,50));
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', [mdl '/Load_Isink'], 'Position', pos(8,2,50,50));

%% --- Scopes / logging ---
add_block('simulink/Sinks/Scope', [mdl '/Scope_SOC'], 'Position', pos(7,2,40,30));
add_block('simulink/Sinks/Scope', [mdl '/Scope_V'], 'Position', pos(11,1,40,30));
add_block('simulink/Sinks/Scope', [mdl '/Scope_I'], 'Position', pos(9,3,40,30));

%% --- Signal-domain wiring (Inport/Outport — reliable across all releases) ---
add_line(mdl, 'DutyCycle_v_mph/1', 'VehicleDynamics/1');
add_line(mdl, 'DutyCycle_v_mph/1', 'dv_dt/1');
add_line(mdl, 'dv_dt/1', 'VehicleDynamics/2');
add_line(mdl, 'VehicleDynamics/1', 'P_to_I_cmd/1');   % P_elec -> numerator
add_line(mdl, 'PSToSim_V/1', 'P_to_I_cmd/2');          % V_meas -> denominator
add_line(mdl, 'P_to_I_cmd/1', 'SimToPS_Icmd/1');

connect_phys(mdl, 'I_sensor', [], 1, 'PSToSim_I', 'Inport', 1);  % physical measurement out -> converter in
add_line(mdl, 'PSToSim_I/1', 'InvCapacity/1');          % battery current (now a real Simulink signal) -> SOC derivative
add_line(mdl, 'InvCapacity/1', 'SOC_Integrator/1');
add_line(mdl, 'SOC_Integrator/1', 'SOC_Clamp/1');
add_line(mdl, 'SOC_Clamp/1', 'OCV_lookup/1');
add_line(mdl, 'SOC_Clamp/1', 'Scope_SOC/1');
add_line(mdl, 'OCV_lookup/1', 'SimToPS_OCV/1');

%% --- Physical-domain wiring (Simscape conserving ports) ---
% This section is the highest-risk part of the script. Each connection is
% wrapped so a failure names the two blocks to connect manually instead of
% aborting the whole build.
% Confirmed port map (from get_param diagnostics):
%   Rint, Ground:            LConn(1) / RConn(1) — pure electrical, no bundling
%   I_sensor, V_sensor:      LConn(1) electrical; RConn(1)=electrical, RConn(2)=PS measurement out
%   OCV_Source, Load_Isink:  LConn(1) electrical; RConn(1)=electrical, RConn(2)=PS control in
%   SimToPS_* (Simulink->PS):Inport(1)=Simulink in; RConn(1)=PS out
%   SolverConfig:            RConn(1) only, attaches to any network node

% Electrical loop: source -> Rint -> node B -> {V_sensor shunt to ground, I_sensor series -> load -> ground}
connect_phys(mdl, 'OCV_Source', 'LConn', 1, 'Ground', 'LConn', 1);
connect_phys(mdl, 'OCV_Source', 'RConn', 1, 'Rint', 'LConn', 1);
connect_phys(mdl, 'Rint', 'RConn', 1, 'V_sensor', 'LConn', 1);
connect_phys(mdl, 'Rint', 'RConn', 1, 'I_sensor', 'LConn', 1);
connect_phys(mdl, 'V_sensor', 'RConn', 1, 'Ground', 'LConn', 1);
connect_phys(mdl, 'I_sensor', 'RConn', 1, 'Load_Isink', 'LConn', 1);
connect_phys(mdl, 'Load_Isink', 'RConn', 1, 'Ground', 'LConn', 1);
connect_phys(mdl, 'SolverConfig', 'RConn', 1, 'Ground', 'LConn', 1);

% Control/measurement physical-signal ports (index 2 of the bundled RConn array)
connect_phys(mdl, 'SimToPS_OCV', 'RConn', 1, 'OCV_Source', 'RConn', 2);   % commanded OCV -> source control
connect_phys(mdl, 'SimToPS_Icmd', 'RConn', 1, 'Load_Isink', 'RConn', 2);  % commanded current -> load control
connect_phys(mdl, 'I_sensor', 'RConn', 2, 'PSToSim_I', 'RConn', 1);       % measured current out
connect_phys(mdl, 'V_sensor', 'RConn', 2, 'PSToSim_V', 'RConn', 1);       % measured voltage out

add_line(mdl, 'PSToSim_V/1', 'Scope_V/1');
add_line(mdl, 'PSToSim_I/1', 'Scope_I/1');

save_system(mdl);
fprintf('Model saved: %s.slx\nCheck Command Window above for any manual-wiring notes.\n', mdl);

end

function connect_phys(mdl, blkA, portFieldA, portIdxA, blkB, portFieldB, portIdxB)
% Attempts a physical-port connection; on failure, prints the two blocks
% to wire by hand instead of stopping the build.
try
    phA = get_param([mdl '/' blkA], 'PortHandles');
    phB = get_param([mdl '/' blkB], 'PortHandles');
    if isempty(portFieldA)
        hA = phA.Outport(portIdxA);   % control signal outport (e.g. Simulink-PS converter output is physical, handled elsewhere)
    else
        hA = phA.(portFieldA)(portIdxA);
    end
    hB = phB.(portFieldB)(portIdxB);
    add_line(mdl, hA, hB);
catch ME
    fprintf(2, '[MANUAL WIRE NEEDED] %s <-> %s  (%s)\n', blkA, blkB, ME.message);
end
end
