import { existsSync } from "node:fs";
import { basename, dirname, join } from "node:path";

import {
  IMPLEMENTATIONS_DIR,
  getMetadata,
  normalizeFeatureName,
  readTextFile,
  statusEmoji,
} from "./shared.ts";

const REQUIRED_FILES: Record<string, string> = {
  "Dockerfile": "Docker container definition",
  "Makefile": "Build automation",
  "README.md": "Implementation documentation",
};

const REQUIRED_MAKEFILE_TARGETS = new Set([
  "all",
  "build",
  "test",
  "analyze",
  "clean",
  "docker-build",
  "docker-test",
  "help",
]);

const REQUIRED_META_FIELDS = new Set([
  "language",
  "version",
  "author",
  "build",
  "run",
  "test",
  "analyze",
  "features",
  "max_ai_depth",
  "source_exts",
]);

const RECOMMENDED_META_FIELDS = new Set([
  "estimated_perft4_ms",
  "bugit",
  "fix",
  "test_contract",
]);

const EXPECTED_FEATURES = new Set([
  "perft",
  "fen",
  "ai",
  "castling",
  "en_passant",
  "promotion",
]);

const PYTHON_TOOLING_PACKAGES = new Set([
  "mypy",
  "pylint",
  "flake8",
  "black",
  "bandit",
  "pytest",
  "coverage",
  "ruff",
  "isort",
]);

const HASKELL_STDLIB_PACKAGES = new Set(["base", "containers", "array", "time"]);
const KOTLIN_STDLIB_COORDS = new Set([
  "org.jetbrains.kotlin:kotlin-stdlib",
  "org.jetbrains.kotlin:kotlin-stdlib-jdk7",
  "org.jetbrains.kotlin:kotlin-stdlib-jdk8",
  "org.jetbrains.kotlin:kotlin-stdlib-common",
]);

type CheckResult = { errors: string[]; warnings: string[]; info: string[] };

function emptyCheckResult(): CheckResult {
  return { errors: [], warnings: [], info: [] };
}

export async function findImplementations(baseDir = process.cwd()): Promise<string[]> {
  const implementationsDir = join(baseDir, "implementations");
  if (!existsSync(implementationsDir)) {
    console.log(`❌ Implementations directory not found: ${implementationsDir}`);
    return [];
  }

  const dirs = await import("node:fs/promises").then((mod) => mod.readdir(implementationsDir, { withFileTypes: true }));
  return dirs.filter((entry) => entry.isDirectory()).map((entry) => join(implementationsDir, entry.name));
}

function checkRequiredFiles(implDir: string): [string[], string[]] {
  const found: string[] = [];
  const missing: string[] = [];
  for (const [file, description] of Object.entries(REQUIRED_FILES)) {
    if (existsSync(join(implDir, file))) {
      found.push(file);
    } else {
      missing.push(`${file} (${description})`);
    }
  }
  return [found, missing];
}

async function checkDockerfileFormat(dockerfilePath: string): Promise<string[]> {
  const issues: string[] = [];
  const implName = basename(dirname(dockerfilePath));
  const expectedBase = `FROM ghcr.io/evaisse/tgac-${implName}-toolchain:latest`;
  try {
    const content = await readTextFile(dockerfilePath);
    const lines = content.split("\n");
    if (!lines[0]?.startsWith(expectedBase)) {
      issues.push(`Dockerfile MUST start with '${expectedBase}'`);
    }
    if (!content.includes("LABEL org.chess.language")) {
      issues.push("Dockerfile missing LABEL org.chess.language");
    }
    if (/\b(?:apt-get|wget|curl)\b/.test(content)) {
      issues.push("Dockerfile contains external download commands (apt-get, wget, curl). Move these to toolchain image.");
    }
  } catch (error) {
    issues.push(`Error reading Dockerfile: ${error instanceof Error ? error.message : String(error)}`);
  }
  return issues;
}

function checkToolchainPresence(implDir: string): string[] {
  const toolchain = join(implDir, "docker-images", "toolchain", "Dockerfile");
  return existsSync(toolchain) ? [] : [`Missing toolchain definition at ${toolchain.replace(`${IMPLEMENTATIONS_DIR}/`, "")}`];
}

async function checkMakefileTargets(makefilePath: string): Promise<[Set<string>, Set<string>]> {
  const found = new Set<string>();
  try {
    const content = await readTextFile(makefilePath);
    for (const line of content.split("\n")) {
      const trimmed = line.trim();
      if (trimmed.includes(":") && !trimmed.startsWith("#") && !trimmed.startsWith("\t")) {
        found.add(trimmed.split(":", 1)[0].trim());
      }
    }
    if (!content.includes(".PHONY")) {
      found.add("_missing_phony");
    }
  } catch (error) {
    found.add(`_error_${error instanceof Error ? error.message : String(error)}`);
  }
  const missing = new Set([...REQUIRED_MAKEFILE_TARGETS].filter((target) => !found.has(target)));
  return [found, missing];
}

function checkMetaPathStandards(data: Record<string, unknown>, implName: string): CheckResult {
  const result = emptyCheckResult();
  for (const field of ["build", "run", "analyze", "test", "test_contract"]) {
    const command = String(data[field] ?? "");
    if (!command) continue;
    if (command.includes(`cd ${implName}`)) {
      result.errors.push(`${field}: Contains 'cd ${implName}' - should use relative paths from implementation directory`);
    }
    if (command.includes(`${implName}/`)) {
      result.warnings.push(`${field}: Contains '${implName}/' prefix - should use relative paths`);
    }
    if (command.startsWith("/")) {
      result.warnings.push(`${field}: Uses absolute path - should use relative paths`);
    }
    if (command.includes("../")) {
      result.warnings.push(`${field}: Contains '../' - verify working directory assumptions`);
    }
  }
  return result;
}

function validateMetadata(data: Record<string, unknown>, implName: string, requireTestContract: boolean): CheckResult {
  const result = emptyCheckResult();
  const missingRequired = [...REQUIRED_META_FIELDS].filter((field) => !(field in data));
  result.errors.push(...missingRequired.map((field) => `Missing required field: ${field}`));

  const missingRecommended = [...RECOMMENDED_META_FIELDS].filter((field) => !(field in data));
  if (requireTestContract && missingRecommended.includes("test_contract")) {
    result.errors.push("Missing required field: test_contract");
  }
  result.warnings.push(...missingRecommended.filter((field) => field !== "test_contract").map((field) => `Missing recommended field: ${field}`));

  const rawFeatures = Array.isArray(data.features) ? data.features.map((value) => normalizeFeatureName(String(value))) : [];
  const featureSet = new Set(rawFeatures);
  for (const feature of EXPECTED_FEATURES) {
    if (!featureSet.has(feature)) {
      result.warnings.push(`Missing feature: ${feature}`);
    }
  }
  for (const feature of featureSet) {
    if (!EXPECTED_FEATURES.has(feature)) {
      result.info.push(`Extra feature: ${feature}`);
    }
  }

  const sourceExts = Array.isArray(data.source_exts) ? data.source_exts.map((value) => String(value).trim().toLowerCase()) : [];
  if (sourceExts.length === 0) {
    result.errors.push("source_exts must be a non-empty list");
  } else {
    const invalidExts = sourceExts.filter((ext) => !/^\.[a-z0-9_+#-]+$/.test(ext));
    if (invalidExts.length > 0) {
      result.errors.push(`source_exts contains invalid extension(s): ${invalidExts.join(", ")}`);
    }
    result.info.push(`Source extensions: ${[...new Set(sourceExts)].sort().join(", ")}`);
  }

  const depth = Number.parseInt(String(data.max_ai_depth ?? ""), 10);
  if (Number.isNaN(depth)) {
    result.warnings.push(`max_ai_depth should be an integer, got: ${String(data.max_ai_depth ?? "")}`);
  } else if (depth < 1 || depth > 10) {
    result.warnings.push(`max_ai_depth should be between 1-10, got: ${depth}`);
  }

  const pathIssues = checkMetaPathStandards(data, implName);
  result.errors.push(...pathIssues.errors);
  result.warnings.push(...pathIssues.warnings);
  result.info.push(`Language: ${String(data.language ?? "unknown")}`);
  result.info.push(`Version: ${String(data.version ?? "unknown")}`);
  if ("test_contract" in data) {
    result.info.push("Unit contract adapter declared");
  }
  return result;
}

async function checkPackageDependencies(implDir: string, language: string): Promise<CheckResult> {
  const result = emptyCheckResult();
  const lower = language.toLowerCase();
  if (lower === "typescript" || lower === "javascript") {
    const packageJsonPath = join(implDir, "package.json");
    if (!existsSync(packageJsonPath)) {
      result.errors.push("Missing package.json file");
      return result;
    }
    const packageData = JSON.parse(await readTextFile(packageJsonPath));
    const scripts = packageData.scripts ?? {};
    const missingScripts = ["build", "test", "lint"].filter((script) => !(script in scripts));
    result.errors.push(...missingScripts.map((script) => `Missing required npm script: ${script}`));
    result.info.push(`Found ${Object.keys(scripts).length} npm scripts`);
    return result;
  }
  if (lower === "ruby") {
    if (existsSync(join(implDir, "Gemfile"))) {
      result.info.push("Found Gemfile");
    } else {
      result.warnings.push("No Gemfile found");
    }
    return result;
  }
  if (lower === "python") {
    const found = ["requirements.txt", "requirements-dev.txt", "pyproject.toml"].find((file) => existsSync(join(implDir, file)));
    if (found) {
      result.info.push(`Found ${found}`);
    } else {
      result.warnings.push("No requirements file found");
    }
    return result;
  }
  result.info.push(`No dependency checks implemented for ${language}`);
  return result;
}

async function checkStdlibOnly(implDir: string, language: string): Promise<CheckResult> {
  const result = emptyCheckResult();
  const lower = language.toLowerCase();

  if (["typescript", "javascript", "imba", "rescript", "elm"].includes(lower)) {
    const packageJsonPath = join(implDir, "package.json");
    if (!existsSync(packageJsonPath)) {
      result.info.push("No package.json found");
      return result;
    }
    const packageData = JSON.parse(await readTextFile(packageJsonPath));
    const dependencies = Object.keys(packageData.dependencies ?? {});
    const devDependencies = Object.keys(packageData.devDependencies ?? {});
    if (dependencies.length > 0) {
      result.errors.push(`Runtime dependencies found: ${dependencies.sort().join(", ")}`);
    }
    if (devDependencies.length > 0) {
      result.warnings.push(`Dev dependencies present: ${devDependencies.sort().join(", ")}`);
    }
    return result;
  }

  if (lower === "python") {
    const files = ["requirements.txt", "requirements-dev.txt", "requirements-dev.in"];
    let found = false;
    for (const file of files) {
      const path = join(implDir, file);
      if (!existsSync(path)) continue;
      found = true;
      const packages = (await readTextFile(path))
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("#"))
        .map((line) => line.split(";", 1)[0].trim())
        .map((line) => line.split(/[<=>~! ]/, 1)[0].trim())
        .filter(Boolean);
      const nonTooling = packages.filter((pkg) => !PYTHON_TOOLING_PACKAGES.has(pkg) && !pkg.startsWith("types-"));
      if (nonTooling.length > 0) {
        result.errors.push(`Non-tooling requirements found: ${[...new Set(nonTooling)].sort().join(", ")}`);
      } else if (packages.length > 0) {
        result.warnings.push(`Tooling requirements present in ${file}: ${[...new Set(packages)].sort().join(", ")}`);
      }
    }
    if (!found) result.info.push("No requirements files found");
    return result;
  }

  if (lower === "ruby") {
    const gemfilePath = join(implDir, "Gemfile");
    if (!existsSync(gemfilePath)) {
      result.info.push("No Gemfile found");
      return result;
    }
    const runtimeGems: string[] = [];
    const devGems: string[] = [];
    let inDevGroup = false;
    for (const line of (await readTextFile(gemfilePath)).split("\n")) {
      const stripped = line.trim();
      if (!stripped || stripped.startsWith("#")) continue;
      if (stripped.startsWith("group ") && (stripped.includes("development") || stripped.includes("test"))) {
        inDevGroup = true;
        continue;
      }
      if (stripped === "end") {
        inDevGroup = false;
        continue;
      }
      const match = stripped.match(/gem\s+['"]([^'"]+)['"]/);
      if (!match) continue;
      (inDevGroup ? devGems : runtimeGems).push(match[1]);
    }
    if (runtimeGems.length > 0) result.errors.push(`Runtime gems found: ${[...new Set(runtimeGems)].sort().join(", ")}`);
    if (devGems.length > 0) result.warnings.push(`Dev/test gems present: ${[...new Set(devGems)].sort().join(", ")}`);
    return result;
  }

  if (lower === "dart") {
    const pubspecPath = join(implDir, "pubspec.yaml");
    if (!existsSync(pubspecPath)) {
      result.info.push("No pubspec.yaml found");
      return result;
    }
    const deps: string[] = [];
    const devDeps: string[] = [];
    let current: "dependencies" | "dev_dependencies" | null = null;
    for (const line of (await readTextFile(pubspecPath)).split("\n")) {
      const raw = line.replace(/\r$/, "");
      const stripped = raw.trim();
      if (!stripped || stripped.startsWith("#")) continue;
      if (!raw.startsWith(" ") && stripped.endsWith(":")) {
        current = stripped === "dependencies:" ? "dependencies" : stripped === "dev_dependencies:" ? "dev_dependencies" : null;
        continue;
      }
      if (current && raw.startsWith("  ") && stripped.includes(":")) {
        const name = stripped.split(":", 1)[0].trim();
        if (name === "sdk") continue;
        (current === "dependencies" ? deps : devDeps).push(name);
      }
    }
    if (deps.length > 0) result.errors.push(`Dart dependencies found: ${[...new Set(deps)].sort().join(", ")}`);
    if (devDeps.length > 0) result.warnings.push(`Dart dev_dependencies present: ${[...new Set(devDeps)].sort().join(", ")}`);
    return result;
  }

  if (lower === "rust") {
    const cargoPath = join(implDir, "Cargo.toml");
    if (!existsSync(cargoPath)) {
      result.info.push("No Cargo.toml found");
      return result;
    }
    const deps = { dependencies: [] as string[], "dev-dependencies": [] as string[], "build-dependencies": [] as string[] };
    let current: keyof typeof deps | null = null;
    for (const line of (await readTextFile(cargoPath)).split("\n")) {
      const stripped = line.trim();
      if (!stripped || stripped.startsWith("#")) continue;
      if (stripped.startsWith("[") && stripped.endsWith("]")) {
        const section = stripped.slice(1, -1);
        current = section in deps ? (section as keyof typeof deps) : null;
        continue;
      }
      if (current && stripped.includes("=")) {
        deps[current].push(stripped.split("=", 1)[0].trim());
      }
    }
    if (deps.dependencies.length > 0) result.errors.push(`Rust dependencies found: ${[...new Set(deps.dependencies)].sort().join(", ")}`);
    const dev = [...deps["dev-dependencies"], ...deps["build-dependencies"]];
    if (dev.length > 0) result.warnings.push(`Rust dev/build dependencies present: ${[...new Set(dev)].sort().join(", ")}`);
    return result;
  }

  if (lower === "go") {
    const gomodPath = join(implDir, "go.mod");
    if (!existsSync(gomodPath)) {
      result.info.push("No go.mod found");
      return result;
    }
    const requires: string[] = [];
    let inBlock = false;
    for (const line of (await readTextFile(gomodPath)).split("\n")) {
      const stripped = line.trim();
      if (!stripped || stripped.startsWith("//")) continue;
      if (stripped.startsWith("require (")) {
        inBlock = true;
        continue;
      }
      if (inBlock) {
        if (stripped === ")") {
          inBlock = false;
          continue;
        }
        requires.push(stripped.split(/\s+/, 1)[0]);
        continue;
      }
      if (stripped.startsWith("require ")) {
        requires.push(stripped.slice("require ".length).split(/\s+/, 1)[0]);
      }
    }
    if (requires.length > 0) result.errors.push(`Go module dependencies found: ${[...new Set(requires)].sort().join(", ")}`);
    return result;
  }

  if (lower === "php") {
    const composerPath = join(implDir, "composer.json");
    if (!existsSync(composerPath)) {
      result.info.push("No composer.json found");
      return result;
    }
    const data = JSON.parse(await readTextFile(composerPath));
    const runtime = Object.keys(data.require ?? {}).filter((key) => key !== "php" && !key.startsWith("ext-"));
    const dev = Object.keys(data["require-dev"] ?? {});
    if (runtime.length > 0) result.errors.push(`Composer runtime dependencies found: ${runtime.sort().join(", ")}`);
    if (dev.length > 0) result.warnings.push(`Composer dev dependencies present: ${dev.sort().join(", ")}`);
    return result;
  }

  if (lower === "kotlin") {
    const gradlePath = [join(implDir, "build.gradle.kts"), join(implDir, "build.gradle")].find((path) => existsSync(path));
    if (!gradlePath) {
      result.info.push("No Gradle build file found");
      return result;
    }
    const runtime: string[] = [];
    const tests: string[] = [];
    let inBlock = false;
    let braceDepth = 0;
    for (const line of (await readTextFile(gradlePath)).split("\n")) {
      const stripped = line.trim();
      if (stripped.startsWith("dependencies")) {
        if (stripped.includes("{")) {
          inBlock = true;
          braceDepth += (stripped.match(/{/g) ?? []).length - (stripped.match(/}/g) ?? []).length;
        }
        continue;
      }
      if (!inBlock) continue;
      braceDepth += (stripped.match(/{/g) ?? []).length - (stripped.match(/}/g) ?? []).length;
      if (braceDepth <= 0) {
        inBlock = false;
        continue;
      }
      if (/^(implementation|api|compileOnly|runtimeOnly)/.test(stripped)) {
        runtime.push(stripped);
      } else if (/^(testImplementation|testCompileOnly|testRuntimeOnly)/.test(stripped)) {
        tests.push(stripped);
      }
    }
    const filteredRuntime = runtime.filter((entry) => ![...KOTLIN_STDLIB_COORDS].some((coord) => entry.includes(coord)) && !entry.includes('kotlin("stdlib'));
    if (filteredRuntime.length > 0) result.errors.push(`Kotlin runtime dependencies found: ${filteredRuntime.join("; ")}`);
    if (tests.length > 0) result.warnings.push(`Kotlin test dependencies present: ${tests.join("; ")}`);
    return result;
  }

  if (lower === "swift") {
    const packagePath = join(implDir, "Package.swift");
    if (!existsSync(packagePath)) {
      result.info.push("No Package.swift found");
      return result;
    }
    const packages = (await readTextFile(packagePath)).split("\n").map((line) => line.trim()).filter((line) => line.includes(".package("));
    if (packages.length > 0) result.errors.push(`Swift package dependencies found: ${packages.join("; ")}`);
    return result;
  }

  if (lower === "haskell") {
    const cabalPath = join(implDir, "chess.cabal");
    if (!existsSync(cabalPath)) {
      result.info.push("No .cabal file found");
      return result;
    }
    const deps: string[] = [];
    let collecting = false;
    for (const line of (await readTextFile(cabalPath)).split("\n")) {
      const stripped = line.trim();
      if (stripped.startsWith("build-depends:")) {
        collecting = true;
        deps.push(...stripped.split(":", 2)[1].split(",").map((item) => item.trim()).filter(Boolean));
        continue;
      }
      if (collecting) {
        if (stripped === "" || !line.startsWith(" ")) {
          collecting = false;
          continue;
        }
        deps.push(...line.split(",").map((item) => item.trim()).filter(Boolean));
      }
    }
    const packages = deps.map((dep) => dep.split(/\s+/, 1)[0]).filter(Boolean);
    const nonStd = packages.filter((pkg) => !HASKELL_STDLIB_PACKAGES.has(pkg));
    if (nonStd.length > 0) result.errors.push(`Haskell dependencies found: ${[...new Set(nonStd)].sort().join(", ")}`);
    return result;
  }

  result.info.push(`No stdlib-only checks implemented for ${language}`);
  return result;
}

export async function verifyImplementation(implDir: string, requireTestContract = false): Promise<Record<string, any>> {
  const implName = basename(implDir);
  const result: Record<string, any> = {
    name: implName,
    path: implDir,
    status: "unknown",
    files: {},
    dockerfile: {},
    makefile: {},
    chess_meta: {},
    summary: { errors: 0, warnings: 0, info: 0 },
  };

  const [foundFiles, missingFiles] = checkRequiredFiles(implDir);
  const toolchainIssues = checkToolchainPresence(implDir);
  result.toolchain = { issues: toolchainIssues };
  result.summary.errors += toolchainIssues.length;

  const metadata = await getMetadata(implDir);
  if (Object.keys(metadata).length === 0) {
    missingFiles.push("Dockerfile labels (org.chess.*)");
  }
  result.files = { found: foundFiles, missing: missingFiles };
  result.summary.errors += missingFiles.length;

  const dockerfilePath = join(implDir, "Dockerfile");
  if (existsSync(dockerfilePath)) {
    const dockerfileIssues = await checkDockerfileFormat(dockerfilePath);
    result.dockerfile = { issues: dockerfileIssues };
    result.summary.warnings += dockerfileIssues.length;
  }

  const makefilePath = join(implDir, "Makefile");
  if (existsSync(makefilePath)) {
    const [foundTargets, missingTargets] = await checkMakefileTargets(makefilePath);
    result.makefile = { found_targets: [...foundTargets], missing_targets: [...missingTargets] };
    result.summary.errors += missingTargets.size;
  }

  if (Object.keys(metadata).length > 0) {
    const metaResult = validateMetadata(metadata, implName, requireTestContract);
    result.chess_meta = metaResult;
    result.summary.errors += metaResult.errors.length;
    result.summary.warnings += metaResult.warnings.length;
    result.summary.info += metaResult.info.length;

    const language = String(metadata.language ?? "unknown");
    const dependencyResult = await checkPackageDependencies(implDir, language);
    result.dependencies = dependencyResult;
    result.summary.errors += dependencyResult.errors.length;
    result.summary.warnings += dependencyResult.warnings.length;
    result.summary.info += dependencyResult.info.length;

    const stdlibResult = await checkStdlibOnly(implDir, language);
    result.stdlib_only = stdlibResult;
    result.summary.errors += stdlibResult.errors.length;
    result.summary.warnings += stdlibResult.warnings.length;
    result.summary.info += stdlibResult.info.length;
  }

  if (result.summary.errors === 0) {
    result.status = result.summary.warnings === 0 ? "excellent" : "good";
  } else {
    result.status = "needs_work";
  }

  return result;
}

function printSection(title: string, items: string[], icon: string): void {
  if (items.length === 0) return;
  console.log(`\n${icon} ${title}:`);
  for (const item of items) {
    console.log(`   - ${item}`);
  }
}

export function printImplementationReport(result: Record<string, any>): void {
  console.log(`\n${statusEmoji(result.status)} **${result.name}** (${result.status})`);
  console.log("=".repeat(result.name.length + 20));
  printSection("Missing files", result.files.missing ?? [], "❌");
  printSection("Found files", result.files.found ?? [], "✅");
  printSection("Dockerfile issues", result.dockerfile.issues ?? [], "⚠️");
  printSection("Toolchain issues", result.toolchain.issues ?? [], "❌");
  printSection("Missing Makefile targets", result.makefile.missing_targets ?? [], "❌");
  printSection("Metadata errors", result.chess_meta.errors ?? [], "❌");
  printSection("Metadata warnings", result.chess_meta.warnings ?? [], "⚠️");
  printSection("Metadata info", result.chess_meta.info ?? [], "📝");
  printSection("Dependency check errors", result.dependencies?.errors ?? [], "❌");
  printSection("Dependency check warnings", result.dependencies?.warnings ?? [], "⚠️");
  printSection("Dependency check info", result.dependencies?.info ?? [], "📝");
  printSection("Standard library rule violations", result.stdlib_only?.errors ?? [], "❌");
  printSection("Standard library rule warnings", result.stdlib_only?.warnings ?? [], "⚠️");
  printSection("Standard library rule info", result.stdlib_only?.info ?? [], "📝");
}

export function printSummaryReport(results: Record<string, any>[]): void {
  const excellent = results.filter((item) => item.status === "excellent").length;
  const good = results.filter((item) => item.status === "good").length;
  const needsWork = results.filter((item) => item.status === "needs_work").length;

  console.log(`\n${"=".repeat(50)}`);
  console.log("📊 OVERALL SUMMARY");
  console.log("=".repeat(50));
  console.log(`Total implementations: ${results.length}`);
  console.log(`🟢 Excellent: ${excellent}`);
  console.log(`🟡 Good: ${good}`);
  console.log(`🔴 Needs work: ${needsWork}`);
}

export interface VerifyOptions {
  baseDir?: string;
  implementation?: string;
  requireTestContract?: boolean;
}

export async function runVerify(options: VerifyOptions): Promise<{ exitCode: number; results: Record<string, any>[] }> {
  const baseDir = options.baseDir ?? process.cwd();
  let implementations = await findImplementations(baseDir);
  if (options.implementation) {
    implementations = implementations.filter((implDir) => basename(implDir) === options.implementation);
  }

  const results: Record<string, any>[] = [];
  for (const implDir of implementations.sort()) {
    const result = await verifyImplementation(implDir, Boolean(options.requireTestContract));
    results.push(result);
    printImplementationReport(result);
  }
  printSummaryReport(results);
  return {
    exitCode: results.some((item) => item.status === "needs_work") ? 1 : 0,
    results,
  };
}
