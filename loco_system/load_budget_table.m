function B = load_budget_table(src)
% LOAD_BUDGET_TABLE  Read load_budget.csv into the matrices the Power Budget block uses.
%   B.LB (nLoads x 7 kW, columns = SLEEP..ESTOP), B.LBmov (kW added when moving in TRACTION/CHARGING),
%   B.LBbus (bus code 1..5 = 750V, 72V, 24V_Ctrl, 24V_BTMS, 12V_BTMS), B.LBeff (conversion efficiency from
%   the 750 V bus to the load, per POC Power Budget Rev B), B.names, B.table.
% Thermal-management loads (MTM compressors, HV heater, SPAL pumps, radiator fans) are in the plant thermal model.
if nargin < 1, src = fullfile(fileparts(mfilename('fullpath')), 'load_budget.csv'); end
T = readtable(src, 'TextType', 'string');
states = {'SLEEP','STANDBY','READY','TRACTION','CHARGING','FAULT','ESTOP'};
buses = {'750V','72V','24V_Ctrl','24V_BTMS','12V_BTMS'};
eff = [1.0, 0.95, 0.95*0.88, 0.93, 0.935];   % 750V direct; LB-1113 95%; LB-1113 x RMD500 88%; DCC65M24 93%; NetPower 93.5%
B.LB = zeros(height(T), numel(states));
for k = 1:numel(states), B.LB(:, k) = double(T.(states{k})); end
B.LBmov = double(T.moving_kW);
B.LBbus = zeros(height(T), 1);
for k = 1:height(T)
    j = find(strcmpi(buses, strtrim(T.bus(k))));
    assert(~isempty(j), 'Unknown bus "%s" for load %s', T.bus(k), T.load_id(k));
    B.LBbus(k) = j;
end
B.LBeff = eff(B.LBbus)';
B.LB(isnan(B.LB)) = 0;
B.LBmov(isnan(B.LBmov)) = 0;
B.names = T.name;
B.ids = T.load_id;
B.table = T;
end
