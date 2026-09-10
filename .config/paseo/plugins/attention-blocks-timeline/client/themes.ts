import type { PluginClientContext } from "@getpaseo/plugin/client";

/**
 * Optional light theme only.
 *
 * For dark mode, use built-in **Zinc** in Settings → Appearance — a plugin `addTheme`
 * cannot be pixel-identical to Zinc (8 hex inputs → derived token ladder; built-in Zinc
 * sets surface1–4, sidebar, status, terminal explicitly). Timeline card stripe colors
 * are plugin-owned in shared/block-variants.ts and work on any theme, including Zinc.
 */
const DOTFILES_CARDS_LIGHT = {
  id: "dotfiles-cards-light",
  name: "Dotfiles Cards (Light)",
  appearance: "light" as const,
  colors: {
    background: "#ffffff",
    foreground: "#1a1a1e",
    raised: "#eef0f4",
    control: "#e2e6ec",
    border: "#d4d8e0",
    accent: "#2563eb",
    mutedForeground: "#5c6370",
    ring: "#2563eb",
  },
};

export function contributeThemes(client: PluginClientContext): void {
  client.addTheme(DOTFILES_CARDS_LIGHT);
}
