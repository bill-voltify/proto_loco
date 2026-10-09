needP = ~evalin('base','exist(''P'',''var'')');
if ~needP
    needP = ~isstruct(evalin('base','P')) || ~isfield(evalin('base','P'),'batt');
end
if needP
    fprintf('P missing or overwritten: rebuilding with build_loco_system...\n');
    evalin('base','build_loco_system;');
end
P = evalin('base','P');

PN = struct();
PN.nstr = 6;
PN.str.Ns = P.batt.Ns;
PN.str.Np = P.batt.Np/PN.nstr;
PN.str.Q_Ah = P.batt.Q_cell*PN.str.Np;
PN.str.soc0 = P.batt.soc0;

PN.SOC = P.batt.SOC_tab(:)';
PN.T = [233.15 253.15 273.15 298.15 318.15 333.15];
fT = exp(P.batt.B_R*(1./PN.T - 1/P.batt.T_ref));
nS = numel(PN.SOC); nT = numel(PN.T);

PN.str.V0   = repmat(PN.str.Ns*P.batt.OCV_tab(:),1,nT);
PN.str.R0   = repmat(PN.str.Ns*P.batt.R0_cell/PN.str.Np*fT,nS,1);
PN.str.R1   = repmat(PN.str.Ns*P.batt.R1_cell/PN.str.Np*fT,nS,1);
PN.str.tau1 = P.batt.tau1*ones(nS,nT);
PN.str.AH   = PN.str.Q_Ah*ones(1,nT);

PN.bus.R = P.batt.R_bus;

I1C = PN.str.Q_Ah;
PN.bench.I = [0 0; 10 0; 10 I1C; 1810 I1C; 1810 0; 2400 0; 2400 -0.5*I1C; 3000 -0.5*I1C];

assignin('base','PN',PN);
assignin('base','I_bench',PN.bench.I);

fprintf('\n== Native string params ==\n');
fprintf('Ns=%d  Np/string=%g  Q=%g Ah  soc0=%g\n',PN.str.Ns,PN.str.Np,PN.str.Q_Ah,PN.str.soc0);
fprintf('OCV @ soc0 = %.1f V\n',interp1(PN.SOC,PN.str.V0(:,4),PN.str.soc0));
fprintf('R0 @25C = %.2f mOhm   R1 @25C = %.2f mOhm\n',PN.str.R0(1,4)*1e3,PN.str.R1(1,4)*1e3);
fprintf('1C = %g A\n',I1C);