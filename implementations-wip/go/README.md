# Go Chess Engine

A complete chess engine implementation in Go, featuring:

- Full chess rules implementation including special moves
- AI with minimax algorithm and alpha-beta pruning
- FEN import/export
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
echo -e "new\nmove e2e4\nexport\nquit" | docker run -i chess-go
```

## Commands

- `new` - Start a new game
- `move <from><to>` - Make a move (e.g., `move e2e4`)
- `undo` - Undo the last move
- `export` - Export current position as FEN
- `ai <depth>` - Let AI make a move at specified depth (1-5)
- `quit` - Exit the program

## Testing

```bash
make test-go
```