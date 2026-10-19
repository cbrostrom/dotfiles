/** output-trim — compacts oversized tool results (ANSI strip, blank-line squeeze, head+tail keep) before they enter context. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Backstop for every tool, not just bash (pi-rtk-optimizer covers bash).
// Aligned with RTK's truncation ceiling so every path hits the same limit.
// Keep head (paths, structure) and tail (errors live there) with an explicit
// marker in between, so the cut stays readable to the model.
const MAX_RESULT_CHARS = 12_000;
const HEAD_KEEP = 9_000;
const TAIL_KEEP = 2_500;
const ANSI_RE = /\x1b\[[0-9;]*[A-Za-z]|\x1b\][^\x07]*(?:\x07|\x1b\\)/g;

function compactResultText(text: string): string | null {
	const out = text.replace(ANSI_RE, "").replace(/\n{3,}/g, "\n\n");
	if (out.length <= MAX_RESULT_CHARS) {
		return out === text ? null : out; // null = unchanged, skip rebuild
	}
	const trimmed = out.length - HEAD_KEEP - TAIL_KEEP;
	return (
		out.slice(0, HEAD_KEEP) +
		`\n\n[${trimmed} chars trimmed — head+tail kept; rerun narrower (offset/limit, filter) for the middle]\n\n` +
		out.slice(-TAIL_KEEP)
	);
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_result", (event) => {
		try {
			const content = event.content;
			if (!Array.isArray(content)) return;

			let changed = false;
			const nextContent = content.map((block) => {
				if (block && typeof block === "object" && "type" in block && block.type === "text") {
					const text = (block as { text?: string }).text ?? "";
					if (!text) return block;
					const compacted = compactResultText(text);
					if (compacted !== null) {
						changed = true;
						return { ...block, text: compacted };
					}
				}
				return block;
			});

			if (changed) return { content: nextContent };
		} catch {
			// Never let the safety net break a legitimate tool result.
		}
	});
}
