public class Piece {
    private PieceType type;
    private PieceColor color;

    public Piece(PieceType type, PieceColor color) {
        this.type = type;
        this.color = color;
    }

    public PieceType getType() {
        return type;
    }

    public void setType(PieceType type) {
        this.type = type;
    }

    public PieceColor getColor() {
        return color;
    }

    public char toChar() {
        char symbol = type.getSymbol();
        return color == PieceColor.WHITE ? symbol : Character.toLowerCase(symbol);
    }

    public static Piece fromChar(char c) {
        PieceType type = PieceType.fromSymbol(c);
        if (type == null) return null;
        PieceColor color = Character.isUpperCase(c) ? PieceColor.WHITE : PieceColor.BLACK;
        return new Piece(type, color);
    }

    public Piece copy() {
        return new Piece(type, color);
    }

    @Override
    public String toString() {
        return String.valueOf(toChar());
    }
}
