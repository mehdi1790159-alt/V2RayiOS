#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

require_command zip
require_command unzip
require_command ditto

configuration="${V2RAYIOS_CONFIGURATION:-Release}"
derived_data_path="${V2RAYIOS_DERIVED_DATA:-${build_root}/DerivedData-${configuration}-device}"
app_path="${V2RAYIOS_APP_PATH:-${derived_data_path}/Build/Products/${configuration}-iphoneos/V2RayiOS.app}"
output_path="${V2RAYIOS_IPA_OUTPUT:-${build_root}/V2RayiOS-${configuration}-unsigned.ipa}"

[[ -d "${app_path}" ]] || fail "device app not found: ${app_path}"
[[ "${output_path}" == *.ipa ]] || fail "V2RAYIOS_IPA_OUTPUT must end in .ipa"
[[ "${output_path}" != "/" ]] || fail "refusing unsafe V2RAYIOS_IPA_OUTPUT"

mkdir -p "$(dirname "${output_path}")"
staging_path="$(mktemp -d "${TMPDIR:-/tmp}/V2RayiOS-ipa.XXXXXX")"
cleanup() {
    rm -rf -- "${staging_path}"
}
trap cleanup EXIT

mkdir -p "${staging_path}/Payload"
ditto "${app_path}" "${staging_path}/Payload/V2RayiOS.app"
rm -f -- "${output_path}"
(
    cd "${staging_path}"
    zip -qry "${output_path}" Payload
)

unzip -tq "${output_path}" >/dev/null
echo "Created ${output_path}"
