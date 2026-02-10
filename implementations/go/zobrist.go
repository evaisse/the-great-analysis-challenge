package main

var (
	pieceKeys      [64][12]uint64
	sideToMoveKey  uint64
	castlingKeys   [16]uint64
	enPassantKeys  [8]uint64
	zobristInitial bool
)

type Xorshift64 struct {
	state uint64
}

func (x *Xorshift64) Next() uint64 {
	x.state ^= x.state << 13
	x.state ^= x.state >> 7
	x.state ^= x.state << 17
	return x.state
}

func initZobrist() {
	if zobristInitial {
		return
	}

	rng := &Xorshift64{state: 0x123456789ABCDEF0}

	for i := 0; i < 64; i++ {
		for j := 0; j < 12; j++ {
			pieceKeys[i][j] = rng.Next()
		}
	}

	sideToMoveKey = rng.Next()

	for i := 0; i < 16; i++ {
		castlingKeys[i] = rng.Next()
	}

	for i := 0; i < 8; i++ {
		enPassantKeys[i] = rng.Next()
	}

	zobristInitial = true
}

func getPieceIndex(p Piece) int {
	base := int(p.Type) - 1
	if p.Color == Black {
		base += 6
	}
	return base
}

func computeZobristHash(gs *GameState) uint64 {
	initZobrist()
	var h uint64

	for r := 0; r < 8; r++ {
		for f := 0; f < 8; f++ {
			p := gs.Board[r][f]
			if p.Type != Empty {
				h ^= pieceKeys[r*8+f][getPieceIndex(p)]
			}
		}
	}

	if gs.ActiveColor == Black {
		h ^= sideToMoveKey
	}

	castlingIndex := 0
	if gs.CastlingRights[White][KingsideCastle] {
		castlingIndex |= 1
	}
	if gs.CastlingRights[White][QueensideCastle] {
		castlingIndex |= 2
	}
	if gs.CastlingRights[Black][KingsideCastle] {
		castlingIndex |= 4
	}
	if gs.CastlingRights[Black][QueensideCastle] {
		castlingIndex |= 8
	}
	h ^= castlingKeys[castlingIndex]

	if gs.EnPassantTarget != nil {
		h ^= enPassantKeys[gs.EnPassantTarget.File]
	}

	return h
}