import { basename, join, resolve } from "node:path";
import { existsSync } from "node:fs";
import { copyFileSync } from "node:fs";

import {
  IMPLEMENTATIONS_DIR,
  REPO_ROOT,
  collectImplMetricsFromMetadata,
  ensureDir,
  discoverImplementationDirs,
  getMetadata,
  normalizeFeatureName,
  readJsonFile,
  removePath,
  runCommand,
  writeGithubOutput,
  writeJsonFile,
} from "./shared.ts";
import { collectSemanticMetrics, toSemanticMetricsSubset } from "./semantic-tokens.ts";
import { runPerformanceBenchmarks } from "./performance.ts";
import { runConcurrencyHarness } from "./concurrency.ts";

export async function detectChanges(
  eventName: string,
  testAll = "false",
  baseSha = "",
  headSha = "",
  beforeSha = "",
): Promise<Record<string, string>> {
  console.log("=== Detecting Changed Implementations ===");
  let implementations = "";
  let hasChanges = false;

  if (testAll === "true" || ["schedule", "workflow_dispatch"].includes(eventName)) {
    implementations = "all";
    hasChanges = true;
  } else {
    let cmd: string[];
    if (eventName === "pull_request" && baseSha && headSha) {
      cmd = ["git", "diff", "--name-only", baseSha, headSha, "--", "implementations/"];
    } else if (beforeSha && beforeSha !== "0000000000000000000000000000000000000000") {
      cmd = ["git", "diff", "--name-only", beforeSha, "HEAD", "--", "implementations/"];
    } else {
      cmd = ["git", "diff", "--name-only", "HEAD~1", "HEAD", "--", "implementations/"];
    }
    try {
      const result = await runCommand(cmd, { check: true });
      const changed = new Set<string>();
      for (const line of result.stdout.split("\n").map((item) => item.trim()).filter(Boolean)) {
        const parts = line.split("/");
        if (parts[0] === "implementations" && parts[1]) {
          changed.add(parts[1]);
        }
      }
      implementations = [...changed].sort().join(" ");
      hasChanges = changed.size > 0;
    } catch (error) {
      console.log(`Error detecting changes: ${error instanceof Error ? error.message : String(error)}`);
      implementations = "";
      hasChanges = false;
    }
  }

  writeGithubOutput("implementations", implementations);
  writeGithubOutput("has-changes", String(hasChanges).toLowerCase());
  console.log(`Changed implementations: ${implementations}`);
  console.log(`Has changes: ${hasChanges}`);
  return { implementations, "has-changes": String(hasChanges).toLowerCase() };
}

export async function generateMatrix(changedImplementations = "all"): Promise<Record<string, any>> {
  console.log("=== Generating Matrix ===");
  let implementations = (await discoverImplementationDirs(IMPLEMENTATIONS_DIR)).map((path) => ({
    name: basename(path).replace(/^./, (letter) => letter.toUpperCase()),
    directory: join("implementations", basename(path)),
    dockerfile: "Dockerfile",
    engine: basename(path),
  }));

  if (changedImplementations !== "all") {
    const changed = new Set(changedImplementations.trim().split(/\s+/).filter(Boolean));
    implementations = implementations.filter((impl) => changed.has(impl.engine));
  }

  const matrix = { include: implementations };
  writeGithubOutput("matrix", JSON.stringify(matrix));
  console.log(`Generated matrix with ${implementations.length} implementations`);
  return matrix;
}

function isConcurrencyReportFile(fileName: string): boolean {
  return fileName.endsWith("-concurrency.json");
}

async function resolveExpectedImplementations(expectedImplementations?: string[]): Promise<Set<string>> {
  const expectedSet = new Set(
    (expectedImplementations ?? [])
      .map((item) => basename(String(item).trim()).toLowerCase())
      .filter(Boolean),
  );

  if (expectedSet.has("all")) {
    expectedSet.clear();
    for (const implPath of await discoverImplementationDirs(IMPLEMENTATIONS_DIR)) {
      expectedSet.add(basename(implPath).toLowerCase());
    }
  }

  return expectedSet;
}

async function clearGeneratedReportFiles(reportDir: string): Promise<void> {
  if (!existsSync(reportDir)) {
    return;
  }

  const glob = new Bun.Glob("*.{json,txt}");
  for await (const file of glob.scan({ cwd: reportDir, onlyFiles: true })) {
    await removePath(join(reportDir, file));
  }
}

async function buildSyntheticBenchmarkError(implName: string, reason: string): Promise<Record<string, any>> {
  const implPath = join(IMPLEMENTATIONS_DIR, implName);
  const metadata = await getMetadata(implPath);
  let size = { source_loc: 0, source_files: 0 };
  let metrics: Record<string, unknown> = {
    tokens_count: null,
    metric_version: null,
  };
  let semanticMetrics: Record<string, unknown> | undefined;

  try {
    const localMetrics = await collectImplMetricsFromMetadata(implPath, metadata);
    size = {
      source_loc: Number(localMetrics.source_loc ?? 0),
      source_files: Number(localMetrics.source_files ?? 0),
    };
    metrics = {
      tokens_count: localMetrics.tokens_count ?? null,
      metric_version: localMetrics.metric_version ?? null,
    };
  } catch (error) {
    console.log(`⚠️ ${implName}: unable to compute local metrics for synthetic report: ${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const semantic = await collectSemanticMetrics(implPath);
    if (semantic) {
      semanticMetrics = toSemanticMetricsSubset(semantic);
    }
  } catch (error) {
    console.log(`⚠️ ${implName}: unable to compute semantic metrics for synthetic report: ${error instanceof Error ? error.message : String(error)}`);
  }

  return {
    language: implName,
    path: implPath,
    metadata,
    track: "v2-full",
    profile: "quick",
    report_status: "missing",
    timings: {
      image_build_seconds: null,
      build_seconds: null,
      analyze_seconds: null,
      test_seconds: null,
      test_chess_engine_seconds: null,
    },
    memory: {},
    size,
    metrics,
    normalized: {},
    docker: {},
    task_results: {
      make_build: false,
      make_analyze: false,
      make_test: false,
      make_test_chess_engine: false,
    },
    scores: {},
    test_results: {
      passed: [],
      failed: ["make_build", "make_analyze", "make_test", "make_test_chess_engine"],
    },
    errors: [reason],
    status: "failed",
    ...(semanticMetrics ? { semantic_metrics: semanticMetrics } : {}),
  };
}

async function writeSyntheticBenchmarkErrorReport(reportsDir: string, implName: string, reason: string): Promise<Record<string, any>> {
  const synthetic = await buildSyntheticBenchmarkError(implName, reason);
  await writeJsonFile(join(reportsDir, `${implName}.json`), synthetic);
  return synthetic;
}

async function normalizeInvalidBenchmarkReport(reportFile: string, data: any): Promise<any> {
  const [isValid, issues] = await validateResultJson(reportFile);
  if (isValid) {
    return data;
  }

  const normalizeOne = (item: any): any => {
    const normalized = typeof item === "object" && item ? { ...item } : { language: basename(reportFile, ".json") };
    normalized.report_status = "failed";
    const existingErrors = Array.isArray(normalized.errors) ? normalized.errors.filter((entry: unknown) => typeof entry === "string") : [];
    const validationErrors = issues.map((issue) => `build error: ${issue}`);
    normalized.errors = [...new Set([...existingErrors, ...validationErrors])];
    return normalized;
  };

  const normalized = Array.isArray(data) ? data.map((item) => normalizeOne(item)) : normalizeOne(data);
  await writeJsonFile(reportFile, normalized);
  return normalized;
}

export async function combineResults(
  options: { artifactsDir?: string; reportsDir?: string; expectedImplementations?: string[] } = {},
): Promise<boolean> {
  console.log("=== Combining Benchmark Results ===");
  const artifactsDir = options.artifactsDir ?? join(REPO_ROOT, "benchmark_artifacts");
  const reportsDir = options.reportsDir ?? join(REPO_ROOT, "reports");

  if (!existsSync(artifactsDir)) {
    console.log(`❌ Benchmark artifacts directory not found: ${artifactsDir}`);
    return false;
  }

  await ensureDir(reportsDir);
  await clearGeneratedReportFiles(reportsDir);

  const glob = new Bun.Glob("**/*.{txt,json}");
  const allResults: Record<string, any>[] = [];
  let copiedBenchmarkJsonCount = 0;

  for await (const file of glob.scan({ cwd: artifactsDir, onlyFiles: true })) {
    const src = join(artifactsDir, file);
    const destName = basename(file);
    const dest = join(reportsDir, destName);
    copyFileSync(src, dest);
    if (destName.endsWith(".json") && destName !== "performance_data.json" && !isConcurrencyReportFile(destName)) {
      copiedBenchmarkJsonCount += 1;
    }
  }

  if (copiedBenchmarkJsonCount === 0) {
    console.log("⚠️ No benchmark result JSON artifacts were copied");
    const expectedSet = await resolveExpectedImplementations(options.expectedImplementations);
    if (expectedSet.size === 0) {
      return false;
    }
    for (const implName of [...expectedSet].sort()) {
      const synthetic = await writeSyntheticBenchmarkErrorReport(reportsDir, implName, "build error: benchmark report missing");
      allResults.push(synthetic);
    }
    await writeJsonFile(join(reportsDir, "performance_data.json"), allResults);
    console.log(`Created ${allResults.length} synthetic benchmark error report(s)`);
    console.log("✅ Benchmark results combined");
    return true;
  }

  const expectedSet = await resolveExpectedImplementations(options.expectedImplementations);
  if (expectedSet.size > 0) {
    const actualSet = new Set<string>();
    const reportsGlob = new Bun.Glob("*.json");
    for await (const file of reportsGlob.scan({ cwd: reportsDir, onlyFiles: true })) {
      if (file !== "performance_data.json" && !isConcurrencyReportFile(file)) {
        actualSet.add(basename(file, ".json").toLowerCase());
      }
    }
    const missing = [...expectedSet].filter((impl) => !actualSet.has(impl)).sort();
    if (missing.length > 0) {
      console.log(`⚠️ Missing expected benchmark artifacts: ${missing.join(", ")}`);
      for (const implName of missing) {
        await writeSyntheticBenchmarkErrorReport(reportsDir, implName, "build error: benchmark report missing");
      }
    }
  }

  const reportsGlob = new Bun.Glob("*.json");
  for await (const file of reportsGlob.scan({ cwd: reportsDir, onlyFiles: true })) {
    if (file === "performance_data.json" || isConcurrencyReportFile(file)) continue;
    try {
      const reportFile = join(reportsDir, file);
      const data = await readJsonFile<any>(reportFile);
      const normalized = await normalizeInvalidBenchmarkReport(reportFile, data);
      if (Array.isArray(normalized)) allResults.push(...normalized);
      else allResults.push(normalized);
    } catch (error) {
      console.log(`Error reading ${file}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  if (allResults.length === 0) {
    console.log("❌ No benchmark result payloads were available to combine");
    return false;
  }

  await writeJsonFile(join(reportsDir, "performance_data.json"), allResults);
  console.log(`Combined ${allResults.length} implementation results`);

  console.log("✅ Benchmark results combined");
  return true;
}

export async function validateResultJson(resultFile: string): Promise<[boolean, string[], string[]]> {
  const issues: string[] = [];
  const warnings: string[] = [];
  if (!existsSync(resultFile)) {
    issues.push(`Result file not found: ${resultFile}`);
    return [false, issues, warnings];
  }
  try {
    let data = await readJsonFile<any>(resultFile);
    if (Array.isArray(data)) {
      if (data.length === 0) {
        issues.push("Result file is empty list");
        return [false, issues, warnings];
      }
      data = data[0];
    }

    for (const field of ["language", "timings", "metadata", "status"]) {
      if (!(field in data)) {
        issues.push(`Missing critical field: ${field}`);
      }
    }
    if (data.status !== "completed") {
      issues.push(`Status is not 'completed': ${data.status}`);
    }

    const taskResults = typeof data.task_results === "object" && data.task_results ? data.task_results : {};
    for (const [taskName, taskOk] of Object.entries(taskResults)) {
      if (taskOk === false) {
        issues.push(`Task result indicates failure: ${taskName}`);
      }
    }

    const timings = data.timings ?? {};
    const docker = typeof data.docker === "object" ? data.docker : {};
    const makeBuildSkipped = Boolean(docker.make_build_skipped);
    if (!makeBuildSkipped && timings.build_seconds == null) {
      issues.push("Required timing field 'build_seconds' is missing");
    }
    if (timings.test_seconds == null) {
      issues.push("Required timing field 'test_seconds' is missing");
    }

    const metadata = data.metadata ?? {};
    if (Object.keys(metadata).length === 0) {
      issues.push("Metadata is empty");
    } else {
      for (const field of ["language", "version", "features"]) {
        if (!(field in metadata)) issues.push(`Metadata missing required field: ${field}`);
        else if (!metadata[field]) issues.push(`Metadata field '${field}' is empty`);
      }
    }

    if (!Array.isArray(metadata.features) || metadata.features.length === 0) {
      issues.push("Features list is empty");
    }

    const metrics = data.metrics ?? {};
    if (Object.keys(metrics).length === 0) {
      warnings.push("Metrics object missing - TOKENS may not be available in README");
    } else {
      if (metrics.tokens_count == null) warnings.push("metrics.tokens_count missing - README will display '-'");
      else if (!Number.isInteger(metrics.tokens_count) || metrics.tokens_count < 0) warnings.push(`metrics.tokens_count should be a non-negative integer, got: ${metrics.tokens_count}`);
      if (metrics.metric_version == null) warnings.push("metrics.metric_version missing");
      else if (typeof metrics.metric_version !== "string" || metrics.metric_version.trim() === "") warnings.push(`metrics.metric_version should be a non-empty string, got: ${metrics.metric_version}`);
    }

    const semanticMetrics = data.semantic_metrics ?? {};
    if (Object.keys(semanticMetrics).length > 0) {
      for (const field of ["metric_version", "complexity_score", "total_tokens", "semantic_tokens", "by_category", "ratios"]) {
        if (!(field in semanticMetrics)) {
          warnings.push(`semantic_metrics.${field} missing`);
        }
      }
    }
  } catch (error) {
    issues.push(`Error reading result file: ${error instanceof Error ? error.message : String(error)}`);
    return [false, issues, warnings];
  }
  return [issues.length === 0, issues, warnings];
}

export async function validateAllResults(
  benchmarkDir = join(REPO_ROOT, "reports"),
  expectedImplementations?: string[],
): Promise<number> {
  console.log("=".repeat(60));
  console.log("Validating Benchmark Result Files");
  console.log("=".repeat(60));

  if (!existsSync(benchmarkDir)) {
    console.log(`❌ Benchmark directory not found: ${benchmarkDir}`);
    console.log("   This is acceptable if no benchmarks have been run yet.");
    return 0;
  }

  const glob = new Bun.Glob("*.json");
  const files: string[] = [];
  for await (const file of glob.scan({ cwd: benchmarkDir, onlyFiles: true })) {
    if (file !== "performance_data.json" && !isConcurrencyReportFile(file)) {
      files.push(join(benchmarkDir, file));
    }
  }
  const expectedSet = await resolveExpectedImplementations(expectedImplementations);
  if (files.length === 0) {
    console.log("⚠️  No result files found in reports/");
    console.log("   This is acceptable if no benchmarks have been run yet.");
    return 0;
  }

  if (expectedSet.size > 0) {
    const actualSet = new Set(files.map((file) => basename(file, ".json").toLowerCase()));
    const missing = [...expectedSet].filter((impl) => !actualSet.has(impl)).sort();
    if (missing.length > 0) {
      console.log(`⚠️ Missing benchmark result files: ${missing.join(", ")}`);
    }
  }

  let allValid = true;
  const validationResults: Array<[string, boolean, string[], string[]]> = [];
  for (const file of files.sort()) {
    const language = basename(file, ".json");
    console.log(`Validating ${language}...`);
    const [isValid, issues, warnings] = await validateResultJson(file);
    validationResults.push([language, isValid, issues, warnings]);
    if (isValid) console.log("  ✅ Valid");
    else {
      console.log(`  ❌ Invalid - ${issues.length} issue(s):`);
      for (const issue of issues) console.log(`     - ${issue}`);
      allValid = false;
    }
    if (warnings.length > 0) {
      console.log(`  ⚠️ Warnings - ${warnings.length}:`);
      for (const warning of warnings) console.log(`     - ${warning}`);
    }
    console.log("");
  }

  console.log("=".repeat(60));
  console.log("Validation Summary");
  console.log("=".repeat(60));
  const validCount = validationResults.filter(([, valid]) => valid).length;
  const invalidCount = validationResults.length - validCount;
  const warningCount = validationResults.reduce((count, [, , , warnings]) => count + warnings.length, 0);
  console.log(`Total files: ${validationResults.length}`);
  console.log(`✅ Valid: ${validCount}`);
  console.log(`❌ Invalid: ${invalidCount}`);
  console.log(`⚠️ Warnings: ${warningCount}`);
  console.log(allValid ? "\n🎉 All result files are valid!" : "\n❌ Some result files have issues - please review and fix");
  return allValid ? 0 : 1;
}

export async function getTestConfig(implementation: string): Promise<Record<string, unknown>> {
  console.log("🔧 Reading test configuration from chess.meta...");
  const implPath = join(IMPLEMENTATIONS_DIR, implementation);
  if (!existsSync(implPath)) return {};
  const metadata = await getMetadata(implPath);
  const features = Array.isArray(metadata.features) ? metadata.features.map((item) => normalizeFeatureName(String(item))) : [];
  const config = {
    language: String(metadata.language ?? implementation),
    supports_interactive: features.includes("interactive"),
    supports_perft: features.includes("perft"),
    supports_ai: features.includes("ai"),
    test_mode: features.length > 3 ? "full" : "basic",
  };
  console.log(`Configuration: ${JSON.stringify(config)}`);
  return config;
}

export async function getAllTestConfigs(): Promise<Record<string, Record<string, unknown>>> {
  const configs: Record<string, Record<string, unknown>> = {};
  for (const implPath of await discoverImplementationDirs(IMPLEMENTATIONS_DIR)) {
    const implName = basename(implPath);
    configs[implName] = await getTestConfig(implName);
    console.log(`✅ ${implName}: ${configs[implName].language ?? "unknown"}`);
  }
  return configs;
}

export async function verifyMakeTarget(engine: string, target: string, timeout = 180): Promise<number> {
  console.log(`🛠️  Verifying 'make ${target} DIR=${engine}' from repository root...`);
  const result = await runCommand(["make", target, `DIR=${engine}`], {
    cwd: REPO_ROOT,
    check: false,
    timeoutMs: timeout * 1000,
  });
  if (result.stdout.trim()) console.log(`📤 Output:\n${result.stdout}`);
  if (result.stderr.trim()) console.log(`⚠️ Stderr:\n${result.stderr}`);
  if (result.exitCode !== 0) {
    console.log(`❌ make ${target} exited with status ${result.exitCode}`);
    return result.exitCode;
  }
  const combined = `${result.stdout}\n${result.stderr}`.toLowerCase();
  const changedMatch = combined.match(/\((\d+) changed\)/);
  if (changedMatch && changedMatch[1] !== "0") {
    console.log("❌ Formatter modified files; please commit formatting changes before running in CI");
    return 1;
  }
  console.log(`✅ make ${target} completed cleanly for ${engine}`);
  return 0;
}

export async function runBenchmarkCommand(implName: string, timeout = 60): Promise<number> {
  await Bun.$`mkdir -p reports`.quiet();
  const jsonPath = join(REPO_ROOT, "reports", `${implName}.json`);
  const outputPath = join(REPO_ROOT, "reports", `${implName}.out.txt`);
  return await runPerformanceBenchmarks({
    impl: join(IMPLEMENTATIONS_DIR, implName),
    json: jsonPath,
    output: outputPath,
    timeout,
  });
}

export async function createRelease(options: {
  versionType: "major" | "minor" | "patch";
  readmeChanged: string;
  excellentCount: number;
  goodCount: number;
  needsWorkCount: number;
  totalCount: number;
}): Promise<number> {
  console.log("=== Creating Release ===");
  let currentVersion = "v0.0.0";
  try {
    const result = await runCommand(["git", "tag", "--sort=-version:refname"], { check: true });
    const tags = result.stdout.split("\n").map((line) => line.trim()).filter((line) => /^v\d+\.\d+\.\d+$/.test(line));
    currentVersion = tags[0] ?? "v0.0.0";
  } catch {
    currentVersion = "v0.0.0";
  }

  const [major, minor, patch] = currentVersion.slice(1).split(".").map((part) => Number.parseInt(part, 10) || 0);
  let nextMajor = major;
  let nextMinor = minor;
  let nextPatch = patch;
  if (options.versionType === "major") {
    nextMajor += 1;
    nextMinor = 0;
    nextPatch = 0;
  } else if (options.versionType === "minor") {
    nextMinor += 1;
    nextPatch = 0;
  } else {
    nextPatch += 1;
  }
  const newVersion = `v${nextMajor}.${nextMinor}.${nextPatch}`;

  if (options.readmeChanged === "true") {
    await combineResults();
    await runCommand(["git", "add", "reports/", "README.md"], { cwd: REPO_ROOT, check: true });
    const commitMessage = `chore: update implementation status from benchmark suite\n\nBenchmark results summary:\n- Total implementations: ${options.totalCount}\n- 🟢 Excellent: ${options.excellentCount}\n- 🟡 Good: ${options.goodCount}\n- 🔴 Needs work: ${options.needsWorkCount}\n\nPerformance testing completed with status updates.`;
    await runCommand(["git", "commit", "-m", commitMessage], { cwd: REPO_ROOT, check: true });
    if (!process.env.GITHUB_ACTIONS) {
      await runCommand(["git", "push", "origin", "master"], { cwd: REPO_ROOT, check: true });
    }
  }

  await runCommand(["git", "tag", "-a", newVersion, "-m", `Release ${newVersion} - Benchmark Update`], {
    cwd: REPO_ROOT,
    check: true,
  });
  if (!process.env.GITHUB_ACTIONS) {
    await runCommand(["git", "push", "origin", newVersion], { cwd: REPO_ROOT, check: true });
  }
  writeGithubOutput("new_version", newVersion);
  console.log(`📤 Output: new_version=${newVersion}`);
  return 0;
}

async function dockerRunTest(engine: string, input: string): Promise<number> {
  const result = await runCommand(["docker", "run", "--network", "none", "--rm", "-i", `chess-${engine}`], {
    input,
    check: false,
    timeoutMs: 60_000,
  });
  if (result.stdout.trim()) console.log(result.stdout);
  if (result.stderr.trim()) console.log(result.stderr);
  return result.exitCode;
}

export async function testBasicCommands(engine: string): Promise<number> {
  return await dockerRunTest(engine, "help\nnew\ndisplay\nquit\n");
}

export async function testAdvancedFeatures(engine: string, supportsPerft = true, supportsAi = true): Promise<number> {
  const commands = ["new", "move e2e4", "move e7e5", "export"];
  if (supportsPerft) commands.push("perft 1");
  if (supportsAi) commands.push("ai 1");
  commands.push("quit");
  return await dockerRunTest(engine, `${commands.join("\n")}\n`);
}

export async function testDemoMode(engine: string): Promise<number> {
  return await dockerRunTest(engine, "new\nmove e2e4\nmove e7e5\nexport\nquit\n");
}

export async function cleanupDocker(engine: string): Promise<number> {
  await runCommand(["docker", "rmi", `chess-${engine}-test`], { check: false });
  await runCommand(["docker", "rmi", `chess-${engine}`], { check: false });
  return 0;
}
