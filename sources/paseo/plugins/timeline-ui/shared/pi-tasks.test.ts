import { describe, expect, it } from "vitest";
import {
  hasActivePiTasks,
  parsePiTodoToolCall,
  piTaskListSchema,
  sameTaskList,
} from "./pi-tasks.js";
import { transformPiTodoToolCall } from "../client/transform-pi-tasks.js";

type ToolCallItem = Parameters<typeof parsePiTodoToolCall>[0];

function toolCall(details: unknown): ToolCallItem {
  return {
    type: "tool_call",
    name: "todo",
    status: "completed",
    detail: { type: "unknown", output: { details } },
  } as unknown as ToolCallItem;
}

describe("parsePiTodoToolCall", () => {
  it("parses the rpiv details.tasks shape", () => {
    const tasks = parsePiTodoToolCall(
      toolCall({
        tasks: [
          { id: 1, subject: "First", activeForm: "Doing first", status: "completed" },
          { id: 2, subject: "Second", status: "in_progress" },
          { id: 3, subject: "Deleted", status: "deleted" },
        ],
      }),
    );
    expect(tasks).toHaveLength(2);
    expect(tasks?.[0]).toMatchObject({
      id: "1",
      text: "First",
      activeForm: "Doing first",
      status: "completed",
    });
    expect(tasks?.[1]).toMatchObject({ id: "2", text: "Second", status: "in_progress" });
  });

  it("parses the pi example details.todos shape", () => {
    const tasks = parsePiTodoToolCall(
      toolCall({
        todos: [
          { id: 1, text: "Alpha", done: true },
          { text: "Beta", done: false },
        ],
      }),
    );
    expect(tasks).toHaveLength(2);
    expect(tasks?.[0]).toMatchObject({ text: "Alpha", status: "completed" });
    expect(tasks?.[1]).toMatchObject({ text: "Beta", status: "pending" });
  });

  it("rejects unrelated, incomplete, and malformed calls", () => {
    expect(parsePiTodoToolCall(toolCall({ other: true }))).toBeUndefined();
    expect(
      parsePiTodoToolCall({ ...toolCall([]), status: "running" } as unknown as ToolCallItem),
    ).toBeUndefined();
    expect(
      parsePiTodoToolCall({ ...toolCall([]), name: "read" } as unknown as ToolCallItem),
    ).toBeUndefined();
  });
});

describe("sameTaskList", () => {
  const a = [
    { text: "One", status: "completed" as const },
    { id: "2", text: "Two", status: "in_progress" as const, activeForm: "Doing two" },
  ];

  it("accepts equal lists", () => {
    expect(sameTaskList(a, structuredClone(a))).toBe(true);
  });

  it("rejects differences in length, status, text, and activeForm", () => {
    expect(sameTaskList(a, [a[0]])).toBe(false);
    expect(
      sameTaskList(a, [
        a[0],
        { ...a[1], status: "completed" as const },
      ]),
    ).toBe(false);
    expect(sameTaskList(a, [a[0], { ...a[1], text: "Changed" }])).toBe(false);
    expect(sameTaskList(a, [a[0], { ...a[1], activeForm: undefined }])).toBe(false);
  });
});

describe("transformPiTodoToolCall", () => {
  it("replaces a todo call with a pi-task-list plugin item", () => {
    const result = transformPiTodoToolCall({
      item: toolCall({ todos: [{ text: "Alpha", done: false }] }),
      phase: "complete",
    } as never);
    expect(result?.items).toHaveLength(1);
    const parsed = piTaskListSchema.parse((result?.items?.[0] as { data: unknown }).data);
    expect(parsed.tasks).toHaveLength(1);
  });

  it("leaves unrelated calls untouched", () => {
    expect(
      transformPiTodoToolCall({
        item: toolCall({ todos: [] }),
        phase: "complete",
      } as never),
    ).toBeUndefined();
  });

  it("flags the list as inactive when every task is completed", () => {
    expect(hasActivePiTasks([{ text: "One", status: "completed" }])).toBe(false);
  });
});
