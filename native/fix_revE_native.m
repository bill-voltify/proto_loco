function fix_revE_native
% FIX_REVE_NATIVE  Apply Model Rev E (2026-10-21) to loco_native_lib, then rebuild loco_native.
%  1. TRB String / Contactor: R_closed = PN.str.R_ext (string resistance outside the cells; was 0.1e-3 fixed).
%  2. TMS Controller / tms: adds the heater coolant pump, TH.P_hpump*mh*tms_en, to Ptms.
% Safe to run twice. Run from the repo root after loco_system_params / native_params carry the Rev E fields:
%   fix_revE_native; build_loco_native;
addpath(genpath(fullfile(pwd,'native')));
evalin('base','native_params;');
P = evalin('base','P');
assert(isfield(P.th,'P_hpump') && isfield(P.batt,'R_ext_str'), ...
    'P lacks Rev E fields: run build_loco_system (loco_system_params Rev E) first.');
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');

c = [lib '/TRB String/Contactor'];
old = get_param(c,'R_closed');
set_param(c,'R_closed','PN.str.R_ext');
fprintf('Contactor R_closed: %s -> PN.str.R_ext (%.2f mOhm)\n', old, evalin('base','PN.str.R_ext')*1e3);

ch = sfroot().find('-isa','Stateflow.EMChart','Path',[lib '/TMS Controller/tms']);
assert(~isempty(ch), 'TMS Controller/tms chart not found in %s', lib);
a = 'Ptms = Pcomp + Qh + TH.P_pump*tms_en + TH.P_fan_cd*mc*tms_en*fan_cd + TH.P_fan_pe*f_pe*en*fan_pe;';
b = 'Ptms = Pcomp + Qh + TH.P_pump*tms_en + TH.P_hpump*mh*tms_en + TH.P_fan_cd*mc*tms_en*fan_cd + TH.P_fan_pe*f_pe*en*fan_pe;';
if contains(ch.Script, b)
    fprintf('TMS Controller already has the heater pump term.\n');
else
    assert(contains(ch.Script, a), 'TMS Controller Ptms line not as built by build_lib_tms; edit by hand.');
    ch.Script = strrep(ch.Script, a, b);
    fprintf('TMS Controller: heater pump term added to Ptms.\n');
end
save_system(lib);
fprintf('Saved %s. Now run build_loco_native to refresh loco_native.slx (it copies voltify_loco_system.slx).\n', lib);
end
