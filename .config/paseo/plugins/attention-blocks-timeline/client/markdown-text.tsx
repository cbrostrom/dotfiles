import type { TextStyle, ViewStyle } from "react-native";
import { Platform, Text, View } from "react-native";
import type { DocumentBlock } from "../shared/markdown-document.js";
import { parseMarkdownDocument } from "../shared/markdown-document.js";
import { parseInlineMarkdown, type InlineSegment } from "../shared/inline-markdown.js";
import { partitionMarkdown, type RenderPhase } from "../shared/markdown-stable.js";

const CODE_FONT = Platform.select({ ios: "Menlo", default: "monospace" });

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

function DocumentBlockView({
  block,
  style,
  codeStyle,
  codeBlockStyle,
  linkStyle,
  headingScale,
  quoteStyle,
  tableHeaderStyle,
  tableCellStyle,
}: {
  block: DocumentBlock;
  style: TextStyle;
  codeStyle: TextStyle;
  codeBlockStyle: TextStyle;
  linkStyle: TextStyle;
  headingScale: number;
  quoteStyle: ViewStyle;
  tableHeaderStyle: TextStyle;
  tableCellStyle: TextStyle;
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
      <View style={{ gap: block.language ? 4 : 0 }}>
        {block.language ? (
          <Text style={{ ...style, fontSize: 11, color: linkStyle.color, opacity: 0.7 }} selectable>
            {block.language}
          </Text>
        ) : null}
        <Text style={codeBlockStyle} selectable>
          {block.text}
        </Text>
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
    return (
      <View style={{ gap: 4 }}>
        <View style={{ flexDirection: "row", gap: 8 }}>
          {block.headers.map((header, index) => (
            <Text key={`th:${index}`} style={{ ...tableHeaderStyle, flex: 1 }} selectable>
              {header}
            </Text>
          ))}
        </View>
        {block.rows.map((row, rowIndex) => (
          <View key={`tr:${rowIndex}`} style={{ flexDirection: "row", gap: 8 }}>
            {row.map((cell, cellIndex) => (
              <Text key={`td:${rowIndex}:${cellIndex}`} style={{ ...tableCellStyle, flex: 1 }} selectable>
                {cell}
              </Text>
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
  phase = "complete",
  stableStreaming = true,
  codeBlockVariant = "subtle",
  stackStyle,
  headingScale = 1.1,
}: {
  text: string;
  style: TextStyle;
  phase?: RenderPhase;
  stableStreaming?: boolean;
  codeBlockVariant?: "subtle" | "bordered";
  stackStyle?: ViewStyle;
  headingScale?: number;
}) {
  const codeStyle: TextStyle = {
    fontFamily: CODE_FONT,
    fontSize: typeof style.fontSize === "number" ? style.fontSize - 1 : 12,
    backgroundColor: "rgba(127,127,127,0.12)",
    borderRadius: 3,
    paddingHorizontal: 3,
  };
  const codeBlockStyle: TextStyle = {
    ...codeStyle,
    fontSize: typeof style.fontSize === "number" ? style.fontSize - 1 : 12,
    padding: 10,
    borderRadius: 8,
    lineHeight: typeof style.lineHeight === "number" ? style.lineHeight : 18,
    ...(codeBlockVariant === "bordered"
      ? { borderWidth: 1, borderColor: "rgba(127,127,127,0.35)", backgroundColor: "rgba(127,127,127,0.08)" }
      : {}),
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
          linkStyle={linkStyle}
          headingScale={headingScale}
          quoteStyle={quoteStyle}
          tableHeaderStyle={tableHeaderStyle}
          tableCellStyle={tableCellStyle}
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
