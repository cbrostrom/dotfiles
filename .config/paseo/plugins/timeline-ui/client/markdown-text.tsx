import type { TextStyle, ViewStyle } from "react-native";
import { Platform, ScrollView, Text, View } from "react-native";
import type { DocumentBlock } from "../shared/markdown-document.js";
import { parseMarkdownDocument } from "../shared/markdown-document.js";
import { parseInlineMarkdown, type InlineSegment } from "../shared/inline-markdown.js";
import { partitionMarkdown, type RenderPhase } from "../shared/markdown-stable.js";

const CODE_FONT = Platform.select({ ios: "Menlo", default: "monospace" });

/** Minimal theme surface the renderer needs. Optional — falls back to theme-agnostic
 * rgba overlays when omitted, so callers that don't have a theme handy still work. */
export type MarkdownTheme = {
  colors: {
    border: string;
    surface0: string;
    surface1: string;
  };
};

function InlineSegments({
  segments,
  baseStyle,
  codeStyle,
  linkStyle,
}: {
  segments: readonly InlineSegment[];
  baseStyle: TextStyle;
  codeStyle: TextStyle;
  linkStyle: TextStyle;
}) {
  return (
    <Text style={baseStyle} selectable>
      {segments.map((segment, index) => {
        const key = `${segment.kind}:${index}`;
        if (segment.kind === "bold") {
          return (
            <Text key={key} style={{ fontWeight: "600" }}>
              {segment.value}
            </Text>
          );
        }
        if (segment.kind === "italic") {
          return (
            <Text key={key} style={{ fontStyle: "italic" }}>
              {segment.value}
            </Text>
          );
        }
        if (segment.kind === "code") {
          return (
            <Text key={key} style={codeStyle}>
              {segment.value}
            </Text>
          );
        }
        if (segment.kind === "link") {
          return (
            <Text key={key} style={linkStyle}>
              {segment.label}
            </Text>
          );
        }
        return segment.value;
      })}
    </Text>
  );
}

function ProseLine({
  text,
  style,
  codeStyle,
  linkStyle,
}: {
  text: string;
  style: TextStyle;
  codeStyle: TextStyle;
  linkStyle: TextStyle;
}) {
  return (
    <InlineSegments
      segments={parseInlineMarkdown(text)}
      baseStyle={style}
      codeStyle={codeStyle}
      linkStyle={linkStyle}
    />
  );
}

/** Rough column-width weighting from content length, so a "Hash"-style short column
 * doesn't get the same width as a long "Subject"/"Description" column. Clamped so no
 * single column can starve the rest. */
function tableColumnWeights(headers: readonly string[], rows: readonly (readonly string[])[]): number[] {
  return headers.map((header, columnIndex) => {
    let max = header.length;
    for (const row of rows) {
      const cell = row[columnIndex];
      if (cell && cell.length > max) max = cell.length;
    }
    return Math.min(Math.max(max, 4), 40);
  });
}

function DocumentBlockView({
  block,
  style,
  codeStyle,
  codeBlockStyle,
  codeLanguageStyle,
  codeContainerStyle,
  linkStyle,
  headingScale,
  quoteStyle,
  tableHeaderStyle,
  tableCellStyle,
  tableChrome,
}: {
  block: DocumentBlock;
  style: TextStyle;
  codeStyle: TextStyle;
  codeBlockStyle: TextStyle;
  codeLanguageStyle: TextStyle;
  codeContainerStyle: ViewStyle;
  linkStyle: TextStyle;
  headingScale: number;
  quoteStyle: ViewStyle;
  tableHeaderStyle: TextStyle;
  tableCellStyle: TextStyle;
  tableChrome: {
    outer: ViewStyle;
    headerRow: ViewStyle;
    row: ViewStyle;
    rowAlt: ViewStyle;
    cell: ViewStyle;
  };
}) {
  if (block.kind === "blank") {
    return <View style={{ height: 4 }} />;
  }
  if (block.kind === "hr") {
    return <View style={{ height: 1, backgroundColor: "rgba(127,127,127,0.25)", marginVertical: 4 }} />;
  }
  if (block.kind === "heading") {
    const fontSize =
      typeof style.fontSize === "number"
        ? style.fontSize * headingScale * (1 + (6 - block.level) * 0.04)
        : 16;
    return (
      <ProseLine
        text={block.text}
        style={{ ...style, fontSize, fontWeight: "600", lineHeight: fontSize * 1.35 }}
        codeStyle={codeStyle}
        linkStyle={linkStyle}
      />
    );
  }
  if (block.kind === "code") {
    return (
      <View style={codeContainerStyle}>
        {block.language ? (
          <View style={{ flexDirection: "row", justifyContent: "flex-end" }}>
            <Text style={codeLanguageStyle} selectable>
              {block.language}
            </Text>
          </View>
        ) : null}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} bounces={false}>
          <Text style={codeBlockStyle} selectable>
            {block.text}
          </Text>
        </ScrollView>
      </View>
    );
  }
  if (block.kind === "blockquote") {
    return (
      <View style={quoteStyle}>
        {block.text.split("\n").map((line, index) => (
          <ProseLine
            key={`quote:${index}`}
            text={line}
            style={{ ...style, fontStyle: "italic" }}
            codeStyle={codeStyle}
            linkStyle={linkStyle}
          />
        ))}
      </View>
    );
  }
  if (block.kind === "list") {
    return (
      <View style={{ gap: 2 }}>
        {block.items.map((item, index) => {
          const marker = block.ordered ? `${item.marker ?? index + 1}.` : "•";
          const indent = item.indent * 12;
          return (
            <View key={`list:${index}`} style={{ flexDirection: "row", paddingLeft: indent, gap: 6 }}>
              <Text style={{ ...style, minWidth: block.ordered ? 18 : 10 }} selectable>
                {marker}
              </Text>
              <View style={{ flex: 1 }}>
                <ProseLine text={item.text} style={style} codeStyle={codeStyle} linkStyle={linkStyle} />
              </View>
            </View>
          );
        })}
      </View>
    );
  }
  if (block.kind === "table") {
    const weights = tableColumnWeights(block.headers, block.rows);
    return (
      <View style={tableChrome.outer}>
        <View style={tableChrome.headerRow}>
          {block.headers.map((header, index) => (
            <View key={`th:${index}`} style={[tableChrome.cell, { flex: weights[index] }]}>
              <ProseLine text={header} style={tableHeaderStyle} codeStyle={codeStyle} linkStyle={linkStyle} />
            </View>
          ))}
        </View>
        {block.rows.map((row, rowIndex) => (
          <View key={`tr:${rowIndex}`} style={rowIndex % 2 === 1 ? tableChrome.rowAlt : tableChrome.row}>
            {row.map((cell, cellIndex) => (
              <View key={`td:${rowIndex}:${cellIndex}`} style={[tableChrome.cell, { flex: weights[cellIndex] ?? 1 }]}>
                <ProseLine text={cell} style={tableCellStyle} codeStyle={codeStyle} linkStyle={linkStyle} />
              </View>
            ))}
          </View>
        ))}
      </View>
    );
  }

  return (
    <View style={{ gap: 4 }}>
      {block.text.split("\n").map((line, index) => (
        <ProseLine key={`p:${index}`} text={line} style={style} codeStyle={codeStyle} linkStyle={linkStyle} />
      ))}
    </View>
  );
}

export function MarkdownText({
  text,
  style,
  theme,
  phase = "complete",
  stableStreaming = true,
  codeBlockVariant = "subtle",
  stackStyle,
  headingScale = 1.1,
}: {
  text: string;
  style: TextStyle;
  theme?: MarkdownTheme;
  phase?: RenderPhase;
  stableStreaming?: boolean;
  codeBlockVariant?: "subtle" | "bordered";
  stackStyle?: ViewStyle;
  headingScale?: number;
}) {
  const borderColor = theme?.colors.border ?? "rgba(127,127,127,0.3)";
  // Softer variant for the default ("subtle") code block outline. Only safe to suffix an
  // alpha byte onto a hex color; the rgba() fallback already has its own baked-in alpha.
  const softBorderColor = theme?.colors.border ? `${theme.colors.border}40` : "rgba(127,127,127,0.18)";
  const codeBg = theme?.colors.surface0 ?? "rgba(127,127,127,0.1)";
  const headerBg = theme?.colors.surface1 ?? "rgba(127,127,127,0.08)";
  const altRowBg = theme?.colors.surface0 ?? "rgba(127,127,127,0.05)";

  const codeStyle: TextStyle = {
    fontFamily: CODE_FONT,
    fontSize: typeof style.fontSize === "number" ? style.fontSize - 1 : 12,
    backgroundColor: "rgba(127,127,127,0.12)",
    borderRadius: 3,
    paddingHorizontal: 3,
  };
  const codeContainerStyle: ViewStyle = {
    gap: 4,
    backgroundColor: codeBg,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: codeBlockVariant === "bordered" ? borderColor : softBorderColor,
    padding: 10,
  };
  const codeBlockStyle: TextStyle = {
    fontFamily: CODE_FONT,
    fontSize: typeof style.fontSize === "number" ? style.fontSize - 1 : 12,
    lineHeight: typeof style.lineHeight === "number" ? style.lineHeight : 18,
    color: style.color,
  };
  const codeLanguageStyle: TextStyle = {
    fontFamily: CODE_FONT,
    fontSize: 10,
    fontWeight: "600",
    color: style.color,
    opacity: 0.55,
    textTransform: "uppercase",
    letterSpacing: 0.4,
  };
  const linkStyle: TextStyle = {
    color: style.color,
    textDecorationLine: "underline",
  };
  const quoteStyle: ViewStyle = {
    borderLeftWidth: 3,
    borderLeftColor: "rgba(127,127,127,0.35)",
    paddingLeft: 10,
    gap: 4,
  };
  const tableHeaderStyle: TextStyle = { ...style, fontWeight: "600" };
  const tableCellStyle: TextStyle = { ...style, color: style.color };
  const tableChrome = {
    outer: {
      borderWidth: 1,
      borderColor,
      borderRadius: 8,
      overflow: "hidden" as const,
    },
    headerRow: {
      flexDirection: "row" as const,
      backgroundColor: headerBg,
      borderBottomWidth: 1,
      borderBottomColor: borderColor,
    },
    row: {
      flexDirection: "row" as const,
    },
    rowAlt: {
      flexDirection: "row" as const,
      backgroundColor: altRowBg,
    },
    cell: {
      paddingHorizontal: 8,
      paddingVertical: 6,
    },
  };

  const effectivePhase = stableStreaming ? phase : "complete";
  const { stable, tail } = partitionMarkdown(text, effectivePhase);
  const blocks = parseMarkdownDocument(stable, effectivePhase === "complete");

  return (
    <View style={stackStyle ?? { gap: 6 }}>
      {blocks.map((block, index) => (
        <DocumentBlockView
          key={`block:${index}`}
          block={block}
          style={style}
          codeStyle={codeStyle}
          codeBlockStyle={codeBlockStyle}
          codeLanguageStyle={codeLanguageStyle}
          codeContainerStyle={codeContainerStyle}
          linkStyle={linkStyle}
          headingScale={headingScale}
          quoteStyle={quoteStyle}
          tableHeaderStyle={tableHeaderStyle}
          tableCellStyle={tableCellStyle}
          tableChrome={tableChrome}
        />
      ))}
      {tail ? (
        <Text style={{ ...style, opacity: 0.92 }} selectable>
          {tail}
        </Text>
      ) : null}
    </View>
  );
}
