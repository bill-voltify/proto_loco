addpath(genpath(fullfile(pwd,'native')));
native_params;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/Charger'];
fw = [lib '/Charger FW'];
if getSimulinkBlockHandle(s) > 0 || getSimulinkBlockHandle(fw) > 0
    error('Charger or Charger FW already exists. Delete them in the library first to rebuild.');
end

fl = 'fl_lib/Electrical/';
add_block('built-in/Subsystem',s,'Position',[350 400 470 520]);
add_block('nesl_utility/Connection Port',[s '/p'],'Position',[20 80 50 100]);
add_block('nesl_utility/Connection Port',[s '/n'],'Position',[20 300 50 320]);
try, set_param([s '/p'],'Side','Left'); catch, end
try, set_param([s '/n'],'Side','Left'); catch, end
add_block([fl 'Electrical Sources/Controlled Current Source'],[s '/Ichg'],'Position',[150 150 200 230]);
add_block([fl 'Electrical Sensors/Voltage Sensor'],[s '/V_sens'],'Position',[260 170 300 210]);
add_block(sprintf('nesl_utility/Simulink-PS\nConverter'),[s '/S2PS_i'],'Position',[100 330 130 350]);
add_block('fl_lib/Physical Signals/Functions/PS Product',[s '/Prod'],'Position',[360 300 390 340]);
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[s '/PS2S_p'],'Position',[440 310 470 330]);
add_block('simulink/Sources/In1',[s '/i_cmd'],'Position',[20 330 50 350]);
add_block('simulink/Sinks/Out1',[s '/p_out'],'Position',[520 310 550 330]);
set_param([s '/S2PS_i'],'Unit','A');
set_param([s '/PS2S_p'],'Unit','W');
add_line(s,'i_cmd/1','S2PS_i/1','autorouting','on');
add_line(s,'PS2S_p/1','p_out/1','autorouting','on');
W = {
 'Ichg','L',1,'p','*',1
 'Ichg','R',2,'n','*',1
 'V_sens','L',1,'p','*',1
 'V_sens','R',2,'n','*',1
 'S2PS_i','R',1,'Ichg','R',1
 'S2PS_i','R',1,'Prod','L',1
 'V_sens','R',1,'Prod','L',2
 'Prod','R',1,'PS2S_p','L',1
};
nf = wire(s,W);
fprintf('Charger wires: %d scripted, %d failed\n',size(W,1)-nf,nf);

add_block('built-in/Subsystem',fw,'Position',[350 600 470 720]);
mk = Simulink.Mask.create(fw);
mp = {'P_max','P.chg.P_max';'I_max','P.chg.I_hw';'I_bms','P.chg.I_bms';'soc_max','P.chg.soc_max'; ...
      'soc_band','P.chg.soc_band';'V_floor','100';'N_str_nom','P.batt.Np';'Ts','0.01'};
for k = 1:size(mp,1)
    mk.addParameter('Name',mp{k,1},'Prompt',mp{k,1},'Value',mp{k,2});
end
in = {'P_cmd','k','soc','n_str','Vdc'};
for k = 1:numel(in)
    add_block('simulink/Sources/In1',[fw '/' in{k}],'Position',[20 20+50*(k-1) 50 40+50*(k-1)]);
end
add_block('simulink/Signal Routing/Mux',[fw '/Mux'],'Position',[120 20 125 260],'Inputs','5');
add_block('simulink/Discrete/Zero-Order Hold',[fw '/Sample'],'Position',[170 125 210 155],'SampleTime','Ts');
add_block('simulink/User-Defined Functions/MATLAB Function',[fw '/chg'],'Position',[260 90 440 190]);
add_block('simulink/Discrete/Unit Delay',[fw '/Scan'],'Position',[490 125 520 155],'SampleTime','Ts');
add_block('simulink/Sinks/Out1',[fw '/i_cmd'],'Position',[570 130 600 150]);
code = strjoin({
 'function i = chg(u, P_max, I_max, I_bms, soc_max, soc_band, V_floor, N_str_nom)'
 'P = u(1); k = u(2); soc = u(3); n_str = u(4); V = u(5);'
 'Ilim = min(I_max, I_bms*k*n_str/N_str_nom);'
 'Ip = min(max(P, 0), P_max)/max(V, V_floor);'
 'taper = min(max((soc_max - soc)/soc_band, 0), 1);'
 'i = min(Ip, Ilim)*taper;'
 'end'
},newline);
ch = sfroot().find('-isa','Stateflow.EMChart','Path',[fw '/chg']);
ch.Script = code;
for nm = {'P_max','I_max','I_bms','soc_max','soc_band','V_floor','N_str_nom'}
    d = ch.find('-isa','Stateflow.Data','Name',nm{1});
    d.Scope = 'Parameter';
end
for k = 1:numel(in)
    add_line(fw,[in{k} '/1'],sprintf('Mux/%d',k),'autorouting','on');
end
add_line(fw,'Mux/1','Sample/1','autorouting','on');
add_line(fw,'Sample/1','chg/1','autorouting','on');
add_line(fw,'chg/1','Scan/1','autorouting','on');
add_line(fw,'Scan/1','i_cmd/1','autorouting','on');

save_system(lib);
fprintf('Charger + Charger FW added to %s.\n',lib);

function nf = wire(s,W)
    nf = 0;
    for k = 1:size(W,1)
        try
            add_line(s,ph(s,W{k,1},W{k,2},W{k,3}),ph(s,W{k,4},W{k,5},W{k,6}),'autorouting','on');
        catch e
            nf = nf + 1;
            fprintf('HAND-WIRE: %s %s%d -> %s %s%d (%s)\n',W{k,1},W{k,2},W{k,3},W{k,4},W{k,5},W{k,6},e.message);
        end
    end
end

function h = ph(s,blk,side,k)
    p = get_param([s '/' blk],'PortHandles');
    c = [p.LConn p.RConn];
    switch side
        case 'L', h = p.LConn(k);
        case 'R', h = p.RConn(k);
        otherwise, h = c(k);
    end
end