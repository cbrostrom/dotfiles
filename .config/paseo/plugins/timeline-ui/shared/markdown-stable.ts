export type RenderPhase = "streaming" | "complete";

export interface MarkdownPartition {
  /** Safe to parse as markdown (complete blocks/lines). */
  readonly stable: string;
  /** Trailing fragment during streaming; show as plain selectable text. */
  readonly tail: string;
}

/** Hold back incomplete fences, paragraphs, and lines while streaming. */
export function partitionMarkdown(text: string, phase: RenderPhase): MarkdownPartition {
  if (phase === "complete" || !text) {
    return { stable: text, tail: "" };
  }

  const fenceCount = (text.match(/```/g) ?? []).length;
  if (fenceCount % 2 === 1) {
    const lastFence = text.lastIndexOf("```");
    return {
      stable: text.slice(0, lastFence).trimEnd(),
      tail: text.slice(lastFence),
    };
  }

  const lastBlank = text.lastIndexOf("\n\n");
  if (lastBlank === -1) {
    if (!text.includes("\n")) {
      return { stable: "", tail: text };
    }
    const lastLineBreak = text.lastIndexOf("\n");
    return {
      stable: text.slice(0, lastLineBreak),
      tail: text.slice(lastLineBreak + 1),
    };
  }

  const tail = text.slice(lastBlank + 2);
  if (!tail.trim()) {
    return { stable: text, tail: "" };
  }

  return {
    stable: text.slice(0, lastBlank),
    tail,
  };
}

const OPEN_INLINE =
  /(\*\*(?:[^*]|\*(?!\*))*$|__(?:[^_]|_(?!_))*$|`[^`\n]*$|\[[^\]\n]*$|\[[^\]]+\]\([^)\n]*$)/;

/** Strip trailing incomplete inline markers from a stable line. */
export function stripIncompleteInline(text: string): { complete: string; fragment: string } {
  const match = OPEN_INLINE.exec(text);
  if (!match || match.index === undefined) {
    return { complete: text, fragment: "" };
  }
  return {
    complete: text.slice(0, match.index),
    fragment: text.slice(match.index),
  };
}
