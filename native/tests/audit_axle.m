base = fullfile(pwd,'loco_system','+locosys');
for n = {'axle','vehicle','lcc_proxy'}
    fprintf('\n== %s.ssc ==\n',n{1});
    type(fullfile(base,[n{1} '.ssc']));
end
P = evalin('base','P');
fprintf('\n== P.ax ==\n'); disp(P.ax);
fprintf('\n== P.veh ==\n'); disp(P.veh);
fprintf('\n== P.lcc ==\n'); disp(P.lcc);