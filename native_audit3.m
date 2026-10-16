p3 = 'voltify_loco_system'; load_system(p3);
pl = [p3 '/Plant'];

fprintf('\n== Inside Plant Inputs (under mask) ==\n');
b = find_system([pl '/Plant Inputs'],'LookUnderMasks','all','FollowLinks','on','SearchDepth',1);
for i = 2:numel(b)
    t = get_param(b{i},'BlockType');
    extra = '';
    switch t
        case 'Mux',       extra = ['Inputs=' get_param(b{i},'Inputs')];
        case 'Demux',     extra = ['Outputs=' get_param(b{i},'Outputs')];
        case 'Selector',  extra = ['Indices=' get_param(b{i},'Indices')];
        case 'Constant',  extra = ['Value=' get_param(b{i},'Value')];
        case 'Gain',      extra = ['Gain=' get_param(b{i},'Gain')];
        case 'Fcn',       extra = get_param(b{i},'Expression');
    end
    fprintf('%-30s %-15s %s\n',get_param(b{i},'Name'),t,extra);
end
try
    sf = find(sfroot,'-isa','Stateflow.EMChart');
    sf = sf(contains({sf.Path},'Plant Inputs'));
    for k = 1:numel(sf)
        fprintf('\n-- MATLAB Function: %s --\n%s\n',sf(k).Path,sf(k).Script);
    end
catch
end

base = fullfile(pwd,'loco_system','+locosys');
for n = {'io_demux','io_mux','battery','dclink'}
    fprintf('\n== %s.ssc ==\n',n{1});
    type(fullfile(base,[n{1} '.ssc']));
end