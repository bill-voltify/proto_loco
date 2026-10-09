addpath(genpath(fullfile(pwd,'native')));
native_params;

lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/D77 Motor'];
if getSimulinkBlockHandle(s) > 0
    error('D77 Motor already exists in %s. Delete it in the library first to rebuild (this erases your wiring).',lib);
end
add_block('built-in/Subsystem',s,'Position',[500 100 620 220]);

add_block('nesl_utility/Connection Port',[s '/ap'],'Position',[20 80 50 100]);
add_block('nesl_utility/Connection Port',[s '/an'],'Position',[20 360 50 380]);
add_block('nesl_utility/Connection Port',[s '/shaft'],'Position',[1000 200 1030 220]);
try, set_param([s '/ap'],'Side','Left'); catch, end
try, set_param([s '/an'],'Side','Left'); catch, end
try, set_param([s '/shaft'],'Side','Right'); catch, end

add_block(libpath('Current Sensor'),[s '/I_arm'],'Position',[120 70 160 110]);
add_block(libpath('Resistor'),[s '/R_arm'],'Position',[230 80 290 100]);
add_block(libpath('Inductor'),[s '/L_arm'],'Position',[350 80 410 100]);
add_block(libpath('Controlled Voltage Source'),[s '/EMF'],'Position',[470 200 520 280]);
add_block(libpath('PS Lookup Table (1D)'),[s '/kphi'],'Position',[250 200 310 240]);
add_block(libpath('PS Product'),[s '/Prod_E'],'Position',[380 230 410 270]);
add_block(libpath('PS Product'),[s '/Prod_T'],'Position',[380 330 410 370]);
add_block(libpath('Ideal Torque Source'),[s '/Torque'],'Position',[700 300 760 360]);
add_block(libpath('Ideal Rotational Motion Sensor'),[s '/W_sens'],'Position',[700 120 760 180]);
add_block(libpath('Mechanical Rotational Reference'),[s '/Case'],'Position',[840 420 880 460]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_i'],'Position',[230 20 260 40]);
add_block(libpath('PS-Simulink Converter'),[s '/PS2S_T'],'Position',[500 420 530 440]);
add_block('simulink/Sinks/Out1',[s '/i_a'],'Position',[320 20 350 40]);
add_block('simulink/Sinks/Out1',[s '/T_m'],'Position',[590 420 620 440]);
add_line(s,'PS2S_i/1','i_a/1','autorouting','on');
add_line(s,'PS2S_T/1','T_m/1','autorouting','on');

set_param([s '/R_arm'],'R','PN.ax.R_m');
try
    set_param([s '/L_arm'],'l','PN.ax.L_a');
catch e
    fprintf('Inductor: %s\n',e.message);
    dp = fieldnames(get_param([s '/L_arm'],'DialogParameters')); fprintf('  %s\n',dp{:});
end
try
    set_param([s '/kphi'],'x','PN.ax.i_k','f','PN.ax.kphi_k');
    try, set_param([s '/kphi'],'x_unit','A'); catch, end
    try, set_param([s '/kphi'],'f_unit','V*s/rad'); catch, end
catch e
    fprintf('Lookup: %s\n',e.message);
    dp = fieldnames(get_param([s '/kphi'],'DialogParameters')); fprintf('  %s\n',dp{:});
end
try, set_param([s '/PS2S_i'],'Unit','A'); catch, end
try, set_param([s '/PS2S_T'],'Unit','N*m'); catch, end

save_system(lib);
open_system(s);

fprintf('\n== Driveline parameter names (for next step) ==\n');
for nm = {'Simple Gear','Wheel and Axle'}
    bp = libpath(nm{1});
    fprintf('\n-- %s  [%s]\n',nm{1},strrep(bp,newline,' '));
    dp = get_param(bp,'DialogParameters'); fn = fieldnames(dp);
    for k = 1:numel(fn)
        pr = ''; try, pr = strrep(dp.(fn{k}).Prompt,newline,' '); catch, end
        v = ''; try, v = get_param(bp,fn{k}); catch, end
        if ~ischar(v), v = '<non-text>'; end
        if isempty(pr) || endsWith(fn{k},'_conf') || endsWith(fn{k},'_unit'), continue; end
        fprintf('%-28s | %-45s | %s\n',fn{k},pr,v);
    end
end
fprintf('\nD77 Motor added. Wire the 18 connections, then Ctrl+S.\n');

function p = libpath(name)
    known = {
     'PS-Simulink Converter',          sprintf('nesl_utility/PS-Simulink\nConverter')
     'Current Sensor',                 'fl_lib/Electrical/Electrical Sensors/Current Sensor'
     'Resistor',                       'fl_lib/Electrical/Electrical Elements/Resistor'
     'Inductor',                       'fl_lib/Electrical/Electrical Elements/Inductor'
     'Controlled Voltage Source',      'fl_lib/Electrical/Electrical Sources/Controlled Voltage Source'
     'PS Lookup Table (1D)',           'fl_lib/Physical Signals/Lookup Tables/PS Lookup Table (1D)'
     'PS Product',                     'fl_lib/Physical Signals/Functions/PS Product'
     'Ideal Torque Source',            'fl_lib/Mechanical/Mechanical Sources/Ideal Torque Source'
     'Ideal Rotational Motion Sensor', 'fl_lib/Mechanical/Mechanical Sensors/Ideal Rotational Motion Sensor'
     'Mechanical Rotational Reference','fl_lib/Mechanical/Rotational Elements/Mechanical Rotational Reference'
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