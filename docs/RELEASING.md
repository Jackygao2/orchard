# ContainerDesk release process

## Current status

ContainerDesk 1.0 is not ready for public distribution. T-E1 built and verified an integrated unsigned-development artifact, not a publishable release. The current candidate DMG reported:

- `arm64`, bundle ID `local.containerdesk`, minimum macOS `26.0`.
- A valid ad-hoc signature without hardened runtime. A no-Team-ID local build cannot load the separately signed Sparkle framework under hardened-runtime library validation.
- Gatekeeper rejected the app; no notarization ticket was stapled.
- The checksum and disk-image verification passed. A prior corrected build launched from a temporary install root and `/Applications`; the integrated candidate DMG was not launch-tested because another ContainerDesk process was already running.

The build and launch checks were on macOS 27.2.1 with Xcode 27.2. The Runtime was installed and started after the retained-data E-01 attempt; that attempt did not establish a clean install or record the complete setup flow. The acceptance report records current results and blockers. These checks do not establish support for macOS 27 or any other OS version. The release support list may name only macOS versions that pass the product acceptance scenarios.

## Local development artifacts

From the fork root, the local artifact path is:

```bash
scripts/build-app.sh
scripts/make-dmg.sh "$PWD/build/ContainerDesk.app" 1.0.0
scripts/verify-release.sh "$PWD/build/ContainerDesk-1.0.0-arm64.dmg"
scripts/install-and-launch-test.sh \
  "$PWD/build/ContainerDesk-1.0.0-arm64.dmg" \
  --install-root "$PWD/build/install-smoke"
```

Expected files are `build/ContainerDesk.app`, `build/ContainerDesk-1.0.0-arm64.dmg` and `build/ContainerDesk-1.0.0-arm64.dmg.sha256`. The `build/` directory is git-ignored. Do not attach this ad-hoc artifact to a public release or describe it as signed by Developer ID, Gatekeeper-approved, notarized or macOS-verified.

Use `scripts/verify-release.sh --require-publishable <dmg>` as the release gate after the signing and notarization path is available. That mode requires a valid Developer ID signature, hardened runtime, Gatekeeper acceptance and a stapled notarization ticket. It also assesses the DMG with Gatekeeper.

After building the app with `scripts/build-app.sh --signed`, creating the DMG, and configuring a local notarytool Keychain profile, run:

```bash
scripts/notarize.sh "$PWD/build/ContainerDesk-1.0.0-arm64.dmg"
```

The script requires the configured Developer ID identity and hardened app signature, submits the DMG, staples and validates the ticket, then runs strict release verification. It stops with a clear message when local credentials or profile are unavailable. The current Mac has no Developer ID identity or `Config/Signing.xcconfig`; no notarization was performed.

## Open release blockers

Resolve these before publishing:

1. **Developer ID and notarization credentials (`OPEN(14)`).** No signing identity or notarization profile is configured. Keep all credentials in the macOS keychain or approved CI secrets, never in the repository or logs.
2. **Release automation policy (`OPEN(16)`).** The choice of local-only scripts versus GitHub Actions, its triggers and credential handling are undecided. The local `scripts/notarize.sh` exists, but no CI workflow was added. Do not run Orchard's inherited release script or workflow as a substitute.
3. **Verification environment (`OPEN(15)`).** The acceptance environment decision is unresolved. E-01 was attempted on this Mac with retained Runtime data and is incomplete; the Runtime is now installed and running. Do not treat this machine as a clean E-01 environment. Resolve the environment decision before planning any clean-install acceptance run.
4. **Product acceptance.** E-01…E-20 have mixed Pass, Partial and Not run results in the acceptance plan. E-01 was attempted with retained Runtime data and lacks a full-flow recording; it is not a clean-install pass. E-14 and E-17 remain unrun, and several other scenarios remain partial.
5. **Full automated suite.** The 719-test unit suite and 52-test checked-in app UI class passed; the launch-test target exits 65 after a host application state timeout. See the integrated candidate's [T-E1 evidence](docs/release/evidence/e1-integrated-test-results-2026-11-16.md).
6. **Accessibility and baseline work.** T-C13's full audit and manual paths remain open. T-A3 and T-A4 have outstanding validation/performance work.

The README must continue to say there is no public release until these gates are satisfied. Do not claim a macOS version is supported solely because `LSMinimumSystemVersion` is set to 26.0.

## Release sequence after blockers resolve

1. Run the test and packaging checks in [BUILDING.md](BUILDING.md); record the exact Xcode version and results.
2. Build with the approved Developer ID identity using `scripts/build-app.sh --signed`.
3. Create the versioned DMG and SHA-256 sidecar using `scripts/make-dmg.sh`.
4. Resolve `OPEN(16)` before adding a release workflow. Use the local notarization script only after Developer ID signing and the Keychain profile are configured; do not skip notarization or claim success without a stapled ticket.
5. Run `scripts/verify-release.sh --require-publishable <dmg>` and `scripts/install-and-launch-test.sh <dmg>` under the acceptance environment. Store outputs and scenario evidence under the release evidence directory.
6. Complete scenarios E-01…E-20 and publish a release report with artifact names, SHA-256, signing and notarization state, tested OS versions and remaining blockers.
7. Publish only after the release report contains the required passing evidence and no unresolved public-release gate.

The current unsigned DMG and checksum were regenerated under the ignored `build/` directory in the T-D5 worktree after correcting its local signing mode. They are local development evidence, not repository release assets.
