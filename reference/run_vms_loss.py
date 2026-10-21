"""E7 VMS-loss scenario (Rev E): 750 V aux collapse at peak heat. Mirrors loco_system/run_vms_loss.m.
VMS crash -> Zekalabs converters stop after 1.5 s CAN silence -> 750 V bus down: SPAL pumps (BTMS 24V PS), MTMs (BTMS 12V PS),
EMP fans, heater, ACH; LCC drops traction after 200 ms (VB-28). Fault rows = VMS_LOSS in faults/fault_library.csv.
Onset = time of the peak PE device outlet temperature (chopper, charger, inverter) in the no-fault run. Observes 60 min after onset.
Usage: python run_vms_loss.py [--r_string vms|cells|bench]"""
import numpy as np, sys, os, argparse, json
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from ref_model import params, simulate, K0, VMS_LOSS, fault_rows
from scenarios import scenarios, build_U
LIM=dict(Tchop=63.,Tinv=60.,Tchg=55.,Tc=45.,Tcd=65.)
ap=argparse.ArgumentParser(); ap.add_argument('--r_string',default='vms',choices=['vms','cells','bench']); a=ap.parse_args()
S={s['name']:s for s in scenarios('revE')}
RUNS=[('S6_notch8_15min',40,None),('S6_notch8_15min',45,None),('S9_dyncharge_2p1MW_demo',40,None),
      ('S6_notch8_15min',40,10.),('S6_notch8_15min',40,60.),('S6_notch8_15min',40,300.)]
OBS=3600.
rows=[]
SETTLE=5.  # s; skip the first samples after onset (the aux power feeding the inverter-node estimate lags one step)
def peak_after(o,key,t0): m=o['t']>=t0+SETTLE; return o[key][m].max()-K0
for name,Ta,outage in RUNS:
    s=S[name]; U=build_U(s['bp'])
    P=params(T_amb_C=Ta,T0_C=Ta,m_trail=s['m_trail'],soc0=s['soc0'],I_chg_bms=s['I_chg'],baseline='revE',r_string=a.r_string)
    base=simulate(P,U,U[-1,0],dt=1.0)
    t_on=float(base['t'][np.argmax(np.maximum(np.maximum(base['Tchop'],base['Tchg']),base['Tinv']))])
    t_end=max(U[-1,0],t_on+OBS)
    Ue=np.vstack([U,[t_end]+list(U[-1,1:])]) if t_end>U[-1,0] else U
    t1=1e9 if outage is None else t_on+outage
    o=simulate(P,Ue,t_end,dt=1.0,faults=fault_rows(VMS_LOSS,t_on,t1))
    b2=simulate(P,Ue,t_end,dt=1.0)
    r=dict(scn=name,Ta=Ta,outage_s='permanent' if outage is None else outage,onset_s=t_on)
    for k in ['Tchop','Tinv','Tchg','Tc','Tcd']:
        kk='Tpe_sup' if k=='Tsup' else k
        r[k+'_at_onset']=o[k][o['t']>=t_on][0]-K0
        r[k+'_peak_after']=peak_after(o,k,t_on)
        r[k+'_peak_after_nofault']=peak_after(b2,k,t_on)
        over=(o[k]-K0>LIM[k])&(o['t']>=t_on+SETTLE)
        r[k+'_min_over_limit']=over.sum()*1.0/60
    r['Tsup_peak_after']=peak_after(o,'Tpe_sup',t_on)
    rows.append(r)
    print(f"{name:24s} {Ta}C outage {r['outage_s']!s:>9} onset {t_on:6.0f}s | chop {r['Tchop_at_onset']:5.1f}->{r['Tchop_peak_after']:5.1f} (nofault {r['Tchop_peak_after_nofault']:5.1f}, lim 63, {r['Tchop_min_over_limit']:4.1f} min over) "
          f"inv {r['Tinv_peak_after']:5.1f} chg {r['Tchg_peak_after']:5.1f} sup {r['Tsup_peak_after']:5.1f} cell {r['Tc_at_onset']:5.1f}->{r['Tc_peak_after']:5.1f}",flush=True)
fn=os.path.join(os.path.dirname(os.path.abspath(__file__)),f'vms_loss_results_revE_{a.r_string}.json')
json.dump(rows,open(fn,'w'),indent=1); print('wrote',os.path.basename(fn))
