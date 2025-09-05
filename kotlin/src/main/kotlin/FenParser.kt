// FEN parsing and export functionality

class FenParser {
    
    fun parseFen(board: Board, fenString: String): Result<Unit> {
        try {
            val parts = fenString.split(" ")
            if (parts.size < 4) {
                return Result.failure(Exception("ERROR: Invalid FEN string"))
            }
            
            val pieces = parts[0]
            val turn = parts[1]
            val castling = parts[2]
            val enPassant = parts[3]
            val halfmove = parts.getOrNull(4) ?: "0"
            val fullmove = parts.getOrNull(5) ?: "1"
            
            // Clear board
            val gameBoard = Array<Piece?>(64) { null }
            
            // Parse piece positions
            var square = 56 // Start at a8 (top-left)
            for (char in pieces) {
                when (char) {
                    '/' -> square -= 16 // Move to next rank
                    in '1'..'8' -> {
                        val emptySquares = char.digitToInt()
                        square += emptySquares
                    }
                    else -> {
                        val piece = Piece.fromChar(char)
                        if (piece != null) {
                            gameBoard[square] = piece
                            square++
                        }
                    }
                }
            }
            
            // Parse turn
            val color = when (turn) {
                "w" -> Color.WHITE
                "b" -> Color.BLACK
                else -> return Result.failure(Exception("ERROR: Invalid FEN string"))
            }
            
            // Parse castling rights
            val rights = parseCastlingRights(castling)
            
            // Parse en passant target
            val enPassantTarget = if (enPassant != "-") {
                algebraicToSquare(enPassant)
            } else {
                null
            }
            
            // Parse move counters
            val halfmoveClock = halfmove.toIntOrNull() ?: 0
            val fullmoveNumber = fullmove.toIntOrNull() ?: 1
            
            val newState = GameState(
                board = gameBoard,
                turn = color,
                castlingRights = rights,
                enPassantTarget = enPassantTarget,
                halfmoveClock = halfmoveClock,
                fullmoveNumber = fullmoveNumber
            )
            
            board.setGameState(newState)
            return Result.success(Unit)
            
        } catch (e: Exception) {
            return Result.failure(Exception("ERROR: Invalid FEN string"))
        }
    }
    
    private fun parseCastlingRights(castlingString: String): CastlingRights {
        return if (castlingString == "-") {
            CastlingRights.none()
        } else {
            CastlingRights(
                whiteKingside = castlingString.contains('K'),
                whiteQueenside = castlingString.contains('Q'),
                blackKingside = castlingString.contains('k'),
                blackQueenside = castlingString.contains('q')
            )
        }
    }
    
    fun exportFen(board: Board): String {
        val gameState = board.getGameState()
        
        val pieces = getPiecesString(gameState)
        val turn = if (gameState.turn == Color.WHITE) "w" else "b"
        val castling = getCastlingString(gameState.castlingRights)
        val enPassant = getEnPassantString(gameState.enPassantTarget)
        
        return "$pieces $turn $castling $enPassant ${gameState.halfmoveClock} ${gameState.fullmoveNumber}"
    }
    
    private fun getPiecesString(gameState: GameState): String {
        val sb = StringBuilder()
        
        for (rank in 7 downTo 0) {
            var emptyCount = 0
            
            for (file in 0..7) {
                val square = rank * 8 + file
                val piece = gameState.board[square]
                
                if (piece != null) {
                    if (emptyCount > 0) {
                        sb.append(emptyCount)
                        emptyCount = 0
                    }
                    sb.append(piece.toChar())
                } else {
                    emptyCount++
                }
            }
            
            if (emptyCount > 0) {
                sb.append(emptyCount)
            }
            
            if (rank > 0) {
                sb.append('/')
            }
        }
        
        return sb.toString()
    }
    
    private fun getCastlingString(rights: CastlingRights): String {
        val sb = StringBuilder()
        
        if (rights.whiteKingside) sb.append('K')
        if (rights.whiteQueenside) sb.append('Q')
        if (rights.blackKingside) sb.append('k')
        if (rights.blackQueenside) sb.append('q')
        
        return if (sb.isEmpty()) "-" else sb.toString()
    }
    
    private fun getEnPassantString(enPassantTarget: Square?): String {
        return enPassantTarget?.let { squareToAlgebraic(it) } ?: "-"
    }
}