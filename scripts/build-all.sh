#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/check-prerequisites.sh"
"${script_dir}/build-v2binding.sh"
"${script_dir}/build-app.sh" device
"${script_dir}/package-ipa.sh"

if [[ "${V2RAYIOS_BUILD_SIMULATOR:-0}" == "1" ]]; then
    "${script_dir}/build-app.sh" simulator
fi

