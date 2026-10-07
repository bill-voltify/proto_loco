import numpy as np
ST=907.185
def build_U(bp, step=0.5):
    bp=np.array(bp,float); t=np.arange(0,bp[-1,0]+step/2,step)
    mph=np.interp(t,bp[:,0],bp[:,1]); grade=np.interp(t,bp[:,0],bp[:,2])
    paux=np.interp(t,bp[:,0],bp[:,3]); pchg=np.interp(t,bp[:,0],bp[:,4])
    en=(t>=2).astype(float)
    return np.column_stack([t,mph,grade,paux,pchg,en])
A0=30e3; AB=42e3
def scenarios():
    S=[]
    S.append(dict(name='S1_first_move',desc='Huntington first move fwd/rev, light engine, 3 mph',m_trail=0,soc0=0.5,I_chg=1884,maxstep=0.5,
      bp=[[0,0,0,A0,0],[20,0,0,A0,0],[50,3,0,A0+AB,0],[110,3,0,A0+AB,0],[140,0,0,A0+AB,0],[200,0,0,A0,0],[230,3,0,A0+AB,0],[290,3,0,A0+AB,0],[320,0,0,A0+AB,0],[400,0,0,A0,0]]))
    S.append(dict(name='S2_showcase1',desc='Showcase 1: light engine, 10 mph x 20 min',m_trail=0,soc0=0.5,I_chg=1884,maxstep=0.5,
      bp=[[0,0,0,A0,0],[20,0,0,A0,0],[80,10,0,A0+AB,0],[1280,10,0,A0+AB,0],[1340,0,0,A0+AB,0],[1500,0,0,A0,0]]))
    S.append(dict(name='S3_dyncharge_2p5MW',desc='Showcase 2: 0.5 mph, 2.5 MW wire, from 20% SOC',m_trail=0,soc0=0.2,I_chg=1884,maxstep=1,
      bp=[[0,0,0,A0,0],[20,0,0,A0,0],[60,0.5,0,A0+AB,0],[120,0.5,0,A0+AB,0],[150,0.5,0,A0+AB,2.5e6],[7800,0.5,0,A0+AB,2.5e6],[7900,0,0,A0,0],[8000,0,0,A0,0]]))
    S.append(dict(name='S4_dyncharge_3p0MW',desc='Demo-plan target: 0.5 mph, 3.0 MW wire, BMS limit raised to 2328 A',m_trail=0,soc0=0.2,I_chg=2328,maxstep=1,
      bp=[[0,0,0,A0,0],[20,0,0,A0,0],[60,0.5,0,A0+AB,0],[120,0.5,0,A0+AB,0],[150,0.5,0,A0+AB,3.0e6],[7800,0.5,0,A0+AB,3.0e6],[7900,0,0,A0,0],[8000,0,0,A0,0]]))
    S.append(dict(name='S5_cont_pull_10mph',desc='J-16/P-02: LC-3 (3,640 t, 0.5%) at 10 mph for 60 min',m_trail=3640*ST,soc0=0.9,I_chg=1884,maxstep=1,
      bp=[[0,0,0.5,A0,0],[20,0,0.5,A0,0],[320,10,0.5,A0+AB,0],[3920,10,0.5,A0+AB,0],[4100,0,0.5,A0+AB,0],[4200,0,0.5,A0,0]]))
    S.append(dict(name='S6_notch8_15min',desc='J-17/P-01: full power ~15+ min, LC-3 on 0.5%',m_trail=3640*ST,soc0=0.9,I_chg=1884,maxstep=1,
      bp=[[0,0,0.5,A0,0],[20,0,0.5,A0,0],[140,30,0.5,A0+AB,0],[1100,30,0.5,A0+AB,0],[1101,0,0.5,A0+AB,0],[1400,0,0.5,A0,0]]))
    cyc=[[0,0,0,A0,0],[600,0,0,A0,0],[660,6,0,A0+AB,0],[840,6,0,A0+AB,0],[900,0,0,A0+AB,0],[1200,0,0,A0,0],[1290,10,0,A0+AB,0],[1530,10,0,A0+AB,0],[1620,0,0,A0+AB,0],[1800,0,0,A0,0]]
    bp=[]
    for k in range(16):
        for r in cyc:
            if k>0 and r[0]==0: continue
            bp.append([r[0]+1800*k]+r[1:])
    S.append(dict(name='S7_switch_shift_8h',desc='8 h yard shift, LC-1 (1,430 t), 2 moves per 30 min',m_trail=1430*ST,soc0=0.9,I_chg=1884,maxstep=2,bp=bp))
    S.append(dict(name='S8_park_6h',desc='Parked 6 h, HV up, TMS active (preconditioning)',m_trail=0,soc0=0.6,I_chg=1884,maxstep=5,
      bp=[[0,0,0,10e3,0],[21600,0,0,10e3,0]]))
    return S
