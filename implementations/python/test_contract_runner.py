#!/usr/bin/env python3
"""Shared unit-contract adapter for the Python chess implementation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict

from lib.ai import AI
from lib.board import Board
from lib.fen_parser import FenParser
from lib.move_generator import MoveGenerator
from lib.types import Move
from lib.zobrist import zobrist


def build_context(setup: Dict[str, Any]) -> Dict[str, Any]:
    board = Board()
    move_generator = MoveGenerator(board)
    fen_parser = FenParser(board)
    ai = AI(board, move_generator)

    if setup["type"] == "fen":
        fen_parser.parse(setup["value"])
        board.game_history = []
        board.position_history = []
        board.irreversible_history = []
        board.zobrist_hash = zobrist.compute_hash(board)

    return {
        "board": board,
        "move_generator": move_generator,
        "fen_parser": fen_parser,
        "ai": ai,
    }


def find_legal_move(context: Dict[str, Any], move_text: str):
    requested = Move.from_algebraic(move_text)
    if requested is None:
        raise ValueError(f"Invalid move: {move_text}")

    legal_moves = context["move_generator"].generate_legal_moves()
    for move in legal_moves:
        if (
            move.from_row == requested.from_row
            and move.from_col == requested.from_col
            and move.to_row == requested.to_row
            and move.to_col == requested.to_col
            and move.promotion == requested.promotion
        ):
            return move

    raise ValueError(f"Illegal move: {move_text}")


def execute_case(case: Dict[str, Any]) -> Dict[str, Any]:
    case_id = case["id"]
    try:
        context = build_context(case["setup"])
        board = context["board"]
        fen_parser = context["fen_parser"]
        operation = case["operation"]
        operation_type = operation["type"]

        if operation_type == "export_fen":
            actual = fen_parser.export()
        elif operation_type == "legal_move_count":
            actual = len(context["move_generator"].generate_legal_moves())
        elif operation_type == "apply_move_export_fen":
            move = find_legal_move(context, operation["move"])
            board.make_move(move)
            actual = fen_parser.export()
        elif operation_type == "apply_move_undo_export_fen":
            move = find_legal_move(context, operation["move"])
            board.make_move(move)
            board.undo_move(move)
            actual = fen_parser.export()
        elif operation_type == "apply_move_status":
            move = find_legal_move(context, operation["move"])
            board.make_move(move)
            actual = board.get_game_status()
        elif operation_type == "ai_best_move":
            best_move, _score = context["ai"].get_best_move(operation["depth"])
            if best_move is None:
                raise ValueError("AI did not return a move")
            actual = best_move.to_algebraic().lower()
        else:
            raise ValueError(f"Unsupported operation: {operation_type}")

        return {
            "id": case_id,
            "status": "passed",
            "normalized_actual": actual,
        }
    except Exception as exc:  # pragma: no cover - adapter surfaces failures in JSON
        return {
            "id": case_id,
            "status": "failed",
            "error": str(exc),
        }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run shared unit contract cases")
    parser.add_argument("--suite", required=True, help="Path to contract suite JSON")
    parser.add_argument("--report", required=True, help="Path to write JSON report")
    args = parser.parse_args()

    suite_path = Path(args.suite)
    report_path = Path(args.report)
    suite = json.loads(suite_path.read_text(encoding="utf-8"))

    report = {
        "schema_version": "1.0",
        "suite": suite["suite"],
        "implementation": "python",
        "cases": [execute_case(case) for case in suite["cases"]],
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
