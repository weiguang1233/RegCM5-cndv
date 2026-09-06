#!/bin/bash
#SBATCH -J c5yr91_pre
#SBATCH -p debug
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 01:30:00
#SBATCH -o logs/preprocess.%j.out
#SBATCH -e logs/preprocess.%j.err

set -euo pipefail
export LANG=C
export LC_ALL=C
export OMP_NUM_THREADS=1
ulimit -s unlimited

module purge
module load compiler/intel/2021.3.0
module load mpi/intelmpi/2021.3.0
module load mathlib/hdf5/intel/1.8.20
module load mathlib/netcdf/intel/4.4.1
module load mathlib/zlib/intel/1.2.11
hash -r

run=/public/home/elpt_2024_000795/workdir_for_RCM/cndv_year2_regcm5_1991
bin=/public/home/elpt_2024_000795/packages/RegCM/RegCM5-cndv/install/bin
cd "$run"

# The grid and CLM surface are byte-for-byte copies of the accepted first year.
test -s input/c5yr1990_DOMAIN000.nc
test -s input/c5yr1990_CLM45_surface.nc
test -s output/c5yr1990_SAV.1991010100.nc
test -s output/c5yr1990.clm.regcm.r.1991010100.nc
test -s output/c5yr1990.clm.regcm.rh0.1991010100.nc

"$bin/sstCN_CNDV_CLM45" cndv_year2.in
"$bin/icbcCN_CNDV_CLM45" cndv_year2.in

test -s input/c5yr1990_SST.nc
test -s input/c5yr1990_ICBC.1991010100.nc
count=0
for file in input/*.nc; do
  test -s "$file"
  ncdump -h "$file" >/dev/null
  count=$((count + 1))
done
printf 'PREPROCESS_NETCDF_OK=%d\n' "$count"
printf 'PREPROCESS_YEAR2_OK\n'
