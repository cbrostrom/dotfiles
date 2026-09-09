import { usePaseo } from "@getpaseo/plugin/client";

export type PaseoApi = ReturnType<typeof usePaseo>;
export type PaseoAgentHandle = ReturnType<NonNullable<PaseoApi>["agents"]["ref"]>;
export type PaseoAgent = Awaited<ReturnType<NonNullable<PaseoApi>["agents"]["get"]>>;
export type PaseoAgentUpdate = Parameters<
  NonNullable<PaseoApi>["agents"]["subscribe"]
>[1] extends (update: infer U) => void
  ? U
  : never;
export type PaseoAgentSendOptions = Parameters<
  ReturnType<NonNullable<PaseoApi>["agents"]["ref"]>["send"]
>[1];
