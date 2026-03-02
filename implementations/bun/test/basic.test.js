import { describe, expect, test } from "bun:test";
import { ChessEngine } from "../engine.js";

describe("ChessEngine", () => {
  test("parses initial FEN", () => {
    const engine = new ChessEngine();
    expect(engine.state.turn).toBe("w");
  });
});
