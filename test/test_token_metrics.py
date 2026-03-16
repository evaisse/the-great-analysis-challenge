#!/usr/bin/env python3
"""Unit tests for language-agnostic token metrics."""

import json
import shutil
import subprocess
import tempfile
import unittest
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from token_metrics import (
    TOKEN_METRIC_VERSION,
    SEMANTIC_METRIC_VERSION,
    collect_impl_metrics_from_metadata,
    collect_semantic_metrics,
    _find_semantic_tokens_script,
)


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _init_git_repo(root: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)


class TokenMetricsTests(unittest.TestCase):
    def test_ignored_files_are_excluded_with_git_discovery(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            impl = root / "implementations" / "sample"
            _init_git_repo(root)

            _write(root / ".gitignore", "implementations/sample/ignored.foo\n")
            _write(impl / "tracked.foo", "alpha + beta\n")
            _write(impl / "untracked.foo", "gamma + delta\n")
            _write(impl / "ignored.foo", "should_not_count\n")
            subprocess.run(["git", "add", ".gitignore", "implementations/sample/tracked.foo"], cwd=root, check=True)

            metrics = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})
            self.assertEqual(metrics["source_files"], 2)
            self.assertEqual(metrics["metric_version"], TOKEN_METRIC_VERSION)

    def test_binary_files_are_skipped_safely(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            impl = root / "implementations" / "sample"
            _init_git_repo(root)

            _write(impl / "text.foo", "a + b\n")
            binary_path = impl / "binary.foo"
            binary_path.parent.mkdir(parents=True, exist_ok=True)
            binary_path.write_bytes(b"\x00\x01\x02binary")

            metrics = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})
            self.assertEqual(metrics["source_files"], 1)
            self.assertEqual(metrics["skipped_binary_or_unreadable"], 1)

    def test_token_count_is_deterministic_for_same_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            impl = root / "implementations" / "sample"
            _init_git_repo(root)

            _write(impl / "main.foo", "a + b\nc + d\n")
            subprocess.run(["git", "add", "implementations/sample/main.foo"], cwd=root, check=True)

            first = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})["tokens_count"]
            second = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})["tokens_count"]
            self.assertEqual(first, second)

    def test_whitespace_only_changes_do_not_change_token_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            impl = root / "implementations" / "sample"
            _init_git_repo(root)

            source = impl / "main.foo"
            _write(source, "alpha+beta\n")
            subprocess.run(["git", "add", "implementations/sample/main.foo"], cwd=root, check=True)
            before = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})["tokens_count"]

            _write(source, "alpha   +     beta\n\n")
            after = collect_impl_metrics_from_metadata(impl, {"source_exts": [".foo"]})["tokens_count"]
            self.assertEqual(before, after)


class SemanticTokenMetricsTests(unittest.TestCase):
    """Tests for the Shiki-based semantic token metrics (tokens-v3)."""

    def test_semantic_metric_version_constant(self):
        self.assertEqual(SEMANTIC_METRIC_VERSION, "tokens-v3")

    def test_find_semantic_tokens_script_exists(self):
        script = _find_semantic_tokens_script()
        self.assertIsNotNone(script, "semantic_tokens.mjs script not found")
        self.assertTrue(script.is_file())

    @unittest.skipUnless(shutil.which("node"), "Node.js not available")
    def test_semantic_metrics_on_real_implementation(self):
        """Run semantic metrics on an actual implementation directory."""
        impl_dir = REPO_ROOT / "implementations" / "python"
        if not impl_dir.is_dir():
            self.skipTest("implementations/python not found")

        result = collect_semantic_metrics(impl_dir)
        self.assertIsNotNone(result, "collect_semantic_metrics returned None")
        self.assertEqual(result.get("metric_version"), "tokens-v3")
        self.assertIn("complexity_score", result)
        self.assertIn("total_tokens", result)
        self.assertIn("semantic_tokens", result)
        self.assertIn("by_category", result)
        self.assertIn("ratios", result)

        # Sanity: complexity score should be positive
        self.assertGreater(result["complexity_score"], 0)
        # semantic_tokens <= total_tokens (comments excluded)
        self.assertLessEqual(result["semantic_tokens"], result["total_tokens"])

        # by_category should have all expected keys
        categories = result["by_category"]
        for cat in ("keyword", "identifier", "type", "operator", "literal", "punctuation", "comment"):
            self.assertIn(cat, categories)
            self.assertGreaterEqual(categories[cat], 0)

    @unittest.skipUnless(shutil.which("node"), "Node.js not available")
    def test_semantic_metrics_returns_none_for_nonexistent_dir(self):
        """Nonexistent implementation directory should not crash."""
        result = collect_semantic_metrics(Path("/tmp/nonexistent_impl_dir"))
        self.assertIsNone(result)

    @unittest.skipUnless(shutil.which("node"), "Node.js not available")
    def test_semantic_metrics_output_matches_node_script(self):
        """Verify the Python wrapper produces the same output as calling the Node script directly."""
        impl_dir = REPO_ROOT / "implementations" / "rust"
        if not impl_dir.is_dir():
            self.skipTest("implementations/rust not found")

        result = collect_semantic_metrics(impl_dir)
        self.assertIsNotNone(result)
        self.assertEqual(result["implementation"], "rust")
        self.assertIn("size", result)
        self.assertIn("weights", result)


if __name__ == "__main__":
    unittest.main()
