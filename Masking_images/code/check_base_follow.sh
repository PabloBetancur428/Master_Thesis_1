#!/usr/bin/env bash
#
# compare_baseline_followup.sh
#
# Purpose:
#   1) Identify the patient IDs (subfolder names) in a baseline directory
#   2) Identify the patient IDs (subfolder names) in a follow-up directory
#   3) Print which IDs are in both, only in baseline, and only in follow-up.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 BASELINE_DIR FOLLOWUP_DIR"
  exit 1
fi

BASELINE_DIR="$1"
FOLLOWUP_DIR="$2"

# -----------------------------------------------------------------------------
# Gather subfolder names (patient IDs) in each directory
# -----------------------------------------------------------------------------
# -mindepth 1 -maxdepth 1 ensures we only look one level down.
# -type d ensures we only look at directories.
# -printf '%f\n' (or using `basename` in some systems) extracts just the folder name.
# If your system doesn't support -printf, you can pipe to 'awk' or use a simpler approach.

mapfile -t baseline_ids < <(find "$BASELINE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
mapfile -t followup_ids < <(find "$FOLLOWUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

# -----------------------------------------------------------------------------
# Create associative arrays to mark presence in baseline and follow-up
# -----------------------------------------------------------------------------
declare -A baseline_set
declare -A followup_set

# Mark all baseline IDs in an associative array
for id in "${baseline_ids[@]}"; do
  baseline_set["$id"]=1
done

# Mark all follow-up IDs in an associative array
for id in "${followup_ids[@]}"; do
  followup_set["$id"]=1
done

in_both=()
only_baseline=()
only_followup=()

# 1) For each baseline ID, check if also in followup
for id in "${baseline_ids[@]}"; do
  if [[ -n "${followup_set[$id]:-}" ]]; then
    in_both+=("$id")
  else
    only_baseline+=("$id")
  fi
done

# 2) For each followup ID, check if not in baseline
for id in "${followup_ids[@]}"; do
  if [[ -z "${baseline_set[$id]:-}" ]]; then
    only_followup+=("$id")
  fi
done

# -----------------------------------------------------------------------------
# Print results
# -----------------------------------------------------------------------------
echo "=============================================="
echo "PATIENTS IN BOTH BASELINE AND FOLLOW-UP (${#in_both[@]})"
echo "=============================================="
for id in "${in_both[@]}"; do
  echo "  $id"
done

echo ""
echo "=============================================="
echo "PATIENTS ONLY IN BASELINE (${#only_baseline[@]})"
echo "=============================================="
for id in "${only_baseline[@]}"; do
  echo "  $id"
done

echo ""
echo "=============================================="
echo "PATIENTS ONLY IN FOLLOW-UP (${#only_followup[@]})"
echo "=============================================="

for id in "${only_followup[@]}"; do
  echo "  $id"
done

