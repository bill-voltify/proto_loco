function plot_thermal_run(R, ttl)
% PLOT_THERMAL_RUN  Thermal traces for one simulation (R from proto_unpack).
P = proto_loco_params();
L = P.lim;
h = R.t/3600;
figure('Name', ['Thermal: ' ttl], 'Position', [120 80 1000 820]);
subplot(4,1,1);
plot(h, R.Tc, h, R.Tb, h, R.Tm); hold on;
yline(L.Tcell_L1(2), 'r--'); yline(L.Tcell_opt(2), 'g:'); yline(L.Tcell_opt(1), 'g:'); yline(L.Tcell_L1(1), 'b--');
ylabel('C'); legend('cell','battery coolant','D77 motor','BMS L1 hot','optimal band','','BMS L1 cold', 'Location', 'eastoutside'); grid on; title(ttl, 'Interpreter', 'none');
subplot(4,1,2);
plot(h, R.Tsup, h, R.Tchg, h, R.Tchop, h, R.Tinv, h, R.Tcd, h, R.Tcs); hold on;
yline(L.T_chg_sup, 'r--'); yline(L.T_inv_out, 'm--'); yline(L.T_chop_out, 'k--'); yline(L.T_check_valve, 'c--');
ylabel('C'); legend('PE supply','charger out','chopper out','inverter out','condenser hot','condenser supply','charger 55','inverter 60','chopper 63','check valve 65', 'Location', 'eastoutside'); grid on;
subplot(4,1,3);
plot(h, R.q_bat/1e3, h, R.q_chill/1e3, h, R.q_heat/1e3, h, R.q_pe/1e3, h, R.p_tms/1e3);
ylabel('kW'); legend('battery heat','chiller','heater','PE heat','TMS electrical', 'Location', 'eastoutside'); grid on;
subplot(4,1,4);
yyaxis left; plot(h, 100*R.soc); ylabel('SOC %');
yyaxis right; plot(h, R.k_dis, h, R.k_chg, h, R.v_mph/10); ylabel('k / (mph/10)');
legend('SOC','k\_dis','k\_chg','speed/10', 'Location', 'eastoutside'); grid on; xlabel('h');
end
