# RegCM5 CNDV 安装与使用说明

本文给出 `feature/regcm5-cndv` 分支在 Linux 上的编译、安装、数据准备、前处理、
耦合运行、诊断和 restart 方法。实现内容及科学依据见
[CNDV 实现说明](CNDV_IMPLEMENTATION_ZH.md)。

## 1. 先理解两个关键事实

1. CNDV 是编译期功能。必须用 `--enable-clm45 --enable-cndv` 构建，并运行这次
   构建产生的程序；namelist 中不存在 `enable_cndv=.true.` 一类开关。
2. 程序后缀会受 Make/配置环境影响。本机 GNU Make 4.4 的已验证安装使用
   `CN`（如 `regcmMPICN`），`huan` 服务器 GNU Make 3.82 的本次安装使用
   `CN_CNDV_CLM45`（如 `regcmMPICN_CNDV_CLM45`）。两者编译参数都同时包含
   `-DCLM45 -DCN -DCNDV`。任何脚本都应先查看目标安装前缀的 `bin/`，以实际
   文件名为准，不能根据旧文档猜测。

本文命令中的 `/path/to/RegCM5-cndv` 表示克隆后的源码目录，例如：

```text
/home/user/RegCM5-cndv
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

首次获取独立仓库时：

```bash
git clone https://github.com/weiguang1233/RegCM5-cndv.git
cd RegCM5-cndv
git switch master
```

`master` 是已集成 CNDV 的默认分支。若要沿用开发分支名称，可以改为：

```bash
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
cd /path/to/RegCM5-cndv
./bootstrap.sh
```

当 `configure.ac` 或 `Makefile.am` 改变后，也应重新执行这一步。

### 4.2 配置 CNDV

```bash
cd /path/to/RegCM5-cndv
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

### 4.5 `huan` 集群上的原生构建

本次服务器部署没有上传本机可执行文件，而是先上传提交
`ef6e753e28e86b8b1a30209184b1c8b0662ec098` 对应的干净源码包，再加入服务器
测试发现并已提交为 `1d8155c7c` 的 Holtslag 两行修复，最后用服务器 Intel
编译器、Intel MPI 和服务器 NetCDF/HDF5 原生重编译。本机二进制依赖的
GNU/OpenMPI/glibc ABI 与 CentOS 7 集群不同，不能直接复用。

服务器目录约定为：

```text
/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv/
├── RegCM5-cndv-ef6e753e2.tar.gz   # 上传的可追溯源码包
├── source/                        # 构建源码树
├── install/                       # 安装前缀
└── logs/                          # bootstrap/configure/make/install 日志
```

登录后加载的模块栈为：

```bash
module purge
module load compiler/intel/2021.3.0
module load mpi/intelmpi/2021.3.0
module load mathlib/hdf5/intel/1.8.20
module load mathlib/netcdf/intel/4.4.1
module load mathlib/zlib/intel/1.2.11
hash -r
```

该组合使用 serial NetCDF 4.4.1；RegCM 主程序仍由 Intel MPI 并行。服务器现有
PnetCDF 是用另一代 Intel MPI（2017）构建的，与本次 Intel MPI 2021.3 ABI 不
一致，因此本次配置明确不使用 `--enable-pnetcdf` 或任何 parallel NetCDF
选项。除非重新用同一编译器/MPI 栈构建全部依赖，不要混用该 PnetCDF。

在服务器上验证成功的配置、编译和安装命令如下：

```bash
set -euo pipefail
export LANG=C
export LC_ALL=C

ROOT=/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv
cd "$ROOT/source"

# `git archive` 不含 .git；在这种源码包中显式记录用于构建的代码提交。
printf '%s\n' '1d8155c7c54ee775a6169f8ba8f581794c954ee8' > version

./bootstrap.sh 2>&1 | tee "$ROOT/logs/bootstrap.log"

CC=icc FC=ifort MPIFC=mpiifort \
  ./configure \
    --prefix="$ROOT/install" \
    --enable-clm45 \
    --enable-cndv \
    --with-netcdf=/public/software/mathlib/libs-intel/netcdf/4.4.1 \
    --with-hdf5=/public/software/mathlib/libs-intel/hdf5/1.8.20 \
  2>&1 | tee "$ROOT/logs/configure.log"

make version 2>&1 | tee "$ROOT/logs/make-version.log"
make -j4 2>&1 | tee "$ROOT/logs/make.log"
make install 2>&1 | tee "$ROOT/logs/install.log"
```

这里必须在 `source/` 中进行 **in-source build**。当前 RegCM5 生成的 Makefile
对 VPATH/out-of-tree 构建支持不完整，服务器实测会找不到 `build/makeinc`，修补
这一处后又会找不到 `external/mo_simple_plumes.f90`。这些失败日志已保留为
`logs/configure-vpath.log`、`logs/make-attempt1.log` 和
`logs/make-vpath-attempt2.log`；它们不是 CNDV 源码编译错误。

安装完成后不要假定程序后缀，先检查实际目录：

```bash
BIN="$ROOT/install/bin"
find "$BIN" -maxdepth 1 -type f -printf '%f\n' | sort
grep '^AM_CPPFLAGS' "$ROOT/source/Main/clmlib/clm4.5/Makefile"
ldd "$BIN/regcmMPICN_CNDV_CLM45" | grep 'not found' && exit 1 || true
```

本次安装确认前处理程序和主程序均使用完整后缀 `CN_CNDV_CLM45`，且编译命令
包含 `-DCLM45 -DCN -DCNDV`。上述路径是当前部署记录；以后更换提交、配置或
安装前缀时仍应重新查看 `bin/`，并同步修改作业脚本。

修复提交加入后，服务器把 `source/version` 更新为完整代码提交
`1d8155c7c54ee775a6169f8ba8f581794c954ee8`，增量 `make -j4` 和
`make install` 均返回 0。最终主程序启动横幅和二进制字符串都含该完整提交，
SHA256 为：

```text
fcece9e28f56700bad73a0e532c4e3a0c336430ef8d15d868d2c5e848be66e60
```

再次执行 `ldd` 仍无 `not found`。因此最终测试所用二进制的自报版本、源码修复
和安装文件相互一致。

## 5. 安装后的程序名

本机已验证安装中的主要 CNDV 程序如下；`huan` 服务器对应名称在右列：

| 本机 GNU Make 4.4 | `huan` 本次安装 | 用途 |
| --- | --- | --- |
| `terrainCN` | `terrainCN_CNDV_CLM45` | 生成区域网格和地表基础文件 |
| `mksurfdataCN` | `mksurfdataCN_CNDV_CLM45` | 生成 CLM4.5 区域 surface 数据 |
| `sstCN` | `sstCN_CNDV_CLM45` | 生成 SST 边界数据 |
| `icbcCN` | `icbcCN_CNDV_CLM45` | 生成大气初始和侧边界数据 |
| `regcmMPICN` | `regcmMPICN_CNDV_CLM45` | 大气—CLM4.5—CN—DV 耦合模式 |
| `interpinicCN` | `interpinicCN_CNDV_CLM45` | 插值已有 CLM 初始或 restart 状态 |
| `clmbcCN` | `clmbcCN_CNDV_CLM45` | 为独立 CLM 准备 ERA5 地表强迫 |
| `clmsaMPICN` | `clmsaMPICN_CNDV_CLM45` | 不运行 RegCM 大气的独立 CLM 模式 |

源码树中尚未安装的程序可能仍使用无后缀名称，例如 `Main/regcm`。若 `find`
结果与表中任一列不同，应以 `bin/` 实际文件为准，同时用编译宏检查确认功能。

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
export REGCM_SRC=/path/to/RegCM5-cndv
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

### 8.2 `huan` 集群独立 smoke 测试

服务器 smoke 测试使用独立目录，不修改已有的 `regcm5_run`：

```text
/public/home/elpt_2024_000795/workdir_for_RCM/cndv_smoke_regcm5_ef6e753e2/
├── cndv_smoke.in
├── preprocess.slurm
├── run.slurm
├── input/
├── output/
└── logs/
```

这样可把本次提交、输入和输出与既有试验隔离，也不会误用其他 RegCM 版本的
软链接或区域文件。测试配置为：

| 项目 | 值 |
| --- | --- |
| domain | `c5smoke`，LAMCON，中心 `45.39°N, 13.48°E` |
| 网格 | `iy=34, jx=64, kz=18, nsg=1`，水平分辨率 60 km |
| 大气/SST | `EIN15` / `ERSST` |
| 全局数据根 | `/public/home/elpt_2024_000795/data/INPUT/RCMdata` |
| 前处理时间窗 | 1990-06-01 00 至 1990-06-03 00 |
| 模式积分 | 1990-06-01 00 至 1990-06-02 00，共 24 小时 |
| 时间步 | 大气 `dt=150 s`，陆面 `dtsrf=600 s` |
| PBL | `ibltyp=1`，Holtslag |
| CLM history | `hist_nhtfrq=-24`，即每 24 小时一条 |

namelist 中必须保留：

```fortran
&clm_inparm
  fpftcon = 'pft-physiology.c130503.nc',
  fsnowoptics = 'snicar_optics_5bnd_c090915.nc',
  fsnowaging = 'snicar_drdt_bst_fit_60_c070416.nc',
  create_crop_landunit = .false.,
  hist_nhtfrq = -24,
  hist_fincl1 = 'DROUGHT_DAYS:I', 'DROUGHT_DAYS20:I',
/
```

`create_crop_landunit=.false.` 不是可选的性能设置；CNDV 会在启动时检查它，值为
`.true.` 时主动终止。`dtsrf=600 s` 时，一天是 144 个陆面步，和
`hist_nhtfrq=-24` 的日输出设置一致。

不要在登录节点直接运行多 rank 模式。加载第 4.5 节模块后，先提交单进程前
处理作业，再让四进程模式作业依赖前处理成功状态：

```bash
cd /public/home/elpt_2024_000795/workdir_for_RCM/cndv_smoke_regcm5_ef6e753e2
pre_job=$(sbatch --parsable preprocess.slurm)
run_job=$(sbatch --parsable --dependency=afterok:"$pre_job" run.slurm)
printf 'preprocess=%s model=%s\n' "$pre_job" "$run_job"
squeue -j "$pre_job,$run_job"
```

两个脚本均使用 `debug` 分区、单节点和 `OMP_NUM_THREADS=1`；前处理请求 1 个
task/30 分钟，模式请求 4 个 task/1 小时。核心命令为：

```bash
BIN=/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv/install/bin
NML=cndv_smoke.in

"$BIN/terrainCN_CNDV_CLM45" "$NML"
"$BIN/mksurfdataCN_CNDV_CLM45" "$NML"
"$BIN/sstCN_CNDV_CLM45" "$NML"
"$BIN/icbcCN_CNDV_CLM45" "$NML"
mpirun -n 4 "$BIN/regcmMPICN_CNDV_CLM45" "$NML"
```

前处理验收至少要求以下文件存在、非空且 `ncdump -h` 能正常读取：

```text
input/c5smoke_DOMAIN000.nc
input/c5smoke_LANDUSE
input/c5smoke_TEXTURE
input/c5smoke_CLM45_surface.nc
input/c5smoke_SST.nc
input/c5smoke_ICBC.1990060100.nc
```

模式积分预期产生 `ATM/RAD/SRF/STS`、终点 `SAV`、CLM restart/history-restart
以及 CNDV `hv` 文件。推荐按下面顺序验收，而不能只根据“文件已创建”判断成功：

```bash
sacct -X -j "$run_job" \
  --format=JobID,JobName,Partition,State,ExitCode,Elapsed
grep -E 'MODEL_RUN_OK|simulation successfully reached end' "logs/run.${run_job}.out"
! grep -aEi 'fatal|segmentation fault|forrtl: severe|mpi_abort|(^|[^[:alpha:]])nan([^[:alpha:]]|$)' \
  "logs/run.${run_job}.out" "logs/run.${run_job}.err"

for file in input/*.nc output/*.nc; do
  test -s "$file"
  ncdump -h "$file" >/dev/null
done

ncdump -h output/c5smoke.clm.regcm.hv.1991.nc | grep -E 'FPCGRID|NIND'
ncdump -h output/c5smoke.clm.regcm.r.1990060200.nc \
  | grep -E 'drought_days|drought_days20'
```

验收还应确认 Slurm 状态为 `COMPLETED`、退出码为 `0:0`，日志包含 CNDV 初始化/
history 消息，并且所有 MPI rank 均未异常退出。这个 24 小时测试不跨年，只验证
构建、前处理、耦合启动、持续积分和落盘链路；年度 CNDV 竞争、死亡、建立和
20 年递推量仍必须另做跨年及 restart 测试。

本次服务器前处理作业 `39201799` 状态为 `COMPLETED`、退出码 `0:0`，并生成了
上述区域输入。修复第 12 节所述 Holtslag 接口回归并刷新二进制版本标识后，
最终耦合作业 `39224268`
使用 4 个 MPI rank，在 26 秒墙钟时间内完成 24 小时积分，状态为 `COMPLETED`、
退出码 `0:0`。日志包含 `Writing initial CNDV FPCGRID`、
`RegCM V5 simulation successfully reached end`、`MODEL_RUN_OK`，并明确显示
`GIT Revision: 1d8155c7c54ee775a6169f8ba8f581794c954ee8`。

验收逐个读取了 8 个模式 NetCDF 输出：ATM、RAD、SRF、STS、终点 SAV、CLM
restart、CLM history-restart 和 CNDV `hv` 均通过 `ncdump -h`。其中 restart 含
`drought_days/drought_days20`，history-restart 含
`DROUGHT_DAYS/DROUGHT_DAYS20`，`hv` 含 `FPCGRID/NIND`；最终作业日志未检出
FATAL、段错误、MPI abort 或独立 NaN 标记。早期两个失败作业及其部分输出已按
作业号放在运行目录的 `attempts/` 下；版本标识刷新前已成功的 `39202048` 输出
也保存在 `attempts/run_39202048_pre_version_refresh/`，均与当前最终输出隔离。

## 9. 如何确认 CNDV 正在工作

CNDV 没有运行时开关，因此确认应从构建、日志和输出三方面进行。

### 9.1 构建检查

- 配置参数含 `--enable-clm45 --enable-cndv`；
- `Main/clmlib/clm4.5/Makefile` 的预处理宏含 `CLM45/CN/CNDV`；
- 实际运行的是同一安装前缀中由 `find` 核实过的 CNDV 主程序（本机示例为
  `regcmMPICN`，本次服务器安装为 `regcmMPICN_CNDV_CLM45`）。

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

### 默认 Holtslag 在首个 PBL 步段错误

若回溯落在 `mod_pbl_holtbl.F90` 原 674/676 行，并且使用默认
`idynamic=1, ibltyp=1`，应确认源码已经包含
`p2m%utend/p2m%vtend` 两个写入目标。RegCM5 上游 cross-point 重构曾遗漏这两
行，使 Holtslag 写入未分配的临时指针。本分支提交 `1d8155c7c` 已修复；详细
依据见实现说明第 4.6 节。不要只把 `ibltyp` 改成其他方案来掩盖问题，也不要把
这一工程修复解释为 CNDV 参数化改变。

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
- [ ] 对实际 CNDV 主程序执行 `ldd`，无缺失库；
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
