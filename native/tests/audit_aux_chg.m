base = fullfile(pwd,'loco_system','+locosys');
for n = {'auxload','charger'}
    fprintf('\n== %s.ssc ==\n',n{1});
    type(fullfile(base,[n{1} '.ssc']));
end
P = evalin('base','P');
fprintf('\n== P.aux ==\n'); disp(P.aux);
fprintf('\n== P.chg ==\n'); disp(P.chg);
fprintf('\n== P.sys.states ==\n'); disp(P.sys.states);
fprintf('\n== P.sys.buses ==\n'); disp(P.sys.buses);