% RUN_THERMAL_SWEEP  Phase 2: every scenario x ambient x initial condition.
% Edit the settings block, then run from the repo root. Outputs go to results/.
%   T0 policy 'soaked'  : pack starts at ambient (parked, no TMS)
%   T0 policy 'precond' : pack starts at 25 C (TMS ran before the duty)
root = fileparts(mfilename('fullpath'));
addpath(root);

% ---- settings -------------------------------------------------------------
ambients = [0 10 20 40 50];          % C
ic_list  = {'soaked','precond'};
bms       = 'jinko';                  % 'jinko' (as shipped) or 'cell_spec'
scn_pick = [];                      % [] = all, or e.g. [2 3 5]
plot_case = {'S3_dyncharge_2p5MW', 40, 'precond'};
% ---------------------------------------------------------------------------

S = proto_scenarios();
if ~isempty(scn_pick), S = S(scn_pick); end
mdl = build_proto_loco(false);
outdir = fullfile(root, 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end

rows = [];
runs = struct('scenario', {}, 'T_amb', {}, 'ic', {}, 'R', {});
n = numel(S)*numel(ambients)*numel(ic_list);
k = 0;
for ic = 1:numel(ic_list)
    for s = 1:numel(S)
        for a = 1:numel(ambients)
            k = k + 1;
            Ta = ambients(a);
            T0 = Ta;
            if strcmp(ic_list{ic}, 'precond'), T0 = 25; end
            P = proto_loco_params(struct('T_amb_C', Ta, 'T0_C', T0, 'm_trail', S(s).m_trail, ...
                'soc0', S(s).soc0, 'I_chg_bms', S(s).I_chg_bms, 'bms', bms));
            U = S(s).U;
            in = Simulink.SimulationInput(mdl);
            in = in.setVariable('P', P);
            in = in.setVariable('U', U);
            in = in.setModelParameter('StopTime', num2str(U(end,1)), 'MaxStep', num2str(S(s).max_step));
            fprintf('[%2d/%2d] %-20s %3d C %-7s ... ', k, n, S(s).name, Ta, ic_list{ic});
            tic;
            try
                out = sim(in);
                if ~isempty(out.ErrorMessage), error(out.ErrorMessage); end
                R = proto_unpack(out.Y);
                M = eval_thermal_run(R, P, S(s), U);
                runs(end+1) = struct('scenario', S(s).name, 'T_amb', Ta, 'ic', ic_list{ic}, 'R', R); %#ok<SAGROW>
            catch ME
                M = blank_metrics(S(s).name, Ta, T0, ME.message);
            end
            M.ic = string(ic_list{ic});
            fprintf('%s (%.0f s) %s\n', M.verdict, toc, M.limit);
            rows = [rows; struct2table(M, 'AsArray', true)]; %#ok<AGROW>
        end
    end
end

stamp = datestr(now, 'yyyymmdd_HHMM'); %#ok<TNOW1,DATST>
writetable(rows, fullfile(outdir, ['thermal_sweep_' stamp '.csv']));
save(fullfile(outdir, ['thermal_sweep_' stamp '.mat']), 'rows', 'runs', 'ambients', 'ic_list', 'bms');

% ---- verdict heatmaps -----------------------------------------------------
lvl = containers.Map({'OPTIMAL','OK','DERATED','FAIL','ERROR'}, {4, 3, 2, 1, 0});
figure('Name', 'Thermal sweep verdicts', 'Position', [100 100 1100 420]);
for ic = 1:numel(ic_list)
    Z = nan(numel(S), numel(ambients));
    for s = 1:numel(S)
        for a = 1:numel(ambients)
            r = rows(rows.scenario == S(s).name & rows.T_amb == ambients(a) & rows.ic == ic_list{ic}, :);
            if ~isempty(r), Z(s, a) = lvl(char(r.verdict(1))); end
        end
    end
    subplot(1, numel(ic_list), ic);
    imagesc(Z, [0 4]);
    colormap([0.5 0.5 0.5; 0.85 0.2 0.2; 0.95 0.65 0.1; 0.6 0.8 0.4; 0.2 0.6 0.3]);
    set(gca, 'XTick', 1:numel(ambients), 'XTickLabel', compose('%d C', ambients), ...
             'YTick', 1:numel(S), 'YTickLabel', strrep({S.name}, '_', '\_'));
    title(sprintf('%s start', ic_list{ic}));
    cb = colorbar; cb.Ticks = 0:4; cb.TickLabels = {'ERROR','FAIL','DERATED','OK','OPTIMAL'};
end

% ---- traces for one case ----------------------------------------------------
i = find(strcmp({runs.scenario}, plot_case{1}) & [runs.T_amb] == plot_case{2} & strcmp({runs.ic}, plot_case{3}), 1);
if ~isempty(i)
    plot_thermal_run(runs(i).R, sprintf('%s, %d C, %s', plot_case{1}, plot_case{2}, plot_case{3}));
end
disp(rows(:, {'scenario','ic','T_amb','verdict','limit','Tcell_min','Tcell_max','Tsup_max','Tchg_sup_max','Tinv_out_max','Tcond_max','k_dis_min','k_chg_min','soc_end','E_tms_kWh'}));

function M = blank_metrics(name, Ta, T0, msg)
f = {'Tcell_max','Tcell_min','Tcell_end','Tsup_max','Tchg_out_max','Tchg_sup_max','Tchop_out_max', ...
     'Tinv_out_max','Tcond_max','Tmotor_max','k_dis_min','k_chg_min','q_bat_max_kW','q_chill_max_kW', ...
     'E_tms_kWh','E_bat_out_kWh','E_bat_in_kWh','soc_end','v_max'};
M.scenario = string(name);
M.T_amb = Ta;
M.T0 = T0;
for k = 1:numel(f), M.(f{k}) = NaN; end
M.speed_ok = false;
M.verdict = "ERROR";
M.limit = string(msg);
M.pe_margin_K = NaN;
end
