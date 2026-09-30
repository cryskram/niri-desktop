#!/usr/bin/env python3
"""Update the pinned pi extension versions in pi/packages.nix.

Everything is now declarative: third-party pi extensions are pinned inside
pi/packages.nix (NOT flake inputs), so `nix flake update` never touches them.
This script:

  1. asks GitHub (via `gh api`) for the latest release tag of each extension
  2. compares it against the pinned version
  3. on request, rewrites the pin: version/tag, fetchFromGitHub source hash
     (nix flake prefetch), and the npm node_modules hash (fakeHash -> build ->
     capture "got:" from the standard nix error channel)
  4. validates with `nix flake check`

Usage (run from the repository root):

  scripts/update-pi-extensions.py                  # report only (default)
  scripts/update-pi-extensions.py --update-all     # bump every outdated pin
  scripts/update-pi-extensions.py --update pi-subagents   # one extension
  scripts/update-pi-extensions.py --yes            # no per-extension prompt
  scripts/update-pi-extensions.py --no-validate    # skip nix flake check
  scripts/update-pi-extensions.py --check          # clean-up build check

Requires: gh (authenticated), nix, python3 >= 3.8. Network for GitHub + nix.

After the update, activate with:
  sudo nixos-rebuild switch --flake .#nixos --accept-flake-config
"""

import argparse
import json
import os
import re
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGES = os.path.join(REPO_ROOT, "pi", "packages.nix")

FAKE_HASH = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# pname (attr used for `nix build .#<name>`) -> upstream repo + pin shape.
EXTENSIONS = [
    {
        "name": "mcp-adapter",
        "repo": ("nicobailon", "pi-mcp-adapter"),
        "deps": True,
    },
    # rpiv-mono monorepo: one shared version/tag/src for both extensions,
    # but each extension has its own npmHash.
    {
        "name": "rpiv",
        "repo": ("juicesharp", "rpiv-mono"),
        "deps": True,
        "children": ["rpiv-ask-user-question", "rpiv-todo"],
    },
    {
        "name": "pi-btw",
        "repo": ("dbachelder", "pi-btw"),
        "deps": False,
    },
    {
        "name": "zentui",
        "repo": ("lmilojevicc", "pi-zentui"),
        "deps": False,
    },
    {
        "name": "pi-subagents",
        "repo": ("nicobailon", "pi-subagents"),
        "deps": True,
    },
    {
        "name": "pi-web-access",
        "repo": ("nicobailon", "pi-web-access"),
        "deps": True,
    },
]


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def latest_tag(owner, repo):
    """Latest release tag via gh (authenticated, avoids rate limits).

    Some projects (rpiv-mono) publish tags without GitHub releases, so fall
    back to the tags endpoint (creation order, newest first) and take the
    first version-shaped tag.
    """
    r = run(["gh", "api", f"repos/{owner}/{repo}/releases/latest", "--jq", ".tag_name"])
    if r.returncode == 0 and r.stdout.strip():
        return r.stdout.strip()
    r = run(["gh", "api", f"repos/{owner}/{repo}/tags?per_page=20", "--jq", ".[].name"])
    if r.returncode != 0:
        raise RuntimeError(f"gh api failed for {owner}/{repo}: {r.stderr.strip()[:200]}")
    version_tags = [t for t in r.stdout.splitlines() if re.match(r"^v?\d+\.\d+", t)]
    if not version_tags:
        raise RuntimeError(f"{owner}/{repo}: no release and no version-shaped tags")
    return version_tags[0]


def prefetch_src_hash(owner, repo, tag):
    """fetchFromGitHub-style source hash for a tag (SRI sha256)."""
    r = run(["nix", "flake", "prefetch", "--json", f"github:{owner}/{repo}/{tag}"])
    if r.returncode != 0:
        raise RuntimeError(f"nix flake prefetch failed for {owner}/{repo}@{tag}: {r.stderr.strip()[:200]}")
    return json.loads(r.stdout)["hash"]


def parse_pin(path):
    """Extract current pinned values. Returns {name: block-strings} keyed by
    a stable anchor so edits can target each assignment with a uniqueness
    check (count==1) before rewriting."""
    text = open(path).read()
    pins = {}

    # Anchors: first line of each pin block, plus the rpiv function definition.
    anchors = {
        "mcp-adapter": "mcp-adapter = withDeps {",
        "rpiv": "rpivExtension =",
        "pi-btw": "pi-btw = plain {",
        "zentui": "zentui = plain {",
        "pi-subagents": "pi-subagents = withDeps {",
        "pi-web-access": "pi-web-access = withDeps {",
        "rpiv-ask-user-question": "rpiv-ask-user-question = rpivExtension {",
        "rpiv-todo": "rpiv-todo = rpivExtension {",
    }

    for name, anchor in anchors.items():
        i = text.find(anchor)
        if i < 0:
            die(f"cannot find anchor {anchor!r} in {PACKAGES} — file layout changed?")
        # Block: from anchor to the next `  };` at two-space indent (closes the
        # attribute/function) or end of the attrset.
        end = text.find("\n  };", i + len(anchor))
        if end < 0:
            end = text.find("\n}", i + len(anchor))
        block = text[i : end if end >= 0 else len(text)]
        fields = {}

        def grab(pat):
            m = re.search(pat, block)
            return m.group(1) if m else None

        fields["version"] = grab(r'version = "([^"]+)"')
        fields["tag"] = grab(r'tag = "([^"]+)"')
        fields["hash"] = grab(r'hash = "(sha256-[^"]+)"')
        fields["npmHash"] = grab(r'npmHash = "(sha256-[^"]+)"')
        if fields["version"] is None and fields["tag"] is None and fields["hash"] is None and fields["npmHash"] is None:
            die(f"no version/tag/hash/npmHash found in block anchored by {anchor!r}")
        pins[name] = fields
    return text, pins


def apply_edit(text, old, new):
    """Replace a full assignment string. Fails loudly if it is not unique."""
    n = text.count(old)
    if n == 0:
        die(f"pattern {old!r} not found (already applied?)")
    if n > 1:
        die(f"pattern {old!r} is not unique ({n} occurrences) — file layout changed?")
    return text.replace(old, new)


def edit_pin(text, block_name, field, old_value, new_value):
    if old_value == new_value:
        return text
    if old_value is None:
        die(f"{block_name}: no current {field} to edit")
    if field == "tag":
        old = f'tag = "{old_value}"'
        new = f'tag = "{new_value}"'
    elif field == "version":
        old = f'version = "{old_value}"'
        new = f'version = "{new_value}"'
    else:  # hash / npmHash
        old = f'{field} = "{old_value}"'
        new = f'{field} = "{new_value}"'
    return apply_edit(text, old, new)


def version_tuple(v):
    return tuple(int(p) if p.isdigit() else p for p in re.split(r"[.-]", v.lstrip("v")))


def capture_npm_hash(pkg_attr):
    """Set npmHash to fakeHash, build, read the real hash from nix's error."""
    text, pins = parse_pin(PACKAGES)
    old = pins[pkg_attr]["npmHash"]
    if old is None:
        die(f"{pkg_attr}: no npmHash field to capture")
    text = edit_pin(text, pkg_attr, "npmHash", old, FAKE_HASH)
    with open(PACKAGES, "w") as f:
        f.write(text)
    print(f"  {pkg_attr}: npmHash -> {FAKE_HASH[:12]}… (capturing)")
    try:
        r = run(["nix", "build", "--no-link", f".#{pkg_attr}"], timeout=1800)
    except subprocess.TimeoutExpired:
        die(f"{pkg_attr}: nix build timed out during npm hash capture")
    got = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", r.stderr)
    if got is None:
        # Sometimes the fixed-output derivation itself succeeds but a different
        # error surfaces; surface the build output for diagnosis.
        print(r.stdout[-2000:], file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        die(f"{pkg_attr}: no 'got:' hash in nix error output (see above)")
    real = got.group(1)
    print(f"  {pkg_attr}: npmHash -> {real}")
    _, pins = parse_pin(PACKAGES)
    text = edit_pin(open(PACKAGES).read(), pkg_attr, "npmHash", FAKE_HASH, real)
    with open(PACKAGES, "w") as f:
        f.write(text)
    # Confirm the pinned hash now resolves.
    r = run(["nix", "build", "--no-link", f".#{pkg_attr}"], timeout=1800)
    if r.returncode != 0:
        print(r.stderr[-2000:], file=sys.stderr)
        die(f"{pkg_attr}: nix build failed even with captured hash")
    return real


def main():
    ap = argparse.ArgumentParser(description="Update pinned pi extensions in pi/packages.nix")
    ap.add_argument("--update", action="append", metavar="NAME", help="update this extension (repeatable)")
    ap.add_argument("--update-all", action="store_true", help="update every outdated extension")
    ap.add_argument("--yes", "-y", action="store_true", help="skip per-extension confirmation")
    ap.add_argument("--check", action="store_true", help="build every extension to verify pins (no updates)")
    ap.add_argument("--no-validate", action="store_true", help="skip nix flake check at the end")
    args = ap.parse_args()

    if not os.path.exists(os.path.join(REPO_ROOT, "flake.nix")) or not os.path.exists(PACKAGES):
        die("run this from the repository root (needs flake.nix and pi/packages.nix)")

    wanted = set(args.update or [])
    if args.update_all:
        wanted = {e["name"] for e in EXTENSIONS}
    for w in wanted:
        if w not in {e["name"] for e in EXTENSIONS} and w not in {c for e in EXTENSIONS for c in e.get("children", [])}:
            die(f"unknown extension {w!r}; known: " + ", ".join(e["name"] for e in EXTENSIONS))

    text, pins = parse_pin(PACKAGES)

    # --- report -----------------------------------------------------------
    print(f"checking latest releases (gh api)…\n")
    outdated = []
    for ext in EXTENSIONS:
        owner, repo = ext["repo"]
        name = ext["name"]
        try:
            latest = latest_tag(owner, repo)
        except RuntimeError as e:
            print(f"  {name:26s} ✗ {e}")
            continue
        current = pins[name]["version"] or "?"
        vers = re.sub(r"^v", "", latest)
        if current == vers:
            print(f"  {name:26s} ok    {current}")
        else:
            print(f"  {name:26s} update {current} -> {vers}  (tag {latest})")
            if name == "rpiv":
                outdated.append(("rpiv", {"version_old": current, "version_new": vers}))
            else:
                outdated.append((name, {"version_old": current, "version_new": vers}))

    if not outdated:
        print("\nall extensions up to date.")

    # --- --check ----------------------------------------------------------
    if args.check:
        print("\nverifying pins by building each extension…")
        for ext in EXTENSIONS:
            name = ext["name"]
            if ext.get("children"):
                for child in ext["children"]:
                    r = run(["nix", "build", "--no-link", f".#{child}"], timeout=1800)
                    print(f"  {child:26s} {'ok' if r.returncode == 0 else 'FAILED'}")
            else:
                r = run(["nix", "build", "--no-link", f".#{name}"], timeout=1800)
                print(f"  {name:26s} {'ok' if r.returncode == 0 else 'FAILED'}")
        sys.exit(0)

    # --- select and apply -------------------------------------------------
    # --update rpiv-ask-user-question / rpiv-todo maps onto the shared rpiv
    # monorepo pin.
    child_names = {c for e in EXTENSIONS for c in e.get("children", [])}
    todo = {n: d for n, d in outdated if n in wanted}
    if wanted & child_names:
        for n, d in outdated:
            if n == "rpiv":
                todo["rpiv"] = d
    if not todo:
        if wanted:
            print("\nselected extensions are already up to date.")
        else:
            print("\nnothing to update (pass --update-all or --update <name> to apply).")
        return

    print()
    for ext in EXTENSIONS:
        name = ext["name"]
        if name not in todo:
            continue
        d = todo[name]
        owner, repo = ext["repo"]
        vers = d["version_new"]
        tag = "v" + vers
        print(f"updating {name}: {d['version_old']} -> {vers}")
        if not args.yes:
            ans = input("  apply? [y/N] ").strip().lower()
            if ans not in ("y", "yes"):
                print("  skipped")
                continue

        # 1. source hash
        print(f"  prefetching source for {repo}@{tag}…")
        try:
            new_hash = prefetch_src_hash(owner, repo, tag)
        except RuntimeError as e:
            print(f"  ✗ {e}")
            continue
        if name == "rpiv":
            blocks = ["rpiv"] + ext["children"]
            text = edit_pin(text, "rpiv", "version", d["version_old"], vers)
            text = edit_pin(text, "rpiv", "tag", pins["rpiv"]["tag"], tag)
            text = edit_pin(text, "rpiv", "hash", pins["rpiv"]["hash"], new_hash)
        else:
            blocks = [name]
            text = edit_pin(text, name, "version", d["version_old"], vers)
            text = edit_pin(text, name, "tag", pins[name]["tag"], tag)
            text = edit_pin(text, name, "hash", pins[name]["hash"], new_hash)
        with open(PACKAGES, "w") as f:
            f.write(text)

        # 2. npm hashes (only for extensions with dependencies)
        if ext.get("deps"):
            for child in blocks:
                # only blocks that carry their own npmHash
                _, pins_after = parse_pin(PACKAGES)
                if pins_after.get(child, {}).get("npmHash") is None:
                    continue
                print(f"  capturing npmHash for {child}…")
                capture_npm_hash(child)

    # --- validate ---------------------------------------------------------
    if not args.no_validate:
        print("\nvalidating: git add + nix flake check…")
        run(["git", "add", "pi/packages.nix"])
        r = run(["nix", "flake", "check"], timeout=1800)
        if r.returncode != 0:
            print(r.stdout[-3000:], file=sys.stderr)
            print(r.stderr[-3000:], file=sys.stderr)
            die("nix flake check failed")
        print("  ok")

    print(
        "\ndone. Review the diff, then activate:\n"
        "  git diff pi/packages.nix\n"
        "  sudo nixos-rebuild switch --flake .#nixos --accept-flake-config\n"
        f"  (extension pins are not flake inputs — flake inputs themselves are still updated\n"
        f"   one at a time with `nix flake update <input>`, see README 'Updating inputs'.)"
    )


if __name__ == "__main__":
    main()