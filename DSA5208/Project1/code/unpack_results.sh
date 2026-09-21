#!/usr/bin/env bash
# Restore every compressed JSONL event history without deleting its archive.
# Existing uncompressed files are preserved so the command is safe to rerun.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

find "$root/results" -type f -name '*.jsonl.gz' -print0 |
  while IFS= read -r -d '' archive; do
    output="${archive%.gz}"
    if [[ -e "$output" ]]; then
      echo "Skipping existing $output"
    else
      echo "Unpacking $archive"
      gzip -dk "$archive"
    fi
  done
