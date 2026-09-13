import { stripIncompleteInline } from "./markdown-stable.js";

export type DocumentBlock =
  | { readonly kind: "blank" }
  | { readonly kind: "hr" }
  | { readonly kind: "heading"; readonly level: number; readonly text: string }
  | { readonly kind: "code"; readonly language: string | null; readonly text: string }
  | { readonly kind: "blockquote"; readonly text: string }
  | {
      readonly kind: "list";
      readonly ordered: boolean;
      readonly items: readonly { readonly indent: number; readonly text: string; readonly marker?: string }[];
    }
  | { readonly kind: "table"; readonly headers: readonly string[]; readonly rows: readonly (readonly string[])[] }
  | { readonly kind: "paragraph"; readonly text: string };

const HR_RE = /^ {0,3}(-{3,}|\*{3,}|_{3,})\s*$/;
const HEADING_RE = /^(#{1,6})\s+(.*)$/;
const BLOCKQUOTE_RE = /^>\s?(.*)$/;
const BULLET_RE = /^(\s*)[-*+]\s+(.*)$/;
const ORDERED_RE = /^(\s*)(\d+)\.\s+(.*)$/;
const TABLE_SEP_RE = /^\s*\|?(?:\s*:?-+:?\s*\|?)+\s*$/;

function indentLevel(whitespace: string): number {
  return Math.floor(whitespace.replace(/\t/g, "  ").length / 2);
}

function parseTableRow(line: string): string[] {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  return trimmed.split("|").map((cell) => cell.trim());
}

function isTableRow(line: string): boolean {
  return line.includes("|") && line.trim().startsWith("|");
}

/** Split prose and fenced code; unclosed fence at EOF becomes a code block. */
export function splitFencedSections(text: string): readonly { readonly kind: "prose" | "code"; readonly language: string | null; readonly body: string }[] {
  const trimmed = text.trim();
  if (!trimmed) return [];

  const sections: { kind: "prose" | "code"; language: string | null; body: string }[] = [];
  const parts = trimmed.split(/```/);

  for (let index = 0; index < parts.length; index++) {
    const part = parts[index];
    if (part === undefined) continue;
    if (index % 2 === 0) {
      const prose = part.trim();
      if (prose) sections.push({ kind: "prose", language: null, body: prose });
      continue;
    }
    const newline = part.indexOf("\n");
    if (newline === -1) {
      sections.push({ kind: "code", language: part.trim() || null, body: "" });
      continue;
    }
    const language = part.slice(0, newline).trim() || null;
    const body = part.slice(newline + 1).trimEnd();
    sections.push({ kind: "code", language, body });
  }

  return sections.length > 0 ? sections : [{ kind: "prose", language: null, body: trimmed }];
}

function parseProseLines(lines: readonly string[], inlineComplete: boolean): DocumentBlock[] {
  const blocks: DocumentBlock[] = [];
  let index = 0;

  while (index < lines.length) {
    const raw = lines[index]!;
    const line = raw.trimEnd();

    if (!line.trim()) {
      blocks.push({ kind: "blank" });
      index += 1;
      continue;
    }

    if (HR_RE.test(line.trim())) {
      blocks.push({ kind: "hr" });
      index += 1;
      continue;
    }

    const heading = HEADING_RE.exec(line);
    if (heading) {
      const text = inlineComplete ? heading[2]!.trim() : stripIncompleteInline(heading[2]!.trim()).complete;
      blocks.push({ kind: "heading", level: heading[1]!.length, text });
      index += 1;
      continue;
    }

    if (isTableRow(line) && index + 1 < lines.length && TABLE_SEP_RE.test(lines[index + 1]!.trim())) {
      const headers = parseTableRow(line);
      index += 2;
      const rows: string[][] = [];
      while (index < lines.length && isTableRow(lines[index]!)) {
        rows.push(parseTableRow(lines[index]!));
        index += 1;
      }
      blocks.push({ kind: "table", headers, rows });
      continue;
    }

    const quote = BLOCKQUOTE_RE.exec(line);
    if (quote) {
      const quoteLines: string[] = [quote[1]!];
      index += 1;
      while (index < lines.length) {
        const next = BLOCKQUOTE_RE.exec(lines[index]!.trimEnd());
        if (!next) break;
        quoteLines.push(next[1]!);
        index += 1;
      }
      blocks.push({ kind: "blockquote", text: quoteLines.join("\n") });
      continue;
    }

    const bullet = BULLET_RE.exec(line);
    const ordered = bullet ? null : ORDERED_RE.exec(line);
    if (bullet || ordered) {
      const isOrdered = Boolean(ordered);
      const items: { indent: number; text: string; marker?: string }[] = [];
      while (index < lines.length) {
        const current = lines[index]!.trimEnd();
        const b = BULLET_RE.exec(current);
        const o = b ? null : ORDERED_RE.exec(current);
        if (!b && !o) break;
        if (b) {
          items.push({ indent: indentLevel(b[1] ?? ""), text: b[2]! });
        } else if (o) {
          items.push({ indent: indentLevel(o[1] ?? ""), text: o[3]!, marker: o[2]! });
        }
        index += 1;
      }
      blocks.push({ kind: "list", ordered: isOrdered, items });
      continue;
    }

    const paragraphLines: string[] = [line];
    index += 1;
    while (index < lines.length) {
      const next = lines[index]!.trimEnd();
      if (
        !next.trim() ||
        HR_RE.test(next.trim()) ||
        HEADING_RE.test(next) ||
        BLOCKQUOTE_RE.test(next) ||
        BULLET_RE.test(next) ||
        ORDERED_RE.test(next) ||
        (isTableRow(next) && index + 1 < lines.length && TABLE_SEP_RE.test(lines[index + 1]!.trim()))
      ) {
        break;
      }
      paragraphLines.push(next);
      index += 1;
    }

    let paragraphText = paragraphLines.join("\n");
    if (!inlineComplete) {
      const lastLine = paragraphLines[paragraphLines.length - 1] ?? "";
      const { complete, fragment } = stripIncompleteInline(lastLine);
      if (fragment) {
        paragraphLines[paragraphLines.length - 1] = complete;
        paragraphText = paragraphLines.filter((entry) => entry.length > 0).join("\n");
      }
    }
    if (paragraphText.trim()) {
      blocks.push({ kind: "paragraph", text: paragraphText });
    }
  }

  return blocks;
}

export function parseMarkdownDocument(text: string, inlineComplete = true): readonly DocumentBlock[] {
  const sections = splitFencedSections(text);
  const blocks: DocumentBlock[] = [];

  for (const section of sections) {
    if (section.kind === "code") {
      blocks.push({ kind: "code", language: section.language, text: section.body });
      continue;
    }
    blocks.push(...parseProseLines(section.body.split("\n"), inlineComplete));
  }

  return blocks.length > 0 ? blocks : [{ kind: "paragraph", text: text.trim() }];
}
