#!/bin/bash
#
# Resize marketing images to an exact App Store screenshot size.
#
# Usage:
#   scripts/resize_marketing.sh [options] <file-or-directory>...
#
# Options:
#   -s WxH    Target size in pixels (default: 1242x2688, the 6.5" iPhone slot)
#   -o DIR    Output directory (default: <input-dir>/AppStore-WxH)
#   -m MODE   fill = scale to cover, center-crop overflow (default)
#             pad  = scale to fit, pad with background color
#   -c HEX    Pad color for pad mode (default: 000000)
#
# Examples:
#   scripts/resize_marketing.sh Screenshots/MarketingSeeded
#   scripts/resize_marketing.sh -s 1320x2868 -m pad ~/Desktop/marketing
#   scripts/resize_marketing.sh -s 410x502 Screenshots/WatchMarketing
#
# Uses only macOS built-in `sips` — no dependencies.

set -euo pipefail

size="1242x2688"
outdir=""
mode="fill"
padcolor="000000"

while getopts "s:o:m:c:h" opt; do
  case "$opt" in
    s) size="$OPTARG" ;;
    o) outdir="$OPTARG" ;;
    m) mode="$OPTARG" ;;
    c) padcolor="$OPTARG" ;;
    h) sed -n '2,20p' "$0"; exit 0 ;;
    *) exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ $# -eq 0 ]]; then
  echo "error: no input files or directories given (try -h)" >&2
  exit 1
fi
if [[ "$mode" != "fill" && "$mode" != "pad" ]]; then
  echo "error: mode must be 'fill' or 'pad'" >&2
  exit 1
fi

target_w="${size%x*}"
target_h="${size#*x}"

# Collect input image files.
files=()
first_dir=""
for input in "$@"; do
  if [[ -d "$input" ]]; then
    [[ -z "$first_dir" ]] && first_dir="$input"
    while IFS= read -r -d '' f; do files+=("$f"); done \
      < <(find "$input" -maxdepth 1 \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | sort -z)
  elif [[ -f "$input" ]]; then
    files+=("$input")
  else
    echo "warning: skipping missing input: $input" >&2
  fi
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "error: no images found in inputs" >&2
  exit 1
fi

if [[ -z "$outdir" ]]; then
  base_dir="${first_dir:-$(dirname "${files[0]}")}"
  outdir="$base_dir/AppStore-${target_w}x${target_h}"
fi
mkdir -p "$outdir"

for f in "${files[@]}"; do
  name="$(basename "$f")"
  out="$outdir/${name%.*}.png"

  src_w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')
  src_h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')

  if [[ "$mode" == "fill" ]]; then
    # Scale so the image covers the target box, then center-crop.
    read -r new_w new_h < <(python3 -c "
import math
s = max($target_w / $src_w, $target_h / $src_h)
print(math.ceil($src_w * s), math.ceil($src_h * s))
")
    sips --resampleHeightWidth "$new_h" "$new_w" \
         --cropToHeightWidth "$target_h" "$target_w" \
         -s format png "$f" --out "$out" >/dev/null
  else
    # Scale so the image fits inside the target box, then pad.
    read -r new_w new_h < <(python3 -c "
s = min($target_w / $src_w, $target_h / $src_h)
print(max(1, round($src_w * s)), max(1, round($src_h * s)))
")
    sips --resampleHeightWidth "$new_h" "$new_w" \
         --padToHeightWidth "$target_h" "$target_w" --padColor "$padcolor" \
         -s format png "$f" --out "$out" >/dev/null
  fi

  echo "$name: ${src_w}x${src_h} -> ${target_w}x${target_h} ($mode) -> $out"
done
