package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/evaisse/the-great-analysis-challenge/go/internal/game"
)

func main() {
	g := game.NewGame()
	reader := bufio.NewReader(os.Stdin)

	fmt.Println(g.Board)

	for {
		fmt.Print("> ")
		cmd, _ := reader.ReadString('\n')
		cmd = strings.TrimSpace(cmd)

		if cmd == "quit" {
			break
		}

		g.HandleCommand(cmd)
	}
}
