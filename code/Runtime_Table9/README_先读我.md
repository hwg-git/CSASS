# 表9：统一条件耗时复测（480次）

本包只复测审稿人要求更新的耗时表。当前CSASS核心和三个对比算法源码均从已保留的完整归档按原字节提取；没有改算法机制、核函数、训练参数或评价预算。五个对比算法全量重测、CF2作图、CF7敏感性和立柱有限元不在本包内。

## 固定范围

CF1、CF7、LIRCMOP1、LIRCMOP7，均10维；HeEMOEA、MO-L2SMEA、PC-SAEA、CSASS；每组种子1–30，共16组480次。N=100，真实评价预算500；CSASS的Pmax=20、K=10。

本次用10维是本轮统一计时协议的明确设置；旧耗时表未单独注明维度。Pmax和K只规定CSASS，其他算法保留各自冻结设置。对手是当前主比较所使用的冻结实现，不是另外尝试过的CDP修改版。

## 在另一台电脑运行

1. 解压本ZIP。打开一个新的MATLAB（Windows 64位，R2020b及以上，需Statistics and Machine Learning Toolbox及Deep Learning Toolbox），将“当前文件夹”切换到包含 MAIN_CSASS_RUNTIME.m 的目录。
2. 为比较单次耗时，关闭其他MATLAB任务和并行池，不要同时运行另一批实验。插电并保持同一个Windows电源计划；本包不修改系统电源设置。
3. 先在命令窗口执行：

```matlab
MAIN_CSASS_RUNTIME('preflight')
MAIN_CSASS_RUNTIME('selftest')
```

这两步不启动基准优化试验。selftest仅用合成小数据核查依赖和选择/指标规则；run也会自动先做这些预检，因此可以直接使用下一条run命令。

4. 检查通过后执行唯一启动命令：

```matlab
MAIN_CSASS_RUNTIME('run')
```

串行运行，一个试验使用一个计算线程。即使电脑有6核，也不同时启动6个试验，避免CPU、内存带宽竞争影响耗时表。线程设置在本函数退出后恢复。

进度、ETA每完成4次更新一次。首次完成4次前不依据旧电脑耗时给出承诺。

## 计时范围

开始：生成初始样本之前。结束：完成搜索并得到最终可行非支配解集之后。计入采样、真实评价、模型训练、搜索、内存记录和最终筛选；不计MATLAB启动、路径/对象准备、IGD/HV、作图、文件保存、CSV/Excel汇总。

CSASS使用冻结核心内已有的准确起止计时，三个对比算法使用相同工作范围的外部计时。算法内部框架与内存记录开销仍保留；终端文字先在内存中收集，计时后保存。没有额外优化预热，也不剔除第一次或慢速运行。种子之间轮换算法顺序，减少固定先后顺序带来的影响。

## 保存位置与发回内容

结果目录：outputs/Runtime_Table9_480/。

- tables/runtime_table.csv：4问题×4算法，均值（样本标准差）。30次全部完整后才填正式均值。
- tables/runtime_summary.csv、run_results.csv、group_progress.csv：完整汇总、逐次秒数和进度；Excel工作簿与CSV同步（若Excel导出失败，CSV仍保留）。
- runs/<试验ID>/：原始解集、500条真实评价账本、MAT诊断数据、逐次耗时、附带IGD/HV、配置、文件SHA256。
- environment.json、sessions/：CPU、内存、操作系统、MATLAB、BLAS、线程、Windows电源计划、会话信息。
- final_audit.json：只有480次完成且文件核验通过后才生成pass。

IGD、HV从本次最终解集计算，仅作核验；计算它们不占用耗时测量区间，也不会自动覆盖论文已有指标表。没有可行解仍是正常完成的试验，其耗时纳入统计。

完成后自动打包；随时也可执行：

```matlab
MAIN_CSASS_RUNTIME('status')
MAIN_CSASS_RUNTIME('collect')
```

请发回collect输出的结果ZIP，而不只是Excel。结果包含本次源码及全部逐次记录，便于回应审稿人的实现一致性与代码公开要求；打包并不等于已经公开发布。

## 暂停、续跑和异常

安全暂停：在 outputs/Runtime_Table9_480 中新建名为 STOP_AFTER_CURRENT.json 的空文件（资源管理器即可），当前试验结束后自动停止。也可从另一个MATLAB命令窗口调用MAIN_CSASS_RUNTIME('stop')，但不要让第二个MATLAB同时运行计算。

正常暂停后，在原电脑、原MATLAB版本和电源计划下重新执行run即可，已完成记录经哈希验证后跳过。不要修改清单、源码或输出中的已完成记录。

如果出现失败或按Ctrl+C中断了试验，本包保留该试验，不自动重跑，也不换种子。执行collect把记录发回分析。异常退出后如残留coordinator.lock，应先确认原运行已结束再处理，不能在原进程运行时删除锁。不要直接删除失败目录来补跑。

## 数据含义

这是新测的受控耗时比较；结论以实际输出为准，不预设CSASS必须更快。全部结果均保留，统计不根据IGD/HV优劣或是否有可行解删选。表9的最终数值、机器说明和审稿回复需要完成后再同步更新。
