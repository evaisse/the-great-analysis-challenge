import { basename, join, resolve } from "node:path";
import { existsSync } from "node:fs";
import { parseArgs } from "node:util";

import { collectCodeSizeMetricsForImpl } from "./code-size-metrics.ts";
import {
  IMPLEMENTATIONS_DIR,
  REPO_ROOT,
  REPORTS_DIR,
  readJsonFile,
  writeJsonFile,
} from "./shared.ts";

function resolveImplementationPath(entry: Record<string, unknown>, fallbackName: string | null = null): string | null {
  const pathCandidates: string[] = [];
  if (typeof entry.path === "string" && entry.path.trim() !== "") {
    pathCandidates.push(resolve(REPO_ROOT, entry.path));
  }

  for (const candidate of pathCandidates) {
    if (existsSync(candidate) && existsSync(join(candidate, "Dockerfile"))) {
      return candidate;
    }
  }

  const nameCandidates = [
    typeof entry.implementation === "string" ? entry.implementation : null,
    typeof entry.language === "string" ? entry.language : null,
    fallbackName,
  ].filter((value): value is string => typeof value === "string" && value.trim() !== "");

  for (const name of nameCandidates) {
    const implPath = join(IMPLEMENTATIONS_DIR, name.toLowerCase());
    if (existsSync(implPath) && existsSync(join(implPath, "Dockerfile"))) {
      return implPath;
    }
  }

  return null;
}

function fallbackNameForReportFile(file: string): string | null {
  const stem = basename(file, ".json");
  if (stem === "performance_data" || stem.endsWith("-concurrency")) {
    return null;
  }
  return stem;
}

type RefreshStats = {
  filesTouched: number;
  entriesUpdated: number;
  entriesSkipped: number;
};

export async function refreshSemanticReportMetrics(reportDir = REPORTS_DIR): Promise<RefreshStats> {
  const stats: RefreshStats = {
    filesTouched: 0,
    entriesUpdated: 0,
    entriesSkipped: 0,
  };
  const metricCache = new Map<string, Promise<Record<string, unknown>>>();

  async function loadMetricsForImpl(implPath: string): Promise<Record<string, unknown>> {
    if (!metricCache.has(implPath)) {
      metricCache.set(implPath, collectCodeSizeMetricsForImpl(implPath));
    }
    return await metricCache.get(implPath)!;
  }

  async function refreshEntry(entry: unknown, fallbackName: string | null): Promise<unknown> {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      stats.entriesSkipped += 1;
      return entry;
    }

    const typedEntry = entry as Record<string, unknown>;
    const implPath = resolveImplementationPath(typedEntry, fallbackName);
    if (!implPath) {
      stats.entriesSkipped += 1;
      return typedEntry;
    }

    const metrics = await loadMetricsForImpl(implPath);
    const updated = { ...typedEntry };
    updated.size = {
      ...(typeof typedEntry.size === "object" && typedEntry.size ? typedEntry.size as Record<string, unknown> : {}),
      source_loc: metrics.source_loc ?? null,
      source_files: metrics.source_files ?? null,
    };
    updated.metrics = {
      ...(typeof typedEntry.metrics === "object" && typedEntry.metrics ? typedEntry.metrics as Record<string, unknown> : {}),
      tokens_count: metrics.tokens_count ?? null,
      metric_version: metrics.metric_version ?? null,
    };
    updated.semantic_metrics = metrics.semantic_metrics ?? null;
    stats.entriesUpdated += 1;
    return updated;
  }

  const reportFiles = [
    "performance_data.json",
    ...await (async () => {
      const files: string[] = [];
      const glob = new Bun.Glob("*.json");
      for await (const file of glob.scan({ cwd: reportDir, onlyFiles: true })) {
        if (file === "performance_data.json" || file.endsWith("-concurrency.json")) {
          continue;
        }
        files.push(file);
      }
      return files.sort();
    })(),
  ];

  for (const file of reportFiles) {
    const filePath = join(reportDir, file);
    if (!existsSync(filePath)) {
      continue;
    }

    const fallbackName = fallbackNameForReportFile(file);
    const data = await readJsonFile<unknown>(filePath);
    const refreshed = Array.isArray(data)
      ? await Promise.all(data.map((entry) => refreshEntry(entry, fallbackName)))
      : await refreshEntry(data, fallbackName);

    if (JSON.stringify(data) === JSON.stringify(refreshed)) {
      continue;
    }

    await writeJsonFile(filePath, refreshed);
    stats.filesTouched += 1;
  }

  return stats;
}

export async function runRefreshReportMetricsCli(args: string[]): Promise<number> {
  const { values } = parseArgs({
    args,
    options: {
      "report-dir": { type: "string" },
    },
  });

  const reportDir = values["report-dir"] ? resolve(values["report-dir"]) : REPORTS_DIR;
  const stats = await refreshSemanticReportMetrics(reportDir);
  console.log(
    `✅ Refreshed report metrics in ${stats.filesTouched} file(s); updated ${stats.entriesUpdated} entr${stats.entriesUpdated === 1 ? "y" : "ies"}, skipped ${stats.entriesSkipped}.`,
  );
  return 0;
}
