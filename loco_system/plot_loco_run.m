function plot_loco_run(RUN, P)
% PLOT_LOCO_RUN  System dashboard figure for one run.
R = RUN.R;
h = R.t/3600;
L = P.lim;
figure('Name', ['System run: ' char(RUN.trace.name)], 'Position', [80 60 1100 900]);
subplot(5,1,1);
plot(h, R.v_ref, '--', h, R.v_mph); ylabel('mph'); grid on;
yyaxis right; plot(h, R.ambient); ylabel('ambient C');
legend('v_{ref}','v','ambient', 'Location', 'eastoutside');
title(sprintf('%s — %s %s', RUN.trace.name, RUN.metrics.verdict, RUN.metrics.limit), 'Interpreter', 'none');
subplot(5,1,2);
stairs(h, R.st); ylim([-0.5 6.5]); yticks(0:6); yticklabels(P.sys.states); grid on;
ylabel('state');
subplot(5,1,3);
yyaxis left; plot(h, 100*R.soc); ylabel('SOC %');
yyaxis right; plot(h, R.p_bat/1e3); ylabel('battery kW'); grid on;
subplot(5,1,4);
plot(h, R.Tc, h, R.Tsup, h, R.Tchg, h, R.Tinv, h, R.Tcd, h, R.Tm); hold on;
yline(L.T_chg_sup, 'r:'); yline(L.T_inv_out, 'm:'); yline(L.T_check_valve, 'c:'); yline(L.Tcell_L1(2), 'r--');
ylabel('C'); grid on;
legend('cell','PE supply','charger out','inverter out','condenser hot','motor', 'Location', 'eastoutside');
subplot(5,1,5);
area(h, [R.P_aux_cmd, R.p_tms]/1e3); ylabel('kW'); grid on; xlabel('h');
legend('aux budget','TMS', 'Location', 'eastoutside');
end
