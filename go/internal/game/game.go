package game

import (
	"fmt"
	"strings"
)

type Game struct {
	*Board
}

func NewGame() *Game {
	return &Game{
		Board: NewBoard(),
	}
}

func (g *Game) HandleCommand(cmd string) {
	parts := strings.Split(cmd, " ")
	switch parts[0] {
	case "new":
		g.Board = NewBoard()
		fmt.Println(g.Board)
	case "fen":
		if len(parts) > 1 {
			fen := strings.Join(parts[1:], " ")
			g.Board.LoadFen(fen)
			fmt.Println(g.Board)
		} else {
			fmt.Println("ERROR: Invalid FEN string")
		}
	case "export":
		// Not implemented yet
		fmt.Println("FEN: not implemented")
	case "move":
		// Not implemented yet
		fmt.Println("OK: move not implemented")
	case "undo":
		// Not implemented yet
		fmt.Println("OK: undo not implemented")
	case "ai":
		// Not implemented yet
		fmt.Println("AI: not implemented")
	case "eval":
		// Not implemented yet
		fmt.Println("eval: not implemented")
	case "perft":
		// Not implemented yet
		fmt.Println("perft: not implemented")
	case "help":
		fmt.Println("Available commands: new, fen, export, move, undo, ai, eval, perft, help, quit")
	case "quit":
		// Should be handled in main
	default:
		fmt.Println("ERROR: Invalid command")
	}
}
