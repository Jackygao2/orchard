# Runtime acceptance scenarios — 2026-11-16 (in progress)

Environment: macOS 27.2.1 (26B131), arm64, Xcode 27.2 (27B52), ContainerDesk 1.0.0 local unsigned DMG, Apple `container` 1.7.1, Compose plugin 0.9.0. These are macOS 27 results only.

## E-02 — launch from `/Applications`

**Pass.** `scripts/install-and-launch-test.sh` installed the corrected DMG into `/Applications/ContainerDesk.app` and verified that the launched process came from that path. Exact command, artifact SHA-256 and result are in [32-runtime-signature-fix-2026-11-16.md](32-runtime-signature-fix-2026-11-16.md). The installed app was then relaunched after Runtime setup without showing Onboarding; the app exposed its main window and Runtime status `Running 1.7.1`.

## E-03 — Runtime already running

**Pass.** After E-01, the app was quit and relaunched with Apple `container` still running. Setup did not reappear. The restored Containers view appeared; Overview then showed `Running 1.7.1`, zero running/stopped containers and zero Compose projects. Evidence: [e03-relaunch-running-2026-11-16.png](e03-relaunch-running-2026-11-16.png), and the `container system status` output in [e01-2026-11-16.md](e01-2026-11-16.md).

## E-04 — Runtime stopped and recovered

**Pass on the empty Runtime.** ContainerDesk's Stop action moved the window to `Container is not currently runnning`; Start returned to Overview with `Running 1.7.1`. Screenshot of the stopped state: [e04-runtime-stopped-2026-11-16.png](e04-runtime-stopped-2026-11-16.png). No containers were running during the stop.

## E-05 — nginx start/stop, port and deletion

**Partial; host-port deviation.** `nginx:alpine` was run with `8080:80`, and ContainerDesk exposed Stop/Start plus the named Delete confirmation. Host port 8080 was already owned by a local `llama-server` process (`lsof` reported `127.0.0.1:8080`); a request there returned its `llama.cpp` 415 response. I did not stop or change that service. The test container was deleted, then recreated on unused port `8081:80`. ContainerDesk's `Open 8081 in Browser` action opened Safari at `localhost:8081`, showing “Welcome to nginx!”; the screenshot is [e05-nginx-8081-2026-11-16.png](e05-nginx-8081-2026-11-16.png). `container exec containerdesk-e05-nginx /bin/sh -c 'wget -S -O- http://127.0.0.1:80/'` returned HTTP 200 inside the container. `curl -I localhost:8081` reset the connection, even with host access; Safari successfully loaded the app-opened URL. Both disposable containers were deleted through ContainerDesk confirmation. Exact requested 8080/curl path remains unverified because of the pre-existing port owner.

## E-06 — pull and delete image

**Pass.** `container image pull alpine:latest` completed. ContainerDesk displayed `alpine:latest` (4.2 MB); Delete opened a confirmation naming `alpine`, and the image disappeared after confirmation. The nginx and Runtime system images were left intact.

## E-07 — failed image pull and retry

**Partial; corrected copy awaiting release-app retest.** In the installed app, pulling `docker.io/library/does-not-exist-containerdesk:latest` returned Docker Hub 401 and the sheet remained responsive with Retry. The original copy exposed the raw URL and status. In `task/t-c13-accessibility`, that response now maps to actionable text without the raw status; the added unit test passed in the full 719-test unit run, and the focused UI test passed 1/1 with Retry still usable. Logs: `/private/tmp/containerdesk-e07-full-unit-2026-11-16.log` and `/private/tmp/containerdesk-e07-ui-2026-11-16.log`. The installed `/Applications` build has not yet been rebuilt from the combined branches and retested, so do not mark E-07 Pass yet.

## E-18 — external Runtime disconnect

**Pass on the empty Runtime.** With ContainerDesk open and no containers running, `container system stop` stopped Apple services. ContainerDesk changed to its stopped/setup state; its Start action recovered to Overview with `Running 1.7.1`. Screenshot: [e18-runtime-disconnected-2026-11-16.png](e18-runtime-disconnected-2026-11-16.png). The exact elapsed time to the next observed state was not measured. No workload data was removed.

## E-08 — live logs, filter, pause, resume and export

**Partial.** Disposable `containerdesk-e08-logs` printed `ContainerDesk line N` once per second. The app showed the stream advancing from line 0 through line 53. Pause changed to Play and the visible contents stayed fixed for three seconds; Play resumed updates. Filtering `ContainerDesk line 5` produced 11 lines (5 and 50–59). Export wrote those 11 displayed lines to `/private/tmp/containerdesk-e08-filtered.log`; the copy in [e08-filtered-log-2026-11-16.txt](e08-filtered-log-2026-11-16.txt) has SHA-256 `bc5c4411d4501680e34abc59a1aebac52eb90a8fc4b8c36391614db1a20d9821`. It has 10 newline characters because the last record has no trailing newline. The app's Copy action was clicked, but a subsequent sandboxed `pbpaste | wc -l` returned 0, so live clipboard contents were not verified. The seeded copy UI test is recorded under T-C10; it does not replace the live check. The disposable container was stopped and deleted in ContainerDesk.

## E-09 — in-app command and external terminal

**Partial.** On disposable `containerdesk-e09-command`, ContainerDesk's Run Command sheet ran `uname -a` and displayed success with output `Linux containerdesk-e09-command 6.18.56 #1 SMP Fri Oct 16 18:41:09 UTC 2026 aarch64 Linux`. The Terminal (sh) action showed its first-use explanation and launched Terminal; `container exec containerdesk-e09-command ps -o pid,ppid,comm,args` showed an additional `sh` process. CUA refused inspection of the Terminal app window, so the terminal's displayed shell/output was not verified. The container was stopped and deleted through ContainerDesk.

## E-10 — Compose import, dry run, Up and service logs

**Pass on macOS 27.2.1 / Runtime 1.7.1 / Compose 0.9.0.** Imported `fixtures/web-db/compose.yaml`. The review showed services `db` and `web`, published port 8082 and named volume `pgdata`. Dry Run reported no changes and listed network, volume, image pull and service create/start steps. Up pulled `postgres:16-alpine`, created `web-db_default` and `web-db_pgdata`, and started `web-db-db` and `web-db-web`. ContainerDesk showed both services running, the network as `192.168.65.0/24`, and `web-db_pgdata` mounted. The web log showed nginx starting; the database log showed PostgreSQL 16.16 ready to accept connections and warned that the test fixture's `POSTGRES_HOST_AUTH_METHOD=trust` allows unauthenticated access from its private Compose network. The fixture publishes no database port and contains no credentials. Evidence: [e10-compose-running-2026-11-16.png](e10-compose-running-2026-11-16.png). The host port is 8082 because the user's existing `llama-server` owns 8080; `trust` is test-only.

## E-11 — PostgreSQL data across Down and Up

**Pass.** Before Down, ran:

```sh
container exec web-db-db psql -U postgres -d postgres -Atc "CREATE TABLE IF NOT EXISTS containerdesk_acceptance (id integer PRIMARY KEY, marker text); INSERT INTO containerdesk_acceptance VALUES (1, 'survives-down-up') ON CONFLICT (id) DO UPDATE SET marker = EXCLUDED.marker; SELECT marker FROM containerdesk_acceptance;"
```

The output ended with `survives-down-up`. Clicked ContainerDesk Down; the containers and network became Not created while the named `web-db_pgdata` volume remained listed as 39.9 MB and Not mounted. Clicked Up and both services returned to Running with the volume mounted. Then ran `container exec web-db-db psql -U postgres -d postgres -Atc "SELECT marker FROM containerdesk_acceptance WHERE id=1;"`; it returned `survives-down-up`. Screenshot: [e11-compose-after-up-2026-11-16.png](e11-compose-after-up-2026-11-16.png).

## E-12 — unsupported Compose review

**Pass for the import-review gate.** Opened `fixtures/unsupported/compose.yaml`. ContainerDesk reported `restart` at line 4, column 14 and `user` at line 5, column 11, with explanations and suggestions. `Add Anyway` was disabled while the behavioural-differences checkbox was clear, became enabled when checked, and disabled again when unchecked. Cancelled without importing or starting a service. Screenshot: [e12-unsupported-compose-2026-11-16.png](e12-unsupported-compose-2026-11-16.png). The UI gate is the import acknowledgement; the service Up action was not reached.

## E-13 — Remove Volumes confirmation

**Pending user confirmation; no removal performed.** ContainerDesk's confirmation explicitly named `web-db_pgdata — 79.8 MB` and warned that Down would permanently remove the volume and its data. The user has been asked at action time whether to delete this temporary acceptance volume. The dialog was cancelled while awaiting that answer; the volume remains mounted and both services remain running. Screenshot: [e13-remove-volume-confirmation-2026-11-16.png](e13-remove-volume-confirmation-2026-11-16.png).

## E-15 — Compose reconcile

**Pass.** Changed only the web published port in `fixtures/web-db/compose.yaml` from `8082:80` to `8083:80`, then used ContainerDesk Up. `container list --all --format json` showed `web-db-web` with host port 8083 and `startedDate` `2026-11-16T17:47:55Z`; `web-db-db` kept host port unset and `startedDate` `2026-11-16T17:45:50Z`. The database marker still returned `survives-down-up`. ContainerDesk showed both services Running and the changed port. Screenshot: [e15-reconcile-running-2026-11-16.png](e15-reconcile-running-2026-11-16.png).

## E-16 — quit keeps workloads

**Partial.** Tried Command-Q and the app menu's `Quit ContainerDesk` and `Quit and Keep Windows`; the ContainerDesk process and main window remained available in the CUA app inventory, so the app did not demonstrably quit. After those attempts, `container list --all --format json` still showed both `web-db-web` and `web-db-db` running and `container system status` reported 2 running containers. This confirms the workloads remained up during the attempts, but it does not establish the requested post-quit condition.

## E-19 — release DMG verification

**Partial for the current source; the inspected artifact itself verified.** Ran `scripts/verify-release.sh build/ContainerDesk-1.0.0-arm64.dmg` in the T-D7 worktree on 2026-11-16. The script exited 0, verified the SHA-256 sidecar and DMG checksums, app identity `local.containerdesk`, minimum macOS 26.0, arm64-only architecture, Applications link and checked-in background. It reported `Code signature: ad-hoc (local development only)`, `Hardened runtime: yes`, `App Gatekeeper assessment: rejected`, and `Notarization ticket stapled: no`. The artifact SHA-256 is `3cbaa9ec1c65b17b384c7df10e7582f0ca0c0d463663cf6caeac8e0e6e8b506b`. The DMG is timestamped 2026-11-15 and predates the latest source changes; it is not a verification of the final integrated candidate. The verifier also emitted Apple's deprecation warning for `hdiutil attach`.

## T-E1 — release-candidate automated tests

**Partial.** The current T-C13 source's full `Orchard` unit suite passed **719 tests in 18 suites**; log `/private/tmp/containerdesk-e07-full-unit-2026-11-16.log`, result bundle `/private/tmp/containerdesk-c13-derived/Logs/Test/Test-Orchard-2026.11.16_12-25-01--0500.xcresult`. The full UI command below completed with all **52 checked-in `OrchardUITests` passing**, including the updated image-pull error/retry test. The separate `OrchardUITestsLaunchTests` target timed out twice while XCTest queried the host application `com.grammarly.ProjectLlama.UpdateService`; one retry later passed, but the test run still exited 65 and reported 2 failures across 54 executions. Log: `/private/tmp/containerdesk-c13-full-ui-2026-11-16-latest.log`; result bundle: `/private/tmp/containerdesk-c13-derived/Logs/Test/Test-OrchardUITests-2026.11.16_12-54-18--0500.xcresult`.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project Orchard.xcodeproj -scheme OrchardUITests -destination 'platform=macOS' -derivedDataPath /private/tmp/containerdesk-c13-derived -clonedSourcePackagesDirPath /private/tmp/containerdesk-xcode-derived/SourcePackages CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

The automated checks are not a single release-candidate pass: the UI launch target fails on this host, and the DMG above predates the current source changes and is not an integrated artifact.

## Remaining limits

E-01 remains incomplete because this Mac retained Runtime data before setup and no full-flow recording was captured. E-05 and E-07 are partial as stated above. E-13 awaits the user's action-time approval to remove the disposable 79.8 MB test volume. E-14 would reinstall the Runtime package and has not been attempted while this test project is running. E-17 requires a deliberate Mac sleep/wake cycle and is not run. E-19 is not run. T-C13's full Accessibility Inspector audit is unresolved; VoiceOver walk-throughs were reported usable by the user, but the audit has outstanding product/platform findings. These results are macOS 27 only and do not establish macOS 26 support.
