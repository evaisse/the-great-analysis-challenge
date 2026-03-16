import { existsSync } from "node:fs";
import { join } from "node:path";

import { describe, expect, test } from "bun:test";

import { collectCodeSizeMetricsForImpl } from "../tooling/code-size-metrics.ts";
import {
  SEMANTIC_METRIC_VERSION,
  collectSemanticMetrics,
} from "../tooling/semantic-tokens.ts";
import { runCommand } from "../tooling/shared.ts";

const PYTHON_IMPL = join(process.cwd(), "implementations", "python");
const RUST_IMPL = join(process.cwd(), "implementations", "rust");
const SCRIPT_PATH = join(process.cwd(), "scripts", "semantic-tokens", "semantic_tokens.mjs");

describe("semantic token metrics", () => {
  test("semantic metric version constant", () => {
    expect(SEMANTIC_METRIC_VERSION).toBe("tokens-v3");
  });

  test("semantic token script exists", () => {
    expect(existsSync(SCRIPT_PATH)).toBe(true);
  });

  test("semantic metrics work on a real implementation", async () => {
    const result = await collectSemanticMetrics(PYTHON_IMPL);
    expect(result).not.toBeNull();
    expect(result?.metric_version).toBe("tokens-v3");
    expect(result?.complexity_score).toBeGreaterThan(0);
    expect(result?.semantic_tokens).toBeLessThanOrEqual(result?.total_tokens ?? 0);

    for (const category of ["keyword", "identifier", "type", "operator", "literal", "punctuation", "comment", "unknown"] as const) {
      expect(result?.by_category[category]).toBeGreaterThanOrEqual(0);
    }
  });

  test("semantic metrics return null for a nonexistent implementation", async () => {
    const result = await collectSemanticMetrics(join(process.cwd(), "implementations", "__missing__"));
    expect(result).toBeNull();
  });

  test("direct analyzer output matches the Bun metrics pipeline", async () => {
    const directResult = await runCommand([process.execPath, "run", SCRIPT_PATH, RUST_IMPL], {
      cwd: process.cwd(),
      check: true,
    });
    const direct = JSON.parse(directResult.stdout);
    const wrapped = await collectCodeSizeMetricsForImpl(RUST_IMPL);
    const semantic = wrapped.semantic_metrics as Record<string, any>;

    expect(direct.implementation).toBe("rust");
    expect(direct.size).toBeDefined();
    expect(direct.weights).toBeDefined();
    expect(semantic.metric_version).toBe(direct.metric_version);
    expect(semantic.complexity_score).toBe(direct.complexity_score);
    expect(semantic.total_tokens).toBe(direct.total_tokens);
    expect(semantic.semantic_tokens).toBe(direct.semantic_tokens);
    expect(semantic.by_category).toEqual(direct.by_category);
    expect(semantic.ratios).toEqual(direct.ratios);
  });
});
