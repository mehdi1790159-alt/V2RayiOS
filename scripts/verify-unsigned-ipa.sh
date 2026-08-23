#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

require_macos
require_command codesign
require_command lipo
require_command unzip

configuration="${V2RAYIOS_CONFIGURATION:-Release}"
ipa_path="${1:-${V2RAYIOS_IPA_OUTPUT:-${build_root}/V2RayiOS-${configuration}-unsigned.ipa}}"
[[ -f "${ipa_path}" ]] || fail "IPA not found: ${ipa_path}"

staging_path="$(mktemp -d "${TMPDIR:-/tmp}/V2RayiOS-verify.XXXXXX")"
cleanup() {
    rm -rf -- "${staging_path}"
}
trap cleanup EXIT

unzip -q "${ipa_path}" -d "${staging_path}"

app_path=""
app_count=0
while IFS= read -r -d '' candidate_path; do
    app_path="${candidate_path}"
    ((app_count += 1))
done < <(find "${staging_path}/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print0)

[[ "${app_count}" -eq 1 ]] || fail "expected exactly one Payload/*.app, found ${app_count}"

signature_artifact="$(
    find "${app_path}" \
        \( -type d -name _CodeSignature -o -type f -name embedded.mobileprovision \) \
        -print -quit
)"
[[ -z "${signature_artifact}" ]] || fail "signature artifact remains in IPA: ${signature_artifact}"

while IFS= read -r -d '' signable_path; do
    if codesign --display --verbose=0 "${signable_path}" >/dev/null 2>&1; then
        fail "signed code remains in IPA: ${signable_path}"
    fi
done < <(
    find "${app_path}" -depth \
        \( -type d \( -name '*.app' -o -name '*.appex' -o -name '*.framework' \) \
        -o -type f -name '*.dylib' \) -print0
)

info_plist="${app_path}/Info.plist"
[[ -f "${info_plist}" ]] || fail "app Info.plist is missing"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${info_plist}")"
[[ -n "${executable_name}" ]] || fail "CFBundleExecutable is empty"
[[ -f "${app_path}/${executable_name}" ]] || fail "app executable is missing: ${executable_name}"

architectures="$(lipo -archs "${app_path}/${executable_name}")"
case " ${architectures} " in
    *" arm64 "*) ;;
    *) fail "app executable does not contain arm64: ${architectures}" ;;
esac

echo "Verified unsigned arm64 IPA: ${ipa_path}"
