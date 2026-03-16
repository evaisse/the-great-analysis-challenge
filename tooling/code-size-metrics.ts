import { resolve } from "node:path";
import { parseArgs } from "node:util";

import {
  collectImplMetricsFromMetadata,
  discoverImplementationDirs,
  getMetadata,
  resolveImplPath,
} from "./shared.ts";
import { collectSemanticMetrics, toSemanticMetricsSubset } from "./semantic-tokens.ts";

export async function collectCodeSizeMetricsForImpl(implPath: string): Promise<Record<string, unknown>> {
  const metadata = await getMetadata(implPath);
  const metrics = await collectImplMetricsFromMetadata(implPath, metadata);
  const result: Record<string, unknown> = {
    implementation: metrics.implementation,
    path: metrics.path,
    source_files: metrics.source_files,
    source_loc: metrics.source_loc,
    tokens_count: metrics.tokens_count,
    metric_version: metrics.metric_version,
    source_exts: metrics.source_exts,
    skipped_binary_or_unreadable: metrics.skipped_binary_or_unreadable,
  };

  const semantic = await collectSemanticMetrics(implPath);
  if (semantic) {
    result.semantic_metrics = toSemanticMetricsSubset(semantic);
  }

  return result;
}

export async function collectCodeSizeMetricsForDir(baseDir: string): Promise<Record<string, unknown>[]> {
  const results: Record<string, unknown>[] = [];
  for (const implPath of await discoverImplementationDirs(baseDir)) {
    results.push(await collectCodeSizeMetricsForImpl(implPath));
  }
  return results;
}

export async function runCodeSizeMetricsCli(args: string[]): Promise<number> {
  const { values } = parseArgs({
    args,
    options: {
      impl: { type: "string" },
      dir: { type: "string" },
      pretty: { type: "boolean" },
    },
  });

  const indent = values.pretty ? 2 : undefined;

  try {
    if (values.impl) {
      const implPath = resolveImplPath(values.impl);
      console.log(JSON.stringify(await collectCodeSizeMetricsForImpl(implPath), null, indent));
      return 0;
    }

    const baseDir = resolve(values.dir ?? "implementations");
    console.log(JSON.stringify(await collectCodeSizeMetricsForDir(baseDir), null, indent));
    return 0;
  } catch (error) {
    console.log(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }, null, indent));
    return 1;
  }
}
