#!/usr/bin/env nim
## Chess Engine Implementation in Nim
## Follows the specification defined in CHESS_ENGINE_SPECS.md

import std/[strutils, sequtils, tables, algorithm, times]

type
  PieceType* = enum
    ptNone, ptPawn, ptKnight, ptBishop, ptRook, ptQueen, ptKing

  Color* = enum
    cWhite, cBlack

  Piece* = object
    pieceType*: PieceType
    color*: Color

  Square* = int  # 0-63, a1=0, h8=63

  Move* = object
    fromSq*: Square
    toSq*: Square
    promotion*: PieceType
    isCapture*: bool
    isCastling*: bool
    isEnPassant*: bool

  Board* = object
    squares*: array[64, Piece]
    toMove*: Color
    castlingRights*: int  # Bitfield: bit 0=WK, 1=WQ, 2=BK, 3=BQ
    enPassantTarget*: int  # -1 if none
    halfmoveClock*: int
    fullmoveNumber*: int

  CastlingRight* = enum
    crWhiteKing = 0, crWhiteQueen = 1, crBlackKing = 2, crBlackQueen = 3

  ChessEngine* = object
    board*: Board
    moveHistory*: seq[Move]

# Board utilities
proc squareToAlgebraic*(sq: Square): string =
  let file = char(ord('a') + (sq mod 8))
  let rank = char(ord('1') + (sq div 8))
  return $file & $rank

proc algebraicToSquare*(pos: string): Square =
  if pos.len != 2:
    return -1
  let file = ord(pos[0]) - ord('a')
  let rank = ord(pos[1]) - ord('1')
  if file < 0 or file > 7 or rank < 0 or rank > 7:
    return -1
  return rank * 8 + file

proc pieceToChar*(piece: Piece): char =
  if piece.pieceType == ptNone:
    return '.'
  
  let baseChar = case piece.pieceType:
    of ptPawn: 'p'
    of ptKnight: 'n'
    of ptBishop: 'b'
    of ptRook: 'r'
    of ptQueen: 'q'
    of ptKing: 'k'
    else: '.'
  
  if piece.color == cWhite:
    return baseChar.toUpperAscii()
  else:
    return baseChar

proc charToPiece*(c: char): Piece =
  let color = if c.isUpperAscii(): cWhite else: cBlack
  let pieceType = case c.toLowerAscii():
    of 'p': ptPawn
    of 'n': ptKnight
    of 'b': ptBishop
    of 'r': ptRook
    of 'q': ptQueen
    of 'k': ptKing
    else: ptNone
  
  return Piece(pieceType: pieceType, color: color)

# Forward declarations
proc parseFEN*(fen: string): Board

# Initialize board to starting position
proc initBoard*(): Board =
  # Setup starting position
  let startingFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  result = parseFEN(startingFEN)

# FEN parsing
proc parseFEN*(fen: string): Board =
  result = Board()
  let parts = fen.split(' ')
  if parts.len != 6:
    return initBoard()  # Return starting position on error
  
  # Parse board position
  let position = parts[0]
  var square = 56  # Start at a8 (rank 8, file a)
  
  for c in position:
    case c:
    of '/':
      square -= 16  # Move to next rank (down one, back to file a)
    of '1'..'8':
      let emptySquares = ord(c) - ord('0')
      for i in 0..<emptySquares:
        result.squares[square] = Piece(pieceType: ptNone, color: cWhite)
        inc square
    else:
      result.squares[square] = charToPiece(c)
      inc square
  
  # Parse active color
  result.toMove = if parts[1] == "w": cWhite else: cBlack
  
  # Parse castling rights
  result.castlingRights = 0
  for c in parts[2]:
    case c:
    of 'K': result.castlingRights = result.castlingRights or (1 shl 0)  # White king
    of 'Q': result.castlingRights = result.castlingRights or (1 shl 1)  # White queen
    of 'k': result.castlingRights = result.castlingRights or (1 shl 2)  # Black king
    of 'q': result.castlingRights = result.castlingRights or (1 shl 3)  # Black queen
    else: discard
  
  # Parse en passant target
  if parts[3] == "-":
    result.enPassantTarget = -1
  else:
    result.enPassantTarget = algebraicToSquare(parts[3])
  
  # Parse move counters
  result.halfmoveClock = parseInt(parts[4])
  result.fullmoveNumber = parseInt(parts[5])

proc boardToFEN*(board: Board): string =
  var fen = ""
  
  # Board position
  for rank in countdown(7, 0):
    var emptyCount = 0
    for file in 0..7:
      let square = rank * 8 + file
      let piece = board.squares[square]
      
      if piece.pieceType == ptNone:
        inc emptyCount
      else:
        if emptyCount > 0:
          fen.add($emptyCount)
          emptyCount = 0
        fen.add(pieceToChar(piece))
    
    if emptyCount > 0:
      fen.add($emptyCount)
    
    if rank > 0:
      fen.add('/')
  
  fen.add(' ')
  
  # Active color
  fen.add(if board.toMove == cWhite: "w" else: "b")
  fen.add(' ')
  
  # Castling rights
  var castling = ""
  if (board.castlingRights and (1 shl 0)) != 0: castling.add('K')  # White king
  if (board.castlingRights and (1 shl 1)) != 0: castling.add('Q')  # White queen
  if (board.castlingRights and (1 shl 2)) != 0: castling.add('k')  # Black king
  if (board.castlingRights and (1 shl 3)) != 0: castling.add('q')  # Black queen
  if castling == "": castling = "-"
  fen.add(castling)
  fen.add(' ')
  
  # En passant target
  if board.enPassantTarget == -1:
    fen.add('-')
  else:
    fen.add(squareToAlgebraic(board.enPassantTarget))
  fen.add(' ')
  
  # Move counters
  fen.add($board.halfmoveClock)
  fen.add(' ')
  fen.add($board.fullmoveNumber)
  
  return fen

# Display board
proc displayBoard*(board: Board): string =
  result = "  a b c d e f g h\n"
  
  for rank in countdown(7, 0):
    result.add($(rank + 1) & " ")
    for file in 0..7:
      let square = rank * 8 + file
      let piece = board.squares[square]
      result.add(pieceToChar(piece) & " ")
    result.add($(rank + 1) & "\n")
  
  result.add("  a b c d e f g h\n\n")
  result.add(if board.toMove == cWhite: "White to move" else: "Black to move")

# Basic move validation (simplified for now)
proc isValidMove*(board: Board, move: Move): bool =
  if move.fromSq < 0 or move.fromSq > 63 or move.toSq < 0 or move.toSq > 63:
    return false
  
  let piece = board.squares[move.fromSq]
  if piece.pieceType == ptNone:
    return false
  
  if piece.color != board.toMove:
    return false
  
  # Basic validation - more complex logic would go here
  return true

# Make move (simplified)
proc makeMove*(board: var Board, move: Move): bool =
  if not isValidMove(board, move):
    return false
  
  let piece = board.squares[move.fromSq]
  board.squares[move.fromSq] = Piece(pieceType: ptNone, color: cWhite)
  board.squares[move.toSq] = piece
  
  # Switch turns
  board.toMove = if board.toMove == cWhite: cBlack else: cWhite
  
  return true

# Parse move from algebraic notation
proc parseMove*(moveStr: string): Move =
  if moveStr.len < 4:
    return Move(fromSq: -1, toSq: -1)
  
  let fromSq = algebraicToSquare(moveStr[0..1])
  let toSq = algebraicToSquare(moveStr[2..3])
  
  var promotion = ptNone
  if moveStr.len == 5:
    promotion = case moveStr[4].toLowerAscii():
      of 'q': ptQueen
      of 'r': ptRook
      of 'b': ptBishop
      of 'n': ptKnight
      else: ptNone
  
  return Move(fromSq: fromSq, toSq: toSq, promotion: promotion)

# Initialize chess engine
proc initChessEngine*(): ChessEngine =
  ChessEngine(
    board: initBoard(),
    moveHistory: @[]
  )

# Process commands
proc processCommand*(engine: var ChessEngine, command: string): string =
  let parts = command.strip().split()
  if parts.len == 0:
    return ""
  
  case parts[0].toLowerAscii():
  of "new":
    engine.board = initBoard()
    engine.moveHistory = @[]
    return "OK: New game started"
  
  of "move":
    if parts.len < 2:
      return "ERROR: Move format required"
    
    let move = parseMove(parts[1])
    if move.fromSq == -1:
      return "ERROR: Invalid move format"
    
    if makeMove(engine.board, move):
      engine.moveHistory.add(move)
      return "OK: " & parts[1]
    else:
      return "ERROR: Illegal move"
  
  of "undo":
    if engine.moveHistory.len > 0:
      # Simplified undo - would need proper implementation
      return "ERROR: Undo not implemented yet"
    else:
      return "ERROR: No moves to undo"
  
  of "fen":
    if parts.len < 2:
      return "ERROR: FEN string required"
    
    let fenString = parts[1..^1].join(" ")
    engine.board = parseFEN(fenString)
    return "OK: Position loaded"
  
  of "export":
    let fen = boardToFEN(engine.board)
    return "FEN: " & fen
  
  of "eval":
    return "EVAL: 0 (evaluation not implemented yet)"
  
  of "ai":
    return "ERROR: AI not implemented yet"
  
  of "perft":
    return "ERROR: Perft not implemented yet"
  
  of "help":
    return """Available commands:
new - Start a new game
move <from><to>[promotion] - Make a move (e.g., move e2e4)
undo - Undo last move
fen <fen_string> - Load position from FEN
export - Export current position as FEN
eval - Show position evaluation
ai <depth> - AI makes a move
perft <depth> - Performance test
help - Show this help
quit - Exit the program"""
  
  of "quit":
    return "QUIT"
  
  else:
    return "ERROR: Unknown command"

# Main program
when isMainModule:
  var engine = initChessEngine()
  
  echo engine.board.displayBoard()
  
  while true:
    stdout.write("\n> ")
    stdout.flushFile()
    
    let input = stdin.readLine()
    if input == "":
      break
    
    let response = engine.processCommand(input)
    
    if response == "QUIT":
      break
    elif response != "":
      echo response
    
    # Show board after moves
    if input.startsWith("move") or input.startsWith("new") or input.startsWith("fen"):
      echo ""
      echo engine.board.displayBoard()