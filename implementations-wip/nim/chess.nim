import std/[strutils, sequtils, tables, strformat]

# ================================
# Type Definitions
# ================================

type
  PieceType* = enum
    ptNone = 0
    ptPawn = 1
    ptKnight = 2
    ptBishop = 3
    ptRook = 4
    ptQueen = 5
    ptKing = 6

  Color* = enum
    cWhite = 0
    cBlack = 1

  Piece* = object
    pieceType*: PieceType
    color*: Color

  Square* = range[0..63]

  Move* = object
    fromSquare*: Square
    toSquare*: Square
    promotion*: PieceType
    isCapture*: bool
    isEnPassant*: bool
    isCastling*: bool

  CastlingRights* = object
    whiteKingside*: bool
    whiteQueenside*: bool
    blackKingside*: bool
    blackQueenside*: bool

  Board* = object
    squares*: array[64, Piece]
    activeColor*: Color
    castlingRights*: CastlingRights
    enPassantTarget*: int  # -1 if none, otherwise 0-63
    halfmoveClock*: int
    fullmoveNumber*: int

  GameState* = object
    board*: Board
    moveHistory*: seq[Move]
    boardHistory*: seq[Board]

# ================================
# Constants
# ================================

const
  InitialFEN* = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  
  EmptyPiece* = Piece(pieceType: ptNone, color: cWhite)
  
  # Direction offsets for move generation
  KnightMoves* = @[17, 15, 10, 6, -6, -10, -15, -17]
  KingMoves* = @[8, -8, 1, -1, 9, -9, 7, -7]
  RookDirections* = @[8, -8, 1, -1]
  BishopDirections* = @[9, -9, 7, -7]
  
  # Piece values for evaluation
  PieceValues*: array[PieceType, int] = [0, 100, 320, 330, 500, 900, 20000]

# ================================
# Utility Functions
# ================================

proc opposite*(c: Color): Color =
  if c == cWhite: cBlack else: cWhite

proc getFile*(sq: Square): int =
  sq mod 8

proc getRank*(sq: Square): int =
  sq div 8

proc makeSquare*(file, rank: int): Square =
  if file in 0..7 and rank in 0..7:
    Square(rank * 8 + file)
  else:
    Square(0)

proc algebraicToSquare*(notation: string): int =
  if notation.len != 2:
    return -1
  let file = notation[0].ord - 'a'.ord
  let rank = notation[1].ord - '1'.ord
  if file in 0..7 and rank in 0..7:
    return rank * 8 + file
  return -1

proc squareToAlgebraic*(sq: Square): string =
  let file = char('a'.ord + getFile(sq))
  let rank = char('1'.ord + getRank(sq))
  return $file & $rank

proc pieceToChar*(p: Piece): char =
  if p.pieceType == ptNone:
    return '.'
  
  let ch = case p.pieceType
    of ptPawn: 'p'
    of ptKnight: 'n'
    of ptBishop: 'b'
    of ptRook: 'r'
    of ptQueen: 'q'
    of ptKing: 'k'
    else: '.'
  
  if p.color == cWhite:
    ch.toUpperAscii
  else:
    ch

proc charToPiece*(ch: char): Piece =
  let color = if ch.isUpperAscii: cWhite else: cBlack
  let pieceType = case ch.toLowerAscii
    of 'p': ptPawn
    of 'n': ptKnight
    of 'b': ptBishop
    of 'r': ptRook
    of 'q': ptQueen
    of 'k': ptKing
    else: ptNone
  
  Piece(pieceType: pieceType, color: color)

# ================================
# Board Functions
# ================================

proc clearBoard*(board: var Board) =
  for i in 0..63:
    board.squares[i] = EmptyPiece
  board.activeColor = cWhite
  board.castlingRights = CastlingRights()
  board.enPassantTarget = -1
  board.halfmoveClock = 0
  board.fullmoveNumber = 1

proc getPiece*(board: Board, sq: Square): Piece =
  board.squares[sq]

proc setPiece*(board: var Board, sq: Square, piece: Piece) =
  board.squares[sq] = piece

proc isEmpty*(board: Board, sq: Square): bool =
  board.squares[sq].pieceType == ptNone

proc isEnemy*(board: Board, sq: Square, color: Color): bool =
  let p = board.getPiece(sq)
  p.pieceType != ptNone and p.color != color

proc isFriendly*(board: Board, sq: Square, color: Color): bool =
  let p = board.getPiece(sq)
  p.pieceType != ptNone and p.color == color

# ================================
# FEN Functions
# ================================

proc parseFEN*(fen: string): Board =
  result.clearBoard()
  
  let parts = fen.split(' ')
  if parts.len != 6:
    raise newException(ValueError, "Invalid FEN: must have 6 parts")
  
  # Parse piece placement
  var rank = 7
  var file = 0
  
  for ch in parts[0]:
    case ch
    of '/':
      rank.dec
      file = 0
    of '1'..'8':
      file += ch.ord - '0'.ord
    else:
      if file > 7:
        raise newException(ValueError, "Invalid FEN: file overflow")
      let sq = makeSquare(file, rank)
      result.setPiece(sq, charToPiece(ch))
      file.inc
  
  # Parse active color
  result.activeColor = if parts[1] == "w": cWhite else: cBlack
  
  # Parse castling rights
  for ch in parts[2]:
    case ch
    of 'K': result.castlingRights.whiteKingside = true
    of 'Q': result.castlingRights.whiteQueenside = true
    of 'k': result.castlingRights.blackKingside = true
    of 'q': result.castlingRights.blackQueenside = true
    of '-': discard
    else: discard
  
  # Parse en passant target
  if parts[3] != "-":
    result.enPassantTarget = algebraicToSquare(parts[3])
  else:
    result.enPassantTarget = -1
  
  # Parse move clocks
  result.halfmoveClock = parseInt(parts[4])
  result.fullmoveNumber = parseInt(parts[5])

proc toFEN*(board: Board): string =
  result = ""
  
  # Piece placement
  for rank in countdown(7, 0):
    var emptyCount = 0
    for file in 0..7:
      let sq = makeSquare(file, rank)
      let piece = board.getPiece(sq)
      
      if piece.pieceType == ptNone:
        emptyCount.inc
      else:
        if emptyCount > 0:
          result.add($emptyCount)
          emptyCount = 0
        result.add(pieceToChar(piece))
    
    if emptyCount > 0:
      result.add($emptyCount)
    
    if rank > 0:
      result.add('/')
  
  # Active color
  result.add(' ')
  result.add(if board.activeColor == cWhite: 'w' else: 'b')
  
  # Castling rights
  result.add(' ')
  var castling = ""
  if board.castlingRights.whiteKingside: castling.add('K')
  if board.castlingRights.whiteQueenside: castling.add('Q')
  if board.castlingRights.blackKingside: castling.add('k')
  if board.castlingRights.blackQueenside: castling.add('q')
  if castling.len == 0: castling = "-"
  result.add(castling)
  
  # En passant
  result.add(' ')
  if board.enPassantTarget >= 0:
    result.add(squareToAlgebraic(Square(board.enPassantTarget)))
  else:
    result.add('-')
  
  # Move clocks
  result.add(' ')
  result.add($board.halfmoveClock)
  result.add(' ')
  result.add($board.fullmoveNumber)

# ================================
# Board Display
# ================================

proc displayBoard*(board: Board): string =
  result = "\n  a b c d e f g h\n"
  
  for rank in countdown(7, 0):
    result.add($(rank + 1) & " ")
    for file in 0..7:
      let sq = makeSquare(file, rank)
      result.add(pieceToChar(board.getPiece(sq)) & " ")
    result.add($(rank + 1) & "\n")
  
  result.add("  a b c d e f g h\n\n")
  result.add(if board.activeColor == cWhite: "White to move\n" else: "Black to move\n")

# ================================
# Move Validation
# ================================

proc findKing*(board: Board, color: Color): Square =
  for sq in 0..63:
    let p = board.getPiece(Square(sq))
    if p.pieceType == ptKing and p.color == color:
      return Square(sq)
  return Square(0)  # Should never happen in valid position

proc isSquareAttacked*(board: Board, sq: Square, byColor: Color): bool =
  # Check pawn attacks
  let pawnDir = if byColor == cWhite: -8 else: 8
  let pawnRank = getRank(sq)
  let pawnFile = getFile(sq)
  
  if byColor == cWhite and pawnRank > 0:
    if pawnFile > 0:
      let attackSq = Square(sq.int + pawnDir - 1)
      let p = board.getPiece(attackSq)
      if p.pieceType == ptPawn and p.color == cWhite:
        return true
    if pawnFile < 7:
      let attackSq = Square(sq.int + pawnDir + 1)
      let p = board.getPiece(attackSq)
      if p.pieceType == ptPawn and p.color == cWhite:
        return true
  elif byColor == cBlack and pawnRank < 7:
    if pawnFile > 0:
      let attackSq = Square(sq.int + pawnDir - 1)
      let p = board.getPiece(attackSq)
      if p.pieceType == ptPawn and p.color == cBlack:
        return true
    if pawnFile < 7:
      let attackSq = Square(sq.int + pawnDir + 1)
      let p = board.getPiece(attackSq)
      if p.pieceType == ptPawn and p.color == cBlack:
        return true
  
  # Check knight attacks
  for delta in KnightMoves:
    let targetSq = sq.int + delta
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      let fileDiff = abs(targetFile - getFile(sq))
      let rankDiff = abs(targetRank - getRank(sq))
      
      if (fileDiff == 2 and rankDiff == 1) or (fileDiff == 1 and rankDiff == 2):
        let p = board.getPiece(Square(targetSq))
        if p.pieceType == ptKnight and p.color == byColor:
          return true
  
  # Check king attacks
  for delta in KingMoves:
    let targetSq = sq.int + delta
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      if abs(targetFile - getFile(sq)) <= 1 and abs(targetRank - getRank(sq)) <= 1:
        let p = board.getPiece(Square(targetSq))
        if p.pieceType == ptKing and p.color == byColor:
          return true
  
  # Check sliding pieces
  for dir in RookDirections:
    var currentSq = sq.int + dir
    var prevFile = getFile(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      if abs(currentFile - prevFile) > 1:
        break
      
      let p = board.getPiece(Square(currentSq))
      if p.pieceType != ptNone:
        if p.color == byColor and p.pieceType in [ptRook, ptQueen]:
          return true
        break
      
      prevFile = currentFile
      currentSq += dir
  
  for dir in BishopDirections:
    var currentSq = sq.int + dir
    var prevFile = getFile(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      if abs(currentFile - prevFile) != 1:
        break
      
      let p = board.getPiece(Square(currentSq))
      if p.pieceType != ptNone:
        if p.color == byColor and p.pieceType in [ptBishop, ptQueen]:
          return true
        break
      
      prevFile = currentFile
      currentSq += dir
  
  return false

proc isInCheck*(board: Board, color: Color): bool =
  let kingSq = board.findKing(color)
  return board.isSquareAttacked(kingSq, opposite(color))

# ================================
# Move Generation
# ================================

proc generatePawnMoves*(board: Board, sq: Square, moves: var seq[Move]) =
  let piece = board.getPiece(sq)
  let direction = if piece.color == cWhite: 8 else: -8
  let startRank = if piece.color == cWhite: 1 else: 6
  let promoRank = if piece.color == cWhite: 7 else: 0
  
  # Single push
  let push1 = sq.int + direction
  if push1 >= 0 and push1 <= 63 and board.isEmpty(Square(push1)):
    if getRank(Square(push1)) == promoRank:
      for promoType in [ptQueen, ptRook, ptBishop, ptKnight]:
        moves.add(Move(fromSquare: sq, toSquare: Square(push1), promotion: promoType))
    else:
      moves.add(Move(fromSquare: sq, toSquare: Square(push1)))
    
    # Double push
    if getRank(sq) == startRank:
      let push2 = sq.int + direction * 2
      if board.isEmpty(Square(push2)):
        moves.add(Move(fromSquare: sq, toSquare: Square(push2)))
  
  # Captures
  for captureOffset in [-1, 1]:
    let targetSq = sq.int + direction + captureOffset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let sourceFile = getFile(sq)
      
      if abs(targetFile - sourceFile) == 1:
        if board.isEnemy(Square(targetSq), piece.color):
          if getRank(Square(targetSq)) == promoRank:
            for promoType in [ptQueen, ptRook, ptBishop, ptKnight]:
              moves.add(Move(fromSquare: sq, toSquare: Square(targetSq), 
                           promotion: promoType, isCapture: true))
          else:
            moves.add(Move(fromSquare: sq, toSquare: Square(targetSq), isCapture: true))
        
        # En passant
        if targetSq == board.enPassantTarget:
          moves.add(Move(fromSquare: sq, toSquare: Square(targetSq), 
                       isCapture: true, isEnPassant: true))

proc generateKnightMoves*(board: Board, sq: Square, moves: var seq[Move]) =
  let piece = board.getPiece(sq)
  
  for delta in KnightMoves:
    let targetSq = sq.int + delta
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      let sourceFile = getFile(sq)
      let sourceRank = getRank(sq)
      
      let fileDiff = abs(targetFile - sourceFile)
      let rankDiff = abs(targetRank - sourceRank)
      
      if (fileDiff == 2 and rankDiff == 1) or (fileDiff == 1 and rankDiff == 2):
        if not board.isFriendly(Square(targetSq), piece.color):
          let isCapture = board.isEnemy(Square(targetSq), piece.color)
          moves.add(Move(fromSquare: sq, toSquare: Square(targetSq), isCapture: isCapture))

proc generateSlidingMoves*(board: Board, sq: Square, directions: seq[int], moves: var seq[Move]) =
  let piece = board.getPiece(sq)
  
  for dir in directions:
    var currentSq = sq.int + dir
    var prevFile = getFile(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      
      # Check for wrapping
      if dir in [-1, 1]:  # Horizontal
        if abs(currentFile - prevFile) != 1:
          break
      elif dir in [-9, -7, 7, 9]:  # Diagonal
        if abs(currentFile - prevFile) != 1:
          break
      
      if board.isFriendly(Square(currentSq), piece.color):
        break
      
      let isCapture = board.isEnemy(Square(currentSq), piece.color)
      moves.add(Move(fromSquare: sq, toSquare: Square(currentSq), isCapture: isCapture))
      
      if isCapture:
        break
      
      prevFile = currentFile
      currentSq += dir

proc generateKingMoves*(board: Board, sq: Square, moves: var seq[Move]) =
  let piece = board.getPiece(sq)
  
  for delta in KingMoves:
    let targetSq = sq.int + delta
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      
      if abs(targetFile - getFile(sq)) <= 1 and abs(targetRank - getRank(sq)) <= 1:
        if not board.isFriendly(Square(targetSq), piece.color):
          let isCapture = board.isEnemy(Square(targetSq), piece.color)
          moves.add(Move(fromSquare: sq, toSquare: Square(targetSq), isCapture: isCapture))
  
  # Castling
  if not board.isInCheck(piece.color):
    if piece.color == cWhite:
      if board.castlingRights.whiteKingside:
        if board.isEmpty(Square(5)) and board.isEmpty(Square(6)):
          if not board.isSquareAttacked(Square(5), cBlack) and 
             not board.isSquareAttacked(Square(6), cBlack):
            moves.add(Move(fromSquare: sq, toSquare: Square(6), isCastling: true))
      
      if board.castlingRights.whiteQueenside:
        if board.isEmpty(Square(3)) and board.isEmpty(Square(2)) and board.isEmpty(Square(1)):
          if not board.isSquareAttacked(Square(3), cBlack) and 
             not board.isSquareAttacked(Square(2), cBlack):
            moves.add(Move(fromSquare: sq, toSquare: Square(2), isCastling: true))
    else:
      if board.castlingRights.blackKingside:
        if board.isEmpty(Square(61)) and board.isEmpty(Square(62)):
          if not board.isSquareAttacked(Square(61), cWhite) and 
             not board.isSquareAttacked(Square(62), cWhite):
            moves.add(Move(fromSquare: sq, toSquare: Square(62), isCastling: true))
      
      if board.castlingRights.blackQueenside:
        if board.isEmpty(Square(59)) and board.isEmpty(Square(58)) and board.isEmpty(Square(57)):
          if not board.isSquareAttacked(Square(59), cWhite) and 
             not board.isSquareAttacked(Square(58), cWhite):
            moves.add(Move(fromSquare: sq, toSquare: Square(58), isCastling: true))

proc generateLegalMoves*(board: Board): seq[Move] =
  result = @[]
  
  for sq in 0..63:
    let piece = board.getPiece(Square(sq))
    if piece.pieceType != ptNone and piece.color == board.activeColor:
      case piece.pieceType
      of ptPawn:
        board.generatePawnMoves(Square(sq), result)
      of ptKnight:
        board.generateKnightMoves(Square(sq), result)
      of ptBishop:
        board.generateSlidingMoves(Square(sq), BishopDirections, result)
      of ptRook:
        board.generateSlidingMoves(Square(sq), RookDirections, result)
      of ptQueen:
        board.generateSlidingMoves(Square(sq), RookDirections & BishopDirections, result)
      of ptKing:
        board.generateKingMoves(Square(sq), result)
      else:
        discard

# ================================
# Move Execution
# ================================

proc makeMove*(board: var Board, move: Move): bool =
  let piece = board.getPiece(move.fromSquare)
  if piece.pieceType == ptNone or piece.color != board.activeColor:
    return false
  
  # Handle castling
  if move.isCastling:
    let fileDiff = getFile(move.toSquare) - getFile(move.fromSquare)
    if fileDiff > 0:  # Kingside
      let rookFrom = if piece.color == cWhite: Square(7) else: Square(63)
      let rookTo = if piece.color == cWhite: Square(5) else: Square(61)
      board.setPiece(rookTo, board.getPiece(rookFrom))
      board.setPiece(rookFrom, EmptyPiece)
    else:  # Queenside
      let rookFrom = if piece.color == cWhite: Square(0) else: Square(56)
      let rookTo = if piece.color == cWhite: Square(3) else: Square(59)
      board.setPiece(rookTo, board.getPiece(rookFrom))
      board.setPiece(rookFrom, EmptyPiece)
  
  # Handle en passant capture
  if move.isEnPassant:
    let captureSquare = if piece.color == cWhite:
      Square(board.enPassantTarget - 8)
    else:
      Square(board.enPassantTarget + 8)
    board.setPiece(captureSquare, EmptyPiece)
  
  # Move the piece
  board.setPiece(move.toSquare, piece)
  board.setPiece(move.fromSquare, EmptyPiece)
  
  # Handle promotion
  if move.promotion != ptNone:
    board.setPiece(move.toSquare, Piece(pieceType: move.promotion, color: piece.color))
  
  # Update en passant square
  if piece.pieceType == ptPawn and abs(getRank(move.toSquare) - getRank(move.fromSquare)) == 2:
    board.enPassantTarget = (move.fromSquare.int + move.toSquare.int) div 2
  else:
    board.enPassantTarget = -1
  
  # Update castling rights
  if piece.pieceType == ptKing:
    if piece.color == cWhite:
      board.castlingRights.whiteKingside = false
      board.castlingRights.whiteQueenside = false
    else:
      board.castlingRights.blackKingside = false
      board.castlingRights.blackQueenside = false
  elif piece.pieceType == ptRook:
    if move.fromSquare == 0: board.castlingRights.whiteQueenside = false
    elif move.fromSquare == 7: board.castlingRights.whiteKingside = false
    elif move.fromSquare == 56: board.castlingRights.blackQueenside = false
    elif move.fromSquare == 63: board.castlingRights.blackKingside = false
  
  # Update move clocks
  if piece.pieceType == ptPawn or move.isCapture:
    board.halfmoveClock = 0
  else:
    board.halfmoveClock.inc
  
  if board.activeColor == cBlack:
    board.fullmoveNumber.inc
  
  # Switch active color
  board.activeColor = opposite(board.activeColor)
  
  return true

# ================================
# Evaluation
# ================================

proc evaluatePosition*(board: Board): int =
  result = 0
  
  for sq in 0..63:
    let piece = board.getPiece(Square(sq))
    if piece.pieceType != ptNone:
      let value = PieceValues[piece.pieceType]
      if piece.color == cWhite:
        result += value
      else:
        result -= value
  
  # Return from perspective of side to move
  if board.activeColor == cBlack:
    result = -result

# ================================
# Simple AI
# ================================

proc minimax*(board: Board, depth: int, alpha: int, beta: int, maximizing: bool): tuple[score: int, move: Move] =
  if depth == 0:
    return (score: evaluatePosition(board), move: Move())
  
  let moves = generateLegalMoves(board)
  if moves.len == 0:
    if board.isInCheck(board.activeColor):
      return (score: if maximizing: -30000 else: 30000, move: Move())
    else:
      return (score: 0, move: Move())  # Stalemate
  
  var bestMove = moves[0]
  var currentAlpha = alpha
  var currentBeta = beta
  
  if maximizing:
    var maxEval = -100000
    for move in moves:
      var newBoard = board
      if newBoard.makeMove(move):
        let eval = minimax(newBoard, depth - 1, currentAlpha, currentBeta, false).score
        if eval > maxEval:
          maxEval = eval
          bestMove = move
        currentAlpha = max(currentAlpha, eval)
        if currentBeta <= currentAlpha:
          break
    return (score: maxEval, move: bestMove)
  else:
    var minEval = 100000
    for move in moves:
      var newBoard = board
      if newBoard.makeMove(move):
        let eval = minimax(newBoard, depth - 1, currentAlpha, currentBeta, true).score
        if eval < minEval:
          minEval = eval
          bestMove = move
        currentBeta = min(currentBeta, eval)
        if currentBeta <= currentAlpha:
          break
    return (score: minEval, move: bestMove)

proc findBestMove*(board: Board, depth: int): Move =
  let result = minimax(board, depth, -100000, 100000, true)
  return result.move

# ================================
# Game Management
# ================================

proc newGame*(): GameState =
  result.board = parseFEN(InitialFEN)
  result.moveHistory = @[]
  result.boardHistory = @[]

proc parseUCIMove*(notation: string): Move =
  if notation.len < 4:
    return Move()
  
  let source = algebraicToSquare(notation[0..1])
  let target = algebraicToSquare(notation[2..3])
  
  if source < 0 or target < 0:
    return Move()
  
  var promotion = ptNone
  if notation.len == 5:
    promotion = case notation[4]
      of 'q': ptQueen
      of 'r': ptRook
      of 'b': ptBishop
      of 'n': ptKnight
      else: ptNone
  
  return Move(fromSquare: Square(source), toSquare: Square(target), promotion: promotion)

proc moveToUCI*(move: Move): string =
  result = squareToAlgebraic(move.fromSquare) & squareToAlgebraic(move.toSquare)
  if move.promotion != ptNone:
    result.add(case move.promotion
      of ptQueen: 'q'
      of ptRook: 'r'
      of ptBishop: 'b'
      of ptKnight: 'n'
      else: ' ')

proc isMoveLegal*(board: Board, move: Move): bool =
  let legalMoves = generateLegalMoves(board)
  for legalMove in legalMoves:
    if legalMove.fromSquare == move.fromSquare and legalMove.toSquare == move.toSquare:
      if move.promotion == ptNone or move.promotion == legalMove.promotion:
        return true
  return false

# ================================
# Command Processing
# ================================

proc processCommand*(game: var GameState, command: string): string =
  let parts = command.strip().split()
  if parts.len == 0:
    return ""
  
  case parts[0].toLowerAscii()
  of "new":
    game = newGame()
    return "OK: New game started"
  
  of "move":
    if parts.len < 2:
      return "ERROR: Move required (e.g., move e2e4)"
    
    let move = parseUCIMove(parts[1])
    
    if not game.board.isMoveLegal(move):
      return "ERROR: Illegal move"
    
    game.boardHistory.add(game.board)
    if game.board.makeMove(move):
      game.moveHistory.add(move)
      return "OK: " & parts[1]
    else:
      return "ERROR: Invalid move"
  
  of "undo":
    if game.moveHistory.len == 0:
      return "ERROR: No moves to undo"
    
    if game.boardHistory.len > 0:
      game.board = game.boardHistory[^1]
      game.boardHistory.setLen(game.boardHistory.len - 1)
      game.moveHistory.setLen(game.moveHistory.len - 1)
      return "OK: Move undone"
    else:
      return "ERROR: Cannot undo"
  
  of "fen":
    if parts.len < 2:
      return "ERROR: FEN string required"
    
    try:
      let fenStr = parts[1..^1].join(" ")
      game.board = parseFEN(fenStr)
      game.moveHistory = @[]
      game.boardHistory = @[]
      return "OK: Position loaded"
    except:
      return "ERROR: Invalid FEN string"
  
  of "export":
    return "FEN: " & toFEN(game.board)
  
  of "eval":
    let score = evaluatePosition(game.board)
    return "EVAL: " & $score
  
  of "ai":
    let depth = if parts.len > 1: parseInt(parts[1]) else: 3
    let move = findBestMove(game.board, depth)
    
    if move.fromSquare == move.toSquare:
      return "ERROR: No legal moves"
    
    game.boardHistory.add(game.board)
    if game.board.makeMove(move):
      game.moveHistory.add(move)
      return "AI: " & moveToUCI(move)
    else:
      return "ERROR: AI move failed"
  
  of "perft":
    if parts.len < 2:
      return "ERROR: Depth required"
    
    let depth = parseInt(parts[1])
    
    proc perft(board: Board, depth: int): int =
      if depth == 0:
        return 1
      
      let moves = generateLegalMoves(board)
      result = 0
      
      for move in moves:
        var newBoard = board
        if newBoard.makeMove(move):
          result += perft(newBoard, depth - 1)
    
    let nodes = perft(game.board, depth)
    return "PERFT: " & $nodes & " nodes"
  
  of "help":
    return """Commands:
new - Start new game
move <from><to>[promo] - Make move (e.g., move e2e4, move a7a8q)
undo - Undo last move
fen <string> - Load FEN position
export - Export current position as FEN
eval - Evaluate position
ai <depth> - AI makes a move (default depth: 3)
perft <depth> - Count positions at depth
quit - Exit program"""
  
  of "quit":
    return "QUIT"
  
  else:
    return "ERROR: Unknown command (type 'help' for commands)"

# ================================
# Main Program
# ================================

when isMainModule:
  var game = newGame()
  
  echo "Nim Chess Engine v2.0"
  echo "Type 'help' for commands\n"
  echo game.board.displayBoard()
  
  while true:
    stdout.write("> ")
    stdout.flushFile()
    
    let input = stdin.readLine()
    if input == "":
      break
    
    let response = processCommand(game, input)
    
    if response == "QUIT":
      echo "Goodbye!"
      break
    elif response != "":
      echo response
    
    # Display board after moves
    if input.startsWith("move") or input.startsWith("new") or 
       input.startsWith("fen") or input.startsWith("ai") or input.startsWith("undo"):
      echo game.board.displayBoard()