# Dart Chess Engine

A chess engine implementation in Dart following the project specifications.

## Building

```bash
make build
# or
dart pub get
dart compile exe bin/main.dart -o bin/chess_engine
```

## Running

```bash
make
./bin/chess_engine
# or
dart run bin/main.dart
```

## Testing

```bash
make test
# or  
dart test
```

## Static Analysis

```bash
make analyze
# or
dart analyze
dart format --set-exit-if-changed .
```

## Docker

```bash
make docker-build
make docker-test
```

## Features

- ✅ Basic chess rules and move validation
- ✅ FEN parsing and generation
- ✅ AI with minimax algorithm
- ✅ Special moves (castling, en passant, promotion)
- ✅ Perft testing for move generation verification
- ✅ Command-line interface matching project specification

## Commands

- `new` - Start new game
- `move <move>` - Make a move (e.g., e2e4)
- `undo` - Undo last move
- `export` - Export position as FEN
- `ai <depth>` - AI move with specified depth
- `quit` - Exit program