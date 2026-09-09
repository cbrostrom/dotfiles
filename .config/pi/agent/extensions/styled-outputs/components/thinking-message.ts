import { Markdown } from "@earendil-works/pi-tui";
import { CONFIG } from "../config.js";
import { currentTheme, applyColor, getVisibleWidth, hasVisibleContent } from "../utils.js";
import { renderMessageStyle } from "./frame.js";

export interface ThinkingMessage {
  invalidate(): void;
  render(width: number): string[];
}

function getFullPrefix(): string {
  const prefix = currentTheme
    ? applyColor(currentTheme, CONFIG.thinkingMessage.prefixColor, CONFIG.thinkingMessage.prefix)
    : CONFIG.thinkingMessage.prefix;
  const label = currentTheme
    ? applyColor(currentTheme, CONFIG.thinkingMessage.labelColor, CONFIG.thinkingMessage.label)
    : CONFIG.thinkingMessage.label;
  return ` ${prefix}${CONFIG.thinkingMessage.isLabelVisible ? ` ${label} ` : ` `}`;
}

/** Legacy prefix renderer keeps optional "Thinking:" label on first line. */
function renderThinkingPrefix(md: Markdown, width: number): string[] {
  const fullPrefix = getFullPrefix();
  const firstLinePrefixWidth = getVisibleWidth(fullPrefix);
  const padding = " ".repeat(getVisibleWidth(CONFIG.thinkingMessage.prefix) + 2);

  if (width <= firstLinePrefixWidth) {
    return [fullPrefix.trimEnd()];
  }

  const mdLines = md.render(width - firstLinePrefixWidth);
  let prefixPlaced = false;
  return mdLines.map((line: string) => {
    if (!prefixPlaced && hasVisibleContent(line)) {
      prefixPlaced = true;
      return `${fullPrefix}${line}`;
    }
    return `${padding}${line}`;
  });
}

export function createThinkingMessage(text: string, markdownTheme: any): ThinkingMessage {
  const md = new Markdown(text, 0, 0, markdownTheme, {
    color: (t: string) => {
      if (!currentTheme) return t;
      return applyColor(currentTheme, CONFIG.thinkingMessage.messageColor, t);
    },
    italic: true,
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

    let rendered: string[];
    if (CONFIG.thinkingMessage.style === "prefix") {
      rendered = renderThinkingPrefix(md, width);
    } else {
      // Strip trailing colon from "Thinking:" for box title
      const title = CONFIG.thinkingMessage.label.replace(/:\s*$/, "") || "Thinking";
      rendered = renderMessageStyle(CONFIG.thinkingMessage.style, md, width, {
        prefix: CONFIG.thinkingMessage.prefix,
        rail: CONFIG.thinkingMessage.rail,
        title,
        colors: {
          accent: CONFIG.thinkingMessage.prefixColor,
          border: CONFIG.thinkingMessage.borderColor,
        },
      });
    }

    cachedWidth = width;
    cachedLines = rendered;
    return rendered;
  }

  return { invalidate, render };
}
