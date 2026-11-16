# T-E1 — integrated-candidate automated results

Candidate source: merged T-C13 code, recorded as `efa59cf`; packaging-only correction and regression test at final candidate commit `fbb9dff`. The Swift app and UI-test sources did not change between those commits. Host: macOS 27.2.1 (26B131), arm64; Xcode 27.2 (27B52).

## Unit suite

Command run from the candidate worktree:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Orchard.xcodeproj -scheme Orchard -destination 'platform=macOS' -derivedDataPath /private/tmp/containerdesk-c13-derived -clonedSourcePackagesDirPath /private/tmp/containerdesk-xcode-derived/SourcePackages -packageCachePath /private/tmp/containerdesk-c13-package-cache -disablePackageRepositoryCache CODE_SIGNING_ALLOWED=NO
```

**Pass on final candidate commit `fbb9dff`:** 719 tests in 18 suites; `** TEST SUCCEEDED **`; test run 1.019 seconds. The Xcode result bundle is `/private/tmp/containerdesk-c13-derived/Logs/Test/Test-Orchard-2026.11.16_14-27-56--0500.xcresult`. The captured log is [e1-integrated-unit-2026-11-16.log](e1-integrated-unit-2026-11-16.log).

## App UI class

Command run from the candidate worktree:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Orchard.xcodeproj -scheme OrchardUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/containerdesk-c13-derived -clonedSourcePackagesDirPath /private/tmp/containerdesk-xcode-derived/SourcePackages -only-testing:OrchardUITests/OrchardUITests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

**Pass:** 52 tests, 0 failures; `** TEST SUCCEEDED **`; 562.924 seconds. This ran against the same Swift app/test tree later committed as `efa59cf`; final commit `fbb9dff` changed only packaging scripts and added a shell regression test. The Xcode result bundle is `/private/tmp/containerdesk-c13-derived/Logs/Test/Test-OrchardUITests-2026.11.16_13-51-54--0500.xcresult`. The log, including the command's `-only-testing` filter, is [e1-integrated-ui-class-2026-11-16.log](e1-integrated-ui-class-2026-11-16.log).

The complete `OrchardUITests` scheme has **not** passed as a whole. On final candidate `fbb9dff`, the isolated launch-test target command below exited 65. The first `testLaunch` attempt timed out because XCTest could not update or identify host application `com.grammarly.ProjectLlama.UpdateService`; its automatic retry passed, but Xcode reported 2 failures across 2 executions. The result bundle is `/private/tmp/containerdesk-c13-derived/Logs/Test/Test-OrchardUITests-2026.11.16_14-34-13--0500.xcresult`, and the captured log is [e1-integrated-launch-tests-2026-11-16.log](e1-integrated-launch-tests-2026-11-16.log). The full combined scheme was not rerun; T-E1 remains partial.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Orchard.xcodeproj -scheme OrchardUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/containerdesk-c13-derived -clonedSourcePackagesDirPath /private/tmp/containerdesk-xcode-derived/SourcePackages -only-testing:OrchardUITests/OrchardUITestsLaunchTests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

## Packaging regression and artifact

`scripts/tests/packaging-scripts-tests.sh` was run after the signing correction: all nine checks passed, including the unsigned-build assertion and `bash -n` for the four scripts. The exact output is [e1-packaging-tests-2026-11-16.log](e1-packaging-tests-2026-11-16.log). Before the correction, that added regression failed because the unsigned build passed `--options runtime` to `codesign`. Commit `fbb9dff` removes that option only from the ad-hoc local path; the Developer ID Release configuration remains hardened.

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build-app.sh` — exit 0; produced arm64 `build/ContainerDesk.app`. Xcode emitted warnings; the archive completed. Log: [e1-integrated-release-build-2026-11-16.log](e1-integrated-release-build-2026-11-16.log).
- `scripts/make-dmg.sh "$PWD/build/ContainerDesk.app" 1.0.0` — exit 0; produced `build/ContainerDesk-1.0.0-arm64.dmg` and checksum sidecar. Log: [e1-integrated-make-dmg-2026-11-16.log](e1-integrated-make-dmg-2026-11-16.log).
- `scripts/verify-release.sh build/ContainerDesk-1.0.0-arm64.dmg` — an unprivileged sandbox invocation exited 1 when `hdiutil attach` returned `Device not configured`; rerun with disk-image access exited 0. The second run verified checksum, bundle ID, minimum OS, arm64, Applications shortcut and background. It reported ad-hoc signature, Hardened Runtime `no`, Gatekeeper rejected and no stapled ticket. Full output: [e19-integrated-candidate-verification-2026-11-16.txt](e19-integrated-candidate-verification-2026-11-16.txt).
- SHA-256: `24ac82684e1808f17c3e564679da8608153b1033f439a758e2af8bcc13fde486`.

The candidate was not launched from the fresh DMG because the existing ContainerDesk process was running and `install-and-launch-test.sh` refuses to confuse it with the app it starts. The current artifact is not Developer ID signed, Gatekeeper accepted, notarized or macOS 26 tested. These checks do not constitute a public release.
