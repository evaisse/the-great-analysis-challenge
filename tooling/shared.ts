import { basename, dirname, extname, join, relative, resolve } from "node:path";
import { appendFileSync, mkdtempSync } from "node:fs";
import { existsSync, readFileSync } from "node:fs";
import { promises as fs } from "node:fs";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";

export const TRUTHY_VALUES = new Set(["1", "true", "yes", "y", "on"]);
export const FALSY_VALUES = new Set(["0", "false", "no", "n", "off"]);
export const SKIP_VALUES = new Set(["skip", "skipped"]);
export const INTERPRETED_RUNTIME_VALUES = new Set(["interpreted", "scripted", "jit"]);
export const TOKEN_METRIC_VERSION = "tokens-v2";
export const CONTAINER_REPO_ROOT = "/repo";

const MODULE_DIR = dirname(fileURLToPath(import.meta.url));

export function findRepoRoot(startPath = MODULE_DIR): string {
  let current = resolve(startPath);
  while (true) {
    if (existsSync(join(current, ".git"))) {
      return current;
    }

    const parent = dirname(current);
    if (parent === current) {
      throw new Error(`Could not locate repository root from ${startPath}`);
    }
    current = parent;
  }
}

export const REPO_ROOT = findRepoRoot();
export const IMPLEMENTATIONS_DIR = join(REPO_ROOT, "implementations");
export const REPORTS_DIR = join(REPO_ROOT, "reports");

export type Json =
  | null
  | boolean
  | number
  | string
  | Json[]
  | { [key: string]: Json };

export interface CommandResult {
  cmd: string[];
  cwd?: string;
  exitCode: number;
  stdout: string;
  stderr: string;
  timedOut: boolean;
}

export interface PhaseExecution {
  implName: string;
  phase: string;
  command: string;
  returncode: number;
  stdout: string;
  stderr: string;
  skipped: boolean;
  skipReason: string | null;
}

export interface RunCommandOptions {
  cwd?: string;
  input?: string;
  timeoutMs?: number;
  env?: Record<string, string | undefined>;
  check?: boolean;
}

export async function sleep(ms: number): Promise<void> {
  await Bun.sleep(ms);
}

async function streamToText(stream: ReadableStream<Uint8Array> | null | undefined): Promise<string> {
  if (!stream) {
    return "";
  }
  return await new Response(stream).text();
}

export async function runCommand(cmd: string[], options: RunCommandOptions = {}): Promise<CommandResult> {
  const proc = Bun.spawn(cmd, {
    cwd: options.cwd,
    env: {
      ...process.env,
      ...(options.env ?? {}),
    },
    stdin: options.input !== undefined ? "pipe" : "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });

  if (options.input !== undefined && proc.stdin) {
    const writer = proc.stdin.getWriter();
    await writer.write(new TextEncoder().encode(options.input));
    await writer.close();
  }

  let timedOut = false;
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  if (options.timeoutMs && options.timeoutMs > 0) {
    timeoutHandle = setTimeout(() => {
      timedOut = true;
      try {
        proc.kill();
      } catch {
        // ignore
      }
    }, options.timeoutMs);
  }

  const [stdout, stderr, exitCode] = await Promise.all([
    streamToText(proc.stdout),
    streamToText(proc.stderr),
    proc.exited,
  ]);

  if (timeoutHandle) {
    clearTimeout(timeoutHandle);
  }

  if (options.check && exitCode !== 0) {
    throw new Error(
      `Command failed (${exitCode}): ${cmd.join(" ")}\n${stdout}\n${stderr}`.trim(),
    );
  }

  return {
    cmd,
    cwd: options.cwd,
    exitCode,
    stdout,
    stderr,
    timedOut,
  };
}

export async function fileExists(path: string): Promise<boolean> {
  try {
    await fs.access(path);
    return true;
  } catch {
    return false;
  }
}

export async function ensureDir(path: string): Promise<void> {
  await fs.mkdir(path, { recursive: true });
}

export async function readJsonFile<T = any>(path: string): Promise<T> {
  const raw = await Bun.file(path).text();
  return JSON.parse(raw) as T;
}

export async function writeJsonFile(path: string, data: unknown): Promise<void> {
  await ensureDir(dirname(path));
  await Bun.write(path, `${JSON.stringify(data, null, 2)}\n`);
}

export async function readTextFile(path: string): Promise<string> {
  return await Bun.file(path).text();
}

export async function writeTextFile(path: string, value: string): Promise<void> {
  await ensureDir(dirname(path));
  await Bun.write(path, value);
}

export function normalizeLineEndings(text: string): string {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

export function normalizePath(path: string): string {
  return path.replaceAll("\\", "/").replace(/^\.\/+/, "");
}

export function resolveImplPath(impl: string): string {
  const candidate = resolve(impl);
  if (existsSync(candidate)) {
    return candidate;
  }

  const fallback = resolve(IMPLEMENTATIONS_DIR, impl);
  if (existsSync(fallback)) {
    return fallback;
  }

  throw new Error(`Implementation not found: ${impl}`);
}

export async function discoverImplementationDirs(baseDir = IMPLEMENTATIONS_DIR): Promise<string[]> {
  const entries = await fs.readdir(baseDir, { withFileTypes: true });
  const implementations: string[] = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }
    const implPath = join(baseDir, entry.name);
    if (existsSync(join(implPath, "Dockerfile"))) {
      implementations.push(implPath);
    }
  }
  implementations.sort((a, b) => basename(a).localeCompare(basename(b)));
  return implementations;
}

export function parseSourceExts(rawValue: unknown): string[] {
  const items = Array.isArray(rawValue)
    ? rawValue.map((item) => String(item).trim())
    : typeof rawValue === "string"
      ? rawValue.split(",").map((item) => item.trim())
      : [];

  const seen = new Set<string>();
  const normalized: string[] = [];
  for (const item of items) {
    if (!item) {
      continue;
    }
    const ext = item.startsWith(".") ? item.toLowerCase() : `.${item.toLowerCase()}`;
    if (seen.has(ext)) {
      continue;
    }
    seen.add(ext);
    normalized.push(ext);
  }
  return normalized;
}

const TOKEN_PATTERN = new RegExp(
  [
    "[A-Za-z_][A-Za-z0-9_]*",
    "\\d+(?:\\.\\d+)?",
    "==|!=|<=|>=|<<|>>|&&|\\|\\||::|->|=>|\\+\\+|--|\\+=|-=|\\*=|/=|%=|&=|\\|=|\\^=|//=",
    "[{}()\\[\\].,;:?+\\-*/%&|^~<>!=]",
    "\\S",
  ].join("|"),
  "g",
);

export function countTokens(text: string): number {
  return normalizeLineEndings(text).match(TOKEN_PATTERN)?.length ?? 0;
}

const METRIC_EXCLUDED_SEGMENTS = [
  "/node_modules/",
  "/vendor/",
  "/dist/",
  "/build/",
  "/target/",
  "/.dart_tool/",
  "/elm-stuff/",
  "/.git/",
  "/.next/",
  "/coverage/",
  "/__pycache__/",
];

function normalizeMetricPath(path: string): string {
  return `/${resolve(path).replaceAll("\\", "/").toLowerCase().replace(/^\/+/, "")}`;
}

export function isExcludedMetricPath(path: string): boolean {
  const normalized = normalizeMetricPath(path);
  return METRIC_EXCLUDED_SEGMENTS.some((segment) => normalized.includes(segment));
}

async function isProbablyBinary(path: string): Promise<boolean> {
  try {
    const bytes = new Uint8Array(await Bun.file(path).slice(0, 8192).arrayBuffer());
    return bytes.includes(0);
  } catch {
    return true;
  }
}

async function readTextSafely(path: string): Promise<string | null> {
  if (await isProbablyBinary(path)) {
    return null;
  }
  try {
    return await Bun.file(path).text();
  } catch {
    return null;
  }
}

export async function listGitDiscoveredFiles(targetPath: string): Promise<string[]> {
  const repoRoot = findRepoRoot(targetPath);
  const relTarget = relative(repoRoot, resolve(targetPath));
  const result = await runCommand(
    ["git", "-C", repoRoot, "ls-files", "-co", "--exclude-standard", "--", relTarget],
    { check: false },
  );

  if (result.exitCode !== 0) {
    throw new Error(`git ls-files failed for ${relTarget}: ${result.stderr.trim() || "unknown error"}`);
  }

  return result.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => resolve(repoRoot, line))
    .filter((path) => existsSync(path) && !isExcludedMetricPath(path));
}

export async function collectImplMetrics(
  implPath: string,
  sourceExts: string[],
): Promise<Record<string, unknown>> {
  const normalizedExts = parseSourceExts(sourceExts);
  if (normalizedExts.length === 0) {
    throw new Error(`No valid source extensions configured for ${implPath}`);
  }

  let sourceFiles = 0;
  let sourceLoc = 0;
  let tokensCount = 0;
  let skippedBinaryOrUnreadable = 0;

  for (const path of await listGitDiscoveredFiles(implPath)) {
    if (!normalizedExts.includes(extname(path).toLowerCase())) {
      continue;
    }
    const text = await readTextSafely(path);
    if (text === null) {
      skippedBinaryOrUnreadable += 1;
      continue;
    }
    const normalized = normalizeLineEndings(text);
    sourceFiles += 1;
    sourceLoc += normalized.split("\n").length;
    tokensCount += countTokens(normalized);
  }

  return {
    implementation: basename(implPath),
    path: implPath,
    source_exts: normalizedExts,
    source_files: sourceFiles,
    source_loc: sourceLoc,
    tokens_count: tokensCount,
    metric_version: TOKEN_METRIC_VERSION,
    skipped_binary_or_unreadable: skippedBinaryOrUnreadable,
  };
}

export async function collectImplMetricsFromMetadata(
  implPath: string,
  metadata: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  return await collectImplMetrics(implPath, parseSourceExts(metadata.source_exts));
}

export function getDockerfileMetadata(dockerfilePath: string): Record<string, unknown> {
  const metadata: Record<string, unknown> = {};
  if (!existsSync(dockerfilePath)) {
    return metadata;
  }

  try {
    const content = readFileSync(dockerfilePath, "utf8");
    const labelPattern =
      /LABEL\s+org\.chess\.([a-z0-9_.]+)\s*=\s*("(?:(?:\\.)|[^"])*"|[^\s\n]+)/g;

    for (const match of content.matchAll(labelPattern)) {
      const key = match[1];
      const rawValue = match[2];
      let value = rawValue;
      if (value.startsWith("\"") && value.endsWith("\"")) {
        value = value.slice(1, -1).replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
      }

      if (["features", "source_exts"].includes(key) && value) {
        metadata[key] = value.split(",").map((item) => item.trim()).filter(Boolean);
      } else if (["max_ai_depth", "estimated_perft4_ms"].includes(key) && value) {
        const parsed = Number.parseInt(value, 10);
        metadata[key] = Number.isNaN(parsed) ? value : parsed;
      } else {
        metadata[key] = value;
      }
    }

    if (metadata.run === undefined) {
      const cmdMatch = content.match(/CMD\s+(?:\[(.*)\]|(.*))/);
      if (cmdMatch) {
        if (cmdMatch[1]) {
          metadata.run = cmdMatch[1]
            .split(",")
            .map((part) => part.trim().replace(/^"|"$/g, ""))
            .join(" ");
        } else if (cmdMatch[2]) {
          metadata.run = cmdMatch[2].trim();
        }
      }
    }
  } catch {
    // Preserve the Python behavior: metadata parsing is best-effort.
  }

  return metadata;
}

export async function getMetadata(implDir: string): Promise<Record<string, unknown>> {
  const implPath = resolve(implDir);
  const metadata: Record<string, unknown> = {};

  const chessMetaPath = join(implPath, "chess.meta");
  if (existsSync(chessMetaPath)) {
    try {
      const parsed = JSON.parse(await Bun.file(chessMetaPath).text()) as Record<string, unknown>;
      Object.assign(metadata, parsed);
    } catch {
      // Preserve lax behavior.
    }
  }

  const dockerfileMetadata = getDockerfileMetadata(join(implPath, "Dockerfile"));
  Object.assign(metadata, dockerfileMetadata);
  return metadata;
}

export async function dockerImageExists(image: string): Promise<boolean> {
  const result = await runCommand(["docker", "image", "inspect", image], { check: false });
  return result.exitCode === 0;
}

function shellMissing(stderr: string, shell: string): boolean {
  const lowered = stderr.toLowerCase();
  return lowered.includes(shell) && (
    lowered.includes("executable file not found in $path") ||
    lowered.includes("no such file or directory")
  );
}

function shouldSkipBuildPhase(metadata: Record<string, unknown>): boolean {
  const benchmarkBuild = String(metadata["benchmark.build"] ?? "").trim().toLowerCase();
  if (TRUTHY_VALUES.has(benchmarkBuild) || SKIP_VALUES.has(benchmarkBuild)) {
    return true;
  }
  const runtimeMode = String(metadata.runtime ?? "").trim().toLowerCase();
  return INTERPRETED_RUNTIME_VALUES.has(runtimeMode);
}

async function runDockerShell(
  image: string,
  shell: string,
  command: string,
  workdir?: string,
): Promise<CommandResult> {
  const dockerCmd = ["docker", "run", "--rm", "--network", "none", "--entrypoint", shell];
  if (workdir) {
    dockerCmd.push("-v", `${resolve(workdir)}:/app`);
  }
  dockerCmd.push(image, "-c", `cd /app && ${command}`);
  return await runCommand(dockerCmd, { check: false });
}

export async function executePhase(
  impl: string,
  phase: string,
  image?: string,
  workdir?: string,
): Promise<PhaseExecution> {
  const implPath = resolveImplPath(impl);
  const implName = basename(implPath);
  const imageName = image ?? `chess-${implName}`;
  const metadata = await getMetadata(implPath);

  if (phase === "build" && shouldSkipBuildPhase(metadata)) {
    return {
      implName,
      phase,
      command: "",
      returncode: 0,
      stdout: "",
      stderr: "",
      skipped: true,
      skipReason: `Skipping build phase for ${implName} (metadata benchmark/runtime flag)`,
    };
  }

  const command = String(metadata[phase] ?? "").trim();
  if (!command) {
    throw new Error(`Missing metadata command 'org.chess.${phase}' for ${implName}`);
  }

  if (!(await dockerImageExists(imageName))) {
    throw new Error(`Docker image '${imageName}' not found. Run: make image DIR=${implName}`);
  }

  if (workdir && !(await fileExists(workdir))) {
    throw new Error(`Workspace not found: ${workdir}`);
  }

  let result = await runDockerShell(imageName, "sh", command, workdir);
  if (result.exitCode !== 0 && shellMissing(result.stderr, "sh")) {
    result = await runDockerShell(imageName, "bash", command, workdir);
  }

  return {
    implName,
    phase,
    command,
    returncode: result.exitCode,
    stdout: result.stdout,
    stderr: result.stderr,
    skipped: false,
    skipReason: null,
  };
}

export async function copyDir(src: string, dest: string): Promise<void> {
  await fs.cp(src, dest, { recursive: true });
}

export function makeTempDir(prefix: string): string {
  return mkdtempSync(join(tmpdir(), prefix));
}

export function repoToContainerPath(path: string): string {
  const resolved = resolve(path);
  const rel = relative(REPO_ROOT, resolved);
  if (rel.startsWith("..")) {
    throw new Error(`Path must be inside repository root: ${resolved}`);
  }
  return normalizePath(join(CONTAINER_REPO_ROOT, rel));
}

export function formatTime(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined || Number.isNaN(seconds) || seconds < 0) {
    return "-";
  }
  const ms = seconds * 1000;
  if (ms < 1) return "<1ms";
  if (ms < 10) return `${ms.toFixed(1)}ms`;
  if (ms < 1000) return `${Math.round(ms)}ms`;
  if (seconds < 60) return `${Number(seconds.toFixed(1)).toString()}s`;
  const rounded = Math.round(seconds);
  const minutes = Math.floor(rounded / 60);
  const remainingSeconds = rounded % 60;
  if (minutes < 60) {
    return `${minutes}m ${remainingSeconds.toString().padStart(2, "0")}s`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  return `${hours}h ${remainingMinutes.toString().padStart(2, "0")}m`;
}

export function formatGroupedInt(value: number | null | undefined): string {
  if (value === null || value === undefined || Number.isNaN(value)) {
    return "-";
  }
  return Math.round(value).toLocaleString("en-US");
}

export function formatMemoryMb(value: number | null | undefined): string {
  if (value === null || value === undefined || value <= 0 || Number.isNaN(value)) {
    return "- MB";
  }
  return `${formatGroupedInt(value)} MB`;
}

export function formatStepMetric(seconds: number | null | undefined, peakMemoryMb: number | null | undefined): string {
  return `${formatTime(seconds)}, ${formatMemoryMb(peakMemoryMb)}`;
}

export function statusEmoji(status: string): string {
  return {
    excellent: "🟢",
    good: "🟡",
    needs_work: "🔴",
    unknown: "⚪",
  }[status] ?? "⚪";
}

export function stripAnsi(value: string): string {
  return value.replace(/\x1b\[[0-9;]*m/g, "");
}

export function normalizeVolatileDurations(value: string): string {
  return stripAnsi(value).replace(
    /\b\d+(?:\.\d+)?(?: ?(?:ms|s|milliseconds?|seconds?|kb|mb|gb))\b/gi,
    "<duration>",
  );
}

export function writeGithubOutput(key: string, value: string): void {
  const output = process.env.GITHUB_OUTPUT;
  if (output) {
    appendFileSync(output, `${key}=${value}\n`, "utf8");
    return;
  }
  console.log(`Would set GitHub output: ${key}=${value}`);
}

export function parseJsonOrNull(value: string): any {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export async function removePath(path: string): Promise<void> {
  await fs.rm(path, { recursive: true, force: true });
}

export function normalizeFeatureName(feature: string): string {
  return feature.trim().toLowerCase().replaceAll("-", "_").replaceAll(" ", "_");
}
