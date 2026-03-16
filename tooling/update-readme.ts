import { basename, join, relative } from "node:path";
import { existsSync } from "node:fs";

import {
  IMPLEMENTATIONS_DIR,
  REPO_ROOT,
  discoverImplementationDirs,
  formatGroupedInt,
  formatStepMetric,
  getMetadata,
  normalizeFeatureName,
  parseSourceExts,
  readJsonFile,
  readTextFile,
  writeGithubOutput,
  writeTextFile,
} from "./shared.ts";
import { collectCodeSizeMetricsForImpl } from "./code-size-metrics.ts";
import { verifyImplementation } from "./verify.ts";

const CUSTOM_EMOJIS: Record<string, string> = {
  python: "🐍",
  crystal: "💠",
  dart: "🎯",
  elm: "🌳",
  gleam: "✨",
  go: "🐹",
  haskell: "📐",
  imba: "🪶",
  javascript: "🟨",
  julia: "🔮",
  kotlin: "🧡",
  lua: "🪐",
  nim: "🦊",
  php: "🐘",
  rescript: "🧠",
  ruby: "❤️",
  rust: "🦀",
  swift: "🐦",
  typescript: "📘",
  zig: "⚡",
};

const FEATURE_CATALOG = [
  "perft",
  "fen",
  "ai",
  "castling",
  "en_passant",
  "promotion",
  "pgn",
  "uci",
  "chess960",
];

const GENERATED_SEGMENTS = ["dist/", "build/", "target/", "lib/es6/", ".build/", "zig-out/", "__pycache__/", "vendor/"];
const EXCLUDED_SEGMENTS = ["/test/", "test/"];

function normalizeRelPath(path: string): string {
  return path.replaceAll("\\", "/").replace(/^\.\/+/, "");
}

function isGeneratedOrExcludedPath(path: string): boolean {
  const lowered = normalizeRelPath(path).toLowerCase();
  return [...GENERATED_SEGMENTS, ...EXCLUDED_SEGMENTS].some((segment) => lowered.includes(segment));
}

function entrypointScore(path: string): number {
  const normalized = normalizeRelPath(path).toLowerCase();
  const base = basename(normalized);
  let score = 0;
  if (normalized.startsWith("src/")) score += 50;
  else if (normalized.startsWith("bin/")) score += 35;
  else if (normalized.startsWith("lib/")) score += 20;
  if (/(^|\/)(main|chess|chess_engine|chessengine)\.[^/]+$/.test(normalized)) score += 35;
  if (normalized.includes("chess_engine") || normalized.includes("chessengine")) score += 25;
  else if (base.includes("chess")) score += 15;
  else if (base.includes("main")) score += 10;
  if (isGeneratedOrExcludedPath(normalized)) score -= 100;
  score -= Math.floor(normalized.split("/").length / 2);
  return score;
}

async function extractCandidatesFromCommand(command: string, implPath: string, extensions: string[]): Promise<string[]> {
  if (!command || extensions.length === 0) {
    return [];
  }
  const extsPattern = extensions.map((ext) => ext.replace(".", "\\.")).join("|");
  const tokenPattern = new RegExp(`([A-Za-z0-9_./*+-]+(?:${extsPattern}))`, "g");
  const results: string[] = [];
  const seen = new Set<string>();

  for (const match of command.matchAll(tokenPattern)) {
    const raw = match[1].replace(/^[`'"([{]+|[`'"\])},;]+$/g, "");
    if (!raw) continue;
    if (raw.includes("*")) {
      const glob = new Bun.Glob(raw);
      for await (const path of glob.scan({ cwd: implPath, onlyFiles: true })) {
        const rel = normalizeRelPath(path);
        if (!seen.has(rel)) {
          seen.add(rel);
          results.push(rel);
        }
      }
      continue;
    }
    const absPath = join(implPath, raw);
    if (existsSync(absPath)) {
      const rel = normalizeRelPath(raw);
      if (!seen.has(rel)) {
        seen.add(rel);
        results.push(rel);
      }
    }
  }

  return results;
}

async function resolveEntrypointFile(implPath: string, language: string, metadata: Record<string, unknown>): Promise<string | null> {
  const extensions = parseSourceExts(metadata.source_exts);
  if (extensions.length === 0) {
    console.log(`⚠️ ${language}: metadata source_exts missing or invalid; cannot link TOKENS to entrypoint`);
    return null;
  }

  const candidates: string[] = [];
  const seen = new Set<string>();
  for (const key of ["build", "run", "test", "analyze"]) {
    const value = metadata[key];
    if (typeof value !== "string") continue;
    for (const rel of await extractCandidatesFromCommand(value, implPath, extensions)) {
      if (!seen.has(rel)) {
        seen.add(rel);
        candidates.push(rel);
      }
    }
  }

  for (const pattern of ["src/**/*", "bin/**/*", "*"]) {
    for (const ext of extensions) {
      const glob = new Bun.Glob(`${pattern}${ext}`);
      for await (const path of glob.scan({ cwd: implPath, onlyFiles: true })) {
        const rel = normalizeRelPath(path);
        if (seen.has(rel) || isGeneratedOrExcludedPath(rel)) continue;
        seen.add(rel);
        candidates.push(rel);
      }
    }
  }

  if (candidates.length === 0) return null;
  return candidates.sort((a, b) => {
    const scoreDiff = entrypointScore(b) - entrypointScore(a);
    return scoreDiff !== 0 ? scoreDiff : a.length - b.length;
  })[0];
}

function formatFeatureSummary(metadata: Record<string, unknown>): string {
  const features = Array.isArray(metadata.features) ? metadata.features.map((item) => normalizeFeatureName(String(item))) : [];
  const catalog = FEATURE_CATALOG.map((item) => normalizeFeatureName(item));
  const matchedCount = features.filter((feature, index) => features.indexOf(feature) === index && catalog.includes(feature)).length;
  return `${matchedCount}/${catalog.length}`;
}

function formatGroupedNumber(value: number | null | undefined): string {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return "-";
  }
  return new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(value);
}

interface LocalMetricSnapshot {
  sourceLoc: number | null;
  complexityScore: number | null;
}

const localMetricCache = new Map<string, Promise<LocalMetricSnapshot>>();

async function getLocalMetricSnapshot(implPath: string, language: string): Promise<LocalMetricSnapshot> {
  if (!localMetricCache.has(implPath)) {
    localMetricCache.set(implPath, (async () => {
      try {
        const localMetrics = await collectCodeSizeMetricsForImpl(implPath);
        const semantic = (
          localMetrics.semantic_metrics &&
          typeof localMetrics.semantic_metrics === "object" &&
          typeof (localMetrics.semantic_metrics as Record<string, unknown>).complexity_score === "number"
        )
          ? localMetrics.semantic_metrics as Record<string, unknown>
          : null;
        return {
          sourceLoc: Number.isInteger(localMetrics.source_loc) ? Number(localMetrics.source_loc) : null,
          complexityScore: semantic ? Number(semantic.complexity_score) : null,
        };
      } catch (error) {
        console.log(`⚠️ ${language}: could not compute local metric fallback: ${error instanceof Error ? error.message : String(error)}`);
        return { sourceLoc: null, complexityScore: null };
      }
    })());
  }
  return await localMetricCache.get(implPath)!;
}

async function loadPerformanceData(): Promise<Record<string, any>[]> {
  const reportsDir = join(REPO_ROOT, "reports");
  if (!existsSync(reportsDir)) {
    console.log("⚠️ Reports directory not found");
    return [];
  }

  const glob = new Bun.Glob("*.json");
  const data: Record<string, any>[] = [];
  for await (const file of glob.scan({ cwd: reportsDir, onlyFiles: true })) {
    if (file.endsWith("performance_data.json")) continue;
    try {
      const parsed = await readJsonFile<any>(join(reportsDir, file));
      if (Array.isArray(parsed)) data.push(...parsed);
      else data.push(parsed);
    } catch (error) {
      console.log(`⚠️ Error loading ${file}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  if (data.length === 0) console.log("⚠️ No performance data found");
  else console.log(`✅ Loaded performance data for ${data.length} implementations`);
  return data;
}

async function getVerificationStatus(): Promise<Record<string, string>> {
  const status: Record<string, string> = {};
  for (const implPath of await discoverImplementationDirs(IMPLEMENTATIONS_DIR)) {
    const result = await verifyImplementation(implPath, false);
    status[basename(implPath).toLowerCase()] = result.status;
  }
  return status;
}

async function resolveSourceLoc(implData: Record<string, any>, implPath: string, language: string): Promise<number | null> {
  const size = implData.size ?? {};
  if (Number.isInteger(size.source_loc) && size.source_loc >= 0) {
    return Number(size.source_loc);
  }
  const local = await getLocalMetricSnapshot(implPath, language);
  if (local.sourceLoc != null) {
    console.log(`⚠️ ${language}: missing report LOC, using local fallback`);
  }
  return local.sourceLoc;
}

async function resolveComplexityScore(implData: Record<string, any>, implPath: string, language: string): Promise<number | null> {
  const semantic = implData.semantic_metrics ?? {};
  if (typeof semantic.complexity_score === "number" && Number.isFinite(semantic.complexity_score)) {
    return Number(semantic.complexity_score);
  }
  const local = await getLocalMetricSnapshot(implPath, language);
  if (local.complexityScore != null) {
    console.log(`⚠️ ${language}: missing report semantic metrics, using local fallback`);
  }
  return local.complexityScore;
}

function resolveTestChessEngineSeconds(implData: Record<string, any>): number | null {
  const timings = implData.timings ?? {};
  let value = timings.test_chess_engine_seconds;
  const trackName = typeof implData.track === "string" ? implData.track.trim() : "";
  if (value == null && trackName) {
    value = timings[`test_${trackName.replaceAll("-", "_")}_seconds`];
  }
  if (value == null) {
    for (const key of [
      "test_v2_full_seconds",
      "test_v2_system_seconds",
      "test_v2_functional_seconds",
      "test_v2_foundation_seconds",
      "test_v1_seconds",
    ]) {
      if (timings[key] != null) {
        value = timings[key];
        break;
      }
    }
  }
  return value == null ? null : Number(value);
}

export async function updateReadmeStatusTable(): Promise<boolean> {
  console.log("=== Updating README Status Table ===");
  const performanceData = await loadPerformanceData();
  const verificationData = await getVerificationStatus();
  const combinedData = new Map<string, Record<string, any>>();

  for (const item of performanceData) {
    if (item.language) {
      combinedData.set(String(item.language).toLowerCase(), item);
    }
  }

  const implementations = (await discoverImplementationDirs(IMPLEMENTATIONS_DIR)).map((path) => basename(path).toLowerCase()).sort();
  if (implementations.length === 0) {
    console.log("❌ Error: Could not discover any implementations");
    return false;
  }

  for (const language of implementations) {
    if (!combinedData.has(language)) {
      combinedData.set(language, {
        language,
        timings: {},
        test_results: { passed: [], failed: [] },
        status: "completed",
      });
    }
  }

  const rows: string[] = [];
  for (const language of implementations) {
    const implData = combinedData.get(language) ?? {};
    const implPath = join(IMPLEMENTATIONS_DIR, language);
    const metadata = await getMetadata(implPath);
    const complexityScore = await resolveComplexityScore(implData, implPath, language);
    const sourceLoc = await resolveSourceLoc(implData, implPath, language);
    const entrypointFile = await resolveEntrypointFile(implPath, language, metadata);
    const status = verificationData[language] ?? "needs_work";
    const emoji = status === "excellent" ? "🟢" : status === "good" ? "🟡" : "🔴";
    const languageEmoji = CUSTOM_EMOJIS[language] ?? "📦";

    const timings = implData.timings ?? {};
    const memory = implData.memory ?? {};
    const buildStep = timings.build_seconds ?? null;
    const analyzeStep = timings.analyze_seconds ?? null;
    const testStep = timings.test_seconds ?? null;
    const ceStep = resolveTestChessEngineSeconds(implData);
    const buildMemory = Number(memory.build?.peak_memory_mb ?? 0);
    const analyzeMemory = Number(memory.analyze?.peak_memory_mb ?? 0);
    const testMemory = Number(memory.test?.peak_memory_mb ?? 0);
    const ceMemory = Number(memory.test_chess_engine?.peak_memory_mb ?? 0);

    let complexityDisplay = "-";
    if (typeof complexityScore === "number" && Number.isFinite(complexityScore)) {
      complexityDisplay = formatGroupedNumber(complexityScore);
    }
    if (entrypointFile && typeof complexityScore === "number" && Number.isFinite(complexityScore)) {
      const repoPath = normalizeRelPath(relative(REPO_ROOT, join(implPath, entrypointFile)));
      complexityDisplay = `[${formatGroupedNumber(complexityScore)}](${repoPath})`;
    }
    const locDisplay = sourceLoc == null ? "-" : formatGroupedInt(sourceLoc);

    rows.push(
      `| ${languageEmoji} ${language.charAt(0).toUpperCase()}${language.slice(1)} | ${complexityDisplay} | ${locDisplay} | ${formatStepMetric(buildStep, buildMemory)} | ${formatStepMetric(analyzeStep, analyzeMemory)} | ${formatStepMetric(testStep, testMemory)} | ${formatStepMetric(ceStep, ceMemory)} | ${emoji} ${formatFeatureSummary(metadata)} |`,
    );
  }

  const newTable = [
    "| Language | Complexity | LOC | make build | make analyze | make test | make test-chess-engine | Features |",
    "|----------|------------|-----|------------|--------------|-----------|------------------------|----------|",
    ...rows,
  ].join("\n");

  const readmePath = join(REPO_ROOT, "README.md");
  const content = await readTextFile(readmePath);
  if (!content.includes("<!-- status-table-start -->") || !content.includes("<!-- status-table-end -->")) {
    console.log("⚠️ Warning: README doesn't contain status table markers");
    return false;
  }

  const newContent = content.replace(
    /(<!-- status-table-start -->)[\s\S]*?(<!-- status-table-end -->)/m,
    `$1\n${newTable}\n$2`,
  );
  if (newContent === content) {
    console.log("⚠️ No changes detected in README content");
    return false;
  }

  await writeTextFile(readmePath, newContent);
  console.log("✅ README status table updated");
  return true;
}

export async function runUpdateReadme(): Promise<number> {
  const changed = await updateReadmeStatusTable();
  writeGithubOutput("changed", String(changed).toLowerCase());
  return 0;
}
