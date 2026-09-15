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

/** PI output-style blocks: **→ Lead-in.** body (blank-line separated). */
export function parseAttentionBlocks(text: string): ParsedAttentionMessage | null {
  if (!text.includes("**→")) return null;

  const paragraphs = text.split(/\n\n+/);
  const blocks: AttentionBlock[] = [];
  const introParts: string[] = [];
  const outroParts: string[] = [];
  let phase: "intro" | "blocks" | "outro" = "intro";

  for (const raw of paragraphs) {
    const para = raw.trim();
    if (!para) continue;

    const match = para.match(ATTENTION_HEAD_RE);
    if (match) {
      phase = "blocks";
      blocks.push({ title: match[1]!.trim(), body: match[2]!.trim() });
      continue;
    }

    if (phase === "intro") {
      introParts.push(para);
    } else if (phase === "blocks") {
      phase = "outro";
      outroParts.push(para);
    } else {
      outroParts.push(para);
    }
  }

  if (blocks.length === 0) return null;

  return {
    intro: introParts.length > 0 ? introParts.join("\n\n") : null,
    blocks,
    outro: outroParts.length > 0 ? outroParts.join("\n\n") : null,
  };
}
