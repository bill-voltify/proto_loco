function build_lib_tms
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/TMS Controller'];
if getSimulinkBlockHandle(s) > 0
    error('TMS Controller already exists. Delete it in the library first to rebuild.');
end
add_block('built-in/Subsystem',s,'Position',[800 400 920 700]);
mk = Simulink.Mask.create(s);
mk.addParameter('Name','TH','Prompt','Thermal parameters (struct)','Value','P.th');
mk.addParameter('Name','Ts','Prompt','Controller sample time (s)','Value','0.1');

in = {'Tc','Tcs','Tpe','dT_s','tms_en','n_mtm','en','fan_cd','fan_pe'};
for k = 1:9
    add_block('simulink/Sources/In1',[s '/' in{k}],'Position',[20 20+50*(k-1) 50 40+50*(k-1)]);
end
add_block('simulink/Signal Routing/Mux',[s '/Mux'],'Position',[120 20 125 460],'Inputs','9');
add_block('simulink/Discrete/Zero-Order Hold',[s '/Sample'],'Position',[170 225 210 255],'SampleTime','Ts');
add_block('simulink/User-Defined Functions/MATLAB Function',[s '/tms'],'Position',[260 180 440 300]);
add_block('simulink/Discrete/Unit Delay',[s '/Scan'],'Position',[490 225 520 255],'SampleTime','Ts');
add_block('simulink/Signal Routing/Demux',[s '/Demux'],'Position',[570 100 575 400],'Outputs','8');
out = {'Qc','Pcomp','Qh','Ptms','k_dis','k_chg','mc','mh'};
for k = 1:8
    add_block('simulink/Sinks/Out1',[s '/' out{k}],'Position',[640 100+40*(k-1) 670 120+40*(k-1)]);
end

code = {
 'function y = tms(u, TH, Ts)'
 'persistent mc mh'
 'if isempty(mc), mc = 0; mh = 0; end'
 'Tc = u(1); Tcs = u(2); Tpe = u(3); dT_s = u(4); tms_en = u(5);'
 'n_mtm = u(6); en = u(7); fan_cd = u(8); fan_pe = u(9);'
 'Tsens = Tc + dT_s;'
 'f1 = min(max(1 - TH.k_cap*(Tcs - TH.T_cs_ref), 0), 1.2);'
 'f2 = min(max((TH.T_cs_cut - Tcs)/TH.dT_cut, 0), 1);'
 'Qc_av = min(max(n_mtm, 0), TH.N_mtm)*TH.Q_mtm*f1*f2;'
 'Qc = tms_en*mc*min(max(TH.Kp_chill*(Tsens - TH.T_cool_set), 0), Qc_av);'
 'COP = max(TH.COP_min, TH.COP_ref - TH.k_cop*(Tcs - TH.T_cs_ref));'
 'Pcomp = Qc/COP;'
 'Qh = tms_en*mh*TH.Q_heat_max;'
 'f_pe = min(max((Tpe - TH.T_fan_on)/TH.dT_fan, 0.1), 1);'
 'Ptms = Pcomp + Qh + TH.P_pump*tms_en + TH.P_fan_cd*mc*tms_en*fan_cd + TH.P_fan_pe*f_pe*en*fan_pe;'
 'k_hot = min(max((TH.T_hot_L2 - Tsens)/(TH.T_hot_L2 - TH.T_hot_L1), 0), 1);'
 'k_cc = min(max((Tsens - TH.T_cchg_L2)/(TH.T_cchg_L1 - TH.T_cchg_L2), 0), 1);'
 'k_cd = min(max((Tsens - TH.T_cdis_L2)/(TH.T_cdis_L1 - TH.T_cdis_L2), 0), 1);'
 'tc = double(Tsens >= TH.T_cool_on || (mc > 0.5 && Tsens > TH.T_cool_off));'
 'th = double(Tsens <= TH.T_heat_on || (mh > 0.5 && Tsens < TH.T_heat_off));'
 'y = [Qc; Pcomp; Qh; Ptms; k_hot*k_cd; k_hot*k_cc; mc; mh];'
 'mc = mc + Ts/TH.tau_m*(tc - mc);'
 'mh = mh + Ts/TH.tau_m*(th - mh);'
 'end'};
ch = sfroot().find('-isa','Stateflow.EMChart','Path',[s '/tms']);
ch.Script = strjoin(code,newline);
for nm = {'TH','Ts'}
    d = ch.find('-isa','Stateflow.Data','Name',nm{1});
    d.Scope = 'Parameter';
end

for k = 1:9, add_line(s,[in{k} '/1'],sprintf('Mux/%d',k),'autorouting','on'); end
add_line(s,'Mux/1','Sample/1','autorouting','on');
add_line(s,'Sample/1','tms/1','autorouting','on');
add_line(s,'tms/1','Scan/1','autorouting','on');
add_line(s,'Scan/1','Demux/1','autorouting','on');
for k = 1:8, add_line(s,sprintf('Demux/%d',k),[out{k} '/1'],'autorouting','on'); end
save_system(lib);
fprintf('TMS Controller added to %s.\n',lib);
end