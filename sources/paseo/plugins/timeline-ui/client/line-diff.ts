/**
 * Minimal line diff with LCS alignment, good enough to pair unchanged and
 * edited lines between oldString/newString for side-by-side display. Input is
 * capped per side; anything past the cap is ignored (rendered bodies truncate
 * before this matters in practice).
 */
export const MAX_DIFF_LINES = 400;

export type DiffRowKind = "same" | "removed" | "added";

export interface DiffRow {
  kind: DiffRowKind;
  left: string | null;
  right: string | null;
}

export function lineDiff(oldText: string, newText: string): DiffRow[] {
  if (!oldText.trim() && !newText.trim()) return [];
  const a = oldText.replace(/\n$/, "").split("\n").slice(0, MAX_DIFF_LINES);
  const b = newText.replace(/\n$/, "").split("\n").slice(0, MAX_DIFF_LINES);
  const m = a.length;
  const n = b.length;
  if (m * n > MAX_DIFF_LINES * MAX_DIFF_LINES) {
    // Degenerate input: zip lines, tint everything as changed.
    const rows: DiffRow[] = [];
    const max = Math.max(m, n);
    for (let i = 0; i < max; i++) {
      rows.push(
        i < m && i < n && a[i] === b[i]
          ? { kind: "same", left: a[i], right: b[i] }
          : {
              kind: "removed",
              left: i < m ? a[i] : null,
              right: i < n ? b[i] : null,
            },
      );
    }
    return rows;
  }

  // dp[i][j] = LCS length of a[i..] and b[j..]
  const width = n + 1;
  const dp = new Uint32Array((m + 1) * width);
  for (let i = m - 1; i >= 0; i--) {
    for (let j = n - 1; j >= 0; j--) {
      dp[i * width + j] =
        a[i] === b[j]
          ? dp[(i + 1) * width + j + 1] + 1
          : Math.max(dp[(i + 1) * width + j], dp[i * width + j + 1]);
    }
  }

  const rows: DiffRow[] = [];
  let i = 0;
  let j = 0;
  while (i < m && j < n) {
    if (a[i] === b[j]) {
      rows.push({ kind: "same", left: a[i], right: b[j] });
      i++;
      j++;
      continue;
    }
    // Standard LCS backtrack: when both lines differ, advance the side whose
    // remainder preserves the longer extension of the edit.
    if (dp[(i + 1) * width + j] >= dp[i * width + j + 1]) {
      rows.push({ kind: "removed", left: a[i], right: null });
      i++;
    } else {
      rows.push({ kind: "added", left: null, right: b[j] });
      j++;
    }
  }
  while (i < m) {
    rows.push({ kind: "removed", left: a[i], right: null });
    i++;
  }
  while (j < n) {
    rows.push({ kind: "added", left: null, right: b[j] });
    j++;
  }
  // Fold a removed row immediately followed by an added row into one paired
  // row so a replaced line renders on the same row in both columns.
  const paired: DiffRow[] = [];
  for (const row of rows) {
    const last = paired[paired.length - 1];
    if (row.kind === "added" && last && last.kind === "removed") {
      paired[paired.length - 1] = { kind: "removed", left: last.left, right: row.right };
    } else if (row.kind === "removed" && row.left !== null && last && last.kind === "added" && last.left === null) {
      paired[paired.length - 1] = { kind: "added", left: row.left, right: last.right };
    } else {
      paired.push(row);
    }
  }
  return paired;
}
