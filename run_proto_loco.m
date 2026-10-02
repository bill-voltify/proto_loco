root = fileparts(mfilename('fullpath'));
addpath(root);
mdl = build_proto_loco();
out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
Y = out.Y;
t = Y.Time;
d = squeeze(Y.Data);
if size(d,1) ~= numel(t), d = d.'; end
names = {'v_mph','soc','vt','ib','vlink','ia','va','te_ax','f_fric','p_aux','p_chg','idc_ax'};
for k = 1:numel(names), R.(names{k}) = d(:,k); end
R.t = t;
R.p_bat = R.vt.*R.ib;
assignin('base', 'R', R);

figure('Name', 'Proto Loco v2');
subplot(5,1,1); plot(t, R.v_mph, t, interp1(evalin('base','U(:,1)'), evalin('base','U(:,2)'), t), '--'); ylabel('mph'); legend('v','v_{ref}'); grid on;
subplot(5,1,2); plot(t, 4*R.te_ax/1e3, t, -R.f_fric/1e3); ylabel('kN'); legend('TE elec (4 ax)','friction'); grid on;
subplot(5,1,3); plot(t, R.ia, t, R.va); ylabel('A / V'); legend('I_a ax1','V_a ax1'); grid on;
subplot(5,1,4); plot(t, R.vt, t, R.vlink); ylabel('V'); legend('V_{TRB}','V_{link}'); grid on;
subplot(5,1,5); yyaxis left; plot(t, R.ib); ylabel('I_{bat} A'); yyaxis right; plot(t, 100*R.soc); ylabel('SOC %'); xlabel('s'); grid on;

E_dis = trapz(t, max(R.p_bat,0))/3.6e6;
E_chg = trapz(t, -min(R.p_bat,0))/3.6e6;
fprintf('V_TRB at t=1 s       : %.1f V (expect ~%.0f)\n', interp1(t,R.vt,1), 416*interp1([0.8 0.9 0.95],[3.33 3.35 3.40],0.9));
fprintf('V_link at t=3 s      : %.1f V\n', interp1(t,R.vlink,3));
fprintf('Peak I_bat discharge : %.0f A (limit 1884)\n', max(R.ib));
fprintf('Peak I_bat charge    : %.0f A (limit 1884)\n', -min(R.ib));
fprintf('Peak I_a per axle    : %.0f A (D77 cont 1050)\n', max(abs(R.ia)));
fprintf('Peak TE (4 axles)    : %.0f kN\n', 4*max(R.te_ax)/1e3);
fprintf('Energy out / in      : %.1f / %.1f kWh\n', E_dis, E_chg);
fprintf('SOC start / end      : %.2f / %.2f %%\n', 100*R.soc(1), 100*R.soc(end));
