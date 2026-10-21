import numpy as np, json, sys
K0=273.15
MODEL_REV='RevE'
MODEL_REV_DATE='2026-10-21'
# Per-string resistance options (Rev E). Cells at 25 C: R0 416*0.13 = 54.08 mOhm, R1 416*0.062 = 25.79 mOhm (79.87 mOhm total).
#   'vms'   (Rev E default): +10.63 mOhm per string outside the cells (contactors, fuse, shunt, cabling) -> 90.5 mOhm total
#           at 25 C, the per-string value the VMS uses (Power_Sequencing 4.8). Heat goes to ambient, not the cells.
#   'cells' : 0 (Rev D).
#   'bench' : +123.42 mOhm -> 177.5 mOhm ohmic, CO-2 bench close 2026-10-15 (VB-11); upper-bound sensitivity, basis unconfirmed.
R_EXT_STR={'vms':90.5e-3-416*(0.13e-3+0.062e-3),'cells':0.0,'bench':177.5e-3-416*0.13e-3}

def params(T_amb_C=25, T0_C=25, m_trail=0.0, soc0=0.9, I_chg_bms=1884.0, bms='jinko', baseline='phase2', r_string='vms'):
    P=dict(
    Ns=416,Np=12,Qc=314*3600*12,R0c=0.13e-3,R1c=0.062e-3,Rbus=1.0e-3,R_ext_str=0.0,BR=2257.0,Tref=298.15,
    SOC=[0,0.05,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,0.95,1],
    OCV=[2.90,3.10,3.18,3.22,3.25,3.27,3.29,3.30,3.31,3.33,3.35,3.40,3.55],
    G=62/15,rw=0.508,R_m=0.035,a_loss=2.5,b_loss=2.38e-3,Kphi=9.0,I0=600.,If_min=50.,flux='legacy',
    m_loco=270000*0.453592,m_trail=m_trail,Crr=0.002,CdA=8,
    eta_aux=0.96,P_trac_max=4*536e3,I_dis=1884.,I_chg_bms=I_chg_bms,I_hw=2500.,eta_drv=0.88,mu=0.25,
    soc_max=0.95,soc_band=0.02,soc0=soc0,
    T_amb=T_amb_C+K0,T0=T0_C+K0,
    C_bat=3.01e7,UA_bc=5000.,UA_benv=300.,C_bc=1.28e6,
    N_mtm=4,Q_mtm=12.5e3,T_cs_ref=50+K0,k_cap=0.02,T_cs_cut=65+K0,dT_cut=5.,
    COP_ref=3.0,k_cop=0.05,COP_min=1.2,Kp_chill=20e3,
    T_cool_set=22+K0,T_cool_on=28+K0,T_cool_off=26.5+K0,Q_heat_max=24e3,T_heat_on=12+K0,T_heat_off=13.5+K0,
    C_cd=2.2e5,UA_cd=2810.,mcp_cd=5880.,C_pe=5e5,UA_pe=2834.,mcp_pe=13300.,mcp_chg=3600.,mcp_chop=1430.,mcp_inv=950.,
    eta_chg=0.9934,k_aux_pe=0.08,k_inv=0.02,Q_pe_idle=1500.,C_mot=1.5e6,UA_mot=276.,
    P_fan_cd=7e3,P_fan_pe=7e3,P_pump=1.5e3,P_hpump=0.0,T_fan_on=35+K0,dT_fan=10.,tau_m=5.,f_ram=0.2,
    baseline=baseline,model_rev='Phase2')
    if baseline=='revE':
        # POC Power Budget Rev B alignment (2026-10-08), Rev C drivetrain (2026-10-15), Rev D PE loop (KULI 2026-10-09)
        P.update(Q_heat_max=12e3,Q_mtm=12e3,k_cop=0.10,COP_min=1.5,mcp_chop=1180.,mcp_inv=1100.)
        P.update(rw=42/2*0.0254,flux='d77_chart',a_loss=1580/1170+0.339,b_loss=3.57e-4)
        # Rev E (2026-10-21), VMS Locomotive_Equipment_List 10-20: 4 BTMS + 3 PE SPAL pumps (350 W) + 8 MTM internal pumps (60 W)
        # via DCC65M24 (93 %); heater coolant pump (Bosch PCE, PDM R7) 50 W placeholder while the heater runs.
        P.update(P_pump=(7*350+8*60)/0.93,P_hpump=50.,R_ext_str=R_EXT_STR[r_string],model_rev=MODEL_REV,r_string=r_string)
    elif baseline!='phase2':
        raise ValueError("baseline must be 'phase2' or 'revE'")
    if bms=='jinko':
        P.update(T_hot_L1=45+K0,T_hot_L2=50+K0,T_cchg_L1=5+K0,T_cchg_L2=3+K0,T_cdis_L1=5+K0,T_cdis_L2=3+K0)
    else:
        P.update(T_hot_L1=45+K0,T_hot_L2=50+K0,T_cchg_L1=5+K0,T_cchg_L2=0+K0,T_cdis_L1=-10+K0,T_cdis_L2=-20+K0)
    P['m_tot']=P['m_loco']+m_trail; P['m_eff']=1.08*P['m_loco']+1.03*m_trail
    wn,z=0.2,0.8; P['Kp_v']=2*z*wn*P['m_eff']; P['Ki_v']=wn**2*P['m_eff']
    return P
I_tab=np.arange(0,1801,50.)
def Kphi_of_I(P,I):
    I=np.maximum(I,P['If_min'])
    if P['flux']=='d77_chart': return 9.488*I/(299+I)
    return P['Kphi']*(1-np.exp(-I/P['I0']))
def T_of_I(P,I): return Kphi_of_I(P,I)*I
def clamp(x,a,b): return min(max(x,a),b)

# Fault channels (as Phase 3 fault_library.csv): n_mtm fan_pe fan_cd pump_pe pump_bat blower_ok comms_ok aux_ok
NOMINAL=dict(n_mtm=4.,fan_pe=1.,fan_cd=1.,pump_pe=1.,pump_bat=1.,blower_ok=1.,comms_ok=1.,aux_ok=1.)
VMS_LOSS=[('aux_ok',0.),('comms_ok',0.),('pump_pe',0.05),('pump_bat',0.),('fan_pe',0.),('fan_cd',0.),('n_mtm',0.)]
def fault_rows(rows,t0,t1): return [dict(channel=c,value=v,t0=t0,t1=t1) for c,v in rows]
def channels(faults,t):
    f=dict(NOMINAL)
    for r in faults:
        if r['t0']<=t<r['t1']: f[r['channel']]=r['value']
    return f

def simulate(P,U,t_end,dt=0.5,faults=()):
    Tt=T_of_I(P,I_tab)
    tU=U[:,0]
    n=int(t_end/dt)+1
    tg=np.arange(n)*dt
    VR=np.interp(tg,tU,U[:,1])*0.44704; GR=np.interp(tg,tU,U[:,2]); PA=np.interp(tg,tU,U[:,3]); PC=np.interp(tg,tU,U[:,4])
    v=0.;xi=0.;soc=P['soc0'];Tc=Tb=P['T0'];Tcd=Tpe=Tm=P['T_amb'];mc=mh=0.;v1=0.
    R1n=P['Ns']*P['R1c']/P['Np']; C1=30/R1n
    out={k:np.zeros(n) for k in ['t','v','soc','ib','Tc','Tb','Tcs','Tcd','Tpe_sup','Tchg','Tchop','Tinv','Tm','Ptms','Qc','Qh','Qb','Qext','Qpe','kdis','kchg','pchg','ia','vt','paux']}
    Ptms=0.; fr=P['f_ram']
    for k in range(n):
        t=k*dt
        F=channels(faults,t) if faults else NOMINAL
        tms=F['aux_ok']; trac=F['comms_ok']
        vref=VR[k]; grade=GR[k]; Paux=PA[k]*tms; Pchg_cmd=PC[k]*trac  # aux_ok = 0 (750 V aux converter lost) sheds the aux load (Rev E; Phase 3 Power Budget gates the override too)
        # BMS
        khot=clamp((P['T_hot_L2']-Tc)/(P['T_hot_L2']-P['T_hot_L1']),0,1)
        kdis=khot*clamp((Tc-P['T_cdis_L2'])/(P['T_cdis_L1']-P['T_cdis_L2']),0,1)
        kchg=khot*clamp((Tc-P['T_cchg_L2'])/(P['T_cchg_L1']-P['T_cchg_L2']),0,1)
        fT=np.exp(P['BR']*(1/Tc-1/P['Tref']))
        R0cell=P['Ns']*P['R0c']*fT/P['Np']+P['Rbus']; Rext=P['R_ext_str']/P['Np']
        R0=R0cell+Rext; R1=R1n*fT
        ocv=P['Ns']*np.interp(soc,P['SOC'],P['OCV'])
        Vb=ocv-v1  # approx terminal before i*R0
        # traction (comms_ok = 0: State Manager FAULT, no traction; friction braking only)
        e=vref-v; TEraw=P['Kp_v']*e+xi
        vabs=max(abs(v),0.5)
        Pdis=min(P['P_trac_max'],P['I_dis']*kdis*max(Vb,100)*P['eta_drv'])
        TEadh=P['mu']*P['m_loco']*9.81
        TEmax=min(TEadh,Pdis/vabs)*trac
        TE=clamp(TEraw,-TEadh,TEmax)
        if TE<0: Ffric=-TE; TEm=0.
        else: Ffric=0.; TEm=TE
        if vref<0.01 and abs(v)<0.05: xi+= -xi*dt
        elif (TEraw>TEmax and e>0) or (TEraw<-TEadh and e<0): pass
        else: xi+=P['Ki_v']*e*dt
        Tm_ax=TEm/4*P['rw']/P['G']; ia=float(np.interp(Tm_ax,Tt,I_tab))
        Pel=TEm*max(v,0)/P['eta_drv'] if v>0.01 else 4*(P['a_loss']*ia+P['b_loss']*ia**2)+4*P['R_m']*ia**2
        Pmech_loss=4*(P['a_loss']*ia+P['b_loss']*ia**2)
        Pauxin=(Paux+Ptms)/P['eta_aux']
        # charger
        fsoc=clamp((P['soc_max']-soc)/P['soc_band'],0,1)
        ich=min(max(Pchg_cmd,0)/max(Vb,100),P['I_hw'],P['I_chg_bms']*kchg)*fsoc
        Pnet=Pel+Pauxin
        # solve battery current with charger current injection: i = idis - ich
        idis=(Vb-np.sqrt(max(Vb**2-4*R0*Pnet,1)))/(2*R0) if Pnet>0 else Pnet/Vb
        i=idis-ich
        vt=ocv-i*R0-v1
        pchg=ich*vt
        Qb=i**2*R0cell+v1**2/R1
        Qext=i**2*Rext
        soc-= i*dt/P['Qc']; v1+= (i/C1-v1/(R1*C1))*dt
        # vehicle
        Fr=P['m_tot']*9.81*(P['Crr']*np.tanh(v/0.1)+grade/100)+0.5*1.225*P['CdA']*v*abs(v)+Ffric*np.tanh(v/0.1)
        v+= (TEm-Fr)/P['m_eff']*dt; v=max(v,0)
        # thermal
        Qrad_cd=P['UA_cd']*(fr+(1-fr)*F['fan_cd'])*(Tcd-P['T_amb']); Tcs=Tcd-Qrad_cd/P['mcp_cd']
        fcap=clamp(1-P['k_cap']*(Tcs-P['T_cs_ref']),0,1.2)*clamp((P['T_cs_cut']-Tcs)/P['dT_cut'],0,1)
        Qav=clamp(F['n_mtm'],0,P['N_mtm'])*P['Q_mtm']*fcap
        Qc=tms*mc*clamp(P['Kp_chill']*(Tc-P['T_cool_set']),0,Qav)
        COP=max(P['COP_min'],P['COP_ref']-P['k_cop']*(Tcs-P['T_cs_ref']))
        Pcomp=Qc/COP; Qh=tms*mh*P['Q_heat_max']
        fq=max(F['pump_pe'],0.05); UAbc=P['UA_bc']*(0.2+0.8*F['pump_bat'])
        Qchop=Pmech_loss; Qchg=max(pchg,0)*(1/P['eta_chg']-1)
        fpe=clamp((Tpe-P['T_fan_on'])/P['dT_fan'],0.1,1)
        Ptms=Pcomp+Qh+P['P_pump']*tms+P['P_hpump']*mh*tms+P['P_fan_cd']*mc*tms*F['fan_cd']+P['P_fan_pe']*fpe*F['fan_pe']
        Qpe=Qchop+Qchg+P['k_aux_pe']*Pauxin+P['Q_pe_idle']
        Qrad_pe=P['UA_pe']*(fr+(1-fr)*F['fan_pe'])*min(1,0.2+0.8*F['pump_pe'])*(Tpe-P['T_amb']); Tsup=Tpe-Qrad_pe/(P['mcp_pe']*fq)
        rec=dict(t=t,v=v/0.44704,soc=soc,ib=i,Tc=Tc,Tb=Tb,Tcs=Tcs,Tcd=Tcd,Tpe_sup=Tsup,Tchg=Tsup+Qchg/(P['mcp_chg']*fq),
                 Tchop=Tsup+Qchop/4/(P['mcp_chop']*fq),Tinv=Tsup+P['k_inv']*Pauxin/(P['mcp_inv']*fq),Tm=Tm,Ptms=Ptms,Qc=Qc,Qh=Qh,Qb=Qb,Qext=Qext,Qpe=Qpe,kdis=kdis,kchg=kchg,pchg=pchg,ia=ia,vt=vt,paux=Pauxin)
        for kk,vv in rec.items(): out[kk][k]=vv
        Tc+= (Qb-UAbc*(Tc-Tb)-P['UA_benv']*(Tc-P['T_amb']))/P['C_bat']*dt
        Tb+= (UAbc*(Tc-Tb)-Qc+Qh)/P['C_bc']*dt
        Tcd+= (Qc+Pcomp-Qrad_cd)/P['C_cd']*dt
        Tpe+= (Qpe-Qrad_pe)/P['C_pe']*dt
        Tm+= (P['R_m']*ia**2-P['UA_mot']*(0.15+0.85*F['blower_ok']*F['aux_ok'])*(Tm-P['T_amb']))/P['C_mot']*dt
        mct=1. if (Tc>=P['T_cool_on'] or (mc>0.5 and Tc>P['T_cool_off'])) else 0.
        mht=1. if (Tc<=P['T_heat_on'] or (mh>0.5 and Tc<P['T_heat_off'])) else 0.
        mc+=(mct-mc)/P['tau_m']*dt; mh+=(mht-mh)/P['tau_m']*dt
    return out
