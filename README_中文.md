# CSASS公开代码与逐次结果包

本包与2026年11月18日工作稿的基准实验、消融、模型使用统计、预测误差、CF7敏感性和新耗时表对应。没有启动新的优化实验，也没有上传到GitHub。

## 先核对结果，不必重跑实验

在本目录打开终端：

```text
python scripts/verify_tables.py --root .
python scripts/verify_process.py --root .
python -m pip install -r requirements.txt
python scripts/verify_saved_metrics.py --root . --output verification_recomputed/saved_metrics
python scripts/verify_release_hashes.py --root .
```

前两项只需Python标准库；从解集重算IGD/HV需NumPy。脚本只读取保存数据，输出核验结果，不做优化、不改数据。paper_tables存放与论文一致的表格源片段。全部15,120份独立最终解集已复算核验；主表与消融重叠的540条自适应记录直接共享。

## MATLAB入口

在MATLAB R2023b、Windows 64位环境中，把当前目录切换到本目录，输入：

```matlab
MAIN_CSASS_PUBLIC
MAIN_CSASS_PUBLIC('benchmark','preflight')
```

不带参数只显示帮助，不会启动试验。只有显式输入第二个参数`run`才启动相应试验，详见英文README和docs/RUNNING.md。主比较、10维消融、20/50维消融、耗时、敏感性各有独立入口。不要直接用底层函数的默认核参数，也不要用历史全算法控制器启动当前CSASS。现有源代码中的V2为固定标识，不表示本次主表和消融使用了两套CSASS。

## 可行次数在哪

- data/Feasibility：主比较432组、消融90组的可行次数。
- data/Supplementary：S1来源、S2主表可行次数、S3消融可行次数、S4共享初始化核查、S5早晚违反RMSE。
- data/Main/main_runs.csv和data/Ablation/ablation_runs.csv：每个种子的最终可行非支配点数FeasibleND、IGD、HV。

每组“有可行解的运行次数”按FeasibleND>0统计。HV=0既可能是没有可行解，也可能有可行解但未对参考区域贡献正体积，二者已经分开。N/A仍遵循论文对30次完整统计的定义，不能据N/A推断30次全失败。

审稿人要求在论文/补充材料中报告这些次数，因此不能仅靠GitHub代替补充表。这里的数据文件可直接作为补充表的数据来源。

## 上传方式

1. 新建公开GitHub仓库，将本目录的内容作为仓库文件上传/提交；不要把私人完整归档、签字文件或整篇内部回复一起上传。
2. 创建固定版本Release，例如v1.0.0。
3. 将外层release_assets目录内全部CSASS_logs_*.zip与RELEASE_ASSETS_SHA256.csv附在同一个Release下。这些是可公开的逐点评价/过程日志，较大文件不直接放普通Git仓库。
4. 将发布后的Release链接填写到论文“代码与数据可用性”及审稿回复。当前说明未虚构URL。

立柱案例的原始运行、工程参考集、选中设计依据和有限元工程文件仍未完整找回，不能把本包称为可复现全部工程结果；具体缺口见docs/ENGINEERING_SCOPE.md。基准最终解集齐全，逐点评价账本的实际覆盖情况另有清单。

第三方版权说明保留于THIRD_PARTY_NOTICES.md及licenses目录；未擅自为全部代码设置MIT等新许可证。
