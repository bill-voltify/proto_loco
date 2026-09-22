%% RUN_BUILD_SIMSCAPE  Sets up the From Workspace input, then builds the model
clear; clc;

[t, v_mph] = duty_cycle_example();
duty_cycle_ts = [t, v_mph];   %#ok<NASGU>  % From Workspace expects [time, data] or timeseries

build_voltify_simscape_model();

fprintf('\nOpen voltify_simscape_model.slx, resolve any [MANUAL WIRE NEEDED] lines above, then Run.\n');
