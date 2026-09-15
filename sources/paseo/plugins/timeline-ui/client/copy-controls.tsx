import { copyText } from "@getpaseo/plugin/client/react-native";
import { useEffect, useState } from "react";
import { Pressable, Text, View } from "react-native";
import type { CopyFormat } from "../shared/copy-block.js";

export type CopyControlsTheme = {
  foreground: string;
  border: string;
};

const CHIP_BASE = {
  flexDirection: "row" as const,
  borderRadius: 5,
  borderWidth: 1,
  paddingHorizontal: 6,
  paddingVertical: 2,
  backgroundColor: "rgba(127,127,127,0.08)",
};

const CHIP_TEXT = {
  fontSize: 10,
  fontWeight: "600" as const,
  letterSpacing: 0.4,
};

/** Segmented MD/TXT picker + Copy chip. Pass only `markdown` for a single Copy chip. */
export function CopyControls({
  markdown,
  text,
  initialFormat = "markdown",
  theme,
}: {
  markdown: string;
  /** Plain-text payload; enables the picker when it differs from `markdown`. */
  text?: string;
  initialFormat?: CopyFormat;
  theme: CopyControlsTheme;
}) {
  const hasPicker = text !== undefined && text !== markdown;
  const [format, setFormat] = useState<CopyFormat>(initialFormat);
  const [state, setState] = useState<"idle" | "copied" | "error">("idle");

  useEffect(() => {
    if (state === "idle") return;
    const timer = setTimeout(() => setState("idle"), 1400);
    return () => clearTimeout(timer);
  }, [state]);

  async function copy(): Promise<void> {
    const payload = hasPicker && format === "text" ? text! : markdown;
    try {
      await copyText(payload);
      setState("copied");
    } catch {
      setState("error");
    }
  }

  const chipText = { ...CHIP_TEXT, color: theme.foreground };

  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 4 }}>
      {hasPicker ? (
        <View style={{ flexDirection: "row", gap: 3 }}>
          {(["markdown", "text"] as const).map((value) => {
            const active = format === value;
            return (
              <Pressable
                key={value}
                onPress={() => setFormat(value)}
                style={{
                  ...CHIP_BASE,
                  borderColor: active ? theme.foreground : theme.border,
                  backgroundColor: active ? "rgba(127,127,127,0.2)" : "rgba(127,127,127,0.08)",
                }}
                hitSlop={4}
              >
                <Text style={chipText} selectable={false}>
                  {value === "markdown" ? "MD" : "TXT"}
                </Text>
              </Pressable>
            );
          })}
        </View>
      ) : null}
      <Pressable
        onPress={() => void copy()}
        style={{ ...CHIP_BASE, borderColor: theme.border }}
        hitSlop={4}
      >
        <Text
          style={{ ...chipText, opacity: state === "idle" ? 1 : 0.85 }}
          selectable={false}
        >
          {state === "copied" ? "Copied" : state === "error" ? "Failed" : "Copy"}
        </Text>
      </Pressable>
    </View>
  );
}
