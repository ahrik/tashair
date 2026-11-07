#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
bash scripts/build-app.sh
temp/outputs/TashAir.app/Contents/MacOS/TashAir --verify "$project_dir/temp/verification"
