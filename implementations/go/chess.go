package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	engine := NewChessEngine()
	engine.Run()
}

type ChessEngine struct {
	gameState *GameState
	ai        *AI
}

func NewChessEngine() *ChessEngine {
	return &ChessEngine{
		gameState: NewGameState(),
		ai:        NewAI(),
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
		case "status":
			engine.handleStatus()
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
	fmt.Print(engine.gameState.Display())
	fmt.Println("OK: new game started")
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
	fmt.Print(engine.gameState.Display())
	fmt.Printf("OK: %s\n", moveStr)

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
	}
}

func (engine *ChessEngine) handleUndo() {
	if engine.gameState.UndoLastMove() {
		fmt.Print(engine.gameState.Display())
		fmt.Println("OK: move undone")
	} else {
		fmt.Println("ERROR: No moves to undo")
	}
}

func (engine *ChessEngine) handleFEN(fen string) {
	err := engine.gameState.FromFEN(fen)
	if err != nil {
		fmt.Printf("ERROR: Invalid FEN: %s\n", err.Error())
	} else {
		fmt.Print(engine.gameState.Display())
		fmt.Println("OK: FEN loaded")
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
		fmt.Println("OK: ongoing")
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

	fmt.Printf("AI: %s (depth=%d, eval=%d, time=%dms)\n",
		moveStr, depth, score, elapsed.Milliseconds())

	fmt.Print(engine.gameState.Display())

	// Check for game end conditions
	legalMoves = engine.gameState.GenerateLegalMoves()
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
	}
}

func (engine *ChessEngine) handlePerft(depth int) {
	start := time.Now()
	nodes := engine.perft(engine.gameState, depth)
	elapsed := time.Since(start)

	fmt.Printf("Perft(%d): %d nodes in %dms\n", depth, nodes, elapsed.Milliseconds())
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
	fmt.Println("  perft <depth> - Run perft test")
	fmt.Println("  display      - Show the current board")
	fmt.Println("  help         - Show this help")
	fmt.Println("  quit         - Exit the program")
}
