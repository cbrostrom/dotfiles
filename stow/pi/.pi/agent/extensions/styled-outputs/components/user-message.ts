import { Markdown } from "@earendil-works/pi-tui";
import { CONFIG } from "../config.js";
import { currentTheme, applyColor } from "../utils.js";
import { renderMessageStyle } from "./frame.js";

export interface UserMessage {
  invalidate(): void;
  render(width: number): string[];
}

export function createUserMessage(text: string, markdownTheme: any): UserMessage {
  const md = new Markdown(text, 0, 0, markdownTheme, {
    color: (t: string) => {
      if (!currentTheme) return t;
      return applyColor(currentTheme, CONFIG.userMessage.bodyColor, t);
    },
  });
  let cachedWidth: number | undefined;
  let cachedLines: string[] | undefined;

  function invalidate(): void {
    cachedWidth = undefined;
    cachedLines = undefined;
    md.invalidate();
  }

  function render(width: number): string[] {
    if (cachedLines && cachedWidth === width) return cachedLines;

    const rendered = renderMessageStyle(CONFIG.userMessage.style, md, width, {
      prefix: CONFIG.userMessage.prefix,
      rail: CONFIG.userMessage.rail,
      title: "User",
      colors: {
        accent: CONFIG.userMessage.color,
        border: CONFIG.userMessage.borderColor,
      },
    });

    cachedWidth = width;
    cachedLines = rendered;
    return rendered;
  }

  return { invalidate, render };
}
