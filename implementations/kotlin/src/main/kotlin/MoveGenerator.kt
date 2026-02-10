// Move generation and validation

class MoveGenerator {
    
    fun generateMoves(gameState: GameState, color: Color): List<Move> {
        val moves = mutableListOf<Move>()
        
        for (square in 0..63) {
            val piece = gameState.board[square]
            if (piece != null && piece.color == color) {
                moves.addAll(generatePieceMoves(gameState, square, piece))
            }
        }
        
        return moves
    }
    
    private fun generatePieceMoves(gameState: GameState, from: Square, piece: Piece, includeCastling: Boolean = true): List<Move> {
        return when (piece.type) {
            PieceType.PAWN -> generatePawnMoves(gameState, from, piece.color)
            PieceType.KNIGHT -> generateKnightMoves(gameState, from, piece.color)
            PieceType.BISHOP -> generateBishopMoves(gameState, from, piece.color)
            PieceType.ROOK -> generateRookMoves(gameState, from, piece.color)
            PieceType.QUEEN -> generateQueenMoves(gameState, from, piece.color)
            PieceType.KING -> generateKingMoves(gameState, from, piece.color, includeCastling)
        }
    }
    
    private fun generatePawnMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        val moves = mutableListOf<Move>()
        val direction = if (color == Color.WHITE) 8 else -8
        val startRank = if (color == Color.WHITE) 1 else 6
        val promotionRank = if (color == Color.WHITE) 7 else 0
        
        val rank = from / 8
        val file = from % 8
        
        // One square forward
        val oneForward = from + direction
        if (isValidSquare(oneForward) && gameState.board[oneForward] == null) {
            if (oneForward / 8 == promotionRank) {
                // Promotion moves
                for (promotion in listOf(PieceType.QUEEN, PieceType.ROOK, PieceType.BISHOP, PieceType.KNIGHT)) {
                    moves.add(Move(from, oneForward, PieceType.PAWN, null, promotion))
                }
            } else {
                moves.add(Move(from, oneForward, PieceType.PAWN))
            }
            
            // Two squares forward from starting position
            if (rank == startRank) {
                val twoForward = from + 2 * direction
                if (isValidSquare(twoForward) && gameState.board[twoForward] == null) {
                    moves.add(Move(from, twoForward, PieceType.PAWN))
                }
            }
        }
        
        // Captures
        for (offset in listOf(direction - 1, direction + 1)) {
            val to = from + offset
            val toFile = to % 8
            
            if (isValidSquare(to) && kotlin.math.abs(toFile - file) == 1) {
                val target = gameState.board[to]
                if (target != null && target.color != color) {
                    if (to / 8 == promotionRank) {
                        // Promotion captures
                        for (promotion in listOf(PieceType.QUEEN, PieceType.ROOK, PieceType.BISHOP, PieceType.KNIGHT)) {
                            moves.add(Move(from, to, PieceType.PAWN, target.type, promotion))
                        }
                    } else {
                        moves.add(Move(from, to, PieceType.PAWN, target.type))
                    }
                }
            }
        }
        
        // En passant
        val enPassantTarget = gameState.enPassantTarget
        if (enPassantTarget != null) {
            val expectedRank = if (color == Color.WHITE) 4 else 3
            if (rank == expectedRank) {
                for (offset in listOf(direction - 1, direction + 1)) {
                    val to = from + offset
                    if (to == enPassantTarget) {
                        moves.add(Move(from, to, PieceType.PAWN, PieceType.PAWN, null, false, true))
                    }
                }
            }
        }
        
        return moves
    }
    
    private fun generateKnightMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        val moves = mutableListOf<Move>()
        val offsets = listOf(-17, -15, -10, -6, 6, 10, 15, 17)
        val file = from % 8
        
        for (offset in offsets) {
            val to = from + offset
            val toFile = to % 8
            
            if (isValidSquare(to) && kotlin.math.abs(toFile - file) <= 2) {
                val target = gameState.board[to]
                if (target == null) {
                    moves.add(Move(from, to, PieceType.KNIGHT))
                } else if (target.color != color) {
                    moves.add(Move(from, to, PieceType.KNIGHT, target.type))
                }
            }
        }
        
        return moves
    }
    
    private fun generateSlidingMoves(gameState: GameState, from: Square, color: Color, directions: List<Int>, pieceType: PieceType): List<Move> {
        val moves = mutableListOf<Move>()
        
        for (direction in directions) {
            var to = from + direction
            var prevFile = from % 8
            
            while (isValidSquare(to)) {
                val toFile = to % 8
                val fileDiff = kotlin.math.abs(toFile - prevFile)
                
                if (kotlin.math.abs(direction) % 8 == 0) {
                    // Vertical moves
                    if (fileDiff != 0) break
                } else {
                    // Horizontal or diagonal moves
                    if (fileDiff != 1) break
                }
                
                val target = gameState.board[to]
                if (target == null) {
                    moves.add(Move(from, to, pieceType))
                } else {
                    if (target.color != color) {
                        moves.add(Move(from, to, pieceType, target.type))
                    }
                    break
                }
                
                prevFile = toFile
                to += direction
            }
        }
        
        return moves
    }
    
    private fun generateBishopMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        return generateSlidingMoves(gameState, from, color, listOf(-9, -7, 7, 9), PieceType.BISHOP)
    }
    
    private fun generateRookMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        return generateSlidingMoves(gameState, from, color, listOf(-8, -1, 1, 8), PieceType.ROOK)
    }
    
    private fun generateQueenMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        return generateSlidingMoves(gameState, from, color, listOf(-9, -8, -7, -1, 1, 7, 8, 9), PieceType.QUEEN)
    }
    
    private fun generateKingMoves(gameState: GameState, from: Square, color: Color, includeCastling: Boolean = true): List<Move> {
        val moves = mutableListOf<Move>()
        val offsets = listOf(-9, -8, -7, -1, 1, 7, 8, 9)
        val file = from % 8
        
        for (offset in offsets) {
            val to = from + offset
            val toFile = to % 8
            
            if (isValidSquare(to) && kotlin.math.abs(toFile - file) <= 1) {
                val target = gameState.board[to]
                if (target == null) {
                    moves.add(Move(from, to, PieceType.KING))
                } else if (target.color != color) {
                    moves.add(Move(from, to, PieceType.KING, target.type))
                }
            }
        }
        
        // Castling
        if (includeCastling) {
            moves.addAll(generateCastlingMoves(gameState, from, color))
        }
        
        return moves
    }
    
    private fun generateCastlingMoves(gameState: GameState, from: Square, color: Color): List<Move> {
        val moves = mutableListOf<Move>()
        
        when (color to from) {
            Color.WHITE to 4 -> {
                // White kingside
                if (gameState.castlingRights.whiteKingside &&
                    gameState.board[5] == null &&
                    gameState.board[6] == null &&
                    isRookAt(gameState, 7, Color.WHITE) &&
                    !isSquareAttacked(gameState, 4, Color.BLACK) &&
                    !isSquareAttacked(gameState, 5, Color.BLACK) &&
                    !isSquareAttacked(gameState, 6, Color.BLACK)) {
                    moves.add(Move(4, 6, PieceType.KING, null, null, true))
                }
                
                // White queenside
                if (gameState.castlingRights.whiteQueenside &&
                    gameState.board[3] == null &&
                    gameState.board[2] == null &&
                    gameState.board[1] == null &&
                    isRookAt(gameState, 0, Color.WHITE) &&
                    !isSquareAttacked(gameState, 4, Color.BLACK) &&
                    !isSquareAttacked(gameState, 3, Color.BLACK) &&
                    !isSquareAttacked(gameState, 2, Color.BLACK)) {
                    moves.add(Move(4, 2, PieceType.KING, null, null, true))
                }
            }
            Color.BLACK to 60 -> {
                // Black kingside
                if (gameState.castlingRights.blackKingside &&
                    gameState.board[61] == null &&
                    gameState.board[62] == null &&
                    isRookAt(gameState, 63, Color.BLACK) &&
                    !isSquareAttacked(gameState, 60, Color.WHITE) &&
                    !isSquareAttacked(gameState, 61, Color.WHITE) &&
                    !isSquareAttacked(gameState, 62, Color.WHITE)) {
                    moves.add(Move(60, 62, PieceType.KING, null, null, true))
                }
                
                // Black queenside
                if (gameState.castlingRights.blackQueenside &&
                    gameState.board[59] == null &&
                    gameState.board[58] == null &&
                    gameState.board[57] == null &&
                    isRookAt(gameState, 56, Color.BLACK) &&
                    !isSquareAttacked(gameState, 60, Color.WHITE) &&
                    !isSquareAttacked(gameState, 59, Color.WHITE) &&
                    !isSquareAttacked(gameState, 58, Color.WHITE)) {
                    moves.add(Move(60, 58, PieceType.KING, null, null, true))
                }
            }
        }
        
        return moves
    }
    
    private fun isRookAt(gameState: GameState, square: Square, color: Color): Boolean {
        val piece = gameState.board[square]
        return piece != null && piece.type == PieceType.ROOK && piece.color == color
    }
    
    fun isSquareAttacked(gameState: GameState, square: Square, byColor: Color): Boolean {
        val squareRank = square / 8
        val squareFile = square % 8
        
        for (fromSquare in 0..63) {
            val piece = gameState.board[fromSquare]
            if (piece != null && piece.color == byColor) {
                if (piece.type == PieceType.PAWN) {
                    val direction = if (byColor == Color.WHITE) 8 else -8
                    val fromFile = fromSquare % 8
                    
                    if (square == fromSquare + direction - 1 && kotlin.math.abs(squareFile - fromFile) == 1) return true
                    if (square == fromSquare + direction + 1 && kotlin.math.abs(squareFile - fromFile) == 1) return true
                    continue
                }
                
                // IMPORTANT: When checking for attacks, we must NOT include castling to avoid infinite recursion
                val moves = generatePieceMoves(gameState, fromSquare, piece, false)
                if (moves.any { it.to == square }) {
                    return true
                }
            }
        }
        return false
    }
    
    fun isInCheck(gameState: GameState, color: Color): Boolean {
        for (square in 0..63) {
            val piece = gameState.board[square]
            if (piece != null && piece.type == PieceType.KING && piece.color == color) {
                return isSquareAttacked(gameState, square, color.opposite())
            }
        }
        return false
    }
    
    fun getLegalMoves(gameState: GameState, color: Color): List<Move> {
        val pseudoLegalMoves = generateMoves(gameState, color)
        val legalMoves = mutableListOf<Move>()
        
        for (move in pseudoLegalMoves) {
            val newState = gameState.copy()
            makeMove(newState, move)
            
            if (!isInCheck(newState, color)) {
                legalMoves.add(move)
            }
        }
        
        return legalMoves
    }
    
    private fun makeMove(gameState: GameState, move: Move) {
        val piece = gameState.board[move.from]!!
        
        // Move piece
        gameState.board[move.to] = piece
        gameState.board[move.from] = null
        
        // Handle special moves
        if (move.isCastling) {
            val rank = if (piece.color == Color.WHITE) 0 else 7
            val (rookFrom, rookTo) = if (move.to == rank * 8 + 6) {
                Pair(rank * 8 + 7, rank * 8 + 5)
            } else {
                Pair(rank * 8, rank * 8 + 3)
            }
            
            val rook = gameState.board[rookFrom]
            if (rook != null) {
                gameState.board[rookTo] = rook
                gameState.board[rookFrom] = null
            }
        }
        
        if (move.isEnPassant) {
            val capturedPawnSquare = if (piece.color == Color.WHITE) {
                move.to - 8
            } else {
                move.to + 8
            }
            gameState.board[capturedPawnSquare] = null
        }
        
        if (move.promotion != null) {
            gameState.board[move.to] = Piece(move.promotion, piece.color)
        }
    }
    
    fun isCheckmate(gameState: GameState, color: Color): Boolean {
        return isInCheck(gameState, color) && getLegalMoves(gameState, color).isEmpty()
    }
    
    fun isStalemate(gameState: GameState, color: Color): Boolean {
        return !isInCheck(gameState, color) && getLegalMoves(gameState, color).isEmpty()
    }
}