# Building V2RayiOS from source

The complete source package has this layout:

```text
V2RayiOS-complete-build-source-20260823/
├── V2RayiOS/
│   ├── V2RayiOS.xcodeproj/
│   └── scripts/
├── v2ray-core/
└── v2ray-core-patches/
```

`V2binding.xcframework` is intentionally not included. It is generated from
the bundled `v2ray-core` source by the build scripts.

## Requirements

- macOS with Xcode and the iOS SDK installed
- Xcode command-line tools selected with `xcode-select`
- Go capable of using the `go1.26.1` toolchain declared by v2ray-core
- Network access on the first build to download Go modules and the pinned
  `golang.org/x/mobile` tools
- `zip`, `unzip`, and `ditto` (included with macOS)

The recorded successful build used Xcode 26.1, Go 1.26.1, and
`golang.org/x/mobile v0.0.0-20260709172247-6129f5bee9d5`.

## Build everything

After extracting the archive:

```bash
cd V2RayiOS-complete-build-source-20260823/V2RayiOS
./scripts/build-all.sh
```

This performs the following operations:

1. validates the source layout and macOS toolchain;
2. when the framework is missing, installs the exact `gomobile` and `gobind`
   version recorded in the bundled v2ray-core `go.mod` into
   `V2RayiOS/build/gomobile-tools`;
3. builds device and simulator slices into `V2binding.xcframework` when it is
   not already present;
4. builds an unsigned Release device app with Xcode; and
5. packages it as `build/V2RayiOS-Release-unsigned.ipa`.

Set `V2BINDING_FORCE_REBUILD=1` to regenerate an existing framework.

To also compile the simulator app, run:

```bash
V2RAYIOS_BUILD_SIMULATOR=1 ./scripts/build-all.sh
```

## Individual stages

```bash
./scripts/check-prerequisites.sh
./scripts/build-v2binding.sh
./scripts/build-app.sh device
./scripts/package-ipa.sh
./scripts/verify-unsigned-ipa.sh
./scripts/build-app.sh simulator
```

Important overrides:

- `V2RAY_CORE_DIR`: use a v2ray-core tree outside the default sibling path.
- `V2BINDING_IOS_MIN_VERSION`: minimum iOS version passed to gomobile;
  defaults to `26.1` to match the Xcode project.
- `V2RAYIOS_CONFIGURATION`: Xcode configuration, default `Release`.
- `V2RAYIOS_BUILD_DIR`: generated-products root.
- `V2RAYIOS_DERIVED_DATA`: custom Xcode DerivedData path.
- `V2RAYIOS_IPA_OUTPUT`: custom output IPA path.

## Signing

The default output is unsigned. Signing identities, provisioning profiles,
certificates, and private keys are deliberately excluded from the source
package.

For an automatic-signing device build:

```bash
V2RAYIOS_SIGNING_MODE=automatic \
V2RAYIOS_TEAM_ID=YOUR_TEAM_ID \
V2RAYIOS_BUNDLE_ID=your.unique.bundle.id \
V2RAYIOS_ALLOW_PROVISIONING_UPDATES=1 \
./scripts/build-app.sh device

V2RAYIOS_IPA_OUTPUT=build/V2RayiOS-Release-signed.ipa \
./scripts/package-ipa.sh
```

The final IPA preserves whatever signature is present in the built `.app`.
Apple account configuration and entitlement approval remain the builder's
responsibility.

## GitHub Actions

`.github/workflows/build-unsigned-ipa.yml` builds on branch pushes, manual
workflow runs, and published releases. When `V2binding.xcframework` is absent,
the workflow checks out the current default-branch HEAD of
`v2fly/v2ray-core`, and records the resolved commit in `build-info.txt`.

Every successful run uploads the IPA, its SHA-256 checksum, build metadata,
and the dSYM (when produced) as a GitHub Actions artifact. The workflow omits
an explicit retention period so the repository or organization setting is
used. Published-release runs also upload the IPA to that GitHub Release.
