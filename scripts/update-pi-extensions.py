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

  scripts/update-pi-extensions.py                    # report only (default)
  scripts/update-pi-extensions.py --update-all       # bump every outdated pin
  scripts/update-pi-extensions.py --update pi-subagents    # one extension
  scripts/update-pi-extensions.py --rehash           # re-capture npm hashes
                                                     # (e.g. after a nixpkgs
                                                     # nodejs/npm bump changed
                                                     # the node_modules tree)
  scripts/update-pi-extensions.py --check            # build every extension
  scripts/update-pi-extensions.py --yes              # no per-extension prompt
  scripts/update-pi-extensions.py --no-validate      # skip nix flake check

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
        "name": "pi-powerline",
        "repo": ("nicobailon", "pi-powerline-footer"),
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
        raise RuntimeError(
            f"nix flake prefetch failed for {owner}/{repo}@{tag}: {r.stderr.strip()[:200]}"
        )
    return json.loads(r.stdout)["hash"]


def anonymize(body):
    """Neutralize strings and comments WITHOUT changing their length, so
    byte offsets into the result still point at the same bytes of `body`.
    (re.sub would normally shrink matches, silently breaking the mapping.)
    """
    body = re.sub(
        r'"[^"]*"',
        lambda m: '"' + "x" * max(0, len(m.group(0)) - 2) + '"',
        body,
    )
    body = re.sub(
        r"#.*",
        lambda m: "#" + "x" * max(0, len(m.group(0)) - 1),
        body,
    )
    return body


def find_block(text, anchor):
    """Brace-balanced extent of the Nix construct starting at `anchor`.

    The anchor normally ends in the opening brace itself (e.g.
    `mcp-adapter = withDeps {`), so balance begins AT that brace — not at the
    next one (the src= fetchFromGitHub attrset lies between). Strings and
    comments are stripped before counting so tokens like
    `@juicesharp/${pname}` or `# ...` inside them cannot confuse the count.

    Handles the `{ params }: withDeps { ... }` arrow shape used by the rpiv
    helper: a balanced group followed by `:` (not `;`) continues into the
    applied expression.
    """
    i = text.find(anchor)
    if i < 0:
        die(f"cannot find anchor {anchor!r} in {PACKAGES} — file layout changed?")
    # Balance from the brace the anchor itself opens (search one char back so
    # an anchor ending in '{' finds it).
    last_end = i + len(anchor) - 1

    while True:
        j = text.find("{", last_end)
        if j < 0:
            die(f"no opening brace after anchor {anchor!r}")
        body = text[j:]
        clean = anonymize(body)
        depth = 0
        matched = None
        for k, ch in enumerate(clean):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    matched = k
                    break
                if depth < 0:
                    die(f"brace mismatch after anchor {anchor!r}")
        if matched is None:
            die(f"unbalanced braces after anchor {anchor!r}")
        end = j + matched + 1
        if end < len(text) and text[end] == ";":
            return (i, end + 1)
        if end < len(text) and text[end] == ":":  # `}:` lambda arrow
            last_end = end + 1
            continue
        return (i, end)


def regions_of(text):
    anchors = {
        "rpiv": "rpivExtension =",
        "pi-btw": "pi-btw = plain {",
        "pi-powerline": "pi-powerline = plain {",
        "pi-subagents": "pi-subagents = withDeps {",
        "pi-web-access": "pi-web-access = withDeps {",
        "rpiv-ask-user-question": "rpiv-ask-user-question = rpivExtension {",
        "rpiv-todo": "rpiv-todo = rpivExtension {",
    }
    return {name: find_block(text, anchor) for name, anchor in anchors.items()}


def parse_fields(block):
    def grab(pat):
        m = re.search(pat, block)
        return m.group(1) if m else None

    return {
        "version": grab(r'version = "([^"]+)"'),
        "tag": grab(r'tag = "([^"]+)"'),
        "hash": grab(r'hash = "(sha256-[^"]+)"'),
        "npmHash": grab(r'npmHash = "(sha256-[^"]+)"'),
    }


def edit_region(text, region, field, old_val, new_val):
    """Replace `field = "old_val"` inside one region; fail if the assignment
    is not unique within it."""
    if old_val == new_val:
        return text
    s, e = region
    seg = text[s:e]
    old = f'{field} = "{old_val}"'
    new = f'{field} = "{new_val}"'
    n = seg.count(old)
    if n == 0:
        die(f"{field}: {old!r} not found in region (already applied?)")
    if n > 1:
        die(f"{field}: {old!r} is not unique within its region")
    return text[:s] + seg.replace(old, new) + text[e:]


def capture_npm_hash(text, region_name):
    """Set npmHash to fakeHash, build, read the real hash from nix's error,
    write it back, and confirm. Restores the previous value on failure."""
    regions = regions_of(text)
    region = regions[region_name]
    old = parse_fields(text[region[0] : region[1]])["npmHash"]
    if old is None:
        die(f"{region_name}: no npmHash field to capture")
    backup = text
    try:
        text = edit_region(text, regions[region_name], "npmHash", old, FAKE_HASH)
        with open(PACKAGES, "w") as f:
            f.write(text)
        print(f"  {region_name}: npmHash -> {FAKE_HASH[:12]}… (capturing)")
        try:
            r = run(["nix", "build", "--no-link", f".#{region_name}"], timeout=1800)
        except subprocess.TimeoutExpired:
            die(f"{region_name}: nix build timed out during npm hash capture")
        got = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", r.stderr)
        if got is None:
            print(r.stdout[-2000:], file=sys.stderr)
            print(r.stderr[-2000:], file=sys.stderr)
            die(f"{region_name}: no 'got:' hash in nix error output (see above)")
        real = got.group(1)
        regions = regions_of(text)
        text = edit_region(text, regions[region_name], "npmHash", FAKE_HASH, real)
        with open(PACKAGES, "w") as f:
            f.write(text)
        print(f"  {region_name}: npmHash -> {real}")
        r = run(["nix", "build", "--no-link", f".#{region_name}"], timeout=1800)
        if r.returncode != 0:
            print(r.stderr[-2000:], file=sys.stderr)
            die(f"{region_name}: nix build failed even with captured hash")
        return text
    except BaseException:
        with open(PACKAGES, "w") as f:
            f.write(backup)
        raise


def capture_ext(text, ext):
    """Capture npm hashes for one extension (children for the rpiv monorepo)."""
    for region_name in ext.get("children", [ext["name"]]):
        regions = regions_of(text)
        if parse_fields(text[regions[region_name][0] : regions[region_name][1]])["npmHash"] is None:
            continue
        print(f"  capturing npmHash for {region_name}…")
        text = capture_npm_hash(text, region_name)
    return text


def version_tuple(v):
    return tuple(int(p) if p.isdigit() else p for p in re.split(r"[.-]", v.lstrip("v")))


def main():
    ap = argparse.ArgumentParser(
        description="Update pinned pi extensions in pi/packages.nix"
    )
    ap.add_argument("--update", action="append", metavar="NAME",
                    help="update this extension (repeatable)")
    ap.add_argument("--update-all", action="store_true",
                    help="update every outdated extension")
    ap.add_argument("--rehash", action="store_true",
                    help="re-capture npm hashes for all extension with deps "
                         "(no version changes)")
    ap.add_argument("--yes", "-y", action="store_true",
                    help="skip per-extension confirmation")
    ap.add_argument("--check", action="store_true",
                    help="build every extension to verify pins (no updates)")
    ap.add_argument("--no-validate", action="store_true",
                    help="skip nix flake check at the end")
    args = ap.parse_args()

    if not os.path.exists(os.path.join(REPO_ROOT, "flake.nix")) or not os.path.exists(PACKAGES):
        die("run this from the repository root (needs flake.nix and pi/packages.nix)")

    known = {e["name"] for e in EXTENSIONS} | {c for e in EXTENSIONS for c in e.get("children", [])}
    wanted = set(args.update or [])
    if args.update_all:
        wanted = {e["name"] for e in EXTENSIONS}
    for w in wanted:
        if w not in known:
            die(f"unknown extension {w!r}; known: " + ", ".join(sorted(known)))

    text = open(PACKAGES).read()
    regions = regions_of(text)

    # --- report -----------------------------------------------------------
    print("checking latest releases (gh api)…\n")
    outdated = []
    for ext in EXTENSIONS:
        owner, repo = ext["repo"]
        name = ext["name"]
        try:
            latest = latest_tag(owner, repo)
        except RuntimeError as e:
            print(f"  {name:26s} ✗ {e}")
            continue
        current = parse_fields(text[regions[name][0] : regions[name][1]])["version"] or "?"
        vers = re.sub(r"^v", "", latest)
        if current == vers:
            print(f"  {name:26s} ok    {current}")
        else:
            print(f"  {name:26s} update {current} -> {vers}  (tag {latest})")
            outdated.append((name, {"version_old": current, "version_new": vers}))

    if not outdated:
        print("\nall extensions up to date.")

    # --- --check ----------------------------------------------------------
    if args.check:
        print("\nverifying pins by building each extension…")
        for ext in EXTENSIONS:
            for name in ext.get("children", [ext["name"]]):
                r = run(["nix", "build", "--no-link", f".#{name}"], timeout=1800)
                print(f"  {name:26s} {'ok' if r.returncode == 0 else 'FAILED'}")
        sys.exit(0)

    # --- --rehash ---------------------------------------------------------
    if args.rehash:
        print("\nre-capturing npm hashes…")
        for ext in EXTENSIONS:
            if ext.get("deps"):
                text = capture_ext(text, ext)
        if not args.no_validate:
            _validate()
        print("\ndone. Review the diff, then activate:\n"
              "  git diff pi/packages.nix\n"
              "  sudo nixos-rebuild switch --flake .#nixos --accept-flake-config")
        return

    # --- select -----------------------------------------------------------
    child_names = {c for e in EXTENSIONS for c in e.get("children", [])}
    todo = {n: d for n, d in outdated if n in wanted}
    if wanted & child_names:  # --update rpiv-* maps onto the shared rpiv pin
        for n, d in outdated:
            if n == "rpiv":
                todo["rpiv"] = d
    if not todo:
        if wanted:
            print("\nselected extensions are already up to date.")
        else:
            print("\nnothing to update (pass --update-all or --update <name> to apply).")
        return

    # --- apply ------------------------------------------------------------
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

        print(f"  prefetching source for {repo}@{tag}…")
        try:
            new_hash = prefetch_src_hash(owner, repo, tag)
        except RuntimeError as e:
            print(f"  ✗ {e}")
            continue
        regions = regions_of(text)
        r = regions[name]
        text = edit_region(text, r, "version", d["version_old"], vers)
        text = edit_region(text, r, "tag", parse_fields(text[r[0]:r[1]])["tag"], tag)
        text = edit_region(text, r, "hash", parse_fields(text[r[0]:r[1]])["hash"], new_hash)
        with open(PACKAGES, "w") as f:
            f.write(text)

        if ext.get("deps"):
            text = capture_ext(text, ext)

    # --- validate ---------------------------------------------------------
    if not args.no_validate:
        _validate()

    print("\ndone. Review the diff, then activate:\n"
          "  git diff pi/packages.nix\n"
          "  sudo nixos-rebuild switch --flake .#nixos --accept-flake-config\n"
          "  (extension pins are not flake inputs — flake inputs themselves are still updated\n"
          "   one at a time with `nix flake update <input>`, see README 'Updating inputs'.)")


def _validate():
    print("\nvalidating: git add + nix flake check…")
    run(["git", "add", "pi/packages.nix"])
    r = run(["nix", "flake", "check"], timeout=1800)
    if r.returncode != 0:
        print(r.stdout[-3000:], file=sys.stderr)
        print(r.stderr[-3000:], file=sys.stderr)
        die("nix flake check failed")
    print("  ok")


if __name__ == "__main__":
    main()