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
/** Split-stream openers that are alone in a fragment: `**→`, `**→ **`, `**`. */
const BARE_MARKER_RE = /^\*\*(?:→\s*(?:\*\*)?)?$/;

/** A fragment that is only the opening of an attention header (or bold pair): the
 * stream got split (e.g. around a reasoning block) before the body/close landed in
 * this item. Rendering this as raw markdown leaks a literal `**→`/`**` card. */
export function isBareAttentionMarker(text: string): boolean {
  return BARE_MARKER_RE.test(text.trim());
}

/** Drop leading bare marker lines (`**→`, `**, `**) plus surrounding blank lines.
 * Used when a completed message carried a stray opener that no longer closes
 * (split stream) — the fragment content after the marker is what survives. */
export function stripLeadingBareMarker(text: string): string {
  const lines = text.split("\n");
  let first = 0;
  while (first < lines.length && !lines[first]!.trim()) first += 1;
  if (first >= lines.length || !isBareAttentionMarker(lines[first]!)) return text;
  let index = first + 1;
  while (index < lines.length && !lines[index]!.trim()) index += 1;
  return lines.slice(index).join("\n");
}

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

/** Client-side safety net: prose text that starts with a `**→` (or a bare `→`) header
 * becomes a block, so a `→` line can never leak out of the card grid as bare text.
 * Tolerates split-stream fragments: an unclosed bold opener (`**→ Both`, `→ Yes, that
 * works** More…`). */
export function attentionProseToBlock(text: string): { readonly title: string; readonly body: string } | null {
  const lines = text.split("\n");
  const first = lines[0]!.trim();
  // Accept `**→ Title.** body` plus a bare split-stream `→ Title …` opener.
  const headRest = first.match(/^(?:\*\*)?→\s*(.*)$/s)?.[1];
  if (headRest === undefined) return null;
  const close = headRest.indexOf("**");
  if (close >= 0) {
    const title = headRest
      .slice(0, close)
      .replace(/\.$/, "")
      .trim();
    if (!title) return null;
    const tail = headRest.slice(close + 2).trim();
    const body = [tail, ...lines.slice(1)].filter((line) => line.trim().length > 0).join("\n").trim();
    return { title, body };
  }
  // No closing bold on the first line (streaming fragment like `**→ Both`): the rest
  // of the first line up to the line break is the title candidate, later lines body.
  const title = headRest
    .replace(/\*{1,2}$/, "")
    .replace(/\.$/, "")
    .trim();
  if (!title) return null;
  const body = lines.slice(1).filter((line) => line.trim().length > 0).join("\n").trim();
  return { title, body };
}
