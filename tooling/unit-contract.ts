import { join, resolve } from "node:path";

import {
  REPO_ROOT,
  dockerImageExists,
  fileExists,
  getMetadata,
  makeTempDir,
  readJsonFile,
  removePath,
  repoToContainerPath,
  runCommand,
  writeTextFile,
} from "./shared.ts";

const DEFAULT_SUITE = join(REPO_ROOT, "test", "contracts", "unit_v1.json");
const DEFAULT_PROTOCOL_SUITE = join(REPO_ROOT, "test", "test_suite.json");
const VALID_CASE_STATUSES = new Set(["passed", "failed", "skipped"]);
const SUPPORTED_COMPARE_TYPES = new Set([
  "fen_exact",
  "integer_exact",
  "move_exact",
  "move_set_exact",
  "status_exact",
  "string_exact",
]);
const SUPPORTED_SETUP_TYPES = new Set(["new_game", "fen"]);
const SUPPORTED_OPERATION_TYPES = new Set([
  "export_fen",
  "legal_move_count",
  "apply_move_export_fen",
  "apply_move_undo_export_fen",
  "apply_move_status",
  "ai_best_move",
]);

export function normalizeValue(compare: string, value: unknown): unknown {
  if (compare === "fen_exact") {
    return String(value).trim().split(/\s+/).join(" ");
  }
  if (compare === "integer_exact") {
    return Number.parseInt(String(value), 10);
  }
  if (compare === "move_exact") {
    return String(value).trim().toLowerCase();
  }
  if (compare === "move_set_exact") {
    if (!Array.isArray(value)) {
      throw new Error("move_set_exact expects an array");
    }
    return value.map((item) => normalizeValue("move_exact", item)).sort();
  }
  if (compare === "status_exact") {
    return String(value).trim().toLowerCase();
  }
  if (compare === "string_exact") {
    return String(value).trim();
  }
  throw new Error(`Unsupported compare mode: ${compare}`);
}

export function compareValues(compare: string, expected: unknown, actual: unknown): [boolean, unknown, unknown] {
  const normalizedExpected = normalizeValue(compare, expected);
  const normalizedActual = normalizeValue(compare, actual);
  return [JSON.stringify(normalizedExpected) === JSON.stringify(normalizedActual), normalizedExpected, normalizedActual];
}

export function validateContractSuite(suite: Record<string, any>): string[] {
  const errors: string[] = [];
  if (suite.schema_version !== "1.0") {
    errors.push("Contract suite schema_version must be '1.0'");
  }
  if (typeof suite.suite !== "string" || suite.suite.trim() === "") {
    errors.push("Contract suite must define a non-empty 'suite' name");
  }

  const declaredRequiredFeatures = suite.required_features ?? [];
  if (declaredRequiredFeatures && !Array.isArray(declaredRequiredFeatures)) {
    errors.push("Contract suite 'required_features' must be a list when present");
  }

  const cases = suite.cases;
  if (!Array.isArray(cases) || cases.length === 0) {
    errors.push("Contract suite must contain a non-empty 'cases' list");
    return errors;
  }

  const seenIds = new Set<string>();
  const seenRequiredFeatures = new Set<string>();
  for (const [index, testCase] of cases.entries()) {
    const label = `case #${index + 1}`;
    if (!testCase || typeof testCase !== "object") {
      errors.push(`${label} must be an object`);
      continue;
    }
    const missingKeys = ["id", "feature", "required", "setup", "operation", "expect", "compare"].filter(
      (key) => !(key in testCase),
    );
    if (missingKeys.length > 0) {
      errors.push(`${label} missing keys: ${missingKeys.sort().join(", ")}`);
      continue;
    }
    if (typeof testCase.id !== "string" || testCase.id.trim() === "") {
      errors.push(`${label} has an invalid 'id'`);
    } else if (seenIds.has(testCase.id)) {
      errors.push(`Duplicate contract case id: ${testCase.id}`);
    } else {
      seenIds.add(testCase.id);
    }

    if (typeof testCase.feature !== "string" || testCase.feature.trim() === "") {
      errors.push(`${label} has an invalid 'feature'`);
    } else if (testCase.required) {
      seenRequiredFeatures.add(testCase.feature);
    }

    if (typeof testCase.required !== "boolean") {
      errors.push(`${label} 'required' must be a boolean`);
    }

    if (!testCase.setup || typeof testCase.setup !== "object") {
      errors.push(`${label} 'setup' must be an object`);
    } else if (!SUPPORTED_SETUP_TYPES.has(testCase.setup.type)) {
      errors.push(`${label} has unsupported setup type '${testCase.setup.type}'`);
    } else if (testCase.setup.type === "fen" && typeof testCase.setup.value !== "string") {
      errors.push(`${label} fen setup must include string 'value'`);
    }

    if (!testCase.operation || typeof testCase.operation !== "object") {
      errors.push(`${label} 'operation' must be an object`);
    } else if (!SUPPORTED_OPERATION_TYPES.has(testCase.operation.type)) {
      errors.push(`${label} has unsupported operation type '${testCase.operation.type}'`);
    } else if (
      ["apply_move_export_fen", "apply_move_undo_export_fen", "apply_move_status"].includes(testCase.operation.type) &&
      typeof testCase.operation.move !== "string"
    ) {
      errors.push(`${label} move operation must include string 'move'`);
    } else if (testCase.operation.type === "ai_best_move" && !Number.isInteger(testCase.operation.depth)) {
      errors.push(`${label} ai_best_move must include integer 'depth'`);
    }

    if (!testCase.expect || typeof testCase.expect !== "object" || !("value" in testCase.expect)) {
      errors.push(`${label} 'expect' must be an object containing 'value'`);
    }

    if (!SUPPORTED_COMPARE_TYPES.has(testCase.compare)) {
      errors.push(`${label} has unsupported compare mode '${testCase.compare}'`);
    }
  }

  if (Array.isArray(declaredRequiredFeatures) && declaredRequiredFeatures.length > 0) {
    const declared = new Set(declaredRequiredFeatures);
    if (
      declared.size !== seenRequiredFeatures.size ||
      [...declared].some((item) => !seenRequiredFeatures.has(item))
    ) {
      errors.push("Contract suite required_features must match the feature set of required cases");
    }
  }

  return errors;
}

function extractProtocolFeatures(protocolSuite: Record<string, any>): [Set<string>, string[]] {
  const features = new Set<string>();
  const errors: string[] = [];
  const categories = protocolSuite.test_categories;
  if (!categories || typeof categories !== "object") {
    return [features, ["Protocol suite must contain 'test_categories' object"]];
  }

  for (const [categoryId, category] of Object.entries<Record<string, any>>(categories)) {
    if (!category?.required) {
      continue;
    }
    if (!Array.isArray(category.tests)) {
      errors.push(`Protocol category '${categoryId}' tests must be a list`);
      continue;
    }
    for (const test of category.tests) {
      const feature = test.feature;
      if (typeof feature !== "string" || feature.trim() === "") {
        errors.push(
          `Required protocol test '${test.id ?? "<unknown>"}' in category '${categoryId}' is missing a feature annotation`,
        );
        continue;
      }
      features.add(feature);
    }
  }

  return [features, errors];
}

export function lintFeatureVocabulary(contractSuite: Record<string, any>, protocolSuite: Record<string, any>): string[] {
  const errors: string[] = [];
  const declaredRequired = Array.isArray(contractSuite.required_features) ? contractSuite.required_features : [];
  const unitFeatures = declaredRequired.length > 0
    ? new Set(declaredRequired)
    : new Set(
        (contractSuite.cases ?? [])
          .filter((testCase: Record<string, any>) => testCase?.required)
          .map((testCase: Record<string, any>) => testCase.feature),
      );
  const [protocolFeatures, protocolErrors] = extractProtocolFeatures(protocolSuite);
  errors.push(...protocolErrors);

  const missingInProtocol = [...unitFeatures].filter((feature) => !protocolFeatures.has(feature)).sort();
  if (missingInProtocol.length > 0) {
    errors.push(`Required unit-contract features missing from protocol suite: ${missingInProtocol.join(", ")}`);
  }

  const missingInContract = [...protocolFeatures].filter((feature) => !unitFeatures.has(feature)).sort();
  if (missingInContract.length > 0) {
    errors.push(`Required protocol-suite features missing from unit contract suite: ${missingInContract.join(", ")}`);
  }

  return errors;
}

export function validateReportSchema(report: Record<string, any>, expectedSuite: string): string[] {
  const errors: string[] = [];
  if (report.schema_version !== "1.0") {
    errors.push("Report schema_version must be '1.0'");
  }
  if (report.suite !== expectedSuite) {
    errors.push(`Report suite must be '${expectedSuite}', got '${report.suite}'`);
  }
  if (typeof report.implementation !== "string" || report.implementation.trim() === "") {
    errors.push("Report must define non-empty 'implementation'");
  }
  if (!Array.isArray(report.cases)) {
    errors.push("Report 'cases' must be a list");
    return errors;
  }
  const seenIds = new Set<string>();
  for (const [index, testCase] of report.cases.entries()) {
    const label = `report case #${index + 1}`;
    if (!testCase || typeof testCase !== "object") {
      errors.push(`${label} must be an object`);
      continue;
    }
    if (typeof testCase.id !== "string" || testCase.id.trim() === "") {
      errors.push(`${label} has invalid 'id'`);
      continue;
    }
    if (seenIds.has(testCase.id)) {
      errors.push(`Duplicate report case id: ${testCase.id}`);
    }
    seenIds.add(testCase.id);
    if (!VALID_CASE_STATUSES.has(testCase.status)) {
      errors.push(`Report case '${testCase.id}' has invalid status '${testCase.status}'`);
    }
  }
  return errors;
}

export function evaluateReport(contractSuite: Record<string, any>, report: Record<string, any>): Record<string, any> {
  const suiteCases = new Map<string, Record<string, any>>((contractSuite.cases ?? []).map((item: Record<string, any>) => [item.id, item]));
  const reportCases = new Map<string, Record<string, any>>(
    (report.cases ?? [])
      .filter((item: Record<string, any>) => item && typeof item === "object" && "id" in item)
      .map((item: Record<string, any>) => [item.id, item]),
  );

  const errors: string[] = [];
  let passed = 0;
  let failed = 0;
  let skipped = 0;

  for (const reportCaseId of reportCases.keys()) {
    if (!suiteCases.has(reportCaseId)) {
      errors.push(`Report contains unknown case id '${reportCaseId}'`);
    }
  }

  for (const [caseId, suiteCase] of suiteCases.entries()) {
    const reportCase = reportCases.get(caseId);
    if (!reportCase) {
      errors.push(`Missing report result for contract case '${caseId}'`);
      failed += 1;
      continue;
    }

    if (reportCase.status === "passed") {
      if (!("normalized_actual" in reportCase)) {
        errors.push(`Passed report case '${caseId}' must include 'normalized_actual'`);
        failed += 1;
        continue;
      }
      try {
        const [matches, normalizedExpected, normalizedActual] = compareValues(
          suiteCase.compare,
          suiteCase.expect.value,
          reportCase.normalized_actual,
        );
        if (!matches) {
          errors.push(`Case '${caseId}' expected ${JSON.stringify(normalizedExpected)} but got ${JSON.stringify(normalizedActual)}`);
          failed += 1;
          continue;
        }
      } catch (error) {
        errors.push(`Case '${caseId}' normalization failed: ${error instanceof Error ? error.message : String(error)}`);
        failed += 1;
        continue;
      }
      passed += 1;
      continue;
    }

    if (reportCase.status === "skipped") {
      skipped += 1;
      if (suiteCase.required) {
        errors.push(`Required case '${caseId}' was skipped`);
        failed += 1;
      }
      continue;
    }

    if (reportCase.status === "failed") {
      failed += 1;
      if (suiteCase.required) {
        errors.push(`Required case '${caseId}' failed: ${reportCase.error ?? "adapter reported failure"}`);
      }
      continue;
    }

    failed += 1;
    errors.push(`Case '${caseId}' has invalid status '${reportCase.status}'`);
  }

  return {
    errors,
    passed,
    failed,
    skipped,
    total: suiteCases.size,
  };
}

async function runContractCommand(image: string, command: string, suitePath: string): Promise<[number, string, string, string | null]> {
  const tempRoot = makeTempDir("tgac-unit-contract-");
  try {
    const reportPath = join(tempRoot, "unit-report.json");
    const suiteInContainer = repoToContainerPath(suitePath);
    const reportInContainer = "/work/unit-report.json";
    const shellCommand = `${command} --suite ${JSON.stringify(suiteInContainer)} --report ${JSON.stringify(reportInContainer)}`;
    const dockerArgs = [
      "docker",
      "run",
      "--rm",
      "--network",
      "none",
      "-v",
      `${REPO_ROOT}:/repo:ro`,
      "-v",
      `${tempRoot}:/work`,
      image,
    ];

    let result = await runCommand([...dockerArgs, "sh", "-c", `cd /app && ${shellCommand}`], { check: false });
    if (result.exitCode !== 0 && result.stderr.toLowerCase().includes("executable file not found in $path")) {
      result = await runCommand([...dockerArgs, "bash", "-c", `cd /app && ${shellCommand}`], { check: false });
    }

    const reportText = await fileExists(reportPath) ? await Bun.file(reportPath).text() : null;
    return [result.exitCode, result.stdout, result.stderr, reportText];
  } finally {
    await removePath(tempRoot);
  }
}

export interface UnitContractOptions {
  impl: string;
  suite?: string;
  protocolSuite?: string;
  dockerImage?: string;
  requireContract?: boolean;
}

export async function runUnitContractSuite(options: UnitContractOptions): Promise<number> {
  const implPath = resolveImplPath(options.impl);
  const metadata = await getMetadata(implPath);
  const suite = await readJsonFile<Record<string, any>>(resolve(options.suite ?? DEFAULT_SUITE));
  const protocolSuite = await readJsonFile<Record<string, any>>(resolve(options.protocolSuite ?? DEFAULT_PROTOCOL_SUITE));

  const suiteErrors = [...validateContractSuite(suite), ...lintFeatureVocabulary(suite, protocolSuite)];
  if (suiteErrors.length > 0) {
    console.log("Contract suite validation failed:");
    for (const error of suiteErrors) {
      console.log(`- ${error}`);
    }
    return 1;
  }

  const contractCommand = String(metadata.test_contract ?? "").trim();
  const implName = resolve(implPath).split("/").pop() ?? implPath;
  const image = options.dockerImage ?? `chess-${implName}`;

  if (!contractCommand) {
    console.log(`SKIPPED: ${implName} does not declare org.chess.test_contract`);
    return options.requireContract ? 1 : 0;
  }

  if (!(await dockerImageExists(image))) {
    console.error(`ERROR: Docker image '${image}' not found. Run: make image DIR=${implName}`);
    return 1;
  }

  console.log(`Running unit contract suite for ${implName} using image '${image}'`);
  console.log(`Contract command: ${contractCommand}`);

  const [returnCode, stdout, stderr, reportText] = await runContractCommand(image, contractCommand, resolve(options.suite ?? DEFAULT_SUITE));
  if (stdout.trim()) {
    console.log(stdout.trim());
  }
  if (returnCode !== 0) {
    console.log(`ERROR: Contract adapter exited with status ${returnCode}`);
    if (stderr.trim()) {
      console.log(stderr.trim());
    }
    return 1;
  }
  if (reportText === null) {
    console.log("ERROR: Contract adapter did not write /work/unit-report.json");
    if (stderr.trim()) {
      console.log(stderr.trim());
    }
    return 1;
  }

  let report: Record<string, any>;
  try {
    report = JSON.parse(reportText);
  } catch (error) {
    console.log(`ERROR: Failed to load contract report: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }

  const evaluation = evaluateReport(suite, report);
  const reportErrors = [
    ...validateReportSchema(report, suite.suite),
    ...evaluation.errors,
  ];
  console.log(
    `Summary: ${evaluation.passed}/${evaluation.total} passed, ${evaluation.failed} failed, ${evaluation.skipped} skipped`,
  );

  if (reportErrors.length > 0) {
    for (const error of reportErrors) {
      console.log(`- ${error}`);
    }
    return 1;
  }

  return 0;
}

export async function writeSampleContractReport(path: string): Promise<void> {
  await writeTextFile(
    path,
    JSON.stringify(
      {
        schema_version: "1.0",
        suite: "unit_v1",
        implementation: "sample",
        cases: [],
      },
      null,
      2,
    ),
  );
}
