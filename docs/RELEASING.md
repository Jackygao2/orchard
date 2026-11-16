# ContainerDesk release process

## Current status

ContainerDesk 1.0 is not ready for public distribution. T-D5 produced an unsigned-development artifact, not a release candidate. After correcting its local signing mode, the tested DMG reported:

- `arm64`, bundle ID `local.containerdesk`, minimum macOS `26.0`.
- A valid ad-hoc signature without hardened runtime. A no-Team-ID local build cannot load the separately signed Sparkle framework under hardened-runtime library validation.
- Gatekeeper rejected the app; no notarization ticket was stapled.
- The checksum and disk-image verification passed, and the corrected app launched from a temporary install root and `/Applications`.

The build and launch checks were on macOS 27.2.1 with Xcode 27.2. The E-01 first-launch walk is in progress; Runtime authorization and the full setup flow have not completed. These checks do not establish support for macOS 27 or any other OS version. The release support list may name only macOS versions that pass the product acceptance scenarios.

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

## Open release blockers

Resolve these before publishing:

1. **Developer ID and notarization credentials (`OPEN(14)`).** No signing identity or notarization profile is configured. Keep all credentials in the macOS keychain or approved CI secrets, never in the repository or logs.
2. **Release automation policy (`OPEN(16)`).** The choice of local-only scripts versus GitHub Actions, its triggers and credential handling are undecided. T-D6's `scripts/notarize.sh` and release automation have not been implemented. Do not run Orchard's inherited release script or workflow as a substitute.
3. **Verification environment (`OPEN(15)`).** The acceptance environment decision is unresolved. Run the project's ordered E-01…E-20 acceptance scenarios only after it is resolved; keep this Mac Runtime-free until E-01 is authorized and recorded.
4. **Product acceptance.** E-01 through E-20 remain `Not run` in the acceptance plan. A temporary-root launch check is not E-01 or E-02, which require the specified clean install conditions and evidence.
5. **Third-party license inventory.** `THIRD_PARTY_NOTICES.md` currently describes itself as an initial notice. Complete and review its dependency inventory before distribution.

The README must continue to say there is no public release until these gates are satisfied. Do not claim a macOS version is supported solely because `LSMinimumSystemVersion` is set to 26.0.

## Release sequence after blockers resolve

1. Run the test and packaging checks in [BUILDING.md](BUILDING.md); record the exact Xcode version and results.
2. Build with the approved Developer ID identity using `scripts/build-app.sh --signed`.
3. Create the versioned DMG and SHA-256 sidecar using `scripts/make-dmg.sh`.
4. Implement and use the notarization workflow selected by `OPEN(16)`. The current branch has no notarization script, so do not skip this step or claim notarization.
5. Run `scripts/verify-release.sh --require-publishable <dmg>` and `scripts/install-and-launch-test.sh <dmg>` under the acceptance environment. Store outputs and scenario evidence under the release evidence directory.
6. Complete scenarios E-01…E-20 and publish a release report with artifact names, SHA-256, signing and notarization state, tested OS versions and remaining blockers.
7. Publish only after the release report contains the required passing evidence and no unresolved public-release gate.

The current unsigned DMG and checksum were regenerated under the ignored `build/` directory in the T-D5 worktree after correcting its local signing mode. They are local development evidence, not repository release assets.
