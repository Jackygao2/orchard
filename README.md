# ContainerDesk

ContainerDesk is a native macOS app for managing containers with Apple's [`container`](https://github.com/apple/container) Runtime. It is built from a fork of [Orchard](https://github.com/andrew-waters/orchard), preserving Orchard's working XPC backend, Compose execution, Runtime installer, logs, terminal launcher and menu bar.

> **Development status:** ContainerDesk 1.0 is not a public release. The local DMG built by these scripts is ad-hoc signed, is rejected by Gatekeeper and is not notarized. Do not distribute it as a release build.

## What it does

ContainerDesk groups the inherited Orchard workflows around the tasks developers use most:

- Overview and container inspection, creation and lifecycle actions.
- Image pulls and builds.
- Volumes and host mounts.
- Networks and DNS.
- Container logs and Compose projects.
- Onboarding and Runtime settings.

Compose parsing and planning use the linked `andrew-waters/compose` Swift package. Compose support is not a promise of full Docker Compose compatibility: ContainerDesk reports unsupported settings and asks the user to review them before running a project. The optional `container compose` plugin is not required by the app.

Orchard's machines, Kubernetes clusters, AI models and sandboxes remain in the Advanced section. They are retained functionality, outside the current 1.0 acceptance scope.

## Runtime and platform

- Apple silicon (`arm64`) only.
- The app is linked to Apple's `container` Runtime 1.7.1. Apple `container` is the only Runtime; ContainerDesk does not use Docker Desktop, OrbStack or another engine.
- Onboarding can offer Apple's signed Runtime installer. ContainerDesk asks before the first System start and remembers the choice. Quitting the app does not stop workloads.
- Compose works in ContainerDesk without a CLI plugin. The optional community plugin is separately verified before installation for `container compose` terminal commands.
- The Release build sets `LSMinimumSystemVersion` to macOS 26.0. That build setting is not a support guarantee: no macOS version has completed the full ContainerDesk release acceptance matrix. The T-D5 build and unit-test run was performed on macOS 27.2.1 and did not complete that matrix.
- In-app update checks are disabled for 1.0.

## Installation

There is no public ContainerDesk release or notarized download yet. To build a local development copy, follow [docs/BUILDING.md](docs/BUILDING.md). The generated DMG can be opened and dragged into Applications for local testing, but its ad-hoc signature is not accepted by Gatekeeper.

## Limitations

- ContainerDesk manages Apple's `container` Runtime; it is not a Docker-compatible engine.
- Compose features unsupported by the linked Compose package are listed for review; they are not silently translated or ignored.
- Advanced Orchard destinations are retained but are not part of the completed 1.0 acceptance run.
- A locally built unsigned/ad-hoc DMG is for development only. Developer ID signing, notarization and the release verification environment remain release blockers.
- `THIRD_PARTY_NOTICES.md` is an initial notice. Its dependency-license inventory must be complete before distribution.

See [docs/RELEASING.md](docs/RELEASING.md) for the current release gates and the distinction between a local artifact and a publishable release.

## Credit and license

ContainerDesk is based on Orchard by Andrew Waters and contributors. Orchard's MIT license and copyright notice are retained in [LICENSE](LICENSE). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the current dependency notice and its completion status.
