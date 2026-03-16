import { mkdtempSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

import { describe, expect, test } from "bun:test";

import { TOKEN_METRIC_VERSION, collectImplMetricsFromMetadata, countTokens, runCommand } from "../tooling/shared.ts";

async function writeFile(path: string, content: string | Uint8Array): Promise<void> {
  await Bun.write(path, content);
}

async function initGitRepo(root: string): Promise<void> {
  await writeFile(join(root, "README.md"), "temp repo\n");
  await runCommand(["git", "init", "-q"], { cwd: root, check: true });
}

function makeTempRoot(): string {
  return mkdtempSync(join(tmpdir(), "tgac-token-metrics-"));
}

describe("token metrics", () => {
  test("ignored files are excluded with git discovery", async () => {
    const root = makeTempRoot();
    const implDir = join(root, "implementations", "sample");
    await initGitRepo(root);

    await writeFile(join(root, ".gitignore"), "implementations/sample/ignored.foo\n");
    await writeFile(join(implDir, "tracked.foo"), "alpha + beta\n");
    await writeFile(join(implDir, "untracked.foo"), "gamma + delta\n");
    await writeFile(join(implDir, "ignored.foo"), "should_not_count\n");
    await runCommand(["git", "add", ".gitignore", "implementations/sample/tracked.foo"], { cwd: root, check: true });

    const metrics = await collectImplMetricsFromMetadata(implDir, { source_exts: [".foo"] });
    expect(metrics.source_files).toBe(2);
    expect(metrics.metric_version).toBe(TOKEN_METRIC_VERSION);
  });

  test("binary files are skipped safely", async () => {
    const root = makeTempRoot();
    const implDir = join(root, "implementations", "sample");
    await initGitRepo(root);

    await writeFile(join(implDir, "text.foo"), "a + b\n");
    await writeFile(join(implDir, "binary.foo"), new Uint8Array([0, 1, 2, 3]));

    const metrics = await collectImplMetricsFromMetadata(implDir, { source_exts: [".foo"] });
    expect(metrics.source_files).toBe(1);
    expect(metrics.skipped_binary_or_unreadable).toBe(1);
  });

  test("token count is deterministic for the same tree", async () => {
    const root = makeTempRoot();
    const implDir = join(root, "implementations", "sample");
    await initGitRepo(root);

    await writeFile(join(implDir, "main.foo"), "a + b\nc + d\n");
    await runCommand(["git", "add", "implementations/sample/main.foo"], { cwd: root, check: true });

    const first = await collectImplMetricsFromMetadata(implDir, { source_exts: [".foo"] });
    const second = await collectImplMetricsFromMetadata(implDir, { source_exts: [".foo"] });
    expect(first.tokens_count).toBe(second.tokens_count);
  });

  test("whitespace-only changes do not change token count", async () => {
    expect(countTokens("alpha+beta\n")).toBe(countTokens("alpha   +     beta\n\n"));
  });
});
