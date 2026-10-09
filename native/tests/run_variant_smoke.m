function run_variant_smoke
addpath(genpath(fullfile(pwd,'native')));
T = 60;
w = zeros(1,2); Y = cell(1,2);
plants = {'phase3','native'};
for k = 1:2
    tic;
    out = run_model(plants{k},'StopTime',num2str(T));
    w(k) = toc;
    Y{k} = lastY(out);
end
nm = {'v_mph','soc','vt','ib','vlink','ia','va','te','ff','pa','pc','idc','Tc','Tb','Tcs','Tcd', ...
      'Tsup','Tchg','Tchop','Tinv','Tm','ptms','qc','qh','qb','qpe','kd','kc'};
fprintf('\n== loco_native variant smoke test, %g s, default scenario ==\n',T);
fprintf('wall: phase3 %.1f s   native %.1f s\n',w(1),w(2));
fprintf('%3s %-6s %14s %14s\n','#','signal','Phase3','Native');
for j = 1:28
    fprintf('%3d %-6s %14.3f %14.3f\n',j,nm{j},Y{1}(j),Y{2}(j));
end
end

function y = lastY(out)
    y = nan(1,28);
    v = out.who;
    for k = 1:numel(v)
        s = out.get(v{k});
        try
            if isa(s,'timeseries'), d = squeeze(s.Data); else, d = []; end
            if isempty(d) && isa(s,'Simulink.SimulationData.Dataset')
                for j = 1:s.numElements
                    e = s.getElement(j); vv = e.Values;
                    if isa(vv,'timeseries')
                        dd = squeeze(vv.Data);
                        if any(size(dd) == 28), d = dd; break; end
                    end
                end
            end
            if any(size(d) == 28)
                if size(d,1) == 28, d = d'; end
                y = d(end,:); return
            end
        catch
        end
    end
end