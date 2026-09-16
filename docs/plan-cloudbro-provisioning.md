# Cloudbro provisioning — implemented

## Status: done (pending commit + cloudbro pull/rerun)

## Root cause

Four failures, three unprovisioned tools + one stale node_modules:

1. **higgins ENOENT** — no Linux binary and no install step. Source (stdlib-only
   Python, `python3 -m higgins.cli`) is in the repo at `higgins/`.
2. **deja ENOENT** — binary-only tool, not in brew; Mac binary came from
   GitHub releases at `vshulcz/deja-vu` (Linux tarballs exist: amd64/arm64).
3. **rtk missing** — Mac symlink → `/opt/homebrew/bin/rtk`. Source:
   `github.com/rtk-ai/rtk` (v0.49.0, Linux tarballs: x86_64-musl, aarch64-gnu).
4. **file-search extension** — `setup/pi.sh` skips `npm ci` when
   `node_modules` exists; macOS-built modules broke on Linux
   (`@effect/platform-node` missing).

## Fix plan (cloudbro profile)

1. ✅ `setup/pi.sh`: platform-stamp `node_modules` — reinstall when stamp
   mismatches current platform, not just when the dir is missing.
2. ✅ New `scripts/install/higgins.sh`: venv at
   `~/.local/share/higgins-venv`, wrapper `~/.local/bin/higgins`
   (`python3 -m higgins.cli`, PYTHONPATH → dotfiles `higgins/`).
   Verified on macOS: CLI responds.
3. ✅ New `scripts/install/rtk.sh`: brew-aware on macOS; release tarball for
   `$uname_m` → `~/.local/bin/rtk` (idempotent, pin via `RTK_VERSION`).
4. ✅ New `scripts/install/deja.sh`: release tarball → `~/.local/bin/deja`
   (idempotent, pin via `DEJA_VERSION`).
5. ✅ `install.sh` cloudbro case: calls the three installers before
   npm-globals/pi setup.
6. Optional follow-up: wire `higgins.sh` into the macos/linux/wsl profiles
   so the manual Mac binary stays replaced.

## Remaining steps for cloudbro

1. Commit + push these changes from the Mac (or pull the branch).
2. On cloudbro: `git -C ~/dotfiles pull`, then `./install.sh cloudbro`.
3. Verify: `higgins status`, `deja --version`, `rtk --version`, and pi
   starts without MCP/extension errors.

## Sources

- rtk: `https://github.com/rtk-ai/rtk/releases/download/v<ver>/rtk-<target>.tar.gz`
- deja: `https://github.com/vshulcz/deja-vu/releases/download/v<ver>/deja-vu_<ver>_linux_<arch>.tar.gz`
- higgins: repo-local Python source, no build needed
