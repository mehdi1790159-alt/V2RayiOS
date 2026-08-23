#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_root="$(cd "${script_dir}/.." && pwd)"
source_root="$(cd "${app_root}/.." && pwd)"
core_root="${V2RAY_CORE_DIR:-${source_root}/v2ray-core}"
build_root="${V2RAYIOS_BUILD_DIR:-${app_root}/build}"

# Non-interactive SSH shells on macOS often omit paths configured by the
# user's interactive shell. Add the standard Go and Homebrew locations so the
# same scripts work both from Terminal and through `ssh host command`.
if [[ "$(uname -s)" == "Darwin" ]]; then
    for candidate_path in /usr/local/bin /opt/homebrew/bin /usr/local/go/bin; do
        if [[ -d "${candidate_path}" && ":${PATH}:" != *":${candidate_path}:"* ]]; then
            PATH="${candidate_path}:${PATH}"
        fi
    done
    export PATH
fi

fail() {
    echo "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_macos() {
    [[ "$(uname -s)" == "Darwin" ]] || fail "this build requires macOS and Xcode"
}

require_app_source_layout() {
    [[ -f "${app_root}/V2RayiOS.xcodeproj/project.pbxproj" ]] || \
        fail "V2RayiOS Xcode project not found under ${app_root}"
}

require_core_source_layout() {
    [[ -f "${core_root}/go.mod" ]] || \
        fail "v2ray-core go.mod not found under ${core_root}; set V2RAY_CORE_DIR if it is elsewhere"
    [[ -d "${core_root}/main/v2binding" ]] || \
        fail "v2binding package not found under ${core_root}/main/v2binding"
}

require_source_layout() {
    require_app_source_layout
    require_core_source_layout
}

v2binding_output_path() {
    printf '%s\n' "${V2BINDING_OUTPUT:-${app_root}/V2binding.xcframework}"
}

v2binding_is_available() {
    local output_path
    output_path="$(v2binding_output_path)"
    [[ -f "${output_path}/Info.plist" ]] && \
        [[ -d "${output_path}/ios-arm64/V2binding.framework" ]]
}
