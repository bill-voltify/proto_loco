addpath(genpath(fullfile(pwd,'native')));
native_params;
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
s = [lib '/TRB String'];
c = [s '/Cells'];
if getSimulinkBlockHandle([s '/soc']) > 0
    fprintf('TRB String already has soc output.\n');
    return
end
set_param(c,'SOC_port','simscape.enum.tablebattery.enable.yes');
p = get_param(c,'PortHandles');
cp = [p.LConn p.RConn];
hn = [];
for j = 1:numel(cp)
    if get_param(cp(j),'Line') == -1, hn = cp(j); end
end
if isempty(hn), error('Could not find the new SOC port on Cells.'); end
add_block(sprintf('nesl_utility/PS-Simulink\nConverter'),[s '/PS2S_soc'],'Position',[300 260 330 280]);
set_param([s '/PS2S_soc'],'Unit','1');
add_block('simulink/Sinks/Out1',[s '/soc'],'Position',[400 260 430 280]);
set_param([s '/soc'],'Port','2');
q = get_param([s '/PS2S_soc'],'PortHandles');
add_line(s,hn,q.LConn(1),'autorouting','on');
add_line(s,'PS2S_soc/1','soc/1','autorouting','on');
save_system(lib);
fprintf('TRB String: soc output added (port 2).\n');