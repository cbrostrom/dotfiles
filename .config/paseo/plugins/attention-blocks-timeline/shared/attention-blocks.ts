export interface AttentionBlock {
  title: string;
  body: string;
}

export interface ParsedAttentionMessage {
  intro: string | null;
  blocks: AttentionBlock[];
  outro: string | null;
}

const ATTENTION_HEAD_RE = /^\*\*→\s*(.+?)\.\*\*\s*(.*)$/s;

/** Split on blank lines, then split single-newline runs of **→ blocks. */
function expandParagraphs(text: string): string[] {
  const expanded: string[] = [];
  for (const paragraph of text.split(/\n\n+/)) {
    const trimmed = paragraph.trim();
    if (!trimmed) continue;
    const parts = trimmed.split(/\n(?=\*\*→\s)/);
    expanded.push(...parts.map((part) => part.trim()).filter(Boolean));
  }
  return expanded;
}

/** PI output-style blocks: **→ Lead-in.** body (blank-line or single-newline separated). */
export function parseAttentionBlocks(text: string): ParsedAttentionMessage | null {
  if (!text.includes("**→")) return null;

  const segments = expandParagraphs(text);
  const blocks: AttentionBlock[] = [];
  const introParts: string[] = [];
  const outroParts: string[] = [];
  let seenBlock = false;

  for (const segment of segments) {
    const match = segment.match(ATTENTION_HEAD_RE);
    if (match) {
      seenBlock = true;
      blocks.push({ title: match[1]!.trim(), body: match[2]!.trim() });
      continue;
    }

    if (!seenBlock) {
      introParts.push(segment);
    } else {
      outroParts.push(segment);
    }
  }

  if (blocks.length === 0) return null;

  return {
    intro: introParts.length > 0 ? introParts.join("\n\n") : null,
    blocks,
    outro: outroParts.length > 0 ? outroParts.join("\n\n") : null,
  };
}
