import type { PluginButtonContentProps, PluginSurfaceProps } from "@getpaseo/plugin/client";
import { useRpc } from "@getpaseo/plugin/client";
import { useEffect, useMemo, useState } from "react";
import { Platform, Pressable, ScrollView, Text, View } from "react-native";
import {
  checkUpdates,
  runUpdates,
  updateProgress,
  type UpdateProgress,
  type UpdateStatus,
} from "../shared/updates.js";
import { notifyUpdateCheckNeeded } from "./update-events.js";

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

const POLL_MS = 2_000;

/**
 * Polls update progress while a run is active. Polling keeps working across a
 * daemon restart (the progress RPC reads the log file, not live state), and it
 * stops once the run reports finished so the screen is quiet again.
 */
function useUpdateProgress(active: boolean) {
  const load = useRpc(updateProgress);
  const [progress, setProgress] = useState<UpdateProgress | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!active) return;
    let stopped = false;
    const poll = async () => {
      try {
        const next = await load({});
        if (!stopped) {
          setProgress(next);
          setError(null);
        }
      } catch (cause) {
        if (!stopped) setError(cause instanceof Error ? cause.message : String(cause));
      }
    };
    void poll();
    const interval = setInterval(poll, POLL_MS);
    return () => {
      stopped = true;
      clearInterval(interval);
    };
  }, [active, load]);

  return { progress, error };
}

function UpdateSection({
  theme,
  running,
  progress,
  progressError,
  onStart,
}: {
  theme: Theme;
  running: boolean;
  progress: UpdateProgress | null;
  progressError: string | null;
  onStart: () => void;
}) {
  const styles = useMemo(
    () => ({
      button: {
        alignSelf: "flex-start" as const,
        paddingHorizontal: 14,
        paddingVertical: 10,
        borderRadius: 8,
        backgroundColor: theme.colors.accent,
      },
      buttonDisabled: { backgroundColor: theme.colors.surface2 },
      buttonText: { color: theme.colors.accentForeground, fontWeight: "600" as const },
      status: { color: theme.colors.foregroundMuted, marginTop: 8 },
      log: {
        color: theme.colors.foregroundMuted,
        fontFamily: Platform.select({ ios: "Menlo", default: "monospace" }),
        fontSize: 11,
        marginTop: 8,
      },
      failure: { color: theme.colors.statusDanger, marginTop: 8 },
    }),
    [theme],
  );

  const exitLine =
    progress?.exitCode == null
      ? null
      : progress.exitCode === 0
        ? "Update finished."
        : `Update exited with code ${progress.exitCode}.`;

  return (
    <View>
      <Pressable
        accessibilityRole="button"
        disabled={running}
        onPress={onStart}
        style={[styles.button, running ? styles.buttonDisabled : null]}
      >
        <Text style={styles.buttonText}>{running ? "Updating…" : "Update now"}</Text>
      </Pressable>
      {running ? <Text style={styles.status}>Running `pi update --all` in the background…</Text> : null}
      {exitLine ? <Text style={styles.status}>{exitLine}</Text> : null}
      {progressError ? <Text style={styles.failure}>Progress unavailable: {progressError}</Text> : null}
      {progress && progress.logTail.trim() ? (
        <ScrollView style={{ maxHeight: 160 }}>
          <Text style={styles.log}>{progress.logTail.trimEnd()}</Text>
        </ScrollView>
      ) : null}
    </View>
  );
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
  const startRun = useRpc(runUpdates);
  const [updating, setUpdating] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);
  const { progress, error: progressError } = useUpdateProgress(updating);

  const startUpdate = async () => {
    setStartError(null);
    try {
      await startRun({});
      setUpdating(true);
    } catch (cause) {
      setStartError(cause instanceof Error ? cause.message : String(cause));
    }
  };

  // Runs until the poller reports the background process finished, then flips
  // off and re-checks what is outdated so the list matches what was installed.
  const running = updating && (progress?.running ?? true);
  useEffect(() => {
    if (updating && progress != null && !progress.running && progress.finishedAt != null) {
      setUpdating(false);
      void refresh(true);
      // The pill module keeps its own status; tell it to re-check too.
      notifyUpdateCheckNeeded();
    }
  }, [updating, progress, refresh]);

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
      <UpdateSection
        theme={theme}
        running={running}
        progress={progress}
        progressError={progressError}
        onStart={() => void startUpdate()}
      />
      {startError ? <Text style={styles.error}>Could not start update: {startError}</Text> : null}
      <Pressable accessibilityRole="button" disabled={loading} onPress={() => void refresh(true).then(() => notifyUpdateCheckNeeded())} style={styles.button}>
        <Text style={styles.buttonText}>{loading ? "Checking…" : "Check now"}</Text>
      </Pressable>
    </View>
  );
}
