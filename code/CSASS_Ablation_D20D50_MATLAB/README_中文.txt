CSASS 消融实验：20维与50维

一、启动
完整解压ZIP。在MATLAB中将“当前文件夹”切换到本文件所在目录（能看到MAIN_CSASS_ABLATION.m），运行：

    MAIN_CSASS_ABLATION

需要 Parallel Computing Toolbox 和 Statistics and Machine Learning Toolbox。
程序使用6个本机进程，每个进程1个计算线程，不依赖GPU。算法、问题、参考前沿与依赖函数均已包含。
请先结束另一批MATLAB实验；本程序不会取消其他实验或删除其数据。

首次启动会让你选择是否复用已有全量CSASS结果：
- 推荐选择另一台电脑上 CSASS_V2_AllBenchmarks_MATLAB 文件夹，或其中 outputs/V2_AllBenchmarks。
- 只有算法源、问题、参考前沿、参数、种子和文件哈希均一致，才会导入对应的360次自适应结果。
- 选定的源实验必须已停止，且这360次对应结果已完成；否则会停止并说明原因，不重复跑这些记录。
- 导入后，仅新增1440次固定模型对照，总表仍为1800次。
- 取消文件夹选择会安全退出，不启动试验。
- 如果确实没有可复用的全量结果，可明确运行 MAIN_CSASS_ABLATION('run_independent')，执行完整1800次独立清单。这个选择会记录在本输出目录。
- 下次执行同一主命令会跳过本目录已完成的试验；360次导入结果完成本地校验后，不再依赖原来源目录。

二、范围与参数
问题：CF2、CF7、CF8、LIRCMOP1、LIRCMOP7、LIRCMOP13。
维度：20、50。已完成的10维试验不包含在此运行清单中。
五种配置：自适应CSASS、仅RBF、仅Kriging、目标RBF/约束违反度Kriging、目标Kriging/约束违反度RBF。
每个问题×维度×配置使用固定种子1–30，共60组、1800次。
N=100，MaxFE=500，Pmax=20，K=10；沿用10维消融的完整算法实现，只扩展问题维度。
IGD使用冻结的GetOptimum(10000)请求前沿、原目标尺度；具体前沿点数由问题定义决定。
HV按相同问题的冻结前沿归一化，统一计算r=1.1、3、20。各配置采用相同规则，不按结果改变参考点。
运行清单和算法源码已锁定；请勿改源码、参数、种子后混入同一输出目录。
底层文件的V2是追踪实现一致性的内部标识；供论文使用的表格显示算法名称CSASS。

三、结果在哪里
    outputs/Ablation_D20D50/tables/results.xlsx
    outputs/Ablation_D20D50/tables/group_summary.csv
    outputs/Ablation_D20D50/tables/ablation_paper_style.csv
    outputs/Ablation_D20D50/tables/ablation_statistics.csv
    outputs/Ablation_D20D50/tables/all_runs.csv
    outputs/Ablation_D20D50/tables/paper_IGD_comparison.csv

每30次完成后更新CSV；定期及最终写Excel。请勿在运行期间用Excel锁住results.xlsx。
IGD和HV均统计30次；IGD若含非有限值，论文式表格显示N/A，显著性符号按有效观测计算。
原始明细仍保存所有值和有限结果数；HV的0保留为0。另有包含失败的IGD秩检验供敏感性核对。
五种配置的模式选择日志均保存；固定配置不会被写成自适应选择。

每次运行目录：outputs/Ablation_D20D50/runs/<ID>/
其中 final_objectives.csv、final_decisions.csv 是最终真实可行非支配解集。
还保存500次真实评价记录、模型选择、预测误差、训练样本编号、诊断MAT文件与配置/哈希。
无可行解的完整试验也保留，不自动重跑，不把失败当作成功。

四、结束后发送给我
成功完成时自动汇总、审核、生成 returns/CSASS_D20D50_RESULTS_日期_标识.zip。
把这一个ZIP传回即可，里面包含CSV、Excel、全部解集和日志，方便核对、合并10维数据并统计HV。
如果实验已完成但打包失败，可再次运行：

    MAIN_CSASS_ABLATION('collect')

其他命令（均不跑新的优化）：
    MAIN_CSASS_ABLATION('plan')       % 只核对范围和进度
    MAIN_CSASS_ABLATION('summarize')  % 用已保存结果重新汇总
    MAIN_CSASS_ABLATION('hv',[1.1,3,20]) % 用保存解集重算HV
    MAIN_CSASS_ABLATION('import')     % 重新选择同实现的全量结果目录

五、断点与资源
尽量让正在运行的批次自然结束。已完成任务自动跳过；中断/报错留下的部分记录不删除、不自动重试。
内存或磁盘不足会暂停派发，当前任务先自然结束，最多等待30分钟；仍不足就保存状态停止。
单次会话最多72小时，达到后停止派发并让在途任务完成。未启动任务可再次运行主命令继续。
原始1800次清单不因结果好坏扩大或提前停止。出现错误时保留提示和输出目录，不要手动删runs子目录。
