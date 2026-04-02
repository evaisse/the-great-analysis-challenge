import { describe, expect, test } from "bun:test";

import { applyConcurrencyTimeoutCap } from "../tooling/concurrency.ts";

describe("applyConcurrencyTimeoutCap", () => {
  test("caps timeout_seconds to the workflow timeout", () => {
    const capped = applyConcurrencyTimeoutCap({ timeout_seconds: 300 }, 180);
    expect(capped.timeout_seconds).toBe(180);
  });

  test("keeps a smaller existing timeout", () => {
    const capped = applyConcurrencyTimeoutCap({ timeout_seconds: 120 }, 180);
    expect(capped.timeout_seconds).toBe(120);
  });

  test("leaves the profile unchanged without a timeout override", () => {
    const original = { timeout_seconds: 120, command: "concurrency quick" };
    const capped = applyConcurrencyTimeoutCap(original, undefined);
    expect(capped).toBe(original);
  });
});
