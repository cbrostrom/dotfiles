import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import { SettingsCard, SettingsSection, SettingsSelect } from "@getpaseo/plugin/client/ui";
import { View } from "react-native";
import { callPreferences } from "../shared/call-message.js";

const DISPLAY_MODES = [
  { label: "Expand latest", value: "expand_last" },
  { label: "Collapsed", value: "collapsed" },
  { label: "Always expanded", value: "expanded" },
] as const;

export function CallSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(callPreferences);
  const disabled = settings.status !== "ready" || settings.saving;
  const mode = settings.status === "ready" ? settings.values.mode : "expand_last";

  return (
    <View>
      <SettingsSection title="Calls">
        <SettingsCard>
          <SettingsSelect
            label="Call cards"
            hint="Choose which inbound call cards open automatically"
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
