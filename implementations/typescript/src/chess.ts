import * as readline from "readline";
import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { FenParser } from "./fen";
import { AI } from "./ai";
import { Perft } from "./perft";
import { Move, PieceType } from "./types";

export class ChessEngine {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private fenParser: FenParser;
  private ai: AI;
  private perft: Perft;
  private rl: readline.Interface;

  constructor() {
    this.board = new Board();
    this.moveGenerator = new MoveGenerator(this.board);
    this.fenParser = new FenParser(this.board);
    this.ai = new AI(this.board, this.moveGenerator);
    this.perft = new Perft(this.board, this.moveGenerator);

    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: false,
    });
  }

  public start(): void {
    console.log(this.board.display());

    this.rl.on("line", (input: string) => {
      const trimmed = input.trim();
      if (trimmed) {
        this.processCommand(trimmed);
      }
    });
  }

  private processCommand(command: string): void {
    const parts = command.split(" ");
    const cmd = parts[0].toLowerCase();

    try {
      switch (cmd) {
        case "move":
          this.handleMove(parts[1]);
          break;
        case "undo":
          this.handleUndo();
          break;
        case "new":
          this.handleNew();
          break;
        case "ai":
          this.handleAI(parts[1]);
          break;
        case "fen":
          this.handleFen(parts.slice(1).join(" "));
          break;
        case "export":
          this.handleExport();
          break;
        case "eval":
          this.handleEval();
          break;
        case "hash":
          this.handleHash();
          break;
        case "draws":
          this.handleDraws();
          break;
        case "history":
          this.handleHistory();
          break;
        case "perft":
          this.handlePerft(parts[1]);
          break;
        case "status":
          this.handleStatus();
          break;
        case "board":
          console.log(this.board.display());
          break;
        case "help":
          this.handleHelp();
          break;
        case "quit":
          process.exit(0);
          break;
        default:
          console.log("ERROR: Invalid command");
          break;
      }
    } catch (error: any) {
      console.log(error.message || "ERROR: Invalid command");
    }
  }

  private handleMove(moveStr: string): void {
    if (!moveStr || moveStr.length < 4) {
      console.log("ERROR: Invalid move format");
      return;
    }

    const from = moveStr.substring(0, 2);
    const to = moveStr.substring(2, 4);
    const promotion = moveStr.substring(4, 5).toUpperCase() as PieceType;

    try {
      const fromSquare = this.board.algebraicToSquare(from);
      const toSquare = this.board.algebraicToSquare(to);

      const piece = this.board.getPiece(fromSquare);
      if (!piece) {
        console.log("ERROR: No piece at source square");
        return;
      }

      if (piece.color !== this.board.getTurn()) {
        console.log("ERROR: Wrong color piece");
        return;
      }

      const legalMoves = this.moveGenerator.getLegalMoves(this.board.getTurn());
      const move = legalMoves.find(
        (m) =>
          m.from === fromSquare &&
          m.to === toSquare &&
          (!m.promotion ||
            m.promotion === promotion ||
            (!promotion && m.promotion === "Q")),
      );

      if (!move) {
        const inCheck = this.moveGenerator.isInCheck(this.board.getTurn());
        if (inCheck) {
          console.log("ERROR: King would be in check");
        } else {
          console.log("ERROR: Illegal move");
        }
        return;
      }

      if (move.promotion && !promotion) {
        move.promotion = "Q";
      } else if (move.promotion && promotion) {
        move.promotion = promotion;
      }

      this.board.makeMove(move);
      console.log(this.board.display());
      this.checkGameEnd();
      console.log(`OK: ${moveStr}`);
    } catch (error) {
      console.log("ERROR: Invalid move format");
    }
  }

  private handleUndo(): void {
    const move = this.board.undoMove();
    if (move) {
      console.log(this.board.display());
      console.log("OK: move undone");
    } else {
      console.log("ERROR: No moves to undo");
    }
  }

  private handleNew(): void {
    this.board.reset();
    console.log(this.board.display());
    console.log("OK: new game started");
  }

  private handleAI(depthStr: string): void {
    const depth = parseInt(depthStr);
    if (isNaN(depth) || depth < 1 || depth > 5) {
      console.log("ERROR: AI depth must be 1-5");
      return;
    }

    const result = this.ai.findBestMove(depth);
    if (!result.move) {
      console.log("ERROR: No legal moves available");
      return;
    }

    const moveStr =
      this.board.squareToAlgebraic(result.move.from) +
      this.board.squareToAlgebraic(result.move.to) +
      (result.move.promotion || "");

    this.board.makeMove(result.move);
    console.log(
      `AI: ${moveStr} (depth=${depth}, eval=${result.eval}, time=${result.time}ms)`,
    );
    console.log(this.board.display());

    this.checkGameEnd();
  }

  private handleFen(fenString: string): void {
    try {
      this.fenParser.parseFen(fenString);
      console.log(this.board.display());
      console.log("OK: FEN loaded");
    } catch (error) {
      console.log("ERROR: Invalid FEN string");
    }
  }

  private handleExport(): void {
    const fen = this.fenParser.exportFen();
    console.log(`FEN: ${fen}`);
  }

  private handleEval(): void {
    const evaluation = this.evaluatePosition();
    console.log(`EVALUATION: ${evaluation}`);
  }

  private handleHash(): void {
    console.log(
      `HASH: ${this.board.getHash().toString(16).padStart(16, "0")}`,
    );
  }

  private handleDraws(): void {
    console.log(`DRAW: ${this.board.getDrawInfo()}`);
  }

  private handleHistory(): void {
    const state = this.board.getState();
    console.log(
      `Position History (${state.positionHistory.length + 1} positions):`,
    );
    state.positionHistory.forEach((hash, i) => {
      console.log(`  ${i}: ${hash.toString(16).padStart(16, "0")}`);
    });
    console.log(
      `  ${state.positionHistory.length}: ${state.zobristHash
        .toString(16)
        .padStart(16, "0")} (current)`,
    );
  }

  private evaluatePosition(): number {
    let score = 0;
    for (let square = 0; square < 64; square++) {
      const piece = this.board.getPiece(square);
      if (piece) {
        const value = {
          P: 100,
          N: 320,
          B: 330,
          R: 500,
          Q: 900,
          K: 20000,
        }[piece.type];
        score += piece.color === "white" ? value : -value;
      }
    }
    return score;
  }

  private handlePerft(depthStr: string): void {
    const depth = parseInt(depthStr);
    if (isNaN(depth) || depth < 1) {
      console.log("ERROR: Invalid perft depth");
      return;
    }

    const startTime = Date.now();
    const nodes = this.perft.perft(depth);
    const endTime = Date.now();

    console.log(`OK: Perft(${depth}): ${nodes} nodes (${endTime - startTime}ms)`);
  }

  private handleStatus(): void {
    const color = this.board.getTurn();
    const legalMoves = this.moveGenerator.getLegalMoves(color);

    if (legalMoves.length === 0) {
      if (this.moveGenerator.isInCheck(color)) {
        const winner = color === "white" ? "Black" : "White";
        console.log(`CHECKMATE: ${winner} wins`);
      } else {
        console.log("STALEMATE: Draw");
      }
    } else if (this.board.isDraw()) {
      console.log(`DRAW: ${this.board.getDrawInfo()}`);
    } else {
      console.log("OK: ongoing");
    }
  }

  private handleHelp(): void {
    console.log("Available commands:");
    console.log(
      "  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)",
    );
    console.log("  undo - Undo the last move");
    console.log("  new - Start a new game");
    console.log("  ai <depth> - Let AI make a move (depth 1-5)");
    console.log("  fen <string> - Load position from FEN");
    console.log("  export - Export current position as FEN");
    console.log("  eval - Evaluate current position");
    console.log("  hash - Show Zobrist hash of current position");
    console.log("  draws - Show draw detection status");
    console.log("  history - Show position hash history");
    console.log("  perft <depth> - Run performance test");
    console.log("  help - Show this help message");
    console.log("  quit - Exit the program");
  }

  private checkGameEnd(): void {
    const color = this.board.getTurn();
    const legalMoves = this.moveGenerator.getLegalMoves(color);

    if (legalMoves.length === 0) {
      if (this.moveGenerator.isInCheck(color)) {
        const winner = color === "white" ? "Black" : "White";
        console.log(`CHECKMATE: ${winner} wins`);
      } else {
        console.log("STALEMATE: Draw");
      }
    } else if (this.board.isDraw()) {
      console.log(`DRAW: ${this.board.getDrawInfo()}`);
    }
  }
}

const engine = new ChessEngine();
engine.start();
