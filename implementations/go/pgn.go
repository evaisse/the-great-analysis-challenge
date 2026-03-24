package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

const pgnStartFEN = StartingPositionFEN

type PgnMoveNode struct {
	SAN        string
	Move       Move
	FenBefore  string
	FenAfter   string
	NAGs       []string
	Comments   []string
	Variations [][]*PgnMoveNode
}

type PgnGame struct {
	Tags            map[string]string
	Moves           []*PgnMoveNode
	Result          string
	Source          string
	InitialFEN      string
	InitialComments []string
}

func newPgnGameFromHistory(history []Move, startFEN, source string) *PgnGame {
	if startFEN == "" {
		startFEN = pgnStartFEN
	}
	gs, err := gameStateFromFEN(startFEN)
	if err != nil {
		gs = NewGameState()
		startFEN = gs.ToFEN()
	}
	game := &PgnGame{
		Tags: map[string]string{
			"Event":  "CLI Game",
			"Site":   "Local",
			"Result": "*",
		},
		Moves:      make([]*PgnMoveNode, 0, len(history)),
		Result:     "*",
		Source:     source,
		InitialFEN: startFEN,
	}
	if startFEN != pgnStartFEN {
		game.Tags["SetUp"] = "1"
		game.Tags["FEN"] = startFEN
	}
	for _, raw := range history {
		move := cloneMove(raw)
		fenBefore := gs.ToFEN()
		san, err := moveToSAN(gs, move)
		if err != nil {
			san = moveToString(move)
		}
		gs.MakeMove(move)
		fenAfter := gs.ToFEN()
		game.Moves = append(game.Moves, &PgnMoveNode{SAN: san, Move: cloneMove(move), FenBefore: fenBefore, FenAfter: fenAfter})
	}
	return game
}

func cloneMove(move Move) Move {
	clone := move
	if move.Captured != nil {
		captured := *move.Captured
		clone.Captured = &captured
	}
	return clone
}

func gameStateFromFEN(fen string) (*GameState, error) {
	gs := NewGameState()
	if err := gs.FromFEN(fen); err != nil {
		return nil, err
	}
	gs.MoveHistory = nil
	gs.StateHistory = nil
	gs.PositionHistory = nil
	gs.ZobristHash = computeZobristHash(gs)
	return gs, nil
}

func moveToSAN(gs *GameState, move Move) (string, error) {
	piece := gs.GetPiece(move.From)
	if piece.IsEmpty() {
		return "", fmt.Errorf("missing moving piece for SAN serialization")
	}
	target := gs.GetPiece(move.To)
	isCapture := move.IsEnPassant || !target.IsEmpty()
	var san string
	if move.IsCastle {
		if move.To.File == 6 {
			san = "O-O"
		} else {
			san = "O-O-O"
		}
	} else {
		destination := move.To.ToAlgebraic()
		promotion := ""
		if move.IsPromotion {
			promotion = "=" + pieceLetter(move.PromoteTo)
		}
		if piece.Type == Pawn {
			prefix := ""
			if isCapture {
				prefix = string(rune('a'+move.From.File)) + "x"
			}
			san = prefix + destination + promotion
		} else {
			prefix := pieceLetter(piece.Type) + disambiguation(gs, move, piece)
			if isCapture {
				prefix += "x"
			}
			san = prefix + destination + promotion
		}
	}
	test := gs.Clone()
	test.MakeMove(cloneMove(move))
	if test.IsInCheck(test.ActiveColor) {
		if len(test.GenerateLegalMoves()) == 0 {
			san += "#"
		} else {
			san += "+"
		}
	}
	return san, nil
}

func pieceLetter(piece PieceType) string {
	switch piece {
	case Knight:
		return "N"
	case Bishop:
		return "B"
	case Rook:
		return "R"
	case Queen:
		return "Q"
	case King:
		return "K"
	default:
		return ""
	}
}

func disambiguation(gs *GameState, move Move, piece Piece) string {
	legal := gs.GenerateLegalMoves()
	clashes := make([]Move, 0)
	for _, candidate := range legal {
		if candidate.From == move.From && candidate.To == move.To && candidate.PromoteTo == move.PromoteTo {
			continue
		}
		other := gs.GetPiece(candidate.From)
		if other.Type == piece.Type && other.Color == piece.Color && candidate.To == move.To {
			clashes = append(clashes, candidate)
		}
	}
	if len(clashes) == 0 {
		return ""
	}
	sameFile := false
	sameRank := false
	for _, candidate := range clashes {
		if candidate.From.File == move.From.File {
			sameFile = true
		}
		if candidate.From.Rank == move.From.Rank {
			sameRank = true
		}
	}
	if !sameFile {
		return string(rune('a' + move.From.File))
	}
	if !sameRank {
		return string(rune('1' + move.From.Rank))
	}
	return string(rune('a'+move.From.File)) + string(rune('1'+move.From.Rank))
}

func normalizeSAN(token string) string {
	cleaned := strings.TrimSpace(token)
	for len(cleaned) > 0 {
		last := cleaned[len(cleaned)-1]
		if last == '+' || last == '#' || last == '!' || last == '?' {
			cleaned = cleaned[:len(cleaned)-1]
			continue
		}
		break
	}
	cleaned = strings.ReplaceAll(cleaned, "0-0-0", "O-O-O")
	cleaned = strings.ReplaceAll(cleaned, "0-0", "O-O")
	cleaned = strings.ReplaceAll(cleaned, "e.p.", "")
	cleaned = strings.ReplaceAll(cleaned, "ep", "")
	if dot := strings.Index(cleaned, "."); dot >= 0 {
		prefix := cleaned[:dot+1]
		allNumeric := true
		for _, ch := range prefix[:len(prefix)-1] {
			if ch < '0' || ch > '9' {
				allNumeric = false
				break
			}
		}
		if allNumeric {
			cleaned = cleaned[dot+1:]
			cleaned = strings.TrimLeft(cleaned, ".")
		}
	}
	return strings.TrimSpace(cleaned)
}

func sanToMove(gs *GameState, san string) (Move, error) {
	normalized := normalizeSAN(san)
	for _, move := range gs.GenerateLegalMoves() {
		candidate, err := moveToSAN(gs, move)
		if err != nil {
			continue
		}
		if normalizeSAN(candidate) == normalized {
			return move, nil
		}
	}
	return Move{}, fmt.Errorf("unresolved SAN move: %s", san)
}

type pgnToken struct {
	Kind  string
	Value string
}

func tokenizePGN(content string) ([]pgnToken, error) {
	tokens := make([]pgnToken, 0)
	for i := 0; i < len(content); {
		ch := content[i]
		if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
			i++
			continue
		}
		switch ch {
		case '[':
			end := strings.IndexByte(content[i:], ']')
			if end < 0 {
				return nil, fmt.Errorf("unterminated PGN tag")
			}
			raw := strings.TrimSpace(content[i+1 : i+end])
			firstSpace := strings.IndexAny(raw, " \t")
			if firstSpace <= 0 {
				return nil, fmt.Errorf("invalid PGN tag: [%s]", raw)
			}
			name := strings.TrimSpace(raw[:firstSpace])
			rest := strings.TrimSpace(raw[firstSpace:])
			if len(rest) < 2 || rest[0] != '"' || rest[len(rest)-1] != '"' {
				return nil, fmt.Errorf("invalid PGN tag: [%s]", raw)
			}
			value := strings.ReplaceAll(rest[1:len(rest)-1], `\"`, `"`)
			tokens = append(tokens, pgnToken{Kind: "TAG", Value: name + "\n" + value})
			i += end + 1
		case '{':
			end := strings.IndexByte(content[i:], '}')
			if end < 0 {
				return nil, fmt.Errorf("unterminated PGN comment")
			}
			tokens = append(tokens, pgnToken{Kind: "COMMENT", Value: strings.TrimSpace(content[i+1 : i+end])})
			i += end + 1
		case ';':
			end := strings.IndexByte(content[i:], '\n')
			if end < 0 {
				end = len(content) - i
			}
			tokens = append(tokens, pgnToken{Kind: "COMMENT", Value: strings.TrimSpace(content[i+1 : i+end])})
			i += end
		case '(':
			tokens = append(tokens, pgnToken{Kind: "LPAREN", Value: "("})
			i++
		case ')':
			tokens = append(tokens, pgnToken{Kind: "RPAREN", Value: ")"})
			i++
		case '$':
			start := i
			i++
			for i < len(content) && content[i] >= '0' && content[i] <= '9' {
				i++
			}
			tokens = append(tokens, pgnToken{Kind: "NAG", Value: content[start:i]})
		default:
			start := i
			for i < len(content) && !strings.ContainsRune(" []{}();\n\r\t", rune(content[i])) {
				i++
			}
			value := content[start:i]
			switch value {
			case "1-0", "0-1", "1/2-1/2", "*":
				tokens = append(tokens, pgnToken{Kind: "RESULT", Value: value})
			default:
				if strings.HasSuffix(value, ".") {
					numeric := true
					for _, ch2 := range strings.TrimRight(value, ".") {
						if ch2 < '0' || ch2 > '9' {
							numeric = false
							break
						}
					}
					if numeric {
						tokens = append(tokens, pgnToken{Kind: "MOVE_NO", Value: value})
						continue
					}
				}
				tokens = append(tokens, pgnToken{Kind: "SAN", Value: value})
			}
		}
	}
	return tokens, nil
}

func parsePGN(content, source string) (*PgnGame, error) {
	tokens, err := tokenizePGN(content)
	if err != nil {
		return nil, err
	}
	idx := 0
	tags := map[string]string{}
	for idx < len(tokens) && tokens[idx].Kind == "TAG" {
		parts := strings.SplitN(tokens[idx].Value, "\n", 2)
		if len(parts) == 2 {
			tags[parts[0]] = parts[1]
		}
		idx++
	}
	initialFEN := tags["FEN"]
	if initialFEN == "" {
		initialFEN = pgnStartFEN
	}
	gs, err := gameStateFromFEN(initialFEN)
	if err != nil {
		return nil, err
	}
	moves, result, initialComments, err := parsePGNSequence(tokens, &idx, gs)
	if err != nil {
		return nil, err
	}
	if result == "" {
		result = tags["Result"]
		if result == "" {
			result = "*"
		}
	}
	if _, ok := tags["Result"]; !ok {
		tags["Result"] = result
	}
	return &PgnGame{Tags: tags, Moves: moves, Result: result, Source: source, InitialFEN: initialFEN, InitialComments: initialComments}, nil
}

func parsePGNSequence(tokens []pgnToken, idx *int, gs *GameState) ([]*PgnMoveNode, string, []string, error) {
	moves := make([]*PgnMoveNode, 0)
	leading := make([]string, 0)
	result := ""
	for *idx < len(tokens) {
		tok := tokens[*idx]
		switch tok.Kind {
		case "RPAREN":
			return moves, result, leading, nil
		case "RESULT":
			*idx++
			return moves, tok.Value, leading, nil
		case "MOVE_NO":
			*idx++
		case "COMMENT":
			if len(moves) == 0 {
				leading = append(leading, tok.Value)
			} else {
				moves[len(moves)-1].Comments = append(moves[len(moves)-1].Comments, tok.Value)
			}
			*idx++
		case "NAG":
			if len(moves) == 0 {
				return nil, "", nil, fmt.Errorf("NAG without move")
			}
			moves[len(moves)-1].NAGs = append(moves[len(moves)-1].NAGs, tok.Value)
			*idx++
		case "LPAREN":
			if len(moves) == 0 {
				return nil, "", nil, fmt.Errorf("variation without anchor move")
			}
			*idx++
			anchor := moves[len(moves)-1]
			variationGS, err := gameStateFromFEN(anchor.FenBefore)
			if err != nil {
				return nil, "", nil, err
			}
			variationMoves, variationResult, pending, err := parsePGNSequence(tokens, idx, variationGS)
			if err != nil {
				return nil, "", nil, err
			}
			if *idx >= len(tokens) || tokens[*idx].Kind != "RPAREN" {
				return nil, "", nil, fmt.Errorf("unterminated PGN variation")
			}
			*idx++
			if len(variationMoves) > 0 && len(pending) > 0 {
				variationMoves[len(variationMoves)-1].Comments = append(variationMoves[len(variationMoves)-1].Comments, pending...)
			}
			if variationResult != "" && variationResult != "*" && len(variationMoves) > 0 {
				variationMoves[len(variationMoves)-1].Comments = append(variationMoves[len(variationMoves)-1].Comments, "result "+variationResult)
			}
			anchor.Variations = append(anchor.Variations, variationMoves)
		case "SAN":
			fenBefore := gs.ToFEN()
			move, err := sanToMove(gs, tok.Value)
			if err != nil {
				return nil, "", nil, err
			}
			san, err := moveToSAN(gs, move)
			if err != nil {
				return nil, "", nil, err
			}
			gs.MakeMove(move)
			moves = append(moves, &PgnMoveNode{SAN: san, Move: cloneMove(move), FenBefore: fenBefore, FenAfter: gs.ToFEN()})
			*idx++
		default:
			return nil, "", nil, fmt.Errorf("unexpected PGN token: %s", tok.Kind)
		}
	}
	return moves, result, leading, nil
}

func serializePGN(game *PgnGame) string {
	if game == nil {
		return ""
	}
	var lines []string
	orderedTags := []string{"Event", "Site", "Date", "Round", "White", "Black", "Result", "SetUp", "FEN"}
	seen := map[string]bool{}
	for _, key := range orderedTags {
		if value, ok := game.Tags[key]; ok {
			lines = append(lines, fmt.Sprintf("[%s \"%s\"]", key, strings.ReplaceAll(value, `"`, `\"`)))
			seen[key] = true
		}
	}
	for key, value := range game.Tags {
		if !seen[key] {
			lines = append(lines, fmt.Sprintf("[%s \"%s\"]", key, strings.ReplaceAll(value, `"`, `\"`)))
		}
	}
	if len(lines) > 0 {
		lines = append(lines, "")
	}
	moveNumber, color := startingPly(game.InitialFEN)
	moveText := serializePGNSequence(game.Moves, moveNumber, color)
	if len(game.InitialComments) > 0 {
		commentParts := make([]string, 0, len(game.InitialComments))
		for _, comment := range game.InitialComments {
			commentParts = append(commentParts, "{"+comment+"}")
		}
		moveText = strings.TrimSpace(strings.Join(commentParts, " ") + " " + moveText)
	}
	if game.Result != "" {
		moveText = strings.TrimSpace(moveText + " " + game.Result)
	}
	lines = append(lines, strings.TrimSpace(moveText))
	return strings.TrimSpace(strings.Join(lines, "\n")) + "\n"
}

func startingPly(fen string) (int, Color) {
	parts := strings.Fields(strings.TrimSpace(fen))
	if len(parts) >= 6 {
		moveNumber, err := strconv.Atoi(parts[5])
		if err != nil || moveNumber < 1 {
			moveNumber = 1
		}
		if parts[1] == "b" {
			return moveNumber, Black
		}
		return moveNumber, White
	}
	return 1, White
}

func serializePGNSequence(moves []*PgnMoveNode, moveNumber int, color Color) string {
	parts := make([]string, 0)
	currentMoveNumber := moveNumber
	currentColor := color
	for _, node := range moves {
		if currentColor == White {
			parts = append(parts, fmt.Sprintf("%d. %s", currentMoveNumber, node.SAN))
		} else {
			if len(parts) == 0 || !strings.HasPrefix(parts[len(parts)-1], fmt.Sprintf("%d.", currentMoveNumber)) {
				parts = append(parts, fmt.Sprintf("%d... %s", currentMoveNumber, node.SAN))
			} else {
				parts = append(parts, node.SAN)
			}
		}
		parts = append(parts, node.NAGs...)
		for _, comment := range node.Comments {
			parts = append(parts, "{"+comment+"}")
		}
		for _, variation := range node.Variations {
			parts = append(parts, "("+serializePGNSequence(variation, currentMoveNumber, currentColor)+")")
		}
		if currentColor == Black {
			currentMoveNumber++
			currentColor = White
		} else {
			currentColor = Black
		}
	}
	return strings.TrimSpace(strings.Join(parts, " "))
}

func loadPGNFile(path string) (*PgnGame, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parsePGN(string(content), path)
}
