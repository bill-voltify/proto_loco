addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
f = fullfile(pwd,'native','lib',[lib '.slx']);
if ~bdIsLoaded(lib), load_system(f); end
set_param(lib,'Lock','off');
s = [lib '/DC-Link'];
if getSimulinkBlockHandle(s) > 0
    error('DC-Link already exists in %s. Delete that block in the library first to rebuild (this erases your wiring).',lib);
end
add_block('built-in/Subsystem',s,'Position',[300 100 420 220]);

add_block('nesl_utility/Connection Port',[s '/p'],'Position',[20 100 50 120]);
add_block('nesl_utility/Connection Port',[s '/n'],'Position',[20 400 50 420]);
add_block('nesl_utility/Connection Port',[s '/q'],'Position',[900 100 930 120]);
try, set_param([s '/p'],'Side','Left'); catch, end
try, set_param([s '/n'],'Side','Left'); catch, end
try, set_param([s '/q'],'Side','Right'); catch, end

add_block(libpath('Switch'),[s '/K_pre'],'Position',[200 20 260 70]);
add_block(libpath('Resistor'),[s '/R_pre'],'Position',[340 30 400 60]);
add_block(libpath('Switch'),[s '/K_main'],'Position',[280 140 340 190]);
add_block(libpath('Capacitor'),[s '/C_link'],'Position',[640 220 680 280]);
add_block(libpath('Voltage Sensor'),[s '/V_bus_sens'],'Position',[150 290 190 330]);
add_block(libpath('Voltage Sensor'),[s '/V_link_sens'],'Position',[500 290 540 330]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_Vbus'],'Position',[230 380 260 400]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_Vlink'],'Position',[580 380 610 400]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_main'],'Position',[840 520 870 540]);
add_block(libpath('Simulink-PS Converter'),[s '/S2PS_pre'],'Position',[960 600 990 620]);

set_param([s '/R_pre'],'R','PN.dcl.R_pre');
set_param([s '/K_pre'],'R_closed','PN.dcl.R_pre_k','G_open','1e-9','Threshold','0.5');
set_param([s '/K_main'],'R_closed','PN.dcl.R_on','G_open','1e-9','Threshold','0.5');
try
    set_param([s '/C_link'],'c','PN.dcl.C');
catch e
    fprintf('Could not set capacitance: %s\nCapacitor dialog parameters:\n',e.message);
    dp = fieldnames(get_param([s '/C_link'],'DialogParameters')); fprintf('  %s\n',dp{:});
end
try, set_param([s '/PS2S_Vbus'],'Unit','V'); catch, end
try, set_param([s '/PS2S_Vlink'],'Unit','V'); catch, end
try, set_param([s '/S2PS_main'],'Unit','1'); catch, end
try, set_param([s '/S2PS_pre'],'Unit','1'); catch, end

add_block('simulink/Sources/In1',[s '/en'],'Position',[20 520 50 540]);
add_block('simulink/Sinks/Out1',[s '/v_link'],'Position',[700 380 730 400]);
add_block('simulink/Sinks/Out1',[s '/main_closed'],'Position',[900 460 930 480]);
add_block('simulink/Logic and Bit Operations/Compare To Constant',[s '/EnOn'],'Position',[100 515 170 545],'relop','>','const','0.5');
add_block('simulink/Math Operations/Gain',[s '/k_close'],'Position',[320 430 370 460],'Gain','PN.dcl.k_close');
add_block('simulink/Logic and Bit Operations/Relational Operator',[s '/AtVoltage'],'Position',[440 440 480 490],'Operator','>=');
add_block('simulink/Logic and Bit Operations/Compare To Constant',[s '/AboveGuard'],'Position',[440 510 510 540],'relop','>','const','PN.dcl.V_guard');
add_block('simulink/Logic and Bit Operations/Logical Operator',[s '/AND3'],'Position',[560 500 590 570],'Operator','AND','Inputs','3');
add_block('simulink/Discrete/Memory',[s '/Scan'],'Position',[630 520 660 550]);
add_block('simulink/Signal Attributes/Data Type Conversion',[s '/ToDbl_main'],'Position',[720 520 780 550],'OutDataTypeStr','double');
add_block('simulink/Logic and Bit Operations/Logical Operator',[s '/NOT'],'Position',[700 590 730 620],'Operator','NOT');
add_block('simulink/Logic and Bit Operations/Logical Operator',[s '/AND2'],'Position',[780 590 810 640],'Operator','AND','Inputs','2');
add_block('simulink/Signal Attributes/Data Type Conversion',[s '/ToDbl_pre'],'Position',[860 600 920 630],'OutDataTypeStr','double');

L = {
 'en/1','EnOn/1'
 'EnOn/1','AND3/1'
 'PS2S_Vlink/1','AtVoltage/1'
 'PS2S_Vbus/1','k_close/1'
 'k_close/1','AtVoltage/2'
 'AtVoltage/1','AND3/2'
 'PS2S_Vlink/1','AboveGuard/1'
 'AboveGuard/1','AND3/3'
 'AND3/1','Scan/1'
 'Scan/1','ToDbl_main/1'
 'ToDbl_main/1','S2PS_main/1'
 'ToDbl_main/1','main_closed/1'
 'Scan/1','NOT/1'
 'EnOn/1','AND2/1'
 'NOT/1','AND2/2'
 'AND2/1','ToDbl_pre/1'
 'ToDbl_pre/1','S2PS_pre/1'
 'PS2S_Vlink/1','v_link/1'
};
for k = 1:size(L,1)
    add_line(s,L{k,1},L{k,2},'autorouting','on');
end

save_system(lib);
open_system(s);
fprintf('\nDC-Link added to %s. Wire the 15 physical connections, then Ctrl+S.\n',lib);

function p = libpath(name)
    known = {
     'Simulink-PS Converter', sprintf('nesl_utility/Simulink-PS\nConverter')
     'PS-Simulink Converter', sprintf('nesl_utility/PS-Simulink\nConverter')
     'Switch',                'fl_lib/Electrical/Electrical Elements/Switch'
     'Resistor',              'fl_lib/Electrical/Electrical Elements/Resistor'
     'Capacitor',             'fl_lib/Electrical/Electrical Elements/Capacitor'
     'Voltage Sensor',        'fl_lib/Electrical/Electrical Sensors/Voltage Sensor'
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