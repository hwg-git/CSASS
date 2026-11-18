"""Compute paper indicators for newly reproduced final-objective CSVs; no optimization."""
from pathlib import Path
import argparse,csv,re,sys,io
import numpy as np
from verify_saved_metrics import read_matrix,igd,hypervolume

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);ap.add_argument('--runs',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 runs=a.runs if a.runs.is_absolute() else a.root/a.runs
 dest=a.output if a.output.is_absolute() else a.root/a.output
 if dest.resolve().is_relative_to((a.root/'data').resolve()):raise ValueError('Output must not overwrite frozen data/')
 rows=[];fronts={}
 for file in sorted(runs.rglob('final_objectives.csv')):
  runid=file.parent.name;m=re.search(r'(CF\d+|LIRCMOP\d+)_D(\d+).*seed(\d+)',runid)
  if not m:raise ValueError('Cannot determine problem/dimension/seed: '+runid)
  problem,d,seed=m.groups()
  if problem not in fronts:fronts[problem]=read_matrix((a.root/'code/CSASS_AllBenchmarks_MATLAB/references/PF10000'/f'{problem}.csv').read_bytes())
  pf=fronts[problem];f=read_matrix(file.read_bytes());width=pf.max(axis=0)-pf.min(axis=0)
  row={'ID':runid,'Problem':problem,'D':int(d),'Seed':int(seed),'FeasibleND':len(f),'IGD10000':igd(f,pf),'HV1p1':hypervolume((f-pf.min(axis=0))/width,np.full(pf.shape[1],1.1)),'FinalSetPath':str(file)}
  rows.append(row)
 if not rows:raise ValueError('No final_objectives.csv found')
 dest.parent.mkdir(parents=True,exist_ok=True)
 with dest.open('w',encoding='utf-8',newline='') as out:
  writer=csv.DictWriter(out,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
 print(f'Recalculated {len(rows)} saved final sets -> {dest}; no optimization or data change.')
if __name__=='__main__':main()
