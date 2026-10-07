function S = proto_scenarios()
% PROTO_SCENARIOS  Phase 2 validation scenarios (DVP/FMEA v0.4 linkage in MODEL_NOTES.md).
% Each scenario: name, desc, dvp, m_trail (kg), soc0, I_chg_bms (A), max_step (s),
% speed_check (hold speed within 1 mph), U = [t, v_ref mph, grade %, P_aux W, P_chg W, en].
% Reverse moves are modeled as repeat moves (speed magnitude only).
ST = 907.185;
A0 = 30e3;
AB = 42e3;
S = struct('name', {}, 'desc', {}, 'dvp', {}, 'm_trail', {}, 'soc0', {}, 'I_chg_bms', {}, 'max_step', {}, 'speed_check', {}, 'U', {});

S(end+1) = mk('S1_first_move', 'Huntington first move fwd/rev, light engine, 3 mph', 'H-12/H-13', 0, 0.5, 1884, 0.5, true, [ ...
    0 0 0 A0 0; 20 0 0 A0 0; 50 3 0 A0+AB 0; 110 3 0 A0+AB 0; 140 0 0 A0+AB 0; ...
    200 0 0 A0 0; 230 3 0 A0+AB 0; 290 3 0 A0+AB 0; 320 0 0 A0+AB 0; 400 0 0 A0 0]);

S(end+1) = mk('S2_showcase1', 'Showcase 1: light engine, 10 mph x 20 min', 'J-02B', 0, 0.5, 1884, 0.5, true, [ ...
    0 0 0 A0 0; 20 0 0 A0 0; 80 10 0 A0+AB 0; 1280 10 0 A0+AB 0; 1340 0 0 A0+AB 0; 1500 0 0 A0 0]);

S(end+1) = mk('S3_dyncharge_2p5MW', 'Showcase 2: 0.5 mph, 2.5 MW wire, from 20% SOC', 'J-09', 0, 0.2, 1884, 1, true, [ ...
    0 0 0 A0 0; 20 0 0 A0 0; 60 0.5 0 A0+AB 0; 120 0.5 0 A0+AB 0; 150 0.5 0 A0+AB 2.5e6; ...
    7800 0.5 0 A0+AB 2.5e6; 7900 0 0 A0 0; 8000 0 0 A0 0]);

S(end+1) = mk('S4_dyncharge_3p0MW', 'Demo-plan target: 0.5 mph, 3.0 MW wire, BMS charge limit raised to 2328 A', 'J-09 (3 MW)', 0, 0.2, 2328, 1, true, [ ...
    0 0 0 A0 0; 20 0 0 A0 0; 60 0.5 0 A0+AB 0; 120 0.5 0 A0+AB 0; 150 0.5 0 A0+AB 3.0e6; ...
    7800 0.5 0 A0+AB 3.0e6; 7900 0 0 A0 0; 8000 0 0 A0 0]);

S(end+1) = mk('S5_cont_pull_10mph', 'LC-3 (3,640 t, 0.5% grade) at 10 mph for 60 min', 'J-16/P-02', 3640*ST, 0.9, 1884, 1, true, [ ...
    0 0 0.5 A0 0; 20 0 0.5 A0 0; 320 10 0.5 A0+AB 0; 3920 10 0.5 A0+AB 0; 4100 0 0.5 A0+AB 0; 4200 0 0.5 A0 0]);

S(end+1) = mk('S6_notch8_15min', 'Full power (Notch 8) ~16 min, LC-3 on 0.5% (v_ref unreachable by design)', 'J-17/P-01', 3640*ST, 0.9, 1884, 1, false, [ ...
    0 0 0.5 A0 0; 20 0 0.5 A0 0; 140 30 0.5 A0+AB 0; 1100 30 0.5 A0+AB 0; 1101 0 0.5 A0+AB 0; 1400 0 0.5 A0 0]);

cyc = [0 0 0 A0 0; 600 0 0 A0 0; 660 6 0 A0+AB 0; 840 6 0 A0+AB 0; 900 0 0 A0+AB 0; 1200 0 0 A0 0; ...
       1290 10 0 A0+AB 0; 1530 10 0 A0+AB 0; 1620 0 0 A0+AB 0; 1800 0 0 A0 0];
bp = cyc;
for k = 1:15
    c = cyc(2:end, :);
    c(:, 1) = c(:, 1) + 1800*k;
    bp = [bp; c]; %#ok<AGROW>
end
S(end+1) = mk('S7_switch_shift_8h', '8 h yard shift, LC-1 (1,430 t), 2 moves per 30 min', 'J-18', 1430*ST, 0.9, 1884, 2, true, bp);

S(end+1) = mk('S8_park_6h', 'Parked 6 h, HV up, TMS active (preconditioning / recovery time)', 'G6 recommission', 0, 0.6, 1884, 5, false, [ ...
    0 0 0 10e3 0; 21600 0 0 10e3 0]);
end

function s = mk(name, desc, dvp, m_trail, soc0, I_chg, max_step, speed_check, bp)
step = 0.5;
t = (0:step:bp(end, 1))';
U = [t, interp1(bp(:,1), bp(:,2), t), interp1(bp(:,1), bp(:,3), t), interp1(bp(:,1), bp(:,4), t), ...
     interp1(bp(:,1), bp(:,5), t), double(t >= 2)];
s = struct('name', name, 'desc', desc, 'dvp', dvp, 'm_trail', m_trail, 'soc0', soc0, 'I_chg_bms', I_chg, ...
           'max_step', max_step, 'speed_check', speed_check, 'U', U);
end
