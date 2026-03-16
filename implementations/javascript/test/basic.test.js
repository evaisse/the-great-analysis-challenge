import { describe, expect, test } from "bun:test";
import { ChessEngine } from "../engine.js";

function findLegalMove(engine, moveText) {
  const parsed = engine.parseMove(moveText);
  if (!parsed) {
    throw new Error(`Invalid move string: ${moveText}`);
  }

  const legalMove = engine
    .generateMoves()
    .find(
      (candidate) =>
        candidate.from === parsed.from &&
        candidate.to === parsed.to &&
        candidate.promotion === parsed.promotion,
    );

  if (!legalMove) {
    throw new Error(`Illegal move: ${moveText}`);
  }

  return legalMove;
}

describe("ChessEngine", () => {
  test("parses initial FEN", () => {
    const engine = new ChessEngine();
    expect(engine.state.turn).toBe("w");
  });

  test("detects draw by repetition", () => {
    const engine = new ChessEngine();
    const moves = [
      "g1f3",
      "g8f6",
      "f3g1",
      "f6g8",
      "g1f3",
      "g8f6",
      "f3g1",
      "f6g8",
    ];

    for (const moveText of moves) {
      engine.makeMove(findLegalMove(engine, moveText));
    }

    expect(engine.getDrawInfo()).toBe("REPETITION");
  });

  test("detects draw by fifty-move rule", () => {
    const engine = new ChessEngine();
    engine.state = engine.parseFen(
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 99 1",
    );

    engine.makeMove(findLegalMove(engine, "g1f3"));

    expect(engine.getDrawInfo()).toBe("50-MOVE RULE");
  });
});
