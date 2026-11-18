from pathlib import Path
from copy import deepcopy
from datetime import datetime
import hashlib
import json
import shutil
import sys
import zipfile

sys.path.append(str(Path(__file__).resolve().parent / 'scientific_python'))
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter
from docx import Document
from docx.text.paragraph import Paragraph
from docx.table import Table
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).resolve().parents[1]
MERGE = ROOT / 'outputs/CSASS_Ablation_D10D20D50_Merged_20261105'
OUT = ROOT / 'output/CSASS_Round2_HV_20261104'
DEST = OUT / 'Reviewer_1_Round_2_Response_Chinese.docx'
DATA = OUT / 'Selection_Statistics'
DATA.mkdir(exist_ok=True)
BLUE = '0050A4'
problems = ['CF2', 'CF7', 'CF8', 'LIRCMOP1', 'LIRCMOP7', 'LIRCMOP13']
keys = [(p, d) for p in problems for d in [10, 20, 50]]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

audit = json.loads((MERGE / 'audit/merge_audit.json').read_text(encoding='utf-8'))
assert audit['Status'] == 'pass' and audit['AdaptiveMissingGroups'] == []
source_paths = [MERGE/'tables'/n for n in ['model_selection_run_level.csv', 'selection_frequency.csv', 'selection_by_stage.csv']]
source_hashes = {str(p): digest(p) for p in source_paths}
ledger = pd.read_csv(source_paths[0])
ledger = ledger.loc[ledger.Mode.eq('adaptive')].sort_values(['ID', 'Stage']).copy()
old_summary = pd.read_csv(source_paths[1])
old_summary = old_summary.loc[old_summary.Mode.eq('adaptive')]
assert len(ledger) == 21600 and ledger.ID.nunique() == 540
assert not ledger.duplicated(['ID', 'Stage']).any()
assert len(ledger.groupby(['Problem', 'D'])) == 18
per_run = []
for run_id, g in ledger.groupby('ID', sort=False):
    assert len(g) == 40 and g.Stage.tolist() == list(range(1, 41))
    assert g.Seed.nunique() == 1 and g.Mode.nunique() == 1
    assert g.UsedObjectiveModel.isin([1, 2]).all() and g.UsedConstraintModel.isin([1, 2]).all()
    assert g.UsedObjectiveModel.iloc[0] == g.UsedConstraintModel.iloc[0] == 1
    assert np.array_equal(g.FEbefore, np.arange(100, 500, 10))
    assert np.array_equal(g.FEafter, np.arange(110, 510, 10))
    assert np.array_equal(g.NextObjectiveModel.iloc[:-1], g.UsedObjectiveModel.iloc[1:])
    assert np.array_equal(g.NextConstraintModel.iloc[:-1], g.UsedConstraintModel.iloc[1:])
    row = dict(ID=run_id, Problem=g.Problem.iloc[0], D=int(g.D.iloc[0]), Seed=int(g.Seed.iloc[0]))
    for task, col in [('Objective', 'UsedObjectiveModel'), ('Constraint', 'UsedConstraintModel')]:
        choices = g[col].to_numpy()
        row[task+'RBFRatio'] = float(np.mean(choices == 1))
        row[task+'Switches'] = int(np.count_nonzero(np.diff(choices)))
        row[task+'SwitchesAfterInitialization'] = int(np.count_nonzero(np.diff(choices[1:])))
    per_run.append(row)
per_run = pd.DataFrame(per_run)
rows = []
phase_rows = []
for problem, dimension in keys:
    g = ledger.loc[ledger.Problem.eq(problem) & ledger.D.eq(dimension)]
    s = per_run.loc[per_run.Problem.eq(problem) & per_run.D.eq(dimension)]
    assert len(s) == 30 and sorted(s.Seed.tolist()) == list(range(1, 31))
    row = dict(Problem=problem, D=dimension, Runs=30, StagesPerRun=40, TaskStageRecords=1200)
    check = old_summary.loc[old_summary.Problem.eq(problem) & old_summary.D.eq(dimension)].iloc[0]
    for task, col in [('Objective', 'UsedObjectiveModel'), ('Constraint', 'UsedConstraintModel')]:
        n_rbf = int(g[col].eq(1).sum())
        row[task+'RBFCount'] = n_rbf
        row[task+'KrigingCount'] = 1200 - n_rbf
        row[task+'RBFPercent'] = 100 * n_rbf / 1200
        row[task+'KrigingPercent'] = 100 - row[task+'RBFPercent']
        row[task+'SwitchMean'] = float(s[task+'Switches'].mean())
        row[task+'SwitchSD'] = float(s[task+'Switches'].std(ddof=1))
        row[task+'RunsWithSwitches'] = int(s[task+'Switches'].gt(0).sum())
        assert row[task+'RBFCount'] == int(check['UsedRBF'+task])
        assert int(s[task+'Switches'].sum()) == int(check[task+'UsedSwitches'])
    rows.append(row)
    for start, end in [(1, 10), (11, 30), (31, 40)]:
        h = g.loc[g.Stage.between(start, end)]
        phase_rows.append(dict(Problem=problem, D=dimension, FirstStage=start, LastStage=end,
            ObjectiveRBFPercent=100*h.UsedObjectiveModel.eq(1).mean(),
            ConstraintRBFPercent=100*h.UsedConstraintModel.eq(1).mean()))
summary = pd.DataFrame(rows)
summary.to_csv(DATA/'selection_summary.csv', index=False, encoding='utf-8-sig')
per_run.to_csv(DATA/'switching_per_run.csv', index=False, encoding='utf-8-sig')
pd.DataFrame(phase_rows).to_csv(DATA/'selection_early_middle_late.csv', index=False, encoding='utf-8-sig')

stage = ledger.assign(ObjectiveRBF=ledger.UsedObjectiveModel.eq(1), ConstraintRBF=ledger.UsedConstraintModel.eq(1))
stage = stage.groupby(['Problem', 'D', 'Stage'])[['ObjectiveRBF', 'ConstraintRBF']].mean().reset_index()
assert len(stage) == 720
stage.to_csv(DATA/'selection_40_stages.csv', index=False, encoding='utf-8-sig')

with plt.rc_context({'font.family': 'Arial', 'font.size': 9, 'pdf.fonttype': 42,
                     'svg.fonttype': 'none', 'axes.linewidth': 0.5}):
    fig, axes = plt.subplots(2, 1, figsize=(6.55, 7.1), layout='constrained')
    labels = [f'{p}  D={d}' for p, d in keys]
    for ax, metric, title in zip(axes, ['ObjectiveRBF', 'ConstraintRBF'],
                                ['(a) Objective models', '(b) Constraint-violation models']):
        mat = np.array([stage.loc[stage.Problem.eq(p) & stage.D.eq(d)].sort_values('Stage')[metric].to_numpy() for p, d in keys])
        assert mat.shape == (18, 40) and np.isfinite(mat).all()
        im = ax.imshow(mat, aspect='auto', cmap='cividis', vmin=0, vmax=1, interpolation='nearest',
                       extent=(0.5, 40.5, 18.5, 0.5))
        ax.set_yticks(range(1, 19), labels, fontsize=8.0)
        ax.set_xticks([1, 10, 20, 30, 40])
        ax.set_xlabel('Update stage', fontsize=9)
        ax.set_title(title, loc='left', fontsize=10, pad=6)
        ax.tick_params(length=2, pad=3)
        for boundary in [3.5, 6.5, 9.5, 12.5, 15.5]:
            ax.axhline(boundary, color='white', linewidth=0.7)
    cb = fig.colorbar(im, ax=axes, location='bottom', shrink=0.65, fraction=0.035, pad=0.025)
    cb.set_ticks([0, 0.25, 0.5, 0.75, 1])
    cb.ax.xaxis.set_major_formatter(PercentFormatter(1))
    cb.set_label('RBF use across 30 runs; Kriging = 100% − RBF', fontsize=9)
    fig.savefig(DATA/'selection_by_stage.png', dpi=400, facecolor='white')
    fig.savefig(DATA/'selection_by_stage.pdf', facecolor='white')
    fig.savefig(DATA/'selection_by_stage.svg', facecolor='white')
    plt.close(fig)

response = [
    '感谢审稿人对模型选择频率提出的具体建议。这项统计有助于直接呈现两种代理模型在搜索中的实际使用情况，并回答模型是否发生切换，以及是否持续偏向某一种模型。',
    '根据您的建议，我们已汇总CF2、CF7、CF8、LIRCMOP1、LIRCMOP7和LIRCMOP13在10、20、50维下各30次独立运行的模型选择记录，共540次运行。我们分别统计目标预测和总约束违反度预测中RBF与Kriging的使用比例、每次运行的切换次数，并展示全部40个更新阶段的使用比例变化，具体见本回复的表R1和图R1。',
    '结果表明，两项预测任务具有不同的模型使用偏好。以CF2十维为例，目标模型使用Kriging的比例为78.9%，平均每次运行切换14.83次，而约束违反度模型始终使用RBF；在CF8二十维上，目标模型使用RBF的比例为79.8%，约束违反度模型使用Kriging的比例为59.7%，两项任务平均分别切换10.27次和29.70次。图R1进一步展示了阶段变化：CF2十维目标模型的RBF使用比例从第1–10阶段的32.0%降至第31–40阶段的16.7%；LIRCMOP13五十维则由78.7%增至95.0%。',
    '我们也保留了持续采用同一模型的结果：CF2、LIRCMOP7和LIRCMOP13在三个维度上的约束违反度模型均始终使用RBF。因此，自适应选择的实际行为既包括模型间的切换，也包括某项预测任务持续采用同一种模型。上述统计直接呈现了这两类情况及其随搜索阶段的变化。',
]
location = '第4.2节 Analysis of Experimental Results末尾、Parameter Sensitivity Analysis小节之前，拟加入模型选择统计表和逐阶段变化图，并补充下列统计口径及结果说明。以下为中文拟稿，尚未写入论文正文。'
excerpts = [
    '在CF2、CF7、CF8、LIRCMOP1、LIRCMOP7和LIRCMOP13的10、20、50维实验中，分别统计30次独立运行的模型使用情况。每次运行包含40个更新阶段，目标模型与总约束违反度模型分别记录。使用比例按各组全部1200个阶段计算；切换次数为相邻阶段实际使用的模型发生变化的次数，报告30次运行的均值和样本标准差。第1阶段采用初始RBF模型，之后的阶段使用前一阶段更新后选定的模型；最后一次更新后未继续用于搜索的模型选择不计入使用比例。',
    '模型使用偏好随预测任务、问题及维度而变化。CF2的目标模型主要使用Kriging，而其约束违反度模型始终使用RBF；CF8则表现为目标模型较多使用RBF、约束违反度模型较多使用Kriging。模型比例也随搜索阶段变化，例如CF2十维目标模型的RBF使用比例由前10个阶段的32.0%降至末10个阶段的16.7%，LIRCMOP13五十维则由78.7%增至95.0%。CF2、LIRCMOP7和LIRCMOP13的约束违反度模型在全部阶段保持RBF，反映了这些任务上的稳定模型使用情况。',
]

backup = OUT/'Audit'/('BeforeSelectionReply_'+datetime.now().strftime('%Y%m%d_%H%M%S'))
backup.mkdir(parents=True)
for ext in ['docx', 'pdf', 'txt']:
    p = DEST.with_suffix('.'+ext)
    if p.exists(): shutil.copy2(p, backup/p.name)
doc = Document(DEST)
old_paras = list(doc.paragraphs)
heading_i = next(i for i,p in enumerate(old_paras) if p.text == '5. Selection frequencies: not addressed')
slot = old_paras[heading_i+3]
assert slot.text == '' and old_paras[heading_i+2].text == 'Authors’ response'
original_xml = [p._p.xml for p in old_paras if p is not slot]
original_comments = [p.text for p in old_paras if p.text.startswith('Reviewer comment (verbatim):')]
anchor = slot._p

def add(text='', bold=False, size=None, page_break=False, after=5, keep_next=False):
    global anchor
    el = deepcopy(slot._p)
    for child in list(el):
        if child.tag != qn('w:pPr'): el.remove(child)
    anchor.addnext(el)
    anchor = el
    p = Paragraph(el, doc._body)
    p.paragraph_format.space_after = Pt(after)
    p.paragraph_format.keep_together = False
    p.paragraph_format.keep_with_next = keep_next or bold
    p.paragraph_format.page_break_before = page_break
    r = p.add_run(text)
    r.bold = bold
    r.font.name = 'Arial'
    r.font.color.rgb = RGBColor.from_string(BLUE)
    r._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'), '宋体')
    if size: r.font.size = Pt(size)
    return p

for t in response: add(t)
add('正文拟补充位置', bold=True)
add(location)
add('正文对应内容 中文拟稿', bold=True)
for t in excerpts: add(t)
add('表R1 模型选择统计', bold=True, page_break=True)
table = doc.add_table(rows=1, cols=6)
table.autofit = False
anchor.addnext(table._tbl)
anchor = table._tbl
widths = [1.05, 0.36, 1.42, 1.42, 1.17, 1.17]
headers = ['问题', 'D', '目标模型\nRBF / Kriging (%)', '约束违反度模型\nRBF / Kriging (%)', '目标模型\n切换次数', '约束违反度模型\n切换次数']
table.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
for j,w in enumerate(widths): table.columns[j].width = Inches(w)
for j,t in enumerate(headers): table.rows[0].cells[j].text = t
for row in rows:
    cells = table.add_row().cells
    values = [row['Problem'], str(row['D']),
        f"{row['ObjectiveRBFPercent']:.1f} / {row['ObjectiveKrigingPercent']:.1f}",
        f"{row['ConstraintRBFPercent']:.1f} / {row['ConstraintKrigingPercent']:.1f}",
        f"{row['ObjectiveSwitchMean']:.2f} ({row['ObjectiveSwitchSD']:.2f})",
        f"{row['ConstraintSwitchMean']:.2f} ({row['ConstraintSwitchSD']:.2f})"]
    for cell,value in zip(cells, values): cell.text = value
for i,row in enumerate(table.rows):
    row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
    for j,cell in enumerate(row.cells):
        cell.width = Inches(widths[j])
        cell.vertical_alignment = 1
        tcpr = cell._tc.get_or_add_tcPr()
        margins = OxmlElement('w:tcMar')
        for side in ['top','bottom']:
            e = OxmlElement('w:'+side);e.set(qn('w:w'),'65');e.set(qn('w:type'),'dxa');margins.append(e)
        tcpr.append(margins)
        for p in cell.paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT if j==0 else WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.space_before = Pt(0);p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1
            for r in p.runs:
                r.font.name='Arial';r.font.size=Pt(9);r.font.bold=(i==0)
                r.font.color.rgb=RGBColor.from_string(BLUE)
                r._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'宋体')
    if i==0 or i==18 or (i>0 and i%3==0):
        for cell in row.cells:
            borders=OxmlElement('w:tcBorders')
            b=OxmlElement('w:bottom');b.set(qn('w:val'),'single');b.set(qn('w:sz'),'8' if i in [0,18] else '3');b.set(qn('w:color'),'7E8A96');borders.append(b)
            if i==0:
                b=OxmlElement('w:top');b.set(qn('w:val'),'single');b.set(qn('w:sz'),'8');b.set(qn('w:color'),'7E8A96');borders.append(b)
            cell._tc.get_or_add_tcPr().append(borders)
add('注：D为决策维度。各组包含30次独立运行，每次40个更新阶段。模型使用比例为全部1200个阶段中的占比；切换次数为均值（样本标准差），包含初始RBF阶段与其后阶段之间的变化。', size=9, after=10)
add('图R1 模型使用比例随更新阶段的变化', bold=True, page_break=True)
p = add('', after=5)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run().add_picture(str(DATA/'selection_by_stage.png'), width=Inches(6.55))
pic = p._p.xpath('.//wp:docPr')[0]
pic.set('descr', '两幅热图展示18个问题与维度组合的40个更新阶段中RBF的使用比例。目标与约束违反度任务分别显示；CF2、LIRCMOP7及LIRCMOP13的约束模型全部使用RBF。')
add('图注：每个色块表示该阶段30次运行中使用RBF的比例，Kriging比例为100%减去RBF比例。上、下图分别对应目标预测和总约束违反度预测。第1阶段为初始RBF模型，之后展示实际用于搜索的模型。', size=9, after=18)
slot._p.getparent().remove(slot._p)
doc.save(DEST)

saved = Document(DEST)
saved_xml = [p._p.xml for p in saved.paragraphs]
preserved = [x for x in saved_xml if x in original_xml]
assert preserved == original_xml
assert original_comments == [p.text for p in saved.paragraphs if p.text.startswith('Reviewer comment (verbatim):')]
assert len(saved.tables) == len(doc.tables)
lines = []
for e in saved.element.body:
    if e.tag == qn('w:p'): lines.append(Paragraph(e,saved._body).text)
    elif e.tag == qn('w:tbl'): lines.extend(' | '.join(c.text for c in row.cells) for row in Table(e,saved._body).rows)
DEST.with_suffix('.txt').write_text('\n'.join(lines), encoding='utf-8')
content = dict(comment_number=5, response_paragraphs=response, proposed_location=location, proposed_manuscript_paragraphs=excerpts,
    manuscript_edited=False, table='表R1', figure='图R1', frequency_basis='40 actually used stages including the initial RBF stage; unused final next-model decision excluded',
    source_hashes=source_hashes, total_runs=540, groups=18, stages_per_run=40, records_per_task=21600,
    objective_runs_with_switches=int(per_run.ObjectiveSwitches.gt(0).sum()), constraint_runs_with_switches=int(per_run.ConstraintSwitches.gt(0).sum()),
    objective_runs_with_post_initial_switches=int(per_run.ObjectiveSwitchesAfterInitialization.gt(0).sum()),
    constraint_runs_with_post_initial_switches=int(per_run.ConstraintSwitchesAfterInitialization.gt(0).sum()),
    raw_logs_changed=False, no_exclusions=True, optimization_rerun=False, backup=str(backup))
(OUT/'selection_reply_content.json').write_text(json.dumps(content, ensure_ascii=False, indent=2),encoding='utf-8')
qa = dict(status='pass',changed_comment=5,original_paragraphs_preserved=len(original_xml),reviewer_comments_verbatim=True,
          hv_response_unchanged=True,scope='reply and descriptive statistics only',manuscript_edited=False,
          source_hashes_unchanged=all(digest(Path(p))==h for p,h in source_hashes.items()),runs=540,groups=18,stages_per_run=40)
(OUT/'Audit/selection_reply_audit.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(qa,ensure_ascii=False,indent=2))
