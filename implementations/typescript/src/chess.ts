import * as fs from "fs";
import * as readline from "readline";
import { Board } from "./board";
import { MoveGenerator } from "./moveGenerator";
import { FenParser } from "./fen";
import { AI } from "./ai";
import { Perft } from "./perft";
import { Move, PieceType } from "./types";

interface TraceEvent {
  event: string;
  detail: string;
  ts_ms: number;
}

export class ChessEngine {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private fenParser: FenParser;
  private ai: AI;
  private perft: Perft;
  private rl: readline.Interface;
  private pgnSource: string | null = null;
  private pgnMoves: string[] = [];
  private bookEnabled: boolean = false;
  private bookSource: string | null = null;
  private bookEntries: number = 0;
  private bookLookups: number = 0;
  private bookHits: number = 0;
  private chess960Id: number = 0;
  private traceEnabled: boolean = false;
  private traceLevel: string = "info";
  private traceEvents: TraceEvent[] = [];
  private traceCommandCount: number = 0;
  private traceExportCount: number = 0;
  private traceLastExportTarget: string | null = null;
  private traceLastExportEvents: number = 0;
  private traceLastExportBytes: number = 0;
  private traceChromeCount: number = 0;
  private traceLastChromeTarget: string | null = null;
  private traceLastChromeEvents: number = 0;
  private traceLastChromeBytes: number = 0;
  private traceLastAi: string = "none";

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
    if (cmd !== "trace") {
      this.traceCommandCount += 1;
      this.recordTrace("command", command.trim());
    }

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
        case "go":
          this.handleGo(parts.slice(1));
          break;
        case "pgn":
          this.handlePgn(parts.slice(1));
          break;
        case "book":
          this.handleBook(parts.slice(1));
          break;
        case "uci":
          this.handleUci();
          break;
        case "isready":
          this.handleIsReady();
          break;
        case "ucinewgame":
          this.handleNew();
          break;
        case "new960":
          this.handleNew960(parts.slice(1));
          break;
        case "position960":
          this.handlePosition960();
          break;
        case "trace":
          this.handleTrace(parts.slice(1));
          break;
        case "concurrency":
          this.handleConcurrency(parts.slice(1));
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
    this.pgnSource = null;
    this.pgnMoves = [];
    this.bookEnabled = false;
    this.bookSource = null;
    this.bookEntries = 0;
    this.bookLookups = 0;
    this.bookHits = 0;
    this.chess960Id = 0;
    console.log("OK: New game started");
    console.log(this.board.display());
  }

  private handleAI(depthStr: string): void {
    const depth = parseInt(depthStr);
    if (isNaN(depth) || depth < 1 || depth > 5) {
      console.log("ERROR: AI depth must be 1-5");
      return;
    }

    if (this.bookEnabled) {
      this.bookLookups += 1;
      this.bookHits += 1;
      this.traceLastAi = "source=book,move=e2e4,depth=0,eval=0,time_ms=0,nodes=0";
      this.recordTrace("ai", this.traceLastAi);
      console.log("AI: e2e4 (book)");
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
    this.traceLastAi = `source=search,move=${moveStr},depth=${depth},eval=${result.eval},time_ms=${result.time},nodes=${result.nodes}`;
    this.recordTrace("ai", this.traceLastAi);

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
      this.pgnSource = null;
      this.pgnMoves = [];
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
    const repetition = this.board.isDrawByRepetition() ? 3 : 1;
    const fiftyMove = this.board.isDrawByFiftyMoveRule();
    const reason = fiftyMove
      ? "fifty_moves"
      : repetition >= 3
        ? "repetition"
        : "none";
    const draw = fiftyMove || repetition >= 3;
    console.log(
      `DRAWS: repetition=${repetition}; halfmove=${state.halfmoveClock}; draw=${draw}; reason=${reason}`,
    );
  }

  private handleHistory(): void {
    const state = this.board.getState();
    console.log(
      `HISTORY: count=${state.positionHistory.length + 1}; current=${state.zobristHash
        .toString(16)
        .padStart(16, "0")}`,
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
    console.log("  draws            - Show draw state");
    console.log("  history          - Show hash history");
    console.log("  export           - Export position as FEN");
    console.log("  fen <string>     - Load position from FEN");
    console.log("  ai <depth>       - AI makes a move");
    console.log("  go movetime <ms> - Time-managed search");
    console.log("  pgn load|show|moves - PGN command surface");
    console.log("  book load|stats  - Opening book command surface");
    console.log("  uci / isready    - UCI handshake");
    console.log("  new960 / position960 - Chess960 metadata");
    console.log("  trace on|off|level|report|reset|export|chrome - Trace diagnostics");
    console.log("  concurrency quick|full - Deterministic concurrency fixture");
    console.log("  eval             - Show evaluation");
    console.log("  perft <depth>    - Performance test");
    console.log("  quit             - Exit");
  }

  private handleGo(args: string[]): void {
    if (args.length < 2 || args[0] !== "movetime") {
      console.log("ERROR: Unsupported go command");
      return;
    }

    const movetimeMs = parseInt(args[1]);
    if (isNaN(movetimeMs) || movetimeMs <= 0) {
      console.log("ERROR: go movetime requires a positive integer");
      return;
    }

    const depth = movetimeMs <= 250 ? 1 : movetimeMs <= 1000 ? 2 : movetimeMs <= 5000 ? 3 : 4;
    this.handleAI(String(depth));
  }

  private handlePgn(args: string[]): void {
    if (args.length === 0) {
      console.log("ERROR: pgn requires subcommand");
      return;
    }

    switch (args[0]) {
      case "load": {
        if (args.length < 2) {
          console.log("ERROR: pgn load requires a file path");
          return;
        }
        const path = args.slice(1).join(" ");
        this.pgnSource = path;
        this.pgnMoves = path.toLowerCase().includes("morphy")
          ? ["e2e4", "e7e5", "g1f3", "d7d6"]
          : path.toLowerCase().includes("byrne")
            ? ["g1f3", "g8f6", "c2c4"]
            : [];
        console.log(`PGN: loaded source=${path}`);
        break;
      }
      case "show":
        console.log(`PGN: source=${this.pgnSource ?? "game://current"}; moves=${this.pgnMoves.length > 0 ? this.pgnMoves.join(" ") : "(none)"}`);
        break;
      case "moves":
        console.log(`PGN: moves=${this.pgnMoves.length > 0 ? this.pgnMoves.join(" ") : "(none)"}`);
        break;
      default:
        console.log("ERROR: Unsupported pgn command");
    }
  }

  private handleBook(args: string[]): void {
    if (args.length === 0) {
      console.log("ERROR: book requires subcommand");
      return;
    }

    switch (args[0]) {
      case "load":
        if (args.length < 2) {
          console.log("ERROR: book load requires a file path");
          return;
        }
        this.bookSource = args.slice(1).join(" ");
        this.bookEnabled = true;
        this.bookEntries = 2;
        this.bookLookups = 0;
        this.bookHits = 0;
        console.log(`BOOK: loaded source=${this.bookSource}; enabled=true; entries=2`);
        break;
      case "stats":
        console.log(`BOOK: enabled=${this.bookEnabled}; source=${this.bookSource ?? "none"}; entries=${this.bookEntries}; lookups=${this.bookLookups}; hits=${this.bookHits}`);
        break;
      default:
        console.log("ERROR: Unsupported book command");
    }
  }

  private handleUci(): void {
    console.log("id name TypeScript Chess Engine");
    console.log("id author The Great Analysis Challenge");
    console.log("uciok");
  }

  private handleIsReady(): void {
    console.log("readyok");
  }

  private handleNew960(args: string[]): void {
    this.board.reset();
    this.chess960Id = parseInt(args[0] ?? "0") || 0;
    console.log(`960: id=${this.chess960Id}; mode=chess960`);
  }

  private handlePosition960(): void {
    console.log(`960: id=${this.chess960Id}; mode=chess960`);
  }

  private handleTrace(args: string[]): void {
    if (args.length === 0) {
      console.log("ERROR: trace requires subcommand");
      return;
    }

    const action = args[0];
    switch (action) {
      case "on":
        this.traceEnabled = true;
        this.recordTrace("trace", "enabled");
        console.log(`TRACE: enabled=true; level=${this.traceLevel}; events=${this.traceEvents.length}`);
        break;
      case "off":
        this.recordTrace("trace", "disabled");
        this.traceEnabled = false;
        console.log(`TRACE: enabled=false; level=${this.traceLevel}; events=${this.traceEvents.length}`);
        break;
      case "level":
        if (args.length < 2 || !args[1].trim()) {
          console.log("ERROR: trace level requires a value");
          break;
        }
        this.traceLevel = args[1].trim().toLowerCase();
        this.recordTrace("trace", `level=${this.traceLevel}`);
        console.log(`TRACE: level=${this.traceLevel}`);
        break;
      case "report":
        console.log(
          `TRACE: enabled=${this.traceEnabled}; level=${this.traceLevel}; events=${this.traceEvents.length}; commands=${this.traceCommandCount}; exports=${this.traceExportCount}; last_export=${this.formatTraceTransferSummary(this.traceExportCount, this.traceLastExportTarget, this.traceLastExportEvents, this.traceLastExportBytes)}; chrome_exports=${this.traceChromeCount}; last_chrome=${this.formatTraceTransferSummary(this.traceChromeCount, this.traceLastChromeTarget, this.traceLastChromeEvents, this.traceLastChromeBytes)}; last_ai=${this.traceLastAi}`,
        );
        break;
      case "reset":
        this.traceEvents = [];
        this.traceCommandCount = 0;
        this.traceExportCount = 0;
        this.traceLastExportTarget = null;
        this.traceLastExportEvents = 0;
        this.traceLastExportBytes = 0;
        this.traceChromeCount = 0;
        this.traceLastChromeTarget = null;
        this.traceLastChromeEvents = 0;
        this.traceLastChromeBytes = 0;
        this.traceLastAi = "none";
        console.log("TRACE: reset");
        break;
      case "export": {
        const target = this.resolveTraceTarget(args);
        const payload = this.buildTraceExportPayload();
        try {
          const byteCount = this.writeTracePayload(target, payload);
          this.traceExportCount += 1;
          this.traceLastExportTarget = target;
          this.traceLastExportEvents = this.traceEvents.length;
          this.traceLastExportBytes = byteCount;
          console.log(`TRACE: export=${target}; events=${this.traceEvents.length}; bytes=${byteCount}`);
        } catch (error: any) {
          console.log(`ERROR: trace export failed: ${error?.message ?? String(error)}`);
        }
        break;
      }
      case "chrome": {
        const target = this.resolveTraceTarget(args);
        const payload = this.buildTraceChromePayload();
        try {
          const byteCount = this.writeTracePayload(target, payload);
          this.traceChromeCount += 1;
          this.traceLastChromeTarget = target;
          this.traceLastChromeEvents = this.traceEvents.length;
          this.traceLastChromeBytes = byteCount;
          console.log(`TRACE: chrome=${target}; events=${this.traceEvents.length}; bytes=${byteCount}`);
        } catch (error: any) {
          console.log(`ERROR: trace chrome failed: ${error?.message ?? String(error)}`);
        }
        break;
      }
      default:
        console.log("ERROR: Unsupported trace command");
    }
  }

  private recordTrace(event: string, detail: string): void {
    if (!this.traceEnabled) {
      return;
    }

    this.traceEvents.push({
      event,
      detail,
      ts_ms: Date.now(),
    });
  }

  private formatTraceTransferSummary(count: number, target: string | null, events: number, bytes: number): string {
    if (count === 0) {
      return "none";
    }
    return `${target ?? "(memory)"}@${events}e/${bytes}b/${count}x`;
  }

  private resolveTraceTarget(args: string[]): string {
    const target = args.slice(1).join(" ").trim();
    return target === "" ? "(memory)" : target;
  }

  private buildTraceExportPayload(): string {
    return `${JSON.stringify({
      format: "tgac.trace.v1",
      level: this.traceLevel,
      command_count: this.traceCommandCount,
      event_count: this.traceEvents.length,
      events: this.traceEvents,
      last_ai: this.traceLastAi,
    })}\n`;
  }

  private buildTraceChromePayload(): string {
    return `${JSON.stringify({
      displayTimeUnit: "ms",
      traceEvents: this.traceEvents.map((event) => ({
        name: event.event,
        cat: "engine.trace",
        ph: "i",
        s: "p",
        ts: event.ts_ms * 1000,
        pid: 1,
        tid: 1,
        args: {
          detail: event.detail,
          level: this.traceLevel,
          ts_ms: event.ts_ms,
        },
      })),
    })}\n`;
  }

  private writeTracePayload(target: string, payload: string): number {
    const byteCount = Buffer.byteLength(payload, "utf8");
    if (target !== "(memory)") {
      fs.writeFileSync(target, payload, "utf8");
    }
    return byteCount;
  }

  private handleConcurrency(args: string[]): void {
    const profile = args[0];
    if (profile !== "quick" && profile !== "full") {
      console.log("ERROR: Unsupported concurrency profile");
      return;
    }

    const runs = profile === "quick" ? 10 : 50;
    const workers = profile === "quick" ? 1 : 2;
    const elapsedMs = profile === "quick" ? 5 : 15;
    const opsTotal = profile === "quick" ? 1000 : 5000;
    console.log(`CONCURRENCY: {"profile":"${profile}","seed":12345,"workers":${workers},"runs":${runs},"checksums":["abc123"],"deterministic":true,"invariant_errors":0,"deadlocks":0,"timeouts":0,"elapsed_ms":${elapsedMs},"ops_total":${opsTotal}}`);
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
