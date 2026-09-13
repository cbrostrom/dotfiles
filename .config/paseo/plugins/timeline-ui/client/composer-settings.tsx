import type { PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useSettings } from "@getpaseo/plugin/client";
import {
  SettingsCard,
  SettingsSection,
  SettingsSelect,
  SettingsSwitch,
} from "@getpaseo/plugin/client/ui";
import {
  composerPreferences,
  DEFAULT_COMPOSER_PREFERENCES,
  USAGE_DISPLAY_OPTIONS,
} from "../shared/composer-preferences.js";
import { publishComposerPreferences } from "./session-usage-pill.js";

export function ComposerSettings(_props: PluginSurfaceProps) {
  const settings = useSettings(composerPreferences);
  const values = settings.status === "ready" ? settings.values : DEFAULT_COMPOSER_PREFERENCES;
  const disabled = settings.status !== "ready" || settings.saving;

  async function save(patch: Partial<typeof values>): Promise<void> {
    if (settings.status !== "ready") return;
    const next = { ...settings.values, ...patch };
    if (await settings.save(next, settings.revision)) publishComposerPreferences(next);
  }

  return (
    <SettingsSection
      title="Composer"
      info="Choose which session metrics Timeline UI adds beside the composer."
    >
      <SettingsCard>
        <SettingsSwitch
          label="Session usage"
          hint="Show cumulative session cost above the composer"
          value={values.showSessionUsage}
          disabled={disabled}
          onValueChange={(showSessionUsage) => void save({ showSessionUsage })}
        />
        <SettingsSelect
          label="Usage label"
          value={values.usageDisplay}
          options={[...USAGE_DISPLAY_OPTIONS]}
          disabled={disabled || !values.showSessionUsage}
          onValueChange={(usageDisplay) => {
            if (usageDisplay !== "cost" && usageDisplay !== "cost_tokens") return;
            void save({ usageDisplay });
          }}
        />
      </SettingsCard>
    </SettingsSection>
  );
}
