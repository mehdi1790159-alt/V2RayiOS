#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"${script_dir}/check-prerequisites.sh"

# shellcheck source=common.sh
source "${script_dir}/common.sh"
if v2binding_is_available && [[ "${V2BINDING_FORCE_REBUILD:-0}" != "1" ]]; then
    echo "Using existing $(v2binding_output_path)"
else
    "${script_dir}/build-v2binding.sh"
fi

"${script_dir}/build-app.sh" device
"${script_dir}/package-ipa.sh"

if [[ "${V2RAYIOS_BUILD_SIMULATOR:-0}" == "1" ]]; then
    "${script_dir}/build-app.sh" simulator
fi
