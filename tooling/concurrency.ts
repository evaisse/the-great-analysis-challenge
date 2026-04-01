import { basename, join, resolve } from "node:path";

import { getMetadata, readJsonFile, resolveImplPath, runCommand, writeJsonFile } from "./shared.ts";
import { ChessEngineTester } from "./chess.ts";

const DEFAULT_PROFILE_SPECS = {
  quick: {
    command: "concurrency quick",
    timeout_seconds: 120,
    required_fields: [
      "profile",
      "seed",
      "workers",
      "runs",
      "checksums",
      "deterministic",
      "invariant_errors",
      "deadlocks",
      "timeouts",
      "elapsed_ms",
      "ops_total",
    ],
    expected_zero_fields: ["invariant_errors", "deadlocks", "timeouts"],
    require_deterministic: true,
  },
  full: {
    command: "concurrency full",
    timeout_seconds: 300,
    required_fields: [
      "profile",
      "seed",
      "workers",
      "runs",
      "checksums",
      "deterministic",
      "invariant_errors",
      "deadlocks",
      "timeouts",
      "elapsed_ms",
      "ops_total",
    ],
    expected_zero_fields: ["invariant_errors", "deadlocks", "timeouts"],
    require_deterministic: true,
  },
};

const CHECKSUM_RE = /^[0-9a-f]{8,16}$/;

export function extractConcurrencyPayload(output: string): [boolean, Record<string, any>, string] {
  const marker = "CONCURRENCY:";
  for (const line of output.split("\n")) {
    const trimmed = line.trim();
    if (trimmed.toUpperCase().startsWith(marker)) {
      const payloadRaw = trimmed.slice(marker.length).trim();
      try {
        return [true, JSON.parse(payloadRaw), ""];
      } catch (error) {
        return [false, {}, `Invalid JSON payload: ${error instanceof Error ? error.message : String(error)}`];
      }
    }
  }
  return [false, {}, "Missing CONCURRENCY: payload"];
}

function validatePayload(payload: Record<string, any>, profileSpec: Record<string, any>): string[] {
  const issues: string[] = [];
  for (const field of profileSpec.required_fields ?? []) {
    if (!(field in payload)) {
      issues.push(`missing field: ${field}`);
    }
  }
  if (issues.length > 0) return issues;

  const expectedProfile = String(profileSpec.command ?? "").split(/\s+/).pop();
  if (expectedProfile && payload.profile !== expectedProfile) {
    issues.push(`profile must match requested profile '${expectedProfile}' (got ${JSON.stringify(payload.profile)})`);
  }
  if (profileSpec.require_deterministic && payload.deterministic !== true) {
    issues.push("deterministic must be true");
  }

  for (const field of profileSpec.expected_zero_fields ?? []) {
    if ((payload[field] ?? 0) !== 0) {
      issues.push(`${field} must be 0 (got ${payload[field]})`);
    }
  }

  for (const [field, minimum] of Object.entries({ seed: 0, workers: 1, runs: 1, elapsed_ms: 0, ops_total: 1 })) {
    if (!Number.isInteger(payload[field])) {
      issues.push(`${field} must be an integer`);
      continue;
    }
    if (payload[field] < minimum) {
      issues.push(`${field} must be >= ${minimum} (got ${payload[field]})`);
    }
  }

  if (!Array.isArray(payload.checksums) || payload.checksums.length === 0) {
    issues.push("checksums must be a non-empty list");
  } else {
    if (Number.isInteger(payload.runs) && payload.checksums.length !== payload.runs) {
      issues.push(`checksums length must equal runs (${payload.checksums.length} != ${payload.runs})`);
    }
    payload.checksums.forEach((checksum: unknown, index: number) => {
      if (typeof checksum !== "string") {
        issues.push(`checksum[${index}] must be a string`);
      } else if (!CHECKSUM_RE.test(checksum)) {
        issues.push(`checksum[${index}] must match ${CHECKSUM_RE.source} (got ${JSON.stringify(checksum)})`);
      }
    });
  }

  return issues;
}

async function runSingleProbe(
  implPath: string,
  profile: string,
  profileSpec: Record<string, any>,
  dockerImage: string,
): Promise<[Record<string, any> | null, string[]]> {
  const metadata = await getMetadata(implPath);
  const tester = new ChessEngineTester(implPath, metadata, dockerImage);
  if (!(await tester.start())) {
    return [null, ["engine failed to start", ...tester.results.errors]];
  }

  try {
    const command = String(profileSpec.command ?? `concurrency ${profile}`);
    const timeoutSeconds = Number(profileSpec.timeout_seconds ?? (profile === "quick" ? 120 : 300));
    const output = await tester.sendCommand(command, timeoutSeconds);
    const [ok, payload, parseError] = extractConcurrencyPayload(output);
    return ok ? [payload, []] : [null, [parseError]];
  } finally {
    await tester.stop();
  }
}

export interface ConcurrencyOptions {
  impl?: string;
  dir?: string;
  profile?: "quick" | "full";
  dockerImage?: string;
  skipBuild?: boolean;
  fixture?: string;
  output?: string;
  timeout?: number;
}

export function applyConcurrencyTimeoutCap(profileSpec: Record<string, any>, timeout?: number): Record<string, any> {
  if (!timeout || !Number.isFinite(timeout) || timeout <= 0) {
    return profileSpec;
  }
  return {
    ...profileSpec,
    timeout_seconds: Math.min(Number(profileSpec.timeout_seconds ?? timeout), Number(timeout)),
  };
}

export async function runConcurrencyHarness(options: ConcurrencyOptions): Promise<number> {
  const profile = options.profile ?? "quick";
  const profileSpecs = options.fixture
    ? (await readJsonFile<Record<string, any>>(resolve(options.fixture))).profiles ?? DEFAULT_PROFILE_SPECS
    : DEFAULT_PROFILE_SPECS;
  const profileSpec = applyConcurrencyTimeoutCap(profileSpecs[profile] ?? DEFAULT_PROFILE_SPECS[profile], options.timeout);
  const implementations = options.impl
    ? [resolveImplPath(options.impl)]
    : (await import("./shared.ts")).discoverImplementationDirs(resolve(options.dir ?? join(process.cwd(), "implementations")));

  const results: Record<string, any>[] = [];
  for (const implPath of await implementations) {
    const implName = basename(implPath);
    const dockerImage = options.dockerImage ?? `chess-${implName}`;
    if (!options.skipBuild) {
      console.log(`🔧 Building Docker image for ${implName}...`);
      const buildResult = await runCommand(["make", "build", `DIR=${implName}`], { check: false });
      if (buildResult.exitCode !== 0) {
        results.push({
          implementation: implName,
          docker_image: dockerImage,
          profile,
          status: "failed",
          issues: [buildResult.stderr || buildResult.stdout || "build failed"],
          payload: null,
        });
        continue;
      }
    }

    const [payload, issues] = await runSingleProbe(implPath, profile, profileSpec, dockerImage);
    const result = {
      implementation: implName,
      docker_image: dockerImage,
      profile,
      status: "failed",
      issues: [...issues],
      payload,
    };

    if (!payload) {
      results.push(result);
      continue;
    }

    const payloadIssues = validatePayload(payload, profileSpec);
    if (payloadIssues.length > 0) {
      result.issues.push(...payloadIssues);
      results.push(result);
      continue;
    }

    const [rerunPayload, rerunIssues] = await runSingleProbe(implPath, profile, profileSpec, dockerImage);
    if (rerunIssues.length > 0 || !rerunPayload) {
      result.issues.push(...rerunIssues.map((issue) => `rerun: ${issue}`));
      results.push(result);
      continue;
    }

    const rerunValidation = validatePayload(rerunPayload, profileSpec);
    if (rerunValidation.length > 0) {
      result.issues.push(...rerunValidation.map((issue) => `rerun: ${issue}`));
      results.push(result);
      continue;
    }

    if (JSON.stringify(rerunPayload.checksums) !== JSON.stringify(payload.checksums)) {
      result.issues.push("checksums changed between identical runs");
      results.push(result);
      continue;
    }

    result.status = "passed";
    results.push(result);
  }

  if (options.output) {
    const payload = results.length === 1 ? results[0] : results;
    await writeJsonFile(options.output, payload);
  }

  for (const result of results) {
    console.log(`${result.status === "passed" ? "✅" : "❌"} ${result.implementation} (${result.profile})`);
    for (const issue of result.issues) {
      console.log(`  - ${issue}`);
    }
  }

  return results.every((result) => result.status === "passed") ? 0 : 1;
}
