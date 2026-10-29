function [T, info] = load_profile_trace(file, varargin)
% LOAD_PROFILE_TRACE  Measured run profile (Time_Seconds, Speed_MPH, Grade_Percent, Distance_Miles, Operation_State)
% -> loco_system trace. The measured speed becomes the speed reference; grade is used as recorded.
%   T = load_profile_trace('routes/mojave_northern_sd40_2_profile.csv', 'Tons', 2470, 'Ambient_C', 40)
% Name-value options:
%   Tons       trailing short tons (2470, Black Mountain loaded run)
%   Ambient_C  ambient (40)
%   Lead_s     READY time before the recorded start, so the HV bus is up before the first move (60)
%   Tail_s     READY time after the recorded stop (60)
%   Out        CSV path to write ('' = none)
here = fileparts(mfilename('fullpath'));
p = inputParser;
p.addParameter('Tons', 2470);
p.addParameter('Ambient_C', 40);
p.addParameter('Lead_s', 60);
p.addParameter('Tail_s', 60);
p.addParameter('Out', '');
p.parse(varargin{:});
o = p.Results;
f = char(file); if ~isfile(f), f = fullfile(here, f); end
S = readtable(f, 'TextType', 'string');
t = S.Time_Seconds + o.Lead_s;
v = S.Speed_MPH;
g = S.Grade_Percent;
t = [0; o.Lead_s - 1; t; t(end) + o.Tail_s];
v = [0; 0; v; 0];
g = [g(1); g(1); g; g(end)];
n = numel(t);
T = table(t, v, g, o.Ambient_C*ones(n, 1), o.Tons*ones(n, 1), strings(n, 1), zeros(n, 1), nan(n, 1), ...
    'VariableNames', {'time_s','speed_mph','grade_pct','ambient_C','trailing_tons','state','wire_kW','aux_override_kW'});
info.file = string(f);
info.miles = S.Distance_Miles(end);
info.duration_min = S.Time_Seconds(end)/60;
info.grade_range = [min(S.Grade_Percent), max(S.Grade_Percent)];
info.states = S.Operation_State;
info.locomotive = S.Locomotive(1);
info.t_profile = S.Time_Seconds + o.Lead_s;
if ~isempty(o.Out), writetable(T, o.Out); end
end
