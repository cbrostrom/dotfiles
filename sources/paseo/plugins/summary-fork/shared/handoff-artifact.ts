import { defineRpc } from "@getpaseo/plugin";
import { z } from "zod";

/** Handoff artifact contract. The plugin id is stamped on the session, so
 * only this plugin can call the save/delete RPCs. */
export const saveHandoff = defineRpc({
  name: "handover.saveArtifact",
  input: z.object({
    /** Raw approved summary text. */
    text: z.string(),
    /** Human-readable label from the source agent title. */
    sourceTitle: z.string(),
  }),
  output: z.object({
    /** Absolute path of the artifact on the daemon machine. */
    path: z.string(),
    id: z.string(),
  }),
});

export const HANDOFF_DIR = "handoffs";
/** Retention for the on-disk handoff copy. The copy is a convenience backup:
 * the receiving agent also gets the summary text as a Paseo attachment, so
 * losing the file never loses the handover. */
export const HANDOFF_TTL_MS = 7 * 24 * 60 * 60 * 1000;
