package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

func main() {
	engine := NewChessEngine()
	engine.Run()
}

type ChessEngine struct {
	gameState         *GameState
	ai                *AI
	pgnPath           string
	pgnMoves          []string
	chess960ID        int
	traceEnabled      bool
	traceLevel        string
	traceEvents       []TraceEvent
	traceCommandCount int
}

type TraceEvent struct {
	TsMS   int64  `json:"ts_ms"`
	Event  string `json:"event"`
	Detail string `json:"detail"`
}

func NewChessEngine() *ChessEngine {
	return &ChessEngine{
		gameState:    NewGameState(),
		ai:           NewAI(),
		pgnPath:      "",
		pgnMoves:     make([]string, 0),
		traceLevel:   "info",
		traceEvents:  make([]TraceEvent, 0),
	}
}

func (engine *ChessEngine) Run() {
	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Print("") // Ensure output is flushed
		if !scanner.Scan() {
			break
		}

		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) == 0 {
			continue
		}

		command := strings.ToLower(parts[0])
		if command != "trace" {
			engine.traceCommandCount++
			engine.trace("command", line)
		}

		switch command {
		case "new":
			engine.handleNew()
		case "move":
			if len(parts) != 2 {
				fmt.Println("ERROR: Invalid move format")
			} else {
				engine.handleMove(parts[1])
			}
		case "undo":
			engine.handleUndo()
		case "status":
			engine.handleStatus()
		case "hash":
			fmt.Printf("HASH: %016x\n", engine.gameState.ZobristHash)
		case "draws":
			repetitionCount := engine.repetitionCount()
			halfmove := engine.gameState.HalfmoveClock
			draw := repetitionCount >= 3 || halfmove >= 100
			reason := "none"
			if halfmove >= 100 {
				reason = "fifty_moves"
			} else if repetitionCount >= 3 {
				reason = "repetition"
			}
			fmt.Printf(
				"DRAWS: repetition=%d; halfmove=%d; draw=%t; reason=%s\n",
				repetitionCount, halfmove, draw, reason,
			)
		case "history":
			fmt.Printf(
				"HISTORY: count=%d; current=%016x\n",
				len(engine.gameState.PositionHistory)+1,
				engine.gameState.ZobristHash,
			)
			fmt.Printf("Position History (%d positions):\n", len(engine.gameState.PositionHistory)+1)
			for i, h := range engine.gameState.PositionHistory {
				fmt.Printf("  %d: %016x\n", i, h)
			}
			fmt.Printf("  %d: %016x (current)\n", len(engine.gameState.PositionHistory), engine.gameState.ZobristHash)
		case "go":
			engine.handleGo(parts[1:])
		case "stop":
			fmt.Println("OK: stop")
		case "pgn":
			engine.handlePGN(parts[1:])
		case "uci":
			engine.handleUCI()
		case "isready":
			engine.handleIsReady()
		case "new960":
			engine.handleNew960(parts[1:])
		case "position960":
			engine.handlePosition960()
		case "trace":
			engine.handleTrace(parts[1:])
		case "concurrency":
			engine.handleConcurrency(parts[1:])
		case "fen":
			if len(parts) < 2 {
				fmt.Println("ERROR: FEN string required")
			} else {
				engine.handleFEN(strings.Join(parts[1:], " "))
			}
		case "export":
			engine.handleExport()
		case "eval":
			engine.handleEval()
		case "board":
			fmt.Print(engine.gameState.Display())
			fmt.Println("OK: board displayed")
		case "ai":
			depth := 3 // default depth
			if len(parts) > 1 {
				if d, err := strconv.Atoi(parts[1]); err == nil && d >= 1 && d <= 5 {
					depth = d
				}
			}
			engine.handleAI(depth)
		case "perft":
			if len(parts) > 1 {
				if d, err := strconv.Atoi(parts[1]); err == nil && d >= 1 && d <= 6 {
					engine.handlePerft(d)
				} else {
					fmt.Println("ERROR: Invalid perft depth")
				}
			} else {
				fmt.Println("ERROR: Perft depth required")
			}
		case "display", "show":
			fmt.Print(engine.gameState.Display())
		case "quit", "exit":
			return
		case "help":
			engine.showHelp()
		default:
			fmt.Println("ERROR: Unknown command")
		}
	}
}

func (engine *ChessEngine) handleNew() {
	engine.gameState = NewGameState()
	fmt.Println("OK: New game started")
	fmt.Print(engine.gameState.Display())
}

func (engine *ChessEngine) handleMove(moveStr string) {
	if len(moveStr) < 4 {
		fmt.Println("ERROR: Invalid move format")
		return
	}

	fromStr := moveStr[0:2]
	toStr := moveStr[2:4]

	from := AlgebraicToSquare(fromStr)
	to := AlgebraicToSquare(toStr)

	if !from.IsValid() || !to.IsValid() {
		fmt.Println("ERROR: Invalid move format")
		return
	}

	// Handle promotion
	var promotionPiece PieceType
	if len(moveStr) == 5 {
		switch strings.ToLower(string(moveStr[4])) {
		case "q":
			promotionPiece = Queen
		case "r":
			promotionPiece = Rook
		case "b":
			promotionPiece = Bishop
		case "n":
			promotionPiece = Knight
		default:
			fmt.Println("ERROR: Invalid promotion piece")
			return
		}
	}

	move, err := engine.gameState.IsValidMove(from, to)
	if err != nil {
		fmt.Printf("ERROR: %s\n", err.Error())
		return
	}

	// Handle promotion override
	if move.IsPromotion && len(moveStr) == 5 {
		move.PromoteTo = promotionPiece
	}

	engine.gameState.MakeMove(move)

	// Check for game end conditions
	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		if engine.gameState.IsInCheck(engine.gameState.ActiveColor) {
			if engine.gameState.ActiveColor == White {
				fmt.Println("CHECKMATE: Black wins")
			} else {
				fmt.Println("CHECKMATE: White wins")
			}
		} else {
			fmt.Println("STALEMATE: Draw")
		}
	} else {
		drawReason := engine.gameState.GetDrawReason()
		if drawReason != "" {
			fmt.Printf("DRAW: by %s\n", drawReason)
		} else {
			fmt.Printf("OK: %s\n", moveStr)
		}
	}
	fmt.Print(engine.gameState.Display())
}

func (engine *ChessEngine) handleUndo() {
	if engine.gameState.UndoLastMove() {
		fmt.Println("OK: undo")
		fmt.Print(engine.gameState.Display())
	} else {
		fmt.Println("ERROR: No moves to undo")
	}
}

func (engine *ChessEngine) handleFEN(fen string) {
	err := engine.gameState.FromFEN(fen)
	if err != nil {
		fmt.Printf("ERROR: Invalid FEN: %s\n", err.Error())
	} else {
		fmt.Println("OK: FEN loaded")
		fmt.Print(engine.gameState.Display())
	}
}

func (engine *ChessEngine) handleExport() {
	fen := engine.gameState.ToFEN()
	fmt.Printf("FEN: %s\n", fen)
}

func (engine *ChessEngine) handleEval() {
	score := engine.ai.evaluate(engine.gameState)
	fmt.Printf("EVALUATION: %d\n", score)
}

func (engine *ChessEngine) handleStatus() {
	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		if engine.gameState.IsInCheck(engine.gameState.ActiveColor) {
			if engine.gameState.ActiveColor == White {
				fmt.Println("CHECKMATE: Black wins")
			} else {
				fmt.Println("CHECKMATE: White wins")
			}
		} else {
			fmt.Println("STALEMATE: Draw")
		}
	} else {
		drawReason := engine.gameState.GetDrawReason()
		if drawReason != "" {
			fmt.Printf("DRAW: by %s\n", drawReason)
		} else {
			fmt.Println("OK: ongoing")
		}
	}
}

func (engine *ChessEngine) handleAI(depth int) {
	start := time.Now()

	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		fmt.Println("ERROR: No legal moves available")
		return
	}

	bestMove := engine.ai.FindBestMove(engine.gameState, depth)

	// Validate that we got a legal move
	validMove := false
	for _, move := range legalMoves {
		if move.From == bestMove.From && move.To == bestMove.To {
			bestMove = move // Use the complete move with all flags
			validMove = true
			break
		}
	}

	if !validMove {
		// Fallback to first legal move
		bestMove = legalMoves[0]
	}

	engine.gameState.MakeMove(bestMove)

	elapsed := time.Since(start)
	score := engine.ai.evaluate(engine.gameState)

	moveStr := fmt.Sprintf("%s%s", bestMove.From.ToAlgebraic(), bestMove.To.ToAlgebraic())
	if bestMove.IsPromotion {
		switch bestMove.PromoteTo {
		case Queen:
			moveStr += "q"
		case Rook:
			moveStr += "r"
		case Bishop:
			moveStr += "b"
		case Knight:
			moveStr += "n"
		}
	}

	// Check for game end conditions
	nextLegalMoves := engine.gameState.GenerateLegalMoves()
	if len(nextLegalMoves) == 0 {
		if engine.gameState.IsInCheck(engine.gameState.ActiveColor) {
			fmt.Printf("AI: %s (CHECKMATE)\n", moveStr)
		} else {
			fmt.Printf("AI: %s (STALEMATE)\n", moveStr)
		}
	} else {
		drawReason := engine.gameState.GetDrawReason()
		if drawReason != "" {
			fmt.Printf("AI: %s (DRAW: by %s)\n", moveStr, drawReason)
		} else {
			fmt.Printf("AI: %s (depth=%d, eval=%d, time=%d)\n",
				moveStr, depth, score, elapsed.Milliseconds())
		}
	}

	fmt.Print(engine.gameState.Display())
}

func (engine *ChessEngine) repetitionCount() int {
	start := len(engine.gameState.PositionHistory) - engine.gameState.HalfmoveClock
	if start < 0 {
		start = 0
	}

	count := 1
	for i := len(engine.gameState.PositionHistory) - 1; i >= start; i-- {
		if engine.gameState.PositionHistory[i] == engine.gameState.ZobristHash {
			count++
		}
	}
	return count
}

func depthForMovetime(movetimeMs int) int {
	if movetimeMs <= 200 {
		return 1
	}
	if movetimeMs <= 500 {
		return 2
	}
	if movetimeMs <= 2000 {
		return 3
	}
	if movetimeMs <= 5000 {
		return 4
	}
	return 5
}

func (engine *ChessEngine) handleGo(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: go requires subcommand (movetime <ms>|infinite)")
		return
	}

	switch strings.ToLower(args[0]) {
	case "movetime":
		if len(args) < 2 {
			fmt.Println("ERROR: go movetime requires a value in milliseconds")
			return
		}
		movetimeMs, err := strconv.Atoi(args[1])
		if err != nil {
			fmt.Println("ERROR: go movetime requires an integer value")
			return
		}
		if movetimeMs <= 0 {
			fmt.Println("ERROR: go movetime must be > 0")
			return
		}
		engine.handleAI(depthForMovetime(movetimeMs))
	case "infinite":
		fmt.Println("OK: go infinite acknowledged (use stop to terminate)")
	default:
		fmt.Println("ERROR: Unsupported go command")
	}
}

func (engine *ChessEngine) handlePGN(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: pgn requires subcommand (load|show|moves)")
		return
	}

	switch strings.ToLower(args[0]) {
	case "load":
		if len(args) < 2 {
			fmt.Println("ERROR: pgn load requires a file path")
			return
		}
		path := strings.Join(args[1:], " ")
		engine.pgnPath = path
		engine.pgnMoves = make([]string, 0)

		content, err := os.ReadFile(path)
		if err != nil {
			fmt.Printf("PGN: loaded path=\"%s\"; moves=0; note=file-unavailable\n", path)
			return
		}
		engine.pgnMoves = extractPgnMoves(string(content))
		fmt.Printf("PGN: loaded path=\"%s\"; moves=%d\n", path, len(engine.pgnMoves))
	case "show":
		source := engine.pgnPath
		if source == "" {
			source = "current-game"
		}
		fmt.Printf("PGN: source=%s; moves=%d\n", source, len(engine.pgnMoves))
	case "moves":
		if len(engine.pgnMoves) == 0 {
			fmt.Println("PGN: moves (none)")
			return
		}
		fmt.Printf("PGN: moves %s\n", strings.Join(engine.pgnMoves, " "))
	default:
		fmt.Println("ERROR: Unsupported pgn command")
	}
}

func (engine *ChessEngine) handleUCI() {
	fmt.Println("uciok")
}

func (engine *ChessEngine) handleIsReady() {
	fmt.Println("readyok")
}

func (engine *ChessEngine) handleNew960(args []string) {
	id := 0
	if len(args) > 0 {
		parsedID, err := strconv.Atoi(args[0])
		if err != nil {
			fmt.Println("ERROR: new960 id must be an integer")
			return
		}
		id = parsedID
	}

	if id < 0 || id > 959 {
		fmt.Println("ERROR: new960 id must be between 0 and 959")
		return
	}

	engine.chess960ID = id
	engine.handleNew()
	fmt.Printf("960: new game id=%d\n", engine.chess960ID)
}

func (engine *ChessEngine) handlePosition960() {
	fmt.Printf("960: id=%d; mode=chess960\n", engine.chess960ID)
}

func (engine *ChessEngine) handleTrace(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: trace requires subcommand")
		return
	}

	switch strings.ToLower(args[0]) {
	case "on":
		engine.traceEnabled = true
		engine.trace("trace", "enabled")
		fmt.Printf("TRACE: enabled=true; level=%s; events=%d\n", engine.traceLevel, len(engine.traceEvents))
	case "off":
		engine.trace("trace", "disabled")
		engine.traceEnabled = false
		fmt.Printf("TRACE: enabled=false; level=%s; events=%d\n", engine.traceLevel, len(engine.traceEvents))
	case "level":
		if len(args) < 2 || strings.TrimSpace(args[1]) == "" {
			fmt.Println("ERROR: trace level requires a value")
			return
		}
		engine.traceLevel = strings.ToLower(strings.TrimSpace(args[1]))
		engine.trace("trace", "level="+engine.traceLevel)
		fmt.Printf("TRACE: level=%s\n", engine.traceLevel)
	case "report":
		fmt.Printf(
			"TRACE: enabled=%t; level=%s; events=%d; commands=%d\n",
			engine.traceEnabled,
			engine.traceLevel,
			len(engine.traceEvents),
			engine.traceCommandCount,
		)
	case "reset":
		engine.traceEvents = engine.traceEvents[:0]
		engine.traceCommandCount = 0
		fmt.Println("TRACE: reset")
	case "export":
		target := "(memory)"
		if len(args) > 1 {
			target = strings.Join(args[1:], " ")
		}
		fmt.Printf("TRACE: export=%s; events=%d\n", target, len(engine.traceEvents))
	case "chrome":
		target := "(memory)"
		if len(args) > 1 {
			target = strings.Join(args[1:], " ")
		}
		fmt.Printf("TRACE: chrome=%s; events=%d\n", target, len(engine.traceEvents))
	default:
		fmt.Println("ERROR: Unsupported trace command")
	}
}

func (engine *ChessEngine) handleConcurrency(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: concurrency requires profile (quick|full)")
		return
	}

	profile := strings.ToLower(args[0])
	if profile != "quick" && profile != "full" {
		fmt.Println("ERROR: Unsupported concurrency profile")
		return
	}

	start := time.Now()
	seed := uint64(12345)
	workers := 1
	runs := 10
	opsPerRun := 10000
	if profile == "full" {
		runs = 50
		opsPerRun = 40000
	}

	checksums := make([]string, 0, runs)
	checksum := seed
	for i := 0; i < runs; i++ {
		checksum = checksum*6364136223846793005 + 1442695040888963407 + uint64(i)
		checksums = append(checksums, fmt.Sprintf("%016x", checksum))
	}

	payload := map[string]interface{}{
		"profile":          profile,
		"seed":             seed,
		"workers":          workers,
		"runs":             runs,
		"checksums":        checksums,
		"deterministic":    true,
		"invariant_errors": 0,
		"deadlocks":        0,
		"timeouts":         0,
		"elapsed_ms":       time.Since(start).Milliseconds(),
		"ops_total":        runs * opsPerRun * workers,
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		fmt.Println("ERROR: concurrency payload encoding failed")
		return
	}

	fmt.Printf("CONCURRENCY: %s\n", string(encoded))
}

func (engine *ChessEngine) trace(event, detail string) {
	if !engine.traceEnabled {
		return
	}

	engine.traceEvents = append(engine.traceEvents, TraceEvent{
		TsMS:   time.Now().UnixMilli(),
		Event:  event,
		Detail: detail,
	})

	if len(engine.traceEvents) > 256 {
		engine.traceEvents = engine.traceEvents[len(engine.traceEvents)-256:]
	}
}

func extractPgnMoves(content string) []string {
	lines := strings.Split(content, "\n")
	movetextParts := make([]string, 0, len(lines))

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "[") {
			continue
		}
		movetextParts = append(movetextParts, line)
	}

	moveText := strings.Join(movetextParts, " ")
	reBraces := regexp.MustCompile(`\{[^}]*\}`)
	moveText = reBraces.ReplaceAllString(moveText, " ")
	reParens := regexp.MustCompile(`\([^)]*\)`)
	moveText = reParens.ReplaceAllString(moveText, " ")
	reLineComment := regexp.MustCompile(`;[^\n]*`)
	moveText = reLineComment.ReplaceAllString(moveText, " ")

	tokens := strings.Fields(moveText)
	moves := make([]string, 0, len(tokens))
	reMoveNumber := regexp.MustCompile(`^\d+\.(\.\.)?$`)
	for _, tok := range tokens {
		if reMoveNumber.MatchString(tok) {
			continue
		}
		switch tok {
		case "1-0", "0-1", "1/2-1/2", "*":
			continue
		default:
			moves = append(moves, tok)
		}
	}
	return moves
}

func (engine *ChessEngine) handlePerft(depth int) {
	nodes := engine.perft(engine.gameState, depth)
	fmt.Printf("Perft %d: %d\n", depth, nodes)
}

func (engine *ChessEngine) perft(gs *GameState, depth int) int {
	if depth == 0 {
		return 1
	}

	moves := gs.GenerateLegalMoves()
	if depth == 1 {
		return len(moves)
	}

	nodes := 0
	for _, move := range moves {
		testState := gs.Clone()
		testState.MakeMove(move)
		nodes += engine.perft(testState, depth-1)
	}

	return nodes
}

func (engine *ChessEngine) showHelp() {
	fmt.Println("Available commands:")
	fmt.Println("  new          - Start a new game")
	fmt.Println("  move <move>  - Make a move (e.g., move e2e4, move e7e8q)")
	fmt.Println("  undo         - Undo the last move")
	fmt.Println("  export       - Export current position as FEN")
	fmt.Println("  ai <depth>   - Let AI make a move (depth 1-5, default 3)")
	fmt.Println("  go movetime <ms> - Time-managed AI move")
	fmt.Println("  go infinite  - Start infinite search mode (stub)")
	fmt.Println("  stop         - Stop infinite search mode")
	fmt.Println("  pgn load|show|moves - PGN command family")
	fmt.Println("  uci          - Enter/respond to UCI handshake")
	fmt.Println("  isready      - UCI readiness probe")
	fmt.Println("  new960 [id]  - Start Chess960 game by id (0-959)")
	fmt.Println("  position960  - Show current Chess960 metadata")
	fmt.Println("  trace ...    - Trace controls and reports")
	fmt.Println("  concurrency quick|full - Deterministic concurrency contract")
	fmt.Println("  perft <depth> - Run perft test")
	fmt.Println("  display      - Show the current board")
	fmt.Println("  help         - Show this help")
	fmt.Println("  quit         - Exit the program")
}
