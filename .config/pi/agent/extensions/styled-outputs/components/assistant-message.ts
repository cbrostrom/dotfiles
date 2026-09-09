import { Markdown } from "@earendil-works/pi-tui";
import { CONFIG } from "../config.js";
import { renderMessageStyle } from "./frame.js";

export interface AssistantMessage {
  invalidate(): void;
  render(width: number): string[];
}

export function createAssistantMessage(text: string, markdownTheme: any): AssistantMessage {
  const md = new Markdown(text, 0, 0, markdownTheme);
  let cachedWidth: number | undefined;
  let cachedLines: string[] | undefined;

  function invalidate(): void {
    cachedWidth = undefined;
    cachedLines = undefined;
    md.invalidate();
  }

  function render(width: number): string[] {
    if (cachedLines && cachedWidth === width) return cachedLines;

    const rendered = renderMessageStyle(CONFIG.assistantMessage.style, md, width, {
      prefix: CONFIG.assistantMessage.prefix,
      rail: CONFIG.assistantMessage.rail,
      title: "Assistant",
      colors: {
        accent: CONFIG.assistantMessage.color,
        border: CONFIG.assistantMessage.borderColor,
      },
    });

    cachedWidth = width;
    cachedLines = rendered;
    return rendered;
  }

  return { invalidate, render };
}
