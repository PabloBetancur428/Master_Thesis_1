#!/usr/bin/env bash
#
# copy_followup_if_in_baseline.sh
#
# Purpose:
#   1) Compare two directories: baseline_dir and followup_dir, each containing
#      subfolders named by patient ID (e.g., Patient_001).
#   2) Identify the set of patients who appear in BOTH directories.
#   3) Copy the follow-up folder for each matching patient into a new destination directory.
#
# Usage:
#   ./copy_followup_if_in_baseline.sh /path/to/baseline_dir /path/to/followup_dir /path/to/new_destination
#
# Example:
#   ./copy_followup_if_in_baseline.sh \
#       /home/user/data/baseline \
#       /home/user/data/followup \
#       /home/user/data/matching_followup

#path_baseline = /home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/pruebas
#path_follow_up = /home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/pruebas_follow_up
#output_follow_up = /home/jbetancur/Desktop/codes/python_qsm/exploratory_pipeline/data_automatization/follow_up_both
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 BASELINE_DIR FOLLOWUP_DIR DESTINATION_DIR"
  exit 1
fi

BASELINE_DIR="$1"
FOLLOWUP_DIR="$2"
DESTINATION_DIR="$3"

# Ensure the destination directory exists
mkdir -p "$DESTINATION_DIR"

# -----------------------------------------------------------------------------
# 1) Gather patient IDs in each directory (one-level down subfolders)
# -----------------------------------------------------------------------------
mapfile -t baseline_ids < <(find "$BASELINE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
mapfile -t followup_ids < <(find "$FOLLOWUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

# -----------------------------------------------------------------------------
# 2) Create sets (associative arrays) for quick membership checks
# -----------------------------------------------------------------------------
declare -A baseline_set
declare -A followup_set

for id in "${baseline_ids[@]}"; do
  baseline_set["$id"]=1
done

for id in "${followup_ids[@]}"; do
  followup_set["$id"]=1
done

# -----------------------------------------------------------------------------
# 3) Identify the intersection (patients in BOTH)
# -----------------------------------------------------------------------------
in_both=()

for id in "${baseline_ids[@]}"; do
  if [[ -n "${followup_set[$id]:-}" ]]; then
    in_both+=("$id")
  fi
done

# -----------------------------------------------------------------------------
# 4) Print summary
# -----------------------------------------------------------------------------
echo "=============================================="
echo "PATIENTS IN BOTH BASELINE AND FOLLOW-UP (${#in_both[@]})"
echo "=============================================="
for id in "${in_both[@]}"; do
  echo "  $id"
done

# -----------------------------------------------------------------------------
# 5) Copy each matching patient’s follow-up folder to DESTINATION_DIR
# -----------------------------------------------------------------------------
echo ""
echo "Copying matching follow-up folders to $DESTINATION_DIR..."

for id in "${in_both[@]}"; do
  FOLLOWUP_PATH="$FOLLOWUP_DIR/$id"
  DEST_PATH="$DESTINATION_DIR/$id"

  if [ -d "$FOLLOWUP_PATH" ]; then
    echo "--------------------------------------------------"
    echo "Copying $FOLLOWUP_PATH -> $DEST_PATH"
    cp -r "$FOLLOWUP_PATH" "$DEST_PATH"
  else
    echo "WARNING: $FOLLOWUP_PATH does not exist, skipping $id"
  fi
done

echo ""
echo "All eligible follow-up folders have been copied."
