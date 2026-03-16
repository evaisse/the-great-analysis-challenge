import { existsSync } from "node:fs";
import { basename, join } from "node:path";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";

import {
  IMPLEMENTATIONS_DIR,
  REPO_ROOT,
  discoverImplementationDirs,
  getMetadata,
  normalizeLineEndings,
  readJsonFile,
  sleep,
} from "./shared.ts";

export const TRACK_TO_SUITE: Record<string, string> = {
  v1: join(REPO_ROOT, "test", "test_suite.json"),
  "v2-foundation": join(REPO_ROOT, "test", "suites", "v2_foundation.json"),
  "v2-functional": join(REPO_ROOT, "test", "suites", "v2_functional.json"),
  "v2-system": join(REPO_ROOT, "test", "suites", "v2_system.json"),
  "v2-full": join(REPO_ROOT, "test", "suites", "v2_full.json"),
  "v3-book": join(REPO_ROOT, "test", "suites", "v3_book.json"),
};

const END_KEYWORDS = [
  "OK:",
  "ERROR:",
  "CHECKMATE:",
  "STALEMATE:",
  "FEN:",
  "AI:",
  "EVALUATION:",
  "HASH:",
  "REPETITION:",
  "DRAW:",
  "DRAWS:",
  "CONCURRENCY:",
  "NODES:",
  "960:",
  "UCIOK",
  "READYOK",
  "BESTMOVE",
  "INFO ",
  "ID NAME",
  "ID AUTHOR",
  "PGN",
  "TRACE",
];

export interface ChessHarnessResults {
  passed: string[];
  failed: Array<Record<string, unknown>>;
  performance: Record<string, number>;
  errors: string[];
}

export interface SuiteTestCase extends Record<string, any> {
  name: string;
  category?: string;
  commands?: Array<string | Record<string, unknown>>;
  expected_patterns?: string[];
  optional?: boolean;
  timeout?: number;
}

export interface ChessHarnessReport {
  metadata: Record<string, unknown>;
  results: ChessHarnessResults;
  performance?: Record<string, number>;
}

export class ChessEngineTester {
  path: string;
  metadata: Record<string, unknown>;
  dockerImage?: string;
  process: ChildProcessWithoutNullStreams | null = null;
  stdoutLog = "";
  stderrLog = "";
  lastStdoutAt = 0;
  results: ChessHarnessResults = {
    passed: [],
    failed: [],
    performance: {},
    errors: [],
  };

  constructor(implementationPath: string, metadata: Record<string, unknown>, dockerImage?: string) {
    this.path = implementationPath;
    this.metadata = metadata;
    this.dockerImage = dockerImage;
  }

  private buildCommand(): string[] {
    const runCommand = String(this.metadata.run ?? "").trim();
    if (!runCommand) {
      throw new Error(`No run command specified for ${this.path}`);
    }

    if (this.dockerImage) {
      return [
        "docker",
        "run",
        "--rm",
        "--network",
        "none",
        "-i",
        "-v",
        `${REPO_ROOT}:/repo:ro`,
        this.dockerImage,
        "sh",
        "-c",
        `cd /app && ${runCommand}`,
      ];
    }

    return runCommand.split(/\s+/).filter(Boolean);
  }

  async start(): Promise<boolean> {
    try {
      const command = this.buildCommand();
      this.process = spawn(command[0], command.slice(1), {
        cwd: this.dockerImage ? undefined : this.path,
        stdio: "pipe",
      });
      this.process.stdout.on("data", (chunk) => {
        this.stdoutLog += chunk.toString("utf8");
        this.lastStdoutAt = Date.now();
      });
      this.process.stderr.on("data", (chunk) => {
        this.stderrLog += chunk.toString("utf8");
      });
      this.process.on("error", (error) => {
        this.results.errors.push(`Failed to start: ${error.message}`);
      });
      await this.drainStartupOutput();
      return true;
    } catch (error) {
      this.results.errors.push(`Failed to start: ${error instanceof Error ? error.message : String(error)}`);
      return false;
    }
  }

  private async drainStartupOutput(maxWaitMs = 1500, quietWindowMs = 200): Promise<void> {
    const startedAt = Date.now();
    let lastDataAt = this.lastStdoutAt || startedAt;

    while (Date.now() - startedAt < maxWaitMs) {
      if (this.lastStdoutAt > lastDataAt) {
        lastDataAt = this.lastStdoutAt;
      }
      if (Date.now() - lastDataAt >= quietWindowMs) {
        break;
      }
      await sleep(50);
    }

    this.stdoutLog = "";
    this.stderrLog = "";
  }

  async sendCommand(command: string, timeoutSeconds = 10): Promise<string> {
    if (!this.process || !this.process.stdin.writable) {
      return "";
    }

    const startIndex = this.stdoutLog.length;
    try {
      this.process.stdin.write(`${command}\n`);
      const startTime = Date.now();
      let endSeenAt: number | null = null;

      while (Date.now() - startTime < timeoutSeconds * 1000) {
        if (this.process.exitCode !== null) {
          break;
        }

        const output = this.stdoutLog.slice(startIndex);
        const lines = output
          .split("\n")
          .map((line) => line.trim())
          .filter(Boolean);

        if (lines.some((line) => END_KEYWORDS.some((keyword) => line.toUpperCase().includes(keyword)))) {
          endSeenAt = Date.now();
        }

        if (endSeenAt !== null && Date.now() - endSeenAt >= 120) {
          return lines.join("\n");
        }

        await sleep(50);
      }

      return this.stdoutLog
        .slice(startIndex)
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean)
        .join("\n");
    } catch (error) {
      this.results.errors.push(`Command error: ${error instanceof Error ? error.message : String(error)}`);
      return "";
    }
  }

  async stop(): Promise<void> {
    if (!this.process) {
      return;
    }
    try {
      await this.sendCommand("quit", 1);
      await sleep(500);
      if (this.process.exitCode === null) {
        this.process.kill();
      }
    } finally {
      this.process = null;
    }
  }
}

export class TestSuite {
  suitePath: string;
  tests: SuiteTestCase[] = [];

  constructor(suitePath = TRACK_TO_SUITE.v1) {
    this.suitePath = suitePath;
  }

  async loadTests(): Promise<void> {
    if (!existsSync(this.suitePath)) {
      console.warn(`Warning: Test suite file not found at ${this.suitePath}`);
      return;
    }

    try {
      const data = await readJsonFile<Record<string, any>>(this.suitePath);
      const categories = data.test_categories ?? {};
      for (const [categoryId, categoryInfo] of Object.entries<Record<string, any>>(categories)) {
        const categoryTests = categoryInfo.tests ?? [];
        for (const test of categoryTests) {
          this.tests.push({
            ...test,
            category: categoryId,
          });
        }
      }
      console.log(`Loaded ${this.tests.length} tests from ${this.suitePath}`);
    } catch (error) {
      console.warn(`Error loading test suite: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  private async resolveCommands(cmdInfo: string | Record<string, any>): Promise<string[]> {
    if (typeof cmdInfo === "string") {
      return [cmdInfo];
    }

    if (!cmdInfo || typeof cmdInfo !== "object") {
      return [String(cmdInfo)];
    }

    if (cmdInfo.fixture_file) {
      const fixturePath = join(REPO_ROOT, String(cmdInfo.fixture_file));
      const raw = normalizeLineEndings(await Bun.file(fixturePath).text());
      const lineTemplate = String(cmdInfo.line_template ?? "{line}");
      const commands: string[] = [];
      for (const [index, line] of raw.split("\n").entries()) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) {
          continue;
        }
        commands.push(lineTemplate.replace("{line}", trimmed).replace("{index}", String(index)));
      }
      return commands;
    }

    if (cmdInfo.cmd) {
      return [String(cmdInfo.cmd)];
    }

    return [];
  }

  async runTest(tester: ChessEngineTester, test: SuiteTestCase): Promise<boolean> {
    try {
      const allOutput: string[] = [];
      const startedAt = Bun.nanoseconds();

      for (const cmdInfo of test.commands ?? []) {
        const commands = await this.resolveCommands(cmdInfo as any);
        for (const command of commands) {
          const output = await tester.sendCommand(command, (test.timeout ?? 1000) / 1000);
          allOutput.push(output);
        }
      }

      const elapsed = Number(Bun.nanoseconds() - startedAt) / 1_000_000_000;
      const fullOutput = allOutput.join("\n");
      const patterns = (test.expected_patterns ?? []).map((pattern) => pattern.toUpperCase());
      const success = patterns.every((pattern) => fullOutput.toUpperCase().includes(pattern));

      if (success) {
        tester.results.passed.push(test.name);
        tester.results.performance[test.name] = elapsed;
        return true;
      }

      tester.results.failed.push({
        test: test.name,
        output: fullOutput.slice(0, 1000),
      });
      return false;
    } catch (error) {
      tester.results.failed.push({
        test: test.name,
        error: error instanceof Error ? error.message : String(error),
      });
      return false;
    }
  }
}

export async function findImplementations(baseDir: string): Promise<Array<[string, Record<string, unknown>]>> {
  const implementations: Array<[string, Record<string, unknown>]> = [];
  const candidates = await discoverImplementationDirs(baseDir);
  for (const currentPath of candidates) {
    const metadata = await getMetadata(currentPath);
    if (Object.keys(metadata).length > 0) {
      implementations.push([currentPath, metadata]);
    }
  }
  return implementations;
}

export async function runPerformanceTests(tester: ChessEngineTester): Promise<Record<string, number>> {
  const perfResults: Record<string, number> = {};
  await tester.sendCommand("new");

  const moveStart = Bun.nanoseconds();
  for (let index = 0; index < 10; index += 1) {
    await tester.sendCommand("move e2e4");
    await tester.sendCommand("undo");
  }
  perfResults.move_speed = Number(Bun.nanoseconds() - moveStart) / 10 / 1_000_000_000;

  for (const depth of [1, 3, 5]) {
    const maxDepth = Number(tester.metadata.max_ai_depth ?? 5);
    if (depth > maxDepth) {
      continue;
    }
    await tester.sendCommand("new");
    const startedAt = Bun.nanoseconds();
    const output = await tester.sendCommand(`ai ${depth}`, 30);
    if (output.includes("AI:")) {
      perfResults[`ai_depth_${depth}`] = Number(Bun.nanoseconds() - startedAt) / 1_000_000_000;
    }
  }

  return perfResults;
}

export function generateReport(results: Record<string, ChessHarnessReport>): string {
  const lines: string[] = [];
  lines.push("=".repeat(80));
  lines.push("CHESS ENGINE TEST HARNESS REPORT");
  lines.push("=".repeat(80));
  lines.push("");
  lines.push("SUMMARY");
  lines.push("-".repeat(40));
  lines.push(`${"Language".padEnd(15)} ${"Passed".padEnd(10)} ${"Failed".padEnd(10)} ${"Errors".padEnd(10)}`);
  lines.push("-".repeat(40));

  for (const [implPath, data] of Object.entries(results)) {
    const language = String(data.metadata.language ?? "Unknown");
    lines.push(
      `${language.padEnd(15)} ${String(data.results.passed.length).padEnd(10)} ${String(data.results.failed.length).padEnd(10)} ${String(data.results.errors.length).padEnd(10)}`,
    );
  }

  for (const [implPath, data] of Object.entries(results)) {
    lines.push(`\n${"=".repeat(40)}`);
    lines.push(`Implementation: ${implPath}`);
    lines.push(`Language: ${String(data.metadata.language ?? "Unknown")}`);
    lines.push("=".repeat(40));

    if (data.results.passed.length > 0) {
      lines.push("\nPASSED TESTS:");
      for (const test of data.results.passed) {
        lines.push(`  ✓ ${test} (${(data.results.performance[test] ?? 0).toFixed(2)}s)`);
      }
    }

    if (data.results.failed.length > 0) {
      lines.push("\nFAILED TESTS:");
      for (const failure of data.results.failed) {
        lines.push(`  ✗ ${String(failure.test)}`);
        if (failure.error) {
          lines.push(`    Error: ${String(failure.error)}`);
        } else if (failure.output) {
          lines.push(`    Output: ${String(failure.output).slice(0, 100)}...`);
        }
      }
    }

    if (data.results.errors.length > 0) {
      lines.push("\nERRORS:");
      for (const error of data.results.errors) {
        lines.push(`  ! ${error}`);
      }
    }

    if (data.performance) {
      lines.push("\nPERFORMANCE:");
      for (const [metric, value] of Object.entries(data.performance)) {
        if (metric.startsWith("ai_depth")) {
          lines.push(`  ${metric}: ${value.toFixed(2)}s`);
        } else if (metric === "move_speed") {
          lines.push(`  Average move time: ${(value * 1000).toFixed(1)}ms`);
        }
      }
    }
  }

  lines.push(`\n${"=".repeat(80)}`);
  return lines.join("\n");
}

export interface TestHarnessRunOptions {
  baseDir?: string;
  suitePath?: string;
  track?: string;
  dockerImage?: string;
  category?: string;
  impl?: string;
  testName?: string;
  performance?: boolean;
  output?: string;
}

export async function runTestHarness(options: TestHarnessRunOptions): Promise<number> {
  const suitePath = options.suitePath ?? (options.track ? TRACK_TO_SUITE[options.track] : TRACK_TO_SUITE.v1);
  const suite = new TestSuite(suitePath);
  await suite.loadTests();

  let implementations: Array<[string, Record<string, unknown>]>;
  if (options.impl) {
    const metadata = await getMetadata(options.impl);
    implementations = Object.keys(metadata).length > 0 ? [[options.impl, metadata]] : [];
  } else {
    implementations = await findImplementations(options.baseDir ?? IMPLEMENTATIONS_DIR);
  }

  if (implementations.length === 0) {
    console.log(`No implementations found in ${options.baseDir ?? options.impl ?? IMPLEMENTATIONS_DIR}`);
    return 1;
  }

  console.log(`Found ${implementations.length} implementation(s)`);
  const allResults: Record<string, ChessHarnessReport> = {};

  for (const [implPath, metadata] of implementations) {
    console.log(`\nTesting ${String(metadata.language ?? "Unknown")} implementation at ${implPath}`);
    console.log("-".repeat(40));

    let dockerImage = options.dockerImage;
    if (!dockerImage && options.impl) {
      dockerImage = `chess-${basename(implPath)}`;
    }
    const tester = new ChessEngineTester(implPath, metadata, dockerImage);
    const started = await tester.start();
    if (!started) {
      console.log(`Failed to start implementation at ${implPath}`);
      allResults[implPath] = { metadata, results: tester.results };
      continue;
    }

    if (options.testName) {
      const test = suite.tests.find((item) => item.name === options.testName);
      if (test) {
        console.log(`Running test: ${test.name}`);
        const success = await suite.runTest(tester, test);
        console.log(`  ${success ? "✓ PASSED" : "✗ FAILED"}`);
      }
    } else {
      for (const test of suite.tests) {
        if (options.category && test.category !== options.category) {
          continue;
        }
        if (test.optional) {
          const features = Array.isArray(metadata.features) ? metadata.features.map((value) => String(value)) : [];
          if (!features.includes(test.name)) {
            continue;
          }
        }
        process.stdout.write(`Running test: ${test.name}`);
        const success = await suite.runTest(tester, test);
        process.stdout.write(` ${success ? "✓" : "✗"}\n`);
      }
    }

    if (options.performance) {
      console.log("\nRunning performance tests...");
      allResults[implPath] = {
        metadata,
        results: tester.results,
        performance: await runPerformanceTests(tester),
      };
    } else {
      allResults[implPath] = { metadata, results: tester.results };
    }

    await tester.stop();
  }

  const report = generateReport(allResults);
  console.log(`\n${report}`);
  if (options.output) {
    await Bun.write(options.output, report);
    console.log(`\nReport saved to ${options.output}`);
  }

  const totalFailed = Object.values(allResults).reduce((count, reportItem) => count + reportItem.results.failed.length, 0);
  return totalFailed === 0 ? 0 : 1;
}
