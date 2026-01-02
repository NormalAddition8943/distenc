#!/bin/bash

# Check minimum input arguments
if [ "$#" -lt 5 ]; then
    echo "Usage: $0 script-src-tgt.sh source_dir source_prefix target_dir target_prefix [extra-args...]"
    exit 1
fi

SCRIPT="$1"
SOURCE_DIR="$2"
SOURCE_PREFIX="$3"
TARGET_DIR="$4"
TARGET_PREFIX="$5"
shift 5

# Any remaining arguments are passed through
EXTRA_ARGS=("$@")

for s in $(seq -w 1 12); do
  for e in $(seq -w 1 28); do
    # Use globbing safely; avoid word-splitting by using arrays
    shopt -s nullglob
    src_matches=("$SOURCE_DIR"/"$SOURCE_PREFIX"*S${s}[Ee]${e}*.mkv)
    tgt_matches=("$TARGET_DIR"/"$TARGET_PREFIX"*S${s}[Ee]${e}*.mkv)
    shopt -u nullglob

    # pick first match if any
    SOURCE_FILE="${src_matches[0]}"
    TARGET_FILE="${tgt_matches[0]}"

    if [[ -n "$SOURCE_FILE" && -n "$TARGET_FILE" && -f "$SOURCE_FILE" && -f "$TARGET_FILE" ]]; then
      # Invoke the script with source, target, then any extra args
      "$SCRIPT" "$SOURCE_FILE" "$TARGET_FILE" "${EXTRA_ARGS[@]}"
    fi
  done
done
