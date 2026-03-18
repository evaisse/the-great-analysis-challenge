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
- `pgn load|show|moves` - PGN command family
- `uci` / `isready` - UCI handshake commands
- `new960 [id]` / `position960` - Chess960 command surface
- `quit` - Exit the program

## Testing

```bash
make test-go
```
