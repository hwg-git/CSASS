"""Independent, watermark-free rendering from CSV; no Origin export is edited."""
from pathlib import Path
import sys, csv, json, hashlib, shutil
sys.path.append(str(Path(__file__).resolve().parent/'scientific_python'))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/CSASS_Round2_HV_20261104/Accuracy_Statistics/Origin_Figures_20261105'
SOURCE=OUT.parent/'Reply_Figures_AllDimensions/all_available_stage_means.csv'
rows=list(csv.DictReader(SOURCE.open(encoding='utf-8-sig',newline='')))
cases=[('CF8',20),('LIRCMOP1',50),('LIRCMOP7',20),('LIRCMOP13',10)]
colors=['#0050A4','#A74B00','#32764D']
with plt.rc_context({'font.family':'Arial','font.size':10,'pdf.fonttype':42,'svg.fonttype':'none','axes.linewidth':0.7}):
    for task in ['objectives','constraint']:
        fig,axes=plt.subplots(2,2,figsize=(6.55,5.3),layout='constrained')
        for i,((prob,d),ax) in enumerate(zip(cases,axes.flat)):
            data=[r for r in rows if r['Problem']==prob and int(r['D'])==d]
            responses=[r for r in ['f1','f2','f3'] if r in {h['Response'] for h in data}] if task=='objectives' else ['CV']
            for k,r in enumerate(responses):
                h=sorted((v for v in data if v['Response']==r),key=lambda v:int(v['Stage']))
                assert len(h)==40 and all(int(v['Runs'])==30 for v in h)
                ax.plot([int(v['Stage']) for v in h],[float(v['MeanRMSE']) for v in h],
                        color=colors[k],ls=['-','--',':'][k],lw=1.25,label=f'$f_{{{k+1}}}$')
            ax.set_title(f'({chr(97+i)}) {prob}, D = {d}',loc='left',fontsize=10.5,pad=8)
            ax.set_xlim(0,40);ax.set_ylim(bottom=0)
            ax.set_xticks([0,10,20,30,40]);ax.yaxis.set_major_locator(MaxNLocator(nbins=4,steps=[1,2,2.5,5,10]))
            ax.set_xlabel('Surrogate update stage',fontsize=10);ax.set_ylabel('Mean RMSE',fontsize=10)
            ax.tick_params(direction='out',length=3,width=0.6,labelsize=9)
            ax.grid(axis='y',color='#E6E6E6',lw=0.45)
            if task=='objectives':ax.legend(loc='upper right',ncol=len(responses),fontsize=8.5,frameon=False,handlelength=1.6,columnspacing=.7,handletextpad=.35)
        for ext in ['png','pdf','svg']:
            fig.savefig(OUT/f'four_cases_{task}.{ext}',dpi=500,facecolor='white')
        plt.close(fig)
shutil.copy2(SOURCE,OUT/'all_available_stage_means.csv')
shutil.copy2(ROOT/'tmp/plot_accuracy_origin.py',OUT/'plot_in_origin.py')
shutil.copy2(Path(__file__),OUT/'plot_without_origin_export.py')
(OUT/'README.txt').write_text('Native editable project: CSASS_Prediction_Error_40Stages.opju\nOrigin version: 2026b SR2. Its current export adds a demo watermark; *_Origin_demo files are retained only for diagnostic provenance and are not used in the response.\nThe clean PNG/PDF/SVG files are freshly rendered from all_available_stage_means.csv using Matplotlib, not by modifying Origin output.\n40 stages, 30 independent runs per curve point; original response scales, no smoothing, no omitted stages.\n',encoding='utf-8')
(OUT/'clean_render_audit.json').write_text(json.dumps({'renderer':'Matplotlib','native_project_renderer':'Origin 2026b SR2','origin_export_limitation':'demo watermark','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'no_origin_image_modified':True,'cases':cases,'points_per_curve':40,'runs_per_point':30},indent=2),encoding='utf-8')
print('Clean plots exported from source CSV.')
