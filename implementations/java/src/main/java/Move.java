public class Move {
    private int fromRow;
    private int fromCol;
    private int toRow;
    private int toCol;
    private PieceType promotionPiece;
    private Piece capturedPiece;
    private boolean isCastling;
    private boolean isEnPassant;
    private int previousEnPassantCol;
    private boolean[] previousCastlingRights;

    public Move(int fromRow, int fromCol, int toRow, int toCol) {
        this.fromRow = fromRow;
        this.fromCol = fromCol;
        this.toRow = toRow;
        this.toCol = toCol;
        this.promotionPiece = null;
        this.capturedPiece = null;
        this.isCastling = false;
        this.isEnPassant = false;
        this.previousEnPassantCol = -1;
        this.previousCastlingRights = new boolean[4];
    }

    public int getFromRow() { return fromRow; }
    public int getFromCol() { return fromCol; }
    public int getToRow() { return toRow; }
    public int getToCol() { return toCol; }
    public PieceType getPromotionPiece() { return promotionPiece; }
    public void setPromotionPiece(PieceType piece) { this.promotionPiece = piece; }
    public Piece getCapturedPiece() { return capturedPiece; }
    public void setCapturedPiece(Piece piece) { this.capturedPiece = piece; }
    public boolean isCastling() { return isCastling; }
    public void setCastling(boolean castling) { this.isCastling = castling; }
    public boolean isEnPassant() { return isEnPassant; }
    public void setEnPassant(boolean enPassant) { this.isEnPassant = enPassant; }
    public int getPreviousEnPassantCol() { return previousEnPassantCol; }
    public void setPreviousEnPassantCol(int col) { this.previousEnPassantCol = col; }
    public boolean[] getPreviousCastlingRights() { return previousCastlingRights; }
    public void setPreviousCastlingRights(boolean[] rights) {
        System.arraycopy(rights, 0, this.previousCastlingRights, 0, 4);
    }

    @Override
    public String toString() {
        String from = "" + (char)('a' + fromCol) + (8 - fromRow);
        String to = "" + (char)('a' + toCol) + (8 - toRow);
        if (promotionPiece != null) {
            return from + to + promotionPiece.getSymbol();
        }
        return from + to;
    }
}
