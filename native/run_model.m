function out = run_model(which,varargin)
switch lower(which)
 case 'phase3', mdl='voltify_loco_system';
 case 'native', mdl='loco_native';
 otherwise, error('phase3 | native');
end
out = sim(mdl,varargin{:});
end
