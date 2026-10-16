addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/Chopper'];
fw = [lib '/Chopper FW'];
if getSimulinkBlockHandle(s) > 0 || getSimulinkBlockHandle(fw) > 0
    error('Chopper or Chopper FW already exists in %s. Delete them in the library first to rebuild.',lib);
end

add_block('built-in/Subsystem',s,'Position',[700 100 820 220]);
add_block('nesl_utility/Connection Port',[s '/p'],'Position',[20 80 50 100]);
add_block('nesl_utility/Connection Port',[s '/n'],'Position',[20 380 50 400]);
add_block('nesl_utility/Connection Port',[s '/mp'],'Position',[1000 80 1030 100]);
add_block('nesl_utility/Connection Port',[s '/mn'],'Position',[1000 380 1030 400]);
try, set_param([s '/p'],'Side','Left'); catch, end
try, set_param([s '/n'],'Side','Left'); catch, end
try, set_param([s '/mp'],'Side','Right'); catch, end
try, set_param([s '/mn'],'Side','Right'); catch, end

add_block(libpath('Controlled Current Source'),[s '/Iin'],'Position',[150 180 200 260]);
add_block(libpath('Voltage Sensor'),[s '/V_dc_sens'],'Position',[260 200 300 240]);
add_block(libpath('Controlled Voltage Source'),[s '/Vout'],'Position',[700 180 750 260]);
add_block(libpath('Current Sensor'),[s '/I_mot'],'Position',[820 70 860 110]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_Va'],'Position',[100 520 130 540]);
add_block(libpath('PS Gain'),[s '/i_buf'],'Position',[860 300 900 330]);
add_block(libpath('PS Gain'),[s '/v_buf'],'Position',[340 300 380 330]);
add_block(libpath('PS Product'),[s '/Prod_P'],'Position',[480 480 510 520]);
add_block(libpath('PS Abs'),[s '/Abs'],'Position',[480 560 510 590]);
add_block(libpath('PS Gain'),[s '/Gain_a'],'Position',[560 560 600 590]);
add_block(libpath('PS Product'),[s '/Prod_sq'],'Position',[480 620 510 660]);
add_block(libpath('PS Gain'),[s '/Gain_b'],'Position',[560 620 600 650]);
add_block(libpath('PS Add'),[s '/Add1'],'Position',[650 580 680 620]);
add_block(libpath('PS Add'),[s '/Add2'],'Position',[720 500 750 540]);
add_block(libpath('PS Constant'),[s '/V_floor'],'Position',[380 400 420 420]);
add_block(libpath('PS Max'),[s '/Max'],'Position',[460 380 490 420]);
add_block(libpath('PS Divide'),[s '/Div'],'Position',[800 440 830 480]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_i'],'Position',[940 600 970 620]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_V'],'Position',[940 660 970 680]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_idc'],'Position',[940 720 970 740]);
add_block('simulink/Sources/In1',[s '/Va_cmd'],'Position',[20 520 50 540]);
add_block('simulink/Sinks/Out1',[s '/i_a'],'Position',[1020 600 1050 620]);
add_block('simulink/Sinks/Out1',[s '/Vdc'],'Position',[1020 660 1050 680]);
add_block('simulink/Sinks/Out1',[s '/i_dc'],'Position',[1020 720 1050 740]);
add_line(s,'Va_cmd/1','S2PS_Va/1','autorouting','on');
add_line(s,'PS2S_i/1','i_a/1','autorouting','on');
add_line(s,'PS2S_V/1','Vdc/1','autorouting','on');
add_line(s,'PS2S_idc/1','i_dc/1','autorouting','on');

trySet([s '/i_buf'],{'gain','1'});
trySet([s '/v_buf'],{'gain','1'});
trySet([s '/Gain_a'],{'gain','PN.ax.a_loss','gain_unit','V'});
trySet([s '/Gain_b'],{'gain','PN.ax.b_loss','gain_unit','Ohm'});
trySet([s '/V_floor'],{'constant','PN.ax.V_floor','constant_unit','V'});
trySet([s '/S2PS_Va'],{'Unit','V'});
trySet([s '/PS2S_i'],{'Unit','A'});
trySet([s '/PS2S_V'],{'Unit','V'});
trySet([s '/PS2S_idc'],{'Unit','A'});

W = {
 'S2PS_Va',1,'Prod_P',1
 'i_buf',1,'Prod_P',2
 'i_buf',1,'Abs',1
 'Abs',1,'Gain_a',1
 'i_buf',1,'Prod_sq',1
 'i_buf',1,'Prod_sq',2
 'Prod_sq',1,'Gain_b',1
 'Gain_a',1,'Add1',1
 'Gain_b',1,'Add1',2
 'Prod_P',1,'Add2',1
 'Add1',1,'Add2',2
 'v_buf',1,'Max',1
 'V_floor',1,'Max',2
 'Add2',1,'Div',1
 'Max',1,'Div',2
 'i_buf',1,'PS2S_i',1
 'v_buf',1,'PS2S_V',1
 'Div',1,'PS2S_idc',1
};
nfail = 0;
for k = 1:size(W,1)
    try
        a = get_param([s '/' W{k,1}],'PortHandles');
        b = get_param([s '/' W{k,3}],'PortHandles');
        add_line(s,a.RConn(W{k,2}),b.LConn(W{k,4}),'autorouting','on');
    catch e
        nfail = nfail + 1;
        fprintf('HAND-WIRE: %s output -> %s input %d   (%s)\n',W{k,1},W{k,3},W{k,4},e.message);
    end
end
fprintf('Chopper math wires: %d scripted, %d to hand-wire\n',size(W,1)-nfail,nfail);

add_block('built-in/Subsystem',fw,'Position',[700 300 820 420]);
add_block('simulink/Sources/In1',[fw '/TE_ref'],'Position',[20 40 50 60]);
add_block('simulink/Sources/In1',[fw '/i_a'],'Position',[20 100 50 120]);
add_block('simulink/Sources/In1',[fw '/v'],'Position',[20 160 50 180]);
add_block('simulink/Sources/In1',[fw '/Vdc'],'Position',[20 220 50 240]);
add_block('simulink/User-Defined Functions/MATLAB Function',[fw '/fw'],'Position',[150 60 330 220]);
add_block('simulink/Sinks/Out1',[fw '/Va'],'Position',[420 130 450 150]);

code = strjoin({
 'function Va = fw(TE_ref, i_a, v, Vdc, A)'
 'wm = A.G*v/A.r_w;'
 'kphi = A.Kphi_sat*(1 - exp(-max(abs(i_a), A.If_min)/A.I0));'
 'E = kphi*wm;'
 'Vmax = min(A.D_max*max(Vdc, 0), A.V_mot_max);'
 'Tm_lim = A.P_ax_max/max(abs(wm), A.w_floor);'
 'Tm_ref = min(max(TE_ref*A.r_w/A.G, -Tm_lim), Tm_lim);'
 'Iref = sign(Tm_ref)*interp1(A.T_tab, A.I_tab, min(abs(Tm_ref), A.T_tab(end)));'
 'Iref = min(max(Iref, -A.I_max), A.I_max);'
 'Va = min(max(E + A.R_m*i_a + A.Kp_i*(Iref - i_a), 0), Vmax);'
 'end'
},newline);
ch = sfroot().find('-isa','Stateflow.EMChart','Path',[fw '/fw']);
ch.Script = code;
dA = ch.find('-isa','Stateflow.Data','Name','A');
dA.Scope = 'Parameter';
mk = Simulink.Mask.create(fw);
mk.addParameter('Name','A','Prompt','Axle parameters (struct)','Value','PN.ax');

add_line(fw,'TE_ref/1','fw/1','autorouting','on');
add_line(fw,'i_a/1','fw/2','autorouting','on');
add_line(fw,'v/1','fw/3','autorouting','on');
add_line(fw,'Vdc/1','fw/4','autorouting','on');
add_line(fw,'fw/1','Va/1','autorouting','on');

save_system(lib);
open_system(s);
fprintf('\nChopper + Chopper FW added. Wire the remaining Chopper connections, then Ctrl+S.\n');

function trySet(b,pv)
    try
        set_param(b,pv{:});
    catch e
        fprintf('SET FAILED on %s: %s\n',b,e.message);
        dp = fieldnames(get_param(b,'DialogParameters'));
        fprintf('   params: %s\n',strjoin(dp(~endsWith(dp,'_conf')),', '));
    end
end

function p = libpath(name)
    known = {
     'Simulink-PS Converter',     sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter',     sprintf('nesl_utility/PS-Simulink\nConverter')
     'Controlled Current Source', 'fl_lib/Electrical/Electrical Sources/Controlled Current Source'
     'Controlled Voltage Source', 'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source'
     'Voltage Sensor',            'fl_lib/Electrical/Electrical Sensors/Voltage Sensor'
     'Current Sensor',            'fl_lib/Electrical/Electrical Sensors/Current Sensor'
     'PS Gain',                   'fl_lib/Physical Signals/Functions/PS Gain'
     'PS Product',                'fl_lib/Physical Signals/Functions/PS Product'
     'PS Add',                    'fl_lib/Physical Signals/Functions/PS Add'
     'PS Divide',                 'fl_lib/Physical Signals/Functions/PS Divide'
     'PS Abs',                    'fl_lib/Physical Signals/Nonlinear Operators/PS Abs'
     'PS Max',                    'fl_lib/Physical Signals/Nonlinear Operators/PS Max'
     'PS Constant',               'fl_lib/Physical Signals/Sources/PS Constant'
    };
    i = find(strcmp(known(:,1),name),1);
    if ~isempty(i)
        try
            if getSimulinkBlockHandle(known{i,2},true) > 0
                p = known{i,2};
                return
            end
        catch
        end
    end
    libs = {'fl_lib','ee_lib','nesl_utility'};
    pat = ['^' strrep(regexptranslate('escape',name),' ','\s') '$'];
    for k = 1:numel(libs)
        try, load_system(libs{k}); catch, continue; end
        h = find_system(libs{k},'LookUnderMasks','all','FollowLinks','on','RegExp','on','Name',pat);
        h = h(~strcmp(h,libs{k}));
        if ~isempty(h)
            [~,j] = min(cellfun(@numel,h));
            p = h{j};
            return
        end
    end
    error('Block not found in libraries: %s',name);
end