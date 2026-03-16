import { join } from "node:path";

import { afterEach, describe, expect, test } from "bun:test";

import { makeTempDir, removePath, readJsonFile, writeJsonFile } from "../tooling/shared.ts";
import { refreshSemanticReportMetrics } from "../tooling/refresh-report-metrics.ts";

const tempDirs: string[] = [];

afterEach(async () => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      await removePath(dir);
    }
  }
});

describe("refresh report metrics", () => {
  test("enriches per-implementation reports and performance_data with semantic metrics", async () => {
    const reportDir = makeTempDir("tgac-refresh-report-metrics-");
    tempDirs.push(reportDir);

    await writeJsonFile(join(reportDir, "python.json"), [
      {
        language: "python",
        path: "implementations/python",
        metrics: {
          tokens_count: 1,
          metric_version: "tokens-v2",
        },
        semantic_metrics: null,
      },
    ]);

    await writeJsonFile(join(reportDir, "performance_data.json"), [
      {
        language: "python",
        path: "implementations/python",
        metrics: {
          tokens_count: 1,
          metric_version: "tokens-v2",
        },
        semantic_metrics: null,
      },
      {
        implementation: "missing-language",
        payload: null,
      },
    ]);

    const stats = await refreshSemanticReportMetrics(reportDir);
    expect(stats.filesTouched).toBe(2);
    expect(stats.entriesUpdated).toBe(2);
    expect(stats.entriesSkipped).toBe(1);

    const pythonReport = await readJsonFile<any[]>(join(reportDir, "python.json"));
    expect(pythonReport[0].size.source_loc).toBeGreaterThan(0);
    expect(pythonReport[0].metrics.tokens_count).toBeGreaterThan(0);
    expect(pythonReport[0].semantic_metrics.metric_version).toBe("tokens-v3");
    expect(pythonReport[0].semantic_metrics.complexity_score).toBeGreaterThan(0);

    const performanceData = await readJsonFile<any[]>(join(reportDir, "performance_data.json"));
    expect(performanceData[0].size.source_files).toBeGreaterThan(0);
    expect(performanceData[0].semantic_metrics.semantic_tokens).toBeGreaterThan(0);
    expect(performanceData[1].semantic_metrics ?? null).toBeNull();
  });
});
