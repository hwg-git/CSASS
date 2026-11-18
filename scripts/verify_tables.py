#!/usr/bin/env python3
"""Recompute published benchmark summaries from frozen run-level CSV files.

Python 3.9+ standard library only; no optimization is started.
Inf IGD observations are retained as tied worst ranks; no seed is discarded.
Main comparisons use unadjusted two-sided normal-approximation rank-sum p-values.
Ablation comparisons apply Holm correction within each four-control family.
"""
import argparse
import csv
import hashlib
import json
import math
import re
import statistics
from collections import Counter, defaultdict
from pathlib import Path

ALGORITHMS = ['ANSGAIII', 'HeEMOEA', 'MOL2SMEA', 'PCSAEA', 'CTAEA', 'CSASS']
MODES = ['adaptive', 'rbf_only', 'kriging_only', 'fixed_rbf_obj_kriging_con', 'fixed_kriging_obj_rbf_con']


def read_csv(path):
    with Path(path).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    with Path(path).open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def rank_sum(x, y):
    """Mann-Whitney U for x; tie/continuity-corrected two-sided p-value."""
    if any(math.isnan(v) for v in x + y):
        raise ValueError('NaN input requires investigation; it is not silently omitted.')
    n, m = len(x), len(y)
    counts = Counter(x + y)
    ranks, previous = {}, 0
    for v, count in sorted(counts.items()):
        ranks[v] = previous + (count + 1) / 2
        previous += count
    u = math.fsum(ranks[v] for v in x) - n * (n + 1) / 2
    total = n + m
    tie_term = sum(c ** 3 - c for c in counts.values())
    variance = n * m / 12 * (total + 1 - tie_term / (total * (total - 1)))
    if variance <= 0:
        return u, 1.0
    z = max(0.0, abs(u - n * m / 2) - 0.5) / math.sqrt(variance)
    return u, min(1.0, math.erfc(z / math.sqrt(2)))


def holm(ps):
    order = sorted(range(len(ps)), key=ps.__getitem__)
    result = [None] * len(ps)
    current = 0.0
    for rank, i in enumerate(order):
        current = max(current, min(1.0, (len(ps) - rank) * ps[i]))
        result[i] = current
    return result


def sign(u, p, higher_better):
    if p >= 0.05:
        return '='
    return '+' if (u > 450) == higher_better else '-'


def summary(values):
    if not all(math.isfinite(v) for v in values):
        return float('inf'), float('nan')
    return statistics.mean(values), statistics.stdev(values)


def number_matches(computed, printed, digits):
    return math.isclose(float(format(computed, f'.{digits}e')), printed, rel_tol=1e-12, abs_tol=1e-14)


def parse_cell(cell):
    sym = re.search(r'\$([+\-=])\$', cell)
    ns = re.findall(r'([+-]?\d+\.\d+e[+-]\d+)', cell, re.I)
    return {'NA': 'N/A' in cell, 'mean': float(ns[0]) if ns else None,
            'sd': float(ns[1]) if len(ns) > 1 else None,
            'symbol': sym.group(1) if sym else '', 'bold': r'\textbf{' in cell}


def verify_table(path, stats, names, metric, main, errors):
    checks, settings = 0, 0
    for line in path.read_text(encoding='utf-8').splitlines():
        if not re.match(r'^(CF\d+|LIRCMOP\d+)\s*&', line):
            continue
        cells = [s.strip() for s in line.split('&')]
        problem, d = cells[0], int(cells[1])
        if len(cells) != len(names) + 2:
            errors.append(f'{path.name}: unexpected column count: {line}')
            continue
        settings += 1
        for name, text in zip(names, cells[2:]):
            got = parse_cell(text)
            expected = stats[(problem, d, name, metric)]
            checks += 1
            if got['NA'] != (not math.isfinite(expected['Mean'])):
                errors.append(f'{path.name} {problem} D{d} {name}: N/A mismatch')
            if not got['NA']:
                if got['mean'] is None or not number_matches(expected['Mean'], got['mean'], 4):
                    errors.append(f'{path.name} {problem} D{d} {name}: mean {expected["Mean"]} != {got["mean"]}')
                if got['sd'] is None or not number_matches(expected['SD'], got['sd'], 2):
                    errors.append(f'{path.name} {problem} D{d} {name}: SD {expected["SD"]} != {got["sd"]}')
            if got['symbol'] != expected['Symbol']:
                errors.append(f'{path.name} {problem} D{d} {name}: symbol {expected["Symbol"]} != {got["symbol"]}')
    return {'file': path.name, 'settings': settings, 'cells': checks}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--main', type=Path)
    p.add_argument('--ablation', type=Path)
    p.add_argument('--tables', type=Path)
    p.add_argument('--paper-tex', type=Path, help='Optional saved manuscript; used to locate its Tables directory.')
    p.add_argument('--runtime', type=Path, help='Optional full-precision controlled runtime CSV; default data/Runtime/run_results_full_precision.csv if present.')
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    root = args.root.resolve()
    main_path = args.main or root / 'data/Main/main_runs.csv'
    ablation_path = args.ablation or root / 'data/Ablation/ablation_runs.csv'
    tables = args.tables or (args.paper_tex.parent / 'Tables' if args.paper_tex else root / 'paper_tables')
    out = args.output or root / 'verification_recomputed'
    out.mkdir(parents=True, exist_ok=True)
    errors, main_stats, ablation_stats, group_rows, comparison_rows = [], {}, {}, [], []
    main_runs, ablation_runs = read_csv(main_path), read_csv(ablation_path)
    for label, rows, expected in [('main', main_runs, 12960), ('ablation', ablation_runs, 2700)]:
        if len(rows) != expected or len({r['ID'] for r in rows}) != expected:
            errors.append(f'{label}: expected {expected} unique run records; found {len(rows)} rows')
    main_groups, ablation_groups = defaultdict(list), defaultdict(list)
    for r in main_runs:
        main_groups[(r['Problem'], int(r['D']), r['Algorithm'])].append(r)
    for r in ablation_runs:
        ablation_groups[(r['Problem'], int(r['D']), r['Mode'])].append(r)
    for label, groups in [('main', main_groups), ('ablation', ablation_groups)]:
        for key, rows in groups.items():
            if sorted(int(r['Seed']) for r in rows) != list(range(1,31)):
                errors.append(f'{label} {key}: expected one record for every seed 1-30')
    for (problem, d, algorithm), rows in main_groups.items():
        baseline = main_groups[(problem, d, 'CSASS')]
        for metric, higher in [('IGD10000', False), ('HV1p1', True)]:
            values = [float(r[metric]) for r in rows]
            mean, sd = summary(values)
            u, pv = rank_sum([float(r[metric]) for r in baseline], values)
            sym = '' if algorithm == 'CSASS' else sign(u, pv, higher)
            row = {'Cohort':'Main', 'Problem':problem, 'D':d, 'Algorithm':algorithm, 'Metric':metric, 'N':len(rows), 'Mean':mean, 'SD':sd,
                   'FeasibleRuns':sum(int(r['FeasibleND']) > 0 for r in rows), 'ZeroHVRuns':sum(float(r['HV1p1']) == 0 for r in rows), 'Symbol':sym, 'P':pv}
            main_stats[(problem,d,algorithm,metric)] = row
            group_rows.append(row)
    ablation_rows = []
    for problem, d in sorted({k[:2] for k in ablation_groups}):
        for metric, higher in [('IGD10000', False), ('HVr1p1',True), ('HVr3',True), ('HVr20',True)]:
            baseline = [float(r[metric]) for r in ablation_groups[(problem,d,'adaptive')]]
            tests = [rank_sum(baseline, [float(r[metric]) for r in ablation_groups[(problem,d,mode)]]) for mode in MODES[1:]]
            adjusted = holm([x[1] for x in tests])
            for i, mode in enumerate(MODES):
                rows = ablation_groups[(problem,d,mode)]
                mean, sd = summary([float(r[metric]) for r in rows])
                if i:
                    u, raw = tests[i-1]; adj = adjusted[i-1]; sym=sign(u,adj,higher)
                    comparison_rows.append({'Problem':problem,'D':d,'Metric':metric,'ControlMode':mode,'N_Adaptive':30,'N_Control':30,'U':u,'RawP':raw,'HolmP':adj,'Symbol':sym})
                else:
                    u, raw, adj, sym=450,1,1,''
                row={'Cohort':'Ablation','Problem':problem,'D':d,'Mode':mode,'Metric':metric,'N':len(rows),'Mean':mean,'SD':sd,
                     'FeasibleRuns':sum(int(r['FeasibleND'])>0 for r in rows),'ZeroHVRuns':sum(float(r['HVr1p1'])==0 for r in rows),'Symbol':sym,'RawP':raw,'HolmP':adj}
                ablation_stats[(problem,d,mode,metric)] = row
                ablation_rows.append(row)
    shared_errors=[]; by_id={r['ID']:r for r in main_runs}; shared=0
    for a in ablation_runs:
        if a['Mode']!='adaptive':continue
        shared+=1; m=by_id.get(a['SharedMainID'])
        if not m:
            shared_errors.append(f'Missing shared main record: {a["ID"]}');continue
        for am,mm in [('IGD10000','IGD10000'),('HVr1p1','HV1p1')]:
            x,y=float(a[am]),float(m[mm])
            if not (x==y or math.isclose(x,y,rel_tol=1e-12,abs_tol=1e-14)):
                shared_errors.append(f'{a["ID"]}: {am} differs from {m["ID"]}')
        if a['FinalSetPath']!=m['FinalSetPath']:
            shared_errors.append(f'{a["ID"]}: final-set path differs from main')
    errors.extend(shared_errors)
    checks=[]
    for fn, metric in [('IGD_CF.tex','IGD10000'),('IGD_LIRCMOP.tex','IGD10000'),('HV_CF.tex','HV1p1'),('HV_LIRCMOP.tex','HV1p1')]:
        checks.append(verify_table(tables/fn,main_stats,ALGORITHMS,metric,True,errors))
    for fn,metric in [('Ablation_IGD.tex','IGD10000'),('Ablation_HV.tex','HVr1p1')]:
        checks.append(verify_table(tables/fn,ablation_stats,MODES,metric,False,errors))
    sensitivity=[]
    for ref,metric in [('1.1','HVr1p1'),('3','HVr3'),('20','HVr20')]:
        comparisons=[r for r in comparison_rows if r['Metric']==metric]
        all_zero=sum(all(float(r[metric])==0 for mode in MODES for r in ablation_groups[(problem,d,mode)]) for problem,d in {k[:2] for k in ablation_groups})
        sensitivity.append({'Reference':ref,'Better':sum(r['Symbol']=='+' for r in comparisons),'Worse':sum(r['Symbol']=='-' for r in comparisons),'Equal':sum(r['Symbol']=='=' for r in comparisons),'AllZeroSettings':all_zero})
    sensitivity_text=(tables/'HV_Reference_Sensitivity.tex').read_text(encoding='utf-8')
    for r in sensitivity:
        pattern=rf'^{re.escape(r["Reference"])}\s*&\s*{r["Better"]}\s*&\s*{r["Worse"]}\s*&\s*{r["Equal"]}\s*&\s*{r["AllZeroSettings"]}\s*\\\\'
        if not re.search(pattern,sensitivity_text,re.M):errors.append(f'Sensitivity table mismatch at r={r["Reference"]}: {r}')
    write_csv(out/'main_statistics_recomputed.csv',group_rows)
    write_csv(out/'ablation_statistics_recomputed.csv',ablation_rows)
    write_csv(out/'ablation_comparisons_recomputed.csv',comparison_rows)
    write_csv(out/'hv_reference_sensitivity_recomputed.csv',sensitivity)
    feasibility=[]
    for label,groups,namekey in [('Main',main_groups,'Algorithm'),('Ablation',ablation_groups,'Mode')]:
        for (problem,d,name), rows in groups.items():
            feasibility.append({'Cohort':label,'Problem':problem,'D':d,'AlgorithmOrMode':name,'Runs':len(rows),'FeasibleRuns':sum(int(r['FeasibleND'])>0 for r in rows),'NoFeasibleRuns':sum(int(r['FeasibleND'])==0 for r in rows),'FiniteIGDRuns':sum(math.isfinite(float(r['IGD10000'])) for r in rows)})
    write_csv(out/'feasible_run_counts_recomputed.csv',feasibility)
    runtime_path=args.runtime or root/'data/Runtime/run_results_full_precision.csv'
    runtime_report={'status':'not_requested','runs':0,'cells':0}
    if runtime_path.exists():
        runtime=read_csv(runtime_path); runtime_groups=defaultdict(list); runtime_rows=[]
        for row in runtime:runtime_groups[(row['Problem'],int(row['D']),row['Algorithm'])].append(row)
        if len(runtime)!=480 or len({r['ID'] for r in runtime})!=480:errors.append('Runtime: expected 480 unique completed runs')
        for (problem,d,algorithm), rows in runtime_groups.items():
            if sorted(int(r['Seed']) for r in rows)!=list(range(1,31)):errors.append(f'Runtime {problem} {algorithm}: expected seeds 1-30')
            if d!=10:errors.append(f'Runtime {problem}: expected D=10')
            values=[float(r['RuntimeSeconds']) for r in rows];mean,sd=summary(values)
            baseline=[float(r['RuntimeSeconds']) for r in runtime_groups[(problem,d,'CSASS')]]
            u,pv=rank_sum(baseline,values)
            runtime_rows.append({'Problem':problem,'D':d,'Algorithm':algorithm,'N':len(rows),'Mean':mean,'SD':sd,'Symbol':'' if algorithm=='CSASS' else sign(u,pv,False),'P':pv,'U':u})
        runtime_stats={(r['Problem'],r['Algorithm']):r for r in runtime_rows}
        if args.paper_tex:
            blocks=re.findall(r'\\begin\{table\}.*?\\end\{table\}',args.paper_tex.read_text(encoding='utf-8'),re.S)
            runtime_text=next(block for block in blocks if r'\label{tab:runtime}' in block)
        else:runtime_text=(tables/'Runtime.tex').read_text(encoding='utf-8')
        count=0
        for line in runtime_text.splitlines():
            if not re.match(r'^(CF\d+|LIRCMOP\d+)\s*&',line):continue
            cells=[c.strip() for c in line.split('&')];problem=cells[0]
            if len(cells)!=5:errors.append(f'Runtime {problem}: unexpected row shape');continue
            for algorithm,cell in zip(['HeEMOEA','MOL2SMEA','PCSAEA','CSASS'],cells[1:]):
                expected=runtime_stats[(problem,algorithm)];got=parse_cell(cell);count+=1
                plain_symbol=re.search(r'\)\s*([+\-=])',cell)
                if not got['symbol'] and plain_symbol:got['symbol']=plain_symbol.group(1)
                if got['mean'] is None or not number_matches(expected['Mean'],got['mean'],4):errors.append(f'Runtime {problem} {algorithm}: mean mismatch')
                if got['sd'] is None or not number_matches(expected['SD'],got['sd'],2):errors.append(f'Runtime {problem} {algorithm}: SD mismatch')
                if got['symbol']!=expected['Symbol']:errors.append(f'Runtime {problem} {algorithm}: symbol mismatch')
        write_csv(out/'runtime_statistics_recomputed.csv',runtime_rows)
        runtime_report={'status':'checked','runs':len(runtime),'groups':len(runtime_groups),'cells':count,'source':'Full-precision RuntimeSeconds from complete.json Row; timer scope verified separately.'}
        if count!=16:errors.append(f'Runtime: expected 16 cells, checked {count}')
    elif args.runtime:errors.append(f'Runtime CSV not found: {runtime_path}')
    report={'status':'pass' if not errors else 'fail','scope':'Tables 2-8, shared CSASS run identity, and optional controlled-runtime Table 9; statistics computed from saved indicators, not an independent re-evaluation of objective functions or final-set metrics','optimization_runs_started':0,'main_runs':len(main_runs),'main_groups':len(main_groups),'ablation_runs':len(ablation_runs),'ablation_groups':len(ablation_groups),'shared_adaptive_records':shared,'shared_record_mismatches':shared_errors,'table_checks':checks,'runtime':runtime_report,'sensitivity':sensitivity,'errors':errors,'input_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [main_path,ablation_path]+([runtime_path] if runtime_path.exists() else [])},'statistics':'Two-sided normal-approximation rank-sum test; ties and continuity corrected; Inf kept; Holm across four ablation controls per setting and metric. All 30 observations retained.'}
    (out/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps({'status':report['status'],'main_runs':len(main_runs),'ablation_runs':len(ablation_runs),'table_cells_checked':sum(r['cells'] for r in checks),'errors':errors[:15]},ensure_ascii=False,indent=2))
    return 0 if not errors else 1


if __name__=='__main__':
    raise SystemExit(main())
