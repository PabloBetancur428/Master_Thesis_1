#!/usr/bin/env bash
#
# copy_baseline_if_in_followup.sh
#
# Purpose:
#   1) Compare two directories: baseline_dir and followup_dir, each containing
#      subfolders named by patient ID (e.g., Patient_001).
#   2) Identify the set of patients who appear in BOTH directories.
#   3) Copy the baseline folder for each matching patient into a new baseline directory.
#
# Usage:
#   ./copy_baseline_if_in_followup.sh /path/to/baseline_dir /path/to/followup_dir /path/to/new_baseline
#
# Example:
#   ./copy_baseline_if_in_followup.sh \
#       /home/user/data/baseline \
#       /home/user/data/followup \
#       /home/user/data/matching_baseline

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 BASELINE_DIR FOLLOWUP_DIR NEW_BASELINE_DIR"
  exit 1
fi

BASELINE_DIR="$1"
FOLLOWUP_DIR="$2"
NEW_BASELINE_DIR="$3"

# Ensure the new baseline directory exists
mkdir -p "$NEW_BASELINE_DIR"

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
# 5) Copy each matching patient’s baseline folder to NEW_BASELINE_DIR
# -----------------------------------------------------------------------------
echo ""
echo "Copying matching baseline folders to $NEW_BASELINE_DIR..."

for id in "${in_both[@]}"; do
  BASELINE_PATH="$BASELINE_DIR/$id"
  DEST_PATH="$NEW_BASELINE_DIR/$id"

  if [ -d "$BASELINE_PATH" ]; then
    echo "--------------------------------------------------"
    echo "Copying $BASELINE_PATH -> $DEST_PATH"
    cp -r "$BASELINE_PATH" "$DEST_PATH"
  else
    echo "WARNING: $BASELINE_PATH does not exist, skipping $id"
  fi
done

echo ""
echo "All eligible baseline folders have been copied."
