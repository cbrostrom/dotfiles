# Mac-only tools
# Available on macOS desktop (profile: desktop-full). Not present on server-headless.

## Browser Automation — agent-browser
Use `agent-browser` for web automation tasks. Only available on macOS.

**Fetch/web-search first. Screenshots only for design review.**
Before opening any URL or taking a screenshot, prefer `fetch` or `websearch` to extract content. Agent-browser snapshots are expensive and slow — use them only when you need visual layout verification or design review.

Core workflow:
1. `agent-browser open <url>` — navigate to page
2. `agent-browser snapshot -i` — get interactive elements with refs (@e1, @e2, …)
3. `agent-browser click @e1` / `agent-browser fill @e2 "text"` — interact via refs
4. Re-snapshot after page changes

Run `agent-browser --help` for full command reference.

## CloudCLI — `/sh`
In CloudCLI chat (ai.local), run shell without prose: `/sh git status`, `/sh brew list --cask`.
Agent executes via Bash in the project workspace; output only. Same as asking here, but faster when you already know the command.