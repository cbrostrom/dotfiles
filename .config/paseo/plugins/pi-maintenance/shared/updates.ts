import { defineRpc } from "@getpaseo/plugin";
import { z } from "zod";

export const updateItemSchema = z.object({
  id: z.string(),
  label: z.string(),
  current: z.string(),
  latest: z.string(),
  source: z.enum(["pi", "npm", "git"]),
});

export const updateStatusSchema = z.object({
  checkedAt: z.string(),
  cached: z.boolean(),
  updates: z.array(updateItemSchema),
  errors: z.array(z.string()),
});

export const checkUpdates = defineRpc({
  name: "pi-maintenance.check",
  input: z.object({ force: z.boolean().optional() }),
  output: updateStatusSchema,
});

export type UpdateItem = z.output<typeof updateItemSchema>;
export type UpdateStatus = z.output<typeof updateStatusSchema>;
