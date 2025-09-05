package game

import "fmt"

type Move struct {
	From      int
	To        int
	Promotion Piece
}

func (m Move) String() string {
	return fmt.Sprintf("%s%s", squareToString(m.From), squareToString(m.To))
}

func squareToString(s int) string {
	file := s % 8
	rank := s / 8
	return fmt.Sprintf("%c%d", 'a'+file, rank+1)
}