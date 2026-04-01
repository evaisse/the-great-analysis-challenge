import { afterEach, describe, expect, test } from "bun:test";

import { hasBuildErrorStatus, resolveReadmeStepMetrics } from "../tooling/update-readme.ts";

describe("README benchmark status rendering", () => {
  afterEach(() => {
    delete process.env.GITHUB_OUTPUT;
  });

  test("marks missing reports as build error", () => {
    const implData = {
      language: "python",
      report_status: "missing",
      status: "failed",
      timings: {},
    };

    expect(hasBuildErrorStatus(implData)).toBe(true);

    const metrics = resolveReadmeStepMetrics(implData, {});
    expect(metrics.hasBuildError).toBe(true);
    expect(metrics.build).toBe("build error");
    expect(metrics.analyze).toBe("-");
    expect(metrics.test).toBe("-");
    expect(metrics.testChessEngine).toBe("-");
  });

  test("marks invalid reports as build error", () => {
    const implData = {
      language: "javascript",
      report_status: "failed",
      status: "completed",
      timings: {
        analyze_seconds: 1,
        test_seconds: 1,
      },
      errors: ["build error: Required timing field 'build_seconds' is missing"],
    };

    expect(hasBuildErrorStatus(implData)).toBe(true);

    const metrics = resolveReadmeStepMetrics(implData, {});
    expect(metrics.hasBuildError).toBe(true);
    expect(metrics.build).toBe("build error");
    expect(metrics.analyze).toBe("-");
  });

  test("keeps timing metrics for fresh completed reports", () => {
    const implData = {
      language: "rust",
      report_status: "fresh",
      status: "completed",
      timings: {
        build_seconds: 1.25,
        analyze_seconds: 2.5,
        test_seconds: 3.75,
        test_chess_engine_seconds: 4.5,
      },
    };
    const memory = {
      build: { peak_memory_mb: 32 },
      analyze: { peak_memory_mb: 64 },
      test: { peak_memory_mb: 128 },
      test_chess_engine: { peak_memory_mb: 256 },
    };

    const metrics = resolveReadmeStepMetrics(implData, memory);
    expect(metrics.hasBuildError).toBe(false);
    expect(metrics.build).not.toBe("build error");
    expect(metrics.build).toContain("32 MB");
    expect(metrics.analyze).toContain("64 MB");
    expect(metrics.test).toContain("128 MB");
    expect(metrics.testChessEngine).toContain("256 MB");
  });
});
