#!/usr/bin/env node
/**
 * Semantic Token Analyzer
 *
 * Uses Shiki (TextMate/VS Code grammars) to tokenize source code and produce
 * weighted complexity metrics that are fair across programming languages.
 *
 * Usage:
 *   node semantic_tokens.mjs <impl-dir> [--lang <shiki-lang>] [--exts .ext1,.ext2]
 *   node semantic_tokens.mjs implementations/rust --lang rust --exts .rs
 *   node semantic_tokens.mjs --all implementations/
 *
 * Output: JSON with semantic metrics to stdout.
 */

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, extname, basename, resolve } from "node:path";
import { execSync } from "node:child_process";
import { createHighlighter } from "shiki";

// ---------------------------------------------------------------------------
// Category weights for complexity scoring
// ---------------------------------------------------------------------------
const CATEGORY_WEIGHTS = {
  keyword: 1.0,
  identifier: 1.0,
  type: 1.0,
  operator: 0.5,
  literal: 0.5,
  punctuation: 0.25,
  comment: 0.0,
  unknown: 0.5,
};

// ---------------------------------------------------------------------------
// TextMate scope → category mapping
// ---------------------------------------------------------------------------
function classifyScope(scopes) {
  if (!scopes || scopes.length === 0) return "unknown";

  // Join all scopes for matching (Shiki provides them as a flat string or array)
  const scope = Array.isArray(scopes) ? scopes.join(" ") : scopes;

  // Comments (highest priority)
  if (scope.includes("comment")) return "comment";

  // Strings and other literals (treat whole string token as 1 literal)
  if (
    scope.includes("string") ||
    scope.includes("constant.numeric") ||
    scope.includes("constant.language") ||
    scope.includes("constant.character")
  )
    return "literal";

  // Operators — must come BEFORE keywords because many languages use
  // scopes like "keyword.operator.arithmetic" for operators
  if (scope.includes("operator")) return "operator";

  // Punctuation
  if (
    scope.includes("punctuation") ||
    scope.includes("meta.brace") ||
    scope.includes("meta.bracket")
  )
    return "punctuation";

  // Types
  if (
    scope.includes("entity.name.type") ||
    scope.includes("support.type") ||
    scope.includes("storage.type.primitive") ||
    scope.includes("entity.name.class") ||
    scope.includes("entity.name.struct") ||
    scope.includes("entity.name.enum") ||
    scope.includes("entity.name.interface") ||
    scope.includes("entity.name.trait")
  )
    return "type";

  // Keywords (after operators/punctuation to avoid misclassifying keyword.operator)
  if (
    scope.includes("keyword") ||
    scope.includes("storage.type") ||
    scope.includes("storage.modifier")
  )
    return "keyword";

  // Identifiers (functions, variables, etc.)
  if (
    scope.includes("entity.name") ||
    scope.includes("variable") ||
    scope.includes("support.function") ||
    scope.includes("meta.function-call") ||
    scope.includes("identifier")
  )
    return "identifier";

  // Source-level tokens that are plain identifiers
  if (scope.startsWith("source.")) return "identifier";

  return "unknown";
}

// ---------------------------------------------------------------------------
// Language mapping: implementation dir name → Shiki language ID
// ---------------------------------------------------------------------------
const LANG_MAP = {
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
  imba: "javascript", // fallback
  mojo: "python", // fallback, similar syntax
};

const DEFAULT_EXTS_MAP = {
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

// ---------------------------------------------------------------------------
// File discovery (git ls-files based, like token_metrics.py)
// ---------------------------------------------------------------------------
function findRepoRoot(startPath) {
  let current = resolve(startPath);
  while (current !== "/") {
    if (existsSync(join(current, ".git"))) return current;
    current = resolve(current, "..");
  }
  return null;
}

function listSourceFiles(implDir, exts) {
  const repoRoot = findRepoRoot(implDir);
  if (!repoRoot) {
    // Fallback: walk directory
    return walkDir(implDir).filter((f) =>
      exts.includes(extname(f).toLowerCase())
    );
  }

  const relPath = resolve(implDir).replace(repoRoot + "/", "");
  const result = execSync(
    `git -C "${repoRoot}" ls-files -co --exclude-standard -- "${relPath}"`,
    { encoding: "utf-8" }
  );

  return result
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && exts.includes(extname(l).toLowerCase()))
    .map((l) => join(repoRoot, l))
    .filter((f) => {
      try {
        return statSync(f).isFile();
      } catch {
        return false;
      }
    });
}

function walkDir(dir) {
  const results = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory() && !entry.name.startsWith(".")) {
      results.push(...walkDir(fullPath));
    } else if (entry.isFile()) {
      results.push(fullPath);
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// Binary file detection
// ---------------------------------------------------------------------------
function isBinary(filePath) {
  try {
    const buf = readFileSync(filePath, { length: 8192 });
    return buf.includes(0);
  } catch {
    return true;
  }
}

// ---------------------------------------------------------------------------
// Core analysis
// ---------------------------------------------------------------------------
async function analyzeFile(highlighter, filePath, lang) {
  if (isBinary(filePath)) return null;

  let content;
  try {
    content = readFileSync(filePath, "utf-8");
  } catch {
    return null;
  }

  // Normalize line endings
  content = content.replace(/\r\n/g, "\n").replace(/\r/g, "\n");

  const loc = content.split("\n").length;

  let tokens;
  try {
    const result = highlighter.codeToTokens(content, {
      lang,
      theme: "github-dark",
      includeExplanation: true,
    });
    tokens = result.tokens;
  } catch (err) {
    // If Shiki can't parse, return null
    process.stderr.write(
      `Warning: Shiki failed for ${filePath}: ${err.message}\n`
    );
    return null;
  }

  const categories = {
    keyword: 0,
    identifier: 0,
    type: 0,
    operator: 0,
    literal: 0,
    punctuation: 0,
    comment: 0,
    unknown: 0,
  };

  let totalTokens = 0;

  for (const line of tokens) {
    for (const token of line) {
      const text = token.content.trim();
      if (!text) continue; // skip whitespace-only tokens

      totalTokens++;

      // Shiki tokens carry fontStyle + color but the scope info is in
      // the explanation field when using codeToTokens with includeExplanation.
      // However, the simpler approach: use token.color as proxy or
      // use the explanation API.
      // With standard codeToTokens, we get token.explanation which contains scopes.
      let category = "unknown";
      if (token.explanation && token.explanation.length > 0) {
        // Use the first explanation's scopes
        for (const exp of token.explanation) {
          if (exp.scopes && exp.scopes.length > 0) {
            const scopeNames = exp.scopes.map((s) => s.scopeName).join(" ");
            category = classifyScope(scopeNames);
            break;
          }
        }
      } else {
        // Fallback: basic heuristic from token content
        category = classifyTokenByContent(text);
      }

      categories[category]++;
    }
  }

  return { filePath, loc, totalTokens, categories };
}

// ---------------------------------------------------------------------------
// Fallback classifier (when Shiki doesn't provide scopes)
// ---------------------------------------------------------------------------
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

function classifyTokenByContent(text) {
  if (COMMON_KEYWORDS.has(text.toLowerCase())) return "keyword";
  if (/^\d+(\.\d+)?$/.test(text)) return "literal";
  if (/^["'`]/.test(text)) return "literal";
  if (/^[{}()\[\].,;:]$/.test(text)) return "punctuation";
  if (/^[+\-*/%=<>!&|^~?]+$/.test(text)) return "operator";
  if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(text)) return "identifier";
  return "unknown";
}

// ---------------------------------------------------------------------------
// Aggregate metrics for an implementation
// ---------------------------------------------------------------------------
function computeMetrics(fileResults) {
  const totals = {
    keyword: 0,
    identifier: 0,
    type: 0,
    operator: 0,
    literal: 0,
    punctuation: 0,
    comment: 0,
    unknown: 0,
  };

  let totalLoc = 0;
  let totalTokens = 0;
  let sourceFiles = 0;

  for (const result of fileResults) {
    if (!result) continue;
    sourceFiles++;
    totalLoc += result.loc;
    totalTokens += result.totalTokens;
    for (const [cat, count] of Object.entries(result.categories)) {
      totals[cat] += count;
    }
  }

  // Compute weighted complexity score
  let complexityScore = 0;
  for (const [cat, count] of Object.entries(totals)) {
    complexityScore += (CATEGORY_WEIGHTS[cat] || 0.5) * count;
  }

  // Semantic tokens = all tokens minus comments
  const semanticTokens = totalTokens - totals.comment;

  return {
    metric_version: "tokens-v3",
    complexity_score: Math.round(complexityScore * 100) / 100,
    total_tokens: totalTokens,
    semantic_tokens: semanticTokens,
    by_category: totals,
    size: {
      source_loc: totalLoc,
      source_files: sourceFiles,
    },
    ratios: {
      keyword_density:
        semanticTokens > 0
          ? Math.round((totals.keyword / semanticTokens) * 1000) / 1000
          : 0,
      comment_ratio:
        totalTokens > 0
          ? Math.round((totals.comment / totalTokens) * 1000) / 1000
          : 0,
      punctuation_ratio:
        semanticTokens > 0
          ? Math.round((totals.punctuation / semanticTokens) * 1000) / 1000
          : 0,
      complexity_per_loc:
        totalLoc > 0
          ? Math.round((complexityScore / totalLoc) * 100) / 100
          : 0,
      complexity_per_file:
        sourceFiles > 0
          ? Math.round((complexityScore / sourceFiles) * 100) / 100
          : 0,
    },
    weights: CATEGORY_WEIGHTS,
  };
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
async function analyzeImplementation(implDir, langOverride, extsOverride) {
  const implName = basename(resolve(implDir));
  const shikiLang = langOverride || LANG_MAP[implName] || implName;
  const exts =
    extsOverride ||
    DEFAULT_EXTS_MAP[implName] || [`.${implName}`];

  // Determine which Shiki languages to load
  const langsToLoad = [shikiLang];

  let highlighter;
  let actualLang = shikiLang;
  try {
    highlighter = await createHighlighter({
      themes: ["github-dark"],
      langs: langsToLoad,
    });
  } catch (err) {
    // Language not available in Shiki bundle — try fallback to javascript
    process.stderr.write(
      `Warning: Language "${shikiLang}" not available in Shiki, falling back to "javascript": ${err.message}\n`
    );
    actualLang = "javascript";
    try {
      highlighter = await createHighlighter({
        themes: ["github-dark"],
        langs: ["javascript"],
      });
    } catch (err2) {
      process.stderr.write(
        `Error creating fallback highlighter: ${err2.message}\n`
      );
      process.exit(1);
    }
  }

  const files = listSourceFiles(implDir, exts);
  const results = [];

  for (const filePath of files) {
    const result = await analyzeFile(highlighter, filePath, actualLang);
    results.push(result);
  }

  highlighter.dispose();

  const metrics = computeMetrics(results);

  return {
    implementation: implName,
    path: resolve(implDir),
    shiki_lang: actualLang,
    shiki_lang_requested: shikiLang !== actualLang ? shikiLang : undefined,
    source_exts: exts,
    ...metrics,
  };
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    console.log(`Usage:
  node semantic_tokens.mjs <impl-dir> [--lang <shiki-lang>] [--exts .ext1,.ext2]
  node semantic_tokens.mjs --all <implementations-dir>
  node semantic_tokens.mjs --all implementations/ --pretty

Options:
  --lang    Override Shiki language ID
  --exts    Comma-separated file extensions (e.g., .rs,.toml)
  --all     Analyze all implementations in directory
  --pretty  Pretty-print JSON output`);
    process.exit(0);
  }

  const allIndex = args.indexOf("--all");
  const langIndex = args.indexOf("--lang");
  const extsIndex = args.indexOf("--exts");
  const pretty = args.includes("--pretty");

  const langOverride = langIndex >= 0 ? args[langIndex + 1] : null;
  const extsOverride =
    extsIndex >= 0 ? args[extsIndex + 1].split(",") : null;

  if (allIndex >= 0) {
    const baseDir = args[allIndex + 1] || "implementations";
    const entries = readdirSync(baseDir, { withFileTypes: true })
      .filter((e) => e.isDirectory() && !e.name.startsWith("."))
      .filter((e) => existsSync(join(baseDir, e.name, "Dockerfile")))
      .sort((a, b) => a.name.localeCompare(b.name));

    const results = [];
    for (const entry of entries) {
      const implDir = join(baseDir, entry.name);
      process.stderr.write(`Analyzing ${entry.name}...\n`);
      try {
        const result = await analyzeImplementation(
          implDir,
          null, // per-impl lang detection
          null  // per-impl ext detection
        );
        results.push(result);
      } catch (err) {
        process.stderr.write(
          `  Error analyzing ${entry.name}: ${err.message}\n`
        );
      }
    }

    console.log(JSON.stringify(results, null, pretty ? 2 : undefined));
  } else {
    const implDir = args.find((a) => !a.startsWith("--"));
    if (!implDir) {
      process.stderr.write("Error: no implementation directory specified\n");
      process.exit(1);
    }

    const result = await analyzeImplementation(
      implDir,
      langOverride,
      extsOverride
    );
    console.log(JSON.stringify(result, null, pretty ? 2 : undefined));
  }
}

main().catch((err) => {
  process.stderr.write(`Fatal error: ${err.message}\n`);
  process.exit(1);
});
