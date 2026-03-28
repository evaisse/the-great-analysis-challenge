import { parseArgs } from "node:util";
import { join, resolve } from "node:path";

import {
  REPO_ROOT,
  executePhase,
  fileExists,
  makeTempDir,
  readTextFile,
  removePath,
  resolveImplPath,
  runCommand,
  writeGithubOutput,
} from "./shared.ts";
import { runErrorAnalysisCommand } from "./error-analysis.ts";
import { runTestHarness } from "./chess.ts";
import { runUnitContractSuite } from "./unit-contract.ts";
import { runVerify } from "./verify.ts";
import { runPerformanceBenchmarks } from "./performance.ts";
import { runConcurrencyHarness } from "./concurrency.ts";
import {
  cleanupDocker,
  combineResults,
  createRelease,
  detectChanges,
  generateMatrix,
  getAllTestConfigs,
  getTestConfig,
  runBenchmarkCommand,
  testAdvancedFeatures,
  testBasicCommands,
  testDemoMode,
  validateAllResults,
  verifyMakeTarget,
} from "./ci.ts";
import { runUpdateReadme } from "./update-readme.ts";
import { triageIssue } from "./issue-triage.ts";
import { runSemanticTokensCli } from "./semantic-tokens.ts";
import { runCodeSizeMetricsCli } from "./code-size-metrics.ts";
import { runRefreshReportMetricsCli } from "./refresh-report-metrics.ts";

async function runMetadataPhaseCli(args: string[]): Promise<number> {
  const { values } = parseArgs({
    args,
    options: {
      impl: { type: "string" },
      phase: { type: "string" },
      image: { type: "string" },
      workdir: { type: "string" },
    },
  });

  if (!values.impl || !values.phase) {
    console.error("Usage: ./workflow run-metadata-phase --impl <name|path> --phase <build|analyze|test|bugit|fix> [--image IMAGE] [--workdir DIR]");
    return 1;
  }

  try {
    const execution = await executePhase(values.impl, values.phase, values.image, values.workdir);
    if (execution.skipped) {
      console.log(execution.skipReason);
      return 0;
    }
    console.log(`Running ${execution.phase} for ${execution.implName} in ${values.workdir ? "workspace mount" : "Docker image"}...`);
    console.log(`Command: ${execution.command}`);
    if (execution.stdout) process.stdout.write(execution.stdout);
    if (execution.stderr) process.stderr.write(execution.stderr);
    return execution.returncode;
  } catch (error) {
    console.error(`ERROR: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}

async function runAnalyzeTools(): Promise<number> {
  const files = ["workflow", "scripts/semantic-tokens/semantic_tokens.mjs"];
  const glob = new Bun.Glob("tooling/**/*.ts");
  for await (const path of glob.scan({ cwd: REPO_ROOT, onlyFiles: true })) {
    files.push(path);
  }
  const testGlob = new Bun.Glob("test/**/*.ts");
  for await (const path of testGlob.scan({ cwd: REPO_ROOT, onlyFiles: true })) {
    files.push(path);
  }

  const outdir = makeTempDir("tgac-bun-analyze-");
  const failures: Array<[string, string]> = [];
  try {
    for (const file of files.sort()) {
      const absPath = resolve(REPO_ROOT, file);
      const result = await Bun.build({
        entrypoints: [absPath],
        outdir,
        target: "bun",
        format: "esm",
        sourcemap: "none",
      });
      if (!result.success) {
        failures.push([file, result.logs.map((log) => log.message).join("\n") || "unknown build error"]);
      }
    }
  } finally {
    await removePath(outdir);
  }

  if (failures.length > 0) {
    console.log("❌ Bun tooling static analysis failed:");
    for (const [path, message] of failures) {
      console.log(`  - ${path}: ${message}`);
    }
    console.log(`\nChecked ${files.length} file(s); ${failures.length} failure(s).`);
    return 1;
  }

  console.log(`✅ Bun tooling static analysis passed on ${files.length} file(s).`);
  return 0;
}

async function runCheckStatisticsFreshness(): Promise<number> {
  const statsFile = join(REPO_ROOT, "language_statistics.yaml");
  try {
    const data = Bun.YAML.parse(await readTextFile(statsFile)) as Record<string, any>;
    const metadata = data.metadata ?? {};
    const lastUpdated = metadata.last_updated;
    if (!lastUpdated) {
      console.log("❌ Error: No last_updated date found in statistics");
      return 1;
    }
    const parsed = new Date(lastUpdated);
    if (Number.isNaN(parsed.getTime())) {
      console.log(`❌ Error parsing date: ${lastUpdated}`);
      return 1;
    }

    const now = new Date();
    const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const daysOld = Math.floor((now.getTime() - parsed.getTime()) / (24 * 60 * 60 * 1000));
    console.log("📊 Language statistics status:");
    console.log(`   Last updated: ${lastUpdated}`);
    console.log(`   Days old: ${daysOld}`);
    console.log(`   TIOBE source: ${metadata.tiobe_source ?? "N/A"}`);
    console.log(`   GitHub source: ${metadata.github_source ?? "N/A"}`);
    console.log("");
    if (parsed < oneMonthAgo) {
      console.log("⚠️  Statistics are outdated (older than 30 days)");
      console.log(`   Please update ${statsFile} with fresh data.`);
      return 2;
    }
    console.log("✅ Statistics are fresh (less than 30 days old)");
    return 0;
  } catch (error) {
    console.log(`❌ Error loading ${statsFile}: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}

function helpText(): string {
  return [
    "workflow <command> [arguments]",
    "",
    "Core commands:",
    "  run-metadata-phase",
    "  error-analysis",
    "  test-harness",
    "  unit-contract",
    "  verify",
    "  analyze-tools",
    "  check-statistics-freshness",
    "  semantic-tokens",
    "  code-size-metrics",
    "  refresh-report-metrics",
    "",
    "CI/public commands:",
    "  detect-changes",
    "  generate-matrix",
    "  run-benchmark",
    "  test-chess-engine",
    "  benchmark-stress",
    "  benchmark-concurrency",
    "  verify-implementations",
    "  validate-results",
    "  combine-results",
    "  update-readme",
    "  create-release",
    "  test-basic-commands",
    "  test-advanced-features",
    "  test-demo-mode",
    "  cleanup-docker",
    "  get-test-config",
    "  verify-make-target",
    "  triage-issue",
  ].join("\n");
}

export async function main(argv: string[]): Promise<number> {
  const [command, ...args] = argv;
  if (!command || command === "--help" || command === "-h" || command === "help") {
    console.log(helpText());
    return 0;
  }

  if (command === "run-metadata-phase") {
    return await runMetadataPhaseCli(args);
  }

  if (command === "error-analysis") {
    const [subcommand, ...rest] = args;
    const { values } = parseArgs({
      args: rest,
      options: {
        impl: { type: "string" },
        image: { type: "string" },
        workspace: { type: "string" },
        "reset-workspace": { type: "boolean" },
        "report-json": { type: "string" },
        "report-text": { type: "string" },
      },
    });
    if (!subcommand || !values.impl) {
      console.error("Usage: ./workflow error-analysis <prepare|bugit|fix|benchmark> --impl <name|path> [options]");
      return 1;
    }
    return await runErrorAnalysisCommand({
      command: subcommand as any,
      impl: values.impl,
      image: values.image,
      workspace: values.workspace,
      resetWorkspace: Boolean(values["reset-workspace"]),
      reportJson: values["report-json"],
      reportText: values["report-text"],
    });
  }

  if (command === "test-harness" || command === "test-chess-engine") {
    const { values, positionals } = parseArgs({
      args,
      allowPositionals: true,
      options: {
        dir: { type: "string" },
        suite: { type: "string" },
        track: { type: "string" },
        "docker-image": { type: "string" },
        category: { type: "string" },
        impl: { type: "string" },
        test: { type: "string" },
        performance: { type: "boolean" },
        output: { type: "string" },
      },
    });
    const engine = command === "test-chess-engine" ? positionals[0] : undefined;
    const impl = values.impl ?? (engine ? join(REPO_ROOT, "implementations", engine) : undefined);
    return await runTestHarness({
      baseDir: values.dir ? resolve(values.dir) : undefined,
      suitePath: values.suite,
      track: values.track ?? (command === "test-chess-engine" ? "v1" : undefined),
      dockerImage: values["docker-image"] ?? (engine ? `chess-${engine}` : undefined),
      category: values.category,
      impl,
      testName: values.test,
      performance: Boolean(values.performance),
      output: values.output,
    });
  }

  if (command === "unit-contract") {
    const { values } = parseArgs({
      args,
      options: {
        impl: { type: "string" },
        suite: { type: "string" },
        "protocol-suite": { type: "string" },
        "docker-image": { type: "string" },
        "require-contract": { type: "boolean" },
      },
    });
    if (!values.impl) {
      console.error("Usage: ./workflow unit-contract --impl <name|path> [--suite FILE] [--protocol-suite FILE] [--docker-image IMAGE] [--require-contract]");
      return 1;
    }
    return await runUnitContractSuite({
      impl: values.impl,
      suite: values.suite,
      protocolSuite: values["protocol-suite"],
      dockerImage: values["docker-image"],
      requireContract: Boolean(values["require-contract"]),
    });
  }

  if (command === "verify" || command === "verify-implementations") {
    const { values, positionals } = parseArgs({
      args,
      options: {
        implementation: { type: "string" },
        "require-test-contract": { type: "boolean" },
      },
      allowPositionals: true,
    });
    const baseDir = values.implementation ? undefined : positionals[0];
    const verification = await runVerify({
      baseDir: baseDir ? resolve(baseDir) : REPO_ROOT,
      implementation: values.implementation,
      requireTestContract: Boolean(values["require-test-contract"]),
    });
    if (command === "verify-implementations") {
      const excellent = verification.results.filter((item) => item.status === "excellent").length;
      const good = verification.results.filter((item) => item.status === "good").length;
      const needsWork = verification.results.filter((item) => item.status === "needs_work").length;
      writeGithubOutput("excellent_count", String(excellent));
      writeGithubOutput("good_count", String(good));
      writeGithubOutput("needs_work_count", String(needsWork));
      writeGithubOutput("total_count", String(verification.results.length));
    }
    return verification.exitCode;
  }

  if (command === "analyze-tools") {
    return await runAnalyzeTools();
  }

  if (command === "check-statistics-freshness") {
    return await runCheckStatisticsFreshness();
  }

  if (command === "semantic-tokens") {
    return await runSemanticTokensCli(args);
  }

  if (command === "code-size-metrics") {
    return await runCodeSizeMetricsCli(args);
  }

  if (command === "refresh-report-metrics") {
    return await runRefreshReportMetricsCli(args);
  }

  if (command === "benchmark-stress" || command === "run-benchmark") {
    const { values, positionals } = parseArgs({
      args,
      allowPositionals: true,
      options: {
        impl: { type: "string" },
        output: { type: "string" },
        json: { type: "string" },
        timeout: { type: "string" },
        track: { type: "string" },
        profile: { type: "string" },
      },
    });
    const engine = positionals[0];
    if (command === "run-benchmark" && engine) {
      return await runBenchmarkCommand(engine, Number(values.timeout ?? 60));
    }
    return await runPerformanceBenchmarks({
      impl: values.impl ?? (engine ? join(REPO_ROOT, "implementations", engine) : undefined),
      output: values.output,
      json: values.json,
      timeout: values.timeout ? Number(values.timeout) : undefined,
      track: values.track,
      profile: (values.profile as "quick" | "full" | undefined) ?? "quick",
    });
  }

  if (command === "benchmark-concurrency") {
    const { values, positionals } = parseArgs({
      args,
      allowPositionals: true,
      options: {
        impl: { type: "string" },
        dir: { type: "string" },
        profile: { type: "string" },
        "docker-image": { type: "string" },
        "skip-build": { type: "boolean" },
        fixture: { type: "string" },
        output: { type: "string" },
      },
    });
    const engine = positionals[0];
    return await runConcurrencyHarness({
      impl: values.impl ?? (engine ? join(REPO_ROOT, "implementations", engine) : undefined),
      dir: values.dir,
      profile: (values.profile as "quick" | "full" | undefined) ?? "quick",
      dockerImage: values["docker-image"] ?? (engine ? `chess-${engine}` : undefined),
      skipBuild: Boolean(values["skip-build"]),
      fixture: values.fixture,
      output: values.output,
    });
  }

  if (command === "detect-changes") {
    const [eventName = "workflow_dispatch"] = args;
    const { values } = parseArgs({
      args: args.slice(1),
      options: {
        "test-all": { type: "string" },
        "base-sha": { type: "string" },
        "head-sha": { type: "string" },
        "before-sha": { type: "string" },
      },
    });
    await detectChanges(
      eventName,
      values["test-all"] ?? "false",
      values["base-sha"] ?? "",
      values["head-sha"] ?? "",
      values["before-sha"] ?? "",
    );
    return 0;
  }

  if (command === "generate-matrix") {
    const [changed = "all"] = args;
    const matrix = await generateMatrix(changed);
    console.log(JSON.stringify(matrix));
    return 0;
  }

  if (command === "validate-results") {
    const { values } = parseArgs({
      args,
      options: {
        "benchmark-dir": { type: "string" },
        expected: { type: "string", multiple: true },
      },
    });
    return await validateAllResults(
      values["benchmark-dir"] ? resolve(values["benchmark-dir"]) : undefined,
      values.expected,
    );
  }

  if (command === "combine-results") {
    const { values } = parseArgs({
      args,
      options: {
        "artifacts-dir": { type: "string" },
        "reports-dir": { type: "string" },
        expected: { type: "string", multiple: true },
      },
    });
    return (await combineResults({
      artifactsDir: values["artifacts-dir"] ? resolve(values["artifacts-dir"]) : undefined,
      reportsDir: values["reports-dir"] ? resolve(values["reports-dir"]) : undefined,
      expectedImplementations: values.expected,
    })) ? 0 : 1;
  }

  if (command === "update-readme") {
    return await runUpdateReadme();
  }

  if (command === "create-release") {
    const { values } = parseArgs({
      args,
      options: {
        "version-type": { type: "string" },
        "readme-changed": { type: "string" },
        "excellent-count": { type: "string" },
        "good-count": { type: "string" },
        "needs-work-count": { type: "string" },
        "total-count": { type: "string" },
      },
    });
    return await createRelease({
      versionType: (values["version-type"] as "major" | "minor" | "patch" | undefined) ?? "patch",
      readmeChanged: values["readme-changed"] ?? "false",
      excellentCount: Number(values["excellent-count"] ?? 0),
      goodCount: Number(values["good-count"] ?? 0),
      needsWorkCount: Number(values["needs-work-count"] ?? 0),
      totalCount: Number(values["total-count"] ?? 0),
    });
  }

  if (command === "get-test-config") {
    const { values, positionals } = parseArgs({ args, options: { all: { type: "boolean" } }, allowPositionals: true });
    const implementation = positionals[0];
    if (values.all) {
      console.log(JSON.stringify(await getAllTestConfigs(), null, 2));
      return 0;
    }
    if (!implementation) {
      console.error("ERROR: Implementation name required (or use --all)");
      return 1;
    }
    const config = await getTestConfig(implementation);
    for (const [key, value] of Object.entries(config)) {
      if (key.startsWith("supports_") || key === "test_mode") {
        writeGithubOutput(key, String(value).toLowerCase());
      }
    }
    console.log(JSON.stringify(config, null, 2));
    return 0;
  }

  if (command === "verify-make-target") {
    const { values, positionals } = parseArgs({ args, options: { timeout: { type: "string" } }, allowPositionals: true });
    const [engine, target] = positionals;
    if (!engine || !target) {
      console.error("Usage: ./workflow verify-make-target <engine> <target> [--timeout 180]");
      return 1;
    }
    return await verifyMakeTarget(engine, target, Number(values.timeout ?? 180));
  }

  if (command === "test-basic-commands") {
    const { positionals } = parseArgs({ args, options: {}, allowPositionals: true });
    const [engine] = positionals;
    return engine ? await testBasicCommands(engine) : 1;
  }

  if (command === "test-advanced-features") {
    const { values, positionals } = parseArgs({
      args,
      options: { "supports-perft": { type: "string" }, "supports-ai": { type: "string" } },
      allowPositionals: true,
    });
    const [engine] = positionals;
    return engine
      ? await testAdvancedFeatures(engine, values["supports-perft"] !== "false", values["supports-ai"] !== "false")
      : 1;
  }

  if (command === "test-demo-mode") {
    const { positionals } = parseArgs({ args, options: {}, allowPositionals: true });
    const [engine] = positionals;
    return engine ? await testDemoMode(engine) : 1;
  }

  if (command === "cleanup-docker") {
    const { positionals } = parseArgs({ args, options: {}, allowPositionals: true });
    const [engine] = positionals;
    return engine ? await cleanupDocker(engine) : 1;
  }

  if (command === "triage-issue") {
    const { values } = parseArgs({ args, options: { repo: { type: "string" }, issue: { type: "string" } } });
    if (!values.repo || !values.issue) {
      console.error("Usage: ./workflow triage-issue --repo owner/repo --issue 123");
      return 1;
    }
    return await triageIssue(values.repo, Number(values.issue));
  }

  console.error(`Unknown command: ${command}`);
  console.log(helpText());
  return 1;
}
