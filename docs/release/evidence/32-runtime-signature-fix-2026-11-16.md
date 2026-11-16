# T-D5 unsigned local build signing correction — 2026-11-16

Environment: macOS 27.2.1 (26B131), Xcode 27.2 (27B52), Apple silicon. Worktree: `task/t-d5-local-packaging`.

## Failure and correction

The original hardened, ad-hoc DMG was installable but crashed at launch. The crash report identified `EXC_CRASH` / `DYLD`, with Sparkle rejected by library validation because the local app had no Team ID. Apple documents library validation as requiring Apple-signed code or code signed with the same Team ID; nested code should be signed from the inside out. See [Apple's nested-code signing guide](https://developer.apple.com/documentation/xcode/using-the-latest-code-signature-format) and [library validation entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.cs.disable-library-validation).

The unsigned local-development branch of `scripts/build-app.sh` now applies an ad-hoc signature without the Hardened Runtime. The optional Developer ID branch is unchanged; it retains Release hardening and uses the configured identity. No library-validation exception entitlement was added. The local app and embedded Sparkle framework both report an ad-hoc signature with no Team ID. `codesign --verify --deep --strict --verbose=2 build/ContainerDesk.app` passed.

## Verification

- `scripts/tests/packaging-scripts-tests.sh` — all seven argument/safety checks passed.
- `bash -n scripts/build-app.sh scripts/make-dmg.sh scripts/verify-release.sh scripts/install-and-launch-test.sh` — passed.
- `scripts/build-app.sh` — exited 0 and built `build/ContainerDesk.app` as arm64 Release. Its ad-hoc signature has no hardened-runtime flag.
- `scripts/make-dmg.sh "$PWD/build/ContainerDesk.app" 1.0.0` — exited 0 and generated the DMG and SHA-256 sidecar.
- `scripts/verify-release.sh build/ContainerDesk-1.0.0-arm64.dmg` — exited 0; checksum and disk image valid; bundle ID `local.containerdesk`; minimum macOS `26.0`; arm64; artwork and Applications link valid; ad-hoc local-development signature; hardened runtime `no`; Gatekeeper rejected; no notarization ticket.
- `scripts/install-and-launch-test.sh build/ContainerDesk-1.0.0-arm64.dmg --install-root /private/tmp/containerdesk-t-d5-relaunch-smoke` — exited 0; verified executable launch from the temporary root and did not install or start the Runtime.
- `scripts/install-and-launch-test.sh build/ContainerDesk-1.0.0-arm64.dmg` — exited 0; verified executable launch from `/Applications/ContainerDesk.app` and did not install or start the Runtime.
- DMG SHA-256: `5de86eeea44bff3f419d290f3f6483218690b5ff4fcd1fd86bd391611416ff51`.
- `git diff --check` — passed.

The earlier `/Applications/ContainerDesk.app` was preserved at `/private/tmp/ContainerDesk-1.0.0-old-runtime-signature.app` before the corrected DMG was installed.

The corrected app now stays open and reached the real Onboarding install flow. The UI verified Apple's Runtime package signature and advanced past administrator authorization; the Runtime package is now installed. E-01 is still **in progress**: ContainerDesk is showing its first-System-start confirmation (“The Runtime is installed but not running. Start it now?”). The user has not yet answered that confirmation. Do not record E-01 as passed until the System start, verification, optional Compose step, dashboard, and post-install version check complete. The unsigned artifact remains local-development-only and is not publishable.
