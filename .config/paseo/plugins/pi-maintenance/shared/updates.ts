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

/**
 * Starts `pi update --all` detached on the daemon machine. Returns immediately;
 * progress arrives through `updateProgress`. A run already in progress is not
 * started twice.
 */
export const runUpdates = defineRpc({
  name: "pi-maintenance.update",
  input: z.object({}),
  output: z.object({
    started: z.boolean(),
    alreadyRunning: z.boolean(),
    startedAt: z.string().nullable(),
    logPath: z.string(),
  }),
});

export const updateProgressSchema = z.object({
  running: z.boolean(),
  startedAt: z.string().nullable(),
  finishedAt: z.string().nullable(),
  exitCode: z.number().nullable(),
  logPath: z.string(),
  logTail: z.string(),
});

export type UpdateProgress = z.output<typeof updateProgressSchema>;

export const updateProgress = defineRpc({
  name: "pi-maintenance.update-progress",
  input: z.object({}),
  output: updateProgressSchema,
});

export type UpdateItem = z.output<typeof updateItemSchema>;
export type UpdateStatus = z.output<typeof updateStatusSchema>;
