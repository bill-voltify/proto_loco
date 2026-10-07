function F = load_fault_table(src)
% LOAD_FAULT_TABLE  Read a fault table (CSV/XLSX path or table). Columns:
%   fault_id, fmea, description, channel, active_value, t_start_s, t_end_s, enabled (0/1)
% Channels: n_mtm fan_pe fan_cd pump_pe pump_bat n_ax_on n_str dT_sense_K blower_ok
%           comms_ok aux_ok chg_derate estop classA  (see loco_system_params).
if istable(src), F = src; else, F = readtable(src, 'TextType', 'string'); end
if ~ismember('enabled', F.Properties.VariableNames), F.enabled = ones(height(F), 1); end
F.channel = string(F.channel);
F.fault_id = string(F.fault_id);
end
