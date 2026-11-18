剩余8个问题：五个对比算法重跑包

一、启动
完整解压ZIP，打开其中CSASS_Missing8_MATLAB文件夹。
在另一台Windows电脑的MATLAB中，将当前文件夹切换到这里，输入：

MAIN_MISSING8

默认开启6个本机进程worker，每个worker单计算线程。
需要Parallel Computing Toolbox、Statistics and Machine Learning Toolbox、Deep Learning Toolbox。
含Windows64 LIBSVM组件；不使用GPU。只打包代码时已做零评价检查，不含本机新实验结果。

二、固定范围
问题：CF2、CF3、CF4、CF6、LIRCMOP5、LIRCMOP6、LIRCMOP9、LIRCMOP10。
维度：10、20、50。算法：A-NSGA-III、HeEMOEA、MO-L2SMEA、PC-SAEA、C-TAEA。
每组种子1—30，共120组、3600次；每次实际初始种群100、真实评价500。
这些问题均为双目标，没有91个方向的情况。
CSASS当前数据已有，本包不重复CSASS，不包含消融或新候选方法。
Pmax=20、K=10属于CSASS参数，不强加给五个对手。

三、保持一致的实验规则
算法入口、问题定义、共享LHS初始化、严格500点评价截断以及最终解集提取，
均沿用之前全量实验的代码，不切换到各算法不同的原生初始样本数。
主IGD使用冻结的GetOptimum(10000)参考前沿；同时保留PF2000诊断IGD。
IGD和HV使用每次同一个真实评价所得的最终可行非支配集。
HV按PF10000上下界归一化，主参考点(1.1,1.1)，另存(3,3)与(20,20)敏感性结果；
不截断目标值、不除以参考盒体积、不按结果挑参考点。
旧算法和旧结果不会改动；这些是重新运行的记录，不是恢复出的历史原始解集。

四、输出
outputs/Missing8_Opponents/tables：全部逐次CSV、120组汇总、IGD/HV矩阵和Excel。
outputs/Missing8_Opponents/runs：每次最终决策/目标/约束、初始点、500条评价账本、
原始MAT、配置、完成标记及文件SHA256。请保留整个目录。
IGD出现Inf时保留原值，汇总展示N/A；HV=0也保留，统计不删除失败获取可行解的运行。
程序执行报错与成功运行但无可行解分别记录。
每完成30次更新CSV；结束后生成Excel，并独立重算全部保存解集进行最终审计。
全部完成并通过审计后，自动在returns文件夹生成CSASS_MISSING8_RESULTS_*.zip。
把这个ZIP发回来即可，不需要另外整理CSV或MAT。

五、恢复和收集
再次运行MAIN_MISSING8：跳过已完成记录，只启动从未运行的任务。
失败或中断的记录保留，不自动重跑；已有结果不覆盖。
若出现单次失败，停止派发新任务，等待已在跑的任务完成，再输出诊断。
单次启动最多派发24小时，达到时限后让当前任务完成；剩余任务可用同一命令续跑。
未全部结束时也可打包已有记录：MAIN_MISSING8('collect')。
只刷新CSV/Excel：MAIN_MISSING8('summarize')。
只检查文件和任务：MAIN_MISSING8('preflight')。
已打开且正在执行其他任务的并行池不会被中止。空闲池会重新创建，避免加载旧工程类。

六、预计时间
按对应历史任务耗时，6核理想并行约8.2小时；实际时间取决于电脑、并发及导出开销。
需要足够空间保存完整解集和打包副本。不要只发送表格后删除runs。
不要修改协议、算法文件或种子；源文件校验会检测这些变化。

算法来源及版权保留在各源文件头部。公共算法代码来自PlatEMO，实验初始化适配沿用已有项目。
