import { Markdown } from "@earendil-works/pi-tui";
import { CONFIG } from "../config.js";
import { parseAttentionBlocks } from "./attention-blocks.js";
import { renderAttentionBlockStyle, renderMessageStyle } from "./frame.js";

export interface AssistantMessage {
  invalidate(): void;
  render(width: number): string[];
}

function renderSection(
  text: string,
  markdownTheme: any,
  width: number,
  title: string,
): string[] {
  const md = new Markdown(text, 0, 0, markdownTheme);
  return renderMessageStyle(CONFIG.assistantMessage.style, md, width, {
    prefix: CONFIG.assistantMessage.prefix,
    rail: CONFIG.assistantMessage.rail,
    title,
    colors: {
      accent: CONFIG.assistantMessage.color,
      border: CONFIG.assistantMessage.borderColor,
    },
  });
}

export function createAssistantMessage(text: string, markdownTheme: any): AssistantMessage {
  let cachedWidth: number | undefined;
  let cachedLines: string[] | undefined;

  function invalidate(): void {
    cachedWidth = undefined;
    cachedLines = undefined;
  }

  function render(width: number): string[] {
    if (cachedLines && cachedWidth === width) return cachedLines;

    const attention =
      CONFIG.assistantMessage.attentionBlocks.enabled ? parseAttentionBlocks(text) : null;

    if (!attention) {
      cachedLines = renderSection(text, markdownTheme, width, "Assistant");
      cachedWidth = width;
      return cachedLines;
    }

    const lines: string[] = [];
    const blockColors = {
      accent: CONFIG.assistantMessage.attentionBlocks.accentColor,
      border: CONFIG.assistantMessage.attentionBlocks.borderColor,
      background: CONFIG.assistantMessage.attentionBlocks.backgroundColor,
    };

    if (attention.intro) {
      lines.push(...renderSection(attention.intro, markdownTheme, width, "Assistant"));
    }

    for (const block of attention.blocks) {
      if (lines.length > 0) lines.push("");
      const body = block.body || " ";
      const md = new Markdown(body, 0, 0, markdownTheme);
      lines.push(...renderAttentionBlockStyle(md, width, block.title, blockColors));
    }

    if (attention.outro) {
      lines.push("");
      lines.push(...renderSection(attention.outro, markdownTheme, width, "Assistant"));
    }

    cachedWidth = width;
    cachedLines = lines;
    return lines;
  }

  return { invalidate, render };
}
