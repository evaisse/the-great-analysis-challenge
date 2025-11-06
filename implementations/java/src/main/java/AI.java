import java.util.List;

public class AI {
    private static final int CHECKMATE_SCORE = 100000;

    public static Move findBestMove(Board board, int depth) {
        List<Move> legalMoves = board.generateLegalMoves();
        if (legalMoves.isEmpty()) return null;

        Move bestMove = null;
        int bestScore = Integer.MIN_VALUE;
        int alpha = Integer.MIN_VALUE;
        int beta = Integer.MAX_VALUE;

        for (Move move : legalMoves) {
            board.makeMove(move);
            int score = -minimax(board, depth - 1, -beta, -alpha);
            board.undo();

            if (score > bestScore) {
                bestScore = score;
                bestMove = move;
            }

            alpha = Math.max(alpha, score);
        }

        return bestMove;
    }

    private static int minimax(Board board, int depth, int alpha, int beta) {
        if (depth == 0) {
            return board.evaluate();
        }

        List<Move> legalMoves = board.generateLegalMoves();
        
        if (legalMoves.isEmpty()) {
            PieceColor currentColor = board.isWhiteTurn() ? PieceColor.WHITE : PieceColor.BLACK;
            if (board.isInCheck(currentColor)) {
                return -CHECKMATE_SCORE;
            }
            return 0; // Stalemate
        }

        int maxScore = Integer.MIN_VALUE;

        for (Move move : legalMoves) {
            board.makeMove(move);
            int score = -minimax(board, depth - 1, -beta, -alpha);
            board.undo();

            maxScore = Math.max(maxScore, score);
            alpha = Math.max(alpha, score);

            if (alpha >= beta) {
                break; // Beta cutoff
            }
        }

        return maxScore;
    }
}
