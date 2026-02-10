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

      const turn = this.board.getTurn();
      if (piece.color !== turn) {
        console.log("ERROR: Wrong color piece");
        return;
      }

      const legalMoves = this.moveGenerator.getLegalMoves(turn);
      const move = legalMoves.find(
        (m) =>
          m.from === fromSquare &&
          m.to === toSquare &&
          (!m.promotion ||
            m.promotion === promotion ||
            (!promotion && m.promotion === "Q")),
      );

      if (!move) {
        const inCheck = this.moveGenerator.isInCheck(turn);
        if (inCheck) {
          console.log("ERROR: King would be in check");
        } else {
          console.log("ERROR: Illegal move");
        }
        return;
      }

      if (move.promotion && !promotion) {
        move.promotion = "Q";
      }

      this.board.makeMove(move);
      
      const nextTurn = this.board.getTurn();
      if (this.moveGenerator.isCheckmate(nextTurn)) {
        console.log(`CHECKMATE: ${turn === "white" ? "White" : "Black"} wins`);
      } else if (this.moveGenerator.isStalemate(nextTurn)) {
        console.log("STALEMATE: Draw");
      } else {
        const drawInfo = this.board.getDrawInfo();
        if (drawInfo) {
          console.log(`DRAW: by ${drawInfo}`);
        } else {
          console.log(`OK: ${moveStr}`);
        }
      }
      console.log(this.board.display());
    } catch (error) {
      console.log("ERROR: Invalid move format");
    }
  }

  private handleUndo(): void {
    const move = this.board.undoMove();
    if (move) {
      console.log("OK: undo");
      console.log(this.board.display());
    } else {
      console.log("ERROR: No moves to undo");
    }
  }

  private handleNew(): void {
    this.board.reset();
    console.log("OK: New game started");
    console.log(this.board.display());
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
      (result.move.promotion || "").toLowerCase();

    const turn = this.board.getTurn();
    this.board.makeMove(result.move);

    const nextTurn = this.board.getTurn();
    if (this.moveGenerator.isCheckmate(nextTurn)) {
      console.log(`AI: ${moveStr} (CHECKMATE)`);
    } else if (this.moveGenerator.isStalemate(nextTurn)) {
      console.log(`AI: ${moveStr} (STALEMATE)`);
    } else {
      const drawInfo = this.board.getDrawInfo();
      if (drawInfo) {
        console.log(`AI: ${moveStr} (DRAW: by ${drawInfo})`);
      } else {
        console.log(
          `AI: ${moveStr} (depth=${depth}, eval=${result.eval}, time=${result.time})`,
        );
      }
    }
    console.log(this.board.display());
  }

  private handleFen(fenString: string): void {
    try {
      this.fenParser.parseFen(fenString);
      console.log("OK: FEN loaded");
      console.log(this.board.display());
    } catch (error) {
      console.log("ERROR: Invalid FEN string");
    }
  }

  private handleExport(): void {
    const fen = this.fenParser.exportFen();
    console.log(`FEN: ${fen}`);
  }

  private handleEval(): void {
    const evaluation = this.ai.evaluatePosition();
    console.log(`EVALUATION: ${evaluation}`);
  }

  private handleHash(): void {
    console.log(`HASH: ${this.board.getHash().toString(16).padStart(16, "0")}`);
  }

  private handleDraws(): void {
    const state = this.board.getState();
    console.log(`REPETITION: ${this.board.isDrawByRepetition()}`);
    console.log(`50-MOVE RULE: ${this.board.isDrawByFiftyMoveRule()}`);
    console.log(`OK: clock=${state.halfmoveClock}`);
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

  private handlePerft(depthStr: string): void {
    const depth = parseInt(depthStr);
    if (isNaN(depth) || depth < 1) {
      console.log("ERROR: Invalid perft depth");
      return;
    }

    const nodes = this.perft.perft(depth);
    console.log(`Perft ${depth}: ${nodes}`);
  }

  private handleStatus(): void {
    const color = this.board.getTurn();
    if (this.moveGenerator.isCheckmate(color)) {
      const winner = color === "white" ? "Black" : "White";
      console.log(`CHECKMATE: ${winner} wins`);
    } else if (this.moveGenerator.isStalemate(color)) {
      console.log("STALEMATE: Draw");
    } else {
      const drawInfo = this.board.getDrawInfo();
      if (drawInfo) {
        console.log(`DRAW: by ${drawInfo}`);
      } else {
        console.log("OK: ongoing");
      }
    }
  }

  private handleHelp(): void {
    console.log("Available commands:");
    console.log(
      "  new              - Start a new game",
    );
    console.log("  move <from><to>  - Make a move (e.g., e2e4)");
    console.log("  undo             - Undo last move");
    console.log("  status           - Show game status");
    console.log("  hash             - Show Zobrist hash");
    console.log("  export           - Export position as FEN");
    console.log("  fen <string>     - Load position from FEN");
    console.log("  ai <depth>       - AI makes a move");
    console.log("  eval             - Show evaluation");
    console.log("  perft <depth>    - Performance test");
    console.log("  quit             - Exit");
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
    } else {
      const drawInfo = this.board.getDrawInfo();
      if (drawInfo) {
        console.log(`DRAW: by ${drawInfo}`);
      }
    }
  }
}

const engine = new ChessEngine();
engine.start();
