#!/usr/bin/env python3
"""Apply the tracked Claude settings to ~/.claude/settings.json.

Usage: merge_settings.py <tracked.json> <settings.json> [--pull|--force|--check]

Tracked top-level keys replace the live values. Untracked live keys are kept (and listed).
Hooks owned by other installers (Paseo, aislop) are preserved from the live file; all other
hooks come from the tracked file. A snapshot of the last applied state (settings.json
sibling .settings.applied.json) detects live edits to tracked keys:
  default  stop and print the diff when drift is found
  --pull   copy drifted live values back into the tracked file
  --force  overwrite drift
  --check  report drift only (exit 1 on drift)
"""
import glob, json, os, shutil, sys, time

args = [a for a in sys.argv[1:] if not a.startswith("--")]
flags = {a for a in sys.argv[1:] if a.startswith("--")}
tracked_path, settings_path = args
snap_path = os.path.join(os.path.dirname(settings_path), ".settings.applied.json")
home = os.path.expanduser("~")

tracked = json.loads(open(tracked_path).read().replace("${HOME}", home))
cur = json.load(open(settings_path)) if os.path.exists(settings_path) else {}
snap = json.load(open(snap_path)) if os.path.exists(snap_path) else None


def foreign(cmd):
    return "PASEO_TERMINAL_ID" in cmd or "paseo hooks" in cmd or "aislop hook" in cmd


def split_hooks(h):
    """Return live hooks that belong to other installers, grouped by event/matcher."""
    out = {}
    for ev, groups in (h or {}).items():
        for g in groups:
            keep = [x for x in g.get("hooks", []) if foreign(x.get("command", ""))]
            if keep:
                out.setdefault(ev, []).append({**{k: v for k, v in g.items() if k != "hooks"}, "hooks": keep})
    return out


def apply(live):
    new = dict(live)
    for k, v in tracked.items():
        new[k] = json.loads(json.dumps(v))
    kept = split_hooks(live.get("hooks"))
    hooks = new.setdefault("hooks", {})
    for ev, groups in kept.items():
        evl = hooks.setdefault(ev, [])
        for g in groups:
            m = next((x for x in evl if x.get("matcher", "") == g.get("matcher", "")), None)
            if m is None:
                evl.insert(0, g)
            else:
                m["hooks"] = g["hooks"] + m["hooks"]
    return new


def norm_hooks(s):
    """Tracked-key view of a settings dict, with foreign hooks stripped."""
    d = {k: s.get(k) for k in tracked}
    if "hooks" in d:
        h = {}
        for ev, groups in (d["hooks"] or {}).items():
            gs = []
            for g in groups:
                keep = [x for x in g.get("hooks", []) if not foreign(x.get("command", ""))]
                if keep:
                    gs.append({**g, "hooks": keep})
            if gs:
                h[ev] = gs
        d["hooks"] = h
    return d


drift = {}
if snap is not None:
    a, b = norm_hooks(snap), norm_hooks(cur)
    drift = {k: (a[k], b[k]) for k in tracked if a[k] != b[k]}
    # Keys that never existed in the snapshot and match tracked are not drift.

if drift and "--force" not in flags:
    print("Live Claude settings changed since the last apply:")
    for k, (old, new) in drift.items():
        print(f"  {k}:\n    applied: {json.dumps(old)[:200]}\n    live:    {json.dumps(new)[:200]}")
    if "--pull" in flags:
        raw = json.load(open(tracked_path))
        for k in drift:
            raw[k] = cur[k]
        with open(tracked_path, "w") as f:
            json.dump(raw, f, indent=2)
            f.write("\n")
        print("Pulled live values into", tracked_path, "(review and commit; ${HOME} paths may need restoring)")
        sys.exit(0)
    print("Re-run with --pull to keep them in dotfiles or --force to overwrite.")
    sys.exit(1)
if "--check" in flags:
    print("no drift")
    sys.exit(0)

new = apply(cur)
untracked = sorted(k for k in cur if k not in tracked and k != "hooks")
if untracked:
    print("Untracked live keys kept:", ", ".join(untracked))
if cur:
    shutil.copy2(settings_path, f"{settings_path}.bak-claude-work-{time.strftime('%Y%m%d-%H%M%S')}")
    for old in sorted(glob.glob(f"{settings_path}.bak-claude-work-*"))[:-2]:
        os.remove(old)
with open(settings_path, "w") as f:
    json.dump(new, f, indent=2)
    f.write("\n")
with open(snap_path, "w") as f:
    json.dump(new, f, indent=2)
    f.write("\n")
