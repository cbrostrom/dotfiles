/**
 * Hard-block expensive Cursor models in Pi.
 * enabledModels only scopes Ctrl+P; /model can still pick Claude etc.
 * This extension reverts any non-allowlisted cursor/* selection.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Base Cursor model IDs allowed (strip @context and :fast/:slow suffixes). */
const ALLOWED_CURSOR_BASE_IDS = new Set([
	"default",
	"auto",
	"auto-smart",
	"composer-2.5",
	"composer-2-5",
	"composer-2",
	"gpt-5.6-sol",
	"gpt-5.6-terra",
	"gpt-5.6-luna",
	"gpt-5-6-sol",
	"gpt-5-6-terra",
	"gpt-5-6-luna",
	"fable-5-1",
	"fable-5",
	"claude-fable-5-1",
	"claude-fable-5",
	"opus-5",
	"claude-opus-5",
]);

function cursorBaseId(modelId: string): string {
	return modelId.split("@")[0]?.split(":")[0] ?? modelId;
}

function isAllowedCursorModel(modelId: string): boolean {
	return ALLOWED_CURSOR_BASE_IDS.has(cursorBaseId(modelId));
}

export default function (pi: ExtensionAPI) {
	let reverting = false;

	pi.on("model_select", async (event, ctx) => {
		if (reverting) return;
		const model = event.model;
		if (!model || model.provider !== "cursor") return;
		if (isAllowedCursorModel(model.id)) return;

		const blocked = `${model.provider}/${model.id}`;
		ctx.ui.notify(
			`Blocked ${blocked} (not in allowlist). Use /scoped-models or add to cursor-model-guard.`,
			"error",
		);

		const fallback =
			ctx.modelRegistry.find("cursor", "composer-2.5") ??
			ctx.modelRegistry.find("cursor", "default") ??
			ctx.modelRegistry.find("opencode", "big-pickle") ??
			event.previousModel;

		if (!fallback) return;

		reverting = true;
		try {
			await pi.setModel(fallback);
		} finally {
			reverting = false;
		}
	});
}
