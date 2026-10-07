function R = proto_unpack(Y)
% PROTO_UNPACK  Convert the 28-column output timeseries Y into a struct of named signals.
% Temperatures returned in C.
t = Y.Time;
d = squeeze(Y.Data);
if size(d, 1) ~= numel(t), d = d.'; end
names = {'v_mph','soc','vt','ib','vlink','ia','va','te_ax','f_fric','p_aux','p_chg','idc_ax', ...
         'Tc','Tb','Tcs','Tcd','Tsup','Tchg','Tchop','Tinv','Tm', ...
         'p_tms','q_chill','q_heat','q_bat','q_pe','k_dis','k_chg'};
for k = 1:numel(names), R.(names{k}) = d(:, k); end
for f = {'Tc','Tb','Tcs','Tcd','Tsup','Tchg','Tchop','Tinv','Tm'}
    R.(f{1}) = R.(f{1}) - 273.15;
end
R.t = t;
R.p_bat = R.vt.*R.ib;
end
