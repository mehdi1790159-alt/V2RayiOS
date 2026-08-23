#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${script_dir}/common.sh"

require_macos
require_command xcodebuild
require_app_source_layout

configuration="${V2RAYIOS_CONFIGURATION:-Release}"
platform="${1:-device}"
signing_mode="${V2RAYIOS_SIGNING_MODE:-unsigned}"

case "${platform}" in
    device)
        sdk="iphoneos"
        destination="generic/platform=iOS"
        product_directory="${configuration}-iphoneos"
        ;;
    simulator)
        sdk="iphonesimulator"
        destination="generic/platform=iOS Simulator"
        product_directory="${configuration}-iphonesimulator"
        ;;
    *)
        fail "platform must be 'device' or 'simulator'"
        ;;
esac

derived_data_path="${V2RAYIOS_DERIVED_DATA:-${build_root}/DerivedData-${configuration}-${platform}}"
framework_path="${V2BINDING_OUTPUT:-${app_root}/V2binding.xcframework}"
[[ -d "${framework_path}" ]] || \
    fail "missing ${framework_path}; run scripts/build-v2binding.sh first"

build_arguments=(
    -project V2RayiOS.xcodeproj
    -scheme V2RayiOS
    -configuration "${configuration}"
    -sdk "${sdk}"
    -destination "${destination}"
    -derivedDataPath "${derived_data_path}"
)

case "${signing_mode}" in
    unsigned)
        build_arguments+=(
            CODE_SIGNING_ALLOWED=NO
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGN_IDENTITY=
            DEVELOPMENT_TEAM=
            "DEVELOPMENT_TEAM[sdk=iphoneos*]="
            PROVISIONING_PROFILE_SPECIFIER=
            "PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]="
        )
        ;;
    automatic)
        : "${V2RAYIOS_TEAM_ID:?Set V2RAYIOS_TEAM_ID when V2RAYIOS_SIGNING_MODE=automatic}"
        build_arguments+=(
            CODE_SIGN_STYLE=Automatic
            "DEVELOPMENT_TEAM=${V2RAYIOS_TEAM_ID}"
        )
        if [[ -n "${V2RAYIOS_BUNDLE_ID:-}" ]]; then
            build_arguments+=("PRODUCT_BUNDLE_IDENTIFIER=${V2RAYIOS_BUNDLE_ID}")
        fi
        if [[ "${V2RAYIOS_ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
            build_arguments+=(-allowProvisioningUpdates)
        fi
        ;;
    *)
        fail "V2RAYIOS_SIGNING_MODE must be 'unsigned' or 'automatic'"
        ;;
esac

cd "${app_root}"
xcodebuild "${build_arguments[@]}" clean build

app_path="${derived_data_path}/Build/Products/${product_directory}/V2RayiOS.app"
[[ -d "${app_path}" ]] || fail "expected app product was not created: ${app_path}"
echo "Created ${app_path}"
