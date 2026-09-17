import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import {
  SettingsCard,
  SettingsSection,
  SettingsSelect,
  SettingsSwitch,
} from "@getpaseo/plugin/client/ui";
import { View } from "react-native";
import {
  DEFAULT_REASONING_PREFERENCES,
  reasoningPreferences,
  type ReasoningPreferences,
} from "../shared/reasoning.js";

const DISPLAY_MODES = [
  { label: "Expand latest", value: "expand_last" },
  { label: "Collapsed", value: "collapsed" },
  { label: "Always expanded", value: "expanded" },
  { label: "One-line", value: "line" },
  { label: "Hidden", value: "hidden" },
] as const;

export function ReasoningSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(reasoningPreferences);
  const values: ReasoningPreferences =
    settings.status === "ready" ? settings.values : DEFAULT_REASONING_PREFERENCES;
  const disabled = settings.status !== "ready" || settings.saving;

  async function save(patch: Partial<ReasoningPreferences>): Promise<void> {
    if (settings.status !== "ready") return;
    await settings.save({ ...settings.values, ...patch }, settings.revision);
  }

  return (
    <View>
      <SettingsSection title="Reasoning">
        <SettingsCard>
          <SettingsSelect
            label="Thinking blocks"
            hint="Which thinking items open automatically; modes are honored strictly, even while streaming"
            value={values.mode}
            options={[...DISPLAY_MODES]}
            disabled={disabled}
            onValueChange={(mode) => void save({ mode: mode as ReasoningPreferences["mode"] })}
          />
          <SettingsSwitch
            label="Reveal hidden thinking"
            hint="Hidden mode: show mid-answer thinking as faint one-liners instead of hiding it completely"
            value={values.revealHidden}
            disabled={disabled}
            onValueChange={(revealHidden) => void save({ revealHidden })}
          />
          <SettingsSwitch
            label="Rotate thinking label"
            hint="Swap the static Thinking label with item-stable phrases like Mulling or Weighing"
            value={values.rotateLabel}
            disabled={disabled}
            onValueChange={(rotateLabel) => void save({ rotateLabel })}
          />
        </SettingsCard>
      </SettingsSection>
    </View>
  );
}
