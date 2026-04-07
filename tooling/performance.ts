import { basename, join, resolve } from "node:path";
import { existsSync } from "node:fs";

import {
  collectImplMetricsFromMetadata,
  discoverImplementationDirs,
  executePhase,
  formatGroupedInt,
  formatStepMetric,
  formatTime,
  getMetadata,
  normalizeFeatureName,
  readTextFile,
  resolveImplPath,
  runCommand,
  writeJsonFile,
  writeTextFile,
} from "./shared.ts";
import { ChessEngineTester, TestSuite, TRACK_TO_SUITE } from "./chess.ts";
import { collectSemanticMetrics, toSemanticMetricsSubset } from "./semantic-tokens.ts";

export interface BenchmarkResult {
  language: string;
  path: string;
  metadata: Record<string, unknown>;
  track: string;
  profile: string;
  timings: Record<string, number | null>;
  memory: Record<string, Record<string, number | string | boolean>>;
  size: Record<string, number>;
  metrics: Record<string, unknown>;
  normalized: Record<string, number>;
  docker: Record<string, unknown>;
  task_results: Record<string, boolean>;
  scores: Record<string, Record<string, number>>;
  test_results: Record<string, unknown>;
  semantic_metrics?: Record<string, unknown>;
  errors: string[];
  status: "pending" | "completed" | "failed";
}

async function collectMetrics(implPath: string, metadata: Record<string, unknown>, result: BenchmarkResult): Promise<void> {
  try {
    const metrics = await collectImplMetricsFromMetadata(implPath, metadata);
    result.size = {
      source_loc: Number(metrics.source_loc ?? 0),
      source_files: Number(metrics.source_files ?? 0),
    };
    result.metrics = {
      tokens_count: metrics.tokens_count ?? null,
      metric_version: metrics.metric_version,
    };
    console.log(
      `📏 Source size: ${result.size.source_loc} LOC across ${result.size.source_files} files, ${result.metrics.tokens_count} TOKENS`,
    );
  } catch (error) {
    result.errors.push(`Code size metrics error: ${error instanceof Error ? error.message : String(error)}`);
    result.size = { source_loc: 0, source_files: 0 };
    result.metrics = { tokens_count: null };
  }

  const semantic = await collectSemanticMetrics(implPath);
  if (semantic) {
    result.semantic_metrics = toSemanticMetricsSubset(semantic);
    console.log(
      `🧠 Semantic: complexity_score=${semantic.complexity_score}, semantic_tokens=${semantic.semantic_tokens}`,
    );
  }
}

async function buildImage(implPath: string, imageName: string): Promise<{ success: boolean; seconds: number; stdout: string; stderr: string }> {
  const startedAt = Bun.nanoseconds();
  const result = await runCommand(["docker", "build", "-t", imageName, "."], {
    cwd: implPath,
    check: false,
    timeoutMs: 20 * 60 * 1000,
  });
  return {
    success: result.exitCode === 0,
    seconds: Number(Bun.nanoseconds() - startedAt) / 1_000_000_000,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

function memoryPlaceholder(source = "unavailable"): Record<string, number | string | boolean> {
  return {
    memory_mb: 0,
    peak_memory_mb: 0,
    avg_cpu_percent: 0,
    psutil_available: false,
    source,
  };
}

async function runTrackSuiteStructured(
  implPath: string,
  metadata: Record<string, unknown>,
  imageName: string,
  track: string,
): Promise<{ success: boolean; seconds: number; score: Record<string, number>; errors: string[] }> {
  const suite = new TestSuite(TRACK_TO_SUITE[track] ?? TRACK_TO_SUITE.v1);
  await suite.loadTests();
  const tester = new ChessEngineTester(implPath, metadata, imageName);
  const started = Bun.nanoseconds();
  const errors: string[] = [];
  let passed = 0;
  let failed = 0;

  if (!(await tester.start())) {
    errors.push(...tester.results.errors);
    return {
      success: false,
      seconds: Number(Bun.nanoseconds() - started) / 1_000_000_000,
      score: { passed: 0, failed: 1, errors: tester.results.errors.length || 1, total: 1 },
      errors,
    };
  }

  try {
    const featureSet = new Set(
      Array.isArray(metadata.features) ? metadata.features.map((value) => normalizeFeatureName(String(value))) : [],
    );
    for (const test of suite.tests) {
      if (test.optional) {
        const normalizedName = normalizeFeatureName(test.name);
        if (!featureSet.has(normalizedName)) {
          continue;
        }
      }
      const success = await suite.runTest(tester, test);
      if (success) {
        passed += 1;
      } else {
        failed += 1;
      }
    }
    errors.push(...tester.results.errors);
  } finally {
    await tester.stop();
  }

  return {
    success: failed === 0 && errors.length === 0,
    seconds: Number(Bun.nanoseconds() - started) / 1_000_000_000,
    score: { passed, failed: failed + errors.length, errors: errors.length, total: passed + failed + errors.length },
    errors,
  };
}

function computeNormalizedMetrics(result: BenchmarkResult): void {
  const sourceLoc = Number(result.size.source_loc ?? 0);
  if (sourceLoc <= 0) {
    return;
  }
  const kloc = sourceLoc / 1000;
  const buildSeconds = Number(result.timings.build_seconds ?? 0);
  const analyzeSeconds = Number(result.timings.analyze_seconds ?? 0);
  const runtimeSeconds = Number(result.timings.test_seconds ?? 0);
  result.normalized = {
    build_ms_per_kloc: (buildSeconds * 1000) / kloc,
    analyze_ms_per_kloc: (analyzeSeconds * 1000) / kloc,
    runtime_ms_per_kloc: (runtimeSeconds * 1000) / kloc,
  };
}

async function runSingleBenchmark(
  implPath: string,
  track: string,
  profile: string,
): Promise<BenchmarkResult> {
  const metadata = await getMetadata(implPath);
  const implName = basename(implPath);
  const language = String(metadata.language ?? implName);
  const imageName = `chess-${implName}`;
  const result: BenchmarkResult = {
    language,
    path: implPath,
    metadata,
    track,
    profile,
    timings: {},
    memory: {},
    size: {},
    metrics: {},
    normalized: {},
    docker: {},
    task_results: {},
    scores: {},
    test_results: {},
    errors: [],
    status: "pending",
  };

  console.log(`\n${"=".repeat(60)}`);
  console.log(`Testing ${language} implementation`);
  console.log(`Path: ${implPath}`);
  console.log(`${"=".repeat(60)}`);

  await collectMetrics(implPath, metadata, result);

  if (existsSync(join(implPath, "Makefile"))) {
    await runCommand(["make", "clean"], { cwd: implPath, check: false, timeoutMs: 30_000 });
  }

  const imageBuild = await buildImage(implPath, imageName);
  result.timings.image_build_seconds = imageBuild.seconds;
  result.memory.image = memoryPlaceholder();
  result.docker.image_build_success = imageBuild.success;
  result.docker.image_build_time = imageBuild.seconds;
  if (!imageBuild.success) {
    result.errors.push(`Docker build failed: ${(imageBuild.stderr || imageBuild.stdout).slice(0, 500)}`);
    result.test_results = { passed: [], failed: ["image"] };
    result.status = "failed";
    return result;
  }

  for (const phase of ["build", "analyze", "test"] as const) {
    const startedAt = Bun.nanoseconds();
    const execution = await executePhase(implPath, phase, imageName);
    const elapsed = Number(Bun.nanoseconds() - startedAt) / 1_000_000_000;
    result.timings[`${phase}_seconds`] = execution.skipped && execution.treatAsSuccessForValidation ? 0 : (execution.skipped ? null : elapsed);
    result.memory[phase] = execution.skipped ? memoryPlaceholder("skipped") : memoryPlaceholder("unavailable");
    result.docker[`make_${phase}_success`] = execution.returncode === 0;
    result.docker[`make_${phase}_time`] = execution.skipped ? null : elapsed;
    if (execution.skipped && execution.treatAsSuccessForValidation) {
      result.docker[`make_${phase}_skipped`] = true;
    }
    result.task_results[`make_${phase}`] = execution.returncode === 0;
    if (execution.returncode !== 0) {
      result.errors.push(`${phase} failed: ${(execution.stderr || execution.stdout).slice(0, 500)}`);
    }
  }

  const trackResult = await runTrackSuiteStructured(implPath, metadata, imageName, track);
  result.timings.test_chess_engine_seconds = trackResult.seconds;
  result.timings[`test_${track.replaceAll("-", "_")}_seconds`] = trackResult.seconds;
  result.memory.test_chess_engine = memoryPlaceholder("unavailable");
  result.docker.test_chess_engine_success = trackResult.success;
  result.docker.test_chess_engine_time = trackResult.seconds;
  result.task_results.make_test_chess_engine = trackResult.success;
  result.scores.make_test_chess_engine = trackResult.score;
  if (!trackResult.success) {
    result.errors.push(
      `track ${track} suite failed: ${trackResult.score.passed}/${trackResult.score.total} checks passed`,
    );
  }
  if (trackResult.errors.length > 0) {
    result.errors.push(...trackResult.errors.map((error) => `track ${track} suite: ${error}`));
  }

  result.scores.make_test = {
    passed: result.task_results.make_test ? 1 : 0,
    failed: result.task_results.make_test ? 0 : 1,
    total: 1,
  };

  result.test_results = {
    passed: Object.entries(result.task_results).filter(([, ok]) => ok).map(([key]) => key),
    failed: Object.entries(result.task_results).filter(([, ok]) => !ok).map(([key]) => key),
  };

  computeNormalizedMetrics(result);
  const allTasksSucceeded = Object.values(result.task_results).every(Boolean);
  result.status = result.errors.length === 0 && allTasksSucceeded ? "completed" : "failed";
  return result;
}

export function generatePerformanceReport(results: BenchmarkResult[]): string {
  const lines: string[] = [];
  lines.push("=".repeat(80));
  lines.push("CHESS ENGINE PERFORMANCE TEST REPORT");
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push("=".repeat(80));
  lines.push("");
  lines.push("PERFORMANCE SUMMARY");
  lines.push("-".repeat(178));
  lines.push(
    `${"Language".padEnd(12)} ${"Status".padEnd(10)} ${"TOKENS".padEnd(10)} ${"LOC".padEnd(8)} ${"make build".padEnd(18)} ${"make analyze".padEnd(18)} ${"make test".padEnd(18)} ${"make test-chess-engine".padEnd(25)} ${"make test score".padEnd(16)} ${"make test-ce score".padEnd(18)}`,
  );
  lines.push("-".repeat(178));

  for (const result of [...results].sort((a, b) => a.language.localeCompare(b.language))) {
    const buildMem = Number(result.memory.build?.peak_memory_mb ?? 0);
    const analyzeMem = Number(result.memory.analyze?.peak_memory_mb ?? 0);
    const testMem = Number(result.memory.test?.peak_memory_mb ?? 0);
    const ceMem = Number(result.memory.test_chess_engine?.peak_memory_mb ?? 0);
    const makeTestScore = result.scores.make_test?.total
      ? `${result.scores.make_test.passed}/${result.scores.make_test.total}`
      : result.task_results.make_test ? "1/1" : "0/1";
    const makeCeScore = result.scores.make_test_chess_engine?.total
      ? `${result.scores.make_test_chess_engine.passed}/${result.scores.make_test_chess_engine.total}`
      : result.task_results.make_test_chess_engine ? "1/1" : "0/1";

    lines.push(
      `${result.language.slice(0, 11).padEnd(12)} ${result.status.slice(0, 9).padEnd(10)} ${String(result.metrics.tokens_count ?? "-").padEnd(10)} ${String(result.size.source_loc ?? 0).padEnd(8)} ${formatStepMetric(result.timings.build_seconds ?? null, buildMem).padEnd(18)} ${formatStepMetric(result.timings.analyze_seconds ?? null, analyzeMem).padEnd(18)} ${formatStepMetric(result.timings.test_seconds ?? null, testMem).padEnd(18)} ${formatStepMetric(result.timings.test_chess_engine_seconds ?? null, ceMem).padEnd(25)} ${makeTestScore.padEnd(16)} ${makeCeScore.padEnd(18)}`,
    );
  }

  for (const result of results) {
    lines.push(`\n${"=".repeat(60)}`);
    lines.push(`DETAILED RESULTS: ${result.language.toUpperCase()}`);
    lines.push("=".repeat(60));
    lines.push(`Implementation: ${result.path}`);
    lines.push(`Track: ${result.track}`);
    lines.push(`Profile: ${result.profile}`);
    lines.push(`Status: ${result.status}`);
    if (result.errors.length > 0) {
      lines.push("Errors:");
      for (const error of result.errors) {
        lines.push(`  - ${error}`);
      }
    }
    lines.push("Timings:");
    for (const [key, value] of Object.entries(result.timings)) {
      lines.push(`  - ${key}: ${formatTime(value ?? null)}`);
    }
    lines.push(`Metrics: TOKENS=${formatGroupedInt(Number(result.metrics.tokens_count ?? 0))}, LOC=${formatGroupedInt(result.size.source_loc)}`);
  }

  return `${lines.join("\n")}\n`;
}

export interface PerformanceOptions {
  impl?: string;
  output?: string;
  json?: string;
  timeout?: number;
  track?: string;
  profile?: "quick" | "full";
}

export async function runPerformanceBenchmarks(options: PerformanceOptions): Promise<number> {
  const track = options.track ?? "v1";
  const profile = options.profile ?? "quick";
  const implementations = options.impl
    ? [resolveImplPath(options.impl)]
    : await discoverImplementationDirs(resolve(process.cwd(), "implementations"));

  const results: BenchmarkResult[] = [];
  for (const implPath of implementations) {
    results.push(await runSingleBenchmark(implPath, track, profile));
  }

  const report = generatePerformanceReport(results);
  console.log(report);

  if (options.output) {
    await writeTextFile(options.output, report);
  }
  if (options.json) {
    if (results.length === 1) {
      await writeJsonFile(options.json, results[0]);
    } else {
      await writeJsonFile(options.json, results);
    }
  }

  return results.every((result) => result.status === "completed") ? 0 : 1;
}
