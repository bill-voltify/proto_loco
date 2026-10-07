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
pb = R.p_bat/1e3; rg = max(pb) - min(pb); if rg < 1, rg = 1; end
ylim([min(pb) - 0.1*rg, max(pb) + 0.1*rg]);
subplot(5,1,4);
TT = [R.Tc, R.Tsup, R.Tchg, R.Tinv, R.Tcd, R.Tm];
plot(h, TT); hold on;
lo = min(TT(:)); hi = max(TT(:));
lim = [L.T_chg_sup, L.T_inv_out, L.T_check_valve, L.Tcell_L1(2), L.Tcell_L1(1)];
sty = {'r:', 'm:', 'c:', 'r--', 'b--'};
pad = max(2, 0.1*(hi - lo));
for q = 1:numel(lim)
    if lim(q) >= lo - 5 && lim(q) <= hi + 5, yline(lim(q), sty{q}); hi = max(hi, lim(q)); lo = min(lo, lim(q)); end
end
ylim([lo - pad, hi + pad]);
ylabel('C'); grid on;
legend('cell','PE supply','charger out','inverter out','condenser hot','motor', 'Location', 'eastoutside', 'AutoUpdate', 'off');
subplot(5,1,5);
area(h, [R.P_aux_cmd, R.p_tms]/1e3); ylabel('kW'); grid on; xlabel('h');
legend('aux budget','TMS', 'Location', 'eastoutside');
end
