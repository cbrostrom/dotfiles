import type { PluginTimelineItemProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { Icon } from "@getpaseo/plugin/client/react-native";
import { useCallback, useMemo, useState } from "react";
import { Platform, Pressable, Text, View } from "react-native";
import type { z } from "zod";
import { buildCardChrome, hexToRgba } from "../shared/card-display.js";
import {
  DEFAULT_TOOL_PREFERENCES,
  toolItemDataSchema,
  toolPreferences,
} from "../shared/tool-call.js";
import { lineDiff, type DiffRow } from "./line-diff.js";
import { MarkdownText } from "./markdown-text.js";
import { useMessagePreferences } from "./use-message-preferences.js";

type ToolData = z.output<typeof toolItemDataSchema>;

const STATUS_LABELS: Record<ToolData["status"], string | null> = {
  running: "Running",
  completed: null,
  failed: "Failed",
  canceled: "Canceled",
};

export function ToolCallTimelineItem({
  item,
  theme,
  layout,
}: PluginTimelineItemProps<ToolData>) {
  const settings = useSettings(toolPreferences);
  const preferences =
    settings.status === "ready" ? settings.values : DEFAULT_TOOL_PREFERENCES;
  const { typography } = useMessagePreferences(layout.compact);
  const [manualExpanded, setManualExpanded] = useState<boolean | null>(null);
  const expanded = manualExpanded ?? false;
  const accent = theme.colors.accent ?? theme.colors.foreground;
  const streaming = item.data.phase === "streaming";
  const stateLabel = streaming ? "Running" : STATUS_LABELS[item.data.status];
  const body = useMemo(() => detailToMarkdown(item.data), [item.data]);
  const nameColor =
    item.data.status === "failed"
      ? (theme.colors.statusDanger ?? accent)
      : accent;

  const detail = useMemo(() => {
    const items = item.data.items as Record<string, unknown> | null;
    if (!items) return null;
    // pi wraps tool payloads in `{ type: "unknown", input, output }`; flatten
    // the input wrapper so shell/edit fields resolve consistently.
    const input = items.input;
    const source =
      input && typeof input === "object" && !Array.isArray(input)
        ? ({ ...items, ...(input as Record<string, unknown>) } as Record<string, unknown>)
        : items;
    const str = (key: string): string | null => {
      const value = source[key];
      return typeof value === "string" && value.trim() ? value : null;
    };
    const num = (key: string): number | null => {
      const value = source[key];
      return typeof value === "number" && Number.isFinite(value) ? value : null;
    };
    return {
      source,
      oldText: str("oldString"),
      newText: str("newString"),
      command: str("command") ?? str("code"),
      output: str("output"),
      language: str("language"),
      timeoutMs: num("timeout"),
    };
  }, [item.data]);
  const useDiff = !!(detail?.oldText && detail?.newText);
  const diff = detail && useDiff ? { old: detail.oldText as string, new: detail.newText as string } : null
  const useShell = !useDiff && !!(detail?.command || detail?.output);
  const hasBody = useDiff || useShell || body !== null;

  const chrome = useMemo(
    () =>
      buildCardChrome(
        {
          borderStyle: "box",
          backgroundOpacity: 0,
          accentColor: accent,
          themeBorder: theme.colors.border,
          themeSurface: theme.colors.surface1,
        },
        layout.compact,
      ),
    [accent, layout.compact, theme.colors.border, theme.colors.surface1],
  );

  const styles = useMemo(
    () => ({
      header: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 6 : 8,
        minHeight: 20,
      },
      line: {
        alignItems: "center" as const,
        flexDirection: "row" as const,
        gap: layout.compact ? 5 : 6,
        minHeight: 18,
      },
      name: {
        color: nameColor,
        fontSize: layout.compact ? 12 : 13,
        fontWeight: "600" as const,
      },
      summary: {
        color: theme.colors.foregroundMuted,
        flex: 1,
        fontSize: layout.compact ? 11 : 12,
      },
      state: {
        color: theme.colors.foregroundMuted,
        fontSize: layout.compact ? 11 : 12,
      },
      body: {
        color: theme.colors.foreground,
        fontSize: typography.fontSize,
        lineHeight: typography.lineHeight,
      },
    }),
    [
      accent,
      nameColor,
      layout.compact,
      theme.colors.foreground,
      theme.colors.foregroundMuted,
      typography,
    ],
  );

  const toggle = useCallback(() => setManualExpanded(!expanded), [expanded]);

  // Chevron only when there is real content behind it.
  const chevron = hasBody ? (
    <Icon
      name={expanded ? "ChevronDown" : "ChevronRight"}
      size={11}
      color={theme.colors.foregroundMuted}
    />
  ) : null;

  return (
    <Pressable
      accessibilityLabel={`${expanded ? "Collapse" : "Expand"} ${item.data.name} call`}
      accessibilityRole="button"
      onPress={toggle}
    >
      {preferences.style === "inline" ? (
        <View style={[styles.line, expanded ? { alignItems: "flex-start" } : undefined]}>
          {chevron}
          <Text style={styles.name}>{item.data.name}</Text>
          {item.data.summary ? (
            <Text style={styles.summary} numberOfLines={expanded ? undefined : 1}>
              {item.data.summary}
            </Text>
          ) : null}
          {stateLabel ? <Text style={styles.state}>{stateLabel}</Text> : null}
        </View>
      ) : (
        <View style={chrome.outer}>
          <View style={chrome.inner}>
            <View style={styles.header}>
              {hasBody ? (
                <Icon
                  name={expanded ? "ChevronDown" : "ChevronRight"}
                  size={13}
                  color={theme.colors.foregroundMuted}
                />
              ) : null}
              <Text style={styles.name}>{item.data.name}</Text>
              {item.data.summary ? (
                <Text style={styles.summary} numberOfLines={1} ellipsizeMode="tail">
                  {item.data.summary}
                </Text>
              ) : null}
            </View>
          </View>
        </View>
      )}
      {expanded && hasBody && detail ? (
        <View
          style={{
            // Indent the expanded body under the title so expanded content
            // clearly belongs to the call line above it.
            paddingLeft: layout.compact ? 17 : 21,
          }}
        >
        {diff ? (
          <DiffBody
            oldText={diff.old}
            newText={diff.new}
            compact={layout.compact}
            danger={theme.colors.statusDanger ?? accent}
            success={theme.colors.statusSuccess ?? accent}
            muted={theme.colors.foregroundMuted}
          />
        ) : useShell && detail ? (
          <ShellBody
            command={detail.command}
            output={detail.output}
            language={detail.language}
            timeoutMs={detail.timeoutMs}
            failed={item.data.status === "failed"}
            accent={accent}
            danger={theme.colors.statusDanger ?? accent}
            muted={theme.colors.foregroundMuted}
            compact={layout.compact}
          />
        ) : (
          <MarkdownText
            text={body ?? ""}
            style={styles.body}
            phase={item.data.phase}
            stableStreaming={false}
            codeBlockVariant="subtle"
            headingScale={typography.headingScale}
            stackStyle={{ gap: typography.gap }}
          />
        )}
        </View>
      ) : null}
    </Pressable>
  );
}

const SKIP_KEYS = new Set(["filePath", "command", "code", "unifiedDiff", "output", "type", "language", "timeout"]);
const MAX_INLINE = 80;
const MAX_JSON = 600;

/**
 * Markdown body for the expanded tool call. Known fields first (path, command,
 * diff, output), then any remaining fields generically so tools like
 * ctx_execute (code) and ctx_batch_execute (commands, queries) render their
 * real content instead of a duplicated tool name. Null when there is nothing
 * to show — callers hide the expand affordance.
 */
function detailToMarkdown(data: ToolData): string | null {
  const items = data.items as Record<string, unknown> | null;
  if (!items) return null;
  const str = (key: string): string | null => {
    const value = items[key];
    return typeof value === "string" && value.trim() ? value : null;
  };
  const parts: string[] = [];
  const filePath = str("filePath");
  const command = str("command") ?? str("code");
  const diff = str("unifiedDiff");
  const output = str("output");
  if (filePath) parts.push(`\`${filePath}\``);
  if (command) parts.push("```\n" + command + "\n```");
  if (diff) parts.push("```diff\n" + diff + "\n```");
  else if (output) parts.push("```\n" + output + "\n```");
  const lines: string[] = [];
  const blocks: string[] = [];
  // Flatten a wrapper `input` object (pi's unknown-detail shape
  // `{ type: "unknown", input, output }`) into the generic pass so its
  // fields render directly instead of as one JSON blob.
  const input = items.input;
  const entries: Array<[string, unknown]> =
    input && typeof input === "object" && !Array.isArray(input)
      ? Object.entries(input as Record<string, unknown>)
      : Object.entries(items);
  for (const [key, value] of entries) {
    if (SKIP_KEYS.has(key)) continue;
    if (typeof value === "string" && value.trim()) {
      if (value.length > MAX_INLINE || value.includes("\n")) {
        blocks.push(`**${key}**\n\`\`\`\n${value}\n\`\`\``);
      } else {
        lines.push(`${key}: ${value}`);
      }
    } else if (typeof value === "number" || typeof value === "boolean") {
      lines.push(`${key}: ${value}`);
    } else if (value !== null && typeof value === "object") {
      const json = JSON.stringify(value, null, 2);
      if (json) {
        blocks.push(
          `**${key}**\n\`\`\`\n${json.length > MAX_JSON ? json.slice(0, MAX_JSON - 1) + "…" : json}\n\`\`\``,
        );
      }
    }
  }
  if (lines.length) parts.push(lines.join("\n"));
  parts.push(...blocks);
  return parts.length ? parts.join("\n\n") : null;
}


const MAX_DIFF_ROWS = 400;
const CODE_FONT = Platform.select({ ios: "Menlo", default: "monospace" });

/**
 * oldString/newString edit body: LCS-aligned rows in one rounded panel,
 * side by side on desktop, stacked on mobile. Removed rows get a danger
 * tint on the left, added rows a success tint on the right, context rows
 * stay muted so the edit pops. Fixed row heights keep the columns aligned.
 */
function DiffBody({
  oldText,
  newText,
  compact,
  danger,
  success,
  muted,
}: {
  oldText: string;
  newText: string;
  compact: boolean;
  danger: string;
  success: string;
  muted: string;
}) {
  const rows = useMemo(() => lineDiff(oldText, newText), [oldText, newText]);
  const shown = rows.slice(0, MAX_DIFF_ROWS);
  const fontSize = compact ? 11 : 12;
  const rowHeight = Math.round(fontSize * 1.55);
  const divider = hexToRgba(muted, 0.22);
  const columnStyle = compact ? undefined : { flex: 1 };
  return (
    <View
      style={{
        marginTop: 8,
        borderRadius: 8,
        borderWidth: 1,
        borderColor: divider,
        backgroundColor: hexToRgba(muted, 0.05),
        overflow: "hidden",
      }}
    >
      <View style={{ flexDirection: compact ? "column" : "row" }}>
        <View style={columnStyle}>
          {shown.map((row, index) => (
            <DiffRowView
              key={index}
              row={row}
              side="left"
              fontSize={fontSize}
              rowHeight={rowHeight}
              tint={row.kind === "removed" ? hexToRgba(danger, 0.12) : null}
              markerColor={danger}
              muted={muted}
              label={compact ? "Old" : null}
            />
          ))}
        </View>
        {!compact ? <View style={{ width: 1, backgroundColor: divider }} /> : null}
        <View style={compact ? { marginTop: 2 } : columnStyle}>
          {shown.map((row, index) => (
            <DiffRowView
              key={index}
              row={row}
              side="right"
              fontSize={fontSize}
              rowHeight={rowHeight}
              tint={
                row.kind === "added" || (row.kind === "removed" && row.right !== null)
                  ? hexToRgba(success, 0.12)
                  : null
              }
              markerColor={success}
              muted={muted}
              label={compact ? "New" : null}
            />
          ))}
        </View>
      </View>
      {rows.length > shown.length ? (
        <Text style={{ color: muted, fontSize: 10, paddingHorizontal: 8, paddingVertical: 4 }}>
          › {rows.length - shown.length} more lines
        </Text>
      ) : null}
    </View>
  );
}

function DiffRowView({
  row,
  side,
  fontSize,
  rowHeight,
  tint,
  markerColor,
  muted,
  label,
}: {
  row: DiffRow;
  side: "left" | "right";
  fontSize: number;
  rowHeight: number;
  tint: string | null;
  markerColor: string;
  muted: string;
  label: string | null;
}) {
  const text = side === "left" ? row.left : row.right;
  if (label) {
    return (
      <Text
        style={{
          color: muted,
          fontSize: 9,
          fontWeight: "600",
          letterSpacing: 0.6,
          paddingHorizontal: 10,
          lineHeight: 18,
          textTransform: "uppercase",
        }}
      >
        {label}
      </Text>
    );
  }
  if (text === null) {
    return <View style={{ height: rowHeight }} />;
  }
  const changed =
    side === "left" ? row.kind === "removed" : row.kind === "added" || (row.kind === "removed" && row.right !== null);
  return (
    <View
      style={{
        flexDirection: "row",
        alignItems: "center",
        backgroundColor: tint ?? "transparent",
        paddingHorizontal: 10,
        borderLeftWidth: changed ? 2 : 0,
        borderLeftColor: changed ? markerColor : "transparent",
      }}
    >
      <Text
        style={{
          fontFamily: CODE_FONT,
          fontSize: fontSize - 2,
          height: rowHeight,
          lineHeight: rowHeight,
          color: changed ? markerColor : "transparent",
          width: 12,
        }}
      >
        {changed ? (side === "left" ? "\u2212" : "+") : "\u00b7"}
      </Text>
      <Text
        numberOfLines={1}
        style={{
          fontFamily: CODE_FONT,
          fontSize,
          height: rowHeight,
          lineHeight: rowHeight,
          flex: 1,
          color: changed ? undefined : muted,
        }}
      >
        {text || " "}
      </Text>
    </View>
  );
}

/**
 * bash/ctx_execute body: command as an accent line, a small language/timeout
 * meta line, then the output hanging beneath a connecting left bar in that
 * accent (danger red when the call failed). No chip boxes.
 */
function ShellBody({
  command,
  output,
  language,
  timeoutMs,
  failed,
  accent,
  danger,
  muted,
  compact,
}: {
  command: string | null;
  output: string | null;
  language: string | null;
  timeoutMs: number | null;
  failed: boolean;
  accent: string;
  danger: string;
  muted: string;
  compact: boolean;
}) {
  const meta: string[] = [];
  if (language) meta.push(language);
  if (timeoutMs) {
    meta.push(
      timeoutMs >= 60000
        ? `${Math.round(timeoutMs / 60000)}m timeout`
        : `${timeoutMs / 1000}s timeout`,
    );
  }
  return (
    <View style={{ gap: 4, marginTop: 6 }}>
      {command ? (
        <Text
          selectable
          style={{
            fontFamily: CODE_FONT,
            fontSize: compact ? 11 : 12,
            lineHeight: compact ? 16 : 17,
            color: accent,
          }}
        >
          {command}
        </Text>
      ) : null}
      {meta.length ? (
        <Text style={{ color: muted, fontSize: 10 }}>{meta.join(" \u00b7 ")}</Text>
      ) : null}
      {output ? (
        <View
          style={{
            borderLeftWidth: 2,
            borderLeftColor: failed ? danger : hexToRgba(accent, 0.45),
            paddingLeft: 10,
            paddingVertical: 2,
          }}
        >
          <Text
            selectable
            style={{
              fontFamily: CODE_FONT,
              fontSize: compact ? 11 : 12,
              lineHeight: compact ? 16 : 17,
              color: failed ? danger : muted,
            }}
          >
            {output}
          </Text>
        </View>
      ) : null}
    </View>
  );
}
