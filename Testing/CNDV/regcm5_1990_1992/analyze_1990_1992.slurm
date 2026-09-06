#!/bin/bash
#SBATCH -J c5yr91_pft
#SBATCH -p debug
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 00:15:00
#SBATCH -o logs/analyze.%j.out
#SBATCH -e logs/analyze.%j.err

set -euo pipefail
export LANG=C
export LC_ALL=C
export OMP_NUM_THREADS=1

first=/public/home/elpt_2024_000795/workdir_for_RCM/cndv_crossyear_regcm5_1990
run=/public/home/elpt_2024_000795/workdir_for_RCM/cndv_year2_regcm5_1991
python=/public/home/elpt_2024_000795/anaconda3/bin/python3

initial="$first/output/c5yr1990.clm.regcm.hv.1991.nc"
year1="$first/output/c5yr1990.clm.regcm.hv.1992.nc"
year2="$run/output/c5yr1990.clm.regcm.hv.1993.nc"
restart="$run/output/c5yr1990.clm.regcm.r.1992010100.nc"
year1_restart="$first/output/c5yr1990.clm.regcm.r.1991010100.nc"

for file in "$initial" "$year1" "$year2" "$restart" "$year1_restart"; do
  test -s "$file"
  ncdump -h "$file" >/dev/null
done

# Pairwise, restart-aware QA for the second annual update.
"$python" "$run/analyze_pft_change.py" \
  "$year1" "$year2" "$run/analysis/year2_pair" "$restart" "$year1_restart"

# Three-state comparison: cold start, first year end, second year end.
"$python" "$run/analyze_three_year_states.py" \
  "$initial" "$year1" "$year2" "$run/analysis/three_state"

for file in \
  "$run/analysis/year2_pair/pft_change_summary.txt" \
  "$run/analysis/year2_pair/pft_change_by_type.csv" \
  "$run/analysis/three_state/pft_three_state_summary.txt" \
  "$run/analysis/three_state/pft_three_state_by_type.csv" \
  "$run/analysis/three_state/pft_two_annual_updates.png" \
  "$run/analysis/three_state/pft_year2_abs_change_map.png"; do
  test -s "$file"
done
printf 'PFT_YEAR2_ANALYSIS_OK\n'
