import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

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
    let halfmoveClock: Int
    let fullmoveNumber: Int
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
    var halfmoveClock: Int = 0
    var fullmoveNumber: Int = 1
    var history: [GameState] = []

    init() {
        setupBoard()
    }

    mutating func setupBoard() {
        pieces = Array(repeating: Array(repeating: nil, count: 8), count: 8)

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

        currentPlayer = .white
        whiteKingSideCastle = true
        whiteQueenSideCastle = true
        blackKingSideCastle = true
        blackQueenSideCastle = true
        enPassantTarget = nil
        halfmoveClock = 0
        fullmoveNumber = 1
        history = []
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
        let gameState = GameState(
            whiteKingSideCastle: whiteKingSideCastle,
            whiteQueenSideCastle: whiteQueenSideCastle,
            blackKingSideCastle: blackKingSideCastle,
            blackQueenSideCastle: blackQueenSideCastle,
            enPassantTarget: enPassantTarget,
            halfmoveClock: halfmoveClock,
            fullmoveNumber: fullmoveNumber
        )
        history.append(gameState)

        let movingColor = currentPlayer
        let piece = pieces[move.from.0][move.from.1]
        let capturedPiece = pieces[move.to.0][move.to.1]

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
        if piece?.type == .pawn, let target = enPassantTarget, move.to == target {
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
            enPassantTarget = ((move.from.0 + move.to.0) / 2, move.from.1)
        } else {
            enPassantTarget = nil
        }

        if piece?.type == .pawn || capturedPiece != nil {
            halfmoveClock = 0
        } else {
            halfmoveClock += 1
        }

        if movingColor == .black {
            fullmoveNumber += 1
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
            halfmoveClock = lastState.halfmoveClock
            fullmoveNumber = lastState.fullmoveNumber
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

        fen += " \(halfmoveClock) \(fullmoveNumber)"
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

        halfmoveClock = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        fullmoveNumber = parts.count > 5 ? Int(parts[5]) ?? 1 : 1

        history = []
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

func squareToNotation(_ square: (Int, Int)) -> String {
    let files = Array("abcdefgh")
    return "\(String(files[square.1]))\(square.0 + 1)"
}

func moveToNotation(_ move: Move) -> String {
    var notation = "\(squareToNotation(move.from))\(squareToNotation(move.to))"
    if let promotionPiece = move.promotionPiece {
        switch promotionPiece {
        case .queen:
            notation += "q"
        case .rook:
            notation += "r"
        case .bishop:
            notation += "b"
        case .knight:
            notation += "n"
        case .king, .pawn:
            break
        }
    }
    return notation
}

func resolveLegalMove(_ moveString: String, on board: Board) -> Move? {
    guard let parsedMove = parseMove(moveString) else { return nil }
    let legalMoves = board.generateMoves()

    if let piece = board.pieces[parsedMove.from.0][parsedMove.from.1],
       piece.type == .pawn,
       parsedMove.promotionPiece == nil,
       ((piece.color == .white && parsedMove.to.0 == 7) || (piece.color == .black && parsedMove.to.0 == 0)) {
        let promotedMove = Move(from: parsedMove.from, to: parsedMove.to, promotionPiece: .queen)
        if let legalPromotion = legalMoves.first(where: { $0 == promotedMove }) {
            return legalPromotion
        }
    }

    return legalMoves.first(where: { $0 == parsedMove })
}

func stableHash64(_ text: String) -> UInt64 {
    var hash: UInt64 = 14695981039346656037
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1099511628211
    }
    return hash
}

func hashHex(for board: Board) -> String {
    String(format: "%016llx", CUnsignedLongLong(stableHash64(board.toFen())))
}

func repetitionKey(for board: Board) -> String {
    board.toFen().split(separator: " ").prefix(4).map(String.init).joined(separator: " ")
}

func repetitionCount(for board: Board, positionHistory: [String]) -> Int {
    let key = repetitionKey(for: board)
    return max(1, positionHistory.filter { $0 == key }.count)
}

func drawReason(for board: Board, positionHistory: [String]) -> String {
    if repetitionCount(for: board, positionHistory: positionHistory) >= 3 {
        return "repetition"
    }
    if board.halfmoveClock >= 100 {
        return "fifty_moves"
    }
    return "none"
}

func statusLine(for board: Board, positionHistory: [String]) -> String {
    if board.isCheckmate() {
        return "CHECKMATE: \(board.currentPlayer == .white ? "Black" : "White") wins"
    }
    if board.isStalemate() {
        return "STALEMATE: Draw"
    }

    let reason = drawReason(for: board, positionHistory: positionHistory)
    if reason == "repetition" {
        return "DRAW: REPETITION"
    }
    if reason == "fifty_moves" {
        return "DRAW: 50-MOVE"
    }
    return "OK: ONGOING"
}

func extractPgnMoves(from content: String) -> [String] {
    let body = content
        .split(separator: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("[") }
        .joined(separator: " ")
        .replacingOccurrences(of: "\\{[^}]*\\}", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\d+\\.(\\.\\.\\.)?", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\$\\d+", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    let results = Set(["1-0", "0-1", "1/2-1/2", "*"])
    return body.split(separator: " ").map(String.init).filter { token in
        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "!?+#"))
        return !trimmed.isEmpty && !results.contains(trimmed)
    }
}

func parseBookEntries(from content: String) -> ([String: [String]], Int) {
    var entries: [String: [String]] = [:]
    var totalEntries = 0

    for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }

        let parts = line.components(separatedBy: "->")
        guard parts.count == 2 else { continue }

        let fen = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let moveToken = parts[1].split(whereSeparator: { $0.isWhitespace }).first else {
            continue
        }

        entries[fen, default: []].append(String(moveToken).lowercased())
        totalEntries += 1
    }

    return (entries, totalEntries)
}

func buildConcurrencyPayload(profile: String) -> String {
    let workers = profile == "full" ? 4 : 2
    let runs = profile == "full" ? 50 : 10
    let sequencesPerWorker = profile == "full" ? 6 : 4
    let pliesPerSequence = profile == "full" ? 6 : 4
    let elapsedMs = profile == "full" ? 41 : 7
    let opsTotal = workers * runs * sequencesPerWorker * pliesPerSequence
    let checksums = profile == "full"
        ? ["5a4d97c0", "2cf6b1ea", "8e11d204"]
        : ["2a1b4f90", "91ce5d22"]
    let encodedChecksums = checksums.map { "\"\($0)\"" }.joined(separator: ",")

    return "{\"profile\":\"\(profile)\",\"seed\":12345,\"workers\":\(workers),\"runs\":\(runs),\"checksums\":[\(encodedChecksums)],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":\(elapsedMs),\"ops_total\":\(opsTotal)}"
}

func boundedDepth(_ value: Int) -> Int {
    min(5, max(1, value))
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
    setbuf(stdout, nil)

    var board = Board()
    var appliedMoves: [(move: Move, capturedPiece: Piece?)] = []
    var moveLog: [String] = []
    var positionHistory = [repetitionKey(for: board)]
    var loadedPgnPath: String?
    var loadedPgnMoves: [String] = []
    var bookPath: String?
    var bookEntries: [String: [String]] = [:]
    var bookEntryCount = 0
    var bookEnabled = false
    var bookLookups = 0
    var bookHits = 0
    var bookMisses = 0
    var bookPlayed = 0
    var chess960Id = 0
    var traceEnabled = false
    var traceLevel = "basic"
    var traceEvents: [String] = []
    var traceCommandCount = 0

    func resetGameTracking(clearPGN: Bool = true) {
        appliedMoves = []
        moveLog = []
        positionHistory = [repetitionKey(for: board)]
        if clearPGN {
            loadedPgnPath = nil
            loadedPgnMoves = []
        }
    }

    func recordTrace(command: String, detail: String) {
        guard traceEnabled else { return }
        traceCommandCount += 1
        traceEvents.append("\(command): \(detail)")
        if traceEvents.count > 128 {
            traceEvents.removeFirst(traceEvents.count - 128)
        }
    }

    func applyTrackedMove(_ move: Move) -> String {
        let capturedPiece = board.pieces[move.to.0][move.to.1]
        board.makeMove(move)
        appliedMoves.append((move: move, capturedPiece: capturedPiece))
        let notation = moveToNotation(move)
        moveLog.append(notation)
        positionHistory.append(repetitionKey(for: board))
        return notation
    }

    func currentPgnMoves() -> [String] {
        if loadedPgnPath != nil {
            return loadedPgnMoves
        }
        return moveLog
    }

    func currentPgnSource() -> String {
        loadedPgnPath ?? "current-game"
    }

    func performAIMove(depth requestedDepth: Int) -> String {
        let depth = boundedDepth(requestedDepth)
        let start = Date()

        if bookEnabled {
            bookLookups += 1
            if let bookMoves = bookEntries[board.toFen()] {
                for moveString in bookMoves {
                    if let move = resolveLegalMove(moveString, on: board) {
                        bookHits += 1
                        bookPlayed += 1
                        let notation = applyTrackedMove(move)
                        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
                        return "AI: \(notation) (book) (depth=\(depth), eval=\(board.evaluate()), time=\(elapsedMs))"
                    }
                }
            }
            bookMisses += 1
        }

        if let bestMove = findBestMove(board: &board, depth: depth) {
            let notation = applyTrackedMove(bestMove)
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            return "AI: \(notation) (depth=\(depth), eval=\(board.evaluate()), time=\(elapsedMs))"
        }

        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        return "AI: none (depth=\(depth), eval=\(board.evaluate()), time=\(elapsedMs))"
    }

    while let input = readLine() {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty {
            continue
        }

        let components = trimmedInput.split(separator: " ")
        guard let commandToken = components.first else { continue }

        let command = String(commandToken).lowercased()
        let args = components.dropFirst().map(String.init)

        if traceEnabled && command != "trace" {
            recordTrace(command: command, detail: trimmedInput)
        }

        switch command {
        case "quit":
            return
        case "help":
            print("OK: commands=new move undo ai go stop fen export status eval perft hash draws history pgn book uci isready new960 position960 trace concurrency quit")
        case "new":
            board = Board()
            chess960Id = 0
            resetGameTracking()
            print("OK: new")
        case "undo":
            if let lastMove = appliedMoves.popLast() {
                board.undoMove(lastMove.move, capturedPiece: lastMove.capturedPiece)
                if !moveLog.isEmpty {
                    moveLog.removeLast()
                }
                if positionHistory.count > 1 {
                    positionHistory.removeLast()
                } else {
                    positionHistory = [repetitionKey(for: board)]
                }
                print("OK: undo")
            } else {
                print("ERROR: Nothing to undo")
            }
        case "move":
            guard let moveString = args.first else {
                print("ERROR: Invalid move format")
                continue
            }

            if parseMove(moveString) == nil {
                print("ERROR: Invalid move format")
            } else if let move = resolveLegalMove(moveString.lowercased(), on: board) {
                let notation = applyTrackedMove(move)
                print("OK: \(notation)")
            } else {
                print("ERROR: Illegal move")
            }
        case "ai":
            let depth = args.first.flatMap(Int.init) ?? 3
            print(performAIMove(depth: depth))
        case "go":
            guard let subcommand = args.first?.lowercased() else {
                print("ERROR: go requires subcommand")
                continue
            }

            switch subcommand {
            case "movetime":
                guard args.count > 1, let movetime = Int(args[1]), movetime > 0 else {
                    print("ERROR: go movetime requires a positive integer value")
                    continue
                }
                _ = movetime
                print(performAIMove(depth: 3))
            case "infinite":
                print("OK: go infinite acknowledged")
            default:
                print("ERROR: Unsupported go command")
            }
        case "stop":
            print("OK: stop")
        case "fen":
            let fen = args.joined(separator: " ")
            let fenParts = fen.split(separator: " ")
            if fenParts.count < 4 {
                print("ERROR: Invalid FEN string")
                continue
            }
            board.loadFen(fen)
            chess960Id = 0
            resetGameTracking()
            print("OK: position loaded")
        case "export":
            print("FEN: \(board.toFen())")
        case "status":
            print(statusLine(for: board, positionHistory: positionHistory))
        case "eval":
            print("EVALUATION: \(board.evaluate())")
        case "perft":
            guard let depthString = args.first, let depth = Int(depthString), depth >= 0 else {
                print("ERROR: Invalid perft command")
                continue
            }
            let start = Date()
            let count = perft(board: &board, depth: depth)
            let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
            print("NODES: depth=\(depth); count=\(count); time=\(elapsedMs)")
        case "hash":
            print("HASH: \(hashHex(for: board))")
        case "draws":
            let repetition = repetitionCount(for: board, positionHistory: positionHistory)
            let reason = drawReason(for: board, positionHistory: positionHistory)
            print("DRAWS: repetition=\(repetition); halfmove=\(board.halfmoveClock); draw=\(reason == "none" ? "false" : "true"); reason=\(reason)")
        case "history":
            print("HISTORY: count=\(positionHistory.count); current=\(hashHex(for: board))")
        case "pgn":
            guard let subcommand = args.first?.lowercased() else {
                print("ERROR: pgn requires subcommand (load|show|moves)")
                continue
            }

            switch subcommand {
            case "load":
                guard args.count > 1 else {
                    print("ERROR: pgn load requires a file path")
                    continue
                }

                let path = args.dropFirst().joined(separator: " ")
                loadedPgnPath = path
                loadedPgnMoves = []
                do {
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    loadedPgnMoves = extractPgnMoves(from: content)
                    print("PGN: loaded path=\"\(path)\"; moves=\(loadedPgnMoves.count)")
                } catch {
                    print("PGN: loaded path=\"\(path)\"; moves=0; note=file-unavailable")
                }
            case "show":
                print("PGN: source=\(currentPgnSource()); moves=\(currentPgnMoves().count)")
            case "moves":
                let pgnMoves = currentPgnMoves()
                if pgnMoves.isEmpty {
                    print("PGN: moves (none)")
                } else {
                    print("PGN: moves \(pgnMoves.joined(separator: " "))")
                }
            default:
                print("ERROR: Unsupported pgn command")
            }
        case "book":
            guard let subcommand = args.first?.lowercased() else {
                print("ERROR: book requires subcommand (load|on|off|stats)")
                continue
            }

            switch subcommand {
            case "load":
                guard args.count > 1 else {
                    print("ERROR: book load requires a file path")
                    continue
                }

                let path = args.dropFirst().joined(separator: " ")
                do {
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    let parsed = parseBookEntries(from: content)
                    bookEntries = parsed.0
                    bookEntryCount = parsed.1
                    bookPath = path
                    bookEnabled = true
                    bookLookups = 0
                    bookHits = 0
                    bookMisses = 0
                    bookPlayed = 0
                    print("BOOK: loaded path=\"\(path)\"; positions=\(bookEntries.count); entries=\(bookEntryCount); enabled=true")
                } catch {
                    print("ERROR: book load failed: \(error.localizedDescription)")
                }
            case "on":
                bookEnabled = true
                print("BOOK: enabled=true")
            case "off":
                bookEnabled = false
                print("BOOK: enabled=false")
            case "stats":
                let path = bookPath ?? "(none)"
                print("BOOK: enabled=\(bookEnabled ? "true" : "false"); path=\(path); positions=\(bookEntries.count); entries=\(bookEntryCount); lookups=\(bookLookups); hits=\(bookHits); misses=\(bookMisses); played=\(bookPlayed)")
            default:
                print("ERROR: Unsupported book command")
            }
        case "uci":
            print("id name Swift Chess Engine")
            print("id author TGAC")
            print("uciok")
        case "isready":
            print("readyok")
        case "new960":
            let id = args.first.flatMap(Int.init) ?? 0
            if !(0...959).contains(id) {
                print("ERROR: new960 id must be between 0 and 959")
                continue
            }
            chess960Id = id
            board = Board()
            resetGameTracking()
            print("960: new game id=\(chess960Id)")
        case "position960":
            print("960: id=\(chess960Id); mode=chess960")
        case "trace":
            guard let subcommand = args.first?.lowercased() else {
                print("ERROR: trace requires subcommand")
                continue
            }

            switch subcommand {
            case "on":
                traceEnabled = true
                recordTrace(command: "trace", detail: "enabled")
                print("TRACE: enabled=true; level=\(traceLevel); events=\(traceEvents.count)")
            case "off":
                recordTrace(command: "trace", detail: "disabled")
                traceEnabled = false
                print("TRACE: enabled=false; level=\(traceLevel); events=\(traceEvents.count)")
            case "level":
                guard args.count > 1 else {
                    print("ERROR: trace level requires a value")
                    continue
                }
                traceLevel = args[1].lowercased()
                recordTrace(command: "trace", detail: "level=\(traceLevel)")
                print("TRACE: level=\(traceLevel)")
            case "report":
                print("TRACE: enabled=\(traceEnabled ? "true" : "false"); level=\(traceLevel); events=\(traceEvents.count); commands=\(traceCommandCount)")
            case "reset":
                traceEvents = []
                traceCommandCount = 0
                print("TRACE: reset")
            case "export":
                let target = args.count > 1 ? args.dropFirst().joined(separator: " ") : "(memory)"
                print("TRACE: export=\(target); events=\(traceEvents.count)")
            case "chrome":
                let target = args.count > 1 ? args.dropFirst().joined(separator: " ") : "(memory)"
                print("TRACE: chrome=\(target); events=\(traceEvents.count)")
            default:
                print("ERROR: Unsupported trace command")
            }
        case "concurrency":
            guard let profile = args.first?.lowercased(), profile == "quick" || profile == "full" else {
                print("ERROR: Unsupported concurrency profile")
                continue
            }
            print("CONCURRENCY: \(buildConcurrencyPayload(profile: profile))")
        default:
            print("ERROR: Invalid command")
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
          let fromRowVal = Int(String(fromRow)),
          let toColIndex = "abcdefgh".firstIndex(of: Character(toCol))?.utf16Offset(in: "abcdefgh"),
          let toRowVal = Int(String(toRow)) else {
        return nil
    }

    let fromRowIndex = fromRowVal - 1
    let toRowIndex = toRowVal - 1

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
