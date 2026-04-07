import { describe, expect, test } from "bun:test";

import {
  buildHarnessContainerName,
  commandOutputSettled,
  normalizeCommandOutputLines,
  outputHasTerminalKeyword,
  sanitizeContainerNameSegment,
} from "../tooling/chess.ts";

describe("harness Docker container naming", () => {
  test("sanitizes implementation names for Docker container usage", () => {
    expect(sanitizeContainerNameSegment("My Impl/Name")).toBe("my-impl-name");
    expect(sanitizeContainerNameSegment("...")).toBe("engine");
  });

  test("builds deterministic bounded harness container names", () => {
    const name = buildHarnessContainerName("/tmp/implementations/Type Script", 1_742_937_600_000);
    expect(name).toStartWith("tgac-harness-type-script-");
    expect(name.length).toBeLessThanOrEqual(80);
    expect(name).toMatch(/^[a-z0-9][a-z0-9_.-]*$/);
  });
});

describe("harness command output detection", () => {
  test("normalizes output lines by trimming blank lines", () => {
    expect(normalizeCommandOutputLines("\n PGN: moves=2 \n\n e4 e5 \n")).toEqual(["PGN: moves=2", "e4 e5"]);
  });

  test("detects terminal keywords used by v2-full commands", () => {
    expect(outputHasTerminalKeyword(["BOOK: enabled=true entries=2"])).toBe(true);
    expect(outputHasTerminalKeyword(["uciok", "readyok"])).toBe(true);
    expect(outputHasTerminalKeyword(["TRACE: enabled=true events=3"])).toBe(true);
  });

  test("settles after a quiet window for recognized command output", () => {
    expect(commandOutputSettled("PGN: moves=2\n1. e4 e5", 50)).toBe(false);
    expect(commandOutputSettled("PGN: moves=2\n1. e4 e5", 250)).toBe(true);
  });

  test("settles after a quiet window even without a keyword match", () => {
    expect(commandOutputSettled("1. e4 e5", 50)).toBe(false);
    expect(commandOutputSettled("1. e4 e5", 250)).toBe(true);
  });
});
