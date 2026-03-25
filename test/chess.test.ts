import { describe, expect, test } from "bun:test";

import {
  buildHarnessContainerName,
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
