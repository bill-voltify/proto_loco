function mdl = build_loco_system()
% BUILD_LOCO_SYSTEM  Build voltify_loco_system.slx (Phase 3) from +locosys.
% Top level: Scenario | Fault Injection | Controls (State Manager, Command Arbiter, Power Budget)
%            | Plant (Simscape: battery, DC link, 4 axles, vehicle, aux, charger, thermal) | Dashboard
here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));
mdl = 'voltify_loco_system';
if bdIsLoaded(mdl), close_system(mdl, 0); end
f = fullfile(here, [mdl '.slx']);
if exist(f, 'file'), delete(f); end

P = loco_system_params();
TR = load_trace(fullfile(here, 'traces', 'S2_showcase1.csv'));
FLT = build_fault_matrix(load_fault_table(fullfile(here, 'faults', 'none.csv')), TR.t_end, P);
B = load_budget_table(fullfile(here, 'load_budget.csv'));
assignin('base', 'P', P);
assignin('base', 'SCN', TR.SCN);
assignin('base', 'SCN_D', TR.SCN_D);
assignin('base', 'FLT', FLT);
assignin('base', 'LB', B.LB);
assignin('base', 'LBmov', B.LBmov);
assignin('base', 'LBbus', B.LBbus);
assignin('base', 'LBeff', B.LBeff);

new_system(mdl);
open_system(mdl);
load_system('sflib');

% ---------------- Scenario ----------------
s = [mdl '/Scenario'];
add_block('built-in/Subsystem', s, 'Position', [40 60 200 260], 'BackgroundColor', 'lightBlue');
add_block('simulink/Sources/From Workspace', [s '/Trace'], 'VariableName', 'SCN', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', [40 60 140 100]);
add_block('simulink/Signal Routing/Demux', [s '/Demux'], 'Outputs', '6', 'Position', [200 40 205 220]);
add_block('simulink/Sources/From Workspace', [s '/State request'], 'VariableName', 'SCN_D', 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', [40 260 140 300]);
outs = {'speed_ref_mph','grade_pct','ambient_C','trailing_tons','wire_kW','aux_override_kW','state_req'};
for k = 1:numel(outs)
    add_block('built-in/Outport', [s '/' outs{k}], 'Position', [320 30+40*k 350 44+40*k]);
end
add_line(s, 'Trace/1', 'Demux/1');
for k = 1:6, add_line(s, sprintf('Demux/%d', k), sprintf('%s/1', outs{k})); end
add_line(s, 'State request/1', 'state_req/1');

% ---------------- Fault Injection ----------------
s = [mdl '/Fault Injection'];
add_block('built-in/Subsystem', s, 'Position', [40 320 200 400], 'BackgroundColor', 'orange');
add_block('simulink/Sources/From Workspace', [s '/Fault table'], 'VariableName', 'FLT', 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', [40 40 140 80]);
add_block('built-in/Outport', [s '/faults'], 'Position', [220 50 250 64]);
add_line(s, 'Fault table/1', 'faults/1');
add_note(s, sprintf('Fault channels (vector of 14):\nn_mtm fan_pe fan_cd pump_pe pump_bat n_ax_on n_str\ndT_sense_K blower_ok comms_ok aux_ok chg_derate estop classA\nSource: faults/*.csv via build_fault_matrix'), [40 120]);

% ---------------- Controls ----------------
s = [mdl '/Controls'];
add_block('built-in/Subsystem', s, 'Position', [300 60 480 400], 'BackgroundColor', 'lightBlue');
ins = {'speed_ref_mph','state_req','wire_kW','aux_override_kW','faults'};
for k = 1:numel(ins)
    add_block('built-in/Inport', [s '/' ins{k}], 'Position', [20 40+60*k 50 54+60*k]);
end
build_state_chart([s '/State Manager'], P.sys.Ts_ctrl, [140 60 300 200]);
add_ml_fcn([s '/Command Arbiter'], arbiter_code(), {}, [380 60 540 200]);
add_ml_fcn([s '/Power Budget'], budget_code(), {'LB','LBmov','LBbus','LBeff'}, [380 260 540 380]);
add_block('simulink/Signal Routing/Mux', [s '/cmd mux'], 'Inputs', '6', 'Position', [620 60 625 260]);
add_block('built-in/Outport', [s '/cmd'], 'Position', [680 150 710 164]);
add_block('built-in/Outport', [s '/p_load'], 'Position', [680 300 710 314]);
add_block('built-in/Outport', [s '/p_bus'], 'Position', [680 340 710 354]);
add_line(s, 'state_req/1', 'State Manager/1');
add_line(s, 'faults/1', 'State Manager/2');
for k = 1:4, add_line(s, sprintf('State Manager/%d', k + 1), sprintf('Command Arbiter/%d', k)); end
add_line(s, 'wire_kW/1', 'Command Arbiter/5');
add_line(s, 'faults/1', 'Command Arbiter/6');
add_line(s, 'State Manager/1', 'Power Budget/1');
add_line(s, 'speed_ref_mph/1', 'Power Budget/2');
add_line(s, 'faults/1', 'Power Budget/3');
add_line(s, 'aux_override_kW/1', 'Power Budget/4');
add_line(s, 'State Manager/1', 'cmd mux/1');
for k = 1:3, add_line(s, sprintf('Command Arbiter/%d', k), sprintf('cmd mux/%d', k + 1)); end
add_line(s, 'Power Budget/1', 'cmd mux/5');
add_line(s, 'Command Arbiter/4', 'cmd mux/6');
add_line(s, 'cmd mux/1', 'cmd/1');
add_line(s, 'Power Budget/2', 'p_load/1');
add_line(s, 'Power Budget/3', 'p_bus/1');

% ---------------- Plant ----------------
s = [mdl '/Plant'];
add_block('built-in/Subsystem', s, 'Position', [580 60 760 400], 'BackgroundColor', 'green');
ins = {'speed_ref_mph','grade_pct','ambient_C','trailing_tons','cmd','faults'};
for k = 1:numel(ins)
    add_block('built-in/Inport', [s '/' ins{k}], 'Position', [20 40+50*k 50 54+50*k]);
end
add_ml_fcn([s '/Plant Inputs'], plant_inputs_code(), {}, [120 60 260 360]);
add_lib([s '/S2PS'], {sprintf('nesl_utility/Simulink-PS\nConverter'), 'nesl_utility/Simulink-PS Converter'}, [320 195 350 225]);
add_lib([s '/Locomotive'], {'nesl_utility/Simscape Component', sprintf('nesl_utility/Simscape\nComponent')}, [400 140 580 280]);
add_lib([s '/PS2S'], {sprintf('nesl_utility/PS-Simulink\nConverter'), 'nesl_utility/PS-Simulink Converter'}, [640 195 670 225]);
add_lib([s '/Solver'], {sprintf('nesl_utility/Solver\nConfiguration'), 'nesl_utility/Solver Configuration'}, [440 330 500 360]);
add_block('built-in/Outport', [s '/y'], 'Position', [720 203 750 217]);
blk = [s '/Locomotive'];
try
    simscape.setBlockComponent(blk, 'locosys.locomotive_sys');
catch
    set_param(blk, 'ComponentPath', 'locosys.locomotive_sys');
end
map = param_map(P);
for k = 1:size(map, 1)
    try
        set_param(blk, map{k,1}, map{k,2});
    catch ME
        warning('param %s not set: %s', map{k,1}, ME.message);
    end
end
for k = 1:numel(ins), add_line(s, sprintf('%s/1', ins{k}), sprintf('Plant Inputs/%d', k)); end
add_line(s, 'Plant Inputs/1', 'S2PS/1');
phS = get_param([s '/S2PS'], 'PortHandles');
phP = get_param([s '/PS2S'], 'PortHandles');
phV = get_param([s '/Solver'], 'PortHandles');
[hU, hY, hREF] = loco_ports(blk);
add_line(s, phS.RConn(1), hU);
add_line(s, hY, phP.LConn(1));
add_line(s, phV.RConn(1), hREF);
add_line(s, 'PS2S/1', 'y/1');

% ---------------- Dashboard ----------------
s = [mdl '/Dashboard'];
add_block('built-in/Subsystem', s, 'Position', [860 60 1020 400], 'BackgroundColor', 'yellow');
ins = {'y','cmd','p_load','p_bus'};
for k = 1:numel(ins)
    add_block('built-in/Inport', [s '/' ins{k}], 'Position', [20 40+80*k 50 54+80*k]);
end
tw = {'Y','SYS','LOADS','BUSES'};
for k = 1:4
    add_block('simulink/Sinks/To Workspace', [s '/' tw{k}], 'VariableName', tw{k}, 'SaveFormat', 'Timeseries', ...
        'Position', [460 30+80*k 540 60+80*k]);
    add_line(s, sprintf('%s/1', ins{k}), sprintf('%s/1', tw{k}));
end
add_scope(s, 'Speed (mph)', 'y', '[1]', 0, [160 20 200 50], [260 20 290 50]);
add_scope(s, 'SOC', 'y', '[2]', 0, [160 70 200 100], [260 70 290 100]);
add_scope(s, 'Temperatures (C): cell, PE supply, charger, inverter, condenser, motor', 'y', '[13 17 18 20 16 21]', -273.15, [160 300 200 330], [260 300 290 330]);
add_scope(s, 'State and commands: st hv tms trac', 'cmd', '[1 2 3 4]', 0, [160 380 200 410], [260 380 290 410]);
add_scope(s, 'Power (kW): aux budget, charge cmd', 'cmd', '[5 6]', 0, [160 440 200 470], [260 440 290 470], 1e-3);

% ---------------- top-level wiring ----------------
add_line(mdl, 'Scenario/1', 'Controls/1');
add_line(mdl, 'Scenario/7', 'Controls/2');
add_line(mdl, 'Scenario/5', 'Controls/3');
add_line(mdl, 'Scenario/6', 'Controls/4');
add_line(mdl, 'Fault Injection/1', 'Controls/5');
add_line(mdl, 'Scenario/1', 'Plant/1');
add_line(mdl, 'Scenario/2', 'Plant/2');
add_line(mdl, 'Scenario/3', 'Plant/3');
add_line(mdl, 'Scenario/4', 'Plant/4');
add_line(mdl, 'Controls/1', 'Plant/5');
add_line(mdl, 'Fault Injection/1', 'Plant/6');
add_line(mdl, 'Plant/1', 'Dashboard/1');
add_line(mdl, 'Controls/1', 'Dashboard/2');
add_line(mdl, 'Controls/2', 'Dashboard/3');
add_line(mdl, 'Controls/3', 'Dashboard/4');
add_note(mdl, sprintf('Voltify GP40-V locomotive system model (Phase 3)\nInputs: traces/*.csv | faults/*.csv | load_budget.csv\nRun: run_loco_system(trace, ''Faults'', file)'), [40 460]);

set_param(mdl, 'StopTime', num2str(TR.t_end), 'MaxStep', num2str(P.sys.max_step), 'RelTol', '1e-4');
set_param(mdl, 'ZeroCrossControl', 'DisableAll');
try
    set_param(mdl, 'Solver', 'daessc');
catch
    set_param(mdl, 'Solver', 'ode23t');
end
set_param(mdl, 'SimscapeLogType', 'none');
save_system(mdl, f);
end

% =====================================================================
function build_state_chart(path, Ts, pos)
add_block('sflib/Chart', path, 'Position', pos);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.Chart', 'Path', path);
ch.ActionLanguage = 'MATLAB';
ch.ChartUpdate = 'DISCRETE';
ch.SampleTime = num2str(Ts);
add_data(ch, 'req', 'Input', '-1');
add_data(ch, 'flt', 'Input', '-1');
outs = {'st','hv','tms','trac','chg'};
for k = 1:numel(outs), add_data(ch, outs{k}, 'Output', '1'); end
names = {'SLEEP','STANDBY','READY','TRACTION','CHARGING','FAULT','ESTOP'};
o = [0 0 0 0; 1 1 0 0; 1 1 1 0; 1 1 1 0; 1 1 1 1; 1 1 0 0; 0 0 0 0];
xy = [60 60; 300 60; 540 60; 780 60; 780 300; 420 300; 60 300];
S = cell(1, 7);
for k = 1:7
    st = Stateflow.State(ch);
    st.LabelString = sprintf('%s\nentry:\nst=%d; hv=%d; tms=%d; trac=%d; chg=%d;', names{k}, k - 1, o(k,1), o(k,2), o(k,3), o(k,4));
    st.Position = [xy(k,:) 180 100];
    S{k} = st;
end
t0 = Stateflow.Transition(ch);
t0.Destination = S{1};
t0.DestinationOClock = 0;
t0.SourceEndpoint = t0.DestinationEndpoint - [0 30];
t0.Midpoint = t0.DestinationEndpoint - [0 15];
estop = '[flt(13) > 0.5]';
faultA = '[flt(14) > 0.5 || flt(10) < 0.5]';
for k = 1:6, add_tr(ch, S{k}, S{7}, estop); end
for k = 2:5, add_tr(ch, S{k}, S{6}, faultA); end
add_tr(ch, S{1}, S{2}, '[req >= 1]');
add_tr(ch, S{2}, S{3}, '[req >= 2]');
add_tr(ch, S{2}, S{1}, '[req < 0.5]');
add_tr(ch, S{3}, S{4}, '[req == 3]');
add_tr(ch, S{3}, S{5}, '[req == 4]');
add_tr(ch, S{3}, S{2}, '[req <= 1]');
add_tr(ch, S{4}, S{5}, '[req == 4]');
add_tr(ch, S{4}, S{3}, '[req <= 2]');
add_tr(ch, S{5}, S{4}, '[req == 3]');
add_tr(ch, S{5}, S{3}, '[req <= 2]');
add_tr(ch, S{6}, S{3}, '[flt(14) < 0.5 && flt(10) > 0.5 && req >= 2]');
add_tr(ch, S{6}, S{2}, '[flt(14) < 0.5 && flt(10) > 0.5 && req < 2]');
add_tr(ch, S{7}, S{1}, '[flt(13) < 0.5]');
end

function add_data(ch, name, scope, sz)
d = Stateflow.Data(ch);
d.Name = name;
d.Scope = scope;
d.DataType = 'double';
d.Props.Array.Size = sz;
end

function add_tr(ch, a, b, label)
t = Stateflow.Transition(ch);
t.Source = a;
t.Destination = b;
t.LabelString = label;
end

function add_ml_fcn(path, code, params, pos)
add_block('simulink/User-Defined Functions/MATLAB Function', path, 'Position', pos);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', path);
ch.Script = code;
for k = 1:numel(params)
    d = ch.find('-isa', 'Stateflow.Data', 'Name', params{k});
    d.Scope = 'Parameter';
    d.Tunable = false;
end
end

function add_scope(s, name, src, idx, bias, posSel, posScope, gain)
if nargin < 8, gain = 1; end
sel = [s '/sel ' name];
add_block('simulink/Signal Routing/Selector', sel, 'IndexOptions', 'Index vector (dialog)', 'Indices', idx, ...
    'InputPortWidth', '-1', 'Position', posSel);
add_line(s, [src '/1'], ['sel ' name '/1'], 'autorouting', 'on');
last = ['sel ' name];
if gain ~= 1
    add_block('simulink/Math Operations/Gain', [s '/gain ' name], 'Gain', num2str(gain), 'Position', posSel + [50 0 50 0]);
    add_line(s, [last '/1'], ['gain ' name '/1']);
    last = ['gain ' name];
end
if bias ~= 0
    add_block('simulink/Math Operations/Bias', [s '/bias ' name], 'Bias', num2str(bias), 'Position', posSel + [50 0 50 0]);
    add_line(s, [last '/1'], ['bias ' name '/1']);
    last = ['bias ' name];
end
add_block('simulink/Sinks/Scope', [s '/' name], 'Position', posScope + [120 0 120 0]);
add_line(s, [last '/1'], [name '/1']);
end

function add_note(sys, txt, xy)
try
    a = Simulink.Annotation(sys, txt);
    a.Position = [xy, xy + [420 60]];
catch
end
end

function add_lib(dst, candidates, pos)
for k = 1:numel(candidates)
    try
        add_block(candidates{k}, dst, 'Position', pos);
        return
    catch
    end
end
error('Library block not found for %s', dst);
end

function [hL, hR, hB] = loco_ports(blk)
ph = get_param(blk, 'PortHandles');
h = [ph.LConn(:); ph.RConn(:)];
assert(numel(h) == 3, 'Expected 3 physical ports on %s, found %d', blk, numel(h));
pos = cell2mat(arrayfun(@(x) get_param(x, 'Position'), h, 'UniformOutput', false));
[~, iB] = max(pos(:,2));
hB = h(iB);
r = setdiff(1:3, iB);
[~, a] = min(pos(r,1));
[~, b] = max(pos(r,1));
hL = h(r(a));
hR = h(r(b));
end

function map = param_map(P)
map = {
    'Ns','P.batt.Ns'; 'Np','P.batt.Np'; 'Q_cell','P.batt.Q_cell'; 'R0_cell','P.batt.R0_cell';
    'R1_cell','P.batt.R1_cell'; 'tau1','P.batt.tau1'; 'R_bus','P.batt.R_bus'; 'soc0','P.batt.soc0';
    'SOC_tab','P.batt.SOC_tab'; 'OCV_tab','P.batt.OCV_tab'; 'B_R','P.batt.B_R'; 'T_ref','P.batt.T_ref';
    'R_pre','P.dcl.R_pre'; 'C_link','P.dcl.C_link'; 'k_close','P.dcl.k_close';
    'G_ratio','P.ax.G'; 'r_w','P.ax.r_w'; 'eta_g','P.ax.eta_g'; 'R_m','P.ax.R_m'; 'L_a','P.ax.L_a';
    'Kphi_sat','P.ax.Kphi_sat'; 'I0','P.ax.I0'; 'If_min','P.ax.If_min'; 'I_max','P.ax.I_max';
    'V_mot_max','P.ax.V_mot_max'; 'P_ax_max','P.ax.P_ax_max'; 'Kp_i','P.ax.Kp_i';
    'a_loss','P.ax.a_loss'; 'b_loss','P.ax.b_loss'; 'I_tab','P.ax.I_tab'; 'T_tab','P.ax.T_tab';
    'm_loco','P.veh.m_loco'; 'k_rot_loco','P.veh.k_rot_loco'; 'k_rot_trail','P.veh.k_rot_trail';
    'Crr','P.veh.Crr'; 'CdA','P.veh.CdA';
    'eta_aux','P.aux.eta'; 'P_aux_max','P.aux.P_max';
    'P_chg_max','P.chg.P_max'; 'I_chg_hw','P.chg.I_hw'; 'I_chg_bms','P.chg.I_bms'; 'soc_max','P.chg.soc_max'; 'soc_band','P.chg.soc_band';
    'wn_v','P.sys.wn_v'; 'zeta_v','P.sys.zeta_v'; 'mu_adh','P.lcc.mu_adh'; 'P_trac_max','P.lcc.P_trac_max';
    'I_dis_max','P.lcc.I_dis_max'; 'I_chg_max','P.lcc.I_chg_max'; 'eta_drv','P.lcc.eta_drv'};
thf = fieldnames(P.th);
map = [map; [strcat('th_', thf), strcat('P.th.', thf)]];
end

% ---------------- MATLAB Function code ----------------
function c = arbiter_code()
c = sprintf([ ...
'function [hv, tms, trac, P_chg_W] = fcn(hv_s, tms_s, trac_s, chg_s, wire_kW, flt)\n' ...
'%% Command Arbiter: state-manager permissions x fault channels.\n' ...
'%% flt = [n_mtm fan_pe fan_cd pump_pe pump_bat n_ax_on n_str dT_sense_K blower_ok comms_ok aux_ok chg_derate estop classA]\n' ...
'aux_ok = flt(11);\n' ...
'comms_ok = flt(10);\n' ...
'hv = hv_s;\n' ...
'tms = tms_s*aux_ok;\n' ...
'trac = trac_s*comms_ok;\n' ...
'P_chg_W = chg_s*max(wire_kW, 0)*1e3*flt(12);\n']);
end

function c = budget_code()
c = sprintf([ ...
'function [P_aux_W, p_load, p_bus] = fcn(st, speed_ref_mph, flt, aux_override_kW, LB, LBmov, LBbus, LBeff)\n' ...
'%% Power Budget: per-load power from load_budget.csv for the current operating state.\n' ...
'%% LB: kW per load x state (SLEEP STANDBY READY TRACTION CHARGING FAULT ESTOP)\n' ...
'%% LBmov: kW added while moving in TRACTION/CHARGING. LBbus: 1=750V 2=72V 3=24V_Ctrl 4=24V_BTMS 5=12V_BTMS\n' ...
'%% LBeff: conversion efficiency 750 V bus -> load (POC Power Budget Rev B). P_aux_W is drawn at the 750 V bus.\n' ...
'%% TMS loads (chillers, heaters, HV fans, pumps) are computed in the Plant thermal model.\n' ...
'idx = min(max(round(st), 0), 6) + 1;\n' ...
'moving = double(speed_ref_mph > 0.05);\n' ...
'drive = double(idx == 4 || idx == 5);\n' ...
'p_load = (LB(:, idx) + LBmov*moving*drive)*1e3*flt(11);\n' ...
'p_bus = zeros(5, 1);\n' ...
'for k = 1:5\n' ...
'    p_bus(k) = sum(p_load .* double(LBbus == k));\n' ...
'end\n' ...
'if aux_override_kW >= 0\n' ...
'    P_aux_W = aux_override_kW*1e3;\n' ...
'else\n' ...
'    P_aux_W = sum(p_load ./ LBeff);\n' ...
'end\n']);
end

function c = plant_inputs_code()
c = sprintf([ ...
'function u = fcn(speed_ref_mph, grade_pct, ambient_C, trailing_tons, cmd, flt)\n' ...
'%% Plant Inputs: build the 18-element input vector of locosys.locomotive_sys.\n' ...
'%% cmd = [st hv tms trac P_aux_W P_chg_W]\n' ...
'u = zeros(18, 1);\n' ...
'u(1) = max(speed_ref_mph, 0);\n' ...
'u(2) = grade_pct;\n' ...
'u(3) = cmd(5);\n' ...
'u(4) = cmd(6);\n' ...
'u(5) = cmd(2);\n' ...
'u(6) = ambient_C + 273.15;\n' ...
'u(7) = max(trailing_tons, 0)*907.185;\n' ...
'u(8) = cmd(3);\n' ...
'u(9) = flt(1);\n' ...
'u(10) = flt(2);\n' ...
'u(11) = flt(3);\n' ...
'u(12) = flt(4);\n' ...
'u(13) = flt(5);\n' ...
'u(14) = flt(6);\n' ...
'u(15) = flt(7);\n' ...
'u(16) = flt(8);\n' ...
'u(17) = flt(9)*flt(11);\n' ...
'u(18) = cmd(4);\n']);
end
