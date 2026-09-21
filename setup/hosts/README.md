# Host-specific setup hooks

Optional scripts named `<fleet-host>.sh` are run by
`scripts/system/fleet-update.sh` after the shared profile installation and
before `scripts/doctor.sh`.

Hooks must be safe to rerun and must fail non-zero when they cannot reach the
desired state. They receive:

- `DOTFILES_FLEET_HOST`: canonical name from `config/fleet-hosts.conf`
- `DOTFILES_PROFILE`: Stow/install profile assigned to that host
- the normal `HOME` and process environment of the remote SSH user

Use hooks only for tracked, non-secret host configuration that cannot be
expressed by a shared Stow profile. Keep credentials, runtime state, and local
overrides outside this repository. A hook may read those local files, but must
not replace or print them.

Example skeleton:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Compare before replacing so reruns are no-ops when already correct.
install -D -m 0644 \
    "$HOME/dotfiles/sources/hosts/$DOTFILES_FLEET_HOST/example.conf" \
    "$HOME/.config/example/example.conf"
```
