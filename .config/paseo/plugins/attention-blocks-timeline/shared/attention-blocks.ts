export interface AttentionBlock {
  title: string;
  body: string;
}

export type AttentionSegment =
  | { readonly kind: "prose"; readonly text: string }
  | { readonly kind: "block"; readonly title: string; readonly body: string };

export interface ParsedAttentionMessage {
  intro: string | null;
  blocks: AttentionBlock[];
  outro: string | null;
  segments: AttentionSegment[];
}

const ATTENTION_HEAD_RE = /^\*\*→\s*(.+?)\.?\*\*\s*(.*)$/s;
const ATTENTION_HEAD_LINE_RE = /^\*\*→\s/;

function parseBlockHeader(line: string): { title: string; body: string } | null {
  const match = line.match(ATTENTION_HEAD_RE);
  if (!match) return null;
  return { title: match[1]!.trim(), body: match[2]!.trim() };
}

/** Keep structured Markdown after a blank line attached to its attention block. */
function blankLineEndsBlockBody(lines: readonly string[], fromIndex: number): boolean {
  let index = fromIndex;
  while (index < lines.length && !lines[index]!.trim()) {
    index += 1;
  }
  if (index >= lines.length) return true;

  const next = lines[index]!.trim();
  if (ATTENTION_HEAD_LINE_RE.test(next)) return true;
  return !isStructuredMarkdownLine(lines[index]!);
}

function isStructuredMarkdownLine(line: string): boolean {
  const trimmed = line.trim();
  return /^(```|#{1,6}\s|>\s?|\|)/.test(trimmed) || /^\s*(\d+\.|[-*+])\s+/.test(line);
}

/** Standalone prose sandwiched between two **→ blocks on adjacent lines. */
function isStandaloneInterstitial(line: string, lines: readonly string[], fromIndex: number): boolean {
  if (isStructuredMarkdownLine(line)) return false;
  let index = fromIndex + 1;
  while (index < lines.length && !lines[index]!.trim()) {
    index += 1;
  }
  if (index >= lines.length) return false;
  return ATTENTION_HEAD_LINE_RE.test(lines[index]!.trim());
}

/**
 * Split into prose runs and block segments. Block bodies include continuation lines
 * until a blank line (outside code fences) or the next **→ header.
 */
function expandSegments(text: string): string[] {
  const lines = text.split("\n");
  const segments: string[] = [];
  let index = 0;

  while (index < lines.length) {
    while (index < lines.length && !lines[index]!.trim()) {
      index += 1;
    }
    if (index >= lines.length) break;

    const line = lines[index]!;
    if (ATTENTION_HEAD_LINE_RE.test(line.trim())) {
      const blockLines = [line.trimEnd()];
      const header = parseBlockHeader(line);
      const hasInlineBody = Boolean(header?.body);
      index += 1;
      let inFence = false;

      while (index < lines.length) {
        const next = lines[index]!;
        const trimmed = next.trim();

        if (!inFence) {
          if (!trimmed) {
            if (blankLineEndsBlockBody(lines, index + 1)) break;
          } else if (ATTENTION_HEAD_LINE_RE.test(trimmed)) {
            break;
          } else if (hasInlineBody && isStandaloneInterstitial(trimmed, lines, index)) {
            break;
          }
        }

        if (trimmed.startsWith("```")) {
          inFence = !inFence;
        }

        blockLines.push(next.trimEnd());
        index += 1;
      }

      segments.push(blockLines.join("\n"));
      continue;
    }

    const proseLines: string[] = [];
    while (index < lines.length) {
      const next = lines[index]!;
      if (!next.trim()) break;
      if (ATTENTION_HEAD_LINE_RE.test(next.trim())) break;
      proseLines.push(next.trimEnd());
      index += 1;
    }
    if (proseLines.length > 0) {
      segments.push(proseLines.join("\n"));
    }
  }

  return segments;
}

/** PI output-style blocks: **→ Lead-in.** body (blank-line or single-newline separated). */
export function parseAttentionBlocks(text: string): ParsedAttentionMessage | null {
  if (!text.includes("**→")) return null;

  const rawSegments = expandSegments(text);
  const segments: AttentionSegment[] = [];
  const blocks: AttentionBlock[] = [];
  const introParts: string[] = [];
  const outroParts: string[] = [];
  let seenBlock = false;

  for (const segment of rawSegments) {
    const header = parseBlockHeader(segment.split("\n")[0] ?? "");
    if (header && ATTENTION_HEAD_LINE_RE.test(segment.trim())) {
      seenBlock = true;
      const continuation = segment
        .split("\n")
        .slice(1)
        .join("\n")
        .trim();
      const body = [header.body, continuation].filter(Boolean).join("\n");
      const block = { title: header.title, body };
      blocks.push(block);
      segments.push({ kind: "block", ...block });
      continue;
    }

    segments.push({ kind: "prose", text: segment });
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
    segments,
  };
}
