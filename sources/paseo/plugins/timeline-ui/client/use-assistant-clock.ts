import {
  publishAssistantTimestamp,
  readLatestAssistantTimestamp,
} from "../shared/assistant-clock.js";

/**
 * Publishes this assistant-text item's timestamp into the per-agent assistant
 * clock so the reasoning renderer can classify mid-answer vs trailing thinking.
 * Render-phase publish, mirroring the existing useIsLatest store in reasoning.tsx;
 * publication is a max-only idempotent write, so re-renders are harmless.
 */
export function useAssistantClock(agentId: string, timestamp: Date): void {
  const time = timestamp.getTime();
  if (time > readLatestAssistantTimestamp(agentId)) {
    publishAssistantTimestamp(agentId, time);
  }
}
