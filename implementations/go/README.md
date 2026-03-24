# Go Chess Engine

A complete chess engine implementation in Go, featuring:

- Full chess rules implementation including special moves
- AI with minimax algorithm and alpha-beta pruning
- FEN import/export
- PGN commands, UCI handshake, and Chess960 command surface
- Command-line interface
- Docker support

## Building and Running

### Local Development
```bash
go build -o chess chess.go
./chess
```

### Docker
```bash
docker build -t chess-go .
echo -e "new\nmove e2e4\nexport\nquit" | docker run --network none -i chess-go
```

## Commands

- `new` - Start a new game
- `move <from><to>` - Make a move (e.g., `move e2e4`)
- `undo` - Undo the last move
- `export` - Export current position as FEN
- `ai <depth>` - Let AI make a move at specified depth (1-5)
- `pgn load|save|show|moves` - PGN command family
- `pgn variation enter|exit` - Navigate PGN variations
- `pgn comment "text"` - Add a PGN comment to current node
- `uci` / `isready` - UCI handshake commands
- `new960 [id]` / `position960` - Chess960 command surface
- Precomputed knight, king, ray, and distance lookup tables back the hot move-generation paths
- `quit` - Exit the program

## Testing

```bash
make test-go
```
