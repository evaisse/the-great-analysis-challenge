public enum PieceType {
    PAWN('P', 100),
    KNIGHT('N', 320),
    BISHOP('B', 330),
    ROOK('R', 500),
    QUEEN('Q', 900),
    KING('K', 20000);

    private final char symbol;
    private final int value;

    PieceType(char symbol, int value) {
        this.symbol = symbol;
        this.value = value;
    }

    public char getSymbol() {
        return symbol;
    }

    public int getValue() {
        return value;
    }

    public static PieceType fromSymbol(char symbol) {
        char upper = Character.toUpperCase(symbol);
        for (PieceType type : values()) {
            if (type.symbol == upper) {
                return type;
            }
        }
        return null;
    }
}
