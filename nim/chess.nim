import std/[strutils, sequtils, tables, algorithm, math, random]

# Core types
type
  PieceKind* = enum
    Empty = 0
    Pawn = 1
    Knight = 2
    Bishop = 3
    Rook = 4
    Queen = 5
    King = 6

  Color* = enum
    White = 0
    Black = 1

  Piece* = tuple
    kind: PieceKind
    color: Color

  Square* = range[0..63]

  Move* = object
    source*: Square
    target*: Square
    promotion*: PieceKind
    capturedPiece*: Piece

  CastleRights* = object
    whiteKingside*: bool
    whiteQueenside*: bool
    blackKingside*: bool
    blackQueenside*: bool

  Position* = object
    board*: array[64, Piece]
    sideToMove*: Color
    castleRights*: CastleRights
    enPassantSquare*: int  # -1 for none, otherwise 0-63
    halfMoveClock*: int
    fullMoveNumber*: int

  GameState* = object
    position*: Position
    history*: seq[Move]
    positionHistory*: seq[Position]

# Constants
const
  EmptyPiece* = (kind: Empty, color: White)
  
  StartingFEN* = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  
  FileA* = 0
  FileH* = 7
  Rank1* = 0
  Rank8* = 7
  
  # Piece values for evaluation
  PieceValues*: array[PieceKind, int] = [0, 100, 320, 330, 500, 900, 20000]
  
  # Direction offsets for sliding pieces
  RookDirections* = [8, -8, 1, -1]
  BishopDirections* = [9, -9, 7, -7]
  KnightOffsets* = [17, 15, 10, 6, -6, -10, -15, -17]
  KingOffsets* = [8, -8, 1, -1, 9, -9, 7, -7]

# Utility functions
proc opposite*(color: Color): Color =
  if color == White: Black else: White

proc fileOf*(sq: Square): int =
  sq mod 8

proc rankOf*(sq: Square): int =
  sq div 8

proc makeSquare*(file, rank: int): Square =
  if file in 0..7 and rank in 0..7:
    Square(rank * 8 + file)
  else:
    Square(0)

proc toAlgebraic*(sq: Square): string =
  let file = char('a'.ord + fileOf(sq))
  let rank = char('1'.ord + rankOf(sq))
  return $file & $rank

proc fromAlgebraic*(s: string): int =
  if s.len != 2:
    return -1
  let file = s[0].ord - 'a'.ord
  let rank = s[1].ord - '1'.ord
  if file notin 0..7 or rank notin 0..7:
    return -1
  return rank * 8 + file

proc pieceChar*(p: Piece): char =
  if p.kind == Empty:
    return '.'
  let c = case p.kind
    of Pawn: 'p'
    of Knight: 'n'
    of Bishop: 'b'
    of Rook: 'r'
    of Queen: 'q'
    of King: 'k'
    else: '.'
  
  if p.color == White:
    c.toUpperAscii
  else:
    c

proc charToPiece*(c: char): Piece =
  let color = if c.isUpperAscii: White else: Black
  let kind = case c.toLowerAscii
    of 'p': Pawn
    of 'n': Knight
    of 'b': Bishop
    of 'r': Rook
    of 'q': Queen
    of 'k': King
    else: Empty
  
  (kind: kind, color: color)

# Board initialization
proc clearPosition*(pos: var Position) =
  for i in 0..63:
    pos.board[i] = EmptyPiece
  pos.sideToMove = White
  pos.castleRights = CastleRights()
  pos.enPassantSquare = -1
  pos.halfMoveClock = 0
  pos.fullMoveNumber = 1

proc parseFEN*(fen: string): Position =
  result.clearPosition()
  
  let parts = fen.split(' ')
  if parts.len != 6:
    raise newException(ValueError, "Invalid FEN string")
  
  # Parse board
  var rank = 7
  var file = 0
  
  for ch in parts[0]:
    case ch
    of '/':
      rank.dec
      file = 0
    of '1'..'8':
      let skip = ch.ord - '0'.ord
      file += skip
    else:
      let sq = makeSquare(file, rank)
      result.board[sq] = charToPiece(ch)
      file.inc
  
  # Parse side to move
  result.sideToMove = if parts[1] == "w": White else: Black
  
  # Parse castling rights
  for ch in parts[2]:
    case ch
    of 'K': result.castleRights.whiteKingside = true
    of 'Q': result.castleRights.whiteQueenside = true
    of 'k': result.castleRights.blackKingside = true
    of 'q': result.castleRights.blackQueenside = true
    of '-': discard
    else: discard
  
  # Parse en passant
  if parts[3] != "-":
    result.enPassantSquare = fromAlgebraic(parts[3])
  else:
    result.enPassantSquare = -1
  
  # Parse clocks
  result.halfMoveClock = parseInt(parts[4])
  result.fullMoveNumber = parseInt(parts[5])

proc toFEN*(pos: Position): string =
  result = ""
  
  # Board
  for rank in countdown(7, 0):
    var emptyCount = 0
    for file in 0..7:
      let sq = makeSquare(file, rank)
      let piece = pos.board[sq]
      
      if piece.kind == Empty:
        emptyCount.inc
      else:
        if emptyCount > 0:
          result.add($emptyCount)
          emptyCount = 0
        result.add(pieceChar(piece))
    
    if emptyCount > 0:
      result.add($emptyCount)
    
    if rank > 0:
      result.add('/')
  
  # Side to move
  result.add(' ')
  result.add(if pos.sideToMove == White: 'w' else: 'b')
  
  # Castling rights
  result.add(' ')
  var castling = ""
  if pos.castleRights.whiteKingside: castling.add('K')
  if pos.castleRights.whiteQueenside: castling.add('Q')
  if pos.castleRights.blackKingside: castling.add('k')
  if pos.castleRights.blackQueenside: castling.add('q')
  if castling.len == 0: castling = "-"
  result.add(castling)
  
  # En passant
  result.add(' ')
  if pos.enPassantSquare >= 0:
    result.add(toAlgebraic(Square(pos.enPassantSquare)))
  else:
    result.add('-')
  
  # Clocks
  result.add(' ')
  result.add($pos.halfMoveClock)
  result.add(' ')
  result.add($pos.fullMoveNumber)

proc displayBoard*(pos: Position): string =
  result = "\n  a b c d e f g h\n"
  
  for rank in countdown(7, 0):
    result.add($(rank + 1) & " ")
    for file in 0..7:
      let sq = makeSquare(file, rank)
      result.add(pieceChar(pos.board[sq]) & " ")
    result.add($(rank + 1) & "\n")
  
  result.add("  a b c d e f g h\n\n")
  result.add(if pos.sideToMove == White: "White to move\n" else: "Black to move\n")

# Move validation helpers
proc isOnBoard*(file, rank: int): bool =
  file in 0..7 and rank in 0..7

proc isEmpty*(pos: Position, sq: Square): bool =
  pos.board[sq].kind == Empty

proc isEnemy*(pos: Position, sq: Square, color: Color): bool =
  let piece = pos.board[sq]
  piece.kind != Empty and piece.color != color

proc isFriendly*(pos: Position, sq: Square, color: Color): bool =
  let piece = pos.board[sq]
  piece.kind != Empty and piece.color == color

proc findKing*(pos: Position, color: Color): Square =
  for sq in 0..63:
    let piece = pos.board[sq]
    if piece.kind == King and piece.color == color:
      return Square(sq)
  return Square(0)  # Should never happen in valid position

proc isAttacked*(pos: Position, sq: Square, byColor: Color): bool =
  # Check pawn attacks
  let pawnDirection = if byColor == White: -8 else: 8
  let pawnRank = rankOf(sq)
  let pawnFile = fileOf(sq)
  
  if byColor == White and pawnRank > 0:
    if pawnFile > 0:
      let attackSq = sq + pawnDirection - 1
      if pos.board[attackSq] == (kind: Pawn, color: White):
        return true
    if pawnFile < 7:
      let attackSq = sq + pawnDirection + 1
      if pos.board[attackSq] == (kind: Pawn, color: White):
        return true
  elif byColor == Black and pawnRank < 7:
    if pawnFile > 0:
      let attackSq = sq + pawnDirection - 1
      if pos.board[attackSq] == (kind: Pawn, color: Black):
        return true
    if pawnFile < 7:
      let attackSq = sq + pawnDirection + 1
      if pos.board[attackSq] == (kind: Pawn, color: Black):
        return true
  
  # Check knight attacks
  for offset in KnightOffsets:
    let targetSq = sq.int + offset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      let sourceFile = fileOf(sq)
      let sourceRank = rankOf(sq)
      
      if abs(targetFile - sourceFile) <= 2 and abs(targetRank - sourceRank) <= 2:
        let piece = pos.board[targetSq]
        if piece.kind == Knight and piece.color == byColor:
          return true
  
  # Check king attacks
  for offset in KingOffsets:
    let targetSq = sq.int + offset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      if abs(targetFile - fileOf(sq)) <= 1 and abs(targetRank - rankOf(sq)) <= 1:
        let piece = pos.board[targetSq]
        if piece.kind == King and piece.color == byColor:
          return true
  
  # Check sliding pieces (rook, bishop, queen)
  for dir in RookDirections:
    var currentSq = sq.int + dir
    var prevFile = fileOf(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      if abs(currentFile - prevFile) > 1:  # Wrapped around board edge
        break
      
      let piece = pos.board[currentSq]
      if piece.kind != Empty:
        if piece.color == byColor and piece.kind in [Rook, Queen]:
          return true
        break
      
      prevFile = currentFile
      currentSq += dir
  
  for dir in BishopDirections:
    var currentSq = sq.int + dir
    var prevFile = fileOf(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      if abs(currentFile - prevFile) != 1:  # Invalid diagonal move
        break
      
      let piece = pos.board[currentSq]
      if piece.kind != Empty:
        if piece.color == byColor and piece.kind in [Bishop, Queen]:
          return true
        break
      
      prevFile = currentFile
      currentSq += dir
  
  return false

proc isInCheck*(pos: Position, color: Color): bool =
  let kingSquare = pos.findKing(color)
  return pos.isAttacked(kingSquare, opposite(color))

# Move generation
proc generatePawnMoves*(pos: Position, sq: Square, moves: var seq[Move]) =
  let piece = pos.board[sq]
  let direction = if piece.color == White: 8 else: -8
  let startRank = if piece.color == White: 1 else: 6
  let promotionRank = if piece.color == White: 7 else: 0
  
  # Single push
  let push1 = sq.int + direction
  if push1 >= 0 and push1 <= 63 and pos.isEmpty(Square(push1)):
    if rankOf(Square(push1)) == promotionRank:
      for promo in [Queen, Rook, Bishop, Knight]:
        moves.add(Move(source: sq, target: Square(push1), promotion: promo))
    else:
      moves.add(Move(source: sq, target: Square(push1)))
    
    # Double push from starting position
    if rankOf(sq) == startRank:
      let push2 = sq.int + direction * 2
      if pos.isEmpty(Square(push2)):
        moves.add(Move(source: sq, target: Square(push2)))
  
  # Captures
  for captureOffset in [-1, 1]:
    let targetSq = sq.int + direction + captureOffset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let sourceFile = fileOf(sq)
      
      if abs(targetFile - sourceFile) == 1:  # Valid diagonal
        if pos.isEnemy(Square(targetSq), piece.color):
          if rankOf(Square(targetSq)) == promotionRank:
            for promo in [Queen, Rook, Bishop, Knight]:
              moves.add(Move(source: sq, target: Square(targetSq), promotion: promo))
          else:
            moves.add(Move(source: sq, target: Square(targetSq)))
        
        # En passant
        if targetSq == pos.enPassantSquare:
          moves.add(Move(source: sq, target: Square(targetSq)))

proc generateKnightMoves*(pos: Position, sq: Square, moves: var seq[Move]) =
  let piece = pos.board[sq]
  
  for offset in KnightOffsets:
    let targetSq = sq.int + offset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      let sourceFile = fileOf(sq)
      let sourceRank = rankOf(sq)
      
      # Verify valid knight move (not wrapping around board)
      let fileDiff = abs(targetFile - sourceFile)
      let rankDiff = abs(targetRank - sourceRank)
      
      if (fileDiff == 2 and rankDiff == 1) or (fileDiff == 1 and rankDiff == 2):
        if not pos.isFriendly(Square(targetSq), piece.color):
          moves.add(Move(source: sq, target: Square(targetSq)))

proc generateSlidingMoves*(pos: Position, sq: Square, directions: openArray[int], moves: var seq[Move]) =
  let piece = pos.board[sq]
  
  for dir in directions:
    var currentSq = sq.int + dir
    var prevFile = fileOf(sq)
    
    while currentSq >= 0 and currentSq <= 63:
      let currentFile = currentSq mod 8
      
      # Check for board edge wrapping
      if dir in [-1, 1]:  # Horizontal movement
        if abs(currentFile - prevFile) != 1:
          break
      elif dir in [-9, -7, 7, 9]:  # Diagonal movement
        if abs(currentFile - prevFile) != 1:
          break
      
      if pos.isFriendly(Square(currentSq), piece.color):
        break
      
      moves.add(Move(source: sq, target: Square(currentSq)))
      
      if pos.isEnemy(Square(currentSq), piece.color):
        break
      
      prevFile = currentFile
      currentSq += dir

proc generateKingMoves*(pos: Position, sq: Square, moves: var seq[Move]) =
  let piece = pos.board[sq]
  
  for offset in KingOffsets:
    let targetSq = sq.int + offset
    if targetSq >= 0 and targetSq <= 63:
      let targetFile = targetSq mod 8
      let targetRank = targetSq div 8
      let sourceFile = fileOf(sq)
      let sourceRank = rankOf(sq)
      
      if abs(targetFile - sourceFile) <= 1 and abs(targetRank - sourceRank) <= 1:
        if not pos.isFriendly(Square(targetSq), piece.color):
          moves.add(Move(source: sq, target: Square(targetSq)))
  
  # Castling
  if not pos.isInCheck(piece.color):
    if piece.color == White:
      if pos.castleRights.whiteKingside:
        if pos.isEmpty(Square(5)) and pos.isEmpty(Square(6)):
          if not pos.isAttacked(Square(5), Black) and not pos.isAttacked(Square(6), Black):
            moves.add(Move(source: sq, target: Square(6)))
      
      if pos.castleRights.whiteQueenside:
        if pos.isEmpty(Square(3)) and pos.isEmpty(Square(2)) and pos.isEmpty(Square(1)):
          if not pos.isAttacked(Square(3), Black) and not pos.isAttacked(Square(2), Black):
            moves.add(Move(source: sq, target: Square(2)))
    else:
      if pos.castleRights.blackKingside:
        if pos.isEmpty(Square(61)) and pos.isEmpty(Square(62)):
          if not pos.isAttacked(Square(61), White) and not pos.isAttacked(Square(62), White):
            moves.add(Move(source: sq, target: Square(62)))
      
      if pos.castleRights.blackQueenside:
        if pos.isEmpty(Square(59)) and pos.isEmpty(Square(58)) and pos.isEmpty(Square(57)):
          if not pos.isAttacked(Square(59), White) and not pos.isAttacked(Square(58), White):
            moves.add(Move(source: sq, target: Square(58)))

proc generateAllMoves*(pos: Position): seq[Move] =
  result = @[]
  
  for sq in 0..63:
    let piece = pos.board[sq]
    if piece.kind != Empty and piece.color == pos.sideToMove:
      case piece.kind
      of Pawn:
        pos.generatePawnMoves(Square(sq), result)
      of Knight:
        pos.generateKnightMoves(Square(sq), result)
      of Bishop:
        pos.generateSlidingMoves(Square(sq), BishopDirections, result)
      of Rook:
        pos.generateSlidingMoves(Square(sq), RookDirections, result)
      of Queen:
        pos.generateSlidingMoves(Square(sq), RookDirections & BishopDirections, result)
      of King:
        pos.generateKingMoves(Square(sq), result)
      else:
        discard

proc makeMove*(pos: var Position, move: Move): bool =
  let piece = pos.board[move.source]
  if piece.kind == Empty or piece.color != pos.sideToMove:
    return false
  
  # Store captured piece
  let capturedPiece = pos.board[move.target]
  
  # Handle castling
  if piece.kind == King:
    let fileDiff = fileOf(move.target) - fileOf(move.source)
    if abs(fileDiff) == 2:  # Castling move
      if fileDiff > 0:  # Kingside
        let rookFrom = if piece.color == White: Square(7) else: Square(63)
        let rookTo = if piece.color == White: Square(5) else: Square(61)
        pos.board[rookTo] = pos.board[rookFrom]
        pos.board[rookFrom] = EmptyPiece
      else:  # Queenside
        let rookFrom = if piece.color == White: Square(0) else: Square(56)
        let rookTo = if piece.color == White: Square(3) else: Square(59)
        pos.board[rookTo] = pos.board[rookFrom]
        pos.board[rookFrom] = EmptyPiece
  
  # Handle en passant capture
  if piece.kind == Pawn and move.target == pos.enPassantSquare:
    let captureSquare = if piece.color == White:
      Square(pos.enPassantSquare - 8)
    else:
      Square(pos.enPassantSquare + 8)
    pos.board[captureSquare] = EmptyPiece
  
  # Move the piece
  pos.board[move.target] = piece
  pos.board[move.source] = EmptyPiece
  
  # Handle promotion
  if move.promotion != Empty:
    pos.board[move.target] = (kind: move.promotion, color: piece.color)
  
  # Update en passant square
  if piece.kind == Pawn and abs(rankOf(move.target) - rankOf(move.source)) == 2:
    pos.enPassantSquare = (move.source.int + move.target.int) div 2
  else:
    pos.enPassantSquare = -1
  
  # Update castling rights
  if piece.kind == King:
    if piece.color == White:
      pos.castleRights.whiteKingside = false
      pos.castleRights.whiteQueenside = false
    else:
      pos.castleRights.blackKingside = false
      pos.castleRights.blackQueenside = false
  elif piece.kind == Rook:
    if move.source == 0: pos.castleRights.whiteQueenside = false
    elif move.source == 7: pos.castleRights.whiteKingside = false
    elif move.source == 56: pos.castleRights.blackQueenside = false
    elif move.source == 63: pos.castleRights.blackKingside = false
  
  # Update clocks
  if piece.kind == Pawn or capturedPiece.kind != Empty:
    pos.halfMoveClock = 0
  else:
    pos.halfMoveClock.inc
  
  if pos.sideToMove == Black:
    pos.fullMoveNumber.inc
  
  # Switch side
  pos.sideToMove = opposite(pos.sideToMove)
  
  return true

# Evaluation
proc evaluatePosition*(pos: Position): int =
  result = 0
  
  for sq in 0..63:
    let piece = pos.board[sq]
    if piece.kind != Empty:
      let value = PieceValues[piece.kind]
      if piece.color == White:
        result += value
      else:
        result -= value
  
  # Return from perspective of side to move
  if pos.sideToMove == Black:
    result = -result

# Simple AI - minimax with alpha-beta pruning
proc minimax*(pos: Position, depth: int, alpha: int, beta: int, maximizing: bool): tuple[score: int, move: Move] =
  if depth == 0:
    return (score: evaluatePosition(pos), move: Move())
  
  let moves = generateAllMoves(pos)
  if moves.len == 0:
    if pos.isInCheck(pos.sideToMove):
      return (score: if maximizing: -30000 else: 30000, move: Move())
    else:
      return (score: 0, move: Move())  # Stalemate
  
  var bestMove = moves[0]
  var currentAlpha = alpha
  var currentBeta = beta
  
  if maximizing:
    var maxEval = -100000
    for move in moves:
      var newPos = pos
      if newPos.makeMove(move):
        let eval = minimax(newPos, depth - 1, currentAlpha, currentBeta, false).score
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
      var newPos = pos
      if newPos.makeMove(move):
        let eval = minimax(newPos, depth - 1, currentAlpha, currentBeta, true).score
        if eval < minEval:
          minEval = eval
          bestMove = move
        currentBeta = min(currentBeta, eval)
        if currentBeta <= currentAlpha:
          break
    return (score: minEval, move: bestMove)

proc findBestMove*(pos: Position, depth: int): Move =
  let result = minimax(pos, depth, -100000, 100000, true)
  return result.move

# Game management
proc newGame*(): GameState =
  result.position = parseFEN(StartingFEN)
  result.history = @[]
  result.positionHistory = @[]

proc parseUCIMove*(moveStr: string): Move =
  if moveStr.len < 4:
    return Move(source: Square(0), target: Square(0))
  
  let source = fromAlgebraic(moveStr[0..1])
  let target = fromAlgebraic(moveStr[2..3])
  
  if source < 0 or target < 0:
    return Move(source: Square(0), target: Square(0))
  
  var promotion = Empty
  if moveStr.len == 5:
    promotion = case moveStr[4]
      of 'q': Queen
      of 'r': Rook
      of 'b': Bishop
      of 'n': Knight
      else: Empty
  
  return Move(source: Square(source), target: Square(target), promotion: promotion)

proc moveToUCI*(move: Move): string =
  result = toAlgebraic(move.source) & toAlgebraic(move.target)
  if move.promotion != Empty:
    result.add(case move.promotion
      of Queen: 'q'
      of Rook: 'r'
      of Bishop: 'b'
      of Knight: 'n'
      else: ' ')

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
    
    # Validate move is in legal moves
    let legalMoves = generateAllMoves(game.position)
    var isLegal = false
    for legalMove in legalMoves:
      if legalMove.source == move.source and legalMove.target == move.target:
        if move.promotion == Empty or move.promotion == legalMove.promotion:
          isLegal = true
          break
    
    if not isLegal:
      return "ERROR: Illegal move"
    
    game.positionHistory.add(game.position)
    if game.position.makeMove(move):
      game.history.add(move)
      return "OK: " & parts[1]
    else:
      return "ERROR: Invalid move"
  
  of "undo":
    if game.history.len == 0:
      return "ERROR: No moves to undo"
    
    if game.positionHistory.len > 0:
      game.position = game.positionHistory[^1]
      game.positionHistory.setLen(game.positionHistory.len - 1)
      game.history.setLen(game.history.len - 1)
      return "OK: Move undone"
    else:
      return "ERROR: Cannot undo"
  
  of "fen":
    if parts.len < 2:
      return "ERROR: FEN string required"
    
    try:
      let fenStr = parts[1..^1].join(" ")
      game.position = parseFEN(fenStr)
      game.history = @[]
      game.positionHistory = @[]
      return "OK: Position loaded"
    except:
      return "ERROR: Invalid FEN string"
  
  of "export":
    return "FEN: " & toFEN(game.position)
  
  of "eval":
    let score = evaluatePosition(game.position)
    return "EVAL: " & $score
  
  of "ai":
    let depth = if parts.len > 1: parseInt(parts[1]) else: 3
    let move = findBestMove(game.position, depth)
    
    if move.source == move.target:
      return "ERROR: No legal moves"
    
    game.positionHistory.add(game.position)
    if game.position.makeMove(move):
      game.history.add(move)
      return "AI: " & moveToUCI(move)
    else:
      return "ERROR: AI move failed"
  
  of "perft":
    if parts.len < 2:
      return "ERROR: Depth required"
    
    let depth = parseInt(parts[1])
    
    proc perft(pos: Position, depth: int): int =
      if depth == 0:
        return 1
      
      let moves = generateAllMoves(pos)
      result = 0
      
      for move in moves:
        var newPos = pos
        if newPos.makeMove(move):
          result += perft(newPos, depth - 1)
    
    let nodes = perft(game.position, depth)
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

# Main program
when isMainModule:
  randomize()
  var game = newGame()
  
  echo "Nim Chess Engine"
  echo "Type 'help' for commands\n"
  echo game.position.displayBoard()
  
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
      echo game.position.displayBoard()