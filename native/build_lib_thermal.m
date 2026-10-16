function build_lib_thermal
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/Thermal Plant'];
if getSimulinkBlockHandle(s) > 0
    error('Thermal Plant already exists. Delete it in the library first to rebuild.');
end
add_block('built-in/Subsystem',s,'Position',[600 400 720 760]);
mk = Simulink.Mask.create(s);
mk.addParameter('Name','TH','Prompt','Thermal parameters (struct)','Value','P.th');
mk.addParameter('Name','f_ram','Prompt','Ram-air fraction','Value','0.2');

tl = 'fl_lib/Thermal/';
TM  = [tl 'Thermal Elements/Thermal Mass'];
TR  = [tl 'Thermal Elements/Thermal Reference'];
CV  = [tl 'Thermal Elements/Convective Heat Transfer'];
HS  = [tl 'Thermal Sources/Controlled Heat Flow Rate Source'];
TSR = [tl 'Thermal Sources/Controlled Temperature Source'];
TS  = [tl 'Thermal Sensors/Temperature Sensor'];
S2  = sprintf('nesl_utility/Simulink-PS\nConverter');
P2  = sprintf('nesl_utility/PS-Simulink\nConverter');

N = {'Cells','TH.C_bat','TH.T0_bat';'Cool','TH.C_bc','TH.T0_bat';'Cond','TH.C_cd','TH.T_amb';
     'PE','TH.C_pe','TH.T_amb';'Mot','TH.C_mot','TH.T_amb'};
for k = 1:5
    y = 60 + 140*(k-1);
    add_block(TM,[s '/' N{k,1}],'Position',[600 y 640 y+40]);
    set_param([s '/' N{k,1}],'mass',N{k,2},'sp_heat','1','T_specify','on','T',N{k,3},'T_unit','K');
end
add_block(TR,[s '/Ref'],'Position',[700 900 740 940]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[s '/Solver'],'Position',[580 900 640 940]);
add_block(TSR,[s '/Amb'],'Position',[900 760 960 820]);

Q = {'Q_cells','Cells';'Q_cool','Cool';'Q_cond','Cond';'Q_pe','PE';'Q_mot','Mot'};
for k = 1:5
    y = 60 + 140*(k-1);
    add_block(HS,[s '/' Q{k,1}],'Position',[450 y 510 y+60]);
end
G = {'G_bc','Cells','Cool','s_hbc';'G_cd','Cond','AMB','s_hcd';'G_pe','PE','AMB','s_hpe';'G_mot','Mot','AMB','s_hmot'};
for k = 1:4
    y = 120 + 140*(k-1);
    add_block(CV,[s '/' G{k,1}],'Position',[750 y 810 y+40]);
    set_param([s '/' G{k,1}],'thermal_type','foundation.enum.constant_variable.variable','area','1');
end
add_block(CV,[s '/G_benv'],'Position',[750 20 810 60]);
set_param([s '/G_benv'],'area','1','heat_tr_coeff','TH.UA_benv');

T = {'T_Cells','Cells','o_Tc';'T_Cool','Cool','o_Tb';'T_Cond','Cond','o_Tcd';'T_PE','PE','o_Tpe';'T_Mot','Mot','o_Tm'};
for k = 1:5
    y = 60 + 140*(k-1);
    add_block(TS,[s '/' T{k,1}],'Position',[1000 y 1060 y+60]);
    add_block(P2,[s '/' T{k,3}],'Position',[1120 y+20 1150 y+40]);
    set_param([s '/' T{k,3}],'Unit','K');
end

SQ = {'s_Qb','W';'s_Qcool','W';'s_Qcond','W';'s_Qpe','W';'s_Qmot','W';
      's_hbc','W/(m^2*K)';'s_hcd','W/(m^2*K)';'s_hpe','W/(m^2*K)';'s_hmot','W/(m^2*K)'};
for k = 1:9
    add_block(S2,[s '/' SQ{k,1}],'Position',[360 40+60*(k-1) 390 60+60*(k-1)]);
    set_param([s '/' SQ{k,1}],'Unit',SQ{k,2});
end
add_block(S2,[s '/s_Ta'],'Position',[820 720 850 740]);
set_param([s '/s_Ta'],'Unit','K');

in = {'Qb','ia','p_chg','p_aux','en','Ta','n_ax_on','fan_pe','fan_cd','pump_pe','pump_bat','blower','Qc','Pcomp','Qh'};
for k = 1:15
    add_block('simulink/Sources/In1',[s '/' in{k}],'Position',[20 20+40*(k-1) 50 40+40*(k-1)]);
end
add_block('simulink/Signal Routing/Mux',[s '/Mux'],'Position',[110 20 115 620],'Inputs','15');
add_block('simulink/User-Defined Functions/MATLAB Function',[s '/heat_inputs'],'Position',[150 250 290 350]);
add_block('simulink/Signal Routing/Demux',[s '/Dh'],'Position',[310 20 315 600],'Outputs','9');
add_block('simulink/User-Defined Functions/MATLAB Function',[s '/outlets'],'Position',[1200 700 1340 800]);
add_block('simulink/Signal Routing/Demux',[s '/Do'],'Position',[1370 700 1375 800],'Outputs','5');
out = {'Tc','o_Tc/1';'Tb','o_Tb/1';'Tcd','o_Tcd/1';'Tpe','o_Tpe/1';'Tm','o_Tm/1';
       'Tcs','Do/1';'Tsup','Do/2';'Tchg','Do/3';'Tchop','Do/4';'Tinv','Do/5';'Qpe','Dh/4'};
for k = 1:11
    add_block('simulink/Sinks/Out1',[s '/' out{k,1}],'Position',[1450 20+50*(k-1) 1480 40+50*(k-1)]);
end

setfcn([s '/heat_inputs'],{
 'function y = heat_inputs(u, TH, f_ram)'
 'Qb = u(1); ia = u(2); p_chg = u(3); p_aux = u(4); en = u(5);'
 'n_ax = u(7); fan_pe = u(8); fan_cd = u(9); pump_pe = u(10); pump_bat = u(11);'
 'blower = u(12); Qc = u(13); Pcomp = u(14); Qh = u(15);'
 'Qchop = n_ax*(TH.a_loss*abs(ia) + TH.b_loss*ia^2);'
 'Qchg = max(p_chg, 0)*(1/TH.eta_chg - 1);'
 'Qpe = Qchop + Qchg + TH.k_aux_pe*p_aux + TH.Q_pe_idle*en;'
 'h_bc = TH.UA_bc*(0.2 + 0.8*pump_bat);'
 'h_cd = TH.UA_cd*(f_ram + (1 - f_ram)*fan_cd);'
 'h_pe = TH.UA_pe*(f_ram + (1 - f_ram)*fan_pe)*min(1, 0.2 + 0.8*pump_pe);'
 'h_mot = TH.UA_mot*(0.15 + 0.85*blower);'
 'y = [Qb; Qh - Qc; Qc + Pcomp; Qpe; TH.R_m*ia^2; h_bc; h_cd; h_pe; h_mot];'
 'end'},{'TH','f_ram'});
setfcn([s '/outlets'],{
 'function y = outlets(Tcd, Tpe, u, TH, f_ram)'
 'ia = u(2); p_chg = u(3); p_aux = u(4); Ta = u(6);'
 'fan_pe = u(8); fan_cd = u(9); pump_pe = u(10);'
 'Qrad_cd = TH.UA_cd*(f_ram + (1 - f_ram)*fan_cd)*(Tcd - Ta);'
 'Tcs = Tcd - Qrad_cd/TH.mcp_cd;'
 'fq = max(pump_pe, 0.05);'
 'Qrad_pe = TH.UA_pe*(f_ram + (1 - f_ram)*fan_pe)*min(1, 0.2 + 0.8*pump_pe)*(Tpe - Ta);'
 'Tsup = Tpe - Qrad_pe/(TH.mcp_pe*fq);'
 'Qchg = max(p_chg, 0)*(1/TH.eta_chg - 1);'
 'Tchg = Tsup + Qchg/(TH.mcp_chg*fq);'
 'Tchop = Tsup + (TH.a_loss*abs(ia) + TH.b_loss*ia^2)/(TH.mcp_chop*fq);'
 'Tinv = Tsup + TH.k_inv*p_aux/(TH.mcp_inv*fq);'
 'y = [Tcs; Tsup; Tchg; Tchop; Tinv];'
 'end'},{'TH','f_ram'});

for k = 1:15, add_line(s,[in{k} '/1'],sprintf('Mux/%d',k),'autorouting','on'); end
add_line(s,'Mux/1','heat_inputs/1','autorouting','on');
add_line(s,'heat_inputs/1','Dh/1','autorouting','on');
for k = 1:9, add_line(s,sprintf('Dh/%d',k),[SQ{k,1} '/1'],'autorouting','on'); end
add_line(s,'Ta/1','s_Ta/1','autorouting','on');
add_line(s,'o_Tcd/1','outlets/1','autorouting','on');
add_line(s,'o_Tpe/1','outlets/2','autorouting','on');
add_line(s,'Mux/1','outlets/3','autorouting','on');
add_line(s,'outlets/1','Do/1','autorouting','on');
for k = 1:11, add_line(s,out{k,2},[out{k,1} '/1'],'autorouting','on'); end

hs = @(b) c3(s,b);
W = {};
W(end+1,:) = {hs('Solver'),1,hs('Ref'),1};
W(end+1,:) = {hs('s_Ta'),2,hs('Amb'),2};
W(end+1,:) = {hs('Amb'),3,hs('Ref'),1};
for k = 1:5
    W(end+1,:) = {hs(SQ{k,1}),2,hs(Q{k,1}),2};
    W(end+1,:) = {hs(Q{k,1}),3,hs('Ref'),1};
    W(end+1,:) = {hs(Q{k,1}),1,hs(Q{k,2}),1};
    W(end+1,:) = {hs(T{k,1}),1,hs(T{k,2}),1};
    W(end+1,:) = {hs(T{k,1}),2,hs('Ref'),1};
    W(end+1,:) = {hs(T{k,1}),3,hs(T{k,3}),1};
end
W(end+1,:) = {hs('G_benv'),1,hs('Cells'),1};
W(end+1,:) = {hs('G_benv'),2,hs('Amb'),1};
for k = 1:4
    W(end+1,:) = {hs(G{k,1}),3,hs(G{k,2}),1};
    if strcmp(G{k,3},'AMB')
        W(end+1,:) = {hs(G{k,1}),1,hs('Amb'),1};
    else
        W(end+1,:) = {hs(G{k,1}),1,hs(G{k,3}),1};
    end
    W(end+1,:) = {hs(G{k,4}),2,hs(G{k,1}),2};
end
nf = 0;
for k = 1:size(W,1)
    a = W{k,1}; b = W{k,3};
    try
        add_line(s,a(W{k,2}),b(W{k,4}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('WIRE FAILED row %d: %s\n',k,e.message);
    end
end
fprintf('Thermal wires: %d scripted, %d failed\n',size(W,1)-nf,nf);
save_system(lib);
fprintf('Thermal Plant added to %s.\n',lib);
end

function c = c3(s,b)
    p = get_param([s '/' b],'PortHandles');
    c = [p.LConn p.RConn];
    if numel(c) < 3, c(end+1:3) = c(end); end
end

function setfcn(blk,lines,params)
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',blk);
    ch.Script = strjoin(lines,newline);
    for k = 1:numel(params)
        d = ch.find('-isa','Stateflow.Data','Name',params{k});
        d.Scope = 'Parameter';
    end
end