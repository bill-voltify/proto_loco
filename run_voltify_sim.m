%% RUN_VOLTIFY_SIM  Top-level: duty cycle -> loads -> battery response
clear; clc;

p = voltify_gp40_params();

[t, v_mph] = duty_cycle_example();   % swap for real duty cycle import

veh = vehicle_dynamics(t, v_mph, p);

P_aux = p.aux.standby_idle_W;        % swap for state-based aux profile if desired
batt = battery_model(t, veh.P_elec, P_aux, p);

%% Plots
figure('Name','Voltify Proto Switcher - Duty Cycle Sim');

subplot(4,1,1);
plot(t, v_mph); ylabel('Speed [mph]'); grid on; title('Duty Cycle');

subplot(4,1,2);
plot(t, veh.T_wheel_total/1000); ylabel('Wheel Torque [kN·m]'); grid on;

subplot(4,1,3);
plot(t, veh.P_elec/1e3); ylabel('DC-Link Power [kW]'); grid on;

subplot(4,1,4);
yyaxis left; plot(t, batt.SOC*100); ylabel('SOC [%]');
yyaxis right; plot(t, batt.V_term); ylabel('Terminal V');
xlabel('Time [s]'); grid on;

fprintf('Peak wheel torque:   %.1f kN*m\n', max(abs(veh.T_wheel_total))/1000);
fprintf('Peak motor torque:   %.1f N*m per motor\n', max(abs(veh.T_motor)));
fprintf('Peak DC-link power:  %.1f kW\n', max(veh.P_elec)/1000);
fprintf('Peak battery current:%.1f A (spec limit %.0f A)\n', max(abs(batt.I_batt)), p.batt.peak_discharge_A);
fprintf('SOC drop over cycle: %.3f %%\n', (batt.SOC(1)-batt.SOC(end))*100);
