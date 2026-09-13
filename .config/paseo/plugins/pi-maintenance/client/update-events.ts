/**
 * Tiny in-bundle event bus so UI surfaces (settings screen, popover) can tell
 * the pill module in index.client.tsx that update status should be re-checked
 * and re-published. Keeps pill state and screen state from drifting apart.
 */
type Listener = () => void;

const listeners = new Set<Listener>();

export function notifyUpdateCheckNeeded(): void {
  for (const listener of listeners) listener();
}

export function onUpdateCheckNeeded(listener: Listener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}
