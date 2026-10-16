addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/Vehicle'];
if getSimulinkBlockHandle(s) > 0
    error('Vehicle already exists in %s. Delete it in the library first to rebuild.',lib);
end

add_block('built-in/Subsystem',s,'Position',[1100 100 1220 220]);
add_block('nesl_utility/Connection Port',[s '/rail'],'Position',[20 100 50 120]);
try, set_param([s '/rail'],'Side','Left'); catch, end

add_block(libpath('Mass'),[s '/Body'],'Position',[200 20 260 60]);
add_block(libpath('Translational Friction'),[s '/Rolling'],'Position',[200 120 260 160]);
add_block(libpath('Ideal Translational Motion Sensor'),[s '/V_sens'],'Position',[200 220 260 280]);
add_block(libpath('Ideal Force Source'),[s '/F_src'],'Position',[200 340 260 400]);
add_block(libpath('Mechanical Translational Reference'),[s '/Ground'],'Position',[420 440 460 480]);

add_block(libpath('PS Gain'),[s '/v_buf'],'Position',[340 230 380 260]);
add_block(libpath('PS Abs'),[s '/Abs'],'Position',[460 200 490 230]);
add_block(libpath('PS Product'),[s '/Prod_aero'],'Position',[540 220 570 260]);
add_block(libpath('PS Gain'),[s '/Gain_aero'],'Position',[620 225 660 255]);
add_block(libpath('PS Lookup Table (1D)'),[s '/tanh_v'],'Position',[460 290 520 320]);
add_block(libpath('PS Product'),[s '/Prod_brk'],'Position',[580 300 610 340]);
add_block(libpath('PS Add'),[s '/Add1'],'Position',[700 250 730 290]);
add_block(libpath('PS Add'),[s '/Add2'],'Position',[780 300 810 340]);
add_block(libpath('PS Gain'),[s '/Neg'],'Position',[860 305 900 335]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_Fb'],'Position',[500 380 530 400]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_Fg'],'Position',[700 400 730 420]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_v'],'Position',[460 150 490 170]);

add_block('simulink/Sources/In1',[s '/grade'],'Position',[20 400 50 420]);
add_block('simulink/Sources/In1',[s '/F_brake'],'Position',[20 380 50 400]);
add_block('simulink/Math Operations/Gain',[s '/K_grade'],'Position',[580 395 640 425],'Gain','PN.veh.K_grade');
add_block('simulink/Sinks/Out1',[s '/v'],'Position',[560 150 590 170]);
set_param([s '/grade'],'Port','1');
set_param([s '/F_brake'],'Port','2');

trySet([s '/Body'],{'mass','PN.veh.m_eff'});
trySet([s '/Body'],{'v_specify','on','v_priority','High','v','PN.veh.v0','v_unit','m/s'});
trySet([s '/Rolling'],{'brkwy_frc','PN.veh.F_roll','Col_frc','PN.veh.F_roll','brkwy_vel','1','visc_coef','0'});
trySet([s '/v_buf'],{'gain','1'});
trySet([s '/Neg'],{'gain','-1'});
trySet([s '/Gain_aero'],{'gain','PN.veh.k_aero','gain_unit','N*s^2/m^2'});
trySet([s '/tanh_v'],{'x','PN.veh.tanh_x','x_unit','m/s','f','PN.veh.tanh_f','f_unit','1'});
trySet([s '/S2PS_Fb'],{'Unit','N'});
trySet([s '/S2PS_Fg'],{'Unit','N'});
trySet([s '/PS2S_v'],{'Unit','m/s'});

add_line(s,'grade/1','K_grade/1','autorouting','on');
add_line(s,'K_grade/1','S2PS_Fg/1','autorouting','on');
add_line(s,'F_brake/1','S2PS_Fb/1','autorouting','on');
add_line(s,'PS2S_v/1','v/1','autorouting','on');

W = {
 'v_buf',1,'Abs',1
 'v_buf',1,'Prod_aero',1
 'Abs',1,'Prod_aero',2
 'Prod_aero',1,'Gain_aero',1
 'v_buf',1,'tanh_v',1
 'S2PS_Fb',1,'Prod_brk',1
 'tanh_v',1,'Prod_brk',2
 'Gain_aero',1,'Add1',1
 'Prod_brk',1,'Add1',2
 'Add1',1,'Add2',1
 'S2PS_Fg',1,'Add2',2
 'Add2',1,'Neg',1
 'v_buf',1,'PS2S_v',1
};
nf = 0;
for k = 1:size(W,1)
    try
        a = get_param([s '/' W{k,1}],'PortHandles');
        b = get_param([s '/' W{k,3}],'PortHandles');
        add_line(s,a.RConn(W{k,2}),b.LConn(W{k,4}),'autorouting','on');
    catch e
        nf = nf + 1;
        fprintf('HAND-WIRE: %s output -> %s input %d   (%s)\n',W{k,1},W{k,3},W{k,4},e.message);
    end
end
fprintf('Force-math wires: %d scripted, %d to hand-wire\n',size(W,1)-nf,nf);

save_system(lib);
open_system(s);
fprintf('\nVehicle block added. Wire the 9 mechanical/sensor connections, then Ctrl+S.\n');

function trySet(b,pv)
    try
        set_param(b,pv{:});
    catch e
        fprintf('SET FAILED on %s: %s\n',b,e.message);
        dp = fieldnames(get_param(b,'DialogParameters'));
        fprintf('   params: %s\n',strjoin(dp(~endsWith(dp,'_conf') & ~endsWith(dp,'_unit')),', '));
    end
end

function p = libpath(name)
    known = {
     'Simulink-PS Converter',             sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter',             sprintf('nesl_utility/PS-Simulink\nConverter')
     'Mass',                              'fl_lib/Mechanical/Translational Elements/Mass'
     'Translational Friction',            'fl_lib/Mechanical/Translational Elements/Translational Friction'
     'Mechanical Translational Reference','fl_lib/Mechanical/Translational Elements/Mechanical Translational Reference'
     'Ideal Translational Motion Sensor', 'fl_lib/Mechanical/Mechanical Sensors/Ideal Translational Motion Sensor'
     'Ideal Force Source',                'fl_lib/Mechanical/Mechanical Sources/Ideal Force Source'
     'PS Gain',                           'fl_lib/Physical Signals/Functions/PS Gain'
     'PS Product',                        'fl_lib/Physical Signals/Functions/PS Product'
     'PS Add',                            'fl_lib/Physical Signals/Functions/PS Add'
     'PS Abs',                            'fl_lib/Physical Signals/Nonlinear Operators/PS Abs'
     'PS Lookup Table (1D)',              'fl_lib/Physical Signals/Lookup Tables/PS Lookup Table (1D)'
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
    libs = {'fl_lib','sdl_lib','ee_lib','nesl_utility'};
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