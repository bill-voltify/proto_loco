function fix_fcn_sizes
lib = 'loco_native_lib';
if ~bdIsLoaded(lib), load_system(fullfile(pwd,'native','lib',[lib '.slx'])); end
set_param(lib,'Lock','off');
S = {
 'Thermal Plant/heat_inputs', 'u',      '[15 1]'
 'Thermal Plant/outlets',     'Tcd',    '[1 1]'
 'Thermal Plant/outlets',     'Tpe',    '[1 1]'
 'Thermal Plant/outlets',     'u',      '[15 1]'
 'TMS Controller/tms',        'u',      '[9 1]'
 'LCC/lcc',                   'u',      '[9 1]'
 'Charger FW/chg',            'u',      '[5 1]'
 'Chopper FW/fw',             'TE_ref', '[1 1]'
 'Chopper FW/fw',             'i_a',    '[1 1]'
 'Chopper FW/fw',             'v',      '[1 1]'
 'Chopper FW/fw',             'Vdc',    '[1 1]'
};
for k = 1:size(S,1)
    p = [lib '/' S{k,1}];
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',p);
    if isempty(ch)
        fprintf('NOT FOUND: %s\n',p);
        continue
    end
    d = ch.find('-isa','Stateflow.Data','Name',S{k,2},'Scope','Input');
    if isempty(d)
        fprintf('NO INPUT %s in %s\n',S{k,2},p);
        continue
    end
    d.Props.Array.Size = S{k,3};
    fprintf('%-28s %-7s size %s\n',S{k,1},S{k,2},S{k,3});
end
save_system(lib);
fprintf('Library saved.\n');
end