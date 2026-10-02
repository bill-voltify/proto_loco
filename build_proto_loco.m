function mdl = build_proto_loco()
root = fileparts(mfilename('fullpath'));
addpath(root);
mdl = 'proto_loco';
if bdIsLoaded(mdl), close_system(mdl, 0); end
f = fullfile(root, [mdl '.slx']);
if exist(f, 'file'), delete(f); end

P = proto_loco_params();
D = proto_duty_cycle();
assignin('base', 'P', P);
assignin('base', 'U', D.U);

new_system(mdl);
open_system(mdl);

add_block('simulink/Sources/From Workspace', [mdl '/U'], 'VariableName', 'U', 'Interpolate', 'on', 'OutputAfterFinalValue', 'Holding final value', 'Position', [40 115 120 145]);
addLib([mdl '/S2PS'], {sprintf('nesl_utility/Simulink-PS\nConverter'), 'nesl_utility/Simulink-PS Converter'}, [170 115 200 145]);
addLib([mdl '/Loco'], {'nesl_utility/Simscape Component', sprintf('nesl_utility/Simscape\nComponent')}, [260 80 440 200]);
addLib([mdl '/PS2S'], {sprintf('nesl_utility/PS-Simulink\nConverter'), 'nesl_utility/PS-Simulink Converter'}, [500 115 530 145]);
addLib([mdl '/Solver'], {sprintf('nesl_utility/Solver\nConfiguration'), 'nesl_utility/Solver Configuration'}, [300 260 360 290]);
add_block('simulink/Sinks/To Workspace', [mdl '/Y'], 'VariableName', 'Y', 'SaveFormat', 'Timeseries', 'Position', [580 115 660 145]);

blk = [mdl '/Loco'];
try
    simscape.setBlockComponent(blk, 'protoloco.locomotive');
catch
    set_param(blk, 'ComponentPath', 'protoloco.locomotive');
end

map = {
    'Ns','P.batt.Ns'; 'Np','P.batt.Np'; 'Q_cell','P.batt.Q_cell'; 'R0_cell','P.batt.R0_cell';
    'R1_cell','P.batt.R1_cell'; 'tau1','P.batt.tau1'; 'R_bus','P.batt.R_bus'; 'soc0','P.batt.soc0';
    'SOC_tab','P.batt.SOC_tab'; 'OCV_tab','P.batt.OCV_tab';
    'R_pre','P.dcl.R_pre'; 'C_link','P.dcl.C_link';
    'G_ratio','P.ax.G'; 'r_w','P.ax.r_w'; 'eta_g','P.ax.eta_g'; 'R_m','P.ax.R_m'; 'L_a','P.ax.L_a';
    'Kphi_sat','P.ax.Kphi_sat'; 'I0','P.ax.I0'; 'If_min','P.ax.If_min'; 'I_max','P.ax.I_max';
    'V_mot_max','P.ax.V_mot_max'; 'P_ax_max','P.ax.P_ax_max'; 'Kp_i','P.ax.Kp_i';
    'a_loss','P.ax.a_loss'; 'b_loss','P.ax.b_loss'; 'I_tab','P.ax.I_tab'; 'T_tab','P.ax.T_tab';
    'm_loco','P.veh.m_loco'; 'm_tot','P.veh.m_tot'; 'm_eff','P.veh.m_eff'; 'Crr','P.veh.Crr'; 'CdA','P.veh.CdA';
    'eta_aux','P.aux.eta'; 'P_aux_max','P.aux.P_max';
    'P_chg_max','P.chg.P_max'; 'I_chg_hw','P.chg.I_hw';
    'Kp_v','P.lcc.Kp_v'; 'Ki_v','P.lcc.Ki_v'; 'mu_adh','P.lcc.mu_adh'; 'P_trac_max','P.lcc.P_trac_max';
    'I_dis_max','P.lcc.I_dis_max'; 'I_chg_max','P.lcc.I_chg_max'; 'eta_drv','P.lcc.eta_drv'};
for k = 1:size(map, 1)
    try
        set_param(blk, map{k,1}, map{k,2});
    catch ME
        warning('param %s not set: %s', map{k,1}, ME.message);
    end
end

phS = get_param([mdl '/S2PS'], 'PortHandles');
phP = get_param([mdl '/PS2S'], 'PortHandles');
phV = get_param([mdl '/Solver'], 'PortHandles');
[hU, hY, hREF] = locoPorts(blk);

add_line(mdl, 'U/1', 'S2PS/1');
add_line(mdl, phS.RConn(1), hU);
add_line(mdl, hY, phP.LConn(1));
add_line(mdl, 'PS2S/1', 'Y/1');
add_line(mdl, phV.RConn(1), hREF);

set_param(mdl, 'StopTime', num2str(D.t_end), 'MaxStep', '0.5', 'RelTol', '1e-4');
try
    set_param(mdl, 'Solver', 'daessc');
catch
    set_param(mdl, 'Solver', 'ode23t');
end
save_system(mdl, f);
end

function addLib(dst, candidates, pos)
for k = 1:numel(candidates)
    try
        add_block(candidates{k}, dst, 'Position', pos);
        return
    catch
    end
end
error('Library block not found for %s', dst);
end

function [hL, hR, hB] = locoPorts(blk)
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
