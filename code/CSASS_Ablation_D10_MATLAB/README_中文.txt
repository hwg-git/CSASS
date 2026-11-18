本机V2十维消融实验（2026-11-04）

范围：CF2、CF7、LIRCMOP1、LIRCMOP7、CF8、LIRCMOP13，全部D=10。
每题比较adaptive、rbf_only、kriging_only、fixed_rbf_obj_kriging_con、
fixed_kriging_obj_rbf_con五种配置，各30次（seed1—30）。
固定900次总矩阵、30组：复用360条经核验的同V2记录，新增540次。
新增为CF2与LIRCMOP1四固定配置各120次，以及CF8与LIRCMOP13各150次。

科学参数和21个算法核心文件完全不变：N100、FE500、Pmax20、K10、RBF多二次核。
IGD10000请求前沿，原目标尺度1；HV使用相同固定前沿min/range归一化及r1.1/3/20。
六题所有配置统一指标口径；保留全部种子、无可行解记录、正负统计结果。
不以接近历史IGD、算法获胜或HV增加为停止条件，也不自动扩大范围。

本机16GB内存，启动准备时可用约4.1GB，采用单MATLAB进程顺序计算，
每次试验1个计算线程，不创建parallel pool，不要求Parallel Computing Toolbox。
需要Statistics and Machine Learning Toolbox以运行ranksum统计。
运行前检查可用物理内存至少1GB、输出盘可用空间至少3GB。
资源不足则等待资源恢复；连续等待超过30分钟时安全停止，保留结果。
单次会话最长12小时，未启动任务可继续；失败、中断任务保留且不会自动重跑。

将当前文件夹设为本文件所在目录：
MAIN_CSASS_V2_D10                  启动/继续从未启动的任务
MAIN_CSASS_V2_D10('plan')          查看固定清单
MAIN_CSASS_V2_D10('preflight')     只核对源码与数据哈希
MAIN_CSASS_V2_D10('summarize')     只统计既有结果
MAIN_CSASS_V2_D10('collect')       打包已有结果与全部解集
MAIN_CSASS_V2_D10('hv',[1.1 3 20]) 只用保存的解集重算HV

输出在outputs/V2_Ablation_D10/：
status.json为当前状态、PID、已完成数、当前任务、耗时；
tables/包含逐次CSV、30组统计、120项消融检验、30行宽表及results.xlsx；
runs/每次保存最终F/X、500点评价账本、模型选择、逐点预测误差、训练样本ID、
完整MAT、配置和哈希完成标记。每30次更新CSV，每90次及结束时完整审计/Excel。
缓存中300条有finalF；CF2/LIRCMOP1十维adaptive共60条暂缺原始解集，已明确标注。
仅保留这些缓存原有的已核验指标，不虚构解集或自动重跑。

与另一台电脑全问题V2任务分开保存，后续合并时按版本/问题/维度/模式/种子去重。
如果导入另一台电脑对应adaptive结果，只能导入已完成并通过源码、参数及产物验证的
记录；已在本机启动或完成的任务绝不覆盖。本机D10未缓存的adaptive只有CF8/LIR13各30。
