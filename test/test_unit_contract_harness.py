#!/usr/bin/env python3
"""Unit tests for the shared unit-contract harness."""

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

TEST_DIR = REPO_ROOT / "test"
if str(TEST_DIR) not in sys.path:
    sys.path.insert(0, str(TEST_DIR))

from unit_contract_harness import (
    compare_values,
    evaluate_report,
    lint_feature_vocabulary,
    validate_contract_suite,
    validate_report_schema,
)


class UnitContractHarnessTests(unittest.TestCase):
    def test_validate_contract_suite_accepts_minimal_valid_suite(self):
        suite = {
            "schema_version": "1.0",
            "suite": "unit_v1",
            "required_features": ["move_generation"],
            "cases": [
                {
                    "id": "starting_position_legal_move_count",
                    "feature": "move_generation",
                    "required": True,
                    "setup": {"type": "new_game"},
                    "operation": {"type": "legal_move_count"},
                    "expect": {"value": 20},
                    "compare": "integer_exact",
                }
            ],
        }

        self.assertEqual(validate_contract_suite(suite), [])

    def test_lint_feature_vocabulary_detects_drift(self):
        contract_suite = {
            "schema_version": "1.0",
            "suite": "unit_v1",
            "required_features": ["fen", "ai"],
            "cases": [
                {
                    "id": "c1",
                    "feature": "fen",
                    "required": True,
                    "setup": {"type": "new_game"},
                    "operation": {"type": "export_fen"},
                    "expect": {"value": "x"},
                    "compare": "string_exact",
                },
                {
                    "id": "c2",
                    "feature": "ai",
                    "required": True,
                    "setup": {"type": "new_game"},
                    "operation": {"type": "ai_best_move", "depth": 1},
                    "expect": {"value": "e2e4"},
                    "compare": "move_exact",
                },
            ],
        }
        protocol_suite = {
            "test_categories": {
                "ai": {
                    "required": True,
                    "tests": [
                        {"id": "ai_basic", "feature": "ai"},
                    ],
                }
            }
        }

        errors = lint_feature_vocabulary(contract_suite, protocol_suite)
        self.assertEqual(
            errors,
            ["Required unit-contract features missing from protocol suite: fen"],
        )

    def test_validate_report_schema_rejects_duplicate_case_ids(self):
        report = {
            "schema_version": "1.0",
            "suite": "unit_v1",
            "implementation": "python",
            "cases": [
                {"id": "c1", "status": "passed", "normalized_actual": 20},
                {"id": "c1", "status": "passed", "normalized_actual": 20},
            ],
        }

        errors = validate_report_schema(report, "unit_v1")
        self.assertIn("Duplicate report case id: c1", errors)

    def test_evaluate_report_requires_all_required_cases(self):
        suite = {
            "cases": [
                {
                    "id": "c1",
                    "feature": "move_generation",
                    "required": True,
                    "setup": {"type": "new_game"},
                    "operation": {"type": "legal_move_count"},
                    "expect": {"value": 20},
                    "compare": "integer_exact",
                }
            ]
        }
        report = {
            "schema_version": "1.0",
            "suite": "unit_v1",
            "implementation": "python",
            "cases": [],
        }

        evaluation = evaluate_report(suite, report)
        self.assertIn("Missing report result for contract case 'c1'", evaluation["errors"])
        self.assertEqual(evaluation["failed"], 1)

    def test_compare_values_normalizes_move_case(self):
        matches, expected, actual = compare_values("move_exact", "d4e5", "D4E5")
        self.assertTrue(matches)
        self.assertEqual(expected, "d4e5")
        self.assertEqual(actual, "d4e5")


if __name__ == "__main__":
    unittest.main()
