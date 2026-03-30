import { describe, expect, test } from "bun:test";

import { extractConcurrencyPayload } from "../tooling/concurrency.ts";

describe("extractConcurrencyPayload", () => {
  test("parses JSON payloads containing additional colons", () => {
    const output = [
      "ready",
      'CONCURRENCY: {"profile":"quick","seed":12345,"workers":2,"runs":1,"checksums":["deadbeef"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":42,"ops_total":12}',
    ].join("\n");

    const [ok, payload, error] = extractConcurrencyPayload(output);

    expect(ok).toBe(true);
    expect(error).toBe("");
    expect(payload.profile).toBe("quick");
    expect(payload.seed).toBe(12345);
    expect(payload.checksums).toEqual(["deadbeef"]);
  });

  test("returns a parse error for malformed JSON payloads", () => {
    const output = 'CONCURRENCY: {"profile" "quick"}';

    const [ok, payload, error] = extractConcurrencyPayload(output);

    expect(ok).toBe(false);
    expect(payload).toEqual({});
    expect(error).toContain("Invalid JSON payload:");
  });
});
