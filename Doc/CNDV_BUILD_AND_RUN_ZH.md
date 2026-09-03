# RegCM5 CNDV 安装与使用说明

本文给出 `feature/regcm5-cndv` 分支在 Linux 上的编译、安装、数据准备、前处理、
耦合运行、诊断和 restart 方法。实现内容及科学依据见
[CNDV 实现说明](CNDV_IMPLEMENTATION_ZH.md)。

## 1. 先理解两个关键事实

1. CNDV 是编译期功能。必须用 `--enable-clm45 --enable-cndv` 构建，并运行这次
   构建产生的程序；namelist 中不存在 `enable_cndv=.true.` 一类开关。
2. 当前安装后的 CNDV 程序使用 `CN` 后缀，例如 `regcmMPICN`。这只是现有
   `makeinc` 的命名结果；构建参数中实际同时包含 `-DCLM45 -DCN -DCNDV`。

本文命令均假定源码位于：

```text
/home/lwg/Desktop/update_regcm-cndv/RegCM-cndv
```

如果放在其他目录，只需替换示例路径。

## 2. 软件依赖

至少需要：

- C 和 Fortran 编译器；
- GNU Make；
- Autoconf、Automake 和 Libtool；
- MPI 编译器包装器及运行器；
- NetCDF-C 与 NetCDF-Fortran 开发文件；
- HDF5、zlib 及 NetCDF 所需的相关开发库；
- Git。

本机已经验证的组合为：

| 组件 | 已验证版本 |
| --- | --- |
| GCC / GFortran | 15.2 |
| GNU Make | 4.4 |
| Autoconf / Automake | 2.72 / 1.18 |
| OpenMPI | 5.0 |
| NetCDF-C / NetCDF-Fortran | 4.9 / 4.6 |
| HDF5 | 1.14，serial |

NetCDF 本身可以是 serial 构建；RegCM 主程序仍可使用 MPI。当前系统没有
parallel NetCDF/PnetCDF，因此不要增加 `--enable-parallel-nc` 或
`--enable-pnetcdf`。

### 2.1 本机 PATH 注意事项

本机 Anaconda 目录位于 `/usr/bin` 之前，其中的 `mpicc`、`mpifort` 和 HDF5
包装器指向不存在的 Conda 编译器。为避免误用，下面始终把系统路径和编译器写
全：

```text
PATH=/usr/bin:/bin
CC=/usr/bin/gcc
FC=/usr/bin/gfortran
MPICC=/usr/bin/mpicc
MPIFC=/usr/bin/mpifort
```

其他机器可以替换为经过验证的 Intel、GNU 或集群编译器模块，但不要在同一次
构建中混用不同编译器族生成的 `.mod` 和目标文件。

## 3. 获取分支

已有本地仓库时：

```bash
cd /home/lwg/Desktop/update_regcm-cndv/RegCM-cndv
git switch feature/regcm5-cndv
```

检查：

```bash
git branch --show-current
git status --short
```

本次实现已提交在本地功能分支。正常检出该提交后，`git status` 应为空；若继续
修改代码，正式实验前应再次提交，并记录完整提交哈希。

## 4. 配置、编译和安装

### 4.1 生成配置系统

Git checkout 通常需要先生成 `configure` 和各级 `Makefile.in`：

```bash
cd /home/lwg/Desktop/update_regcm-cndv/RegCM-cndv
./bootstrap.sh
```

当 `configure.ac` 或 `Makefile.am` 改变后，也应重新执行这一步。

### 4.2 配置 CNDV

```bash
cd /home/lwg/Desktop/update_regcm-cndv/RegCM-cndv
env PATH=/usr/bin:/bin \
  CC=/usr/bin/gcc \
  FC=/usr/bin/gfortran \
  MPICC=/usr/bin/mpicc \
  MPIFC=/usr/bin/mpifort \
  ./configure \
    --enable-clm45 \
    --enable-cndv \
    --with-netcdf=/usr \
    --prefix="$PWD/install-cndv"
```

约束：

- 必须使用 `--enable-clm45`，不是旧版 CLM3.5 的 `--enable-clm`；
- `--enable-cndv` 会自动加入 `-DCN -DCNDV`；
- 不要手工编辑生成的 `Main/clmlib/clm4.5/Makefile`；
- 不要加入旧版使用的 `-DMAXPATCH_PFT=17`；当前 CLM4.5 已按
  `numpft+1` 确定自然植被 patch 数；
- 不要另外定义 `DYNPFT`，它与 CNDV 不兼容。

如果 NetCDF 安装在其他前缀，应把 `/usr` 改为实际前缀，并确保 NetCDF-C 与
NetCDF-Fortran 使用兼容的编译器和 ABI。

### 4.3 编译并安装

```bash
make version
make -j4
make install
```

`-j4` 可按可用内存和 CPU 调整。切换编译器或宏后若看到旧 `.mod` 导致的接口
错误，先执行：

```bash
make clean
```

然后重新运行配置、编译和安装。旧 RegCM4.3.4 中“主目录失败后进入 radlib
继续 make”的绕行方法不适用于这里；当前依赖已经在构建系统中处理。

### 4.4 检查构建是否确实启用了 CNDV

```bash
./configure --help | grep enable-cndv
grep '^AM_CPPFLAGS' Main/clmlib/clm4.5/Makefile
find install-cndv/bin -maxdepth 1 -type f -printf '%f\n' | sort
ldd install-cndv/bin/regcmMPICN
```

`AM_CPPFLAGS` 应含 `-DCLM45`、`-DCN` 和 `-DCNDV`；`ldd` 不应出现
`not found`。

还可做不进入真实积分的启动检查：

```bash
/usr/bin/mpirun -np 1 ./install-cndv/bin/regcmMPICN
```

程序能够初始化、打印版本/用法并因缺少 namelist 正常退出，即说明可执行文件和
基本动态库链路可用。这不是数值模拟测试。

## 5. 安装后的程序名

当前安装前缀中的主要 CNDV 程序为：

| 程序 | 用途 |
| --- | --- |
| `terrainCN` | 生成区域网格和地表基础文件 |
| `mksurfdataCN` | 生成 CLM4.5 区域 surface 数据 |
| `sstCN` | 生成 SST 边界数据 |
| `icbcCN` | 生成大气初始和侧边界数据 |
| `regcmMPICN` | 正常的大气—CLM4.5—CN—DV 耦合模式 |
| `interpinicCN` | 在网格/地表权重变化时插值已有 CLM 初始或 restart 状态 |
| `clmbcCN` | 为独立 CLM 模式准备逐小时 ERA5 地表强迫 |
| `clmsaMPICN` | 不运行 RegCM 大气的独立 CLM 模式 |

旧手册中可能出现 `*CLM45` 名称；本分支应以 `install-cndv/bin` 中的实际文件名
为准。源码树中尚未安装的程序可能仍使用无后缀名称，例如 `Main/regcm`。

## 6. 准备输入数据

RegCM 全局数据根目录应至少具有类似布局：

```text
REGCM_DATA/
├── SURFACE/
├── CLM45/
│   ├── megan/
│   ├── pftdata/
│   │   └── pft-physiology.c130503.nc
│   ├── snicardata/
│   │   ├── snicar_optics_5bnd_c090915.nc
│   │   └── snicar_drdt_bst_fit_60_c070416.nc
│   └── surface/
├── ERA5/                 # 或 dattyp 所指定的其他大气资料
└── CMIP6/                # 视实验配置需要
```

其中：

- `terrainCN` 从 `inpter/SURFACE` 一类目录读取高程、土地利用和土壤数据；
- `mksurfdataCN` 从 `inpglob/CLM45/surface` 读取 CLM4.5 全球地表数据；
- 模型会在 `inpglob/CLM45/pftdata` 和 `inpglob/CLM45/snicardata` 下寻找
  `fpftcon`、`fsnowoptics` 和 `fsnowaging`；
- 大气和 SST 数据目录由 `dattyp`、`ssttyp` 与所选数据集共同决定。

仓库原始数据说明见 [ObtainData.tex](UserGuide/ObtainData.tex)。数据下载地址和
文件版本可能变化，正式实验应记录实际文件清单、校验和及数据来源。

## 7. 建立运行目录和 namelist

建议把源码、全局输入、区域中间文件和结果分开：

```bash
export REGCM_SRC=/home/lwg/Desktop/update_regcm-cndv/RegCM-cndv
export REGCM_PREFIX="$REGCM_SRC/install-cndv"
export REGCM_DATA=/path/to/RegCM_Data
export REGCM_RUN=/path/to/run-cndv

mkdir -p "$REGCM_RUN/input" "$REGCM_RUN/output"
cp "$REGCM_SRC/Testing/test_001.in" "$REGCM_RUN/regcm-cndv.in"
cd "$REGCM_RUN"
```

编辑 `regcm-cndv.in`。除区域、日期和物理方案外，CNDV 至少要注意下面各项。

### 7.1 路径、网格和日期

```fortran
&dimparam
  iy  = 34,
  jx  = 64,
  kz  = 18,
  nsg = 1,
/

&terrainparam
  domname = 'test_001',
  dirter  = 'input/',
  inpter  = '/path/to/RegCM_Data',
/

&globdatparam
  dattyp  = 'ERA5 ',
  ssttyp  = 'ERA5D',
  gdate1  = 1990060100,
  gdate2  = 1990070100,
  dirglob = 'input/',
  inpglob = '/path/to/RegCM_Data',
/

&restartparam
  ifrest = .false.,
  mdate0 = 1990060100,
  mdate1 = 1990060100,
  mdate2 = 1990060600,
/

&outparam
  ifsave = .true.,
  savfrq = 0.,
  dirout = 'output/',
/
```

说明：

- CLM4.5 不应使用 RegCM subgrid，保持 `nsg=1`；
- `dirter` 是 `terrainCN` 输出位置；
- `dirglob` 同时保存 SST、ICBC 和生成的 CLM4.5 区域 surface 文件；
- 使用同一个 `input/` 可减少路径错配；
- `inpter` 和 `inpglob` 可以指向同一个全局数据根；
- 日期和 `dattyp/ssttyp` 必须与实际下载的数据一致。

### 7.2 CNDV 必需和建议的 CLM namelist

```fortran
&clm_inparm
  fpftcon = 'pft-physiology.c130503.nc',
  fsnowoptics = 'snicar_optics_5bnd_c090915.nc',
  fsnowaging = 'snicar_drdt_bst_fit_60_c070416.nc',

  create_crop_landunit = .false.,

  hist_nhtfrq = 0,
  hist_fincl1 = 'DROUGHT_DAYS:I', 'DROUGHT_DAYS20:I',
/

&clm_soilhydrology_inparm
  h2osfcflag = 1,
  origflag = 0,
/

&clm_hydrology1_inparm
  oldfflag = 0,
/

&clm_regcm
  enable_more_crop_pft = .false.,
  enable_dv_baresoil = .false.,
/
```

最重要的是：

- `create_crop_landunit` 的代码默认值是 `.true.`，CNDV 模式必须显式设成
  `.false.`，否则程序会主动终止；
- `enable_dv_baresoil` 不是 CNDV 开关。`.false.` 表示冷启动时使用 surface
  文件的初始植被权重；`.true.` 会把植被重置为裸地，通常需要更长的 spin-up；
- `DROUGHT_DAYS` 和 `DROUGHT_DAYS20` 默认不输出，上面的 `hist_fincl1`
  才会把它们加入第一条 CLM history tape；
- `hist_nhtfrq=0` 表示月输出。负值按小时解释，例如 `-24` 为日输出、`-1`
  为小时输出；高频输出会显著增加文件量。

默认 `hist_dov2xy=.true.`，column 状态会被映射/平均到二维网格。若研究需要保留
column 维度，可改为：

```fortran
&clm_inparm
  create_crop_landunit = .false.,
  hist_dov2xy = .false.,
  hist_type1d_pertape = 'COLS',
  hist_nhtfrq = 0,
  hist_fincl1 = 'DROUGHT_DAYS:I', 'DROUGHT_DAYS20:I',
  ! 这里仍需保留 fpftcon、fsnowoptics、fsnowaging
/
```

二维 history 与 column history 的文件维度不同，批处理脚本应相应调整。

## 8. 标准耦合前处理和运行

在运行目录中按顺序执行：

```bash
"$REGCM_PREFIX/bin/terrainCN" regcm-cndv.in
"$REGCM_PREFIX/bin/mksurfdataCN" regcm-cndv.in
"$REGCM_PREFIX/bin/sstCN" regcm-cndv.in
"$REGCM_PREFIX/bin/icbcCN" regcm-cndv.in
/usr/bin/mpirun -np 4 "$REGCM_PREFIX/bin/regcmMPICN" regcm-cndv.in
```

前四步通常只需单进程。预期的关键区域文件包括：

```text
input/test_001_DOMAIN000.nc
input/test_001_LANDUSE
input/test_001_CLM45_surface.nc
input/test_001_SST.nc
input/test_001_ICBC.<date>.nc
```

MPI 进程数必须适合区域分解；可通过 RegCM 的 `njxcpus/niycpus` 设置明确分解。
先用较小进程数做短测试，再提交长时间积分。

### 8.1 哪些程序不是标准耦合流程的一部分

- `interpinicCN` 只在已有 CLM 初始/restart 文件需要匹配新的 surface 权重或网格
  时使用。其调用形式是：

  ```bash
  "$REGCM_PREFIX/bin/interpinicCN" old.r.nc new.r.nc
  ```

  两个 NetCDF 文件都必须已经存在；普通冷启动不需要它。

- `clmbcCN` 和 `clmsaMPICN` 用于只运行 CLM 的独立陆面流程。`clmbcCN` 从逐
  小时 ERA5 场生成 `*_SFBC.*.nc`，随后由 `clmsaMPICN` 读取。正常
  `regcmMPICN` 耦合模拟不运行 `clmbcCN`。

## 9. 如何确认 CNDV 正在工作

CNDV 没有运行时开关，因此确认应从构建、日志和输出三方面进行。

### 9.1 构建检查

- 配置参数含 `--enable-clm45 --enable-cndv`；
- `Main/clmlib/clm4.5/Makefile` 的预处理宏含 `CLM45/CN/CNDV`；
- 实际运行的是同一安装前缀中的 `regcmMPICN`。

### 9.2 日志检查

冷启动时应看到 CNDV 初始 FPC 输出相关消息。跨过日历年末时应看到类似：

```text
End of year. CNDV called now
Annual CNDV calculations are complete
```

如果试验没有跨越年末，逐时间步 CN/物候仍会运行，但建立、竞争、死亡及本次
新增的长期干旱量更新不会执行。

### 9.3 NetCDF 检查

```bash
ncdump -h output/*.clm.*.h0.*.nc | grep DROUGHT
ncdump -h output/*.clm.*.r.*.nc | grep drought_days
ncdump -h output/*.clm.*.hv.*.nc | grep -E 'FPCGRID|NIND'
```

典型输出包括：

- 常规 RegCM `ATM/SRF/RAD/SAV` 文件；
- CLM history：`<case>.clm.<instance>.h0.<date>.nc`；
- CLM restart：`<case>.clm.<instance>.r.<date>.nc`；
- CNDV 年度文件：`<case>.clm.<instance>.hv.<year>.nc`，包含 `FPCGRID`、
  `NIND` 等动态植被状态。

`DROUGHT_DAYS20` 在首次日历年末更新前可能为内部未初始化标志值；跨年后应按
实现说明中的递推公式更新。只有从 1 月 1 日起算时，首次样本才是完整年度值。

## 10. Restart 和分段长积分

### 10.1 首段运行

```fortran
&restartparam
  ifrest = .false.,
  mdate0 = 1990010100,
  mdate1 = 1990010100,
  mdate2 = 1991010100,
/

&outparam
  ifsave = .true.,
  savfrq = 0.,
  dirout = 'output/',
/
```

### 10.2 接续运行

接续时保持最初的 `mdate0`，把 `mdate1` 设为上一段的 `mdate2`，再指定新的
`mdate2`：

```fortran
&restartparam
  ifrest = .true.,
  mdate0 = 1990010100,
  mdate1 = 1991010100,
  mdate2 = 1992010100,
/
```

必须把同一日期的以下文件作为一个 restart 集合保留：

- RegCM SAV；
- CLM restart；
- 模型要求的 CLM history-restart/关联文件。

只保存 RegCM SAV、丢失 CLM restart，会破坏 CN 碳氮库、植被状态和本次新增的
`drought_days/drought_days20` 连续性。

新代码可读取缺少两个干旱变量的旧 CLM restart，但会警告并使用 0/-1 重新开始
统计。若旧文件日期不是 1 月 1 日，第一个“年度值”并不覆盖完整日历年；不要把
这种过渡结果直接用于正式分析。

### 10.3 Restart 一致性测试

正式长积分前，建议比较：

1. 一次连续运行跨过某一日期；
2. 在该日期保存后停止，再从 restart 接续；
3. 比较后续 `DROUGHT_DAYS`、`DROUGHT_DAYS20`、FPC、LAI、碳氮库及能量水量
   守恒。

允许浮点并行归约造成极小差异，但不应出现状态重置、整年偏差或 PFT 突变。

## 11. Spin-up 与正式科学试验

CNDV 会同时演化碳氮库、LAI、个体密度和 PFT 覆盖，不能把“程序能启动”当成
“生态系统已平衡”。

- `spinup_state=1` 是现有 CN 的 accelerated decomposition soil-C spin-up
  选项，不代表已经自动完成一套适合本研究的完整 CNDV spin-up；
- `enable_dv_baresoil=.true.` 从裸地开始，通常收敛更慢；
- 当前 `drought_days20` 不会等待 20 个完整年度才生效；首年值就可触发 45 天
  规则；
- 需要自行设计 forcing 循环、加速阶段、正常阶段、收敛判据和 restart 链；
- 每个阶段都应记录提交、编译选项、namelist、输入数据和初始文件。

建议至少监控植被碳、土壤碳氮、NPP/GPP、LAI、FPC、NIND、水量和能量守恒，
以及两个新增干旱变量。具体 spin-up 长度必须由区域、分辨率、forcing 和收敛
目标决定，本文不规定一个未经验证的固定年数。

## 12. 常见问题

### `--enable-cndv requires --enable-clm45`

配置遗漏了 CLM4.5。重新使用：

```text
--enable-clm45 --enable-cndv
```

### 启动后报 `create_crop_landunit = T`

在 `&clm_inparm` 中显式加入：

```fortran
create_crop_landunit = .false.,
```

模板未写该项并不代表其默认值适合 CNDV。

### 找不到 `mpifort` 或出现 `x86_64-conda-linux-gnu-*` 错误

误用了 Conda 包装器。使用本文给出的 `PATH=/usr/bin:/bin` 和显式
`/usr/bin/mpifort`，然后干净重编译。

### Fortran 报 `.mod` 版本或过程接口不一致

通常是切换编译器、宏或分支后留下旧目标文件。执行 `make clean`，重新
`configure`，再完整构建。

### 找不到 `*_CLM45_surface.nc`

确认已经在 `terrainCN` 之后运行 `mksurfdataCN`，并检查：

- `dirglob` 是否是生成文件所在目录；
- 文件名中的 `domname` 是否一致；
- `inpglob/CLM45/surface` 数据是否完整。

### history 中没有干旱变量

两个字段默认 inactive。检查 `&clm_inparm` 中是否有：

```fortran
hist_fincl1 = 'DROUGHT_DAYS:I', 'DROUGHT_DAYS20:I',
```

并确认查看的是 CLM `.h0.` 文件而不是 RegCM `SRF` 文件。

### 没有看到年度植被变化

年度 DV 更新只在日历年末执行。确认运行时段跨过 12 月 31 日，并查看 `.hv.`
文件和日志中的年度 CNDV 消息。

### 多进程在 Codex 沙箱中报 UCX/OPAL 网络接口错误

当前沙箱禁止网络接口枚举。单进程启动可检查链接；真正多 rank 模拟应在正常
宿主环境、作业调度节点或容器的合适 MPI 配置下运行。

## 13. 最小验收清单

开始正式计算前，逐项确认：

- [ ] 当前分支和完整提交哈希已记录；
- [ ] 配置含 `--enable-clm45 --enable-cndv`；
- [ ] 编译宏含 `CLM45/CN/CNDV`；
- [ ] `ldd regcmMPICN` 无缺失库；
- [ ] `create_crop_landunit=.false.`；
- [ ] `nsg=1`；
- [ ] CLM45 `pftdata/snicardata/surface` 文件完整；
- [ ] 四个标准前处理程序按顺序成功；
- [ ] 短耦合模拟成功，并检查能量/水量和 NaN；
- [ ] 运行跨年，年度 CNDV 更新发生；
- [ ] history 中能看到所需干旱诊断；
- [ ] restart 文件包含 `drought_days` 和 `drought_days20`；
- [ ] 连续/分段 restart 对比通过；
- [ ] spin-up 和科学验证方案已单独记录。

完成这些工程检查后，才适合进入多年 spin-up、敏感性试验和论文结果复现。
