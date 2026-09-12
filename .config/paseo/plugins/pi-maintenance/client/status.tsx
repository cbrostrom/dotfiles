import type { PluginButtonContentProps, PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useRpc } from "@getpaseo/plugin/client";
import { useEffect, useMemo, useState } from "react";
import { Pressable, Text, View } from "react-native";
import { checkUpdates, type UpdateStatus } from "../shared/updates.js";

type Theme = PluginSurfaceProps["theme"];
type Layout = PluginSurfaceProps["layout"];

function StatusRows({ status, theme }: { status: UpdateStatus; theme: Theme }) {
  const styles = useMemo(
    () => ({
      card: {
        gap: 6,
        borderWidth: 1,
        borderColor: theme.colors.border,
        borderRadius: 10,
        padding: 12,
        backgroundColor: theme.colors.surface1,
      },
      title: { color: theme.colors.foreground, fontWeight: "600" as const },
      detail: { color: theme.colors.foregroundMuted },
      warning: { color: theme.colors.statusWarning },
      error: { color: theme.colors.statusDanger },
    }),
    [theme],
  );

  if (status.updates.length === 0) {
    return (
      <View style={styles.card}>
        <Text style={styles.title}>Pi is up to date</Text>
        <Text style={styles.detail}>Checked {new Date(status.checkedAt).toLocaleString()}</Text>
        {status.errors.map((error) => <Text key={error} style={styles.error}>{error}</Text>)}
      </View>
    );
  }

  return (
    <View style={styles.card}>
      <Text style={styles.warning}>{status.updates.length} update{status.updates.length === 1 ? "" : "s"} available</Text>
      {status.updates.map((update) => (
        <View key={update.id}>
          <Text style={styles.title}>{update.label}</Text>
          <Text style={styles.detail}>{update.current} → {update.latest}</Text>
        </View>
      ))}
      {status.errors.map((error) => <Text key={error} style={styles.error}>{error}</Text>)}
    </View>
  );
}

function useUpdateStatus(force = false) {
  const load = useRpc(checkUpdates);
  const [status, setStatus] = useState<UpdateStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = async (forceRefresh = force) => {
    setLoading(true);
    setError(null);
    try {
      setStatus(await load({ force: forceRefresh }));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void refresh(false);
  }, []);

  return { status, error, loading, refresh };
}

export function PiUpdatesPopover({ theme }: PluginButtonContentProps) {
  const { status, error, loading } = useUpdateStatus();
  const detail = { color: theme.colors.foregroundMuted };
  const failure = { color: theme.colors.statusDanger };

  if (loading && !status) return <Text style={detail}>Checking Pi updates…</Text>;
  if (error) return <Text style={failure}>Update check failed: {error}</Text>;
  return status ? <StatusRows status={status} theme={theme} /> : null;
}

export function PiMaintenanceScreen({ theme, layout }: PluginSurfaceProps) {
  const { status, error, loading, refresh } = useUpdateStatus();
  const styles = useMemo(
    () => ({
      screen: {
        flex: 1,
        gap: 12,
        padding: layout.compact ? 16 : 24,
        backgroundColor: theme.colors.surface0,
      },
      title: { color: theme.colors.foreground, fontSize: layout.compact ? 20 : 24, fontWeight: "600" as const },
      detail: { color: theme.colors.foregroundMuted },
      error: { color: theme.colors.statusDanger },
      button: { alignSelf: "flex-start" as const, paddingHorizontal: 14, paddingVertical: 10, borderRadius: 8, backgroundColor: theme.colors.accent },
      buttonText: { color: theme.colors.accentForeground, fontWeight: "600" as const },
    }),
    [layout.compact, theme],
  );

  return (
    <View style={styles.screen}>
      <Text style={styles.title}>Pi maintenance</Text>
      <Text style={styles.detail}>Checks Pi, configured npm extensions, and configured git extensions once per day.</Text>
      {status ? <StatusRows status={status} theme={theme} /> : null}
      {error ? <Text style={styles.error}>Update check failed: {error}</Text> : null}
      <Pressable accessibilityRole="button" disabled={loading} onPress={() => void refresh(true)} style={styles.button}>
        <Text style={styles.buttonText}>{loading ? "Checking…" : "Check now"}</Text>
      </Pressable>
    </View>
  );
}
