import { z } from "zod";
import { parsePeerDelivery } from "./peer-message.js";

export const peerMessageSchema = z.object({
  sender: z.string(),
  cwd: z.string().nullable(),
  body: z.string(),
  /** Authority boundary from pi-peer; kept so the receiver-facing statement stays inspectable. */
  boundary: z.string().nullable(),
  replyHint: z.string().nullable(),
  /** Original envelope, used when peer cards are turned off in settings. */
  text: z.string(),
  phase: z.enum(["streaming", "complete"]),
});

export type PeerMessageData = z.output<typeof peerMessageSchema>;

type UserMessageItem = { type: "user_message"; text: string };
type TransformPhase = "streaming" | "complete";

/**
 * Fold an inbound pi-peer delivery into a peer card. Non-peer user rows
 * return undefined so Paseo keeps its original rendering.
 */
export function transformPeerMessage({ item, phase }: {
  item: UserMessageItem;
  phase: TransformPhase;
}) {
  const parsed = parsePeerDelivery(item.text);
  if (!parsed) return undefined;
  return {
    items: [
      {
        type: "plugin" as const,
        kind: "peer-message",
        version: 1,
        data: { ...parsed, text: item.text, phase },
      },
    ],
  };
}
