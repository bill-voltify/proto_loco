function TR = load_trace(src, opts)
% LOAD_TRACE  Read a duty trace (CSV/XLSX path or table) into the matrices the model reads.
% Columns (header names; only time_s and speed_mph are required):
%   time_s, speed_mph, grade_pct, ambient_C, trailing_tons (short tons), state, wire_kW, aux_override_kW
% state: SLEEP | STANDBY | READY | TRACTION | CHARGING (name or 0..4). Blank/missing = automatic:
%   SLEEP for t < 2 s, CHARGING when wire_kW > 0, TRACTION when speed > 0, else READY.
% aux_override_kW: blank or < 0 = use load_budget.csv; >= 0 replaces the budget (regression use).
% opts.ambient_C (scalar) overrides the ambient column; opts.ambient_offset_C adds to it.
if nargin < 2, opts = struct(); end
if istable(src), T = src; else, T = readtable(src, 'TextType', 'string'); end
v = T.Properties.VariableNames;
n = height(T);
col = @(name, def) getcol(T, v, name, def, n);
t = col('time_s', NaN);
assert(~any(isnan(t)), 'trace needs a time_s column');
mph = col('speed_mph', 0);
grade = col('grade_pct', 0);
amb = col('ambient_C', 25);
tons = col('trailing_tons', 0);
wire = col('wire_kW', 0);
ovr = col('aux_override_kW', -1);
ovr(isnan(ovr)) = -1;
if isfield(opts, 'ambient_C') && ~isempty(opts.ambient_C), amb(:) = opts.ambient_C; end
if isfield(opts, 'ambient_offset_C'), amb = amb + opts.ambient_offset_C; end

names = {'SLEEP','STANDBY','READY','TRACTION','CHARGING'};
st = nan(n, 1);
if ismember('state', v)
    s = T.state;
    if isnumeric(s)
        st = double(s);
    else
        s = upper(strtrim(string(s)));
        for k = 1:numel(names), st(s == names{k}) = k - 1; end
    end
end
auto = isnan(st);
st(auto & t < 2) = 0;
st(auto & t >= 2) = 2;
st(auto & t >= 2 & mph > 0) = 3;
st(auto & t >= 2 & wire > 0) = 4;

[t, i] = sort(t);
TR.SCN = [t, mph(i), grade(i), amb(i), tons(i), wire(i), ovr(i)];
TR.SCN_D = [t, st(i)];
TR.t_end = t(end);
TR.ambient0_C = amb(i(1));
if ischar(src) || isstring(src), TR.name = string(src); else, TR.name = "table"; end
end

function x = getcol(T, v, name, def, n)
if ismember(name, v)
    x = double(T.(name));
    x(isnan(x)) = def;
else
    x = def*ones(n, 1);
end
end
