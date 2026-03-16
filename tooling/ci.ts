import { basename, join, resolve } from "node:path";
import { existsSync } from "node:fs";
import { copyFileSync } from "node:fs";

import {
  IMPLEMENTATIONS_DIR,
  REPO_ROOT,
  discoverImplementationDirs,
  getMetadata,
  normalizeFeatureName,
  parseJsonOrNull,
  readJsonFile,
  runCommand,
  writeGithubOutput,
  writeJsonFile,
} from "./shared.ts";
import { runPerformanceBenchmarks } from "./performance.ts";
import { runConcurrencyHarness } from "./concurrency.ts";
import { runTestHarness } from "./chess.ts";

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

export async function combineResults(): Promise<boolean> {
  console.log("=== Combining Benchmark Results ===");
  await Bun.$`mkdir -p reports`.quiet();
  const glob = new Bun.Glob("benchmark_artifacts/**/*.{txt,json}");
  const allResults: Record<string, any>[] = [];

  for await (const file of glob.scan({ cwd: REPO_ROOT, onlyFiles: true })) {
    const src = join(REPO_ROOT, file);
    const dest = join(REPO_ROOT, "reports", basename(file));
    copyFileSync(src, dest);
  }

  const reportsGlob = new Bun.Glob("*.json");
  for await (const file of reportsGlob.scan({ cwd: join(REPO_ROOT, "reports"), onlyFiles: true })) {
    if (file.endsWith("performance_data.json")) continue;
    try {
      const data = await readJsonFile<any>(join(REPO_ROOT, "reports", file));
      if (Array.isArray(data)) allResults.push(...data);
      else allResults.push(data);
    } catch (error) {
      console.log(`Error reading ${file}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  if (allResults.length > 0) {
    await writeJsonFile(join(REPO_ROOT, "reports", "performance_data.json"), allResults);
    console.log(`Combined ${allResults.length} implementation results`);
  }

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

export async function validateAllResults(benchmarkDir = join(REPO_ROOT, "reports")): Promise<number> {
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
    if (!file.endsWith("performance_data.json")) {
      files.push(join(benchmarkDir, file));
    }
  }
  if (files.length === 0) {
    console.log("⚠️  No result files found in reports/");
    console.log("   This is acceptable if no benchmarks have been run yet.");
    return 0;
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
