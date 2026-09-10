import { flattenInlineMarkdown } from "./inline-markdown.js";

/** Plain-text cleanup for heuristics (icons, search). */
export function stripInlineMarkdown(text: string): string {
  return text
    .split("\n")
    .map((line) =>
      flattenInlineMarkdown(line.replace(/^\s*#{1,6}\s+/, "").replace(/^\s*[-*+]\s+/, "").replace(/^>\s?/, "")),
    )
    .join("\n")
    .replace(/```[\s\S]*?```/g, (block) =>
      block
        .replace(/```[^\n]*\n?/g, "")
        .replace(/```/g, "")
        .replace(/\s+/g, " ")
        .trim(),
    )
    .trim();
}
