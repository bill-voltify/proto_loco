import numpy as np, sys, argparse, json
import os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from ref_model import params, simulate, K0
from scenarios import scenarios, build_U
ap=argparse.ArgumentParser(description='Reference-model ambient sweep. phase2 writes expected_results.json (regression reference, frozen); revE writes expected_results_revE.json.')
ap.add_argument('--baseline',default='phase2',choices=['phase2','revE'])
ap.add_argument('--r_string',default='vms',choices=['vms','cells','bench'])
a=ap.parse_args()
amb=[0,10,20,40,50]
rows=[]
for ic in ['soaked','precond']:
  for s in scenarios(a.baseline):
    U=build_U(s['bp']); tend=U[-1,0]
    for Ta in amb:
        T0=Ta if ic=='soaked' else 25
        P=params(T_amb_C=Ta,T0_C=T0,m_trail=s['m_trail'],soc0=s['soc0'],I_chg_bms=s['I_chg'],baseline=a.baseline,r_string=a.r_string)
        o=simulate(P,U,tend,dt=1.0 if s['maxstep']>=1 else 0.5)
        C=lambda x: x-K0
        r=dict(ic=ic,scn=s['name'],Ta=Ta,Tc_max=C(o['Tc'].max()),Tc_min=C(o['Tc'].min()),Tc_end=C(o['Tc'][-1]),
               Tsup=C(o['Tpe_sup'].max()),Tchg=C(o['Tchg'].max()),Tchop=C(o['Tchop'].max()),Tinv=C(o['Tinv'].max()),Tcd=C(o['Tcd'].max()),Tm=C(o['Tm'].max()),
               kdis=o['kdis'].min(),kchg=o['kchg'].min(),soc_end=o['soc'][-1],Qb_max=o['Qb'].max()/1e3,Qc_max=o['Qc'].max()/1e3,
               Etms=np.trapezoid(o['Ptms'],o['t'])/3.6e6,v_end=o['v'][-1],vmax=o['v'].max(),ib_max=o['ib'].max(),ib_min=o['ib'].min())
        if a.baseline!='phase2':
            r.update(model_rev=P['model_rev'],r_string=a.r_string,Qext_max=o['Qext'].max()/1e3,vt_min=o['vt'].min())
        rows.append(r)
        print(f"{ic:7s} {s['name']:24s} {Ta:3d}C Tc {r['Tc_min']:5.1f}-{r['Tc_max']:5.1f} sup {r['Tsup']:5.1f} chg {r['Tchg']:5.1f} chop {r['Tchop']:5.1f} inv {r['Tinv']:5.1f} cd {r['Tcd']:5.1f} mot {r['Tm']:6.1f} kd {r['kdis']:.2f} kc {r['kchg']:.2f} soc {r['soc_end']:.2f} Qb {r['Qb_max']:5.1f} Qc {r['Qc_max']:5.1f} vmax {r['vmax']:4.1f} ib {r['ib_min']:6.0f}/{r['ib_max']:5.0f} Etms {r["Etms"]:6.1f}", flush=True)
here=os.path.dirname(os.path.abspath(__file__))
fn='expected_results.json' if a.baseline=='phase2' else f'expected_results_revE{"" if a.r_string=="vms" else "_"+a.r_string}.json'
json.dump(rows,open(os.path.join(here,fn),'w'),indent=1)
print('wrote',fn)
