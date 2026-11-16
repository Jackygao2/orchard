#!/usr/bin/env python3
"""Generate bundled notices from the exact SwiftPM-resolved source revisions."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOLVED = ROOT / "Orchard.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
OUTPUTS = (ROOT / "THIRD_PARTY_NOTICES.md", ROOT / "Orchard/Resources/THIRD_PARTY_NOTICES.txt")
NAMES = {"license", "license.txt", "license.md", "licence", "licence.txt", "licence.md", "copying", "copying.txt", "notice", "notice.txt", "notice.md", "notices.txt", "notices.md"}
LICENSES = {name for name in NAMES if name.startswith(("licen", "licenc"))}


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def generate(checkouts):
    pins = json.loads(RESOLVED.read_text(encoding="utf-8"))["pins"]
    dirs = {p.name.lower(): p for p in checkouts.iterdir() if p.is_dir()}
    lines = ["# ContainerDesk third-party notices\n", "Generated from Package.resolved and the exact checked-out source revisions.\n", "## Orchard (upstream application)\n", (ROOT / "LICENSE").read_text(encoding="utf-8").rstrip() + "\n"]
    for pin in sorted(pins, key=lambda x: x["identity"]):
        name = pin["identity"]
        repo = dirs.get(name.lower())
        if repo is None:
            raise ValueError(f"Missing checkout: {name}")
        revision = pin["state"]["revision"]
        head = git(repo, "rev-parse", "HEAD").decode().strip()
        if head != revision:
            raise ValueError(f"Checkout revision does not match Package.resolved: {name}")
        files = git(repo, "ls-tree", "-r", "--name-only", revision).decode().splitlines()
        selected = sorted((f for f in files if Path(f).name.lower() in NAMES), key=str.lower)
        if not any("/" not in f and f.lower() in LICENSES for f in selected):
            raise ValueError(f"No root licence file for {name}; record and investigate the missing evidence")
        version = pin["state"].get("version", revision)
        lines.append(f"\n## {name} {version}\n\nSource: {pin['location']}\nRevision: {revision}\n")
        for filename in selected:
            content = git(repo, "show", f"{revision}:{filename}").decode("utf-8")
            # Strip trailing whitespace only, preserving all legal text.
            content = "\n".join(line.rstrip() for line in content.splitlines())
            lines.append(f"\n### {filename}\n\n{content.rstrip()}\n")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkouts", required=True, type=Path, help="SwiftPM SourcePackages/checkouts directory")
    parser.add_argument("--check", action="store_true", help="Fail if generated notices are not current")
    args = parser.parse_args()
    try:
        text = generate(args.checkouts)
        for output in OUTPUTS:
            if args.check:
                if not output.exists() or output.read_text(encoding="utf-8") != text:
                    raise ValueError(f"Generated notices are missing or stale: {output.relative_to(ROOT)}")
            else:
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_text(text, encoding="utf-8")
        print(f"{'Verified' if args.check else 'Generated'} notices for {len(json.loads(RESOLVED.read_text())['pins'])} resolved packages")
    except (OSError, ValueError, subprocess.CalledProcessError, UnicodeError) as error:
        print(f"Notice generation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
