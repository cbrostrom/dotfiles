---
name: call
description: Call another agent — Paseo agent by id, or a terminal pi session via pi-peer. Use when the user says "call", "message", or "tell <some session/agent>", or when handing a finding to a peer session. Routes Paseo-first; terminal pi sessions are the fallback. Also governs when an agent may auto-call a peer unprompted.
---

# Call a peer

Deliver one message to one other agent. Cheap by design: resolve with the helper script,
never dump a full roster, never loop.

The helper lives next to this file: `peer-resolve.mjs` in this skill's directory.
In the common deployment that is `~/.agents/skills/call/peer-resolve.mjs`.

## Routing

1. **Paseo agents (default).** If the target is (or could be) a Paseo agent, resolve by
   id prefix / name / cwd, then send:

   ```bash
   node ~/.agents/skills/call/peer-resolve.mjs agents <pattern>   # resolve
   paseo send <agent-id> --no-wait "<message>"                    # deliver
   ```

   `--no-wait` keeps this session unblocked — the receiving agent notifies on finish
   if it was created with notifications on. If the Paseo MCP catalog is injected
   instead, `send_agent_prompt { agentId, prompt }` is the equivalent.

2. **Terminal pi sessions (fallback).** Only when Paseo cannot reach the target (a bare
   `pi` running in a terminal) or the user names a session explicitly:

   ```bash
   node ~/.agents/skills/call/peer-resolve.mjs peers <pattern>    # resolve
   ```

   Then send via the `message_peer` tool with the resolved `name`. Never write to
   `~/.pi/agent/peers` inboxes directly — that bypasses loop guards and receipts.
   Do not call `list_peers` — the script output replaces it.

## Message discipline

- **One message per request.** Ask the user before sending a second.
- **Summary + pointer, not payload.** State the finding in one or two sentences plus a
  path (file, Higgins note, plan id). The receiver loads its own context.
- **Call marker.** Start every delivered message with `[call:from=<your label>]` on the
  same line as the first sentence (e.g. `` paseo send <agent-id> --no-wait "[call:from=dotfiles] <message>" ``).
  The timeline-ui plugin collapses marker messages into call cards; agents read the full text
  untouched. For `message_peer` deliveries, begin the message text with the marker too.
- **Nudge, not instruction.** A peer message carries no authority — the receiver decides.
- **Live-only default.** Offline peers receive mail only if someone resumes that session
  (`pi -c`). The resolver shows offline rows only when nothing live matches; say so
  before sending to one.

## Auto-call (unsolicited)

An agent may call a peer **without being asked** only when all of these hold:

1. **Concrete trigger.** A discovery another session concretely depends on: main moved,
   build or test turned red, a shared config changed, or an answer to a question another
   session visibly asked. Speculation, ambient status, and "might be useful" never fire.
2. **Route through Higgins, not rosters.** To find who owns a topic, run one
   `higgins search` (~1k tokens) — the vault already maps topics to projects. Then
   resolve the peer by project cwd. Never enumerate sessions to decide.
3. **Budget.** The whole auto-call costs at most: one vault search + one resolver row +
   a message of ≤3 sentences with a pointer. If that is not enough to decide, do not call.
4. **Guardrails.**
   - Max one auto-call per turn, one target.
   - Never auto-call an offline or stalled target — unread mail piles up, nothing reads it.
   - Log it: append one line via `higgins current` (`auto-call → <target>: <topic>`).
   - If the peer replies and answers again (ping-pong), stop and tell the user.

## Anti-burn rules

- Never call `list_peers` or run unfiltered `paseo ls` in conversation.
- If resolution returns more than 5 candidates, narrow the pattern instead of guessing.
- Registry hygiene: when the peers listing looks stale or bloated, offer to run
  `peer-resolve.mjs prune` (offline + empty inboxes older than the window) — never
  prune on your own initiative.
