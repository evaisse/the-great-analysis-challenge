import { basename, join, resolve } from "node:path";

import {
  PhaseExecution,
  REPORTS_DIR,
  dockerImageExists,
  ensureDir,
  executePhase,
  fileExists,
  normalizeVolatileDurations,
  removePath,
  resolveImplPath,
  runCommand,
  writeJsonFile,
  writeTextFile,
} from "./shared.ts";

const WORKSPACE_ROOT = join(REPORTS_DIR, "error-analysis-workspaces");
const REPORT_ROOT = join(REPORTS_DIR, "error-analysis");

export function defaultWorkspacePath(implName: string): string {
  return join(WORKSPACE_ROOT, implName);
}

export function defaultReportJsonPath(implName: string): string {
  return join(REPORT_ROOT, `${implName}.json`);
}

export function defaultReportTextPath(implName: string): string {
  return join(REPORT_ROOT, `${implName}.txt`);
}

function executionToDict(execution: PhaseExecution, durationSeconds?: number): Record<string, unknown> {
  return {
    phase: execution.phase,
    command: execution.command,
    returncode: execution.returncode,
    success: execution.returncode === 0,
    skipped: execution.skipped,
    skip_reason: execution.skipReason,
    stdout: execution.stdout,
    stderr: execution.stderr,
    ...(durationSeconds !== undefined ? { duration_s: Number(durationSeconds.toFixed(6)) } : {}),
  };
}

function phaseSignature(phase: Record<string, unknown>): [unknown, unknown, unknown] {
  return [
    phase.returncode,
    typeof phase.stdout === "string" ? normalizeVolatileDurations(phase.stdout) : phase.stdout,
    typeof phase.stderr === "string" ? normalizeVolatileDurations(phase.stderr) : phase.stderr,
  ];
}

function bugDetected(baseline: Record<string, unknown>, candidate: Record<string, unknown>): boolean {
  if (baseline.success) {
    return !candidate.success;
  }
  return JSON.stringify(phaseSignature(candidate)) !== JSON.stringify(phaseSignature(baseline));
}

function recoveredToBaseline(baseline: Record<string, unknown>, candidate: Record<string, unknown>): boolean {
  if (baseline.success) {
    return Boolean(candidate.success);
  }
  return JSON.stringify(phaseSignature(candidate)) === JSON.stringify(phaseSignature(baseline));
}

export async function seedWorkspace(image: string, workspace: string): Promise<void> {
  await removePath(workspace);
  await ensureDir(workspace);

  const created = await runCommand(["docker", "create", image], { check: true });
  const containerId = created.stdout.trim();
  try {
    await runCommand(["docker", "cp", `${containerId}:/app/.`, workspace], { check: true });
  } finally {
    await runCommand(["docker", "rm", "-f", containerId], { check: false });
  }
}

async function recordPhase(
  implPath: string,
  phase: string,
  image: string,
  workspace: string,
): Promise<Record<string, unknown>> {
  const startedAt = Bun.nanoseconds();
  const execution = await executePhase(implPath, phase, image, workspace);
  const durationSeconds = Number(Bun.nanoseconds() - startedAt) / 1_000_000_000;
  return executionToDict(execution, durationSeconds);
}

function buildTextReport(report: Record<string, any>): string {
  const summary = report.summary;
  const phases = report.phases;
  const lines = [
    "ERROR ANALYSIS BENCHMARK REPORT",
    "=".repeat(80),
    `Implementation: ${report.implementation}`,
    `Image: ${report.image}`,
    `Workspace: ${report.workspace}`,
    `Generated: ${report.generated_at}`,
    "",
    "SUMMARY",
    "-".repeat(80),
    `Baseline analyzer green: ${summary.baseline_green}`,
    `Bug injected: ${summary.bugit_success}`,
    `Analyzer detected bug: ${summary.bug_detected}`,
    `Fix applied: ${summary.fix_success}`,
    `Analyzer restored to baseline after fix: ${summary.recovered}`,
    "",
    "PHASES",
    "-".repeat(80),
  ];

  for (const [name, phase] of Object.entries<Record<string, any>>(phases)) {
    lines.push(
      `${name}: success=${phase.success} returncode=${phase.returncode} duration_s=${phase.duration_s ?? 0}`,
    );
    lines.push(`  command: ${phase.command}`);
  }

  for (const section of [
    ["BASELINE ANALYZE STDERR", phases.baseline_analyze.stderr],
    ["BASELINE ANALYZE STDOUT", phases.baseline_analyze.stdout],
    ["ANALYZE WITH BUG STDERR", phases.analyze_with_bug.stderr],
    ["ANALYZE WITH BUG STDOUT", phases.analyze_with_bug.stdout],
    ["ANALYZE AFTER FIX STDERR", phases.analyze_after_fix.stderr],
    ["ANALYZE AFTER FIX STDOUT", phases.analyze_after_fix.stdout],
  ]) {
    lines.push("");
    lines.push(section[0]);
    lines.push("-".repeat(80));
    lines.push(String(section[1]).trim() || "(empty)");
  }

  return `${lines.join("\n")}\n`;
}

async function writeReport(report: Record<string, unknown>, jsonPath: string, textPath: string): Promise<void> {
  await writeJsonFile(jsonPath, report);
  await writeTextFile(textPath, buildTextReport(report as Record<string, any>));
}

export interface ErrorAnalysisOptions {
  command: "prepare" | "bugit" | "fix" | "benchmark";
  impl: string;
  image?: string;
  workspace?: string;
  resetWorkspace?: boolean;
  reportJson?: string;
  reportText?: string;
}

export async function runErrorAnalysisCommand(options: ErrorAnalysisOptions): Promise<number> {
  const implPath = resolveImplPath(options.impl);
  const implName = basename(implPath);
  const image = options.image ?? `chess-${implName}`;
  const workspace = resolve(options.workspace ?? defaultWorkspacePath(implName));
  const reportJson = resolve(options.reportJson ?? defaultReportJsonPath(implName));
  const reportText = resolve(options.reportText ?? defaultReportTextPath(implName));

  if (!(await dockerImageExists(image))) {
    console.error(`ERROR: Docker image '${image}' not found. Run: make image DIR=${implName}`);
    return 1;
  }

  if (options.command === "prepare") {
    await seedWorkspace(image, workspace);
    console.log(`Prepared workspace for ${implName}: ${workspace}`);
    return 0;
  }

  if (options.command === "bugit") {
    if (options.resetWorkspace || !(await fileExists(workspace))) {
      await seedWorkspace(image, workspace);
    }
    const phase = await recordPhase(implPath, "bugit", image, workspace);
    if (phase.stdout) process.stdout.write(String(phase.stdout));
    if (phase.stderr) process.stderr.write(String(phase.stderr));
    return Number(phase.returncode ?? 1);
  }

  if (options.command === "fix") {
    const phase = await recordPhase(implPath, "fix", image, workspace);
    if (phase.stdout) process.stdout.write(String(phase.stdout));
    if (phase.stderr) process.stderr.write(String(phase.stderr));
    return Number(phase.returncode ?? 1);
  }

  await seedWorkspace(image, workspace);
  const baselineAnalyze = await recordPhase(implPath, "analyze", image, workspace);
  const bugitPhase = await recordPhase(implPath, "bugit", image, workspace);
  const analyzeWithBug = await recordPhase(implPath, "analyze", image, workspace);
  const fixPhase = await recordPhase(implPath, "fix", image, workspace);
  const analyzeAfterFix = await recordPhase(implPath, "analyze", image, workspace);

  const report = {
    implementation: implName,
    image,
    workspace,
    generated_at: new Date().toISOString(),
    phases: {
      baseline_analyze: baselineAnalyze,
      bugit: bugitPhase,
      analyze_with_bug: analyzeWithBug,
      fix: fixPhase,
      analyze_after_fix: analyzeAfterFix,
    },
    summary: {
      baseline_green: Boolean(baselineAnalyze.success),
      bugit_success: Boolean(bugitPhase.success),
      bug_detected: bugDetected(baselineAnalyze, analyzeWithBug),
      fix_success: Boolean(fixPhase.success),
      recovered: recoveredToBaseline(baselineAnalyze, analyzeAfterFix),
    },
  };

  await writeReport(report, reportJson, reportText);
  console.log(`JSON report: ${reportJson}`);
  console.log(`Text report: ${reportText}`);
  console.log(
    `Summary: baseline_green=${report.summary.baseline_green} bugit_success=${report.summary.bugit_success} bug_detected=${report.summary.bug_detected} fix_success=${report.summary.fix_success} recovered=${report.summary.recovered}`,
  );

  return report.summary.bugit_success &&
      report.summary.bug_detected &&
      report.summary.fix_success &&
      report.summary.recovered
    ? 0
    : 1;
}
