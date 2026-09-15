import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { SettingsCard, SettingsSection, SettingsSelect } from "@getpaseo/plugin/client/ui";
import { View } from "react-native";
import { reasoningPreferences } from "../shared/reasoning.js";

const DISPLAY_MODES = [
  { label: "Expand latest", value: "expand_last" },
  { label: "Collapsed", value: "collapsed" },
  { label: "Always expanded", value: "expanded" },
] as const;

export function ReasoningSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(reasoningPreferences);
  const disabled = settings.status !== "ready" || settings.saving;
  const mode = settings.status === "ready" ? settings.values.mode : "expand_last";

  return (
    <View>
      <SettingsSection title="Reasoning">
        <SettingsCard>
          <SettingsSelect
            label="Thinking blocks"
            hint="Choose which reasoning cards open automatically"
            value={mode}
            options={[...DISPLAY_MODES]}
            disabled={disabled}
            onValueChange={(nextMode) => {
              if (settings.status !== "ready") return;
              void settings.save({ mode: nextMode }, settings.revision);
            }}
          />
        </SettingsCard>
      </SettingsSection>
    </View>
  );
}
