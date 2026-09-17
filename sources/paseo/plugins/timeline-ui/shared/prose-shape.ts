import { parseMarkdownDocument } from "./markdown-document.js";

/** Render shape for a completed plain-markdown fragment. Decides boxing by content
 * structure, not by stream-splitting accident:
 * - `headline`: short single plain sentence — bare semibold text, no card, no chips.
 * - `leadIn`: `**Lead-in:** body` paragraph — title-less card promoted to a titled
 *   attention block so the box keeps chrome but gains a real title row.
 * - `plain`: single paragraph with inline formatting — bare flowing text, no card.
 * - `rich`: anything structured (lists, headings, fences, tables) or multi-paragraph
 *   — ProseCard with copy chips. */
export type ProseShape =
  | { readonly kind: "headline"; readonly text: string }
  | { readonly kind: "leadIn"; readonly title: string; readonly body: string }
  | { readonly kind: "plain"; readonly text: string }
  | { readonly kind: "rich" };

const HEADLINE_MAX_CHARS = 90;
const LEAD_IN_TITLE_MAX_WORDS = 8;
const LEAD_IN_RE = /^\*\*([^*\n]+?)[:.!?]\*\*\s*/;

/** Exported so lead-in parsing rules and attention parsing stay observable in tests. */
export function parseLeadInBlock(text: string): { readonly title: string; readonly body: string } | null {
  const trimmed = text.trim();
  if (!trimmed || trimmed.includes("→")) return null;
  const match = LEAD_IN_RE.exec(trimmed);
  if (!match) return null;
  const title = match[1]!.trim();
  const body = trimmed.slice(match[0].length).trim();
  if (!title || !body) return null;
  if (title.split(/\s+/).length > LEAD_IN_TITLE_MAX_WORDS) return null;
  return { title, body };
}

function isStructuredMarkdown(text: string): boolean {
  return /(```|^\s*#{1,6}\s|^\s*(?:[-*+]|\d+\.)\s|^\s*>|\|)/m.test(text);
}

/** Classify a completed markdown fragment. Empty input falls through to `rich`
 * (the caller decides to render nothing before shape matters). */
export function classifyProseShape(text: string): ProseShape {
  const trimmed = text.trim();
  if (!trimmed) return { kind: "rich" };

  if (!isStructuredMarkdown(trimmed)) {
    const lead = parseLeadInBlock(trimmed);
    if (lead) {
      const blocks = parseMarkdownDocument(trimmed).filter((block) => block.kind !== "blank");
      if (blocks.length === 1 && blocks[0]!.kind === "paragraph") {
        return { kind: "leadIn", ...lead };
      }
      return { kind: "rich" };
    }

    // Multi-paragraph or blank-line separated: always boxed.
    if (/\n\s*\n/.test(trimmed)) return { kind: "rich" };

    const singleLine = !trimmed.includes("\n");
    const wholesaleBold = /^\*\*[^*]+\*\*$/.test(trimmed);
    const hasInlineFormatting = !wholesaleBold && /(\*\*|__|`|~~|→)/.test(trimmed);
    if (singleLine && !hasInlineFormatting && trimmed.length <= HEADLINE_MAX_CHARS) {
      return { kind: "headline", text: trimmed };
    }
    return { kind: "plain", text: trimmed };
  }

  return { kind: "rich" };
}
