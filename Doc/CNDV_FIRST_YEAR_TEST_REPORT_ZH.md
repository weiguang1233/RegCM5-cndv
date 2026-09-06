# RegCM5-CNDV 1990—1991 跨年测试报告

## 1. 文档目的与结论状态

本文记录 RegCM5-CNDV 全日历年测试的配置、作业链、并行策略、输出验收方法以及科学解释边界。测试目标是让模式从 1990-01-01 00:00 积分到 1991-01-01 00:00，跨过 CNDV 年度更新时刻，并比较更新前后的植被功能型（PFT）状态。

当前结论状态：**工程运行链路通过，首年 PFT 结果不具备物理可信度**。正式作业完整积分
8760 小时，CNDV 年度更新恰好执行一次，年度文件与最终 restart 的 FPC/NIND
完全一致；但第一次冷启动年度更新后植被目标覆盖几乎全部转为裸地，因此不能把
本次结果解释为可信的生态响应或论文复现。

关键可执行文件、年度 HV、SAV 与 CLM restart 的 SHA-256 均已采集；输出目录文件数
与容量也已归档。后续第二整年测试已经使用这些已校验的 1991-01-01 重启文件作为
唯一起点；结果见[两整年连续测试报告](CNDV_TWO_YEAR_TEST_REPORT_ZH.md)。

## 2. 软件、目录与数据来源

| 项目 | 记录 |
| --- | --- |
| 服务器登录别名 | `ssh huan` |
| 安装目录 | `/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv` |
| 测试可执行文件 | `/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv/install/bin/regcmMPICN_CNDV_CLM45` |
| 运行目录 | `/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990` |
| 输入目录 | `/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/input` |
| 输出目录 | `/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/output` |
| 分析目录 | `/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/analysis` |
| RegCM 输入资料根目录 | `/public/home/elpt_2024_000795/data/INPUT/RCMdata` |
| 本次运行日志目录 | `/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/logs` |
| 已记录的模式源码 revision | `1d8155c7c54ee775a6169f8ba8f581794c954ee8` |
| 可执行文件 SHA-256 | `fcece9e28f56700bad73a0e532c4e3a0c336430ef8d15d868d2c5e848be66e60` |
| 服务器二进制记录的源码提交 | `1d8155c7c54ee775a6169f8ba8f581794c954ee8` |
| 报告整理前的 GitHub 基线 | `6bb90a3c6ab2702c87bceb509925eb6d6b50fd6f`（相对二进制提交仅更新文档） |

## 3. 试验配置

主冷启动配置文件为 `cndv_crossyear.in`；若采用 1990-04-01 检查点续算，配置文件为 `cndv_crossyear_resume_19900401.in`。

### 3.1 区域和网格

| 参数 | 值 |
| --- | --- |
| 投影 | Lambert conformal（`LAMCON`） |
| 水平网格 | `iy=34`, `jx=64` |
| 垂直层数 | `kz=18` |
| 网格距 | `ds=60 km` |
| 区域中心 | `clat=45.39`, `clon=13.48` |
| 真纬度 | `30°`, `60°` |
| 域名 | `c5yr1990` |

### 3.2 强迫、时间与物理方案

| 参数 | 值 |
| --- | --- |
| 大气驱动 | `EIN15` |
| 海温 | `ERSST` |
| 日历 | `gregorian` |
| 前处理时段 | `gdate1=1990010100`, `gdate2=1991010200` |
| 冷启动积分时段 | `mdate1=1990010100` 至 `mdate2=1991010100` |
| 模式时间步长 | `dt=150 s` |
| 辐射时间步长 | `dtrad=30 min` |
| 地表交换时间步长 | `dtsrf=600 s` |
| 陆面模式 | CLM4.5 + CNDV |
| 对流方案 | 陆地/海洋均为 `icup=4` |
| 边界更新间隔 | `ibdyfrq=6 h` |

为限制一整年测试的输出量，关闭 ATM/RAD/SRF/STS/SUB 常规历史输出；保留模式保存文件，并在 CLM 月历史文件中仅输出 `DROUGHT_DAYS` 与 `DROUGHT_DAYS20`。`ifsts=.false.` 必须显式给出，因为 `ifsrf=.false.` 时不能启用 STS 输出。

### 3.3 检查点续算配置（仅在实际采用时填写）

续算配置保持原始 `mdate0=1990010100`，设置：

```text
ifrest = .true.
mdate1 = 1990040100
mdate2 = 1991010100
```

所需的三个 1990-04-01 检查点文件为：

```text
c5yr1990_SAV.1990040100.nc
c5yr1990.clm.regcm.r.1990040100.nc
c5yr1990.clm.regcm.rh0.1990040100.nc
```

是否实际采用续算：**否**。8 MPI 进程冷启动作业在切换前已经自然完成，因而没有
取消、续算或覆盖现有结果。32-rank 脚本只作为失败恢复预案保留。

## 4. 前处理记录

前处理作业号为 `39241707`，Slurm 结果为 `COMPLETED`、退出码 `0:0`。复核采用以下
命令，标准输出和错误日志保存在运行目录的 `logs/` 中：

- `sacct -j 39241707 -X -o JobID,JobName,Partition,AllocCPUS,State,ExitCode,Elapsed`
- 对 DOMAIN、CLM45 surface、SST 和全部 ICBC 文件执行 `ncdump -h`
- 核对 ICBC 从 `1990010100` 连续覆盖至跨年终点所需范围

前处理输出 NetCDF 文件总数：**16**；其中 ICBC 文件数：**13**；输入目录实际占用约
**946 MiB**。

前处理最终验收：**通过**。16 个 NetCDF 文件均已通过 `ncdump -h`；日志见
`logs/preprocess.39241707.out` 和 `.err`。

## 5. 作业链与已知纠错记录

| 作业号 | 用途 | 状态 |
| --- | --- | --- |
| `39241707` | 地形、海温和 ICBC 前处理 | 已记录为 `COMPLETED 0:0`；最终复核见第 4 节 |
| `39241787` | 首次运行参数检查 | 失败于终止时间不是 24 小时整倍数；未进入正式积分 |
| `39241812` | 第二次运行参数检查 | 失败于 `ifsrf=.false.` 但 STS 默认启用；未进入正式积分 |
| `39241823` | 1 节点、8 MPI 进程全日历年正式积分 | `COMPLETED`；模式内部耗时 3941.915 s；末端 1991-01-01 00:00 |
| `39241951` | 原始正式积分的依赖分析作业 | afterok 依赖执行成功，末行 `PFT_ANALYSIS_OK` |
| 未提交 | 1990-04-01 起 1 节点、32 MPI 进程续算 | 正式作业已完成，不再续算 |
| 未提交 | 续算完成后的 PFT 分析 | 不适用 |

参数检查失败的两个作业只用于暴露配置错误，不代表 CNDV 数值积分失败。本报告将
它们保留在审计链中；正式结果仅来自作业 `39241823`。

## 6. 并行策略

原始正式运行采用 `cpu_parallel` 队列、1 节点、8 个 MPI 进程、每进程 1 个 OpenMP 线程。加速续算脚本采用同一队列、1 节点、32 个 MPI 进程、每进程 1 个 OpenMP 线程。

本域只有 `64 × 34 = 2176` 个水平格点。直接使用 2 节点 × 64 进程（共 128 MPI 进程）时，平均每进程仅约 17 个水平格点，而且规则二维分解可能使单个子域过窄；通信、边界交换和 I/O 开销可能超过计算收益，甚至不满足模式的最小子域要求。因此，本测试将 32 MPI 进程作为较稳妥的加速点。若需验证 64 或 128 进程，必须单独做短时基准，比较初始化成功率、模拟日/墙钟小时和并行效率后再决定。

实际采用 **1 个节点、8 个 MPI 进程**，二维分解为 `4 × 2`。模式内部耗时
3941.915 s，即约 **10.80 墙钟秒/模拟日**，或 **333.34 模拟日/墙钟小时**。
因原作业已经完成，没有再提交 32/64/128-rank 作业，也就没有虚构并行加速比。

## 7. 正式运行验收

### 7.1 调度器和日志

最终正式运行作业号：`39241823`。

```bash
sacct -j 39241823 -X -o JobID,JobName,Partition,NNodes,AllocCPUS,State,ExitCode,Elapsed,MaxRSS
tail -n 80 /public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/logs/run.39241823.out
```

验收条件：

- Slurm 状态为 `COMPLETED` 且 `ExitCode=0:0`；
- 日志末尾包含 `MODEL_RUN_OK` 或 `MODEL_RESUME_OK`；
- 日志没有真实的 `FATAL`、NaN、MPI abort 或 NetCDF I/O 错误；
- 模式积分达到 `1991010100`，而不是只生成了中途月文件；
- 若为续算，明确保留了冷启动段与续算段各自的日志，并说明拼接点为 `1990040100`。

调度器验收结果：**通过**。依赖方式为 `afterok:39241823` 的分析作业已经运行并
完成，且正式日志末端有 `MODEL_RUN_OK`。

日志验收结果：**通过**。解析到 2920 个三小时时次，首末为
1990-01-01 03:00 和 1991-01-01 00:00，所有相邻时次严格相差 3 小时，没有缺口
或重复。`End of year. CNDV called now` 与
`Annual CNDV calculations are complete` 均恰好出现一次；未发现真实 NaN、FATAL、
MPI abort 或段错误。ETALAKE/LAKEFETCH 缺失时使用默认湖泊值，以及首时步跳过 CN
balance check，均为非致命告警。

### 7.2 最终输出文件

至少检查以下文件非空且 `ncdump -h` 成功：

```text
output/c5yr1990.clm.regcm.hv.1991.nc
output/c5yr1990.clm.regcm.hv.1992.nc
output/c5yr1990_SAV.1991010100.nc
output/c5yr1990.clm.regcm.r.1991010100.nc
output/c5yr1990.clm.regcm.rh0.1991010100.nc
```

全输出目录共有 **62** 个普通文件，占用约 **734 MiB**。末端关键文件 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `c5yr1990.clm.regcm.hv.1991.nc` | `054fc1624c0105fdca43cb4071ddb5dde0ffdc1609a65b297b79b6ca49e38f18` |
| `c5yr1990.clm.regcm.hv.1992.nc` | `fbcde33ea81447de30eaa3df7edae013ea32ad156f28eae71353a7157bc7ff9e` |
| `c5yr1990_SAV.1991010100.nc` | `18d84acc8de4e8c72e6c9fc0990b1bb4b1c6a48bce82369f13a5dfd784872309` |
| `c5yr1990.clm.regcm.r.1991010100.nc` | `074ef22ca7904bd6a3e3bbc5bdfc9cea045cf8c4500086926369c8eb4a8b1a01` |
| `c5yr1990.clm.regcm.rh0.1991010100.nc` | `8b22a7e394ccdfc8324c0a7e8dbd1fa23ef317879c930e3f0afa77fbd607f467` |

NetCDF 完整性验收：**核心分析输入通过**。两份 HV 与最终 CLM restart 均被 h5py
完整打开，最终 FPC/NIND 跨文件逐槽一致；模式日志同时明确成功写出 SAV、CLM
restart 与 history-restart。以上核心文件校验和已经归档。

> CNDV 年度历史文件的命名使用“下一年”标签：1990 年初始状态对应 `hv.1991.nc`，跨过 1991-01-01 年度更新后的状态对应 `hv.1992.nc`。必须依据文件内时间及代码语义确认，不能仅按文件名直觉解释。

## 8. PFT 分析与数值验收

分析脚本：

```text
/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990/analyze_pft_change.py
```

运行分析前，必须先确认初始与最终文件中的以下映射完全一致：

- `pfts1d_gridcell`
- `pfts1d_itypveg`
- `pfts1d_ityplun`

分析只把 `pfts1d_ityplun == 1` 的 soil landunit 纳入 PFT 空间统计。`FPCGRID` 的单位是百分比，`NIND` 的单位是 individuals m⁻²。PFT 0—16 用于覆盖度闭合检查，其中动态自然植被类型为 1—14；PFT 0、15、16 应保留在闭合和汇总表中，但不能都解释为动态自然植被。

### 8.1 必需分析产物

```text
analysis/pft_change_summary.txt
analysis/pft_change_by_type.csv
analysis/pft_top_changes.csv
analysis/dominant_pft_transitions.csv
analysis/pft_grid_mean_fpc_before_after.png
analysis/pft_total_abs_change_map.png
analysis/dominant_pft_before_after.png
```

分析作业号：`39241951`；日志末尾标记：`PFT_ANALYSIS_OK`。

分析产物完整性验收：**通过**，上述 7 个文件均非空。

### 8.2 关键数值结果（只填写脚本实际输出）

| 指标 | 实际结果 |
| --- | --- |
| 纳入统计的 soil grid 数 | 1311 |
| 初始 PFT 覆盖度闭合误差最大值 | `2.8422e-14` 个百分点 |
| 最终 PFT 覆盖度闭合误差最大值 | `4.2633e-14` 个百分点 |
| 发生非零变化的自然 PFT 槽位 | 7392 / 18354（40.27%） |
| 变化至少 0.01 pp 的自然 PFT 槽位 | 5575 / 18354（30.37%） |
| `max(abs(ΔFPCGRID))` | 99 个百分点 |
| 每格自然 PFT 绝对变化量之和的区域平均 | 61.0983 个百分点 |
| 主导自然 PFT 发生转移的格点数 | 679 / 1311（51.79%） |
| 区域均值降幅最大的自然 PFT | PFT 13，−23.7153 个百分点 |
| 变化最大的格点/PFT 组合 | PFT 9；gridcell 10 或 9；99% → 0% |
| 最终有效 `DROUGHT_DAYS` 范围 | 1311 个 active-soil column 均为 0 天（年度更新后已重置） |
| 最终有效 `DROUGHT_DAYS20` 范围 | 0—352.5694 天；均值 31.4762 天；中位数 15.3681 天；P95 142.0660 天 |
| `DROUGHT_DAYS20 > 45` 的 active-soil column | 240 / 1311（18.31%） |

覆盖度闭合验收标准：每个 soil grid 上 PFT 0—16 的 `FPCGRID` 之和应为 100%，允许误差不超过 `1e-6`。实际验收：**通过**。

最终重启文件还应交叉检查：

```text
100 * (fpcgrid - fpcgridold)
```

应与“最终 HV 的 `FPCGRID` − 初始 HV 的 `FPCGRID`”一致。旧分析器未限定 soil
槽位，得到的全数组最大差为 100 个百分点；该值受特殊 landunit/无效槽位污染，
不能据此判断 restart 错误。修正分析器并对 22,287 个有效 soil PFT 槽位复核后，
最终 HV 与 restart 的 FPC、NIND 最大差均为 **0**，且年度增量最大差也为 **0**。
因此跨文件一致性验收通过。未掩膜的 `1e20` 为非活动 column 的哨兵值，不参与
干旱统计。

### 8.3 PFT 变化摘要

按 PFT 类型填写分析脚本生成的结果，不手工估算：

| PFT 类型 | 初始区域平均 FPC | 最终区域平均 FPC | 变化 | 变化格点数 |
| --- | ---: | ---: | ---: | ---: |
| PFT 13 非北极 C3 草 | 23.8892% | 0.1739% | −23.7153 pp | 1305 |
| PFT 7 温带落叶阔叶树 | 15.5940% | 0.0804% | −15.5136 pp | 1286 |
| PFT 1 温带常绿针叶树 | 13.3702% | 0.0066% | −13.3636 pp | 1222 |
| PFT 2 寒带常绿针叶树 | 2.5967% | 0.0074% | −2.5893 pp | 678 |
| PFT 8 寒带落叶阔叶树 | 2.4750% | 0.0285% | −2.4465 pp | 675 |
| PFT 10 温带落叶阔叶灌木 | 1.5009% | 0.0074% | −1.4934 pp | 981 |

初始与最终主导自然 PFT 相同的格点为 632 个，发生变化的为 679 个。最大转移为
PFT 7 → PFT 13（160 格），其次为 13 → 7（123 格）和 1 → 13（110 格）。必须
注意，最终自然 PFT 总覆盖仅 0.4505%，这里的“主导”只是残余自然植被内部最大者，
不能单独理解成仍存在高覆盖植被。

## 9. 科学解释边界

本试验可以回答：程序能否完成一次跨年 CNDV 年度更新；年度更新前后 PFT 目标覆盖度是否发生数值变化；保存文件、HV 历史文件与重启状态是否相互一致。

本试验不能单独证明：

- CNDV 已达到植被—气候平衡。这里只有一个冷启动年份，没有多年 spin-up；
- 结果可直接用于气候学结论或复现参考论文。区域、分辨率、驱动资料、初值和积分长度都需要与论文实验设计逐项对齐；
- `pfts1d_wtxy` 在年度边界瞬间就等于新目标覆盖度。该实际耦合权重会在下一年内插更新；年度目标变化应优先看 `FPCGRID`；
- 本欧洲小区域可以验证所有 PFT 特定规则。初始场中 PFT 4（热带常绿阔叶树）是否存在及其有效样本数必须由输出确认；如果样本为零，就不能用本试验验证针对 PFT 4 的 45 日干旱淘汰规则；
- 非零差异自动等同于“科学正确”。仍需做守恒、范围、映射、重启一致性以及多年稳定性检查。

初始 PFT 4 的非零 FPC/NIND 样本数为 **0**。因此本欧洲域**不能**检验 PFT 4 的
45 日干旱淘汰规则；它只能检验一般年度 CNDV 更新链路。

## 10. 最终结论

正式积分作业 `39241823` 于 2026-09-06 完成，使用 1 个节点和 8 个 MPI 进程，
从 `1990010100` 冷启动积分至 `1991010100`。调度器依赖链、日志连续性和核心
NetCDF 分析输入验收均通过。CNDV 年度更新前后有 7392 个自然 PFT 槽位出现非零
覆盖变化，最大变化为 99 个百分点；最终 HV 与 restart 的 FPC/NIND 完全一致，
soil-only 的 `fpcgridold` 年度增量交叉检查也精确一致。

因此，本次工程验收结论为：**年度 CNDV 软件路径通过**。

科学解释应限定为：**已验证一次年度更新链路可执行，但首年更新后裸地由 5.4656%
升至 99.5495%、自然 PFT 由 61.5440% 降至 0.4505%，且 PFT 15 作物由 32.9904%
降至 0；该状态不是可信的平衡植被结果。必须先解决/解释冷启动碳库—覆盖不一致与
作物边界，再进行多年 spin-up、热带域试验及论文配置复现。**

## 11. 可复现命令清单

以下命令应在服务器运行目录执行，并将输出保存到最终验收附件：

```bash
cd /public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990

# 作业状态
sacct -j 39241823,39241951 -X -o JobID,JobName,Partition,NNodes,AllocCPUS,State,ExitCode,Elapsed,MaxRSS

# 最终关键文件结构
for f in \
  output/c5yr1990.clm.regcm.hv.1991.nc \
  output/c5yr1990.clm.regcm.hv.1992.nc \
  output/c5yr1990_SAV.1991010100.nc \
  output/c5yr1990.clm.regcm.r.1991010100.nc \
  output/c5yr1990.clm.regcm.rh0.1991010100.nc
do
  test -s "$f" && ncdump -h "$f" >/dev/null && sha256sum "$f"
done

# PFT 分析（最终重跑一次以固定产物）
/public/home/elpt_2024_000795/anaconda3/bin/python3 \
  analyze_pft_change.py \
  output/c5yr1990.clm.regcm.hv.1991.nc \
  output/c5yr1990.clm.regcm.hv.1992.nc \
  analysis \
  output/c5yr1990.clm.regcm.r.1991010100.nc
```

- 报告填写人：Codex 协作测试
- 验收日期：2026-09-06
- 关联 Git 提交：服务器二进制 `1d8155c7c54e`；报告整理前仓库基线
  `6bb90a3c6ab2`；本报告自身提交以 Git 历史为准
