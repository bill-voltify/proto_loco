function W = cemex_weight(E_kWh, core)
% CEMEX_WEIGHT  Battery locomotive weight vs installed battery energy, from the Voltify weight study
% (Drive: "BEL weights - G3 Packs", SD40 core with 6 / 7 battery columns; AC44 core with 8).
%   W = cemex_weight(5852)            SD40 core, 5.85 MWh
%   W = cemex_weight([4000 8000], 'SD40')
% Battery-proportional items, per kWh (worksheet 6-column case, 9,375 kWh):
%   packs 1,200 kg per 195.3125 kWh pack; steel racks 5,336 lb per column; BTMS 100 kg (15 kW unit) per column;
%   one column = 8 packs = 1,562.5 kWh.
% Fixed items, lb (SD40 core): frame 132,775; trucks 2 x 39,500; 6 DC traction motors 60,000; compressor 2,325;
%   plow 1,200; MEC (DC) 3,200; DB grids 2,300; DB fans 700; charger + filter 4,409; pantographs 1,940;
%   choppers 2,450; VMS 15; LCC 50.
% The worksheet lists but does not weigh: AC inverter, ducting / cables / busbars, circuit breakers, contactor
% panels, pantograph bus bars, cab, "all other parts". W.total_lb is therefore a lower bound; W.unweighed lists them.
% Check: E = 9,375 kWh gives 450,689 lb, the worksheet's 6-column SD40 total.
if nargin < 2, core = 'SD40'; end
kg = 0.453592;
col_kWh = 8*195.3125;
per_kWh = (1200/kg/195.3125) + 5336/col_kWh + (100/kg)/col_kWh;   % lb/kWh: packs + racks + BTMS
switch upper(core)
    case 'SD40'
        fixed = struct('frame', 132775, 'trucks', 79000, 'traction_motors', 60000, 'compressor', 2325, 'plow', 1200, ...
            'mec', 3200, 'db_grids', 2300, 'db_fans', 700, 'charger_filter', 4409, 'pantographs', 1940, ...
            'choppers', 2450, 'vms', 15, 'lcc', 50);
    case 'AC44'
        fixed = struct('frame', 173970, 'trucks', 79000, 'traction_motors', 81600, 'compressor', 2325, 'plow', 1200, ...
            'mec', 1000, 'db_grids', 2300, 'db_fans', 700, 'charger_filter', 4409, 'pantographs', 1940, ...
            'choppers', 2450, 'vms', 15, 'lcc', 50);
    otherwise
        error('core must be SD40 or AC44');
end
f = fieldnames(fixed);
fixed_lb = sum(cellfun(@(n) fixed.(n), f));
W.core = upper(core);
W.E_kWh = E_kWh;
W.columns = E_kWh/col_kWh;
W.battery_lb = per_kWh*E_kWh;
W.fixed_lb = fixed_lb;
W.total_lb = fixed_lb + W.battery_lb;
W.axle_lb = W.total_lb/6;
W.lb_per_kWh = per_kWh;
W.fixed = fixed;
W.unweighed = ["AC inverter", "ducting, cables, busbars", "circuit breakers", "contactor panels", ...
    "pantograph bus bars", "cab", "all other parts"];
end
