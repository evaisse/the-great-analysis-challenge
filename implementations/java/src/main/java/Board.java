import java.util.ArrayList;
import java.util.List;
import java.util.Stack;

public class Board {
    private Piece[][] board;
    private boolean whiteTurn;
    private int enPassantCol;
    private boolean[] castlingRights; // [White King, White Queen, Black King, Black Queen]
    private Stack<Move> moveHistory;
    private int halfMoveClock;
    private int fullMoveNumber;

    public Board() {
        board = new Piece[8][8];
        whiteTurn = true;
        enPassantCol = -1;
        castlingRights = new boolean[]{true, true, true, true};
        moveHistory = new Stack<>();
        halfMoveClock = 0;
        fullMoveNumber = 1;
        initializeBoard();
    }

    private void initializeBoard() {
        // Initialize pawns
        for (int col = 0; col < 8; col++) {
            board[1][col] = new Piece(PieceType.PAWN, PieceColor.BLACK);
            board[6][col] = new Piece(PieceType.PAWN, PieceColor.WHITE);
        }

        // Initialize other pieces
        PieceType[] backRow = {
            PieceType.ROOK, PieceType.KNIGHT, PieceType.BISHOP, PieceType.QUEEN,
            PieceType.KING, PieceType.BISHOP, PieceType.KNIGHT, PieceType.ROOK
        };

        for (int col = 0; col < 8; col++) {
            board[0][col] = new Piece(backRow[col], PieceColor.BLACK);
            board[7][col] = new Piece(backRow[col], PieceColor.WHITE);
        }
    }

    public void display() {
        System.out.println("  a b c d e f g h");
        for (int row = 0; row < 8; row++) {
            System.out.print((8 - row) + " ");
            for (int col = 0; col < 8; col++) {
                Piece piece = board[row][col];
                if (piece == null) {
                    System.out.print(". ");
                } else {
                    System.out.print(piece.toChar() + " ");
                }
            }
            System.out.println((8 - row));
        }
        System.out.println("  a b c d e f g h");
        System.out.println();
        System.out.println((whiteTurn ? "White" : "Black") + " to move");
    }

    public Move parseMove(String moveStr) {
        if (moveStr.length() < 4) return null;

        int fromCol = moveStr.charAt(0) - 'a';
        int fromRow = 8 - (moveStr.charAt(1) - '0');
        int toCol = moveStr.charAt(2) - 'a';
        int toRow = 8 - (moveStr.charAt(3) - '0');

        if (fromCol < 0 || fromCol > 7 || fromRow < 0 || fromRow > 7 ||
            toCol < 0 || toCol > 7 || toRow < 0 || toRow > 7) {
            return null;
        }

        Move move = new Move(fromRow, fromCol, toRow, toCol);

        if (moveStr.length() > 4) {
            char promotionChar = moveStr.charAt(4);
            PieceType promotionType = PieceType.fromSymbol(promotionChar);
            if (promotionType != null && promotionType != PieceType.PAWN && promotionType != PieceType.KING) {
                move.setPromotionPiece(promotionType);
            }
        }

        return move;
    }

    public boolean makeMove(Move move) {
        Piece piece = board[move.getFromRow()][move.getFromCol()];
        
        if (piece == null) return false;
        if ((whiteTurn && piece.getColor() != PieceColor.WHITE) ||
            (!whiteTurn && piece.getColor() != PieceColor.BLACK)) {
            return false;
        }

        if (!isLegalMove(move)) return false;

        // Store state for undo
        move.setPreviousEnPassantCol(enPassantCol);
        move.setPreviousCastlingRights(castlingRights);
        move.setCapturedPiece(board[move.getToRow()][move.getToCol()]);

        // Handle castling
        if (piece.getType() == PieceType.KING && Math.abs(move.getToCol() - move.getFromCol()) == 2) {
            move.setCastling(true);
            if (move.getToCol() == 6) { // Kingside
                Piece rook = board[move.getFromRow()][7];
                board[move.getFromRow()][5] = rook;
                board[move.getFromRow()][7] = null;
            } else { // Queenside
                Piece rook = board[move.getFromRow()][0];
                board[move.getFromRow()][3] = rook;
                board[move.getFromRow()][0] = null;
            }
        }

        // Handle en passant
        if (piece.getType() == PieceType.PAWN && move.getToCol() == enPassantCol &&
            Math.abs(move.getToRow() - move.getFromRow()) == 1 &&
            Math.abs(move.getToCol() - move.getFromCol()) == 1 &&
            board[move.getToRow()][move.getToCol()] == null) {
            move.setEnPassant(true);
            int captureRow = whiteTurn ? move.getToRow() + 1 : move.getToRow() - 1;
            move.setCapturedPiece(board[captureRow][move.getToCol()]);
            board[captureRow][move.getToCol()] = null;
        }

        // Update board
        board[move.getToRow()][move.getToCol()] = piece;
        board[move.getFromRow()][move.getFromCol()] = null;

        // Handle promotion
        if (piece.getType() == PieceType.PAWN &&
            (move.getToRow() == 0 || move.getToRow() == 7)) {
            PieceType promoteTo = move.getPromotionPiece() != null ? 
                move.getPromotionPiece() : PieceType.QUEEN;
            piece.setType(promoteTo);
        }

        // Update en passant
        enPassantCol = -1;
        if (piece.getType() == PieceType.PAWN &&
            Math.abs(move.getToRow() - move.getFromRow()) == 2) {
            enPassantCol = move.getFromCol();
        }

        // Update castling rights
        if (piece.getType() == PieceType.KING) {
            if (whiteTurn) {
                castlingRights[0] = false;
                castlingRights[1] = false;
            } else {
                castlingRights[2] = false;
                castlingRights[3] = false;
            }
        } else if (piece.getType() == PieceType.ROOK) {
            if (move.getFromRow() == 7 && move.getFromCol() == 0) castlingRights[1] = false;
            if (move.getFromRow() == 7 && move.getFromCol() == 7) castlingRights[0] = false;
            if (move.getFromRow() == 0 && move.getFromCol() == 0) castlingRights[3] = false;
            if (move.getFromRow() == 0 && move.getFromCol() == 7) castlingRights[2] = false;
        }

        moveHistory.push(move);
        whiteTurn = !whiteTurn;
        if (whiteTurn) fullMoveNumber++;

        return true;
    }

    public boolean undo() {
        if (moveHistory.isEmpty()) return false;

        Move move = moveHistory.pop();
        whiteTurn = !whiteTurn;
        if (whiteTurn) fullMoveNumber--;

        Piece piece = board[move.getToRow()][move.getToCol()];
        board[move.getFromRow()][move.getFromCol()] = piece;
        board[move.getToRow()][move.getToCol()] = move.getCapturedPiece();

        // Restore promotion
        if (move.getPromotionPiece() != null) {
            piece.setType(PieceType.PAWN);
        }

        // Undo castling
        if (move.isCastling()) {
            if (move.getToCol() == 6) { // Kingside
                Piece rook = board[move.getFromRow()][5];
                board[move.getFromRow()][7] = rook;
                board[move.getFromRow()][5] = null;
            } else { // Queenside
                Piece rook = board[move.getFromRow()][3];
                board[move.getFromRow()][0] = rook;
                board[move.getFromRow()][3] = null;
            }
        }

        // Undo en passant
        if (move.isEnPassant()) {
            int captureRow = whiteTurn ? move.getToRow() + 1 : move.getToRow() - 1;
            board[captureRow][move.getToCol()] = move.getCapturedPiece();
            board[move.getToRow()][move.getToCol()] = null;
        }

        enPassantCol = move.getPreviousEnPassantCol();
        castlingRights = move.getPreviousCastlingRights();

        return true;
    }

    private boolean isLegalMove(Move move) {
        Piece piece = board[move.getFromRow()][move.getFromCol()];
        if (piece == null) return false;

        if (!isValidMove(move)) return false;

        // Check if move leaves king in check
        Piece captured = board[move.getToRow()][move.getToCol()];
        board[move.getToRow()][move.getToCol()] = piece;
        board[move.getFromRow()][move.getFromCol()] = null;

        boolean inCheck = isInCheck(whiteTurn ? PieceColor.WHITE : PieceColor.BLACK);

        board[move.getFromRow()][move.getFromCol()] = piece;
        board[move.getToRow()][move.getToCol()] = captured;

        return !inCheck;
    }

    private boolean isValidMove(Move move) {
        Piece piece = board[move.getFromRow()][move.getFromCol()];
        if (piece == null) return false;

        int fromRow = move.getFromRow();
        int fromCol = move.getFromCol();
        int toRow = move.getToRow();
        int toCol = move.getToCol();
        int rowDiff = toRow - fromRow;
        int colDiff = toCol - fromCol;

        Piece target = board[toRow][toCol];
        if (target != null && target.getColor() == piece.getColor()) return false;

        switch (piece.getType()) {
            case PAWN:
                return isValidPawnMove(move);
            case KNIGHT:
                return (Math.abs(rowDiff) == 2 && Math.abs(colDiff) == 1) ||
                       (Math.abs(rowDiff) == 1 && Math.abs(colDiff) == 2);
            case BISHOP:
                return Math.abs(rowDiff) == Math.abs(colDiff) && isPathClear(move);
            case ROOK:
                return (rowDiff == 0 || colDiff == 0) && isPathClear(move);
            case QUEEN:
                return (Math.abs(rowDiff) == Math.abs(colDiff) || rowDiff == 0 || colDiff == 0) && 
                       isPathClear(move);
            case KING:
                return isValidKingMove(move);
        }
        return false;
    }

    private boolean isValidPawnMove(Move move) {
        Piece piece = board[move.getFromRow()][move.getFromCol()];
        int direction = piece.getColor() == PieceColor.WHITE ? -1 : 1;
        int startRow = piece.getColor() == PieceColor.WHITE ? 6 : 1;
        
        int rowDiff = move.getToRow() - move.getFromRow();
        int colDiff = Math.abs(move.getToCol() - move.getFromCol());

        // Forward move
        if (colDiff == 0 && board[move.getToRow()][move.getToCol()] == null) {
            if (rowDiff == direction) return true;
            if (rowDiff == 2 * direction && move.getFromRow() == startRow &&
                board[move.getFromRow() + direction][move.getFromCol()] == null) {
                return true;
            }
        }

        // Capture
        if (colDiff == 1 && rowDiff == direction) {
            if (board[move.getToRow()][move.getToCol()] != null) return true;
            // En passant
            if (move.getToCol() == enPassantCol) {
                int captureRow = piece.getColor() == PieceColor.WHITE ? move.getToRow() + 1 : move.getToRow() - 1;
                Piece capturedPawn = board[captureRow][move.getToCol()];
                if (capturedPawn != null && capturedPawn.getType() == PieceType.PAWN &&
                    capturedPawn.getColor() != piece.getColor()) {
                    return true;
                }
            }
        }

        return false;
    }

    private boolean isValidKingMove(Move move) {
        int rowDiff = Math.abs(move.getToRow() - move.getFromRow());
        int colDiff = Math.abs(move.getToCol() - move.getFromCol());

        // Normal king move
        if (rowDiff <= 1 && colDiff <= 1) return true;

        // Castling
        if (rowDiff == 0 && colDiff == 2) {
            return canCastle(move);
        }

        return false;
    }

    private boolean canCastle(Move move) {
        Piece piece = board[move.getFromRow()][move.getFromCol()];
        if (piece.getType() != PieceType.KING) return false;

        PieceColor color = piece.getColor();
        boolean isWhite = color == PieceColor.WHITE;
        int row = isWhite ? 7 : 0;

        if (move.getFromRow() != row || move.getFromCol() != 4) return false;
        if (isInCheck(color)) return false;

        boolean isKingside = move.getToCol() == 6;
        int rookCol = isKingside ? 7 : 0;
        int rightIndex = isWhite ? (isKingside ? 0 : 1) : (isKingside ? 2 : 3);

        if (!castlingRights[rightIndex]) return false;

        Piece rook = board[row][rookCol];
        if (rook == null || rook.getType() != PieceType.ROOK) return false;

        // Check path is clear
        int start = Math.min(4, rookCol);
        int end = Math.max(4, rookCol);
        for (int col = start + 1; col < end; col++) {
            if (board[row][col] != null) return false;
        }

        // Check king doesn't pass through check
        int direction = isKingside ? 1 : -1;
        for (int i = 0; i <= 2; i++) {
            int col = 4 + i * direction;
            if (col < 0 || col > 7) continue;
            if (i <= 2 && isSquareAttacked(row, col, color.opposite())) {
                return false;
            }
        }

        return true;
    }

    private boolean isPathClear(Move move) {
        int fromRow = move.getFromRow();
        int fromCol = move.getFromCol();
        int toRow = move.getToRow();
        int toCol = move.getToCol();

        int rowDir = Integer.compare(toRow, fromRow);
        int colDir = Integer.compare(toCol, fromCol);

        int row = fromRow + rowDir;
        int col = fromCol + colDir;

        while (row != toRow || col != toCol) {
            if (board[row][col] != null) return false;
            row += rowDir;
            col += colDir;
        }

        return true;
    }

    public boolean isInCheck(PieceColor color) {
        int kingRow = -1, kingCol = -1;
        for (int row = 0; row < 8; row++) {
            for (int col = 0; col < 8; col++) {
                Piece piece = board[row][col];
                if (piece != null && piece.getType() == PieceType.KING && piece.getColor() == color) {
                    kingRow = row;
                    kingCol = col;
                    break;
                }
            }
            if (kingRow != -1) break;
        }

        return isSquareAttacked(kingRow, kingCol, color.opposite());
    }

    private boolean isSquareAttacked(int row, int col, PieceColor attacker) {
        for (int r = 0; r < 8; r++) {
            for (int c = 0; c < 8; c++) {
                Piece piece = board[r][c];
                if (piece != null && piece.getColor() == attacker) {
                    Move testMove = new Move(r, c, row, col);
                    if (piece.getType() == PieceType.KING) {
                        if (Math.abs(row - r) <= 1 && Math.abs(col - c) <= 1) return true;
                    } else if (isValidMove(testMove)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    public List<Move> generateLegalMoves() {
        List<Move> moves = new ArrayList<>();
        PieceColor currentColor = whiteTurn ? PieceColor.WHITE : PieceColor.BLACK;

        for (int fromRow = 0; fromRow < 8; fromRow++) {
            for (int fromCol = 0; fromCol < 8; fromCol++) {
                Piece piece = board[fromRow][fromCol];
                if (piece == null || piece.getColor() != currentColor) continue;

                for (int toRow = 0; toRow < 8; toRow++) {
                    for (int toCol = 0; toCol < 8; toCol++) {
                        Move move = new Move(fromRow, fromCol, toRow, toCol);
                        if (isLegalMove(move)) {
                            moves.add(move);
                        }
                    }
                }
            }
        }

        return moves;
    }

    public GameState getGameState() {
        PieceColor currentColor = whiteTurn ? PieceColor.WHITE : PieceColor.BLACK;
        boolean inCheck = isInCheck(currentColor);
        boolean hasLegalMoves = !generateLegalMoves().isEmpty();

        if (!hasLegalMoves) {
            return inCheck ? GameState.CHECKMATE : GameState.STALEMATE;
        }

        return inCheck ? GameState.CHECK : GameState.PLAYING;
    }

    public int evaluate() {
        int score = 0;

        for (int row = 0; row < 8; row++) {
            for (int col = 0; col < 8; col++) {
                Piece piece = board[row][col];
                if (piece == null) continue;

                int value = piece.getType().getValue();
                
                // Add position bonuses
                if (piece.getType() == PieceType.PAWN) {
                    int advancement = piece.getColor() == PieceColor.WHITE ? (6 - row) : (row - 1);
                    value += advancement * 5;
                }
                
                // Center control bonus
                if ((row == 3 || row == 4) && (col == 3 || col == 4)) {
                    value += 10;
                }

                if (piece.getColor() == PieceColor.WHITE) {
                    score += value;
                } else {
                    score -= value;
                }
            }
        }

        return whiteTurn ? score : -score;
    }

    public long perft(int depth) {
        if (depth == 0) return 1;

        List<Move> moves = generateLegalMoves();
        long nodes = 0;

        for (Move move : moves) {
            makeMove(move);
            nodes += perft(depth - 1);
            undo();
        }

        return nodes;
    }

    public String toFEN() {
        StringBuilder fen = new StringBuilder();

        // Board position
        for (int row = 0; row < 8; row++) {
            int empty = 0;
            for (int col = 0; col < 8; col++) {
                Piece piece = board[row][col];
                if (piece == null) {
                    empty++;
                } else {
                    if (empty > 0) {
                        fen.append(empty);
                        empty = 0;
                    }
                    fen.append(piece.toChar());
                }
            }
            if (empty > 0) fen.append(empty);
            if (row < 7) fen.append('/');
        }

        // Active color
        fen.append(' ').append(whiteTurn ? 'w' : 'b');

        // Castling rights
        fen.append(' ');
        String castling = "";
        if (castlingRights[0]) castling += 'K';
        if (castlingRights[1]) castling += 'Q';
        if (castlingRights[2]) castling += 'k';
        if (castlingRights[3]) castling += 'q';
        fen.append(castling.isEmpty() ? "-" : castling);

        // En passant
        fen.append(' ');
        if (enPassantCol == -1) {
            fen.append('-');
        } else {
            int row = whiteTurn ? 2 : 5;
            fen.append((char)('a' + enPassantCol)).append(8 - row);
        }

        // Move counters
        fen.append(' ').append(halfMoveClock);
        fen.append(' ').append(fullMoveNumber);

        return fen.toString();
    }

    public boolean fromFEN(String fen) {
        try {
            String[] parts = fen.trim().split("\\s+");
            if (parts.length < 4) return false;

            // Clear board
            board = new Piece[8][8];

            // Parse board
            String[] ranks = parts[0].split("/");
            if (ranks.length != 8) return false;

            for (int row = 0; row < 8; row++) {
                int col = 0;
                for (char c : ranks[row].toCharArray()) {
                    if (Character.isDigit(c)) {
                        col += c - '0';
                    } else {
                        Piece piece = Piece.fromChar(c);
                        if (piece == null) return false;
                        board[row][col] = piece;
                        col++;
                    }
                }
            }

            // Parse active color
            whiteTurn = parts[1].equals("w");

            // Parse castling rights
            castlingRights = new boolean[4];
            if (!parts[2].equals("-")) {
                for (char c : parts[2].toCharArray()) {
                    switch (c) {
                        case 'K': castlingRights[0] = true; break;
                        case 'Q': castlingRights[1] = true; break;
                        case 'k': castlingRights[2] = true; break;
                        case 'q': castlingRights[3] = true; break;
                    }
                }
            }

            // Parse en passant
            enPassantCol = -1;
            if (!parts[3].equals("-")) {
                enPassantCol = parts[3].charAt(0) - 'a';
            }

            // Parse move counters
            if (parts.length > 4) {
                halfMoveClock = Integer.parseInt(parts[4]);
            }
            if (parts.length > 5) {
                fullMoveNumber = Integer.parseInt(parts[5]);
            }

            moveHistory.clear();
            return true;

        } catch (Exception e) {
            return false;
        }
    }

    public boolean isWhiteTurn() {
        return whiteTurn;
    }

    public Piece getPiece(int row, int col) {
        return board[row][col];
    }
}
