#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  printf 'Usage: %s <source.mkv> <target.mkv>\n' "$0" >&2
  exit 2
fi

SRC=$1
TGT=$2

if [[ -d /dev/shm && -w /dev/shm ]]; then
  TMPDIR=$(mktemp -d /dev/shm/replace-audio.XXXXXX)
else
  TMPDIR=$(mktemp -d)
fi
trap 'rm -rf -- "$TMPDIR"' EXIT

command -v mkvmerge >/dev/null 2>&1
command -v mkvextract >/dev/null 2>&1

# extract first audio track from source
SRC_ID=$(mkvmerge -i "$SRC" | awk -F': ' '/Track ID [0-9]+: audio/ { sub(/Track ID /,"",$1); sub(/: audio.*/,"",$1); print $1; exit }')
SRC_AUDIO="$TMPDIR/src_audio.track"
mkvextract tracks "$SRC" "${SRC_ID}:${SRC_AUDIO}"

# remux target without audio and add the extracted source audio
NOAUDIO="$TMPDIR/target_noaudio.mkv"
mkvmerge -o "$NOAUDIO" --no-audio "$TGT"

OUT="${TGT%.*}.replaced.mkv"
mkvmerge -o "$OUT" "$NOAUDIO" "$SRC_AUDIO"

mv -v "$OUT" "$TGT"

