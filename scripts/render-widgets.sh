#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
bash scripts/swift.sh build --product TashAirWidgetPreview
binary_dir="$(bash scripts/swift.sh build --show-bin-path)"
"$binary_dir/TashAirWidgetPreview" "$project_dir/temp/widget-previews"
