function M = eval_thermal_run(R, P, scn, U)
% EVAL_THERMAL_RUN  Metrics and verdict for one scenario x ambient run.
% Verdict ladder: OPTIMAL > OK > DERATED > FAIL. 'limit' names the first binding item.
L = P.lim;
t = R.t;
vref = interp1(U(:,1), U(:,2), t, 'linear', 'extrap');
pcmd = interp1(U(:,1), U(:,5), t, 'linear', 'extrap');
charging = pcmd > 1e3 & R.soc < P.chg.soc_max - 0.03;
traction = vref > 0.2;

M.scenario = string(scn.name);
M.T_amb = P.opts.T_amb_C;
M.T0 = P.opts.T0_C;
M.Tcell_max = max(R.Tc);
M.Tcell_min = min(R.Tc);
M.Tcell_end = R.Tc(end);
M.Tsup_max = max(R.Tsup);
M.Tchg_out_max = max(R.Tchg);
M.Tchg_sup_max = max([R.Tsup(charging); NaN]);
M.Tchop_out_max = max(R.Tchop);
M.Tinv_out_max = max(R.Tinv);
M.Tcond_max = max(R.Tcd);
M.Tmotor_max = max(R.Tm);
M.k_dis_min = min([R.k_dis(traction); 1]);
M.k_chg_min = min([R.k_chg(charging); 1]);
M.q_bat_max_kW = max(R.q_bat)/1e3;
M.q_chill_max_kW = max(R.q_chill)/1e3;
M.E_tms_kWh = trapz(t, R.p_tms)/3.6e6;
M.E_bat_out_kWh = trapz(t, max(R.p_bat, 0))/3.6e6;
M.E_bat_in_kWh = trapz(t, -min(R.p_bat, 0))/3.6e6;
M.soc_end = R.soc(end);
M.v_max = max(R.v_mph);

M.speed_ok = true;
if scn.speed_check
    dv = [0; diff(vref)];
    idx = find(abs(dv) > 1e-6);
    tchg = t(idx);
    since = inf(size(t));
    for k = 1:numel(t)
        j = find(tchg <= t(k), 1, 'last');
        if ~isempty(j), since(k) = t(k) - tchg(j); end
    end
    hold = vref > 0.4 & abs(dv) < 1e-6 & since > 180;
    if any(hold)
        M.speed_ok = mean(R.v_mph(hold) >= vref(hold) - 1) >= 0.95;
    end
end

fails = {};
if M.Tcell_max >= P.bms.T_hot_L2, fails{end+1} = 'cell >= BMS L2 hot'; end
if any(R.Tc(traction | charging) <= min(P.bms.T_cdis_L2, P.bms.T_cchg_L2)), fails{end+1} = 'cell <= BMS L2 cold'; end
if ~isnan(M.Tchg_sup_max) && M.Tchg_sup_max > L.T_chg_sup, fails{end+1} = sprintf('charger supply > %g C', L.T_chg_sup); end
if M.Tchop_out_max > L.T_chop_out, fails{end+1} = sprintf('chopper fluid > %g C', L.T_chop_out); end
if M.Tinv_out_max > L.T_inv_out, fails{end+1} = sprintf('inverter fluid > %g C', L.T_inv_out); end
if M.Tcond_max > L.T_check_valve, fails{end+1} = sprintf('condenser loop > %g C (check valve)', L.T_check_valve); end
if M.Tmotor_max > L.T_motor, fails{end+1} = sprintf('motor > %g C', L.T_motor); end

derates = {};
if M.k_dis_min < 0.99, derates{end+1} = 'BMS discharge derate'; end
if M.k_chg_min < 0.99, derates{end+1} = 'BMS charge derate'; end
if ~M.speed_ok, derates{end+1} = 'speed not held'; end

m_chg = L.T_chg_sup - M.Tchg_sup_max;
if isnan(m_chg), m_chg = inf; end
opt_margin = min([m_chg, L.T_chop_out - M.Tchop_out_max, L.T_inv_out - M.Tinv_out_max, L.T_check_valve - M.Tcond_max]);
in_L1 = M.Tcell_max <= L.Tcell_L1(2) && all(R.Tc(traction | charging) >= L.Tcell_L1(1));
in_opt = M.Tcell_max <= L.Tcell_opt(2) && M.Tcell_min >= L.Tcell_opt(1);

if ~isempty(fails)
    M.verdict = "FAIL"; M.limit = string(strjoin(fails, '; '));
elseif ~isempty(derates)
    M.verdict = "DERATED"; M.limit = string(strjoin(derates, '; '));
elseif ~in_L1
    M.verdict = "DERATED"; M.limit = "cell outside BMS L1 band";
elseif in_opt && opt_margin >= L.margin_opt
    M.verdict = "OPTIMAL"; M.limit = "";
else
    M.verdict = "OK";
    if ~in_opt, M.limit = sprintf("cell %.0f-%.0f C outside %g-%g C", M.Tcell_min, M.Tcell_max, L.Tcell_opt); else, M.limit = sprintf("PE margin %.1f K", opt_margin); end
end
M.pe_margin_K = opt_margin;
end
