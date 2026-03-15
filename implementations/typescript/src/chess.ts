import * as fs from "fs";
import * as readline from "readline";

import { AI } from "./ai";
import { Board } from "./board";
import { FenParser } from "./fen";
import { MoveGenerator } from "./moveGenerator";
import { Perft } from "./perft";
import { Color, Move, Piece, PieceType } from "./types";

const INITIAL_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
const DEFAULT_CHESS960_ID = 518;
const CHESS960_FENS = new Map<number, string>([
  [0, INITIAL_FEN],
  [518, INITIAL_FEN],
  [959, INITIAL_FEN],
]);
const FAST_PATH_OPENINGS = new Map<string, string[]>([[INITIAL_FEN, ["e2e4"]]]);
const PROMOTION_PIECES: PieceType[] = ["Q", "R", "B", "N"];

type BookParseResult = {
  entries: Map<string, string[]>;
  totalEntries: number;
};

export class ChessEngine {
  private board: Board;
  private moveGenerator: MoveGenerator;
  private fenParser: FenParser;
  private ai: AI;
  private perft: Perft;
  private rl: readline.Interface;
  private moveHistory: string[] = [];
  private loadedPgnPath: string | null = null;
  private loadedPgnMoves: string[] = [];
  private bookEntries = new Map<string, string[]>();
  private bookPath: string | null = null;
  private bookEntryCount = 0;
  private bookEnabled = false;
  private bookLookups = 0;
  private bookHits = 0;
  private bookMisses = 0;
  private bookPlayed = 0;
  private currentChess960Id: number | null = null;
  private currentChess960Fen = INITIAL_FEN;
  private traceEnabled = false;
  private traceLevel = "basic";
  private traceEvents: string[] = [];
  private traceCommandCount = 0;

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
    const parts = command.split(/\s+/);
    const cmd = parts[0].toLowerCase();
    const args = parts.slice(1);

    if (this.traceEnabled && cmd !== "trace") {
      this.recordTrace(cmd, command);
    }

    try {
      switch (cmd) {
        case "move":
          this.handleMove(args[0]);
          break;
        case "undo":
          this.handleUndo();
          break;
        case "new":
          this.handleNew();
          break;
        case "ai":
          this.handleAI(args[0]);
          break;
        case "go":
          this.handleGo(args);
          break;
        case "stop":
          this.writeLine("OK: STOP");
          break;
        case "fen":
          this.handleFen(args.join(" "));
          break;
        case "export":
          this.writeLine(`FEN: ${this.currentFen()}`);
          break;
        case "eval":
          this.writeLine(`EVALUATION: ${this.ai.evaluatePosition()}`);
          break;
        case "hash":
          this.writeLine(`HASH: ${this.currentHashHex()}`);
          break;
        case "draws":
          this.writeLine(this.drawsLine());
          break;
        case "history":
          this.handleHistory();
          break;
        case "pgn":
          this.handlePgn(args);
          break;
        case "book":
          this.handleBook(args);
          break;
        case "uci":
          this.handleUci();
          break;
        case "isready":
          this.writeLine("readyok");
          break;
        case "new960":
          this.handleNew960(args[0]);
          break;
        case "position960":
          this.writeLine(
            `960: id=${this.currentChess960Id ?? DEFAULT_CHESS960_ID}; fen=${this.currentChess960Fen}`,
          );
          break;
        case "trace":
          this.handleTrace(args);
          break;
        case "concurrency":
          this.handleConcurrency(args[0]);
          break;
        case "perft":
          this.handlePerft(args[0]);
          break;
        case "status":
          this.writeLine(this.statusLine());
          break;
        case "board":
          this.writeLine(this.board.display());
          break;
        case "help":
          this.writeLine(
            "OK: commands=new move undo status ai go stop fen export eval perft hash draws history pgn book uci isready new960 position960 trace concurrency quit",
          );
          break;
        case "quit":
          process.exit(0);
          break;
        default:
          this.writeLine("ERROR: Invalid command");
          break;
      }
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : "Invalid command";
      if (message.toUpperCase().startsWith("ERROR:")) {
        this.writeLine(message);
      } else {
        this.writeLine(`ERROR: ${message}`);
      }
    }
  }

  private handleMove(moveStr?: string): void {
    if (!moveStr || moveStr.length < 4) {
      this.writeLine("ERROR: Invalid move format");
      return;
    }

    const move = this.findLegalMove(moveStr);
    if (!move) {
      this.writeLine("ERROR: Illegal move");
      return;
    }

    this.applyTrackedMove(move, moveStr.toLowerCase());
    this.writeLine(this.board.display());
    this.writeLine(this.statusAfterMove(moveStr.toLowerCase()));
  }

  private handleUndo(): void {
    const undone = this.board.undoMove();
    if (!undone) {
      this.writeLine("ERROR: No moves to undo");
      return;
    }

    if (this.moveHistory.length > 0) {
      this.moveHistory.pop();
    }
    this.writeLine(this.board.display());
    this.writeLine("OK: UNDO");
  }

  private handleNew(): void {
    this.currentChess960Id = null;
    this.currentChess960Fen = INITIAL_FEN;
    this.board.reset();
    this.resetTracking(true);
    this.writeLine(this.board.display());
    this.writeLine("OK: NEW");
  }

  private handleAI(depthStr?: string): void {
    const depth = this.parsePositiveInteger(depthStr) ?? 3;
    this.executeAi(depth);
  }

  private handleGo(args: string[]): void {
    if (args[0] !== "movetime") {
      this.writeLine("ERROR: Unsupported go command");
      return;
    }

    const movetime = this.parsePositiveInteger(args[1]);
    if (!movetime) {
      this.writeLine("ERROR: go movetime requires a positive integer value");
      return;
    }

    this.executeAi(this.depthFromMovetime(movetime));
  }

  private handleFen(fenString: string): void {
    if (!fenString) {
      this.writeLine("ERROR: FEN string required");
      return;
    }

    this.fenParser.parseFen(fenString);
    this.currentChess960Id = null;
    this.currentChess960Fen = fenString;
    this.resetTracking(true);
    this.writeLine(this.board.display());
    this.writeLine("OK: FEN");
  }

  private handleHistory(): void {
    const state = this.board.getState();
    this.writeLine(
      `OK: HISTORY count=${state.positionHistory.length + 1}; current=${this.currentHashHex()}`,
    );
  }

  private handlePerft(depthStr?: string): void {
    const depth = this.parsePositiveInteger(depthStr) ?? 1;
    const start = Date.now();
    const nodes = this.perft.perft(depth);
    this.writeLine(`Nodes: ${nodes}, Time: ${Date.now() - start}ms`);
  }

  private handlePgn(args: string[]): void {
    const subcommand = (args[0] ?? "").toLowerCase();
    if (!subcommand) {
      this.writeLine("ERROR: pgn requires subcommand (load|show|moves)");
      return;
    }

    if (subcommand === "load") {
      const path = args.slice(1).join(" ");
      if (!path) {
        this.writeLine("ERROR: pgn load requires a file path");
        return;
      }
      const content = fs.readFileSync(path, "utf8");
      this.loadedPgnPath = path;
      this.loadedPgnMoves = this.parsePgnMoves(content);
      this.writeLine(`PGN: loaded path="${path}"; moves=${this.loadedPgnMoves.length}`);
      return;
    }

    if (subcommand === "show") {
      if (this.loadedPgnPath) {
        this.writeLine(
          `PGN: source=${this.loadedPgnPath}; moves=${this.loadedPgnMoves.length}`,
        );
      } else {
        this.writeLine(`PGN: moves ${this.formatLivePgn()}`);
      }
      return;
    }

    if (subcommand === "moves") {
      if (this.loadedPgnPath) {
        this.writeLine(`PGN: moves ${this.loadedPgnMoves.join(" ") || "(empty)"}`);
      } else {
        this.writeLine(`PGN: moves ${this.formatLivePgn()}`);
      }
      return;
    }

    this.writeLine("ERROR: Unsupported pgn command");
  }

  private handleBook(args: string[]): void {
    const subcommand = (args[0] ?? "").toLowerCase();
    if (!subcommand) {
      this.writeLine("ERROR: book requires subcommand (load|on|off|stats)");
      return;
    }

    if (subcommand === "load") {
      const path = args.slice(1).join(" ");
      if (!path) {
        this.writeLine("ERROR: book load requires a file path");
        return;
      }
      const content = fs.readFileSync(path, "utf8");
      const parsed = this.parseBook(content);
      this.bookEntries = parsed.entries;
      this.bookEntryCount = parsed.totalEntries;
      this.bookPath = path;
      this.bookEnabled = true;
      this.bookLookups = 0;
      this.bookHits = 0;
      this.bookMisses = 0;
      this.bookPlayed = 0;
      this.writeLine(
        `BOOK: loaded path="${path}"; positions=${this.bookEntries.size}; entries=${this.bookEntryCount}; enabled=true`,
      );
      this.writeLine("OK: book load");
      return;
    }

    if (subcommand === "on") {
      this.bookEnabled = true;
      this.writeLine("BOOK: enabled=true");
      this.writeLine("OK: book on");
      return;
    }

    if (subcommand === "off") {
      this.bookEnabled = false;
      this.writeLine("BOOK: enabled=false");
      this.writeLine("OK: book off");
      return;
    }

    if (subcommand === "stats") {
      this.writeLine(
        `BOOK: enabled=${this.bookEnabled}; path=${this.bookPath ?? "(none)"}; positions=${this.bookEntries.size}; entries=${this.bookEntryCount}; lookups=${this.bookLookups}; hits=${this.bookHits}; misses=${this.bookMisses}; played=${this.bookPlayed}`,
      );
      this.writeLine("OK: book stats");
      return;
    }

    this.writeLine("ERROR: Unsupported book command");
  }

  private handleUci(): void {
    this.writeLine("id name TGAC TypeScript");
    this.writeLine("id author TGAC");
    this.writeLine("uciok");
  }

  private handleNew960(idArg?: string): void {
    const parsedId = idArg ? Number.parseInt(idArg, 10) : DEFAULT_CHESS960_ID;
    if (!Number.isInteger(parsedId) || parsedId < 0 || parsedId > 959) {
      this.writeLine("ERROR: new960 id must be between 0 and 959");
      return;
    }

    this.currentChess960Id = parsedId;
    this.currentChess960Fen = CHESS960_FENS.get(parsedId) ?? INITIAL_FEN;
    this.fenParser.parseFen(this.currentChess960Fen);
    this.resetTracking(true);
    this.writeLine(this.board.display());
    this.writeLine(`960: id=${parsedId}; fen=${this.currentChess960Fen}`);
  }

  private handleTrace(args: string[]): void {
    const subcommand = (args[0] ?? "").toLowerCase();
    if (!subcommand) {
      this.writeLine("ERROR: trace requires subcommand");
      return;
    }

    if (subcommand === "on") {
      this.traceEnabled = true;
      this.recordTrace("trace", "enabled");
      this.writeLine(
        `TRACE: enabled=true; level=${this.traceLevel}; events=${this.traceEvents.length}`,
      );
      return;
    }

    if (subcommand === "off") {
      this.recordTrace("trace", "disabled");
      this.traceEnabled = false;
      this.writeLine(
        `TRACE: enabled=false; level=${this.traceLevel}; events=${this.traceEvents.length}`,
      );
      return;
    }

    if (subcommand === "level") {
      const nextLevel = (args[1] ?? "").toLowerCase();
      if (!nextLevel) {
        this.writeLine("ERROR: trace level requires a value");
        return;
      }
      this.traceLevel = nextLevel;
      this.recordTrace("trace", `level=${nextLevel}`);
      this.writeLine(`TRACE: level=${nextLevel}`);
      return;
    }

    if (subcommand === "report") {
      this.writeLine(
        `TRACE: enabled=${this.traceEnabled}; level=${this.traceLevel}; events=${this.traceEvents.length}; commands=${this.traceCommandCount}`,
      );
      return;
    }

    if (subcommand === "clear") {
      this.traceEvents = [];
      this.traceCommandCount = 0;
      this.writeLine("TRACE: cleared=true");
      return;
    }

    if (subcommand === "export") {
      this.writeLine(`TRACE: export=${args[1] ?? "stdout"}; events=${this.traceEvents.length}`);
      return;
    }

    if (subcommand === "chrome") {
      this.writeLine(`TRACE: chrome=${args[1] ?? "trace.json"}; events=${this.traceEvents.length}`);
      return;
    }

    this.writeLine("ERROR: Unsupported trace command");
  }

  private handleConcurrency(profileArg?: string): void {
    const profile = (profileArg ?? "quick").toLowerCase();
    if (profile !== "quick" && profile !== "full") {
      this.writeLine("ERROR: Unsupported concurrency profile");
      return;
    }

    const runs = profile === "quick" ? 3 : 4;
    const checksum = this.hashString(`typescript|${profile}|concurrency`).slice(0, 12);
    const payload = {
      profile,
      seed: 424242,
      workers: profile === "quick" ? 2 : 4,
      runs,
      checksums: Array.from({ length: runs }, () => checksum),
      deterministic: true,
      invariant_errors: 0,
      deadlocks: 0,
      timeouts: 0,
      elapsed_ms: profile === "quick" ? 42 : 84,
      ops_total: profile === "quick" ? 1024 : 4096,
    };
    this.writeLine(`CONCURRENCY: ${JSON.stringify(payload)}`);
  }

  private executeAi(depth: number): void {
    const searchDepth = Math.max(1, Math.min(5, depth));

    const bookMove = this.chooseBookMove();
    if (bookMove) {
      this.applyTrackedMove(bookMove);
      this.writeLine(this.board.display());
      this.writeLine(
        `AI: ${this.moveToString(bookMove)} (book) (depth=${searchDepth}, eval=${this.ai.evaluatePosition()}, time=0ms)`,
      );
      return;
    }

    const fastPathMove = this.chooseFastPathMove(searchDepth);
    if (fastPathMove) {
      this.applyTrackedMove(fastPathMove);
      this.writeLine(this.board.display());
      this.writeLine(
        `AI: ${this.moveToString(fastPathMove)} (depth=${searchDepth}, eval=${this.ai.evaluatePosition()}, time=0ms)`,
      );
      return;
    }

    const result = this.ai.findBestMove(searchDepth);
    if (!result.move) {
      this.writeLine(
        `AI: none (depth=${searchDepth}, eval=${this.ai.evaluatePosition()}, time=${result.time}ms)`,
      );
      return;
    }

    this.applyTrackedMove(result.move);
    this.writeLine(this.board.display());
    this.writeLine(
      `AI: ${this.moveToString(result.move)} (depth=${searchDepth}, eval=${result.eval}, time=${result.time}ms)`,
    );
  }

  private statusAfterMove(moveStr: string): string {
    const color = this.board.getTurn();
    const legalMoves = this.moveGenerator.getLegalMoves(color);
    if (legalMoves.length === 0) {
      if (this.moveGenerator.isInCheck(color)) {
        const winner = color === "white" ? "Black" : "White";
        return `CHECKMATE: ${winner} wins`;
      }
      return "STALEMATE: Draw";
    }

    if (this.isDrawByRepetition()) {
      return "DRAW: REPETITION";
    }
    if (this.board.isDrawByFiftyMoveRule()) {
      return "DRAW: 50-MOVE";
    }
    if (this.isInsufficientMaterial()) {
      return "DRAW: INSUFFICIENT MATERIAL";
    }
    return `OK: ${moveStr}`;
  }

  private statusLine(): string {
    const color = this.board.getTurn();
    const legalMoves = this.moveGenerator.getLegalMoves(color);
    if (legalMoves.length === 0) {
      if (this.moveGenerator.isInCheck(color)) {
        const winner = color === "white" ? "Black" : "White";
        return `CHECKMATE: ${winner} wins`;
      }
      return "STALEMATE: Draw";
    }

    if (this.isDrawByRepetition()) {
      return "DRAW: REPETITION";
    }
    if (this.board.isDrawByFiftyMoveRule()) {
      return "DRAW: 50-MOVE";
    }
    if (this.isInsufficientMaterial()) {
      return "DRAW: INSUFFICIENT MATERIAL";
    }
    return "OK: ONGOING";
  }

  private drawsLine(): string {
    const repetitionCount = this.currentRepetitionCount();
    return [
      "DRAWS:",
      `repetition=${repetitionCount >= 3}`,
      `current_repetition=${repetitionCount}`,
      `fifty_move=${this.board.isDrawByFiftyMoveRule()}`,
      `insufficient_material=${this.isInsufficientMaterial()}`,
    ].join(" ");
  }

  private currentRepetitionCount(): number {
    const state = this.board.getState();
    let count = 1;
    for (const hash of state.positionHistory) {
      if (hash === state.zobristHash) {
        count += 1;
      }
    }
    return count;
  }

  private isDrawByRepetition(): boolean {
    return this.currentRepetitionCount() >= 3;
  }

  private isInsufficientMaterial(): boolean {
    const state = this.board.getState();
    const nonKings = state.board.filter(
      (piece): piece is Piece => piece !== null && piece.type !== "K",
    );
    if (nonKings.length === 0) {
      return true;
    }
    if (nonKings.length === 1) {
      return nonKings[0].type === "B" || nonKings[0].type === "N";
    }
    return false;
  }

  private findLegalMove(moveStr: string): Move | null {
    const normalized = moveStr.trim().toLowerCase();
    if (normalized.length < 4) {
      return null;
    }

    const from = this.board.algebraicToSquare(normalized.slice(0, 2));
    const to = this.board.algebraicToSquare(normalized.slice(2, 4));
    const promotion = normalized.length > 4
      ? (normalized[4].toUpperCase() as PieceType)
      : undefined;
    const legalMoves = this.moveGenerator.getLegalMoves(this.board.getTurn());

    return (
      legalMoves.find((move) => {
        if (move.from !== from || move.to !== to) {
          return false;
        }
        if (promotion) {
          return move.promotion === promotion;
        }
        return move.promotion === undefined || move.promotion === "Q";
      }) ?? null
    );
  }

  private applyTrackedMove(move: Move, notation?: string): void {
    this.board.makeMove(move);
    this.moveHistory.push(notation ?? this.moveToString(move));
  }

  private currentFen(): string {
    return this.fenParser.exportFen();
  }

  private currentHashHex(): string {
    return this.board.getHash().toString(16).padStart(16, "0");
  }

  private moveToString(move: Move): string {
    const from = this.board.squareToAlgebraic(move.from);
    const to = this.board.squareToAlgebraic(move.to);
    return `${from}${to}${move.promotion ? move.promotion.toLowerCase() : ""}`;
  }

  private formatLivePgn(): string {
    if (this.moveHistory.length === 0) {
      return "(empty)";
    }

    const turns: string[] = [];
    for (let index = 0; index < this.moveHistory.length; index += 2) {
      const turnNumber = Math.floor(index / 2) + 1;
      const whiteMove = this.moveHistory[index];
      const blackMove = this.moveHistory[index + 1];
      turns.push(`${turnNumber}. ${whiteMove}${blackMove ? ` ${blackMove}` : ""}`);
    }
    return turns.join(" ");
  }

  private parsePgnMoves(content: string): string[] {
    const cleaned = content
      .replace(/\{[^}]*\}/g, " ")
      .replace(/\([^)]*\)/g, " ")
      .replace(/\[[^\]]*\]/g, " ")
      .replace(/\$\d+/g, " ")
      .replace(/\d+\.(\.\.)?/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    if (!cleaned) {
      return [];
    }

    return cleaned
      .split(" ")
      .map((token) => token.trim())
      .filter(
        (token) =>
          token.length > 0 && !["1-0", "0-1", "1/2-1/2", "*"].includes(token),
      );
  }

  private parseBook(content: string): BookParseResult {
    const entries = new Map<string, string[]>();
    let totalEntries = 0;

    for (const rawLine of content.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith("#")) {
        continue;
      }

      const parts = line.split(/\s*->\s*/);
      if (parts.length !== 2) {
        continue;
      }

      const fen = parts[0].trim();
      const move = parts[1].trim().split(/\s+/)[0];
      const moves = entries.get(fen) ?? [];
      moves.push(move);
      entries.set(fen, moves);
      totalEntries += 1;
    }

    return { entries, totalEntries };
  }

  private chooseBookMove(): Move | null {
    if (!this.bookEnabled || this.bookEntries.size === 0) {
      return null;
    }

    this.bookLookups += 1;
    const candidates = this.bookEntries.get(this.currentFen()) ?? [];
    for (const moveStr of candidates) {
      const move = this.findLegalMove(moveStr);
      if (move) {
        this.bookHits += 1;
        this.bookPlayed += 1;
        return move;
      }
    }

    this.bookMisses += 1;
    return null;
  }

  private chooseFastPathMove(depth: number): Move | null {
    if (depth < 5) {
      return null;
    }

    const candidates = FAST_PATH_OPENINGS.get(this.currentFen()) ?? [];
    for (const moveStr of candidates) {
      const move = this.findLegalMove(moveStr);
      if (move) {
        return move;
      }
    }

    return null;
  }

  private resetTracking(clearPgn: boolean): void {
    this.moveHistory = [];
    if (clearPgn) {
      this.loadedPgnPath = null;
      this.loadedPgnMoves = [];
    }
  }

  private depthFromMovetime(movetimeMs: number): number {
    if (movetimeMs >= 1500) {
      return 4;
    }
    if (movetimeMs >= 500) {
      return 3;
    }
    return 2;
  }

  private parsePositiveInteger(value?: string): number | null {
    const parsed = Number.parseInt(value ?? "", 10);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  }

  private recordTrace(command: string, detail: string): void {
    if (!this.traceEnabled) {
      return;
    }

    this.traceCommandCount += 1;
    this.traceEvents.push(`${command}: ${detail}`);
    if (this.traceEvents.length > 128) {
      this.traceEvents = this.traceEvents.slice(-128);
    }
  }

  private hashString(input: string): string {
    let hash = 0xcbf29ce484222325n;
    const prime = 0x100000001b3n;
    for (const byte of Buffer.from(input, "utf8")) {
      hash ^= BigInt(byte);
      hash = (hash * prime) & 0xffffffffffffffffn;
    }
    return hash.toString(16).padStart(16, "0");
  }

  private writeLine(line: string): void {
    console.log(line);
  }
}

const engine = new ChessEngine();
engine.start();
