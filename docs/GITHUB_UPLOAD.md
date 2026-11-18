CSASS GitHub上传包（2026-11-18）

一、repository目录：代码、最终解集、逐次指标、可行次数、图表数据、核验脚本及中英文运行说明。
把repository目录里面的内容作为GitHub仓库根目录上传/提交，不是只上传一个ZIP。
文件数较多，建议用Git客户端提交；普通网页上传单文件有25MiB限制。

二、release_assets目录：6个CSASS_logs_*.zip及RELEASE_ASSETS_SHA256.csv。
在同一仓库创建固定版本Release（例如v1.0.0），把这些文件作为附件上传。
所有日志包均小于GitHub单Release附件2GiB限制；不要将外层总ZIP作为单个Release附件。

三、运行说明：repository/README.md。
MAIN_CSASS_PUBLIC默认只显示帮助；不需要重跑即可用Python核验论文表格和指标。

四、可行次数已经包含：data/Feasibility和data/Supplementary。审稿人还要求在论文或补充表中呈现，不能仅用仓库链接代替补充表。

五、立柱案例的原始运行、工程IGD参考集及选中设计来源仍未完整恢复；本包明确该范围，没有虚称已复现工程表13-15。

当前没有向GitHub上传任何文件。发布后在论文和回复中使用固定版本Release链接。
官方说明：https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
