# Pi settings synchronization

Pi owns mutable runtime settings at `~/.pi/agent/settings.json`. The repository
stores only the portable baseline at `setup/pi/settings.base.json`.

Apply the baseline and host model policy:

```sh
./setup/pi.sh
```

Promote portable runtime changes back to the baseline:

```sh
pi-sync-settings
git diff -- setup/pi/settings.base.json
```

The sync command excludes runtime identity fields. Review its diff before
committing. Authentication, sessions, caches, usage data, and host resolution
remain local under `~/.pi/agent/`.
