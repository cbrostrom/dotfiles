---
description: Extract PI sessions to Higgins vault for memory
argument-hint: "[--since YYYY-MM-DD] [--project name] [--dry-run] [--reindex]"
---
Run the session extraction script to capture session history into the Higgins vault:

```bash
bun run ~/.pi/agent/scripts/extract.ts ${@:---since today}
```

After extraction, report how many sessions were extracted and any errors.
