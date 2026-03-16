import { existsSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { basename, extname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { createHighlighter } from "shiki";

import {
  discoverImplementationDirs,
  getMetadata,
  listGitDiscoveredFiles,
  normalizeLineEndings,
  parseSourceExts,
} from "./shared.ts";

export const SEMANTIC_METRIC_VERSION = "tokens-v3";

export const CATEGORY_WEIGHTS = {
  keyword: 1.0,
  identifier: 1.0,
  type: 1.0,
  operator: 0.5,
  literal: 0.5,
  punctuation: 0.25,
  comment: 0.0,
  unknown: 0.5,
} as const;

export type SemanticCategory = keyof typeof CATEGORY_WEIGHTS;

export interface SemanticAnalysisResult {
  implementation: string;
  path: string;
  shiki_lang: string;
  shiki_lang_requested?: string;
  source_exts: string[];
  metric_version: typeof SEMANTIC_METRIC_VERSION;
  complexity_score: number;
  total_tokens: number;
  semantic_tokens: number;
  by_category: Record<SemanticCategory, number>;
  size: {
    source_loc: number;
    source_files: number;
  };
  ratios: {
    keyword_density: number;
    comment_ratio: number;
    punctuation_ratio: number;
    complexity_per_loc: number;
    complexity_per_file: number;
  };
  weights: Record<SemanticCategory, number>;
}

export interface SemanticMetricsSubset {
  metric_version: typeof SEMANTIC_METRIC_VERSION;
  complexity_score: number;
  total_tokens: number;
  semantic_tokens: number;
  by_category: Record<SemanticCategory, number>;
  ratios: SemanticAnalysisResult["ratios"];
}

const ZERO_COUNTS: Record<SemanticCategory, number> = {
  keyword: 0,
  identifier: 0,
  type: 0,
  operator: 0,
  literal: 0,
  punctuation: 0,
  comment: 0,
  unknown: 0,
};

const COMMON_KEYWORDS = new Set([
  "if",
  "else",
  "for",
  "while",
  "return",
  "fn",
  "func",
  "function",
  "def",
  "class",
  "struct",
  "enum",
  "impl",
  "trait",
  "interface",
  "import",
  "from",
  "use",
  "pub",
  "private",
  "public",
  "protected",
  "const",
  "let",
  "var",
  "val",
  "mut",
  "match",
  "switch",
  "case",
  "break",
  "continue",
  "try",
  "catch",
  "throw",
  "async",
  "await",
  "yield",
  "type",
  "module",
  "package",
  "do",
  "end",
  "then",
  "begin",
  "where",
  "in",
  "is",
  "as",
  "new",
  "self",
  "this",
  "super",
  "true",
  "false",
  "nil",
  "null",
  "none",
  "not",
  "and",
  "or",
]);

export const LANG_MAP: Record<string, string> = {
  rust: "rust",
  go: "go",
  typescript: "typescript",
  bun: "typescript",
  javascript: "javascript",
  python: "python",
  ruby: "ruby",
  kotlin: "kotlin",
  swift: "swift",
  haskell: "haskell",
  gleam: "gleam",
  elm: "elm",
  crystal: "crystal",
  nim: "nim",
  zig: "zig",
  lua: "lua",
  php: "php",
  dart: "dart",
  julia: "julia",
  rescript: "rescript",
  imba: "javascript",
  mojo: "python",
};

export const DEFAULT_EXTS_MAP: Record<string, string[]> = {
  rust: [".rs"],
  go: [".go"],
  typescript: [".ts"],
  bun: [".ts"],
  javascript: [".js"],
  python: [".py"],
  ruby: [".rb"],
  kotlin: [".kt"],
  swift: [".swift"],
  haskell: [".hs"],
  gleam: [".gleam"],
  elm: [".elm"],
  crystal: [".cr"],
  nim: [".nim"],
  zig: [".zig"],
  lua: [".lua"],
  php: [".php"],
  dart: [".dart"],
  julia: [".jl"],
  rescript: [".res"],
  imba: [".imba"],
  mojo: [".mojo", ".🔥"],
};

function cloneZeroCounts(): Record<SemanticCategory, number> {
  return { ...ZERO_COUNTS };
}

function round(value: number, precision = 2): number {
  const factor = 10 ** precision;
  return Math.round(value * factor) / factor;
}

function classifyScope(scopes: string | string[] | undefined): SemanticCategory {
  if (!scopes || (Array.isArray(scopes) && scopes.length === 0)) {
    return "unknown";
  }

  const scope = Array.isArray(scopes) ? scopes.join(" ") : scopes;

  if (scope.includes("comment")) return "comment";
  if (
    scope.includes("string") ||
    scope.includes("constant.numeric") ||
    scope.includes("constant.language") ||
    scope.includes("constant.character")
  ) {
    return "literal";
  }
  if (scope.includes("operator")) return "operator";
  if (scope.includes("punctuation") || scope.includes("meta.brace") || scope.includes("meta.bracket")) {
    return "punctuation";
  }
  if (
    scope.includes("entity.name.type") ||
    scope.includes("support.type") ||
    scope.includes("storage.type.primitive") ||
    scope.includes("entity.name.class") ||
    scope.includes("entity.name.struct") ||
    scope.includes("entity.name.enum") ||
    scope.includes("entity.name.interface") ||
    scope.includes("entity.name.trait")
  ) {
    return "type";
  }
  if (
    scope.includes("keyword") ||
    scope.includes("storage.type") ||
    scope.includes("storage.modifier")
  ) {
    return "keyword";
  }
  if (
    scope.includes("entity.name") ||
    scope.includes("variable") ||
    scope.includes("support.function") ||
    scope.includes("meta.function-call") ||
    scope.includes("identifier")
  ) {
    return "identifier";
  }
  if (scope.startsWith("source.")) return "identifier";
  return "unknown";
}

function classifyTokenByContent(text: string): SemanticCategory {
  if (COMMON_KEYWORDS.has(text.toLowerCase())) return "keyword";
  if (/^\d+(?:\.\d+)?$/.test(text)) return "literal";
  if (/^["'`]/.test(text)) return "literal";
  if (/^[{}()[\].,;:]$/.test(text)) return "punctuation";
  if (/^[+\-*/%=<>!&|^~?]+$/.test(text)) return "operator";
  if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(text)) return "identifier";
  return "unknown";
}

async function isBinaryFile(path: string): Promise<boolean> {
  try {
    const bytes = new Uint8Array(await Bun.file(path).slice(0, 8192).arrayBuffer());
    return bytes.includes(0);
  } catch {
    return true;
  }
}

async function walkSourceFiles(dir: string, exts: string[]): Promise<string[]> {
  const files: string[] = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.startsWith(".")) {
      continue;
    }
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walkSourceFiles(fullPath, exts));
      continue;
    }
    if (entry.isFile() && exts.includes(extname(fullPath).toLowerCase())) {
      files.push(fullPath);
    }
  }
  return files;
}

async function listSourceFiles(implDir: string, exts: string[]): Promise<string[]> {
  try {
    return (await listGitDiscoveredFiles(implDir)).filter((path) => exts.includes(extname(path).toLowerCase()));
  } catch {
    return await walkSourceFiles(implDir, exts);
  }
}

async function analyzeFile(highlighter: any, filePath: string, lang: string): Promise<{
  filePath: string;
  loc: number;
  totalTokens: number;
  categories: Record<SemanticCategory, number>;
} | null> {
  if (await isBinaryFile(filePath)) {
    return null;
  }

  let content: string;
  try {
    content = normalizeLineEndings(await Bun.file(filePath).text());
  } catch {
    return null;
  }

  const loc = content.split("\n").length;

  let tokenLines: any[];
  try {
    const result = highlighter.codeToTokens(content, {
      lang,
      theme: "github-dark",
      includeExplanation: true,
    }) as { tokens: any[] };
    tokenLines = result.tokens ?? [];
  } catch (error) {
    console.error(`Warning: Shiki failed for ${filePath}: ${error instanceof Error ? error.message : String(error)}`);
    return null;
  }

  const categories = cloneZeroCounts();
  let totalTokens = 0;

  for (const line of tokenLines) {
    for (const token of line) {
      const text = String(token.content ?? "").trim();
      if (!text) {
        continue;
      }

      totalTokens += 1;

      let category: SemanticCategory = "unknown";
      const explanations = Array.isArray(token.explanation) ? token.explanation : [];
      for (const explanation of explanations) {
        const scopeNames = Array.isArray(explanation?.scopes)
          ? explanation.scopes.map((scope: { scopeName?: string }) => scope.scopeName ?? "").filter(Boolean)
          : [];
        if (scopeNames.length > 0) {
          category = classifyScope(scopeNames);
          break;
        }
      }

      if (category === "unknown") {
        category = classifyTokenByContent(text);
      }

      categories[category] += 1;
    }
  }

  return { filePath, loc, totalTokens, categories };
}

function computeMetrics(fileResults: Array<Awaited<ReturnType<typeof analyzeFile>>>): Omit<SemanticAnalysisResult, "implementation" | "path" | "shiki_lang" | "shiki_lang_requested" | "source_exts"> {
  const totals = cloneZeroCounts();
  let totalLoc = 0;
  let totalTokens = 0;
  let sourceFiles = 0;

  for (const result of fileResults) {
    if (!result) {
      continue;
    }
    sourceFiles += 1;
    totalLoc += result.loc;
    totalTokens += result.totalTokens;
    for (const [category, count] of Object.entries(result.categories) as Array<[SemanticCategory, number]>) {
      totals[category] += count;
    }
  }

  let complexityScore = 0;
  for (const [category, count] of Object.entries(totals) as Array<[SemanticCategory, number]>) {
    complexityScore += CATEGORY_WEIGHTS[category] * count;
  }

  const semanticTokens = totalTokens - totals.comment;

  return {
    metric_version: SEMANTIC_METRIC_VERSION,
    complexity_score: round(complexityScore, 2),
    total_tokens: totalTokens,
    semantic_tokens: semanticTokens,
    by_category: totals,
    size: {
      source_loc: totalLoc,
      source_files: sourceFiles,
    },
    ratios: {
      keyword_density: semanticTokens > 0 ? round(totals.keyword / semanticTokens, 3) : 0,
      comment_ratio: totalTokens > 0 ? round(totals.comment / totalTokens, 3) : 0,
      punctuation_ratio: semanticTokens > 0 ? round(totals.punctuation / semanticTokens, 3) : 0,
      complexity_per_loc: totalLoc > 0 ? round(complexityScore / totalLoc, 2) : 0,
      complexity_per_file: sourceFiles > 0 ? round(complexityScore / sourceFiles, 2) : 0,
    },
    weights: { ...CATEGORY_WEIGHTS },
  };
}

async function createHighlighterForLanguage(requestedLanguage: string): Promise<{ highlighter: any; actualLanguage: string }> {
  try {
    const highlighter = await createHighlighter({
      themes: ["github-dark"],
      langs: [requestedLanguage],
    });
    return { highlighter, actualLanguage: requestedLanguage };
  } catch (error) {
    console.error(
      `Warning: Language "${requestedLanguage}" not available in Shiki, falling back to "javascript": ${error instanceof Error ? error.message : String(error)}`,
    );
    const highlighter = await createHighlighter({
      themes: ["github-dark"],
      langs: ["javascript"],
    });
    return { highlighter, actualLanguage: "javascript" };
  }
}

function resolveExts(implName: string, metadata: Record<string, unknown>, override?: string[]): string[] {
  if (override && override.length > 0) {
    return parseSourceExts(override);
  }
  const metadataExts = parseSourceExts(metadata.source_exts);
  if (metadataExts.length > 0) {
    return metadataExts;
  }
  return DEFAULT_EXTS_MAP[implName] ?? [`.${implName}`];
}

export async function analyzeImplementation(
  implDir: string,
  options: { lang?: string; exts?: string[] } = {},
): Promise<SemanticAnalysisResult> {
  const resolvedPath = resolve(implDir);
  const implName = basename(resolvedPath);
  const metadata = await getMetadata(resolvedPath);
  const requestedLanguage = options.lang ?? LANG_MAP[implName] ?? implName;
  const exts = resolveExts(implName, metadata, options.exts);

  const { highlighter, actualLanguage } = await createHighlighterForLanguage(requestedLanguage);
  try {
    const fileResults = [];
    for (const filePath of await listSourceFiles(resolvedPath, exts)) {
      fileResults.push(await analyzeFile(highlighter, filePath, actualLanguage));
    }

    return {
      implementation: implName,
      path: resolvedPath,
      shiki_lang: actualLanguage,
      ...(requestedLanguage !== actualLanguage ? { shiki_lang_requested: requestedLanguage } : {}),
      source_exts: exts,
      ...computeMetrics(fileResults),
    };
  } finally {
    highlighter.dispose();
  }
}

export async function collectSemanticMetrics(
  implPath: string,
  options: { lang?: string; exts?: string[] } = {},
): Promise<SemanticAnalysisResult | null> {
  const resolvedPath = resolve(implPath);
  if (!existsSync(resolvedPath)) {
    return null;
  }
  try {
    return await analyzeImplementation(resolvedPath, options);
  } catch {
    return null;
  }
}

export function toSemanticMetricsSubset(result: SemanticAnalysisResult): SemanticMetricsSubset {
  return {
    metric_version: result.metric_version,
    complexity_score: result.complexity_score,
    total_tokens: result.total_tokens,
    semantic_tokens: result.semantic_tokens,
    by_category: result.by_category,
    ratios: result.ratios,
  };
}

function parseExtList(rawValue: string | undefined): string[] | undefined {
  if (!rawValue) {
    return undefined;
  }
  const parsed = parseSourceExts(rawValue.split(","));
  return parsed.length > 0 ? parsed : undefined;
}

function semanticTokensUsage(): string {
  return [
    "Usage:",
    "  bun run scripts/semantic-tokens/semantic_tokens.mjs <impl-dir> [--lang <shiki-lang>] [--exts .ext1,.ext2] [--pretty]",
    "  bun run scripts/semantic-tokens/semantic_tokens.mjs --all implementations/ [--pretty]",
  ].join("\n");
}

export async function runSemanticTokensCli(args: string[]): Promise<number> {
  const { values, positionals } = parseArgs({
    args,
    allowPositionals: true,
    options: {
      all: { type: "boolean" },
      lang: { type: "string" },
      exts: { type: "string" },
      pretty: { type: "boolean" },
    },
  });

  if (args.includes("--help") || args.includes("-h")) {
    console.log(semanticTokensUsage());
    return 0;
  }

  const indent = values.pretty ? 2 : undefined;
  const exts = parseExtList(values.exts);

  try {
    if (values.all) {
      const baseDir = resolve(positionals[0] ?? "implementations");
      const implementations = await discoverImplementationDirs(baseDir);
      const results: SemanticAnalysisResult[] = [];
      for (const implPath of implementations) {
        results.push(await analyzeImplementation(implPath, { lang: values.lang, exts }));
      }
      console.log(JSON.stringify(results, null, indent));
      return 0;
    }

    const target = positionals[0];
    if (!target) {
      console.error(semanticTokensUsage());
      return 1;
    }

    const result = await analyzeImplementation(target, { lang: values.lang, exts });
    console.log(JSON.stringify(result, null, indent));
    return 0;
  } catch (error) {
    console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}
