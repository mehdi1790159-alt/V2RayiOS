#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

require_macos
require_command xcodebuild
require_command xcrun
require_command zip
require_command unzip
require_command ditto
require_app_source_layout

echo "V2RayiOS source: ${app_root}"
echo "Build directory: ${build_root}"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version

if v2binding_is_available && [[ "${V2BINDING_FORCE_REBUILD:-0}" != "1" ]]; then
    echo "Existing generated framework: $(v2binding_output_path)"
else
    require_command go
    require_core_source_layout
    mobile_version="$(awk '$1 == "golang.org/x/mobile" { print $2; exit }' "${core_root}/go.mod")"
    [[ -n "${mobile_version}" ]] || fail "could not determine golang.org/x/mobile version from ${core_root}/go.mod"

    echo "v2ray-core source: ${core_root}"
    echo "Pinned x/mobile: ${mobile_version}"
    go version
    echo "V2binding.xcframework is absent or a rebuild was requested; it will be generated"
fi
