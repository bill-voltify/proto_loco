addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/LCC'];
if getSimulinkBlockHandle(s) > 0
    error('LCC already exists in %s. Delete it in the library first to rebuild.',lib);
end
add_block('built-in/Subsystem',s,'Position',[1300 100 1420 300]);

in = {'v_ref','v','Vbat','k_dis','k_chg','m_trail','trac','n_ax_on','n_str'};
for k = 1:numel(in)
    add_block('simulink/Sources/In1',[s '/' in{k}],'Position',[20 20+50*(k-1) 50 40+50*(k-1)]);
end
add_block('simulink/Signal Routing/Mux',[s '/Mux'],'Position',[120 20 125 460],'Inputs','9');
add_block('simulink/Discrete/Zero-Order Hold',[s '/Sample'],'Position',[170 225 210 255],'SampleTime','PN.lcc.Ts');
add_block('simulink/User-Defined Functions/MATLAB Function',[s '/lcc'],'Position',[260 180 440 300]);
add_block('simulink/Discrete/Unit Delay',[s '/Scan'],'Position',[490 225 520 255],'SampleTime','PN.lcc.Ts');
add_block('simulink/Signal Routing/Demux',[s '/Demux'],'Position',[570 180 575 300],'Outputs','3');
out = {'TE_ax','TE_ax4','F_fric'};
for k = 1:numel(out)
    add_block('simulink/Sinks/Out1',[s '/' out{k}],'Position',[640 185+40*(k-1) 670 205+40*(k-1)]);
end

code = strjoin({
 'function y = lcc(u, L)'
 'persistent xi'
 'if isempty(xi), xi = 0; end'
 'v_ref = u(1); v = u(2); Vbat = u(3); k_dis = u(4); k_chg = u(5);'
 'm_trail = u(6); trac = u(7); n_ax_on = u(8); n_str = u(9);'
 'mt = max(m_trail, 0);'
 'm_tot = L.m_loco + mt;'
 'm_eff = L.k_rot_loco*L.m_loco + L.k_rot_trail*mt;'
 'Kp = 2*L.zeta*L.wn*m_eff;'
 'Ki = L.wn^2*m_eff;'
 'nax = min(max(n_ax_on, 0), L.N_ax);'
 'fstr = min(max(n_str, 0), L.N_str_nom)/L.N_str_nom;'
 'TE_adh = L.mu_adh*L.m_loco*L.g*nax/L.N_ax;'
 'e = v_ref - v;'
 'TE_raw = Kp*e + xi;'
 'vabs = max(abs(v), L.v_floor);'
 'P_dis = trac*min(L.P_trac_max*nax/L.N_ax, L.I_dis_max*fstr*k_dis*Vbat*L.eta_drv);'
 'P_reg = min(L.P_trac_max*nax/L.N_ax, L.I_chg_max*fstr*k_chg*Vbat/L.eta_drv);'
 'TE_mot_lim = min(TE_adh, P_dis/vabs);'
 'TE_reg_lim = min(TE_adh, P_reg/vabs)*min(abs(v)/L.v_blend, 1);'
 'TE_cmd = min(max(TE_raw, -TE_adh), TE_mot_lim);'
 'TE_el = max(TE_cmd, -TE_reg_lim);'
 'F_park = L.mu_park*m_tot*L.g;'
 'if v_ref < 0.01'
 '    F_hold = F_park;'
 '    dxi = -xi/1;'
 'else'
 '    F_hold = F_park*min(max(-v/L.v_rb, 0), 1);'
 '    dxi = Ki*e + (TE_cmd - TE_raw)/L.T_aw;'
 'end'
 'xi = xi + L.Ts*dxi;'
 'TE_each = TE_el/max(nax, 1);'
 'y = [TE_each; TE_each*min(max(nax - 3, 0), 1); TE_el - TE_cmd + F_hold];'
 'end'
},newline);
ch = sfroot().find('-isa','Stateflow.EMChart','Path',[s '/lcc']);
ch.Script = code;
dL = ch.find('-isa','Stateflow.Data','Name','L');
dL.Scope = 'Parameter';
mk = Simulink.Mask.create(s);
mk.addParameter('Name','L','Prompt','LCC parameters (struct)','Value','PN.lcc');

for k = 1:numel(in)
    add_line(s,[in{k} '/1'],sprintf('Mux/%d',k),'autorouting','on');
end
add_line(s,'Mux/1','Sample/1','autorouting','on');
add_line(s,'Sample/1','lcc/1','autorouting','on');
add_line(s,'lcc/1','Scan/1','autorouting','on');
add_line(s,'Scan/1','Demux/1','autorouting','on');
for k = 1:numel(out)
    add_line(s,sprintf('Demux/%d',k),[out{k} '/1'],'autorouting','on');
end

save_system(lib);
open_system(s);
fprintf('\nLCC block added to %s (sampled at %g s).\n',lib,PN.lcc.Ts);