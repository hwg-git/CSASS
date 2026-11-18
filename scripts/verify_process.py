#!/usr/bin/env python3
"""Validate Figure 3 usage and Figures 4/5 RMSE plotting records from run/stage logs.
No optimization is started. Python standard library only.
"""
import argparse,csv,json,math,statistics
from pathlib import Path
from collections import defaultdict

def read(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))

def close(a,b):return math.isclose(float(a),float(b),rel_tol=1e-10,abs_tol=1e-12)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path)
    args=p.parse_args();root=args.root;out=args.output or root/'verification_recomputed';out.mkdir(exist_ok=True,parents=True)
    data=root/'data/Process';errors=[]
    selections=read(data/'Latest18/adaptive_model_selection.csv')
    usage=read(data/'ModelUsage/selection_40_stages.csv')
    sel_groups=defaultdict(list)
    for row in selections:sel_groups[(row['Problem'],int(row['D']),int(row['Stage']))].append(row)
    for row in usage:
        k=row['Problem'],int(row['D']),int(row['Stage']);g=sel_groups[k]
        if len(g)!=30:errors.append(f'Usage group {k}: not 30 observations')
        for col,pred in [('ObjectiveRBF','UsedObjectiveModel'),('ConstraintRBF','UsedConstraintModel')]:
            expected=sum(float(x[pred])==1 for x in g)/30
            if not close(expected,row[col]):errors.append(f'Usage {k} {col}: {expected} != {row[col]}')
    rmse=read(data/'Latest18/stage_rmse_all18.csv');groups=defaultdict(list);run_response=defaultdict(dict)
    for row in rmse:
        key=row['Problem'],int(row['D']),row['Response'],int(row['Stage'])
        groups[key].append(float(row['SelectedRMSE']))
        run_response[key[:3]+(int(row['Seed']),)][int(row['Stage'])]=float(row['SelectedRMSE'])
    stage_means=[]
    for (problem,d,response,stage),values in sorted(groups.items()):
        if len(values)!=30:errors.append(f'RMSE group {(problem,d,response,stage)}: expected 30 runs')
        stage_means.append({'Problem':problem,'D':d,'Response':response,'Stage':stage,'Runs':len(values),'MeanRMSE':statistics.mean(values),'SDRMSE':statistics.stdev(values)})
    with (out/'current_stage_means_all18.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(stage_means[0]));w.writeheader();w.writerows(stage_means)
    expected_phase=read(data/'Latest18/all18_early_late_with_returned_CV.csv')
    phase_groups=defaultdict(list)
    for key,stages in run_response.items():
        if sorted(stages)!=list(range(1,41)):errors.append(f'Incomplete 40 stages: {key}')
        for phase,ids in [('All',range(1,41)),('Early',range(1,11)),('Late',range(31,41))]:
            phase_groups[key[:3]+(phase,)].append(math.sqrt(statistics.mean(stages[i]**2 for i in ids)))
    for row in expected_phase:
        key=row['Problem'],int(row['D']),row['Response']
        for phase in ['All','Early','Late']:
            vals=phase_groups[key+(phase,)];expected=statistics.mean(vals)
            if len(vals)!=30:errors.append(f'Phase {key} {phase}: not 30 runs')
            if not close(expected,row[phase]):errors.append(f'Phase {key} {phase}: {expected} != {row[phase]}')
    selected={('CF8',20),('LIRCMOP1',50),('LIRCMOP7',20),('LIRCMOP13',10)}
    figure_data=root/'figures/Figures04_05_PredictionError/all_available_stage_means.csv'
    if not figure_data.exists():figure_data=root/'figures/PredictionError/all_available_stage_means.csv'
    checks=0
    if figure_data.exists():
        for row in read(figure_data):
            if (row['Problem'],int(row['D'])) not in selected:continue
            key=row['Problem'],int(row['D']),row['Response'],int(row['Stage']);values=groups[key];expected=statistics.mean(values);checks+=1
            if len(values)!=30:errors.append(f'Figure 4/5 {key}: not 30 runs')
            if not close(expected,row['MeanRMSE']):errors.append(f'Figure 4/5 {key}: {expected} != {row["MeanRMSE"]}')
    else:errors.append(f'Missing Figure 4/5 plotting CSV: {figure_data}')
    report={'status':'pass' if not errors else 'fail','model_selection_records':len(selections),'usage_plot_records_checked':len(usage),'rmse_run_stage_response_records':len(rmse),'early_late_response_groups':len(expected_phase),'figure_4_5_plot_rows_checked':checks,'errors':errors,'scope':'Cross-check archived run-stage records against plotting means and phase aggregation. No optimization and no reconstruction of missing original predictions.'}
    (out/'process_verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2));return 0 if not errors else 1

if __name__=='__main__':raise SystemExit(main())
