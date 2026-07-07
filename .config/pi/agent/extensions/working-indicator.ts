/**
 * working-indicator — powerbar segment
 *
 * Shows an animated spinner in the powerbar while pi is thinking/working.
 * Registers a "working" segment that cycles through braille frames during
 * turn_start → turn_end. Clears when idle.
 *
 * After installing, enable the segment via `/extension-settings` → powerbar
 * left/right segments and toggle "Working Indicator" on.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const INTERVAL_MS = 100;
const SEGMENT_ID = "working";

export default function (pi: ExtensionAPI): void {
  let frameIndex = 0;
  let timer: ReturnType<typeof setTimeout> | null = null;

  function tick(): void {
    pi.events.emit("powerbar:update", {
      id: SEGMENT_ID,
      text: FRAMES[frameIndex % FRAMES.length],
      icon: "",
      color: "accent",
    });
    frameIndex++;
    timer = setTimeout(tick, INTERVAL_MS);
  }

  function startSpinner(): void {
    if (timer !== null) return;
    frameIndex = 0;
    tick();
  }

  function stopSpinner(): void {
    if (timer !== null) {
      clearTimeout(timer);
      timer = null;
    }
    // Emit with text=undefined to remove the segment from the bar
    pi.events.emit("powerbar:update", { id: SEGMENT_ID, text: undefined });
  }

  pi.on("session_start", async () => {
    pi.events.emit("powerbar:register-segment", {
      id: SEGMENT_ID,
      label: "Working Indicator",
    });
  });

  pi.on("turn_start", async () => {
    startSpinner();
  });

  pi.on("turn_end", async () => {
    stopSpinner();
  });
}
