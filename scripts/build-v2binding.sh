#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

require_macos
require_command xcodebuild
require_command xcrun
require_command go
require_source_layout

ios_min_version="${V2BINDING_IOS_MIN_VERSION:-26.1}"
output_path="${V2BINDING_OUTPUT:-${app_root}/V2binding.xcframework}"
tool_bin="${V2BINDING_TOOL_BIN:-${build_root}/gomobile-tools/bin}"
mobile_version="$(awk '$1 == "golang.org/x/mobile" { print $2; exit }' "${core_root}/go.mod")"

[[ -n "${mobile_version}" ]] || fail "could not determine golang.org/x/mobile version from ${core_root}/go.mod"
[[ "${output_path}" == *.xcframework ]] || fail "V2BINDING_OUTPUT must end in .xcframework"
[[ "${output_path}" != "/" ]] || fail "refusing unsafe V2BINDING_OUTPUT"

mkdir -p "${build_root}" "${tool_bin}" "$(dirname "${output_path}")"

echo "Installing pinned gomobile tools (${mobile_version}) into ${tool_bin}"
GOBIN="${tool_bin}" go install "golang.org/x/mobile/cmd/gomobile@${mobile_version}"
GOBIN="${tool_bin}" go install "golang.org/x/mobile/cmd/gobind@${mobile_version}"

export PATH="${tool_bin}:${PATH}"

cd "${core_root}"
if [[ "${V2BINDING_SKIP_GO_VERIFY:-0}" != "1" ]]; then
    go mod download
    go mod verify
fi

temporary_dir="$(mktemp -d "${build_root}/v2binding.XXXXXX")"
cleanup() {
    rm -rf -- "${temporary_dir}"
}
trap cleanup EXIT

temporary_output="${temporary_dir}/V2binding.xcframework"
echo "Building V2binding for ios and iossimulator"
"${tool_bin}/gomobile" bind \
    -v \
    -target=ios,iossimulator \
    -iosversion="${ios_min_version}" \
    -o "${temporary_output}" \
    ./main/v2binding

[[ -d "${temporary_output}/ios-arm64/V2binding.framework" ]] || \
    fail "gomobile did not produce the ios-arm64 framework"
[[ -d "${temporary_output}/ios-arm64_x86_64-simulator/V2binding.framework" ]] || \
    fail "gomobile did not produce the combined simulator framework"

if [[ -e "${output_path}" ]]; then
    rm -rf -- "${output_path}"
fi
mv "${temporary_output}" "${output_path}"

echo "Created ${output_path}"

