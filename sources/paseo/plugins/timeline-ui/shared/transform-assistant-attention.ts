import type { PluginTimelineItem } from "@getpaseo/plugin";
import { isBareAttentionMarker, parseAttentionBlocks } from "./attention-blocks.js";
import {
  isContinuationFragment,
  noteAssistantFragment,
  readLastAssistantFragment,
} from "./assistant-clock.js";
import { noteAssistantComplete } from "./split-probe.js";
import { parseCall, CALL_RENDERER_KIND, CALL_RENDERER_VERSION } from "./call-message.js";
import { parsePeerDelivery } from "./peer-message.js";

type AssistantMessageItem = {
  type: "assistant_message";
  text: string;
  messageId?: string;
};
type TransformPhase = "streaming" | "complete";

type TransformInput = {
  item: AssistantMessageItem;
  phase: TransformPhase;
};

function markdownPluginItem(
  text: string,
  phase: TransformPhase,
  continuation = false,
): PluginTimelineItem {
  return {
    type: "plugin",
    kind: "markdown-message",
    version: 3,
    data: continuation ? { text, phase, continuation } : { text, phase },
  };
}

export function transformAssistantAttention({ item, phase }: TransformInput) {
  // Call and pi-peer deliveries can surface as assistant items (peer relay does not
  // always arrive as user_message). Match the marker/envelope first so mail collapses
  // into its card instead of leaking as plain markdown. Normal assistant text never
  // starts with `[call:from=` or `Message from pi session`, so the surface is tiny.
  const call = parseCall(item.text);
  if (call) {
    return {
      items: [
        {
          type: "plugin" as const,
          kind: CALL_RENDERER_KIND,
          version: CALL_RENDERER_VERSION,
          data: { from: call.from, body: call.body, phase },
        },
      ],
    };
  }
  const peer = parsePeerDelivery(item.text);
  if (peer) {
    return {
      items: [
        {
          type: "plugin" as const,
          kind: "peer-message",
          version: 2,
          data: { ...peer, text: item.text, phase },
        },
      ],
    };
  }

  const hasMarker = item.text.includes("**→");

  // Stream split stranded the header/bold opener in its own fragment (body lands in
  // the next assistant_message item). Render nothing instead of a raw `**→`/`**` card.
  if (isBareAttentionMarker(item.text)) {
    return { items: [markdownPluginItem("", phase)] };
  }

  if (phase === "streaming" && hasMarker) {
    return { items: [markdownPluginItem(item.text, phase)] };
  }

  const parsed = phase === "complete" && hasMarker ? parseAttentionBlocks(item.text) : null;
  if (parsed) {
    noteAssistantFragment(true, item.text);
    noteAssistantComplete(item.messageId ?? `text:${item.text}`);
    let blockIndex = 0;
    return {
      items: [
        {
          type: "plugin" as const,
          kind: "attention-message",
          version: 6,
          data: {
            intro: parsed.intro,
            blocks: parsed.blocks.map((block, index) => ({
              title: block.title,
              body: block.body,
              variantIndex: index,
            })),
            outro: parsed.outro,
            segments: parsed.segments.map((segment) => {
              if (segment.kind === "prose") return segment;
              const variantIndex = blockIndex;
              blockIndex += 1;
              return {
                kind: "block" as const,
                title: segment.title,
                body: segment.body,
                variantIndex,
              };
            }),
            phase,
          },
        },
      ],
    };
  }

  if (phase === "complete") {
    const prev = readLastAssistantFragment();
    noteAssistantFragment(false, item.text);
    noteAssistantComplete(item.messageId ?? `text:${item.text}`);
    if (isContinuationFragment(item.text, prev)) {
      return { items: [markdownPluginItem(item.text, phase, true)] };
    }
  }
  return { items: [markdownPluginItem(item.text, phase)] };
}
