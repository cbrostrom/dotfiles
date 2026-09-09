import { Linking, Platform } from "react-native";

export function openAgentInPaseoWorkspace(
  serverId: string,
  workspaceId: string,
  agentId: string,
): void {
  if (Platform.OS !== "web") {
    const encodedServerId = encodeURIComponent(serverId);
    const encodedWorkspaceId = encodeURIComponent(workspaceId);
    const encodedOpenIntent = encodeURIComponent(`agent:${agentId}`);
    const route = `/h/${encodedServerId}/workspace/${encodedWorkspaceId}?open=${encodedOpenIntent}`;
    void Linking.openURL(`paseo:/${route}`).catch(() => undefined);
    return;
  }

  const globalObj = globalThis as {
    CustomEvent?: new <T>(type: string, eventInitDict?: CustomEventInit<T>) => CustomEvent<T>;
    dispatchEvent?: (event: Event) => boolean;
    location?: { assign?: (url: string) => void; href?: string };
  };
  try {
    const CustomEventConstructor = globalObj.CustomEvent;
    const dispatch = globalObj.dispatchEvent;
    if (typeof dispatch === "function" && CustomEventConstructor) {
      const event = new CustomEventConstructor("paseo:web-notification-click", {
        detail: {
          data: {
            serverId,
            workspaceId,
            agentId,
          },
        },
        cancelable: true,
      });
      const prevented = !dispatch(event);
      if (prevented) return;
    }
  } catch {
    // Continue to location fallback.
  }

  try {
    const loc = globalObj.location;
    if (loc) {
      const encodedServerId = encodeURIComponent(serverId);
      const encodedWorkspaceId = encodeURIComponent(workspaceId);
      const route = `/h/${encodedServerId}/workspace/${encodedWorkspaceId}?open=${encodeURIComponent(`agent:${agentId}`)}`;
      if (typeof loc.assign === "function") {
        loc.assign(route);
      } else {
        loc.href = route;
      }
    }
  } catch {
    // Ignore navigation errors in headless environments.
  }
}
