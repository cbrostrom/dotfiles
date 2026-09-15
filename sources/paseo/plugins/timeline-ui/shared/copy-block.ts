import { flattenInlineMarkdown } from "./inline-markdown.js";
import { parseMarkdownDocument } from "./markdown-document.js";

export type CopyFormat = "markdown" | "text";

export const COPY_FORMAT_OPTIONS = [
  { label: "Markdown", value: "markdown" },
  { label: "Plain text", value: "text" },
] as const;

/** Reconstructed markdown source of a **→ attention block. */
export function attentionBlockMarkdown(block: { readonly title: string; readonly body: string }): string {
  const head = `**→ ${block.title}.**`;
  const body = block.body.trim();
  return body ? `${head}\n${body}` : head;
}

function plainLine(text: string): string {
  return flattenInlineMarkdown(text).trim();
}

/** Render a markdown document as paste-friendly plain text (rendered-text copy). */
export function markdownToPlainText(text: string): string {
  const out: string[] = [];
  for (const block of parseMarkdownDocument(text)) {
    switch (block.kind) {
      case "code":
        out.push(block.text);
        break;
      case "heading":
        out.push(plainLine(block.text));
        break;
      case "paragraph":
        out.push(block.text.split("\n").map(plainLine).join(" "));
        break;
      case "list":
        for (const item of block.items) {
          const marker = item.marker ? `${item.marker}.` : "•";
          out.push(`${"  ".repeat(item.indent)}${marker} ${plainLine(item.text)}`);
        }
        break;
      case "blockquote":
        for (const line of block.text.split("\n")) {
          out.push(`> ${plainLine(line)}`);
        }
        break;
      case "table":
        out.push([block.headers.join(" | "), ...block.rows.map((row) => row.join(" | "))].join("\n"));
        break;
      case "hr":
        out.push("———");
        break;
      case "blank":
        break;
    }
  }
  return out.join("\n").trim();
}

/** Plain-text copy payload for an attention block. */
export function attentionBlockPlainText(block: { readonly title: string; readonly body: string }): string {
  const head = plainLine(block.title);
  const body = block.body.trim();
  if (!body) return head;
  const plain = markdownToPlainText(body);
  return plain ? `${head}\n${plain}` : head;
}
