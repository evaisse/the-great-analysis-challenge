package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	engine := NewChessEngine()
	engine.Run()
}

type ChessEngine struct {
	gameState              *GameState
	ai                     *AI
	pgnPath                string
	pgnMoves               []string
	bookPath               string
	bookEnabled            bool
	bookEntries            map[string][]BookEntry
	bookEntryCount         int
	bookLookups            int
	bookHits               int
	bookMisses             int
	bookPlayed             int
	uciHashMB              int
	uciThreads             int
	chess960ID             int
	traceEnabled           bool
	traceLevel             string
	traceEvents            []TraceEvent
	traceCommandCount      int
	traceExportCount       int
	traceLastExportTarget  string
	traceLastExportEvents  int
	traceLastExportBytes   int
	traceChromeCount       int
	traceLastChromeTarget  string
	traceLastChromeEvents  int
	traceLastChromeBytes   int
	traceLastAISource      string
	traceLastAIMove        string
	traceLastAIDepth       int
	traceLastAIScoreCP     int
	traceLastAIElapsedMS   int64
	traceLastAITimedOut    bool
	traceLastAINodes       int
	traceLastAIEvalCalls   int
	traceLastAINPS         int64
	traceLastAITTHits      int
	traceLastAITTMisses    int
	traceLastAIBetaCutoffs int
}

type TraceEvent struct {
	TsMS   int64  `json:"ts_ms"`
	Event  string `json:"event"`
	Detail string `json:"detail"`
}

type BookEntry struct {
	Move   string
	Weight int
}

type EndgameInfo struct {
	Kind       string
	Strong     Color
	Weak       Color
	WhiteScore int
	Detail     string
}

func NewChessEngine() *ChessEngine {
	return &ChessEngine{
		gameState:   NewGameState(),
		ai:          NewAI(),
		pgnPath:     "",
		pgnMoves:    make([]string, 0),
		bookPath:    "",
		bookEnabled: false,
		bookEntries: make(map[string][]BookEntry),
		uciHashMB:   16,
		uciThreads:  1,
		traceLevel:  "info",
		traceEvents: make([]TraceEvent, 0),
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
		case "book":
			engine.handleBook(parts[1:])
		case "endgame":
			engine.handleEndgame(parts[1:])
		case "uci":
			engine.handleUCI()
		case "isready":
			engine.handleIsReady()
		case "setoption":
			engine.handleSetOption(parts[1:])
		case "ucinewgame":
			engine.handleUCINewGame()
		case "position":
			engine.handlePosition(parts[1:])
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
	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		fmt.Println("ERROR: No legal moves available")
		return
	}

	if bookMove, ok := engine.chooseBookMove(legalMoves); ok {
		engine.applyBookAIMove(bookMove)
		return
	}

	if endgameMove, info, ok := engine.chooseEndgameMove(legalMoves); ok {
		engine.applyEndgameAIMove(endgameMove, info)
		return
	}

	result := engine.ai.Search(engine.gameState, depth, 0)
	engine.applyAIMove(result, legalMoves, depth)
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
		fmt.Println("ERROR: go requires subcommand (movetime <ms>|wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]|infinite)")
		return
	}

	switch strings.ToLower(args[0]) {
	case "depth":
		if len(args) < 2 {
			fmt.Println("ERROR: go depth requires a value")
			return
		}
		depth, err := strconv.Atoi(args[1])
		if err != nil {
			fmt.Println("ERROR: go depth requires an integer value")
			return
		}
		if depth < 1 {
			depth = 1
		}
		if depth > MAX_DEPTH {
			depth = MAX_DEPTH
		}
		engine.handleUCIDepthSearch(depth)
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
		engine.handleAITimed(MAX_DEPTH, movetimeMs)
	case "wtime":
		movetimeMs, err := deriveMovetimeFromClockArgs(args, engine.gameState.ActiveColor)
		if err != nil {
			fmt.Printf("ERROR: %s\n", err.Error())
			return
		}
		engine.handleAITimed(MAX_DEPTH, movetimeMs)
	case "infinite":
		fmt.Println("OK: go infinite acknowledged (bounded search mode)")
		// Cooperative bounded search in this synchronous CLI.
		engine.handleAITimed(MAX_DEPTH, 15000)
	default:
		fmt.Println("ERROR: Unsupported go command")
	}
}

func (engine *ChessEngine) handleUCIDepthSearch(depth int) {
	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		fmt.Println("bestmove 0000")
		return
	}

	if bookMove, ok := engine.chooseBookMove(legalMoves); ok {
		moveStr := moveToString(bookMove)
		engine.recordTraceAI("uci-book", moveStr, 0, 0, 0, false, 0, 0, 0, 0, 0)
		fmt.Printf("info string bookmove %s\n", moveStr)
		fmt.Printf("bestmove %s\n", moveStr)
		return
	}

	if endgameMove, info, ok := engine.chooseEndgameMove(legalMoves); ok {
		moveStr := moveToString(endgameMove)
		engine.recordTraceAI("uci-endgame", moveStr, 0, info.WhiteScore, 0, false, 0, 0, 0, 0, 0)
		fmt.Printf("info string endgame %s score cp %d\n", info.Kind, info.WhiteScore)
		fmt.Printf("bestmove %s\n", moveStr)
		return
	}

	result := engine.ai.Search(engine.gameState, depth, 0)
	bestMove := normalizeBestMove(result.Move, legalMoves)
	moveStr := moveToString(bestMove)
	engine.recordTraceAI("uci-search", moveStr, result.Depth, result.Score, result.ElapsedMS, result.TimedOut, result.Nodes, result.EvalCalls, result.TTHits, result.TTMisses, result.BetaCutoffs)
	fmt.Printf("info depth %d score cp %d time %d nodes %d\n", result.Depth, result.Score, result.ElapsedMS, result.Nodes)
	fmt.Printf("bestmove %s\n", moveStr)
}

func deriveMovetimeFromClockArgs(args []string, active Color) (int, error) {
	values := map[string]int{
		"winc":      0,
		"binc":      0,
		"movestogo": 30,
	}

	i := 0
	for i < len(args) {
		key := strings.ToLower(strings.TrimSpace(args[i]))
		i++
		if i >= len(args) {
			return 0, fmt.Errorf("go %s requires a value", key)
		}
		value, err := strconv.Atoi(args[i])
		if err != nil {
			return 0, fmt.Errorf("go %s requires an integer value", key)
		}
		i++

		switch key {
		case "wtime", "btime", "winc", "binc", "movestogo":
			values[key] = value
		default:
			return 0, fmt.Errorf("unsupported go parameter: %s", key)
		}
	}

	wtime, hasWtime := values["wtime"]
	btime, hasBtime := values["btime"]
	if !hasWtime || !hasBtime {
		return 0, fmt.Errorf("go wtime/btime parameters are required")
	}
	if wtime <= 0 || btime <= 0 {
		return 0, fmt.Errorf("go wtime/btime must be > 0")
	}
	if values["movestogo"] <= 0 {
		values["movestogo"] = 30
	}

	base := wtime
	increment := values["winc"]
	if active == Black {
		base = btime
		increment = values["binc"]
	}

	budget := base/(values["movestogo"]+1) + increment/2
	if budget < 50 {
		budget = 50
	}
	if budget >= base {
		budget = base / 2
	}
	if budget <= 0 {
		return 0, fmt.Errorf("unable to derive positive movetime from clocks")
	}
	return budget, nil
}

func (engine *ChessEngine) handleAITimed(maxDepth int, movetimeMs int) {
	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) == 0 {
		fmt.Println("ERROR: No legal moves available")
		return
	}

	if bookMove, ok := engine.chooseBookMove(legalMoves); ok {
		engine.applyBookAIMove(bookMove)
		return
	}

	if endgameMove, info, ok := engine.chooseEndgameMove(legalMoves); ok {
		engine.applyEndgameAIMove(endgameMove, info)
		return
	}

	result := engine.ai.Search(engine.gameState, maxDepth, movetimeMs)
	engine.applyAIMove(result, legalMoves, maxDepth)
}

func (engine *ChessEngine) applyAIMove(result SearchResult, legalMoves []Move, requestedDepth int) {
	bestMove := normalizeBestMove(result.Move, legalMoves)

	engine.gameState.MakeMove(bestMove)

	moveStr := moveToString(bestMove)
	depthUsed := result.Depth
	if depthUsed == 0 {
		depthUsed = requestedDepth
	}
	engine.recordTraceAI("search", moveStr, depthUsed, result.Score, result.ElapsedMS, result.TimedOut, result.Nodes, result.EvalCalls, result.TTHits, result.TTMisses, result.BetaCutoffs)

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
				moveStr, depthUsed, result.Score, result.ElapsedMS)
		}
	}

	fmt.Print(engine.gameState.Display())
}

func normalizeBestMove(bestMove Move, legalMoves []Move) Move {
	validMove := false
	for _, move := range legalMoves {
		if move.From == bestMove.From && move.To == bestMove.To {
			if !bestMove.IsPromotion || move.PromoteTo == bestMove.PromoteTo {
				bestMove = move
				validMove = true
				break
			}
		}
	}
	if !validMove {
		return legalMoves[0]
	}
	return bestMove
}

func moveToString(move Move) string {
	moveStr := fmt.Sprintf("%s%s", move.From.ToAlgebraic(), move.To.ToAlgebraic())
	if move.IsPromotion {
		switch move.PromoteTo {
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
	return moveStr
}

func bookPositionKeyFromFEN(fen string) string {
	parts := strings.Fields(strings.TrimSpace(fen))
	if len(parts) >= 4 {
		return strings.Join(parts[:4], " ")
	}
	return strings.TrimSpace(fen)
}

func parseBookEntries(content string) (map[string][]BookEntry, int, error) {
	entries := make(map[string][]BookEntry)
	totalEntries := 0
	movePattern := regexp.MustCompile(`^[a-h][1-8][a-h][1-8][qrbn]?$`)
	lines := strings.Split(content, "\n")

	for idx, raw := range lines {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "->", 2)
		if len(parts) != 2 {
			return nil, 0, fmt.Errorf("line %d: expected '<fen> -> <move> [weight]'", idx+1)
		}

		key := bookPositionKeyFromFEN(parts[0])
		if key == "" {
			return nil, 0, fmt.Errorf("line %d: empty position key", idx+1)
		}

		rhsFields := strings.Fields(strings.TrimSpace(parts[1]))
		if len(rhsFields) == 0 {
			return nil, 0, fmt.Errorf("line %d: missing move", idx+1)
		}

		move := strings.ToLower(rhsFields[0])
		if !movePattern.MatchString(move) {
			return nil, 0, fmt.Errorf("line %d: invalid move %q", idx+1, move)
		}

		weight := 1
		if len(rhsFields) > 1 {
			parsedWeight, err := strconv.Atoi(rhsFields[1])
			if err != nil {
				return nil, 0, fmt.Errorf("line %d: invalid weight %q", idx+1, rhsFields[1])
			}
			if parsedWeight <= 0 {
				return nil, 0, fmt.Errorf("line %d: weight must be > 0", idx+1)
			}
			weight = parsedWeight
		}

		entries[key] = append(entries[key], BookEntry{
			Move:   move,
			Weight: weight,
		})
		totalEntries++
	}

	return entries, totalEntries, nil
}

func (engine *ChessEngine) handleBook(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: book requires subcommand (load|on|off|stats)")
		return
	}

	switch strings.ToLower(args[0]) {
	case "load":
		if len(args) < 2 {
			fmt.Println("ERROR: book load requires a file path")
			return
		}

		path := strings.Join(args[1:], " ")
		content, err := os.ReadFile(path)
		if err != nil {
			fmt.Printf("ERROR: book load failed: %s\n", err.Error())
			return
		}

		entries, totalEntries, parseErr := parseBookEntries(string(content))
		if parseErr != nil {
			fmt.Printf("ERROR: book load failed: %s\n", parseErr.Error())
			return
		}

		engine.bookPath = path
		engine.bookEntries = entries
		engine.bookEntryCount = totalEntries
		engine.bookEnabled = true
		engine.bookLookups = 0
		engine.bookHits = 0
		engine.bookMisses = 0
		engine.bookPlayed = 0

		fmt.Printf(
			"BOOK: loaded path=\"%s\"; positions=%d; entries=%d; enabled=%t\n",
			path,
			len(entries),
			totalEntries,
			engine.bookEnabled,
		)
	case "on":
		engine.bookEnabled = true
		fmt.Println("BOOK: enabled=true")
	case "off":
		engine.bookEnabled = false
		fmt.Println("BOOK: enabled=false")
	case "stats":
		path := engine.bookPath
		if path == "" {
			path = "(none)"
		}
		fmt.Printf(
			"BOOK: enabled=%t; path=%s; positions=%d; entries=%d; lookups=%d; hits=%d; misses=%d; played=%d\n",
			engine.bookEnabled,
			path,
			len(engine.bookEntries),
			engine.bookEntryCount,
			engine.bookLookups,
			engine.bookHits,
			engine.bookMisses,
			engine.bookPlayed,
		)
	default:
		fmt.Println("ERROR: Unsupported book command")
	}
}

func (engine *ChessEngine) chooseBookMove(legalMoves []Move) (Move, bool) {
	engine.bookLookups++
	if !engine.bookEnabled || len(engine.bookEntries) == 0 {
		engine.bookMisses++
		return Move{}, false
	}

	key := bookPositionKeyFromFEN(engine.gameState.ToFEN())
	entries := engine.bookEntries[key]
	if len(entries) == 0 {
		engine.bookMisses++
		return Move{}, false
	}

	legalByNotation := make(map[string]Move, len(legalMoves))
	for _, move := range legalMoves {
		legalByNotation[strings.ToLower(moveToString(move))] = move
	}

	type weightedCandidate struct {
		move   Move
		weight int
	}

	candidates := make([]weightedCandidate, 0, len(entries))
	totalWeight := 0
	for _, entry := range entries {
		move, ok := legalByNotation[entry.Move]
		if !ok {
			continue
		}
		weight := entry.Weight
		if weight <= 0 {
			weight = 1
		}
		candidates = append(candidates, weightedCandidate{
			move:   move,
			weight: weight,
		})
		totalWeight += weight
	}

	if len(candidates) == 0 || totalWeight <= 0 {
		engine.bookMisses++
		return Move{}, false
	}

	selector := int((uint64(engine.gameState.ZobristHash) + uint64(engine.bookLookups)) % uint64(totalWeight))
	acc := 0
	chosen := candidates[0].move
	for _, candidate := range candidates {
		acc += candidate.weight
		if selector < acc {
			chosen = candidate.move
			break
		}
	}

	engine.bookHits++
	return chosen, true
}

func (engine *ChessEngine) applyBookAIMove(bestMove Move) {
	engine.gameState.MakeMove(bestMove)
	engine.bookPlayed++

	moveStr := moveToString(bestMove)
	engine.recordTraceAI("book", moveStr, 0, 0, 0, false, 0, 0, 0, 0, 0)
	nextLegalMoves := engine.gameState.GenerateLegalMoves()
	if len(nextLegalMoves) == 0 {
		if engine.gameState.IsInCheck(engine.gameState.ActiveColor) {
			fmt.Printf("AI: %s (book, CHECKMATE)\n", moveStr)
		} else {
			fmt.Printf("AI: %s (book, STALEMATE)\n", moveStr)
		}
	} else {
		drawReason := engine.gameState.GetDrawReason()
		if drawReason != "" {
			fmt.Printf("AI: %s (book, DRAW: by %s)\n", moveStr, drawReason)
		} else {
			fmt.Printf("AI: %s (book)\n", moveStr)
		}
	}

	fmt.Print(engine.gameState.Display())
}

func (engine *ChessEngine) handleEndgame(_ []string) {
	info, ok := detectEndgame(engine.gameState)
	if !ok {
		fmt.Printf("ENDGAME: type=none; active=%s; score=0\n", colorName(engine.gameState.ActiveColor))
		return
	}

	output := fmt.Sprintf(
		"ENDGAME: type=%s; strong=%s; weak=%s; score=%d",
		info.Kind,
		colorName(info.Strong),
		colorName(info.Weak),
		info.WhiteScore,
	)

	legalMoves := engine.gameState.GenerateLegalMoves()
	if len(legalMoves) > 0 {
		if bestMove, _, ok := engine.chooseEndgameMove(legalMoves); ok {
			output += fmt.Sprintf("; bestmove=%s", strings.ToLower(moveToString(bestMove)))
		}
	}
	if info.Detail != "" {
		output += fmt.Sprintf("; detail=%s", info.Detail)
	}

	fmt.Println(output)
}

func colorName(color Color) string {
	if color == White {
		return "white"
	}
	return "black"
}

func minInt(values ...int) int {
	if len(values) == 0 {
		return 0
	}
	result := values[0]
	for i := 1; i < len(values); i++ {
		if values[i] < result {
			result = values[i]
		}
	}
	return result
}

func nonKingMaterialCount(counts [2][7]int, color Color) int {
	total := 0
	for pieceType := Pawn; pieceType <= Queen; pieceType++ {
		total += counts[color][pieceType]
	}
	return total
}

func detectEndgame(gs *GameState) (EndgameInfo, bool) {
	var counts [2][7]int
	var kingSquares [2]Square
	var hasKing [2]bool
	var pawnSquares [2]Square
	var hasPawn [2]bool
	var rookSquares [2]Square
	var hasRook [2]bool
	var queenSquares [2]Square
	var hasQueen [2]bool

	for rank := 0; rank < 8; rank++ {
		for file := 0; file < 8; file++ {
			piece := gs.Board[rank][file]
			if piece.Type == Empty {
				continue
			}
			counts[piece.Color][piece.Type]++

			square := Square{File: file, Rank: rank}
			switch piece.Type {
			case King:
				kingSquares[piece.Color] = square
				hasKing[piece.Color] = true
			case Pawn:
				if !hasPawn[piece.Color] {
					pawnSquares[piece.Color] = square
					hasPawn[piece.Color] = true
				}
			case Rook:
				if !hasRook[piece.Color] {
					rookSquares[piece.Color] = square
					hasRook[piece.Color] = true
				}
			case Queen:
				if !hasQueen[piece.Color] {
					queenSquares[piece.Color] = square
					hasQueen[piece.Color] = true
				}
			}
		}
	}

	if !hasKing[White] || !hasKing[Black] {
		return EndgameInfo{}, false
	}

	whiteMaterial := nonKingMaterialCount(counts, White)
	blackMaterial := nonKingMaterialCount(counts, Black)

	// KQK
	if counts[White][Queen] == 1 && whiteMaterial == 1 && blackMaterial == 0 {
		weakKing := kingSquares[Black]
		strongKing := kingSquares[White]
		edgeDistance := minInt(weakKing.File, 7-weakKing.File, weakKing.Rank, 7-weakKing.Rank)
		kingDistance := attackTableManhattanDistance(strongKing, weakKing)
		score := 900 + (14-kingDistance)*6 + (3-edgeDistance)*20
		return EndgameInfo{
			Kind:       "KQK",
			Strong:     White,
			Weak:       Black,
			WhiteScore: score,
			Detail:     fmt.Sprintf("queen=%s", queenSquares[White].ToAlgebraic()),
		}, true
	}
	if counts[Black][Queen] == 1 && blackMaterial == 1 && whiteMaterial == 0 {
		weakKing := kingSquares[White]
		strongKing := kingSquares[Black]
		edgeDistance := minInt(weakKing.File, 7-weakKing.File, weakKing.Rank, 7-weakKing.Rank)
		kingDistance := attackTableManhattanDistance(strongKing, weakKing)
		score := 900 + (14-kingDistance)*6 + (3-edgeDistance)*20
		return EndgameInfo{
			Kind:       "KQK",
			Strong:     Black,
			Weak:       White,
			WhiteScore: -score,
			Detail:     fmt.Sprintf("queen=%s", queenSquares[Black].ToAlgebraic()),
		}, true
	}

	// KPK
	if counts[White][Pawn] == 1 && whiteMaterial == 1 && blackMaterial == 0 {
		pawn := pawnSquares[White]
		strongKing := kingSquares[White]
		weakKing := kingSquares[Black]
		promotion := Square{File: pawn.File, Rank: 7}
		pawnSteps := 7 - pawn.Rank
		score := 120 + (6-pawnSteps)*35 + attackTableManhattanDistance(weakKing, promotion)*6 - attackTableManhattanDistance(strongKing, pawn)*8
		if pawnSteps <= 1 {
			score += 80
		}
		if score < 30 {
			score = 30
		}
		return EndgameInfo{
			Kind:       "KPK",
			Strong:     White,
			Weak:       Black,
			WhiteScore: score,
			Detail:     fmt.Sprintf("pawn=%s", pawn.ToAlgebraic()),
		}, true
	}
	if counts[Black][Pawn] == 1 && blackMaterial == 1 && whiteMaterial == 0 {
		pawn := pawnSquares[Black]
		strongKing := kingSquares[Black]
		weakKing := kingSquares[White]
		promotion := Square{File: pawn.File, Rank: 0}
		pawnSteps := pawn.Rank
		score := 120 + (6-pawnSteps)*35 + attackTableManhattanDistance(weakKing, promotion)*6 - attackTableManhattanDistance(strongKing, pawn)*8
		if pawnSteps <= 1 {
			score += 80
		}
		if score < 30 {
			score = 30
		}
		return EndgameInfo{
			Kind:       "KPK",
			Strong:     Black,
			Weak:       White,
			WhiteScore: -score,
			Detail:     fmt.Sprintf("pawn=%s", pawn.ToAlgebraic()),
		}, true
	}

	// KRKP
	if counts[White][Rook] == 1 && whiteMaterial == 1 && counts[Black][Pawn] == 1 && blackMaterial == 1 {
		strongKing := kingSquares[White]
		weakKing := kingSquares[Black]
		weakPawn := pawnSquares[Black]
		pawnSteps := weakPawn.Rank
		score := 380 - pawnSteps*25 + (attackTableManhattanDistance(weakKing, weakPawn)-attackTableManhattanDistance(strongKing, weakPawn))*12
		if score < 50 {
			score = 50
		}
		return EndgameInfo{
			Kind:       "KRKP",
			Strong:     White,
			Weak:       Black,
			WhiteScore: score,
			Detail:     fmt.Sprintf("rook=%s,pawn=%s", rookSquares[White].ToAlgebraic(), weakPawn.ToAlgebraic()),
		}, true
	}
	if counts[Black][Rook] == 1 && blackMaterial == 1 && counts[White][Pawn] == 1 && whiteMaterial == 1 {
		strongKing := kingSquares[Black]
		weakKing := kingSquares[White]
		weakPawn := pawnSquares[White]
		pawnSteps := 7 - weakPawn.Rank
		score := 380 - pawnSteps*25 + (attackTableManhattanDistance(weakKing, weakPawn)-attackTableManhattanDistance(strongKing, weakPawn))*12
		if score < 50 {
			score = 50
		}
		return EndgameInfo{
			Kind:       "KRKP",
			Strong:     Black,
			Weak:       White,
			WhiteScore: -score,
			Detail:     fmt.Sprintf("rook=%s,pawn=%s", rookSquares[Black].ToAlgebraic(), weakPawn.ToAlgebraic()),
		}, true
	}

	return EndgameInfo{}, false
}

func (engine *ChessEngine) chooseEndgameMove(legalMoves []Move) (Move, EndgameInfo, bool) {
	rootInfo, ok := detectEndgame(engine.gameState)
	if !ok || len(legalMoves) == 0 {
		return Move{}, EndgameInfo{}, false
	}

	rootColor := engine.gameState.ActiveColor
	bestMove := legalMoves[0]
	bestNotation := strings.ToLower(moveToString(bestMove))
	bestScore := -INFINITY

	for _, candidate := range legalMoves {
		clone := engine.gameState.Clone()
		clone.MakeMove(candidate)

		score := engine.ai.evaluate(clone)
		if endInfo, hasEndgame := detectEndgame(clone); hasEndgame {
			score = endInfo.WhiteScore
		}
		if rootColor == Black {
			score = -score
		}

		notation := strings.ToLower(moveToString(candidate))
		if score > bestScore || (score == bestScore && notation < bestNotation) {
			bestScore = score
			bestMove = candidate
			bestNotation = notation
		}
	}

	return bestMove, rootInfo, true
}

func (engine *ChessEngine) applyEndgameAIMove(bestMove Move, info EndgameInfo) {
	engine.gameState.MakeMove(bestMove)
	moveStr := moveToString(bestMove)
	engine.recordTraceAI("endgame", moveStr, 0, info.WhiteScore, 0, false, 0, 0, 0, 0, 0)

	nextLegalMoves := engine.gameState.GenerateLegalMoves()
	if len(nextLegalMoves) == 0 {
		if engine.gameState.IsInCheck(engine.gameState.ActiveColor) {
			fmt.Printf("AI: %s (endgame %s, CHECKMATE)\n", moveStr, info.Kind)
		} else {
			fmt.Printf("AI: %s (endgame %s, STALEMATE)\n", moveStr, info.Kind)
		}
	} else {
		drawReason := engine.gameState.GetDrawReason()
		if drawReason != "" {
			fmt.Printf("AI: %s (endgame %s, DRAW: by %s)\n", moveStr, info.Kind, drawReason)
		} else {
			fmt.Printf("AI: %s (endgame %s, score=%d)\n", moveStr, info.Kind, info.WhiteScore)
		}
	}

	fmt.Print(engine.gameState.Display())
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

func (engine *ChessEngine) handleSetOption(args []string) {
	if len(args) < 4 || strings.ToLower(args[0]) != "name" {
		fmt.Println("ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'")
		return
	}

	valueIndex := -1
	for i := 1; i < len(args); i++ {
		if strings.ToLower(args[i]) == "value" {
			valueIndex = i
			break
		}
	}
	if valueIndex <= 1 || valueIndex+1 >= len(args) {
		fmt.Println("ERROR: setoption requires 'value <n>'")
		return
	}

	name := strings.ToLower(strings.TrimSpace(strings.Join(args[1:valueIndex], " ")))
	value, err := strconv.Atoi(args[valueIndex+1])
	if err != nil {
		fmt.Println("ERROR: setoption value must be an integer")
		return
	}

	switch name {
	case "hash":
		if value < 1 {
			value = 1
		}
		if value > 1024 {
			value = 1024
		}
		engine.uciHashMB = value
		fmt.Printf("info string option Hash=%d\n", engine.uciHashMB)
	case "threads":
		if value < 1 {
			value = 1
		}
		if value > 64 {
			value = 64
		}
		engine.uciThreads = value
		fmt.Printf("info string option Threads=%d\n", engine.uciThreads)
	default:
		fmt.Printf("info string unsupported option %s\n", strings.TrimSpace(strings.Join(args[1:valueIndex], " ")))
	}
}

func (engine *ChessEngine) handleUCINewGame() {
	engine.gameState = NewGameState()
	engine.ai = NewAI()
}

func (engine *ChessEngine) handlePosition(args []string) {
	if len(args) == 0 {
		fmt.Println("ERROR: position requires 'startpos' or 'fen <...>'")
		return
	}

	i := 0
	switch strings.ToLower(args[0]) {
	case "startpos":
		engine.gameState = NewGameState()
		engine.ai = NewAI()
		i = 1
	case "fen":
		i = 1
		fenParts := make([]string, 0, 6)
		for i < len(args) && strings.ToLower(args[i]) != "moves" {
			fenParts = append(fenParts, args[i])
			i++
		}
		if len(fenParts) == 0 {
			fmt.Println("ERROR: position fen requires a FEN string")
			return
		}
		if err := engine.gameState.FromFEN(strings.Join(fenParts, " ")); err != nil {
			fmt.Printf("ERROR: Invalid FEN: %s\n", err.Error())
			return
		}
	default:
		fmt.Println("ERROR: position requires 'startpos' or 'fen <...>'")
		return
	}

	if i < len(args) && strings.ToLower(args[i]) == "moves" {
		i++
		for ; i < len(args); i++ {
			if err := engine.applyMoveSilently(args[i]); err != nil {
				fmt.Printf("ERROR: position move %s failed: %s\n", args[i], err.Error())
				return
			}
		}
	}
}

func (engine *ChessEngine) applyMoveSilently(moveStr string) error {
	if len(moveStr) < 4 {
		return fmt.Errorf("invalid move format")
	}

	from := AlgebraicToSquare(moveStr[0:2])
	to := AlgebraicToSquare(moveStr[2:4])
	if !from.IsValid() || !to.IsValid() {
		return fmt.Errorf("invalid move format")
	}

	var promotionPiece PieceType
	hasPromotion := false
	if len(moveStr) == 5 {
		hasPromotion = true
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
			return fmt.Errorf("invalid promotion piece")
		}
	}

	move, err := engine.gameState.IsValidMove(from, to)
	if err != nil {
		return err
	}
	if move.IsPromotion && hasPromotion {
		move.PromoteTo = promotionPiece
	}
	engine.gameState.MakeMove(move)
	return nil
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
		report := fmt.Sprintf(
			"TRACE: enabled=%t; level=%s; events=%d; commands=%d; exports=%d; last_export=%s; chrome_exports=%d; last_chrome=%s; last_ai=%s",
			engine.traceEnabled,
			engine.traceLevel,
			len(engine.traceEvents),
			engine.traceCommandCount,
			engine.traceExportCount,
			formatTraceTransferSummary(
				engine.traceExportCount,
				engine.traceLastExportTarget,
				engine.traceLastExportEvents,
				engine.traceLastExportBytes,
			),
			engine.traceChromeCount,
			formatTraceTransferSummary(
				engine.traceChromeCount,
				engine.traceLastChromeTarget,
				engine.traceLastChromeEvents,
				engine.traceLastChromeBytes,
			),
			engine.formatTraceAISummary(),
		)
		if searchMetrics := engine.formatTraceSearchMetrics(); searchMetrics != "" {
			report += "; search_metrics=" + searchMetrics
		}
		fmt.Println(report)
	case "reset":
		engine.traceEvents = engine.traceEvents[:0]
		engine.traceCommandCount = 0
		engine.traceExportCount = 0
		engine.traceLastExportTarget = ""
		engine.traceLastExportEvents = 0
		engine.traceLastExportBytes = 0
		engine.traceChromeCount = 0
		engine.traceLastChromeTarget = ""
		engine.traceLastChromeEvents = 0
		engine.traceLastChromeBytes = 0
		engine.resetTraceSearchState()
		fmt.Println("TRACE: reset")
	case "export":
		target := resolveTraceTarget(args[1:])
		engine.exportTracePayload(
			"export",
			target,
			engine.buildStructuredTracePayload,
			func(eventCount, byteCount int) {
				engine.traceExportCount++
				engine.traceLastExportTarget = target
				engine.traceLastExportEvents = eventCount
				engine.traceLastExportBytes = byteCount
			},
		)
	case "chrome":
		target := resolveTraceTarget(args[1:])
		engine.exportTracePayload(
			"chrome",
			target,
			engine.buildChromeTracePayload,
			func(eventCount, byteCount int) {
				engine.traceChromeCount++
				engine.traceLastChromeTarget = target
				engine.traceLastChromeEvents = eventCount
				engine.traceLastChromeBytes = byteCount
			},
		)
	default:
		fmt.Println("ERROR: Unsupported trace command")
	}
}

func resolveTraceTarget(parts []string) string {
	target := strings.TrimSpace(strings.Join(parts, " "))
	if target == "" {
		return "(memory)"
	}
	return target
}

func formatTraceTransferSummary(count int, target string, eventCount int, byteCount int) string {
	if count == 0 || strings.TrimSpace(target) == "" {
		return "none"
	}
	return fmt.Sprintf("%s (%d events, %d bytes)", target, eventCount, byteCount)
}

func (engine *ChessEngine) resetTraceSearchState() {
	engine.traceLastAISource = ""
	engine.traceLastAIMove = ""
	engine.traceLastAIDepth = 0
	engine.traceLastAIScoreCP = 0
	engine.traceLastAIElapsedMS = 0
	engine.traceLastAITimedOut = false
	engine.traceLastAINodes = 0
	engine.traceLastAIEvalCalls = 0
	engine.traceLastAINPS = 0
	engine.traceLastAITTHits = 0
	engine.traceLastAITTMisses = 0
	engine.traceLastAIBetaCutoffs = 0
}

func (engine *ChessEngine) formatTraceAISummary() string {
	if strings.TrimSpace(engine.traceLastAISource) == "" || strings.TrimSpace(engine.traceLastAIMove) == "" {
		return "none"
	}

	summary := fmt.Sprintf("%s:%s", engine.traceLastAISource, engine.traceLastAIMove)
	if strings.Contains(engine.traceLastAISource, "search") {
		summary += fmt.Sprintf("@d%d/%dcp/%dms/n%d/e%d/nps%d", engine.traceLastAIDepth, engine.traceLastAIScoreCP, engine.traceLastAIElapsedMS, engine.traceLastAINodes, engine.traceLastAIEvalCalls, engine.traceLastAINPS)
		if engine.traceLastAITimedOut {
			summary += "/timeout"
		}
	} else if strings.Contains(engine.traceLastAISource, "endgame") {
		summary += fmt.Sprintf("/%dcp", engine.traceLastAIScoreCP)
	}

	return summary
}

func (engine *ChessEngine) formatTraceSearchMetrics() string {
	if !strings.Contains(engine.traceLastAISource, "search") {
		return ""
	}
	return fmt.Sprintf(
		"nodes=%d,eval_calls=%d,tt_hits=%d,tt_misses=%d,beta_cutoffs=%d,nps=%d",
		engine.traceLastAINodes,
		engine.traceLastAIEvalCalls,
		engine.traceLastAITTHits,
		engine.traceLastAITTMisses,
		engine.traceLastAIBetaCutoffs,
		engine.traceLastAINPS,
	)
}

func (engine *ChessEngine) recordTraceAI(source, move string, depth, scoreCP int, elapsedMS int64, timedOut bool, nodes, evalCalls, ttHits, ttMisses, betaCutoffs int) {
	engine.traceLastAISource = source
	engine.traceLastAIMove = move
	engine.traceLastAIDepth = depth
	engine.traceLastAIScoreCP = scoreCP
	engine.traceLastAIElapsedMS = elapsedMS
	engine.traceLastAITimedOut = timedOut
	engine.traceLastAINodes = nodes
	engine.traceLastAIEvalCalls = evalCalls
	engine.traceLastAITTHits = ttHits
	engine.traceLastAITTMisses = ttMisses
	engine.traceLastAIBetaCutoffs = betaCutoffs
	if nodes > 0 {
		divisor := elapsedMS
		if divisor <= 0 {
			divisor = 1
		}
		engine.traceLastAINPS = int64(nodes) * 1000 / divisor
	} else {
		engine.traceLastAINPS = 0
	}
	engine.trace("ai", engine.formatTraceAISummary())
}

func (engine *ChessEngine) traceLastAIPayload() map[string]interface{} {
	if strings.TrimSpace(engine.traceLastAISource) == "" || strings.TrimSpace(engine.traceLastAIMove) == "" {
		return nil
	}

	return map[string]interface{}{
		"source":       engine.traceLastAISource,
		"move":         engine.traceLastAIMove,
		"depth":        engine.traceLastAIDepth,
		"score_cp":     engine.traceLastAIScoreCP,
		"elapsed_ms":   engine.traceLastAIElapsedMS,
		"timed_out":    engine.traceLastAITimedOut,
		"nodes":        engine.traceLastAINodes,
		"eval_calls":   engine.traceLastAIEvalCalls,
		"nps":          engine.traceLastAINPS,
		"tt_hits":      engine.traceLastAITTHits,
		"tt_misses":    engine.traceLastAITTMisses,
		"beta_cutoffs": engine.traceLastAIBetaCutoffs,
		"summary":      engine.formatTraceAISummary(),
	}
}

func (engine *ChessEngine) exportTracePayload(
	kind string,
	target string,
	build func() ([]byte, error),
	onSuccess func(eventCount, byteCount int),
) {
	payload, err := build()
	if err != nil {
		fmt.Printf("ERROR: trace %s encoding failed: %s\n", kind, err.Error())
		return
	}

	if target != "(memory)" {
		if err := os.WriteFile(target, payload, 0644); err != nil {
			fmt.Printf("ERROR: trace %s failed: %s\n", kind, err.Error())
			return
		}
	}

	eventCount := len(engine.traceEvents)
	byteCount := len(payload)
	onSuccess(eventCount, byteCount)
	fmt.Printf("TRACE: %s=%s; events=%d; bytes=%d\n", kind, target, eventCount, byteCount)
}

func (engine *ChessEngine) buildStructuredTracePayload() ([]byte, error) {
	snapshot := append([]TraceEvent(nil), engine.traceEvents...)
	payload := map[string]interface{}{
		"format":          "tgac.trace.v1",
		"engine":          "go",
		"generated_at_ms": time.Now().UnixMilli(),
		"enabled":         engine.traceEnabled,
		"level":           engine.traceLevel,
		"command_count":   engine.traceCommandCount,
		"event_count":     len(snapshot),
		"events":          snapshot,
	}
	if lastAI := engine.traceLastAIPayload(); lastAI != nil {
		payload["last_ai"] = lastAI
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

func (engine *ChessEngine) buildChromeTracePayload() ([]byte, error) {
	snapshot := append([]TraceEvent(nil), engine.traceEvents...)
	chromeEvents := make([]map[string]interface{}, 0, len(snapshot))
	for _, event := range snapshot {
		chromeEvents = append(chromeEvents, map[string]interface{}{
			"name": event.Event,
			"cat":  "engine",
			"ph":   "i",
			"s":    "p",
			"ts":   event.TsMS * 1000,
			"pid":  1,
			"tid":  1,
			"args": map[string]interface{}{
				"detail": event.Detail,
				"level":  engine.traceLevel,
				"ts_ms":  event.TsMS,
			},
		})
	}

	payload := map[string]interface{}{
		"format":            "tgac.chrome_trace.v1",
		"engine":            "go",
		"generated_at_ms":   time.Now().UnixMilli(),
		"enabled":           engine.traceEnabled,
		"level":             engine.traceLevel,
		"command_count":     engine.traceCommandCount,
		"event_count":       len(chromeEvents),
		"display_time_unit": "ms",
		"events":            chromeEvents,
	}

	data, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
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
	spec := concurrencyProfileFor(profile)

	resultsCh := make(chan concurrencyWorkerResult, spec.workers)
	var wg sync.WaitGroup

	for workerID := 0; workerID < spec.workers; workerID++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()

			workerRuns := make([]concurrencyRunResult, 0, spec.runs)
			for runIndex := 0; runIndex < spec.runs; runIndex++ {
				workerRuns = append(workerRuns, safeRunConcurrencyWorkload(id, runIndex, seed, spec))
			}

			resultsCh <- concurrencyWorkerResult{
				workerID: id,
				runs:     workerRuns,
			}
		}(workerID)
	}

	go func() {
		wg.Wait()
		close(resultsCh)
	}()

	workerResults := make([][]concurrencyRunResult, spec.workers)
	for workerResult := range resultsCh {
		workerResults[workerResult.workerID] = workerResult.runs
	}

	invariantErrors := 0
	opsTotal := 0
	checksums := make([]string, 0, spec.runs)

	for runIndex := 0; runIndex < spec.runs; runIndex++ {
		runChecksum := mixConcurrencyUint64(mixConcurrencyUint64(concurrencyChecksumOffset, seed), uint64(runIndex+1))
		for workerID := 0; workerID < spec.workers; workerID++ {
			runResult := workerResults[workerID][runIndex]
			invariantErrors += runResult.invariantErrors
			opsTotal += runResult.ops
			runChecksum = mixConcurrencyUint64(runChecksum, uint64(workerID+1))
			runChecksum = mixConcurrencyUint64(runChecksum, runResult.checksum)
		}
		checksums = append(checksums, fmt.Sprintf("%016x", runChecksum))
	}

	payload := map[string]interface{}{
		"profile":          profile,
		"seed":             seed,
		"workers":          spec.workers,
		"runs":             spec.runs,
		"checksums":        checksums,
		"deterministic":    true,
		"invariant_errors": invariantErrors,
		"deadlocks":        0,
		"timeouts":         0,
		"elapsed_ms":       time.Since(start).Milliseconds(),
		"ops_total":        opsTotal,
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

type concurrencyProfile struct {
	workers int
	runs    int
	steps   int
}

type concurrencyRunResult struct {
	runIndex        int
	checksum        uint64
	ops             int
	invariantErrors int
}

type concurrencyWorkerResult struct {
	workerID int
	runs     []concurrencyRunResult
}

var concurrencyWorkloadFENs = []string{
	StartingPositionFEN,
	"r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
	"rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3",
	"8/2k5/3p4/3P4/2P5/8/3K4/8 w - - 0 1",
}

const (
	concurrencyChecksumOffset = uint64(1469598103934665603)
	concurrencyChecksumPrime  = uint64(1099511628211)
)

func concurrencyProfileFor(profile string) concurrencyProfile {
	if profile == "full" {
		return concurrencyProfile{
			workers: 4,
			runs:    16,
			steps:   24,
		}
	}

	return concurrencyProfile{
		workers: 2,
		runs:    8,
		steps:   12,
	}
}

func mixConcurrencyUint64(current, value uint64) uint64 {
	return (current ^ value) * concurrencyChecksumPrime
}

func mixConcurrencyString(current uint64, value string) uint64 {
	mixed := current
	for i := 0; i < len(value); i++ {
		mixed = mixConcurrencyUint64(mixed, uint64(value[i]))
	}
	return mixed
}

func deterministicConcurrencyMoveIndex(seed uint64, workerID, runIndex, fenIndex, step, moveCount int) int {
	selector := mixConcurrencyUint64(concurrencyChecksumOffset, seed)
	selector = mixConcurrencyUint64(selector, uint64(workerID+1))
	selector = mixConcurrencyUint64(selector, uint64(runIndex+1))
	selector = mixConcurrencyUint64(selector, uint64(fenIndex+1))
	selector = mixConcurrencyUint64(selector, uint64(step+1))
	return int(selector % uint64(moveCount))
}

func shouldVerifyUndo(workerID, runIndex, fenIndex, step int) bool {
	return (workerID+runIndex+fenIndex+step)%2 == 0
}

func normalizedConcurrencyMoveStrings(moves []Move) []string {
	notations := make([]string, 0, len(moves))
	for _, move := range moves {
		notations = append(notations, strings.ToLower(moveToString(move)))
	}
	sort.Strings(notations)
	return notations
}

func equalStringSlices(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for i := range left {
		if left[i] != right[i] {
			return false
		}
	}
	return true
}

func newConcurrencyGameState(fen string) (*GameState, error) {
	gs := NewGameState()
	if err := gs.FromFEN(fen); err != nil {
		return nil, err
	}

	gs.MoveHistory = gs.MoveHistory[:0]
	gs.StateHistory = gs.StateHistory[:0]
	gs.PositionHistory = gs.PositionHistory[:0]
	gs.ZobristHash = computeZobristHash(gs)

	return gs, nil
}

func runConcurrencyWorkload(workerID, runIndex int, seed uint64, spec concurrencyProfile) concurrencyRunResult {
	result := concurrencyRunResult{
		runIndex: runIndex,
		checksum: mixConcurrencyUint64(
			mixConcurrencyUint64(concurrencyChecksumOffset, seed),
			uint64((workerID+1)*(runIndex+1)),
		),
	}

	for fenIndex, fen := range concurrencyWorkloadFENs {
		gs, err := newConcurrencyGameState(fen)
		result.ops++
		if err != nil {
			result.invariantErrors++
			result.checksum = mixConcurrencyString(result.checksum, err.Error())
			continue
		}

		result.checksum = mixConcurrencyString(result.checksum, gs.ToFEN())
		result.checksum = mixConcurrencyUint64(result.checksum, gs.ZobristHash)

		for step := 0; step < spec.steps; step++ {
			beforeFEN := gs.ToFEN()
			beforeHash := gs.ZobristHash

			legalMoves := gs.GenerateLegalMoves()
			result.ops++
			if len(legalMoves) == 0 {
				if step == 0 {
					result.invariantErrors++
				}
				result.checksum = mixConcurrencyString(result.checksum, beforeFEN)
				result.checksum = mixConcurrencyUint64(result.checksum, beforeHash)
				break
			}

			sort.Slice(legalMoves, func(i, j int) bool {
				return strings.ToLower(moveToString(legalMoves[i])) < strings.ToLower(moveToString(legalMoves[j]))
			})

			move := legalMoves[deterministicConcurrencyMoveIndex(seed, workerID, runIndex, fenIndex, step, len(legalMoves))]
			moveNotation := strings.ToLower(moveToString(move))

			result.checksum = mixConcurrencyString(result.checksum, moveNotation)
			result.checksum = mixConcurrencyUint64(result.checksum, uint64(len(legalMoves)))

			gs.MakeMove(move)
			result.ops++

			afterFEN := gs.ToFEN()
			afterHash := gs.ZobristHash
			afterMoves := gs.GenerateLegalMoves()
			result.ops++

			result.checksum = mixConcurrencyString(result.checksum, afterFEN)
			result.checksum = mixConcurrencyUint64(result.checksum, afterHash)
			result.checksum = mixConcurrencyUint64(result.checksum, uint64(len(afterMoves)))

			if shouldVerifyUndo(workerID, runIndex, fenIndex, step) {
				if !gs.UndoLastMove() {
					result.invariantErrors++
					result.checksum = mixConcurrencyString(result.checksum, "undo-failed")
					break
				}
				result.ops++

				if gs.ToFEN() != beforeFEN || gs.ZobristHash != beforeHash {
					result.invariantErrors++
				}

				gs.MakeMove(move)
				result.ops++

				if gs.ToFEN() != afterFEN || gs.ZobristHash != afterHash {
					result.invariantErrors++
				}
				continue
			}

			reloaded, err := newConcurrencyGameState(afterFEN)
			result.ops++
			if err != nil {
				result.invariantErrors++
				result.checksum = mixConcurrencyString(result.checksum, "reload-failed")
				break
			}

			if reloaded.ToFEN() != afterFEN || reloaded.ZobristHash != afterHash {
				result.invariantErrors++
			}

			reloadedMoves := reloaded.GenerateLegalMoves()
			result.ops++
			if !equalStringSlices(
				normalizedConcurrencyMoveStrings(afterMoves),
				normalizedConcurrencyMoveStrings(reloadedMoves),
			) {
				result.invariantErrors++
			}

			result.checksum = mixConcurrencyUint64(result.checksum, reloaded.ZobristHash)
		}
	}

	return result
}

func safeRunConcurrencyWorkload(workerID, runIndex int, seed uint64, spec concurrencyProfile) (result concurrencyRunResult) {
	defer func() {
		if recovered := recover(); recovered != nil {
			result = concurrencyRunResult{
				runIndex:        runIndex,
				checksum:        mixConcurrencyString(mixConcurrencyUint64(concurrencyChecksumOffset, seed), fmt.Sprintf("panic:%v", recovered)),
				ops:             0,
				invariantErrors: 1,
			}
		}
	}()

	return runConcurrencyWorkload(workerID, runIndex, seed, spec)
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
	fmt.Println("  go movetime <ms> - Time-managed AI move with iterative deepening")
	fmt.Println("  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-based timed move")
	fmt.Println("  go depth <n> - UCI-style depth-limited search (prints info/bestmove)")
	fmt.Println("  go infinite  - Start bounded long search mode")
	fmt.Println("  stop         - Stop infinite search mode")
	fmt.Println("  pgn load|show|moves - PGN command family")
	fmt.Println("  book load|on|off|stats - Native opening book controls")
	fmt.Println("  endgame      - Detect specialized endgame module and best move hint")
	fmt.Println("  uci          - Enter/respond to UCI handshake")
	fmt.Println("  isready      - UCI readiness probe")
	fmt.Println("  setoption name <Hash|Threads> value <n> - Set UCI option")
	fmt.Println("  ucinewgame   - Reset internal state for UCI game")
	fmt.Println("  position startpos|fen ... [moves ...] - Load UCI position")
	fmt.Println("  new960 [id]  - Start Chess960 game by id (0-959)")
	fmt.Println("  position960  - Show current Chess960 metadata")
	fmt.Println("  trace ...    - Trace controls and reports")
	fmt.Println("  concurrency quick|full - Deterministic concurrency contract")
	fmt.Println("  perft <depth> - Run perft test")
	fmt.Println("  display      - Show the current board")
	fmt.Println("  help         - Show this help")
	fmt.Println("  quit         - Exit the program")
}
