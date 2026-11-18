#!/usr/bin/env python3
"""Recompute IGD and exact 2D/3D HV from saved feasible final sets only.

Usage: python verify_saved_metrics.py --root /path/to/release --output audit_metrics
Dependencies: numpy. No MATLAB, optimizer, model fit or new evaluation is used.
An optional --archive path reads the authors' internal archive without extraction.
"""
import os
os.environ.setdefault('OPENBLAS_NUM_THREADS','1')
os.environ.setdefault('OMP_NUM_THREADS','1')
import argparse,csv,io,json,math,time,zipfile,hashlib
from pathlib import Path
import numpy as np

def igd(final, front):
    if len(final)==0:return math.inf
    distances=[]
    for start in range(0,len(front),1024):
        sq=np.sum((front[start:start+1024,None,:]-final[None,:,:])**2,axis=2)
        distances.append(np.sqrt(np.min(sq,axis=1)))
    return float(np.mean(np.concatenate(distances)))

def hv2(points, ref):
    best=float(ref[1]);total=0.0
    for x,y in points[np.argsort(points[:,0],kind='stable')]:
        if y<best:
            total+=float((ref[0]-x)*(best-y));best=float(y)
    return total

def hypervolume(points, ref):
    """Union volume of minimization boxes [point, ref]; no clipping/division."""
    if len(points)==0:return 0.0
    points=np.unique(points[np.all(points<ref,axis=1)],axis=0)
    if len(points)==0:return 0.0
    if points.shape[1]==2:return hv2(points,ref)
    if points.shape[1]!=3:raise ValueError('Only 2- and 3-objective data supported')
    points=points[np.argsort(points[:,0],kind='stable')]
    total=0.0
    for i in range(len(points)):
        right=points[i+1,0] if i+1<len(points) else ref[0]
        if right>points[i,0]:
            total+=float(right-points[i,0])*hv2(points[:i+1,1:],ref[1:])
    return total

def read_matrix(data):
    lines=list(csv.reader(io.StringIO(data.decode('utf-8-sig'))))
    if not lines:raise ValueError('Missing CSV objective header')
    m=len(lines[0])
    vals=[[float(v) for v in row] for row in lines[1:] if row]
    a=np.asarray(vals,dtype=float).reshape(-1,m)
    if not np.isfinite(a).all():raise ValueError('Nonfinite objective data')
    return a

class Source:
    def __init__(self,root=None,archive=None):
        self.root=Path(root) if root else None
        self.zip=zipfile.ZipFile(archive) if archive else None
        self.prefix='CSASS_Complete_Archive_20261111/'
    def read(self,path):
        if self.zip:return self.zip.read(self.prefix+path)
        if path.startswith('05_Data/'):path='data/'+path[len('05_Data/'):]
        if path.startswith('04_Algorithms/'):path='code/'+path[len('04_Algorithms/'):]
        return (self.root/path).read_bytes()
    def rows(self,path):return list(csv.DictReader(io.StringIO(self.read(path).decode('utf-8-sig'))))

def equal(a,b,atol,rtol):
    if math.isinf(a) and math.isinf(b):return True
    return math.isfinite(a) and math.isfinite(b) and math.isclose(a,b,abs_tol=atol,rel_tol=rtol)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    x=ap.add_mutually_exclusive_group(required=True);x.add_argument('--root');x.add_argument('--archive')
    ap.add_argument('--output',required=True);ap.add_argument('--limit',type=int)
    ap.add_argument('--atol',type=float,default=1e-10);ap.add_argument('--rtol',type=float,default=1e-9)
    args=ap.parse_args();dest=Path(args.output);dest.mkdir(parents=True,exist_ok=True)
    src=Source(args.root,args.archive);started=time.monotonic()
    mainrows=src.rows('05_Data/Main/main_runs.csv');abrows=src.rows('05_Data/Ablation/ablation_runs.csv')
    records=[dict(r,Cohort='main',SavedHV=r['HV1p1']) for r in mainrows]
    records += [dict(r,Cohort='ablation_control',SavedHV=r['HVr1p1']) for r in abrows if r['Mode']!='adaptive']
    if args.limit:records=records[:args.limit]
    cache={};checked=[];failures=[];maxerr={'IGD':0.0,'HV1p1':0.0};reference_inventory=[]
    for i,r in enumerate(records,1):
        p=r['Problem']
        if p not in cache:
            raw=src.read(f'04_Algorithms/CSASS_AllBenchmarks_MATLAB/references/PF10000/{p}.csv')
            front=read_matrix(raw);lower=front.min(axis=0);width=front.max(axis=0)-lower
            if not np.all(width>0):raise ValueError(f'Zero PF coordinate range: {p}')
            cache[p]=(front,lower,width)
            reference_inventory.append({'Problem':p,'Points':len(front),'Objectives':front.shape[1],'SHA256':hashlib.sha256(raw).hexdigest()})
        front,lower,width=cache[p];raw=src.read(r['FinalSetPath']);final=read_matrix(raw)
        a=igd(final,front);b=hypervolume((final-lower)/width,np.full(front.shape[1],1.1))
        saved_a=float(r['IGD10000']);saved_b=float(r['SavedHV'])
        err_a=abs(a-saved_a) if math.isfinite(a) and math.isfinite(saved_a) else 0.0
        err_b=abs(b-saved_b)
        maxerr['IGD']=max(maxerr['IGD'],err_a);maxerr['HV1p1']=max(maxerr['HV1p1'],err_b)
        passed=len(final)==int(r['FeasibleND']) and equal(a,saved_a,args.atol,args.rtol) and equal(b,saved_b,args.atol,args.rtol)
        row={'Cohort':r['Cohort'],'ID':r['ID'],'Problem':p,'D':r['D'],'Seed':r['Seed'],'FeasiblePoints':len(final),'SavedIGD':saved_a,'RecomputedIGD':a,'IGDAbsoluteDifference':err_a,'SavedHV1p1':saved_b,'RecomputedHV1p1':b,'HVAbsoluteDifference':err_b,'Status':'pass' if passed else 'FAIL','FinalSetSHA256':hashlib.sha256(raw).hexdigest()}
        checked.append(row)
        if not passed:failures.append(row)
        if i%500==0:print(f'{i}/{len(records)} saved sets checked; failures={len(failures)}; elapsed={time.monotonic()-started:.1f}s',flush=True)
    with (dest/'saved_metrics_verification.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(checked[0]));w.writeheader();w.writerows(checked)
    report={'Status':'pass' if not failures else 'failed','SavedSetsChecked':len(checked),'MainRuns':sum(r['Cohort']=='main' for r in checked),'ControlRuns':sum(r['Cohort']=='ablation_control' for r in checked),'SharedAdaptiveRowsNotDoubleCounted':540 if not args.limit else None,'ReferenceRequest':10000,'ObjectiveScale':1,'HVReference':1.1,'HVNormalization':'PF10000 column minimum and range; no clipping; no box-volume division','HVAlgorithm':'Exact 2D sweep and exact 3D slice union','AbsoluteTolerance':args.atol,'RelativeTolerance':args.rtol,'ToleranceRationale':'Allows roundoff from independent floating-point arithmetic and saved CSV decimal representation; no data altered','MaximumAbsoluteDifferences':maxerr,'ReferenceFronts':reference_inventory,'Failures':failures,'ElapsedSeconds':time.monotonic()-started,'OptimizationRuns':0,'NewEvaluations':0,'ModelFits':0}
    (dest/'metric_verification.json').write_text(json.dumps(report,indent=2,allow_nan=True),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['ReferenceFronts','Failures']},indent=2),flush=True)
    return 0 if not failures else 1

if __name__=='__main__':raise SystemExit(main())
