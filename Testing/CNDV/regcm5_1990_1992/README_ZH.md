# RegCM5-CNDV 两整年连续性测试

本目录保存 1990 冷启动年与 1991 重启年的可复现配置和 PFT 分析程序。它是服务器
实测案例，不是通用默认配置；路径、网格、资料类型和 Slurm 资源必须按目标环境调整。

完整结果和解释见
[`Doc/CNDV_TWO_YEAR_TEST_REPORT_ZH.md`](../../../Doc/CNDV_TWO_YEAR_TEST_REPORT_ZH.md)。

## 文件

- `cndv_crossyear_1990.in`：1990-01-01 至 1991-01-01 冷启动年；
- `preprocess_1990.slurm`、`run_1990_8r.slurm`：首年前处理和 8 MPI 积分；
- `cndv_year2_1991.in`：从 1991-01-01 restart 连续积分到 1992-01-01；
- `preprocess_1991.slurm`、`run_1991_32r.slurm`：第二年前处理和 32 MPI 积分；
- `analyze_pft_change.py`：两份 HV 的成对比较及前后 restart 交叉验证；
- `analyze_three_year_states.py`：初始、第一年末、第二年末三状态比较；
- `analyze_1990_1992.slurm`：服务器分析作业。

## 关键约束

1. 第二年必须同时保留同一时刻的 RegCM `SAV`、CLM `r` 和 CLM `rh0`；不能只用
   一个 SAV 文件接续。
2. restart 运行必须保持原始 `mdate0=1990010100`，第二年设置
   `mdate1=1991010100`、`mdate2=1992010100`，这样年末 `kyr=2`。
3. CNDV 构建必须启用 `--enable-clm45 --enable-cndv`；namelist 中没有运行时
   CNDV 开关。
4. `create_crop_landunit=.false.` 是当前 CNDV 的硬性要求；历史字段配置在分段运行
   之间必须一致。
5. `FPCGRID` 是年度目标覆盖度。实际耦合 PFT 权重在下一年内插，不应以年末瞬时
   `pfts1d_wtxy` 代替目标变化。
6. HV 文件名存在一年偏移：内部日期 1990-01-01、1991-01-01、1992-01-01 分别
   写为 `hv.1991.nc`、`hv.1992.nc`、`hv.1993.nc`；分析必须读取 `mcdate`。

## 第二年作业链

在服务器的独立运行目录内执行：

```bash
pre=$(sbatch --parsable preprocess_1991.slurm)
run=$(sbatch --parsable --dependency=afterok:$pre run_1991_32r.slurm)
sbatch --dependency=afterok:$run analyze_1990_1992.slurm
```

本次实测作业号为 `39249854`、`39249855`、`39249856`；修正图表标签后的复算作业
为 `39250464` 和 `39250468`。所有正式作业均为 `COMPLETED 0:0`。

## 分析器直接调用

成对分析的最后两个参数依次是年末 restart 和年初 restart；同时提供两者才能用
模型的 `present` 标志精确统计建立和消亡：

```bash
python3 analyze_pft_change.py \
  FIRST_YEAR_END_HV SECOND_YEAR_END_HV OUTPUT_DIR \
  SECOND_YEAR_END_RESTART FIRST_YEAR_END_RESTART

python3 analyze_three_year_states.py \
  INITIAL_HV FIRST_YEAR_END_HV SECOND_YEAR_END_HV OUTPUT_DIR
```

验收时至少要求：映射完全一致、PFT 0—16 逐格闭合为 100%、HV 与 restart 的
FPC/NIND 一致、`drought_days` 年末归零、日志中年度 CNDV 调用恰好一次。
