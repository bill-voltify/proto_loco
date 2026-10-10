function verify_pe_update
here = fullfile(pwd,'loco_system');
addpath(here); addpath(pwd);
clear loco_system_params
Pp = loco_system_params(struct('baseline','poc'));
P2 = loco_system_params(struct('baseline','phase2'));
fprintf('\n== P.th values ==\n');
fprintf('%-10s  poc %7g   phase2 %7g\n','mcp_chop',Pp.th.mcp_chop,P2.th.mcp_chop);
fprintf('%-10s  poc %7g   phase2 %7g\n','mcp_inv',Pp.th.mcp_inv,P2.th.mcp_inv);

m = 'loco_native';
if ~bdIsLoaded(m), load_system(fullfile(pwd,'native',[m '.slx'])); end
b3 = [m '/Plant/Phase3/Locomotive'];
fprintf('\n== Phase 3 block expressions ==\n');
for nm = {'th_mcp_chop','th_mcp_inv'}
    try
        fprintf('%-12s = %s\n',nm{1},get_param(b3,nm{1}));
    catch e
        fprintf('%-12s : %s\n',nm{1},e.message);
    end
end
fprintf('\n== Native Thermal Plant / TMS mask ==\n');
try, fprintf('Thermal Plant TH = %s\n',get_param([m '/Plant/Native/TP'],'TH')); catch e, fprintf('%s\n',e.message); end
try, fprintf('TMS Controller TH = %s\n',get_param([m '/Plant/Native/TMS'],'TH')); catch e, fprintf('%s\n',e.message); end

fprintf('\n== Fault library ==\n');
F = load_fault_table(fullfile(here,'faults','fault_library.csv'));
r = F(F.fault_id == "PE_PUMP_1OF3",:);
disp(r);
ok = Pp.th.mcp_chop == 1180 && Pp.th.mcp_inv == 1100 && P2.th.mcp_chop ~= 1180 && height(r) == 1;
if ok, fprintf('RESULT: PASS\n'); else, fprintf('RESULT: CHECK\n'); end
end