# Local signing configuration

Release builds target Apple silicon and enable the hardened runtime. With no local
signing configuration, Release builds are unsigned and intended for development.

To use an existing Developer ID Application identity, copy
`Signing.example.xcconfig` to `Signing.xcconfig`, set the team and identity on
your Mac, and build Release. `Signing.xcconfig` is git-ignored. Keep private keys,
notary credentials, and certificates out of this repository. Signing alone does
not notarize an app; the release workflow must also notarize and verify it.
