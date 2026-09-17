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
  BORDER_STYLE_OPTIONS,
  COPY_FORMAT_OPTIONS,
  DEFAULT_CARD_PREFERENCES,
  OPACITY_OPTIONS,
  preferences,
} from "../shared/preferences.js";

export function CardSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(preferences);

  const values = settings.status === "ready" ? settings.values : DEFAULT_CARD_PREFERENCES;
  const disabled = settings.status !== "ready" || settings.saving;

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
      <SettingsSection title="Attention cards">
        <Text style={hintStyle}>
          Applies to timeline cards on every client connected to this host. Reload the chat if a
          change does not appear immediately.
        </Text>
        <SettingsCard>
          <SettingsSwitch
            label="Content icons"
            hint="Keyword-based Lucide icons from block title and body"
            value={values.showIcons}
            disabled={disabled}
            onValueChange={(showIcons) => void save({ showIcons })}
          />
          <SettingsSelect
            label="Border"
            hint="Box uses theme border; left/top use the block accent color"
            value={values.borderStyle}
            options={[...BORDER_STYLE_OPTIONS]}
            disabled={disabled}
            onValueChange={(borderStyle) =>
              void save({ borderStyle: borderStyle as typeof values.borderStyle })
            }
          />
          <SettingsSelect
            label="Background tint"
            hint="Opacity of the block accent color behind card text"
            value={values.backgroundOpacity}
            options={[...OPACITY_OPTIONS]}
            disabled={disabled}
            onValueChange={(backgroundOpacity) =>
              void save({
                backgroundOpacity: backgroundOpacity as typeof values.backgroundOpacity,
              })
            }
          />
          <SettingsSelect
            label="Copy format"
            hint="Default payload for copy buttons on cards and code blocks"
            value={values.copyFormat}
            options={[...COPY_FORMAT_OPTIONS]}
            disabled={disabled}
            onValueChange={(copyFormat) =>
              void save({ copyFormat: copyFormat as typeof values.copyFormat })
            }
          />
          <SettingsSwitch
            label="Project color accent"
            hint="Tint card accents with a stable per-chat color derived from the host; off keeps the theme accent"
            value={values.hostColorAccent}
            disabled={disabled}
            onValueChange={(hostColorAccent) => void save({ hostColorAccent })}
          />
        </SettingsCard>
      </SettingsSection>
    </View>
  );
}
