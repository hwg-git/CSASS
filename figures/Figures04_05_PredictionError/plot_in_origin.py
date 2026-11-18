"""Run inside Origin 2026b. Plot saved stage means; no new statistics or experiments."""
from pathlib import Path
import csv, json, math, hashlib, traceback
import originpro as op

ROOT = Path(r'C:/Users/LOCAL_USER/Documents/ChatGPT/New project')
OUT = ROOT/'output/CSASS_Round2_HV_20261104/Accuracy_Statistics/Origin_Figures_20261105'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = OUT.parent/'Reply_Figures_AllDimensions/all_available_stage_means.csv'
CASES = [('CF8',20),('LIRCMOP1',50),('LIRCMOP7',20),('LIRCMOP13',10)]
COLORS = ['#0050A4','#A74B00','#32764D']

def nice_top(v):
    target = v*1.08/4
    unit = 10**math.floor(math.log10(target))
    step = next(s*unit for s in [1,2,2.5,5,10] if s*unit>=target)
    top = math.ceil(v*1.08/step)*step
    return top, step

try:
    rows = list(csv.DictReader(SOURCE.open(encoding='utf-8-sig',newline='')))
    op.new()
    evidence=[]
    for task in ['objectives','constraint']:
        g=op.new_graph(template='line',lname='Objective prediction errors' if task=='objectives' else 'Constraint prediction errors')
        g.name='Objectives' if task=='objectives' else 'Constraints'
        g.lt_exec('page.width=8*page.resx; page.height=6.1*page.resy; page.basecolor=color(white); page.connect=0;')
        layers=[g[0]]+[g.add_layer(0) for _ in range(3)]
        for i, ((prob,d),gl) in enumerate(zip(CASES,layers)):
            data=[r for r in rows if r['Problem']==prob and int(r['D'])==d]
            responses=[r for r in ['f1','f2','f3'] if r in {h['Response'] for h in data}] if task=='objectives' else ['CV']
            w=op.new_sheet('w',lname=f'{prob} D{d} {task}')
            w.name=f'{prob}D{d}'
            w.from_list(0,list(range(1,41)),lname='Update stage',axis='X')
            max_y=0
            for k,response in enumerate(responses):
                h=sorted((r for r in data if r['Response']==response),key=lambda r:int(r['Stage']))
                assert [int(r['Stage']) for r in h]==list(range(1,41))
                assert all(int(r['Runs'])==30 for r in h)
                vals=[float(r['MeanRMSE']) for r in h]
                assert all(math.isfinite(v) and v>=0 for v in vals)
                max_y=max(max_y,max(vals))
                w.from_list(k+1,vals,lname=response,comments='Mean of 30 run-specific RMSE values; 10 newly evaluated points per run per stage. No smoothing.',axis='Y')
                p=gl.add_plot(w,coly=k+1,colx=0,type='l')
                p.color=COLORS[k]
                p.set_cmd('-wp 1.45',f'-d {k}')
                assert w.to_list(k+1)==vals
                evidence.append(dict(task=task,problem=prob,D=d,response=response,points=len(vals),min=min(vals),max=max(vals),worksheet=w.lt_range()))
            gl.set_int('unit',1)
            for prop,val in {'left':11 if i%2==0 else 61,'top':10 if i<2 else 59,'width':35,'height':31}.items():
                gl.set_float(prop,val)
            gl.rescale()
            ymax,ystep=nice_top(max_y)
            gl.set_xlim(0,40,10)
            gl.set_ylim(0,ymax,ystep)
            gl.axis('x').title='Surrogate update stage'
            gl.axis('y').title='Mean RMSE'
            gl.lt_exec('layer.x.label.pt=12; layer.y.label.pt=12; layer.x.label.font=font(Arial); layer.y.label.font=font(Arial); layer.x.thickness=1; layer.y.thickness=1; layer.x2.showaxes=0; layer.y2.showaxes=0; layer.x.minorTicks=0; layer.y.minorTicks=0;')
            for name in ['xb','yl']:
                lab=gl.label(name)
                if lab:
                    lab.set_int('fsize',13)
                    gl.lt_exec(f'{name}.font=font(Arial);')
            title=gl.add_label(f'({chr(97+i)}) {prob}, D = {d}',0,ymax*1.145)
            title.set_int('fsize',14)
            title.set_int('bold',1)
            gl.lt_exec(f'{title.name}.font=font(Arial);')
            legend=gl.label('Legend')
            if legend: legend.remove()
            if task=='objectives':
                legend=gl.add_label('   '.join(r'\l(%d) f\-(%d)'%(j+1,j+1) for j in range(len(responses))),12,ymax*1.00)
                legend.set_int('fsize',11)
                gl.lt_exec(f'{legend.name}.font=font(Arial);')
            gl.set_int('speedmode',0)
        g.activate()
        outputs={}
        for ext in ['png','pdf']:
            path=OUT/f'four_cases_{task}_Origin_demo.{ext}'
            result=g.save_fig(str(path),width=3200 if ext=='png' else 0)
            outputs[ext]=str(path)
        evidence.append(dict(task=task,exports=outputs))
    op.find_graph('Objectives').activate()
    op.save(str(OUT/'CSASS_Prediction_Error_40Stages.opju'))
    (OUT/'origin_plot_audit.json').write_text(json.dumps(dict(status='success',software='Origin 2026b SR2',source=str(SOURCE),sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),curves=evidence,no_smoothing=True,all_stages_retained=True),indent=2),encoding='utf-8')
except Exception:
    (OUT/'origin_plot_error.txt').write_text(traceback.format_exc(),encoding='utf-8')
    raise
