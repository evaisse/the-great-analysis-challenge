import Foundation

// Represents the color of a piece
enum Color {
    case white
    case black
}

// Represents the type of a piece
enum PieceType {
    case king
    case queen
    case rook
    case bishop
    case knight
    case pawn
}

// Represents a single chess piece
struct Piece {
    let type: PieceType
    let color: Color

    var character: Character {
        switch type {
        case .king: return color == .white ? "K" : "k"
        case .queen: return color == .white ? "Q" : "q"
        case .rook: return color == .white ? "R" : "r"
        case .bishop: return color == .white ? "B" : "b"
        case .knight: return color == .white ? "N" : "n"
        case .pawn: return color == .white ? "P" : "p"
        }
    }
}

// Represents a move from a source square to a destination square
struct Move: Equatable {
    let from: (Int, Int)
    let to: (Int, Int)
    let promotionPiece: PieceType?

    init(from: (Int, Int), to: (Int, Int), promotionPiece: PieceType? = nil) {
        self.from = from
        self.to = to
        self.promotionPiece = promotionPiece
    }

    static func == (lhs: Move, rhs: Move) -> Bool {
        return lhs.from.0 == rhs.from.0 && lhs.from.1 == rhs.from.1 &&
               lhs.to.0 == rhs.to.0 && lhs.to.1 == rhs.to.1 &&
               lhs.promotionPiece == rhs.promotionPiece
    }
}

// Game state for undoing moves
struct GameState {
    let whiteKingSideCastle: Bool
    let whiteQueenSideCastle: Bool
    let blackKingSideCastle: Bool
    let blackQueenSideCastle: Bool
    let enPassantTarget: (Int, Int)?
}

// Represents the game board
struct Board {
    var pieces: [[Piece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    var currentPlayer: Color = .white
    var whiteKingSideCastle: Bool = true
    var whiteQueenSideCastle: Bool = true
    var blackKingSideCastle: Bool = true
    var blackQueenSideCastle: Bool = true
    var enPassantTarget: (Int, Int)? = nil
    var history: [GameState] = []

    init() {
        setupBoard()
    }

    mutating func setupBoard() {
        // Set up the white pieces
        pieces[0] = [
            Piece(type: .rook, color: .white),
            Piece(type: .knight, color: .white),
            Piece(type: .bishop, color: .white),
            Piece(type: .queen, color: .white),
            Piece(type: .king, color: .white),
            Piece(type: .bishop, color: .white),
            Piece(type: .knight, color: .white),
            Piece(type: .rook, color: .white),
        ]
        pieces[1] = Array(repeating: Piece(type: .pawn, color: .white), count: 8)

        // Set up the black pieces
        pieces[6] = Array(repeating: Piece(type: .pawn, color: .black), count: 8)
        pieces[7] = [
            Piece(type: .rook, color: .black),
            Piece(type: .knight, color: .black),
            Piece(type: .bishop, color: .black),
            Piece(type: .queen, color: .black),
            Piece(type: .king, color: .black),
            Piece(type: .bishop, color: .black),
            Piece(type: .knight, color: .black),
            Piece(type: .rook, color: .black),
        ]
    }

    func generateMoves() -> [Move] {
        var moves: [Move] = []
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = pieces[row][col], piece.color == currentPlayer {
                    moves.append(contentsOf: generateMoves(for: piece, at: (row, col)))
                }
            }
        }
        return moves.filter { move in
            var boardCopy = self
            let capturedPiece = boardCopy.pieces[move.to.0][move.to.1]
            boardCopy.makeMove(move)
            return !boardCopy.isInCheck(color: currentPlayer)
        }
    }

    func generateMoves(for piece: Piece, at position: (Int, Int)) -> [Move] {
        switch piece.type {
        case .pawn:
            return generatePawnMoves(from: position)
        case .knight:
            return generateKnightMoves(from: position)
        case .rook:
            return generateRookMoves(from: position)
        case .bishop:
            return generateBishopMoves(from: position)
        case .queen:
            return generateQueenMoves(from: position)
        case .king:
            return generateKingMoves(from: position)
        }
    }

    func generatePawnMoves(from position: (Int, Int)) -> [Move] {
        var moves: [Move] = []
        let (row, col) = position
        let direction = currentPlayer == .white ? 1 : -1
        let isPromotionRank = (currentPlayer == .white && row == 6) || (currentPlayer == .black && row == 1)

        if isPromotionRank {
            // Forward move promotion
            if isWithinBounds(row: row + direction, col: col) && pieces[row + direction][col] == nil {
                for pieceType in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: position, to: (row + direction, col), promotionPiece: pieceType))
                }
            }
            // Capture promotion
            if isWithinBounds(row: row + direction, col: col - 1) {
                if let piece = pieces[row + direction][col - 1], piece.color != currentPlayer {
                    for pieceType in [PieceType.queen, .rook, .bishop, .knight] {
                        moves.append(Move(from: position, to: (row + direction, col - 1), promotionPiece: pieceType))
                    }
                }
            }
            if isWithinBounds(row: row + direction, col: col + 1) {
                if let piece = pieces[row + direction][col + 1], piece.color != currentPlayer {
                    for pieceType in [PieceType.queen, .rook, .bishop, .knight] {
                        moves.append(Move(from: position, to: (row + direction, col + 1), promotionPiece: pieceType))
                    }
                }
            }
        } else {
            // Single square move
            if isWithinBounds(row: row + direction, col: col) && pieces[row + direction][col] == nil {
                moves.append(Move(from: position, to: (row + direction, col)))
            }

            // Double square move
            if (currentPlayer == .white && row == 1) || (currentPlayer == .black && row == 6) {
                if isWithinBounds(row: row + 2 * direction, col: col) && pieces[row + 2 * direction][col] == nil && pieces[row + direction][col] == nil {
                    moves.append(Move(from: position, to: (row + 2 * direction, col)))
                }
            }

            // Captures
            if isWithinBounds(row: row + direction, col: col - 1) {
                if let piece = pieces[row + direction][col - 1], piece.color != currentPlayer {
                    moves.append(Move(from: position, to: (row + direction, col - 1)))
                }
            }
            if isWithinBounds(row: row + direction, col: col + 1) {
                if let piece = pieces[row + direction][col + 1], piece.color != currentPlayer {
                    moves.append(Move(from: position, to: (row + direction, col + 1)))
                }
            }
        }

        // En passant
        if let enPassantTarget = enPassantTarget, row + direction == enPassantTarget.0 && (col - 1 == enPassantTarget.1 || col + 1 == enPassantTarget.1) {
            moves.append(Move(from: position, to: enPassantTarget))
        }

        return moves
    }

    func isWithinBounds(row: Int, col: Int) -> Bool {
        return row >= 0 && row < 8 && col >= 0 && col < 8
    }

    func generateKnightMoves(from position: (Int, Int)) -> [Move] {
        var moves: [Move] = []
        let (row, col) = position
        let knightMoves = [
            (row + 2, col + 1), (row + 2, col - 1),
            (row - 2, col + 1), (row - 2, col - 1),
            (row + 1, col + 2), (row + 1, col - 2),
            (row - 1, col + 2), (row - 1, col - 2),
        ]

        for (newRow, newCol) in knightMoves {
            if isWithinBounds(row: newRow, col: newCol) {
                if let piece = pieces[newRow][newCol] {
                    if piece.color != currentPlayer {
                        moves.append(Move(from: position, to: (newRow, newCol)))
                    }
                } else {
                    moves.append(Move(from: position, to: (newRow, newCol)))
                }
            }
        }

        return moves
    }

    func generateRookMoves(from position: (Int, Int)) -> [Move] {
        return generateSlidingMoves(from: position, directions: [(0, 1), (0, -1), (1, 0), (-1, 0)])
    }

    func generateBishopMoves(from position: (Int, Int)) -> [Move] {
        return generateSlidingMoves(from: position, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])
    }

    func generateQueenMoves(from position: (Int, Int)) -> [Move] {
        return generateSlidingMoves(from: position, directions: [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)])
    }

    func generateSlidingMoves(from position: (Int, Int), directions: [(Int, Int)]) -> [Move] {
        var moves: [Move] = []
        let (row, col) = position

        for (rowDir, colDir) in directions {
            var newRow = row + rowDir
            var newCol = col + colDir
            while isWithinBounds(row: newRow, col: newCol) {
                if let piece = pieces[newRow][newCol] {
                    if piece.color != currentPlayer {
                        moves.append(Move(from: position, to: (newRow, newCol)))
                    }
                    break
                }
                moves.append(Move(from: position, to: (newRow, newCol)))
                newRow += rowDir
                newCol += colDir
            }
        }
        return moves
    }

    func generateKingMoves(from position: (Int, Int)) -> [Move] {
        var moves: [Move] = []
        let (row, col) = position
        let kingMoves = [
            (row + 1, col), (row - 1, col),
            (row, col + 1), (row, col - 1),
            (row + 1, col + 1), (row + 1, col - 1),
            (row - 1, col + 1), (row - 1, col - 1),
        ]

        for (newRow, newCol) in kingMoves {
            if isWithinBounds(row: newRow, col: newCol) {
                if let piece = pieces[newRow][newCol] {
                    if piece.color != currentPlayer {
                        moves.append(Move(from: position, to: (newRow, newCol)))
                    }
                } else {
                    moves.append(Move(from: position, to: (newRow, newCol)))
                }
            }
        }

        // Castling
        if currentPlayer == .white {
            if whiteKingSideCastle && pieces[0][5] == nil && pieces[0][6] == nil &&
               !isSquareAttacked(at: (0, 4), by: .black) && !isSquareAttacked(at: (0, 5), by: .black) && !isSquareAttacked(at: (0, 6), by: .black) {
                moves.append(Move(from: position, to: (0, 6)))
            }
            if whiteQueenSideCastle && pieces[0][1] == nil && pieces[0][2] == nil && pieces[0][3] == nil &&
               !isSquareAttacked(at: (0, 4), by: .black) && !isSquareAttacked(at: (0, 3), by: .black) && !isSquareAttacked(at: (0, 2), by: .black) {
                moves.append(Move(from: position, to: (0, 2)))
            }
        } else {
            if blackKingSideCastle && pieces[7][5] == nil && pieces[7][6] == nil &&
               !isSquareAttacked(at: (7, 4), by: .white) && !isSquareAttacked(at: (7, 5), by: .white) && !isSquareAttacked(at: (7, 6), by: .white) {
                moves.append(Move(from: position, to: (7, 6)))
            }
            if blackQueenSideCastle && pieces[7][1] == nil && pieces[7][2] == nil && pieces[7][3] == nil &&
               !isSquareAttacked(at: (7, 4), by: .white) && !isSquareAttacked(at: (7, 3), by: .white) && !isSquareAttacked(at: (7, 2), by: .white) {
                moves.append(Move(from: position, to: (7, 2)))
            }
        }

        return moves
    }

    func isSquareAttacked(at position: (Int, Int), by color: Color) -> Bool {
        // Check for pawn attacks
        let direction = color == .white ? -1 : 1
        if isWithinBounds(row: position.0 + direction, col: position.1 - 1) {
            if let piece = pieces[position.0 + direction][position.1 - 1], piece.type == .pawn && piece.color == color {
                return true
            }
        }
        if isWithinBounds(row: position.0 + direction, col: position.1 + 1) {
            if let piece = pieces[position.0 + direction][position.1 + 1], piece.type == .pawn && piece.color == color {
                return true
            }
        }

        // Check for knight attacks
        let knightMoves = [
            (position.0 + 2, position.1 + 1), (position.0 + 2, position.1 - 1),
            (position.0 - 2, position.1 + 1), (position.0 - 2, position.1 - 1),
            (position.0 + 1, position.1 + 2), (position.0 + 1, position.1 - 2),
            (position.0 - 1, position.1 + 2), (position.0 - 1, position.1 - 2),
        ]
        for (row, col) in knightMoves {
            if isWithinBounds(row: row, col: col) {
                if let piece = pieces[row][col], piece.type == .knight && piece.color == color {
                    return true
                }
            }
        }

        // Check for sliding piece attacks
        let rookDirections = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        let bishopDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        let queenDirections = rookDirections + bishopDirections
        for (rowDir, colDir) in queenDirections {
            var newRow = position.0 + rowDir
            var newCol = position.1 + colDir
            while isWithinBounds(row: newRow, col: newCol) {
                if let piece = pieces[newRow][newCol] {
                    if piece.color == color {
                        if (piece.type == .rook && rookDirections.contains(where: { $0 == (rowDir, colDir) })) ||
                           (piece.type == .bishop && bishopDirections.contains(where: { $0 == (rowDir, colDir) })) ||
                           piece.type == .queen {
                            return true
                        }
                    }
                    break
                }
                newRow += rowDir
                newCol += colDir
            }
        }

        return false
    }

    func kingPosition(for color: Color) -> (Int, Int)? {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = pieces[row][col], piece.type == .king && piece.color == color {
                    return (row, col)
                }
            }
        }
        return nil
    }

    func isInCheck(color: Color) -> Bool {
        guard let kingPos = kingPosition(for: color) else { return false }
        return isSquareAttacked(at: kingPos, by: color == .white ? .black : .white)
    }

    func isCheckmate() -> Bool {
        return isInCheck(color: currentPlayer) && generateMoves().isEmpty
    }

    func isStalemate() -> Bool {
        return !isInCheck(color: currentPlayer) && generateMoves().isEmpty
    }

    mutating func makeMove(_ move: Move) {
        let gameState = GameState(whiteKingSideCastle: whiteKingSideCastle, whiteQueenSideCastle: whiteQueenSideCastle, blackKingSideCastle: blackKingSideCastle, blackQueenSideCastle: blackQueenSideCastle, enPassantTarget: enPassantTarget)
        history.append(gameState)




        let piece = pieces[move.from.0][move.from.1]
        // Handle castling
        if piece?.type == .king {
            if move.to.1 - move.from.1 == 2 { // Kingside
                pieces[move.from.0][5] = pieces[move.from.0][7]
                pieces[move.from.0][7] = nil
            } else if move.to.1 - move.from.1 == -2 { // Queenside
                pieces[move.from.0][3] = pieces[move.from.0][0]
                pieces[move.from.0][0] = nil
            }
        }

        // Handle en passant
        if piece?.type == .pawn, let ep = enPassantTarget, move.to == ep {
            pieces[move.from.0][move.to.1] = nil
        }

        pieces[move.to.0][move.to.1] = pieces[move.from.0][move.from.1]
        pieces[move.from.0][move.from.1] = nil

        // Handle promotion
        if let promotionPiece = move.promotionPiece {
            pieces[move.to.0][move.to.1] = Piece(type: promotionPiece, color: currentPlayer)
        }

        // Update castling rights
        if piece?.type == .king {
            if currentPlayer == .white {
                whiteKingSideCastle = false
                whiteQueenSideCastle = false
            } else {
                blackKingSideCastle = false
                blackQueenSideCastle = false
            }
        }
        if piece?.type == .rook {
            if move.from == (0, 0) { whiteQueenSideCastle = false }
            if move.from == (0, 7) { whiteKingSideCastle = false }
            if move.from == (7, 0) { blackQueenSideCastle = false }
            if move.from == (7, 7) { blackKingSideCastle = false }
        }

        // Update en passant target
        if piece?.type == .pawn && abs(move.to.0 - move.from.0) == 2 {
            enPassantTarget = ( (move.from.0 + move.to.0) / 2, move.from.1)
        } else {
            enPassantTarget = nil
        }

        currentPlayer = (currentPlayer == .white) ? .black : .white
    }


    func evaluate() -> Int {
        var score = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = pieces[row][col] {
                    score += pieceValue(piece)
                    score += positionalValue(piece, at: (row, col))
                }
            }
        }
        return score
    }

    private func pieceValue(_ piece: Piece) -> Int {
        let value: Int
        switch piece.type {
        case .pawn: value = 100
        case .knight: value = 320
        case .bishop: value = 330
        case .rook: value = 500
        case .queen: value = 900
        case .king: value = 20000
        }
        return piece.color == .white ? value : -value
    }

    private func positionalValue(_ piece: Piece, at position: (Int, Int)) -> Int {
        var score = 0
        let (row, col) = position
        // Center control
        if (row == 3 || row == 4) && (col == 3 || col == 4) {
            score += 10
        }
        // Pawn advancement
        if piece.type == .pawn {
            if piece.color == .white {
                score += 5 * (row - 1)
            } else {
                score += 5 * (6 - row)
            }
        }
        return piece.color == .white ? score : -score
    }

    mutating func undoMove(_ move: Move, capturedPiece: Piece?) {
        let piece = pieces[move.to.0][move.to.1]
        // Handle castling
        if piece?.type == .king {
            if move.to.1 - move.from.1 == 2 { // Kingside
                pieces[move.from.0][7] = pieces[move.from.0][5]
                pieces[move.from.0][5] = nil
            } else if move.to.1 - move.from.1 == -2 { // Queenside
                pieces[move.from.0][0] = pieces[move.from.0][3]
                pieces[move.from.0][3] = nil
            }
        }

        // Handle en passant
        if piece?.type == .pawn && capturedPiece == nil && move.from.1 != move.to.1 {
            let capturedPawnRow = move.from.0
            let capturedPawnCol = move.to.1
            let capturedPawnColor: Color = currentPlayer == .white ? .black : .white
            pieces[capturedPawnRow][capturedPawnCol] = Piece(type: .pawn, color: capturedPawnColor)
        }

        // Handle promotion
        if move.promotionPiece != nil {
            let pawnColor: Color = currentPlayer == .white ? .black : .white
            pieces[move.from.0][move.from.1] = Piece(type: .pawn, color: pawnColor)
        } else {
            pieces[move.from.0][move.from.1] = pieces[move.to.0][move.to.1]
        }

        pieces[move.to.0][move.to.1] = capturedPiece
        currentPlayer = (currentPlayer == .white) ? .black : .white

        if let lastState = history.popLast() {
            whiteKingSideCastle = lastState.whiteKingSideCastle
            whiteQueenSideCastle = lastState.whiteQueenSideCastle
            blackKingSideCastle = lastState.blackKingSideCastle
            blackQueenSideCastle = lastState.blackQueenSideCastle
            enPassantTarget = lastState.enPassantTarget
        }
    }

    func toFen() -> String {
        var fen = ""
        for i in (0...7).reversed() {
            var empty = 0
            for j in 0...7 {
                if let piece = pieces[i][j] {
                    if empty > 0 {
                        fen += "\(empty)"
                        empty = 0
                    }
                    fen += "\(piece.character)"
                } else {
                    empty += 1
                }
            }
            if empty > 0 {
                fen += "\(empty)"
            }
            if i > 0 {
                fen += "/"
            }
        }
        fen += " \(currentPlayer == .white ? "w" : "b")"

        var castlingRights = ""
        if whiteKingSideCastle { castlingRights += "K" }
        if whiteQueenSideCastle { castlingRights += "Q" }
        if blackKingSideCastle { castlingRights += "k" }
        if blackQueenSideCastle { castlingRights += "q" }
        if castlingRights.isEmpty { castlingRights = "-" }
        fen += " \(castlingRights)"

        if let enPassantTarget = enPassantTarget {
            let col = "abcdefgh"[String.Index(utf16Offset: enPassantTarget.1, in: "abcdefgh")]
            let row = enPassantTarget.0 + 1
            fen += " \(col)\(row)"
        } else {
            fen += " -"
        }

        fen += " 0 1"
        return fen
    }

    mutating func loadFen(_ fen: String) {
        let parts = fen.split(separator: " ")
        let ranks = parts[0].split(separator: "/")
        pieces = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        for (i, rank) in ranks.enumerated() {
            var col = 0
            for char in rank {
                if let num = Int(String(char)) {
                    col += num
                } else {
                    let color: Color = char.isUppercase ? .white : .black
                    let type: PieceType
                    switch char.lowercased() {
                    case "k": type = .king
                    case "q": type = .queen
                    case "r": type = .rook
                    case "b": type = .bishop
                    case "n": type = .knight
                    case "p": type = .pawn
                    default: continue
                    }
                    pieces[7 - i][col] = Piece(type: type, color: color)
                    col += 1
                }
            }
        }
        currentPlayer = parts[1] == "w" ? .white : .black

        let castlingRights = parts[2]
        whiteKingSideCastle = castlingRights.contains("K")
        whiteQueenSideCastle = castlingRights.contains("Q")
        blackKingSideCastle = castlingRights.contains("k")
        blackQueenSideCastle = castlingRights.contains("q")

        if parts[3] != "-" {
            let enPassantString = String(parts[3])
            let col = enPassantString[enPassantString.startIndex]
            let row = enPassantString[enPassantString.index(enPassantString.startIndex, offsetBy: 1)]
            if let colIndex = "abcdefgh".firstIndex(of: col)?.utf16Offset(in: "abcdefgh"),
               let rowIndex = Int(String(row)) {
                enPassantTarget = (rowIndex - 1, colIndex)
            }
        } else {
            enPassantTarget = nil
        }
    }
}

extension Board: CustomStringConvertible {
    var description: String {
        var result = "  a b c d e f g h\n"
        for i in (0...7).reversed() {
            result += "\(i + 1) "
            for j in 0...7 {
                if let piece = pieces[i][j] {
                    result += "\(piece.character) "
                } else {
                    result += ". "
                }
            }
            result += "\(i + 1)\n"
        }
        result += "  a b c d e f g h\n\n"
        result += "\(currentPlayer == .white ? "White" : "Black") to move"
        return result
    }
}


func minimax(board: inout Board, depth: Int, alpha: inout Int, beta: inout Int, maximizingPlayer: Bool) -> Int {
    if depth == 0 {
        return board.evaluate()
    }

    if maximizingPlayer {
        var maxEval = Int.min
        for move in board.generateMoves() {
            let capturedPiece = board.pieces[move.to.0][move.to.1]
            board.makeMove(move)
            let eval = minimax(board: &board, depth: depth - 1, alpha: &alpha, beta: &beta, maximizingPlayer: false)
            board.undoMove(move, capturedPiece: capturedPiece)
            maxEval = max(maxEval, eval)
            alpha = max(alpha, eval)
            if beta <= alpha {
                break
            }
        }
        return maxEval
    } else {
        var minEval = Int.max
        for move in board.generateMoves() {
            let capturedPiece = board.pieces[move.to.0][move.to.1]
            board.makeMove(move)
            let eval = minimax(board: &board, depth: depth - 1, alpha: &alpha, beta: &beta, maximizingPlayer: true)
            board.undoMove(move, capturedPiece: capturedPiece)
            minEval = min(minEval, eval)
            beta = min(beta, eval)
            if beta <= alpha {
                break
            }
        }
        return minEval
    }
}

// Main game loop
func main() {
    var board = Board()
    while true {
        print(board)

        if board.isCheckmate() {
            print("CHECKMATE: \(board.currentPlayer == .white ? "Black" : "White") wins")
            break
        }
        if board.isStalemate() {
            print("STALEMATE: Draw")
            break
        }

        if let input = readLine() {
            let components = input.split(separator: " ")
            guard let command = components.first else { continue }

            switch command {
            case "quit":
                return
            case "new":
                board = Board()
            case "move":
                if components.count > 1 {
                    let moveString = String(components[1])
                    if let move = parseMove(moveString) {
                        board.makeMove(move)
                    } else {
                        print("ERROR: Invalid move format")
                    }
                }
            case "ai":
                if let bestMove = findBestMove(board: &board, depth: 3) {
                    board.makeMove(bestMove)
                } else {
                    print("No legal moves available.")
                }
            case "fen":
                let fen = components.dropFirst().joined(separator: " ")
                board.loadFen(fen)
            case "export":
                print("FEN: \(board.toFen())")
            case "perft":
                if components.count > 1, let depth = Int(String(components[1])) {
                    let count = perft(board: &board, depth: depth)
                    print("Perft(\(depth)): \(count)")
                } else {
                    print("ERROR: Invalid perft command")
                }
            default:
                print("ERROR: Invalid command")
            }
        }
    }
}

func findBestMove(board: inout Board, depth: Int) -> Move? {
    var bestMove: Move?
    var bestValue = board.currentPlayer == .white ? Int.min : Int.max

    for move in board.generateMoves() {
        let capturedPiece = board.pieces[move.to.0][move.to.1]
        board.makeMove(move)
        var alpha = Int.min
        var beta = Int.max
        let boardValue = minimax(board: &board, depth: depth - 1, alpha: &alpha, beta: &beta, maximizingPlayer: board.currentPlayer == .white)
        board.undoMove(move, capturedPiece: capturedPiece)

        if board.currentPlayer == .white {
            if boardValue > bestValue {
                bestValue = boardValue
                bestMove = move
            }
        } else {
            if boardValue < bestValue {
                bestValue = boardValue
                bestMove = move
            }
        }
    }
    return bestMove
}

func perft(board: inout Board, depth: Int) -> Int {
    if depth == 0 {
        return 1
    }

    var count = 0
    for move in board.generateMoves() {
        let capturedPiece = board.pieces[move.to.0][move.to.1]
        board.makeMove(move)
        count += perft(board: &board, depth: depth - 1)
        board.undoMove(move, capturedPiece: capturedPiece)
    }
    return count
}

func parseMove(_ moveString: String) -> Move? {
    let promotionChar = moveString.last
    let movePart = moveString.count == 5 ? String(moveString.dropLast()) : moveString
    guard movePart.count == 4 else { return nil }
    let fromCol = movePart[movePart.startIndex].lowercased()
    let fromRow = movePart[movePart.index(movePart.startIndex, offsetBy: 1)]
    let toCol = movePart[movePart.index(movePart.startIndex, offsetBy: 2)].lowercased()
    let toRow = movePart[movePart.index(movePart.startIndex, offsetBy: 3)]

    guard let fromColIndex = "abcdefgh".firstIndex(of: Character(fromCol))?.utf16Offset(in: "abcdefgh"),
          let fromRowInt = Int(String(fromRow)),
          let toColIndex = "abcdefgh".firstIndex(of: Character(toCol))?.utf16Offset(in: "abcdefgh"),
          let toRowInt = Int(String(toRow)) else {
        return nil
    }
    
    let fromRowIndex = fromRowInt - 1
    let toRowIndex = toRowInt - 1

    var promotionPiece: PieceType?
    if let promotionChar = promotionChar {
        switch promotionChar.lowercased() {
        case "q": promotionPiece = .queen
        case "r": promotionPiece = .rook
        case "b": promotionPiece = .bishop
        case "n": promotionPiece = .knight
        default: break
        }
    }

    return Move(from: (fromRowIndex, fromColIndex), to: (toRowIndex, toColIndex), promotionPiece: promotionPiece)
}

main()
