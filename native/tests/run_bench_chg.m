addpath(genpath(fullfile(pwd,'native')));
native_params;
PN.str.soc0 = 0.92;
assignin('base','PN',PN);
P = evalin('base','P');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end

mdl = 'bench_chg';
f = fullfile(pwd,'native','tests',[mdl '.slx']);
if bdIsLoaded(mdl), close_system(mdl,0); end
if isfile(f), delete(f); end
new_system(mdl);
el = 'fl_lib/Electrical/';
for k = 1:6
    add_block([lib '/TRB String'],sprintf('%s/S%d',mdl,k),'Position',[200 60+90*(k-1) 320 120+90*(k-1)]);
end
add_block('simulink/Sources/Constant',[mdl '/K_all'],'Position',[20 300 60 330],'Value','ones(6,1)');
add_block('simulink/Signal Routing/Demux',[mdl '/K_demux'],'Position',[110 60 115 600],'Outputs','6');
add_block('simulink/Signal Routing/Mux',[mdl '/soc_mux'],'Position',[400 300 405 600],'Inputs','6');
add_block('simulink/Math Operations/Sum of Elements',[mdl '/soc_sum'],'Position',[440 430 470 460]);
add_block('simulink/Math Operations/Gain',[mdl '/soc_avg'],'Position',[500 430 540 460],'Gain','1/6');
add_block([el 'Electrical Elements/Resistor'],[mdl '/R_bus'],'Position',[400 40 460 70],'R','PN.bus.R');
add_block([el 'Electrical Sensors/Current Sensor'],[mdl '/I_pack_sens'],'Position',[500 30 540 70]);
add_block([el 'Electrical Sensors/Voltage Sensor'],[mdl '/V_bus_sens'],'Position',[580 120 620 160]);
add_block([el 'Electrical Elements/Electrical Reference'],[mdl '/GND'],'Position',[600 760 640 800]);
add_block(sprintf('nesl_utility/Solver\nConfiguration'),[mdl '/Solver'],'Position',[480 760 540 800]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_I'],'Position',[600 0 630 20]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[mdl '/PS2S_V'],'Position',[660 200 690 220]);
set_param([mdl '/PS2S_I'],'Unit','A');
set_param([mdl '/PS2S_V'],'Unit','V');
add_block([lib '/AUX'],[mdl '/AUX'],'Position',[760 40 880 160]);
add_block([lib '/Charger'],[mdl '/CHG'],'Position',[760 220 880 320]);
add_block([lib '/Charger FW'],[mdl '/CFW'],'Position',[600 380 720 500]);
add_block('simulink/Sources/From Workspace',[mdl '/Pchg_cmd'],'Position',[480 360 540 390],'VariableName','Pchg_bench');
add_block('simulink/Sources/Constant',[mdl '/k1'],'Position',[500 400 530 420],'Value','1');
add_block('simulink/Sources/Constant',[mdl '/nstr'],'Position',[500 480 540 500],'Value','P.batt.Np');
add_block('simulink/Sources/Constant',[mdl '/Paux'],'Position',[680 40 730 60],'Value','50e3');
add_block('simulink/Sources/Constant',[mdl '/P2'],'Position',[680 80 730 100],'Value','0');

T = {'I_pack','PS2S_I/1';'V_bus','PS2S_V/1';'soc','soc_avg/1';'i_cmd','CFW/1';'p_in','AUX/1'};
for k = 1:size(T,1)
    add_block('simulink/Sinks/To Workspace',[mdl '/log_' T{k,1}],'Position',[1000 40+50*k 1060 70+50*k], ...
        'VariableName',T{k,1},'SaveFormat','Timeseries');
    add_line(mdl,T{k,2},['log_' T{k,1} '/1'],'autorouting','on');
end
S = {'K_all/1','K_demux/1';'soc_mux/1','soc_sum/1';'soc_sum/1','soc_avg/1';
     'Pchg_cmd/1','CFW/1';'k1/1','CFW/2';'soc_avg/1','CFW/3';'nstr/1','CFW/4';'PS2S_V/1','CFW/5';
     'CFW/1','CHG/1';'Paux/1','AUX/1';'P2/1','AUX/2'};
for k = 1:6
    S(end+1,:) = {sprintf('K_demux/%d',k),sprintf('S%d/1',k)};
    S(end+1,:) = {sprintf('S%d/2',k),sprintf('soc_mux/%d',k)};
end
for k = 1:size(S,1)
    add_line(mdl,S{k,1},S{k,2},'autorouting','on');
end

W = {
 'S1','R',1,'R_bus','L',1
 'R_bus','R',1,'I_pack_sens','L',1
 'I_pack_sens','R',2,'V_bus_sens','L',1
 'V_bus_sens','R',2,'GND','L',1
 'S1','R',2,'GND','L',1
 'I_pack_sens','R',2,'AUX','L',1
 'AUX','L',2,'GND','L',1
 'I_pack_sens','R',2,'CHG','L',1
 'CHG','L',2,'GND','L',1
 'I_pack_sens','R',1,'PS2S_I','L',1
 'V_bus_sens','R',1,'PS2S_V','L',1
 'Solver','*',1,'GND','L',1
};
for k = 1:5
    W(end+1,:) = {sprintf('S%d',k),'R',1,sprintf('S%d',k+1),'R',1};
    W(end+1,:) = {sprintf('S%d',k),'R',2,sprintf('S%d',k+1),'R',2};
end
nf = 0;
for k = 1:size(W,1)
    try
        add_line(mdl,ph(mdl,W{k,1},W{k,2},W{k,3}),ph(mdl,W{k,4},W{k,5},W{k,6}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('WIRE FAILED: %s %s%d -> %s %s%d (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
    end
end
fprintf('Bench wires: %d scripted, %d failed\n',size(W,1)-nf,nf);

t_end = 600; t_on = 5; Pc0 = 3e6; Pa0 = 50e3;
assignin('base','Pchg_bench',[0 0; t_on 0; t_on Pc0; t_end Pc0]);
set_param(mdl,'SolverType','Variable-step','Solver','daessc','StopTime',num2str(t_end),'MaxStep','0.1');
save_system(mdl,f);

tic; out = sim(mdl); tsim = toc;
gt = @(n) out.get(n);
In = gt('I_pack'); Sn = gt('soc');

Ns = P.batt.Ns;
R0t = Ns*P.batt.R0_cell/P.batt.Np + P.batt.R_bus;
R1t = Ns*P.batt.R1_cell/P.batt.Np;
Qb = P.batt.Np*P.batt.Q_cell*3600;
Gocv = griddedInterpolant(P.batt.SOC_tab,Ns*P.batt.OCV_tab);
C = P.chg;
dt = 0.01; t = (0:dt:t_end)'; nT = numel(t);
I_r = zeros(nT,1); z_r = I_r;
z = 0.92; v1 = 0; vp = Gocv(z);
for k = 1:nT
    Eb = Gocv(z) - v1;
    Pc = Pc0*(t(k) >= t_on);
    taper = min(max((C.soc_max - z)/C.soc_band,0),1);
    ic = min(min(Pc,C.P_max)/max(vp,100), min(C.I_hw,C.I_bms))*taper;
    ia = min(Pa0,P.aux.P_max)/P.aux.eta/max(vp,100);
    is = ia - ic;
    vp = Eb - R0t*is;
    I_r(k) = is; z_r(k) = z;
    z  = z - dt*is/Qb;
    v1 = v1 + dt/P.batt.tau1*(is*R1t - v1);
end

inn = interp1(In.Time,squeeze(In.Data),t);
sn = interp1(Sn.Time,squeeze(Sn.Data),t);
m = t > t_on + 0.5;
eI = max(abs(inn(m) - I_r(m)))/max(abs(I_r))*100;
eS = max(abs(sn - z_r));
t93n = t(find(sn >= 0.93,1)); t93r = t(find(z_r >= 0.93,1));
if isempty(t93n), t93n = NaN; end
if isempty(t93r), t93r = NaN; end
sign_ok = mean(inn(t > t_on + 1 & t < t_on + 20)) < 0;

fprintf('\n== Bench: 6 strings + AUX 50 kW + Charger 3 MW cmd from 92%% SOC ==\n');
fprintf('Native sim time %.0f s\n',tsim);
for tq = [10 60 120 240 400 599]
    k = find(t >= tq,1);
    fprintf('t=%3.0f s  I_pack %7.0f / %7.0f A   SOC %.4f / %.4f\n',tq,inn(k),I_r(k),sn(k),z_r(k));
end
fprintf('(native / ref)\n');
fprintf('Time to 93%% SOC: native %.1f s  ref %.1f s\n',t93n,t93r);
fprintf('Charging sign ok (pack current negative): %s\n',string(sign_ok));
fprintf('Errors: pack current %.2f %% of peak   SOC %.5f\n',eI,eS);
if sign_ok && eI < 1 && eS < 5e-4 && abs(t93n - t93r) < 2
    fprintf('RESULT: PASS\n');
else
    fprintf('RESULT: FAIL\n');
end

fig = figure('Name','bench_chg vs Phase 3');
subplot(2,1,1); plot(t,inn,t,I_r,'--'); ylabel('I_{pack} (A)'); legend('native','ref'); grid on;
subplot(2,1,2); plot(t,sn,t,z_r,'--'); ylabel('SOC'); xlabel('t (s)'); grid on;
yline([0.93 0.95],':',{'taper start','soc_{max}'});
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_chg_compare.png'));

function h = ph(mdl,blk,side,k)
    p = get_param([mdl '/' blk],'PortHandles');
    c = [p.LConn p.RConn];
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        otherwise, h = c(k);
    end
end