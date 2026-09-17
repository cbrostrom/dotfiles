/**
 * Module-level clock of the newest assistant-text item per agent, mirroring the
 * reasoning renderer's `latestTimestamps` store. The assistant-text renderers
 * (attention-message, markdown-message) publish their item timestamps here so the
 * reasoning renderer can tell trailing thinking (after the last assistant text)
 * from mid-answer thinking (sandwiched between answer fragments that models emit
 * when they reason mid-turn).
 */

const latestAssistantTimestamps = new Map<string, number>();
const listeners = new Set<() => void>();

export function publishAssistantTimestamp(agentId: string, timestamp: number): void {
  if (timestamp <= (latestAssistantTimestamps.get(agentId) ?? 0)) return;
  latestAssistantTimestamps.set(agentId, timestamp);
  for (const listener of listeners) listener();
}

export function subscribeAssistantTimestamps(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function readLatestAssistantTimestamp(agentId: string): number {
  return latestAssistantTimestamps.get(agentId) ?? 0;
}

// ---------------------------------------------------------------------------
// Split-fragment tracking (single global slot, transform-level state).
// Transforms receive no agentId, so continuation classification uses the most
// recently transformed assistant fragment regardless of agent.

export interface AssistantFragmentInfo {
  /** True when the fragment carried **→ attention markers. */
  hadMarker: boolean;
  text: string;
  at: number;
}

const CONTINUATION_WINDOW_MS = 90_000;
let lastAssistantFragment: AssistantFragmentInfo | null = null;

export function noteAssistantFragment(hadMarker: boolean, text: string): void {
  lastAssistantFragment = { hadMarker, text, at: Date.now() };
}

export function readLastAssistantFragment(): AssistantFragmentInfo | null {
  return lastAssistantFragment;
}

/** A no-marker complete fragment right after a marker-bearing answer fragment is
 * almost certainly a stream-split remnant (reasoning interrupted the answer),
 * not a fresh answer. Terminal punctuation on the previous fragment and an
 * upper-case start on this one both argue for a separate message instead. */
export function isContinuationFragment(text: string, prev: AssistantFragmentInfo | null): boolean {
  if (!prev || !prev.hadMarker) return false;
  if (Date.now() - prev.at > CONTINUATION_WINDOW_MS) return false;
  const prevEnd = prev.text.replace(/\s+$/, "").slice(-1);
  const terminalChars = new Set([".", "!", "?", "…", ":", "'", '"', "`"]);
  const prevEndsOpen = !terminalChars.has(prevEnd);
  const startsMid = /^[a-z,;:)\]}]/.test(text.trimStart());
  return prevEndsOpen || startsMid;
}
