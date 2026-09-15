import {
  CALL_RENDERER_KIND,
  CALL_RENDERER_VERSION,
  parseCall,
} from "./call-message.js";

type UserMessageItem = { type: "user_message"; text: string };
type TransformPhase = "streaming" | "complete";

/**
 * Fold a call delivery (marker-prefixed user message) into a call card.
 * Non-call user rows return undefined so other transformers keep theirs.
 */
export function transformCallMessage({ item, phase }: {
  item: UserMessageItem;
  phase: TransformPhase;
}) {
  const parsed = parseCall(item.text);
  if (!parsed) return undefined;
  return {
    items: [
      {
        type: "plugin" as const,
        kind: CALL_RENDERER_KIND,
        version: CALL_RENDERER_VERSION,
        data: { from: parsed.from, body: parsed.body, phase },
      },
    ],
  };
}
