// Main chess engine with CLI interface

import kotlin.system.measureTimeMillis

class ChessEngine {
    private val board = Board()
    private val moveGenerator = MoveGenerator()
    private val fenParser = FenParser()
    private val ai = AI()
    private val perft = Perft()
    
    fun run() {
        println(board)
        
        while (true) {
            print("")
            val input = readlnOrNull()?.trim() ?: "quit"
            
            if (input.isEmpty()) continue
            
            if (!processCommand(input)) {
                break
            }
        }
    }
    
    private fun processCommand(command: String): Boolean {
        val parts = command.split(" ")
        if (parts.isEmpty()) return true
        
        when (parts[0].lowercase()) {
            "move" -> {
                if (parts.size > 1) {
                    handleMove(parts[1])
                } else {
                    println("ERROR: Invalid move format")
                }
            }
            "undo" -> handleUndo()
            "new" -> handleNew()
            "ai" -> {
                if (parts.size > 1) {
                    handleAi(parts[1])
                } else {
                    println("ERROR: AI depth must be 1-5")
                }
            }
            "fen" -> {
                if (parts.size > 1) {
                    val fenString = parts.drop(1).joinToString(" ")
                    handleFen(fenString)
                } else {
                    println("ERROR: Invalid FEN string")
                }
            }
            "export" -> handleExport()
            "eval" -> handleEval()
            "perft" -> {
                if (parts.size > 1) {
                    handlePerft(parts[1])
                } else {
                    println("ERROR: Invalid perft depth")
                }
            }
            "help" -> handleHelp()
            "quit" -> return false
            else -> println("ERROR: Invalid command")
        }
        
        return true
    }
    
    private fun handleMove(moveStr: String) {
        if (moveStr.length < 4) {
            println("ERROR: Invalid move format")
            return
        }
        
        val fromStr = moveStr.substring(0, 2)
        val toStr = moveStr.substring(2, 4)
        val promotionStr = if (moveStr.length > 4) moveStr.substring(4, 5) else null
        
        val fromSquare = algebraicToSquare(fromStr)
        val toSquare = algebraicToSquare(toStr)
        
        if (fromSquare == null || toSquare == null) {
            println("ERROR: Invalid move format")
            return
        }
        
        val piece = board.getPiece(fromSquare)
        if (piece == null) {
            println("ERROR: No piece at source square")
            return
        }
        
        if (piece.color != board.getTurn()) {
            println("ERROR: Wrong color piece")
            return
        }
        
        val legalMoves = moveGenerator.getLegalMoves(board.getGameState(), board.getTurn())
        val matchingMove = findMatchingMove(legalMoves, fromSquare, toSquare, promotionStr)
        
        if (matchingMove != null) {
            board.makeMove(matchingMove)
            println("OK: $moveStr")
            println(board)
            checkGameEnd()
        } else {
            if (moveGenerator.isInCheck(board.getGameState(), board.getTurn())) {
                println("ERROR: King would be in check")
            } else {
                println("ERROR: Illegal move")
            }
        }
    }
    
    private fun findMatchingMove(moves: List<Move>, from: Square, to: Square, promotionStr: String?): Move? {
        return moves.find { move ->
            move.from == from && move.to == to &&
            when {
                move.promotion != null && promotionStr != null -> {
                    val promoType = PieceType.fromChar(promotionStr[0])
                    move.promotion == promoType
                }
                move.promotion == null && promotionStr == null -> true
                move.promotion == PieceType.QUEEN && promotionStr == null -> true // Default to queen
                else -> false
            }
        }
    }
    
    private fun handleUndo() {
        val move = board.undoMove()
        if (move != null) {
            println("Move undone")
            println(board)
        } else {
            println("ERROR: No moves to undo")
        }
    }
    
    private fun handleNew() {
        board.reset()
        println("New game started")
        println(board)
    }
    
    private fun handleAi(depthStr: String) {
        val depth = depthStr.toIntOrNull()
        if (depth == null || depth < 1 || depth > 5) {
            println("ERROR: AI depth must be 1-5")
            return
        }
        
        val result = ai.findBestMove(board, depth)
        
        if (result.bestMove != null) {
            val moveStr = result.bestMove.toString()
            board.makeMove(result.bestMove)
            println("AI: $moveStr (depth=$depth, eval=${result.evaluation}, time=${result.timeMs}ms)")
            println(board)
            checkGameEnd()
        } else {
            println("ERROR: No legal moves available")
        }
    }
    
    private fun handleFen(fenString: String) {
        val result = fenParser.parseFen(board, fenString)
        if (result.isSuccess) {
            println("Position loaded from FEN")
            println(board)
        } else {
            println(result.exceptionOrNull()?.message ?: "ERROR: Invalid FEN string")
        }
    }
    
    private fun handleExport() {
        val fen = fenParser.exportFen(board)
        println("FEN: $fen")
    }
    
    private fun handleEval() {
        val result = ai.findBestMove(board, 1)
        println("Position evaluation: ${result.evaluation}")
    }
    
    private fun handlePerft(depthStr: String) {
        val depth = depthStr.toIntOrNull()
        if (depth == null || depth < 1) {
            println("ERROR: Invalid perft depth")
            return
        }
        
        val timeMs = measureTimeMillis {
            val nodes = perft.perft(board.getGameState(), depth)
            println("Perft($depth): $nodes nodes")
        }
        println("Time: ${timeMs}ms")
    }
    
    private fun handleHelp() {
        println("Available commands:")
        println("  move <from><to>[promotion] - Make a move (e.g., e2e4, e7e8Q)")
        println("  undo - Undo the last move")
        println("  new - Start a new game")
        println("  ai <depth> - Let AI make a move (depth 1-5)")
        println("  fen <string> - Load position from FEN")
        println("  export - Export current position as FEN")
        println("  eval - Evaluate current position")
        println("  perft <depth> - Run performance test")
        println("  help - Show this help message")
        println("  quit - Exit the program")
    }
    
    private fun checkGameEnd() {
        val color = board.getTurn()
        val legalMoves = moveGenerator.getLegalMoves(board.getGameState(), color)
        
        if (legalMoves.isEmpty()) {
            if (moveGenerator.isInCheck(board.getGameState(), color)) {
                val winner = if (color == Color.WHITE) "Black" else "White"
                println("CHECKMATE: $winner wins")
            } else {
                println("STALEMATE: Draw")
            }
        }
    }
}

fun main() {
    val engine = ChessEngine()
    engine.run()
}