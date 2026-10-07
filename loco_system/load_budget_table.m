function B = load_budget_table(src)
% LOAD_BUDGET_TABLE  Read load_budget.csv into the matrices the Power Budget block uses.
%   B.LB (nLoads x 7 kW, columns = SLEEP..ESTOP), B.LBmov (kW added when moving in TRACTION/CHARGING),
%   B.LBbus (bus code 1..5 = 750V, 72V, 24V, 12V, 220VAC), B.names, B.table.
if nargin < 1, src = fullfile(fileparts(mfilename('fullpath')), 'load_budget.csv'); end
T = readtable(src, 'TextType', 'string');
states = {'SLEEP','STANDBY','READY','TRACTION','CHARGING','FAULT','ESTOP'};
buses = {'750V','72V','24V','12V','220VAC'};
B.LB = zeros(height(T), numel(states));
for k = 1:numel(states), B.LB(:, k) = double(T.(states{k})); end
B.LBmov = double(T.moving_kW);
B.LBbus = zeros(height(T), 1);
for k = 1:height(T)
    j = find(strcmpi(buses, strtrim(T.bus(k))));
    assert(~isempty(j), 'Unknown bus "%s" for load %s', T.bus(k), T.load_id(k));
    B.LBbus(k) = j;
end
B.LB(isnan(B.LB)) = 0;
B.LBmov(isnan(B.LBmov)) = 0;
B.names = T.name;
B.ids = T.load_id;
B.table = T;
end
