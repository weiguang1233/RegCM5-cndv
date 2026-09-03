# RegCM5 CNDV 实现说明：改动、依据与边界

本文说明 `feature/regcm5-cndv` 分支相对基线提交
`ae3fc8b6484b` 的 CNDV 实现。它回答三个问题：具体改了什么、每项改动的
依据是什么、哪些内容没有改。

配套的编译、数据准备、前处理、运行和重启步骤见
[CNDV 安装与使用说明](CNDV_BUILD_AND_RUN_ZH.md)。

## 1. 实现目标

本分支以 RegCM5 已有的 CLM4.5、碳氮循环（CN）和动态植被（CNDV）代码为
基础，完成以下工作：

1. 提供可重复使用的 `--enable-cndv` 配置入口，不再手工修改生成的
   Makefile；
2. 按 Wang et al. 的 RefinedCN 描述修改胁迫落叶型物候；
3. 按论文的 ModifiedDV 描述加入干旱季长度及热带常绿阔叶树生存限制；
4. 让新增状态能够初始化、并行分解、输出和 restart；
5. 修复启用现有 CNDV 路径后暴露的少量编译、依赖和 FPC 计算问题。

这里的“完成”是指代码已经能够在本机 GNU/MPI/NetCDF 环境中干净编译、
链接和安装。它不等同于已经复现论文数值试验或完成科学验证。

## 2. 依据及其使用方式

### 2.1 主要科学依据

主要依据是：

> G. Wang et al., *On the development of a coupled regional
> climate–vegetation model RCM–CLM–CN–DV and its validation in Tropical
> Africa*, Climate Dynamics 46, 515–539 (2016), online publication 2015,
> DOI: [10.1007/s00382-015-2596-z](https://doi.org/10.1007/s00382-015-2596-z)。

[Springer 论文页面](https://link.springer.com/article/10.1007/s00382-015-2596-z)
说明该模型改进包含三部分：CLM4.5 的 GPP 参数化、RefinedCN 胁迫落叶物候，
以及 ModifiedDV 的热带常绿阔叶树干旱生存规则。本次直接新增的科学逻辑对应
论文第 2.3.2 和 2.3.3 节；GPP 部分的处理见第 7.1 节。

### 2.2 其他依据

| 依据 | 在本次工作中的用途 |
| --- | --- |
| 当前 RegCM5/CLM4.5 源码 | 决定状态所属层级、年度 CNDV 调用时机、restart/history 接口和 PFT 命名常量 |
| 用户提供的 RegCM4.3.4 可工作源码与补丁包 | 用作迁移参考和缺陷交叉检查，不作逐文件复制 |
| Fortran 量纲、数组归属和并行依赖 | 修复 seed FPC、shrub FPC、模块依赖和预处理后的编译错误 |
| 本地完整构建、安装和启动检查 | 验证工程链路，不用于宣称生态结果正确 |

旧版代码与论文存在若干差异和明显缺陷，因此“旧版能编译”不是逐行移植的
充分依据。第 6 节列出了本实现与旧版的关键差异。

## 3. 总体数据流

新增的 ModifiedDV 状态位于 CLM 的 column 层级，计算流程如下：

1. 每个陆面时间步，在活动的自然土壤列上检查最上方三层土壤水势；
2. 若三层中最湿层仍严格低于 `-2 MPa`，按当前陆面时间步折算成天数，累加到
   `drought_days`；
3. 日历年末进入既有 CNDV 年度更新，将当年值更新到
   `drought_days20`，随后把 `drought_days` 清零；
4. 建立/生存判断把每个 PFT 映射到所属 column；对热带常绿阔叶树，若长期量
   大于 45 天，则同时禁止其生存和建立；
5. 两个状态写入 CLM restart，并可按需写入 CLM history。

## 4. 具体改动

### 4.1 正式增加 CNDV 编译选项

修改文件：[configure.ac](../configure.ac)。

- 新增 `--enable-cndv`；
- 该选项只接受 `yes/no`；
- 启用时自动加入 `-DCN -DCNDV`；
- 未同时使用 `--enable-clm45` 时，配置阶段立即报错；
- CNDV 仍是编译期功能，没有新增运行时 namelist 开关。

这替代了 RegCM4.3.4 中在 `configure` 之后手工编辑 Makefile、追加宏的做法。
正式构建方式是：

```text
./configure --enable-clm45 --enable-cndv ...
```

不是旧 CLM3.5 使用的 `--enable-clm`。

### 4.2 RefinedCN：胁迫落叶型物候

修改文件：
[mod_clm_cnphenology.F90](../Main/clmlib/clm4.5/mod_clm_cnphenology.F90)，
例程 `CNStressDecidPhenology`。

| 项目 | 基线行为 | 当前行为 | 依据 |
| --- | --- | --- | --- |
| 展叶水势 | 固定取第 3 层 | 取最上方三层中的最干值 `minval` | 论文 §2.3.2 |
| 衰老水势 | 固定取第 3 层 | 取最上方三层中的最湿值 `maxval` | 论文 §2.3.2 |
| 水势阈值 | `-2 MPa` | 不变 | 论文 §2.3.2 |
| 连续胁迫/恢复触发期 | 15 天 | 不变 | 论文 §2.3.2 |
| 展叶完成期 | 30 天 | 不变 | 论文 §2.3.2 |
| 胁迫落叶完成期 | 15 天 | 30 天 | 论文 §2.3.2 |
| 季节性落叶完成期 | 15 天 | 15 天，不受本改动影响 | 限定论文改动范围 |

代码通过 `lbound`/`ubound` 取得合法数组边界，在当前 CLM4.5 网格上使用顶部
三层。这样避免把旧补丁中被注释掉的第三层误认为已生效。

“最干”和“最湿”的判断需要结合负水势理解：数值越负表示越干。因此：

- 只有最干层也达到或高于 `-2 MPa` 时，三层才都满足湿润展叶条件；
- 只有最湿层也达到或低于 `-2 MPa` 时，三层才都满足干旱落叶条件。

落叶期使用独立的 `ndays_off_stress=30`，季节性落叶仍使用原来的
`ndays_off=15`。这是文档审计后特意收紧的作用范围。

### 4.3 ModifiedDV：年度干旱时长

主要修改文件：

- [mod_clm_type.F90](../Main/clmlib/clm4.5/mod_clm_type.F90)：新增 column 状态；
- [mod_clm_typeinit.F90](../Main/clmlib/clm4.5/mod_clm_typeinit.F90)：分配并设置初值；
- [mod_clm_cndvecosystemdynini.F90](../Main/clmlib/clm4.5/mod_clm_cndvecosystemdynini.F90)：CNDV 冷启动初始化；
- [mod_clm_hydrology2.F90](../Main/clmlib/clm4.5/mod_clm_hydrology2.F90)：逐时间步累计；
- [mod_clm_cndv.F90](../Main/clmlib/clm4.5/mod_clm_cndv.F90)：年末更新长期量并清零；
- [mod_clm_driver.F90](../Main/clmlib/clm4.5/mod_clm_driver.F90)：向年度更新传递 column 边界。

对 column `c`，当下式成立时累计干旱时长：

```text
max(soilpsi(c, top 3 layers)) < -2 MPa
```

使用 `max` 是因为它代表三层中的最湿值；最湿层仍低于阈值等价于三层全部
低于阈值。比较使用严格小于号，对应论文的 “below -2 MPa”。每个时间步增加：

```text
drought_days += dtsrf / seconds_per_day
```

累计只应用于 `cactive` 且 landunit 类型为 `istsoil` 的 column，不把湖泊、冰川、
城市不透水面或 crop landunit 计入自然植被干旱统计。

年末长期量的当前实现为：

```text
首次年末样本： drought_days20 = drought_days
后续年末样本： drought_days20 =
              (19 * drought_days20 + drought_days) / 20
```

`drought_days20=-1` 是“尚无年末样本”的内部标志。只有从 1 月 1 日开始积分时，
首次年末样本才覆盖完整日历年。该设计避免根据模拟年份编号重置从 restart
恢复的有效长期状态。

需要特别说明：这与现有 `tmomin20`、`agdd20` 及旧版补丁采用相同的
`19/20 + 1/20` 递推平滑，但不是保存最近 20 个年度样本的严格有限滑动窗口。
变量名沿用模型中的 “20-year running mean” 术语，科学分析时必须保留这个实现
区别。

### 4.4 ModifiedDV：热带常绿阔叶树限制

修改文件：
[mod_clm_cndvestablishment.F90](../Main/clmlib/clm4.5/mod_clm_cndvestablishment.F90)。

- 通过 `pcolumn(p)` 获取每个 PFT 所属 column，避免旧代码使用未赋值列索引；
- 使用命名常量 `nbrdlf_evr_trp_tree`，不硬编码 PFT 编号；
- 当 `drought_days20 > 45 days` 时，同时设置：

```text
survive = false
estab   = false
```

严格大于 45 天对应论文 §2.3.3 的“长于 45 天”。该规则只作用于热带常绿阔叶树，
没有扩展到其他树、灌木或草本 PFT。它是论文采用的经验生存约束，不应解释为
所有地区和数据集均已验证的普适生态阈值。

### 4.5 初始化、restart 和诊断输出

修改文件：

- [mod_clm_cnrest.F90](../Main/clmlib/clm4.5/mod_clm_cnrest.F90)；
- [mod_clm_histflds.F90](../Main/clmlib/clm4.5/mod_clm_histflds.F90)；
- [mod_clm_cnsetvalue.F90](../Main/clmlib/clm4.5/mod_clm_cnsetvalue.F90)。

具体行为：

- `drought_days` 和 `drought_days20` 都写入并从 CLM restart 恢复；
- 旧 restart 不含这两个变量时不会直接终止，而是发出警告，将当前年累计设为
  0、长期值设为 -1；
- 新增可选 history 字段 `DROUGHT_DAYS` 和 `DROUGHT_DAYS20`，单位均为天；
- 两个 history 字段默认 `inactive`，不会无意增大输出，必须由用户显式请求；
- 特殊/非活动 column 的统一赋值流程已包含新字段，避免未定义值泄漏到输出。

从缺少新字段的旧 restart 在年中启动时，第一次年末样本只覆盖 restart 之后的
部分年份。正式试验应优先从年初启动该新统计，或重新进行一致的 spin-up。

### 4.6 启用 CNDV 后暴露的工程缺陷修复

以下改动是使现有 RegCM5 CNDV 路径可靠工作的工程修复，不是 Wang 论文提出的
新参数化。

#### Fortran 预处理顺序

[mod_clm_cndecompcascadebgc.F90](../Main/clmlib/clm4.5/mod_clm_cndecompcascadebgc.F90)
原先在启用 CN 后会把 `implicit none` 放在后续 `use` 语句之前，违反 Fortran
语句顺序。现在按预处理分支保留且只出现于合法位置。

#### 并行构建依赖

[Makefile.am](../Main/clmlib/clm4.5/Makefile.am) 为
`mod_clm_cndvecosystemdynini.o` 补充 `mod_clm_atmlnd.o` 依赖，避免 `make -j`
时在所需 `.mod` 文件生成之前编译使用者。

#### 新建立 PFT 的 seed FPC

[mod_clm_cndvestablishment.F90](../Main/clmlib/clm4.5/mod_clm_cndvestablishment.F90)
把判断修正为：

- 木本：`0.000844`；
- 非木本：`0.05`。

原分支把非木本默认值设为 `0.000844`，随后又在“是木本”时覆盖为 `0.05`，与
旧可工作实现及相邻注释的两类 seed FPC 语义相反。该修复不是 45 天干旱规则
的一部分。

#### shrub FPC 超限分配

[mod_clm_cndvlight.F90](../Main/clmlib/clm4.5/mod_clm_cndvlight.F90) 中，原公式
得到一个无量纲超限比例，却直接从某一 PFT 的 FPC 中扣除。当前公式先计算
gridcell 的 shrub FPC 超额，再按各 shrub PFT 的覆盖比例分摊：

```text
excess_p = (fpc_shrub_total - fpc_shrub_max)
           * fpc_p / fpc_shrub_total
```

这样 `excess_p` 与 FPC 量纲一致，且全部 shrub PFT 调整后的总量恰好回到允许
上限。

### 4.7 文档和本地安装目录

- [Doc/UserGuide/Install.tex](UserGuide/Install.tex) 增加 CNDV 配置入口和约束的
  简要说明；
- [.gitignore](../.gitignore) 忽略文档所用的仓库内安装前缀
  `install-cndv/`；
- 本文和 [CNDV 安装与使用说明](CNDV_BUILD_AND_RUN_ZH.md) 给出完整说明。

## 5. 与 RegCM4.3.4 参考实现的差异

本次没有整文件回拷旧版，原因如下：

| 旧版情况 | 当前处理 |
| --- | --- |
| 物候补丁的第三层代码被注释，实际只用顶部两层 | 明确使用顶部三层 |
| 某版本把 stress-deciduous 展叶完成期设为 60 天 | 按论文保留 30 天 |
| 用硬编码常数初始化长期干旱状态 | 用 -1 标志并由首次年末样本初始化 |
| establishment 片段使用未在对应循环赋值的 `c` | 通过 `pcolumn(p)` 显式映射 |
| 通过数字判断 `ivt==4` | 使用 `nbrdlf_evr_trp_tree` |
| 手工编辑 Makefile 加 `-DCN -DCNDV` | 使用正式 `--enable-cndv` 配置项 |
| 手工把 `MAXPATCH_PFT` 改成 17 | 不采用；CLM4.5 已由 `numpft+1` 推导 |

因此，当前实现意在落实论文描述并适配 RegCM5 数据结构，而不是与旧
RegCM4.3.4 结果做 bit-for-bit 复现。

## 6. 修改文件与职责

| 文件 | 职责 |
| --- | --- |
| `configure.ac` | CNDV 配置入口、依赖关系和宏 |
| `Main/clmlib/clm4.5/Makefile.am` | Fortran module 构建依赖 |
| `mod_clm_cnphenology.F90` | RefinedCN 顶部三层物候和 stress 落叶期 |
| `mod_clm_hydrology2.F90` | 逐时间步干旱时长累计 |
| `mod_clm_cndv.F90` | 年末长期量更新和清零 |
| `mod_clm_cndvestablishment.F90` | 45 天生存规则及 seed FPC 修复 |
| `mod_clm_cndvlight.F90` | shrub FPC 超限分摊修复 |
| `mod_clm_type.F90` | 新增 column 状态定义 |
| `mod_clm_typeinit.F90` | 新状态分配和基础初值 |
| `mod_clm_cndvecosystemdynini.F90` | CNDV 冷启动初值 |
| `mod_clm_driver.F90` | 年度 CNDV 调用的 column 边界 |
| `mod_clm_cnrest.F90` | 新状态 restart 读写和旧文件兼容 |
| `mod_clm_histflds.F90` | 可选 history 诊断字段 |
| `mod_clm_cnsetvalue.F90` | 特殊 column 的统一赋值 |
| `mod_clm_cndecompcascadebgc.F90` | CN 预处理后的 Fortran 语句顺序 |
| `Doc/UserGuide/Install.tex`、`.gitignore` | 简要安装说明和本地前缀隔离 |

表中的 `mod_clm_*.F90` 均位于 `Main/clmlib/clm4.5/`。

## 7. 明确没有修改的内容

### 7.1 没有重新移植 GPP/冠层模块

论文的第一项改进是把 CLM4.5 的冠层辐射、光合作用和气孔导度等改进用于当时
基于 CLM4 的 RegCM4.3.4。当前基线本身已经是 CLM4.5；本分支没有修改
`mod_clm_canopyfluxes` 等 GPP 代码，也没有从 4.3.4 旧包回拷整套 canopy
模块。因此准确表述是“直接使用 RegCM5 已有 CLM4.5 实现”，不是“本分支重新
实现了论文的 GPP 方案”。

### 7.2 没有改动这些模型部分

- RegCM 大气动力框架、辐射、积云、PBL、海洋和大气—陆面耦合接口；
- 常规 CN 的碳氮分配、分解、火灾、背景死亡和 gap mortality 科学公式；
- 植物水力学、根系适应、液流、水力死亡或物种演化机制；
- 地形、SST、ICBC 和 CLM4.5 surface 数据的插值算法；
- PFT 生理参数文件和任何区域校准参数；
- `-2 MPa` 水势阈值、15 天连续触发期、30 天展叶期和 45 天树种限制；
- 非目标 PFT 的建立与生存气候阈值。

### 7.3 没有启用或解除这些组合

- 不使用 CLM3.5 的 `--enable-clm`；
- 不手工设置 `MAXPATCH_PFT=17`；
- 不同时启用 `DYNPFT`；
- 不支持 `create_crop_landunit=.true.`；
- 没有额外开启 `CROP`、`LCH4`、`VERTSOILC` 或 `CENTURY_DECOMP`；
- 没有新增 namelist 形式的 CNDV 开/关。

### 7.4 没有实现严格 20 年队列

当前只保存递推长期量，没有保存 20 个逐年值的环形缓冲。因此不能把
`drought_days20` 描述为“最近 20 个完整年度的严格算术平均”。如未来科学设计
明确要求该定义，需要增加年度样本数组、restart 变量、有效样本数和迁移策略。

### 7.5 没有复现论文试验

本次没有运行论文的热带非洲多年试验，也没有完成 ERA-Interim、MODIS、GIMMS、
FLUXNET 等观测对比。因而目前不能宣称：

- 已复现论文图表或统计指标；
- 已消除所有 LAI 虚假波动；
- 已正确再现热带森林—稀树草原边界；
- 45 天经验阈值对其他区域同样适用；
- 长期碳氮库和动态植被已经达到平衡。

## 8. 已完成的工程验证

在本机内置 Linux 环境中已经完成：

- `./bootstrap.sh`；
- 使用系统 GCC/GFortran/OpenMPI 和 NetCDF 的 CNDV 配置；
- 干净的完整并行编译；
- `make install`；
- `make check`（该项目当前没有覆盖上述科学逻辑的实质性单元测试）；
- `ldd` 动态库缺失检查；
- 已安装 `regcmMPICN` 的 MPI 初始化和命令行启动检查；
- `--enable-cndv` 缺少 `--enable-clm45` 时的预期失败检查；
- RefinedCN 作用范围修正后的单文件重新编译。

本机沙箱禁止 OpenMPI/UCX 枚举网络接口，因此没有在沙箱内完成真实多进程区域
模拟。这一限制不表示 OpenMPI 安装损坏；正式多 rank 测试应在正常宿主机或计算
节点上进行。

## 9. 科学使用前仍需完成的验证

建议按以下顺序推进：

1. 用短域完成 `terrain → mksurfdata → sst → icbc → regcm` 端到端测试；
2. 跨年运行，确认 `DROUGHT_DAYS` 年内递增、年末归零，`DROUGHT_DAYS20`
   按公式更新；
3. 做同一日期的连续运行与 restart 分段运行对比；
4. 构造湿润、临界和干旱三类 column，验证严格 `< -2 MPa` 和 `>45 days`
   边界；
5. 检查只影响 `nbrdlf_evr_trp_tree`，季节性落叶 PFT 的 15 天过程保持不变；
6. 设计足够长的 CN/CNDV spin-up，并记录 forcing 循环、初始文件和收敛指标；
7. 最后再进行论文区域、时段和观测资料的复现实验。

特别注意：当前代码不会等待收集满 20 个年度样本。首次日历年末更新后，
`drought_days20` 就等于从本段起点累计到年末的值，45 天限制可能立即生效。
正式试验宜从 1 月 1 日开始该统计；稳定的长期植被分布仍依赖科学设计的
spin-up 和敏感性试验。

## 10. 可复现性记录

本文对应：

- 仓库：`weiguang1233/RegCM-cndv`；
- 本地分支：`feature/regcm5-cndv`；
- 基线提交：`ae3fc8b6484b`；
- 编译器验证：GNU Fortran/GCC 15.2、OpenMPI 5.0、NetCDF-C 4.9、
  NetCDF-Fortran 4.6；
- 文档日期：2026-09-04。

本次实现已在本地功能分支提交；任何科学试验仍应记录完整提交哈希、namelist、
输入数据版本、编译器版本和 restart 来源。
