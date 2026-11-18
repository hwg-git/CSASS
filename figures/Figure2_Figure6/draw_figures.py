"""Redraw Figures 2 and 6 from archived, verified records; no optimization.

Run with Python + numpy, matplotlib and Pillow. The local dependency fallback is
only for this workstation; data paths below are relative and portable.
"""
from pathlib import Path
import csv, hashlib, json, math, sys

HERE = Path(__file__).resolve().parent
LOCAL_LIB = HERE.parents[2] / 'tmp' / 'cf2_plot_dependencies'
if LOCAL_LIB.is_dir():
    sys.path.insert(0, str(LOCAL_LIB))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.ticker import FuncFormatter
from PIL import Image

DATA = HERE / 'data'
SHA = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
ALG_LABELS = [('ANSGAIII','A-NSGA-III'), ('CTAEA','C-TAEA'),
              ('HeEMOEA','HeEMOEA'), ('MOL2SMEA','MO-L2SMEA'),
              ('PCSAEA','PC-SAEA'), ('CSASS','CSASS')]
for name in ['times.ttf', 'timesi.ttf', 'timesbd.ttf', 'timesbi.ttf']:
    font = Path('C:/Windows/Fonts') / name
    if font.is_file():
        font_manager.fontManager.addfont(str(font))

STYLE = {'font.family':'Times New Roman', 'font.size':24,
         'axes.titlesize':28, 'axes.labelsize':28,
         'xtick.labelsize':23, 'ytick.labelsize':23,
         'mathtext.fontset':'stix', 'axes.linewidth':1.2,
         'pdf.fonttype':42, 'ps.fonttype':42, 'svg.fonttype':'none',
         'figure.facecolor':'white', 'savefig.facecolor':'white'}

def rows(name):
    with (DATA/name).open(encoding='utf-8-sig',newline='') as f:
        return list(csv.DictReader(f))

def matrix(name):
    return np.loadtxt(DATA/name,delimiter=',',skiprows=1,ndmin=2)

def export(fig,name,size):
    fig.savefig(HERE/f'{name}.png',dpi=300)
    # PNG stores integer pixels/metre; 300dpi is represented as 299.9994,
    # exactly matching the manuscript figures being replaced.
    with Image.open(HERE/f'{name}.png') as im:
        assert im.size == size, (im.size,size)
        assert im.info['dpi'] == (299.9994,299.9994)
        im.convert('RGB').save(HERE/f'{name}.png',dpi=(300,300))
    fig.savefig(HERE/f'{name}.pdf',metadata={'Title':name,'Creator':'Matplotlib; saved run-level records'})
    fig.savefig(HERE/f'{name}.svg')
    plt.close(fig)
    return {'Pixels':size,'DPI':list(Image.open(HERE/f'{name}.png').info['dpi']),
            'SHA256':SHA(HERE/f'{name}.png')}

def figure2():
    selected=rows('CF2_selected_runs.csv')
    pf=matrix('CF2_PF10000.csv')
    assert pf.shape == (6251,2)
    assert np.all(np.diff(pf[:,0]) >= 0)
    parts=np.split(pf,np.flatnonzero(np.diff(pf[:,0])>.001)+1)
    points=[]
    records=[]
    for alg,label in ALG_LABELS:
        r=next(r for r in selected if r['Algorithm']==alg)
        assert (int(r['D']),int(r['Rank']),int(r['Runs']))==(10,15,30)
        name=f'{alg}_CF2_D10_seed{int(r["Seed"]):02d}_final_objectives.csv'
        F=matrix(name)
        assert SHA(DATA/name)==r['SourceSHA256']
        assert F.shape[1]==2 and np.isfinite(F).all()
        assert not any(np.any(np.all(F<=p,axis=1)&np.any(F<p,axis=1)) for p in F)
        igd=np.min(np.linalg.norm(pf[:,None,:]-F[None,:,:],axis=2),axis=1).mean()
        assert abs(igd-float(r['IGD']))<1e-12
        assert len(F)==int(r['TotalPoints'])
        points.append(F)
        records.append({'Algorithm':alg,'Seed':int(r['Seed']),'Rank':15,
                        'IGD':float(igd),'Points':len(F), 'AllPointsVisible':True,
                        'ObjectiveMinimum':F.min(axis=0).tolist(),
                        'ObjectiveMaximum':F.max(axis=0).tolist()})
    limits=[0.,4.5]
    assert sum(len(F) for F in points)==58
    assert all(np.all((F>=limits[0])&(F<=limits[1])) for F in points)
    with plt.rc_context(STYLE):
        fig,axes=plt.subplots(2,3,figsize=(4351/300,2725/300))
        fig.subplots_adjust(left=.064,right=.989,bottom=.091,top=.94,wspace=.24,hspace=.39)
        for ax,(alg,label),F in zip(axes.flat,ALG_LABELS,points):
            for part in parts:
                if len(part)>1:
                    ax.plot(part[:,0],part[:,1],c='black',lw=1.2,zorder=2)
                else:
                    ax.plot(part[:,0],part[:,1],'.',c='black',ms=3,zorder=2)
            ax.scatter(F[:,0],F[:,1],s=52,c='#ff0000',edgecolors='none',zorder=3)
            ax.set(title=label,xlabel=r'$f_1$',ylabel=r'$f_2$',xlim=limits,ylim=limits)
            ax.set_xticks(np.arange(5));ax.set_yticks(np.arange(5))
            ax.tick_params(direction='in',top=True,right=True,length=5,width=1.1,pad=4)
            ax.xaxis.labelpad=1;ax.yaxis.labelpad=1
            ax.set_title(label,pad=6)
        meta=export(fig,'Figure2_current',(4351,2725))
    return {'File':meta,'Problem':'CF2','D':10,'RunsPerAlgorithm':30,
            'RepresentativeRun':'IGD ascending, seed ascending tie-break; rank 15 of 30 (lower middle actual run).',
            'Objectives':'Raw objective values; no normalization, jitter, smoothing, or pooling.',
            'Limits':{'f1':limits,'f2':limits},'TotalPoints':58,
            'ReferenceFrontRequestedPoints':10000,'ReferenceFrontActualPoints':len(pf),
            'ReferenceFrontSegmentLengths':[len(part) for part in parts],
            'ReferenceFront':'Disconnected intervals plotted separately, including isolated point (0,1).',
            'SourceRuns':records}

def figure6():
    runs=rows('CF7_all_runs.csv')
    summary=rows('CF7_group_summary.csv')
    assert len(runs)==270
    assert len({r['ID'] for r in runs})==270
    assert all(r['Problem']=='CF7' and int(r['D'])==10 and r['Status']=='completed' and int(r['FE'])==500 for r in runs)
    groups=[(p,10) for p in [20,40,60,80,100]]+[(20,k) for k in [5,15,20,30]]
    stats={}
    for p,k in groups:
        group=[r for r in runs if int(r['Pmax'])==p and int(r['K'])==k]
        assert sorted(int(r['Seed']) for r in group)==list(range(1,31))
        x=np.array([float(r['IGD10000']) for r in group])
        assert len(x)==30 and np.isfinite(x).all()
        q1,med,q3=np.quantile(x,[.25,.5,.75],method='linear')
        sr=next(r for r in summary if int(r['Pmax'])==p and int(r['K'])==k)
        for a,key in [(np.mean(x),'IGD10000Mean30'),(np.std(x,ddof=1),'IGD10000SD30'),
                      (q1,'IGD10000Q1_30'),(med,'IGD10000Median30'),(q3,'IGD10000Q3_30')]:
            assert abs(a-float(sr[key]))<1e-12,(p,k,key,a,sr[key])
        iqr=q3-q1
        low=np.min(x[x>=q1-1.5*iqr]); high=np.max(x[x<=q3+1.5*iqr])
        stats[(p,k)]={'q1':float(q1),'med':float(med),'q3':float(q3),
                      'whislo':float(low),'whishi':float(high),
                      'fliers':x[(x<low)|(x>high)].tolist(),
                      'mean':float(x.mean()),'sd':float(x.std(ddof=1)),
                      'n':len(x),'minimum':float(x.min()),'maximum':float(x.max())}
    ymax=math.ceil(max(float(r['IGD10000']) for r in runs)+.3)
    assert abs(stats[(20,10)]['med']-2.684507680382489)<1e-12
    with plt.rc_context({**STYLE,'font.size':26,'axes.titlesize':32,
                         'axes.labelsize':30,'xtick.labelsize':26,'ytick.labelsize':26}):
        fig,axes=plt.subplots(1,2,figsize=(3900/300,1744/300))
        fig.subplots_adjust(left=.07,right=.985,bottom=.17,top=.885,wspace=.245)
        settings=[([(p,10) for p in [20,40,60,80,100]],[20,40,60,80,100],r'$P_{\max}$'),
                  ([(20,k) for k in [5,10,15,20,30]],[5,10,15,20,30],r'$K$')]
        for ax,(gs,labels,xlabel) in zip(axes,settings):
            b=[{**stats[g],'label':str(label)} for g,label in zip(gs,labels)]
            ax.bxp(b,showfliers=True,patch_artist=True,widths=.5,
                   boxprops={'facecolor':'#cbe2f0','edgecolor':'#0066a3','linewidth':1.5},
                   medianprops={'color':'#0066a3','linewidth':1.5},
                   whiskerprops={'color':'black','linewidth':1.3},
                   capprops={'color':'black','linewidth':1.3},
                   flierprops={'marker':'o','markersize':6,'markerfacecolor':'white',
                               'markeredgecolor':'#0066a3','markeredgewidth':1.2})
            ax.set(title='CF7',xlabel=xlabel,ylabel='IGD',ylim=(0,ymax))
            ax.set_yticks(np.arange(0,ymax+1,2))
            ax.set_title('CF7',pad=8)
            ax.tick_params(direction='in',top=True,right=True,length=5,width=1.2,pad=5)
            ax.xaxis.labelpad=5;ax.yaxis.labelpad=4
        meta=export(fig,'Figure6_current',(3900,1744))
    return {'File':meta,'Problem':'CF7','D':10,'InitialN':100,'MaxFE':500,
            'IndependentRecords':270,'Settings':9,'RunsPerSetting':30,'Seeds':'1-30',
            'DefaultSettingPlottedTwice':'Pmax20 K10 is the identical same 30-record group in both panels.',
            'LeftPanel':'Pmax20,40,60,80,100; K10 fixed',
            'RightPanel':'K5,10,15,20,30; Pmax20 fixed',
            'Metric':'Saved IGD10000 in raw objective units; all 270 records finite and included.',
            'BoxDefinition':'Quartiles: linear interpolation (type 7), matching the saved group_summary; median center; whiskers are extreme data within 1.5 IQR; all outside observations shown as open circles.',
            'YLimits':[0,ymax],'DefaultMean':stats[(20,10)]['mean'],
            'DefaultMedian':stats[(20,10)]['med'],
            'Groups':[{'Pmax':p,'K':k,**stats[(p,k)]} for p,k in groups]}

if __name__=='__main__':
    manifest={'Status':'pass','OptimizationRuns':0,'DataModified':False,
              'PythonVersion':sys.version,'MatplotlibVersion':matplotlib.__version__,
              'NumpyVersion':np.__version__,'Figure2':figure2(),'Figure6':figure6(),
              'DataSHA256':{p.name:SHA(p) for p in sorted(DATA.glob('*.csv'))}}
    (HERE/'figure_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'Status':manifest['Status'],'Figure2':manifest['Figure2']['File'],
                     'Figure6':manifest['Figure6']['File'],'DefaultMean':manifest['Figure6']['DefaultMean'],
                     'DefaultMedian':manifest['Figure6']['DefaultMedian']},indent=2))
