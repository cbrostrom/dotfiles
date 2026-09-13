export type InlineSegment =
  | { readonly kind: "text"; readonly value: string }
  | { readonly kind: "bold"; readonly value: string }
  | { readonly kind: "italic"; readonly value: string }
  | { readonly kind: "code"; readonly value: string }
  | { readonly kind: "link"; readonly label: string; readonly href: string };

export type MarkdownBlock =
  | { readonly kind: "prose"; readonly text: string }
  | { readonly kind: "code"; readonly text: string };

const INLINE_PATTERN =
  /(`[^`\n]+`|\*\*[^*\n]+\*\*|__[^_\n]+__|\*[^*\n]+\*|_[^_\n]+_|\[[^\]]+\]\([^)]+\))/g;

function parseLink(token: string): InlineSegment | null {
  const match = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(token);
  if (!match) return null;
  return { kind: "link", label: match[1]!, href: match[2]! };
}

function classifyInlineToken(token: string): InlineSegment {
  if (token.startsWith("`") && token.endsWith("`")) {
    return { kind: "code", value: token.slice(1, -1) };
  }
  if (token.startsWith("**") && token.endsWith("**")) {
    return { kind: "bold", value: token.slice(2, -2) };
  }
  if (token.startsWith("__") && token.endsWith("__")) {
    return { kind: "bold", value: token.slice(2, -2) };
  }
  if (token.startsWith("*") && token.endsWith("*")) {
    return { kind: "italic", value: token.slice(1, -1) };
  }
  if (token.startsWith("_") && token.endsWith("_")) {
    return { kind: "italic", value: token.slice(1, -1) };
  }
  const link = parseLink(token);
  if (link) return link;
  return { kind: "text", value: token };
}

/** Tokenize one line of inline markdown for React Native Text nesting. */
export function parseInlineMarkdown(text: string): readonly InlineSegment[] {
  if (!text) return [{ kind: "text", value: "" }];

  const segments: InlineSegment[] = [];
  let lastIndex = 0;
  INLINE_PATTERN.lastIndex = 0;

  for (const match of text.matchAll(INLINE_PATTERN)) {
    const token = match[0]!;
    const index = match.index ?? 0;
    if (index > lastIndex) {
      segments.push({ kind: "text", value: text.slice(lastIndex, index) });
    }
    segments.push(classifyInlineToken(token));
    lastIndex = index + token.length;
  }

  if (lastIndex < text.length) {
    segments.push({ kind: "text", value: text.slice(lastIndex) });
  }

  return segments.length > 0 ? segments : [{ kind: "text", value: text }];
}

/** Split prose and fenced code blocks. Unclosed fences render as code to EOF. */
export function splitMarkdownBlocks(text: string): readonly MarkdownBlock[] {
  const trimmed = text.trim();
  if (!trimmed) return [{ kind: "prose", text: "" }];

  const blocks: MarkdownBlock[] = [];
  const parts = trimmed.split(/```/);
  for (let index = 0; index < parts.length; index++) {
    const part = parts[index];
    if (part === undefined) continue;
    if (index % 2 === 0) {
      const prose = part.trim();
      if (prose) blocks.push({ kind: "prose", text: prose });
      continue;
    }
    const newline = part.indexOf("\n");
    const code = (newline === -1 ? part : part.slice(newline + 1)).trimEnd();
    if (code) blocks.push({ kind: "code", text: code });
  }

  return blocks.length > 0 ? blocks : [{ kind: "prose", text: trimmed }];
}

/** Plain-text fallback for search/heuristics. */
export function flattenInlineMarkdown(text: string): string {
  return parseInlineMarkdown(text)
    .map((segment) => {
      if (segment.kind === "link") return segment.label;
      return segment.value;
    })
    .join("");
}
