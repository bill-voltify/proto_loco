base = fullfile(pwd,'loco_system','+locosys');
fprintf('\n== thermal.ssc ==\n');
type(fullfile(base,'thermal.ssc'));
P = evalin('base','P');
fprintf('\n== P.th ==\n'); disp(P.th);
fprintf('\n== P.bms ==\n'); disp(P.bms);
fprintf('\n== P.lim ==\n'); disp(P.lim);
fprintf('\n== P.opts ==\n'); disp(P.opts);