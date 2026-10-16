native_params;
mdl = 'bench_string';
if ~bdIsLoaded(mdl), load_system(fullfile(pwd,'native','tests',[mdl '.slx'])); end
blk = [mdl '/String1'];

dynCls = 'simscape.enum.tablebattery.prm_dyn';
m = string(enumeration(dynCls));
j = find(contains(lower(m),'1') | contains(lower(m),'one'),1);
if isempty(j)
    fprintf('prm_dyn options: %s\n',strjoin(m,', '));
    error('No single-RC option found for Charge dynamics');
end

set_param(blk, ...
    'SOC_vec','PN.SOC','SOC_vec_unit','1', ...
    'T_dependence','simscape.enum.tablebattery.temperature_dependence.yes', ...
    'T_vec','PN.T','T_vec_unit','K', ...
    'prm_dir','simscape.enum.tablebattery.prm_dir.noCurrentDirectionality', ...
    'V0_mat','PN.str.V0','V0_mat_unit','V', ...
    'V_range','[0 inf]', ...
    'R0_mat','PN.str.R0','R0_mat_unit','Ohm', ...
    'AH','PN.str.Q_Ah','AH_unit','A*hr', ...
    'prm_leak','simscape.enum.tablebattery.prm_leak.disabled', ...
    'extrapolation_option','simscape.enum.extrapolation.nearest', ...
    'prm_dyn',[dynCls '.' char(m(j))], ...
    'R1_mat','PN.str.R1','R1_mat_unit','Ohm', ...
    'tau1_mat','PN.str.tau1','tau1_mat_unit','s', ...
    'prm_fade','simscape.enum.tablebattery.prm_fade.disabled', ...
    'thermal_port','simscape.enum.thermaleffects.omit', ...
    'temperature',num2str(evalin('base','P.batt.T_ref')),'temperature_unit','K', ...
    'stateOfCharge_specify','on','stateOfCharge_priority','High', ...
    'stateOfCharge','PN.str.soc0','stateOfCharge_unit','1');
save_system(mdl);
fprintf('Battery block set. Charge dynamics = %s\n',m(j));

out = sim(mdl);
Vs = out.get('V_term'); Is = out.get('I_meas');
ts = Vs.Time; vs = squeeze(Vs.Data); is = squeeze(Is.Data);

dt = 0.1; t = (0:dt:ts(end))';
[tu,iu] = unique(PN.bench.I(:,1),'last');
Ic = interp1(tu,PN.bench.I(iu,2),t,'previous');
z = zeros(size(t)); v1 = z; vr = z;
z(1) = PN.str.soc0;
R0 = PN.str.R0(1,4); R1 = PN.str.R1(1,4); tau = PN.str.tau1(1,4);
ocv = @(s) interp1(PN.SOC,PN.str.V0(:,4),min(max(s,0),1));
for k = 1:numel(t)
    vr(k) = ocv(z(k)) - Ic(k)*R0 - v1(k);
    if k < numel(t)
        z(k+1)  = z(k) - Ic(k)*dt/(PN.str.Q_Ah*3600);
        v1(k+1) = v1(k) + dt/tau*(Ic(k)*R1 - v1(k));
    end
end

vsi = interp1(ts,vs,t);
isi = interp1(ts,is,t);
win = (t > 900 & t < 1000);
dis_ok = mean(isi(win)) > 0 && vsi(find(t>=1800,1)) < vsi(find(t>=5,1));

mask = true(size(t));
for te = tu(2:end)'
    mask(abs(t-te) < 2) = false;
end
err = (vsi - vr)./vr*100;
emax = max(abs(err(mask)));
erms = sqrt(mean(err(mask).^2));

fprintf('\n== Bench: one string, 1C discharge / rest / 0.5C charge ==\n');
fprintf('Discharge sign correct : %s\n',string(dis_ok));
fprintf('V start  sim %.1f  ref %.1f V\n',vsi(1),vr(1));
fprintf('V@1800s  sim %.1f  ref %.1f V\n',vsi(find(t>=1800,1)),vr(find(t>=1800,1)));
fprintf('V@3000s  sim %.1f  ref %.1f V\n',vsi(end),vr(end));
fprintf('Ref SOC end = %.3f\n',z(end));
fprintf('Voltage error max %.3f %%   rms %.3f %%\n',emax,erms);
if ~dis_ok
    fprintf('RESULT: SIGN WRONG. Swap the two blue wires on Load and rerun.\n');
elseif emax < 1
    fprintf('RESULT: PASS (< 1%%)\n');
else
    fprintf('RESULT: FAIL (>= 1%%)\n');
end

fig = figure('Name','bench_string vs Phase 3');
subplot(3,1,1); plot(t,vsi,t,vr,'--'); ylabel('V_{term} (V)'); legend('native','Phase 3 eq'); grid on;
subplot(3,1,2); plot(t,err); ylabel('error (%)'); grid on;
subplot(3,1,3); plot(t,isi,t,Ic,'--'); ylabel('I (A)'); xlabel('t (s)'); legend('measured','command'); grid on;
rd = fullfile(pwd,'native','results'); if ~isfolder(rd), mkdir(rd); end
exportgraphics(fig,fullfile(rd,'bench_string_compare.png'));