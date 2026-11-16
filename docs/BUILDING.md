# Building ContainerDesk

These instructions build the ContainerDesk app and a local development DMG from the personal fork. They do not install or start Apple's `container` Runtime.

## Prerequisites

- An Apple silicon Mac (`arm64`). Intel builds are not produced.
- Xcode 27.2 (27B52) is the toolchain used for the current build and test evidence. Swift is included with Xcode.
- GitHub access for the first Swift Package Manager resolution. `Package.resolved` pins the app's dependencies.
- A Runtime installation is not needed to build the app or run the unit tests.

The current app target has a minimum macOS setting of 26.0. The product support matrix remains open until the release acceptance scenarios pass on specific macOS versions; see [README.md](../README.md) and [RELEASING.md](RELEASING.md).

## Clone the fork

```bash
git clone --branch containerdesk/main https://github.com/Jackygao2/orchard.git ContainerDesk
cd ContainerDesk
```

The Xcode project and scheme keep Orchard's names for upstream compatibility; the built app is `ContainerDesk.app`.

## Run tests

```bash
xcodebuild test \
  -project Orchard.xcodeproj \
  -scheme Orchard \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/build/DerivedData" \
  -clonedSourcePackagesDirPath "$PWD/build/SourcePackages" \
  CODE_SIGNING_ALLOWED=NO

scripts/tests/packaging-scripts-tests.sh
```

The first command runs the `Orchard` unit-test scheme. The packaging script checks exercise the packaging scripts' argument, signing-mode and safety guards, including the local notarization script's missing-credential path, then run `bash -n` on all five packaging scripts. Current integrated-candidate results are recorded in its [T-E1 evidence](release/evidence/e1-integrated-test-results-2026-11-16.md). Unit or packaging checks are not a pass of the release acceptance scenarios or the separate UI test scheme.

## Build a local unsigned app

```bash
scripts/build-app.sh
```

This runs an arm64 Release archive and writes `build/ContainerDesk.app`. It uses the pinned package cache in `build/SourcePackages` and derived data in `build/DerivedData`. The unsigned local-development artifact is ad-hoc signed without the hardened runtime, because it has no Team ID and cannot load the separately signed Sparkle framework under hardened-runtime library validation. This artifact is for local development only; it is not Developer ID signed, notarized, Gatekeeper-approved or publishable. The signed Developer ID path retains the hardened runtime and signs embedded code with the configured identity. Re-running the script replaces its own `build/ContainerDesk.xcarchive`, `build/ContainerDesk.app` and export output.

## Create and verify a DMG

```bash
scripts/make-dmg.sh "$PWD/build/ContainerDesk.app" 1.0.0
scripts/verify-release.sh "$PWD/build/ContainerDesk-1.0.0-arm64.dmg"
```

The DMG is named `ContainerDesk-<version>-arm64.dmg`; the script also writes a `.sha256` sidecar. It contains the app, an `/Applications` shortcut and the checked-in 1x/2x background artwork. macOS may ask the invoking app (for example, Terminal) to control Finder so the script can set the DMG window layout.

The verifier checks the sidecar, disk image, bundle identifier, minimum macOS, architecture, artwork and code-signing state. An unsigned-development artifact should report an ad-hoc signature, Gatekeeper rejection and no notarization ticket. To make the verifier require release-level checks, run:

```bash
scripts/verify-release.sh --require-publishable "$PWD/build/ContainerDesk-1.0.0-arm64.dmg"
```

This strict mode must fail for the local ad-hoc build. A successful local verification does not mean the artifact is ready for distribution.

## Exercise installation and launch safely

```bash
scripts/install-and-launch-test.sh \
  "$PWD/build/ContainerDesk-1.0.0-arm64.dmg" \
  --install-root "$PWD/build/install-smoke"
```

The explicit install root keeps the check out of `/Applications`. The script refuses to overwrite an existing app or confuse an already-running ContainerDesk process, launches the copied app, checks its executable path and stops only the process it started. It does not install or start the Runtime. The copied app remains at `build/install-smoke/ContainerDesk.app` until you remove it.

## Optional local Developer ID build

Developer ID signing is only for a Mac with a valid Developer ID Application identity in its keychain. Copy the example and edit the local, ignored file:

```bash
cp Config/Signing.example.xcconfig Config/Signing.xcconfig
```

Set `CD_SIGNING_TEAM` to the 10-character team ID and `CD_SIGNING_IDENTITY` to the specific Developer ID Application identity. Then run:

```bash
scripts/build-app.sh --signed
```

`Config/Signing.xcconfig` is git-ignored. Never commit signing identities, private keys, certificates or notarization credentials. A signed build is not automatically notarized; notarization and publication remain blocked by the open release decisions documented in [docs/RELEASING.md](RELEASING.md). This optional signed path has not been tested in the current environment because no Developer ID identity is configured.

After a signed build and DMG exist, configure a `notarytool` Keychain profile as described in [RELEASING.md](RELEASING.md), then use `scripts/notarize.sh <dmg>` to submit, staple, validate and run strict release verification. The script fails before submission when the signing configuration, Developer ID identity or Keychain profile is missing. Its argument and missing-credential paths are tested; successful signing and notarization still require external credentials and have not run here.
