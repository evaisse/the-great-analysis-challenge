import { join } from "node:path";

import { afterEach, describe, expect, test } from "bun:test";

import { combineResults, validateAllResults } from "../tooling/ci.ts";
import { makeTempDir, readJsonFile, removePath, writeJsonFile, writeTextFile } from "../tooling/shared.ts";

const tempDirs: string[] = [];

afterEach(async () => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      await removePath(dir);
    }
  }
});

function benchmarkPayload(language: string) {
  return {
    language,
    timings: {
      build_seconds: 1,
      test_seconds: 1,
      analyze_seconds: 1,
      test_chess_engine_seconds: 1,
    },
    metadata: {
      language,
      version: "1.0",
      features: ["perft"],
    },
    status: "completed",
    docker: {
      make_build_skipped: false,
    },
    metrics: {
      tokens_count: 1,
      metric_version: "tokens-v2",
    },
  };
}

describe("benchmark result safety checks", () => {
  test("combineResults ignores concurrency payloads and writes fresh performance data", async () => {
    const root = makeTempDir("tgac-ci-combine-");
    tempDirs.push(root);

    const artifactsDir = join(root, "benchmark_artifacts");
    const reportsDir = join(root, "reports");
    const nestedArtifactDir = join(artifactsDir, "benchmark-rust-123");

    await writeJsonFile(join(nestedArtifactDir, "rust.json"), benchmarkPayload("rust"));
    await writeJsonFile(join(nestedArtifactDir, "rust-concurrency.json"), [
      { implementation: "rust", status: "failed", payload: null },
    ]);
    await writeTextFile(join(nestedArtifactDir, "rust.out.txt"), "benchmark output\n");
    await writeJsonFile(join(reportsDir, "stale.json"), benchmarkPayload("stale"));

    const combined = await combineResults({
      artifactsDir,
      reportsDir,
      expectedImplementations: ["rust"],
    });

    expect(combined).toBe(true);

    const validationExitCode = await validateAllResults(reportsDir, ["rust"]);
    expect(validationExitCode).toBe(0);
  });

  test("combineResults creates a synthetic build error report when an expected artifact is missing", async () => {
    const root = makeTempDir("tgac-ci-missing-");
    tempDirs.push(root);

    const artifactsDir = join(root, "benchmark_artifacts");
    const reportsDir = join(root, "reports");
    const nestedArtifactDir = join(artifactsDir, "benchmark-rust-123");

    await writeJsonFile(join(nestedArtifactDir, "rust.json"), benchmarkPayload("rust"));

    const combined = await combineResults({
      artifactsDir,
      reportsDir,
      expectedImplementations: ["rust", "python"],
    });

    expect(combined).toBe(true);

    const syntheticPython = await readJsonFile<any>(join(reportsDir, "python.json"));
    expect(syntheticPython.status).toBe("failed");
    expect(syntheticPython.report_status).toBe("failed");
    expect(syntheticPython.errors).toContain("build error: benchmark report missing");

    const validationExitCode = await validateAllResults(reportsDir, ["rust", "python"]);
    expect(validationExitCode).toBe(1);
  });

  test("validateAllResults tolerates missing expected reports when synthetic entries exist", async () => {
    const root = makeTempDir("tgac-ci-validate-");
    tempDirs.push(root);

    const reportsDir = join(root, "reports");

    await writeJsonFile(join(reportsDir, "rust.json"), benchmarkPayload("rust"));
    await writeJsonFile(join(reportsDir, "rust-concurrency.json"), [
      { implementation: "rust", status: "failed", payload: null },
    ]);
    await writeJsonFile(join(reportsDir, "python.json"), {
      ...benchmarkPayload("python"),
      report_status: "missing",
      status: "failed",
      errors: ["build error: benchmark report missing"],
      timings: {
        build_seconds: null,
        test_seconds: null,
        analyze_seconds: null,
        test_chess_engine_seconds: null,
      },
    });

    const exitCode = await validateAllResults(reportsDir, ["rust", "python"]);
    expect(exitCode).toBe(1);
  });

  test("combineResults marks invalid benchmark reports as failed build errors", async () => {
    const root = makeTempDir("tgac-ci-invalid-");
    tempDirs.push(root);

    const artifactsDir = join(root, "benchmark_artifacts");
    const reportsDir = join(root, "reports");
    const nestedArtifactDir = join(artifactsDir, "benchmark-javascript-123");

    await writeJsonFile(join(nestedArtifactDir, "javascript.json"), {
      ...benchmarkPayload("javascript"),
      timings: {
        analyze_seconds: 1,
        test_seconds: 1,
        test_chess_engine_seconds: 1,
      },
    });

    const combined = await combineResults({
      artifactsDir,
      reportsDir,
      expectedImplementations: ["javascript"],
    });

    expect(combined).toBe(true);

    const normalizedJavascript = await readJsonFile<any>(join(reportsDir, "javascript.json"));
    expect(normalizedJavascript.report_status).toBe("failed");
    expect(normalizedJavascript.errors).toContain("build error: Required timing field 'build_seconds' is missing");
  });
});
