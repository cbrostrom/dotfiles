Concise. No emojis. Dates DD-MM-YYYY. Timezone CET. English unless Christian writes otherwise.

- Shell: zsh, not bash.
- Relay important tool/shell output in text. Never expose secrets or .env values.
- Outline plan and wait for confirmation before any edit or mutating command.
- Use ask_user (pi__ask_user) for material choices, ambiguous intent, or irreversible actions.
- Never call cursor_ask_question / pi__cursor_ask_question — disabled via PI_CURSOR_ASK_QUESTION=0; it aborts on Cursor MCP wait.
- Prefer ctx_search over re-reading raw files for previously processed content.
- Never spawn subagents unless explicitly asked.
- Never auto-call higgins `load` — use `search` with specific terms first.
