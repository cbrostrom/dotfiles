# Mac-only tools
# Available on macOS desktop (profile: desktop-full). Not present on server-headless.

## Browser Automation — agent-browser
Use `agent-browser` for web automation tasks. Only available on macOS.

Core workflow:
1. `agent-browser open <url>` — navigate to page
2. `agent-browser snapshot -i` — get interactive elements with refs (@e1, @e2, …)
3. `agent-browser click @e1` / `agent-browser fill @e2 "text"` — interact via refs
4. Re-snapshot after page changes

Run `agent-browser --help` for full command reference.

Trigger: web scraping, form filling, browser testing, UI automation.