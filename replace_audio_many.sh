#!/bin/bash

# Check input arguments
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 script-src-tgt.sh source_dir source_prefix target_dir target_prefix"
    exit 1
fi

SCRIPT="$1"
SOURCE_DIR="$2"
SOURCE_PREFIX="$3"
TARGET_DIR="$4"
TARGET_PREFIX="$5"

for s in $(seq -w 1 12); do
  for e in $(seq -w 1 28); do
    SOURCE_FILE=$(ls $SOURCE_DIR/$SOURCE_PREFIX*S${s}E${e}*.mkv)
    TARGET_FILE=$(ls $TARGET_DIR/$TARGET_PREFIX*S${s}E${e}*.mkv)

    if [[ -f "$SOURCE_FILE" && -f "$TARGET_FILE" ]]; then
      "$SCRIPT" "$SOURCE_FILE" "$TARGET_FILE"
    fi
  done
done
