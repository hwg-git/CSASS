CSASS 固定 V2：全问题补齐实验（6 个进程）

一、运行范围
CF1—CF10、LIRCMOP1—LIRCMOP14；D=10、20、50；每个问题和维度固定种子 1—30。
总计 72 组、2160 次。包内复用已完成的 210 次，本次只新增 1950 次。
复用组均为 D10：CF2、CF7、LIRCMOP1、LIRCMOP2、LIRCMOP3、LIRCMOP4、LIRCMOP7，各 30 次。
这些缓存来自此前完成并核验的 V2 实验；逐次来源及 SHA256 记录在 baseline/completed_runs.csv 和 baseline/provenance.json。
缓存被排除在调度清单之外，不会重复运行，也不会按指标值筛选种子。

二、一条命令开始
将整个 ZIP 解压到本地目录；在 MATLAB 中把当前文件夹切换到包含 MAIN_CSASS_V2_ALL.m 的目录。
执行：
    MAIN_CSASS_V2_ALL
默认即 run；也可执行 MAIN_CSASS_V2_ALL('run')。
需要 Parallel Computing Toolbox。程序启动 6 个本地进程 worker，每次试验使用 1 个计算线程；不使用 GPU。
若现有并行池忙，程序会提示等待，不取消别的任务。空闲但不符合要求的池才会重新建立。

三、固定的科学设置
只运行已冻结的 V2 自适应版本；N=100、MaxFE=500、Pmax=20、K=10，其他训练和选择设置不变。
CF 三目标任务仍由同一 V2 框架以 N=100 执行；这个包不运行其他五个对手算法。
主要 IGD 统一使用 GetOptimum 请求 10000 的冻结参考前沿，原目标尺度为 1。
请求 10000 不保证每个问题实际返回 10000 行，实际行数写在逐次结果中。
引擎自身保留冻结的 ReferencePoints=2000 设置，并另存 IGD2000；这不代替主要 IGD10000。
HV 使用固定前沿的最小值和范围归一化，默认统一输出参考点 1.1、3、20。
不根据接近原论文 IGD、优于对手或 HV 大小提前停止或增加试验。
72 小时是单次会话保护上限，不是新增实验预算。达到后停止派发，已经开始的试验自然完成并保留。

四、查看进度和结果
输出：outputs/V2_AllBenchmarks/
    status.json                 会话进度、完成数、失败原因
    runs/<ID>/                  每次真实评价记录、最终解集、预测/选择日志及 diagnostic_result.mat
    tables/all_runs.csv         已完成逐次指标，标明 new 或 cached
    tables/group_summary.csv    72 组的滚动汇总
    tables/paper_IGD_comparison.csv  与原论文 IGD 的比较
    tables/results.xlsx         Excel 汇总
每完成 30 次新增任务更新轻量 CSV；每 300 次和结束时做完整审计、日志汇总与 Excel 输出。
开始阶段 Excel 可能尚未产生；CSV 显示当前进度。原始逐次数据始终单独保留。
Inf/未找到可行解与程序报错是不同情况；正常完成但无可行解的试验仍保留在固定 30 次统计中。

五、续跑和异常
再次运行同一个主命令会跳过已经有正确 completed.json 的任务。
普通试验失败后停止派发新任务，让手上已经启动的试验自然结束并保存，然后报告失败。
started/failure/incomplete 记录不会删除或自动重跑；存在这些记录时，后续启动会要求先核查。
不要删掉失败目录来掩盖记录，也不要同时开第二个主控制器。
Ctrl+C 只取消本次会话创建的 futures；中断任务记录保留。不直接结束 MATLAB.exe。

六、只做检查、汇总或重新计算 HV
    MAIN_CSASS_V2_ALL('plan')        只看固定任务清单和完成情况
    MAIN_CSASS_V2_ALL('preflight')   核验源文件哈希、缓存身份和参数
    MAIN_CSASS_V2_ALL('summarize')   从保存记录生成完整汇总，不运行优化
    MAIN_CSASS_V2_ALL('hv')          对保存解集按默认参考点重新计算 HV
    MAIN_CSASS_V2_ALL('hv',[1.1 1.5 2 3 20])
最后一条只用已保存解集做统一参考点敏感性分析；不会修改算法、重跑优化或覆盖原始结果表。
新的 HV 后处理结果保存在独立的带时间戳目录。第二参数只允许用于 hv 模式。
新增1950次均保存最终目标集、决策变量和全部500条真实评价记录，可独立重算HV。
旧缓存210次中，本包收录了120份最终目标集；CF2、LIRCMOP1、LIRCMOP3十维共90份原始目标集尚未回传。
这90次已有的IGD和三个默认HV值仍保留在主汇总中，不重跑、不丢弃。
自定义参考点的HV重算会将这些缺失解集明确标为不可重算，原已报告HV另列，不据此推算新值。
缺失清单见baseline/missing_solutions.csv，后续应从原实验电脑取回对应解集。

七、运行后回传
    MAIN_CSASS_V2_ALL('collect')
先核验并汇总，再把结果、完整保存的解集和日志、缓存来源、冻结源码、参考前沿及协议一起打包。
ZIP 保存在 returns/，文件名以 CSASS_V2_ALL_RESULTS_ 开头。
把这个 ZIP 发回即可；不要只发 tables 文件夹，否则无法独立核查每次最终解和模型选择日志。
打包不会包含 returns 自己，也不会包含无关实验目录；正在运行时请先等控制器完成或停止再打包。
