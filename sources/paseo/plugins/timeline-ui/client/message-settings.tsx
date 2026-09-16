import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import {
  SettingsCard,
  SettingsSection,
  SettingsSelect,
  SettingsSwitch,
} from "@getpaseo/plugin/client/ui";
import { useMemo } from "react";
import { Text, View } from "react-native";
import {
  CODE_STYLE_OPTIONS,
  DEFAULT_MESSAGE_PREFERENCES,
  messagePreferences,
  PEER_CARD_STYLE_OPTIONS,
  PROSE_DENSITY_OPTIONS,
  type MessagePreferences,
} from "../shared/message-preferences.js";
import {
  DEFAULT_TOOL_PREFERENCES,
  TOOL_STYLE_OPTIONS,
  toolPreferences,
} from "../shared/tool-call.js";

export function MessageSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(messagePreferences);
  const values: MessagePreferences =
    settings.status === "ready"
      ? { ...DEFAULT_MESSAGE_PREFERENCES, ...settings.values }
      : DEFAULT_MESSAGE_PREFERENCES;
  const disabled = settings.status !== "ready" || settings.saving;
  const toolSettings = useSettings(toolPreferences);
  const toolValues =
    toolSettings.status === "ready" ? toolSettings.values : DEFAULT_TOOL_PREFERENCES;
  const toolDisabled = toolSettings.status !== "ready" || toolSettings.saving;

  const hintStyle = useMemo(
    () => ({ color: _props.theme.colors.foregroundMuted, fontSize: 13, lineHeight: 18 }),
    [_props.theme.colors.foregroundMuted],
  );

  async function save(patch: Partial<typeof values>): Promise<void> {
    if (settings.status !== "ready") return;
    await settings.save({ ...settings.values, ...patch }, settings.revision);
  }

  return (
    <View>
      <SettingsSection title="Timeline messages">
        <Text style={hintStyle}>
          Controls how assistant replies render in the agent timeline. Reload or revisit a chat to
          refresh older messages.
        </Text>
        <SettingsCard>
          <SettingsSwitch
            label="Attention cards"
            hint="Turn **→ blocks into colored cards; off keeps markdown-only rendering"
            value={values.attentionCards}
            disabled={disabled}
            onValueChange={(attentionCards) => void save({ attentionCards })}
          />
          <SettingsSwitch
            label="Peer message cards"
            hint="Fold inbound pi-peer messages into a dedicated card with sender and body"
            value={values.peerCards}
            disabled={disabled}
            onValueChange={(peerCards) => void save({ peerCards })}
          />
          <SettingsSelect
            label="Peer card style"
            value={values.peerCardStyle}
            options={[...PEER_CARD_STYLE_OPTIONS]}
            disabled={disabled || !values.peerCards}
            onValueChange={(peerCardStyle) =>
              void save({ peerCardStyle: peerCardStyle as typeof values.peerCardStyle })
            }
          />
          <SettingsSwitch
            label="Message cards"
            hint="Give every assistant reply a neutral card so plain prose matches the Thinking and attention cards"
            value={values.proseCards}
            disabled={disabled}
            onValueChange={(proseCards) => void save({ proseCards })}
          />
          <SettingsSelect
            label="Tool calls"
            value={toolValues.style}
            options={[...TOOL_STYLE_OPTIONS]}
            disabled={toolDisabled}
            onValueChange={(style) =>
              toolSettings.status === "ready"
                ? void toolSettings.save({ style: style as "inline" | "card" }, toolSettings.revision)
                : undefined
            }
          />
          <SettingsSwitch
            label="Hide compaction rows"
            hint="Hide the Compacted notice that appears after context compaction"
            value={values.hideCompaction}
            disabled={disabled}
            onValueChange={(hideCompaction) => void save({ hideCompaction })}
          />
          <SettingsSwitch
            label="Stable streaming"
            hint="Hold incomplete sections as plain text until a block boundary closes"
            value={values.stableStreaming}
            disabled={disabled}
            onValueChange={(stableStreaming) => void save({ stableStreaming })}
          />
          <SettingsSelect
            label="Prose density"
            value={values.proseDensity}
            options={[...PROSE_DENSITY_OPTIONS]}
            disabled={disabled}
            onValueChange={(proseDensity) =>
              void save({ proseDensity: proseDensity as typeof values.proseDensity })
            }
          />
          <SettingsSelect
            label="Code blocks"
            value={values.codeStyle}
            options={[...CODE_STYLE_OPTIONS]}
            disabled={disabled}
            onValueChange={(codeStyle) => void save({ codeStyle: codeStyle as typeof values.codeStyle })}
          />
        </SettingsCard>
      </SettingsSection>
    </View>
  );
}
