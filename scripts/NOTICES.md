# Regenerating third-party notices

Resolve the packages in `Orchard.xcodeproj` with Xcode, then run:

```sh
python3 scripts/generate-notices.py --checkouts /path/to/SourcePackages/checkouts
python3 scripts/generate-notices.py --checkouts /path/to/SourcePackages/checkouts --check
```

The generator checks each checkout against `Package.resolved`, reads root and nested
licence, copying and notice files from the pinned Git revision, and writes both
the repository notice and the resource bundled in the app. It normalizes trailing
whitespace. A missing checkout, mismatched revision or missing licence is an
error that must be investigated; do not invent or silently omit evidence.
