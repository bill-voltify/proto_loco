function FLT = build_fault_matrix(F, t_end, P)
% BUILD_FAULT_MATRIX  Piecewise-constant fault channel matrix [t, ch1..ch14] for the model.
% Enabled rows apply active_value on [t_start_s, t_end_s); later rows win on the same channel.
if nargin < 3, P = loco_system_params(); end
ch = P.sys.fault_channels;
nom = P.sys.fault_nominal;
F = F(F.enabled > 0, :);
for k = 1:height(F)
    assert(any(strcmp(ch, F.channel(k))), 'Unknown fault channel "%s" (row %d)', F.channel(k), k);
end
tb = unique([0; F.t_start_s(:); F.t_end_s(:); t_end]);
tb = tb(tb >= 0 & tb <= t_end);
FLT = zeros(numel(tb), numel(ch) + 1);
for i = 1:numel(tb)
    val = nom;
    for k = 1:height(F)
        if tb(i) >= F.t_start_s(k) && tb(i) < F.t_end_s(k)
            val(strcmp(ch, F.channel(k))) = F.active_value(k);
        end
    end
    FLT(i, :) = [tb(i), val];
end
if size(FLT, 1) == 1, FLT = [FLT; FLT]; FLT(2, 1) = max(t_end, 1); end
end
