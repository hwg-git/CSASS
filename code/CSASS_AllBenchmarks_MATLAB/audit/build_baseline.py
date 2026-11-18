"""Build a fixed, traceable cache from completed V2 trials; no scientific execution."""
import csv, io, json, math, hashlib, statistics, zipfile
from pathlib import Path

PKG=Path(__file__).resolve().parents[1]
WORK=PKG.parents[2]
COMPARE=Path('C:/$Recycle.Bin/S-1-5-21-3815341782-4056756569-3813834504-1001/$RL7BDRS/compare/all_runs.csv')
RETURN=Path('C:/Users/10564/Desktop/CSASS_V2_LIR24_RESULTS_20261104_135839_489_129443b8.zip')
CACHE=WORK/'outputs/side_CSASS_remote_20261103/CSASS_Review_MATLAB/cache'
FIELDS=['ID','Version','Problem','D','M','Seed','FE','Status','FeasibleND','IGD10000','IGD2000',
        'HVr1p1','HVr3','HVr20','Source','SourceSHA256','SourceContainer','SourceID','RecordSHA256',
        'RuntimeSeconds','Origin','TraceAvailable','FinalObjectivesAvailable','FinalObjectivesPath',
        'FinalObjectivesSHA256','FinalDecisionsAvailable','FinalDecisionsPath','FinalDecisionsSHA256']
sha=lambda b:hashlib.sha256(b).hexdigest()
readcsv=lambda b:list(csv.DictReader(io.StringIO(b.decode('utf-8-sig'))))
close=lambda a,b:math.isclose(float(a),float(b),rel_tol=1e-10,abs_tol=1e-11)


def main():
    compare_bytes=COMPARE.read_bytes();compare_sha=sha(compare_bytes)
    assert compare_sha=='8487797c7beaf5f9d7088ecc1b307c23de2178d9d77d744791a7adca018ee1fa'
    comp=readcsv(compare_bytes);assert len(comp)==360
    return_sha=sha(RETURN.read_bytes());records=[];provenance=[];missing=[]
    with zipfile.ZipFile(RETURN) as z:
        member='outputs/V2_LIR24/tables/all_runs.csv'
        returned=readcsv(z.read(member));assert len(returned)==120
        report=json.loads(z.read('outputs/V2_LIR24/tables/audit.json'))
        assert report['Status']=='pass' and report['AllExperimentsComplete'] and report['NewComplete']==60
        selected=[(r,str(RETURN)+'!'+member,None) for r in returned]
        selected += [(r,str(COMPARE),CACHE/r['ID']) for r in comp if r['Version']=='V2' and r['Problem'] in ['CF2','CF7','LIRCMOP7']]
        assert len(selected)==210
        for original,container,oldcache in selected:
            p=original['Problem'];seed=int(original['Seed']);id=f'V2_{p}_D10_seed{seed:02d}'
            assert original['Version']=='V2' and int(original['D'])==10 and int(original['FE'])==500
            assert math.isfinite(float(original['IGD10000'])) and int(original['FeasibleND'])>0
            row={k:original.get(k,'') for k in FIELDS}
            row.update(ID=id,M=2,Status='completed',SourceContainer=container,SourceID=original['ID'],
                       RecordSHA256=sha(json.dumps(original,sort_keys=True,separators=(',',':')).encode()),
                       FinalObjectivesAvailable='0',FinalDecisionsAvailable='0',FinalObjectivesPath='',
                       FinalObjectivesSHA256='',FinalDecisionsPath='',FinalDecisionsSHA256='')
            if not row['SourceSHA256']:row['SourceSHA256']=compare_sha
            if not row['Origin']:row['Origin']=original['Source']
            if not row['TraceAvailable']:row['TraceAvailable']=original.get('FullTrace','0')
            evidence={'ID':id,'SourceContainer':container,'OriginalRecord':original,'CopiedFiles':[]}
            files={}
            if p in ['LIRCMOP2','LIRCMOP4']:
                run=f'outputs/V2_LIR24/runs/{id}/'
                for name in ['final_objectives.csv','final_decisions.csv']:
                    files[name]=(z.read(run+name),str(RETURN)+'!'+run+name)
                result=json.loads(z.read(run+'result.json'))
                assert result['FE']==500 and result['ID']==id and result['Version']=='V2'
                evidence['ResultJSON_SHA256']=sha(z.read(run+'result.json'))
                evidence['CompletedJSON_SHA256']=sha(z.read(run+'completed.json'))
            elif p in ['CF7','LIRCMOP7']:
                result=json.loads((oldcache/'result.json').read_text(encoding='utf-8'))
                assert result['Version']=='V2' and result['Mode']=='adaptive' and result['FE']==500 and result['Status']=='completed'
                for k in ['IGD10000','IGD2000','HVr1p1','HVr3','HVr20']:assert close(result[k],original[k]),(id,k)
                data=(oldcache/'final_objectives.csv').read_bytes();assert sha(data)==result['FinalSHA256']
                files['final_objectives.csv']=(data,str(oldcache/'final_objectives.csv'))
                evidence['CacheResultSHA256']=sha((oldcache/'result.json').read_bytes())
                evidence['OriginalSourceEvidence']=json.loads((oldcache/'source_evidence.json').read_text(encoding='utf-8'))
            for name,(data,source) in files.items():
                rel=f'baseline/solutions/{id}/{name}';dest=PKG/rel;dest.parent.mkdir(parents=True,exist_ok=True)
                if dest.exists():assert dest.read_bytes()==data
                else:dest.write_bytes(data)
                item={'Path':rel,'SHA256':sha(data),'Source':source,'ByteExactCopy':True}
                evidence['CopiedFiles'].append(item)
                if name=='final_objectives.csv':
                    objs=readcsv(data);assert len(objs)==int(original['FeasibleND'])
                    assert len(objs[0])==2 and all(math.isfinite(float(v)) for a in objs for v in a.values())
                    row.update(FinalObjectivesAvailable='1',FinalObjectivesPath=rel,FinalObjectivesSHA256=sha(data))
                else:
                    assert len(readcsv(data))==int(original['FeasibleND'])
                    row.update(FinalDecisionsAvailable='1',FinalDecisionsPath=rel,FinalDecisionsSHA256=sha(data))
            if row['FinalObjectivesAvailable']=='0':
                missing.append({'ID':id,'Problem':p,'D':10,'Seed':seed,'FinalObjectivesAvailable':False,
                                'Reason':'Only audited returned per-run metrics are locally available; no final solution file supplied. No reconstruction or rerun.'})
            records.append(row);provenance.append(evidence)
    assert len({r['ID'] for r in records})==210
    stats=[]
    for p in ['CF2','CF7','LIRCMOP1','LIRCMOP2','LIRCMOP3','LIRCMOP4','LIRCMOP7']:
        a=sorted([r for r in records if r['Problem']==p],key=lambda r:int(r['Seed']))
        assert len(a)==30 and [int(r['Seed']) for r in a]==list(range(1,31))
        d={'Problem':p,'D':10,'Runs':30,'FiniteIGDRuns':30,
           'FinalObjectivesAvailable':sum(r['FinalObjectivesAvailable']=='1' for r in a),
           'FinalDecisionsAvailable':sum(r['FinalDecisionsAvailable']=='1' for r in a)}
        for c in ['IGD10000','IGD2000','HVr1p1','HVr3','HVr20']:
            v=[float(r[c]) for r in a];d[c+'Mean']=statistics.mean(v);d[c+'SD']=statistics.stdev(v)
        d['ZeroHVRuns']=sum(float(r['HVr1p1'])==0 for r in a);stats.append(d)
    records.sort(key=lambda r: (r['Problem'].startswith('LIR'),int(r['Problem'].replace('LIRCMOP','').replace('CF','')),int(r['Seed'])))
    out=PKG/'baseline';out.mkdir(exist_ok=True)
    with (out/'completed_runs.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=FIELDS);w.writeheader();w.writerows(records)
    with (out/'missing_solutions.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(missing[0]));w.writeheader();w.writerows(missing)
    p={'Status':'pass','CachedRecords':210,'CachedGroups':7,'Dimension':10,'Seeds':'1-30',
       'Version':'V2','Mode':'adaptive','FE':500,'N':100,'Pmax':20,'K':10,
       'RequestedPF':10000,'ObjectiveScale':1,'HVReferences':[1.1,3,20],
       'FinalObjectivesAvailable':120,'FinalObjectivesMissing':90,'FinalDecisionsAvailable':60,
       'MissingFinalGroups':['CF2 D10','LIRCMOP1 D10','LIRCMOP3 D10'],
       'NewDispatchRule':'All24 problems x dimensions10,20,50 x seeds1-30 minus these exact210 canonical IDs =1950 new trials.',
       'CacheUse':'Performance summaries only; original Origin/TraceAvailable retained as provenance, current summary labels cached/false.',
       'ExtraReferencePostprocessing':'Only120 cached final sets can be recomputed locally. Missing90 must remain unavailable for new references, while supplied r1.1/3/20 metrics remain usable.',
       'MetricPolicy':'Existing audited PF10000 scale1 run metrics copied, no cross-run pooling, no fitting or optimization.',
       'SourceHashes':{str(COMPARE):compare_sha,str(RETURN):return_sha},
       'CacheCSV_SHA256':sha((out/'completed_runs.csv').read_bytes()),'Groups':stats,'Records':provenance,
       'OptimizationRuns':0,'ObjectiveEvaluations':0,'ModelFits':0,'OriginalSourcesModified':False}
    (out/'provenance.json').write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    assert sha(COMPARE.read_bytes())==compare_sha and sha(RETURN.read_bytes())==return_sha
    print(json.dumps({k:p[k] for k in ['Status','CachedRecords','FinalObjectivesAvailable','FinalObjectivesMissing','FinalDecisionsAvailable','CacheCSV_SHA256','Groups']},indent=2))

if __name__=='__main__':main()
