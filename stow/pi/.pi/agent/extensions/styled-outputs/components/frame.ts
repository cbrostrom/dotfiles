import { type Markdown, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { currentTheme, applyBgColor, applyColor, getVisibleWidth, hasVisibleContent } from "../utils.js";

export type MessageStyle = "prefix" | "framed" | "labeled";

export type FrameColors = {
  accent: string;
  border: string;
};

function colorize(color: string, text: string): string {
  if (!currentTheme) return text;
  return applyColor(currentTheme, color, text);
}

function fillLine(content: string, width: number): string {
  const truncated = truncateToWidth(content, Math.max(0, width), "");
  return `${truncated}${" ".repeat(Math.max(0, width - visibleWidth(truncated)))}`;
}

/** First-line prefix glyph; continuation lines indent to match. */
export function renderPrefixStyle(
  md: Markdown,
  width: number,
  prefix: string,
  accentColor: string,
): string[] {
  const prefixWidth = getVisibleWidth(prefix) + 2;
  const padding = " ".repeat(prefixWidth);

  if (width <= prefixWidth) {
    return [` ${colorize(accentColor, prefix)} `];
  }

  const mdLines = md.render(width - prefixWidth);
  let prefixPlaced = false;
  return mdLines.map((line: string) => {
    if (!prefixPlaced && hasVisibleContent(line)) {
      prefixPlaced = true;
      return ` ${colorize(accentColor, prefix)} ${line}`;
    }
    return `${padding}${line}`;
  });
}

/** Top/bottom ─ rules + left accent rail (zentui framed). */
export function renderFramedStyle(
  md: Markdown,
  width: number,
  rail: string,
  colors: FrameColors,
): string[] {
  if (width <= 0) return [""];

  const railRaw = `${rail} `;
  const railStyled = colorize(colors.accent, railRaw);
  const railWidth = visibleWidth(railRaw);
  const contentWidth = Math.max(1, width - railWidth);
  const body = md.render(contentWidth);
  const lines = body.length > 0 ? body : [""];

  const row = (line: string) => {
    const available = Math.max(0, width - railWidth);
    return truncateToWidth(`${railStyled}${fillLine(line, available)}`, width, "");
  };

  const rule = colorize(colors.border, truncateToWidth("─".repeat(width), width, ""));
  return [rule, row(""), ...lines.map(row), row(""), rule];
}

/** Closed Unicode box with title label (zentui labeled). */
export function renderLabeledStyle(
  md: Markdown,
  width: number,
  title: string,
  colors: FrameColors,
): string[] {
  if (width <= 0) return [""];
  if (width <= 2) {
    return md.render(width).map((line: string) => truncateToWidth(line, width, ""));
  }

  const horizontalPadding = width >= 5 ? 1 : 0;
  const contentWidth = Math.max(1, width - 2 - horizontalPadding * 2);
  const body = md.render(contentWidth);
  const lines = body.length > 0 ? body : [""];
  const pad = " ".repeat(horizontalPadding);
  const border = (text: string) => colorize(colors.border, text);
  const accent = (text: string) => colorize(colors.accent, text);

  // "╭─ Title ─╮" needs 4 border chars + title length
  const titleSpan = ` ${title} `;
  const titleBudget = 4 + getVisibleWidth(titleSpan);
  const top =
    width >= titleBudget
      ? `${border("╭─")}${accent(titleSpan)}${border(`${"─".repeat(Math.max(0, width - titleBudget))}╮`)}`
      : border(`╭${"─".repeat(Math.max(0, width - 2))}╮`);

  const side = (line: string) =>
    `${border("│")}${pad}${fillLine(line, contentWidth)}${pad}${border("│")}`;

  const bottom = border(`╰${"─".repeat(Math.max(0, width - 2))}╯`);
  return [top, ...lines.map(side), bottom];
}

/** Labeled box with tinted interior (PI **→ Lead-in.** attention blocks). */
export function renderAttentionBlockStyle(
  md: Markdown,
  width: number,
  title: string,
  colors: FrameColors & { background: string },
): string[] {
  if (width <= 0) return [""];
  if (width <= 2) {
    return md.render(width).map((line: string) => truncateToWidth(line, width, ""));
  }

  const horizontalPadding = width >= 5 ? 1 : 0;
  const contentWidth = Math.max(1, width - 2 - horizontalPadding * 2);
  const body = md.render(contentWidth);
  const lines = body.length > 0 ? body : [""];
  const pad = " ".repeat(horizontalPadding);
  const border = (text: string) => colorize(colors.border, text);
  const accent = (text: string) => colorize(colors.accent, text);
  const tint = (text: string) => {
    if (!currentTheme) return text;
    return applyBgColor(currentTheme, colors.background, text);
  };

  const titleSpan = ` → ${title} `;
  const titleBudget = 4 + getVisibleWidth(titleSpan);
  const top =
    width >= titleBudget
      ? `${border("╭─")}${accent(titleSpan)}${border(`${"─".repeat(Math.max(0, width - titleBudget))}╮`)}`
      : border(`╭${"─".repeat(Math.max(0, width - 2))}╮`);

  const side = (line: string) => {
    const inner = `${pad}${fillLine(line, contentWidth)}${pad}`;
    return `${border("│")}${tint(inner)}${border("│")}`;
  };

  const bottom = border(`╰${"─".repeat(Math.max(0, width - 2))}╯`);
  return [top, ...lines.map(side), bottom];
}

export function renderMessageStyle(
  style: MessageStyle,
  md: Markdown,
  width: number,
  opts: {
    prefix: string;
    rail: string;
    title: string;
    colors: FrameColors;
  },
): string[] {
  switch (style) {
    case "framed":
      return renderFramedStyle(md, width, opts.rail, opts.colors);
    case "labeled":
      return renderLabeledStyle(md, width, opts.title, opts.colors);
    case "prefix":
    default:
      return renderPrefixStyle(md, width, opts.prefix, opts.colors.accent);
  }
}
