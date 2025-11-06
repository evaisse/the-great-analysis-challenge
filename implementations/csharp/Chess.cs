using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Chess
{
    // Piece types
    enum PieceType { None, Pawn, Knight, Bishop, Rook, Queen, King }
    enum Color { White, Black }

    // Represents a chess piece
    class Piece
    {
        public PieceType Type { get; set; }
        public Color Color { get; set; }

        public Piece(PieceType type, Color color)
        {
            Type = type;
            Color = color;
        }

        public override string ToString()
        {
            if (Type == PieceType.None) return ".";
            char c = Type switch
            {
                PieceType.King => 'K',
                PieceType.Queen => 'Q',
                PieceType.Rook => 'R',
                PieceType.Bishop => 'B',
                PieceType.Knight => 'N',
                PieceType.Pawn => 'P',
                _ => '.'
            };
            return Color == Color.White ? c.ToString() : c.ToString().ToLower();
        }
    }

    // Represents a move
    class Move
    {
        public int FromRow { get; set; }
        public int FromCol { get; set; }
        public int ToRow { get; set; }
        public int ToCol { get; set; }
        public PieceType? Promotion { get; set; }

        public Move(int fromRow, int fromCol, int toRow, int toCol, PieceType? promotion = null)
        {
            FromRow = fromRow;
            FromCol = fromCol;
            ToRow = toRow;
            ToCol = toCol;
            Promotion = promotion;
        }

        public override string ToString()
        {
            char fromFile = (char)('a' + FromCol);
            char toFile = (char)('a' + ToCol);
            int fromRank = 8 - FromRow;
            int toRank = 8 - ToRow;
            string promo = Promotion.HasValue ? Promotion.Value.ToString()[0].ToString() : "";
            return $"{fromFile}{fromRank}{toFile}{toRank}{promo}";
        }
    }

    // Main chess board class
    class ChessBoard
    {
        private Piece?[,] board = new Piece?[8, 8];
        public Color CurrentTurn { get; private set; } = Color.White;
        public bool WhiteCanCastleKingside { get; private set; } = true;
        public bool WhiteCanCastleQueenside { get; private set; } = true;
        public bool BlackCanCastleKingside { get; private set; } = true;
        public bool BlackCanCastleQueenside { get; private set; } = true;
        public int? EnPassantCol { get; private set; } = null;
        public int HalfMoveClock { get; private set; } = 0;
        public int FullMoveNumber { get; private set; } = 1;

        private List<(Piece?[,], Color, bool, bool, bool, bool, int?, int, int)> moveHistory = new();

        public ChessBoard()
        {
            InitializeBoard();
        }

        private void InitializeBoard()
        {
            // Clear board
            for (int row = 0; row < 8; row++)
                for (int col = 0; col < 8; col++)
                    board[row, col] = null;

            // Place black pieces
            board[0, 0] = new Piece(PieceType.Rook, Color.Black);
            board[0, 1] = new Piece(PieceType.Knight, Color.Black);
            board[0, 2] = new Piece(PieceType.Bishop, Color.Black);
            board[0, 3] = new Piece(PieceType.Queen, Color.Black);
            board[0, 4] = new Piece(PieceType.King, Color.Black);
            board[0, 5] = new Piece(PieceType.Bishop, Color.Black);
            board[0, 6] = new Piece(PieceType.Knight, Color.Black);
            board[0, 7] = new Piece(PieceType.Rook, Color.Black);
            for (int col = 0; col < 8; col++)
                board[1, col] = new Piece(PieceType.Pawn, Color.Black);

            // Place white pieces
            for (int col = 0; col < 8; col++)
                board[6, col] = new Piece(PieceType.Pawn, Color.White);
            board[7, 0] = new Piece(PieceType.Rook, Color.White);
            board[7, 1] = new Piece(PieceType.Knight, Color.White);
            board[7, 2] = new Piece(PieceType.Bishop, Color.White);
            board[7, 3] = new Piece(PieceType.Queen, Color.White);
            board[7, 4] = new Piece(PieceType.King, Color.White);
            board[7, 5] = new Piece(PieceType.Bishop, Color.White);
            board[7, 6] = new Piece(PieceType.Knight, Color.White);
            board[7, 7] = new Piece(PieceType.Rook, Color.White);

            CurrentTurn = Color.White;
            WhiteCanCastleKingside = true;
            WhiteCanCastleQueenside = true;
            BlackCanCastleKingside = true;
            BlackCanCastleQueenside = true;
            EnPassantCol = null;
            HalfMoveClock = 0;
            FullMoveNumber = 1;
            moveHistory.Clear();
        }

        public void Display()
        {
            Console.WriteLine("  a b c d e f g h");
            for (int row = 0; row < 8; row++)
            {
                Console.Write($"{8 - row} ");
                for (int col = 0; col < 8; col++)
                {
                    Console.Write(board[row, col]?.ToString() ?? ".");
                    Console.Write(" ");
                }
                Console.WriteLine($"{8 - row}");
            }
            Console.WriteLine("  a b c d e f g h");
            Console.WriteLine();
            Console.WriteLine($"{(CurrentTurn == Color.White ? "White" : "Black")} to move");
        }

        public string ToFEN()
        {
            StringBuilder fen = new StringBuilder();

            // Piece placement
            for (int row = 0; row < 8; row++)
            {
                int emptyCount = 0;
                for (int col = 0; col < 8; col++)
                {
                    var piece = board[row, col];
                    if (piece == null)
                    {
                        emptyCount++;
                    }
                    else
                    {
                        if (emptyCount > 0)
                        {
                            fen.Append(emptyCount);
                            emptyCount = 0;
                        }
                        fen.Append(piece.ToString());
                    }
                }
                if (emptyCount > 0)
                    fen.Append(emptyCount);
                if (row < 7)
                    fen.Append('/');
            }

            // Active color
            fen.Append(CurrentTurn == Color.White ? " w " : " b ");

            // Castling rights
            string castling = "";
            if (WhiteCanCastleKingside) castling += "K";
            if (WhiteCanCastleQueenside) castling += "Q";
            if (BlackCanCastleKingside) castling += "k";
            if (BlackCanCastleQueenside) castling += "q";
            fen.Append(castling.Length > 0 ? castling : "-");
            fen.Append(" ");

            // En passant
            if (EnPassantCol.HasValue)
            {
                char file = (char)('a' + EnPassantCol.Value);
                int rank = CurrentTurn == Color.White ? 6 : 3;
                fen.Append($"{file}{rank}");
            }
            else
            {
                fen.Append("-");
            }

            // Halfmove and fullmove
            fen.Append($" {HalfMoveClock} {FullMoveNumber}");

            return fen.ToString();
        }

        public bool LoadFEN(string fen)
        {
            try
            {
                string[] parts = fen.Split(' ');
                if (parts.Length < 4) return false;

                // Clear board
                for (int row = 0; row < 8; row++)
                    for (int col = 0; col < 8; col++)
                        board[row, col] = null;

                // Parse piece placement
                string[] ranks = parts[0].Split('/');
                if (ranks.Length != 8) return false;

                for (int row = 0; row < 8; row++)
                {
                    int col = 0;
                    foreach (char c in ranks[row])
                    {
                        if (char.IsDigit(c))
                        {
                            col += c - '0';
                        }
                        else
                        {
                            Color color = char.IsUpper(c) ? Color.White : Color.Black;
                            PieceType type = char.ToUpper(c) switch
                            {
                                'K' => PieceType.King,
                                'Q' => PieceType.Queen,
                                'R' => PieceType.Rook,
                                'B' => PieceType.Bishop,
                                'N' => PieceType.Knight,
                                'P' => PieceType.Pawn,
                                _ => PieceType.None
                            };
                            board[row, col] = new Piece(type, color);
                            col++;
                        }
                    }
                }

                // Parse active color
                CurrentTurn = parts[1] == "w" ? Color.White : Color.Black;

                // Parse castling rights
                WhiteCanCastleKingside = parts[2].Contains('K');
                WhiteCanCastleQueenside = parts[2].Contains('Q');
                BlackCanCastleKingside = parts[2].Contains('k');
                BlackCanCastleQueenside = parts[2].Contains('q');

                // Parse en passant
                if (parts[3] != "-")
                {
                    EnPassantCol = parts[3][0] - 'a';
                }
                else
                {
                    EnPassantCol = null;
                }

                // Parse halfmove and fullmove
                if (parts.Length >= 5)
                    HalfMoveClock = int.Parse(parts[4]);
                if (parts.Length >= 6)
                    FullMoveNumber = int.Parse(parts[5]);

                moveHistory.Clear();
                return true;
            }
            catch
            {
                return false;
            }
        }

        public bool MakeMove(string moveStr)
        {
            if (moveStr.Length < 4) return false;

            int fromCol = moveStr[0] - 'a';
            int fromRow = 8 - (moveStr[1] - '0');
            int toCol = moveStr[2] - 'a';
            int toRow = 8 - (moveStr[3] - '0');

            if (fromRow < 0 || fromRow > 7 || fromCol < 0 || fromCol > 7 ||
                toRow < 0 || toRow > 7 || toCol < 0 || toCol > 7)
                return false;

            PieceType? promotion = null;
            if (moveStr.Length >= 5)
            {
                promotion = char.ToUpper(moveStr[4]) switch
                {
                    'Q' => PieceType.Queen,
                    'R' => PieceType.Rook,
                    'B' => PieceType.Bishop,
                    'N' => PieceType.Knight,
                    _ => null
                };
            }

            Move move = new Move(fromRow, fromCol, toRow, toCol, promotion);
            return MakeMove(move);
        }

        private bool MakeMove(Move move)
        {
            var piece = board[move.FromRow, move.FromCol];
            if (piece == null || piece.Color != CurrentTurn)
                return false;

            if (!IsLegalMove(move))
                return false;

            // Save state for undo
            var boardCopy = (Piece?[,])board.Clone();
            moveHistory.Add((boardCopy, CurrentTurn, WhiteCanCastleKingside, WhiteCanCastleQueenside,
                BlackCanCastleKingside, BlackCanCastleQueenside, EnPassantCol, HalfMoveClock, FullMoveNumber));

            // Handle special moves
            bool isCapture = board[move.ToRow, move.ToCol] != null;
            bool isPawnMove = piece.Type == PieceType.Pawn;

            // En passant capture
            if (isPawnMove && move.ToCol != move.FromCol && board[move.ToRow, move.ToCol] == null)
            {
                int captureRow = move.FromRow;
                board[captureRow, move.ToCol] = null;
                isCapture = true;
            }

            // Castling
            if (piece.Type == PieceType.King && Math.Abs(move.ToCol - move.FromCol) == 2)
            {
                if (move.ToCol > move.FromCol) // Kingside
                {
                    board[move.ToRow, 5] = board[move.ToRow, 7];
                    board[move.ToRow, 7] = null;
                }
                else // Queenside
                {
                    board[move.ToRow, 3] = board[move.ToRow, 0];
                    board[move.ToRow, 0] = null;
                }
            }

            // Execute move
            board[move.ToRow, move.ToCol] = piece;
            board[move.FromRow, move.FromCol] = null;

            // Pawn promotion
            if (isPawnMove && (move.ToRow == 0 || move.ToRow == 7))
            {
                board[move.ToRow, move.ToCol] = new Piece(move.Promotion ?? PieceType.Queen, piece.Color);
            }

            // Update en passant
            EnPassantCol = null;
            if (isPawnMove && Math.Abs(move.ToRow - move.FromRow) == 2)
            {
                EnPassantCol = move.FromCol;
            }

            // Update castling rights
            if (piece.Type == PieceType.King)
            {
                if (piece.Color == Color.White)
                {
                    WhiteCanCastleKingside = false;
                    WhiteCanCastleQueenside = false;
                }
                else
                {
                    BlackCanCastleKingside = false;
                    BlackCanCastleQueenside = false;
                }
            }
            if (piece.Type == PieceType.Rook)
            {
                if (piece.Color == Color.White)
                {
                    if (move.FromRow == 7 && move.FromCol == 0) WhiteCanCastleQueenside = false;
                    if (move.FromRow == 7 && move.FromCol == 7) WhiteCanCastleKingside = false;
                }
                else
                {
                    if (move.FromRow == 0 && move.FromCol == 0) BlackCanCastleQueenside = false;
                    if (move.FromRow == 0 && move.FromCol == 7) BlackCanCastleKingside = false;
                }
            }

            // Update clocks
            if (isPawnMove || isCapture)
                HalfMoveClock = 0;
            else
                HalfMoveClock++;

            if (CurrentTurn == Color.Black)
                FullMoveNumber++;

            CurrentTurn = CurrentTurn == Color.White ? Color.Black : Color.White;

            return true;
        }

        public bool Undo()
        {
            if (moveHistory.Count == 0) return false;

            var state = moveHistory[^1];
            board = state.Item1;
            CurrentTurn = state.Item2;
            WhiteCanCastleKingside = state.Item3;
            WhiteCanCastleQueenside = state.Item4;
            BlackCanCastleKingside = state.Item5;
            BlackCanCastleQueenside = state.Item6;
            EnPassantCol = state.Item7;
            HalfMoveClock = state.Item8;
            FullMoveNumber = state.Item9;
            moveHistory.RemoveAt(moveHistory.Count - 1);

            return true;
        }

        private bool IsLegalMove(Move move)
        {
            var piece = board[move.FromRow, move.FromCol];
            if (piece == null) return false;

            // Check basic move validity
            if (!IsValidMove(move)) return false;

            // Check if move puts own king in check
            var boardCopy = DeepCopyBoard();
            var tempBoard = new ChessBoard();
            tempBoard.board = boardCopy;
            tempBoard.CurrentTurn = CurrentTurn;
            tempBoard.WhiteCanCastleKingside = WhiteCanCastleKingside;
            tempBoard.WhiteCanCastleQueenside = WhiteCanCastleQueenside;
            tempBoard.BlackCanCastleKingside = BlackCanCastleKingside;
            tempBoard.BlackCanCastleQueenside = BlackCanCastleQueenside;
            tempBoard.EnPassantCol = EnPassantCol;

            // Make the move on temp board
            tempBoard.board[move.ToRow, move.ToCol] = piece;
            tempBoard.board[move.FromRow, move.FromCol] = null;

            // En passant capture on temp board
            if (piece.Type == PieceType.Pawn && move.ToCol != move.FromCol && board[move.ToRow, move.ToCol] == null)
            {
                tempBoard.board[move.FromRow, move.ToCol] = null;
            }

            // Castling rook move on temp board
            if (piece.Type == PieceType.King && Math.Abs(move.ToCol - move.FromCol) == 2)
            {
                if (move.ToCol > move.FromCol)
                {
                    tempBoard.board[move.ToRow, 5] = board[move.ToRow, 7];
                    tempBoard.board[move.ToRow, 7] = null;
                }
                else
                {
                    tempBoard.board[move.ToRow, 3] = board[move.ToRow, 0];
                    tempBoard.board[move.ToRow, 0] = null;
                }
            }

            return !tempBoard.IsInCheck(CurrentTurn);
        }

        private bool IsValidMove(Move move)
        {
            var piece = board[move.FromRow, move.FromCol];
            if (piece == null) return false;

            int rowDiff = move.ToRow - move.FromRow;
            int colDiff = move.ToCol - move.FromCol;

            switch (piece.Type)
            {
                case PieceType.Pawn:
                    return IsValidPawnMove(move, piece.Color);
                case PieceType.Knight:
                    if ((Math.Abs(rowDiff) == 2 && Math.Abs(colDiff) == 1) ||
                        (Math.Abs(rowDiff) == 1 && Math.Abs(colDiff) == 2))
                    {
                        var target = board[move.ToRow, move.ToCol];
                        return target == null || target.Color != piece.Color;
                    }
                    return false;
                case PieceType.Bishop:
                    return Math.Abs(rowDiff) == Math.Abs(colDiff) && IsPathClear(move);
                case PieceType.Rook:
                    return (rowDiff == 0 || colDiff == 0) && IsPathClear(move);
                case PieceType.Queen:
                    return ((rowDiff == 0 || colDiff == 0) || (Math.Abs(rowDiff) == Math.Abs(colDiff))) && IsPathClear(move);
                case PieceType.King:
                    return IsValidKingMove(move, piece.Color);
                default:
                    return false;
            }
        }

        private bool IsValidPawnMove(Move move, Color color)
        {
            int direction = color == Color.White ? -1 : 1;
            int startRow = color == Color.White ? 6 : 1;
            int rowDiff = move.ToRow - move.FromRow;
            int colDiff = Math.Abs(move.ToCol - move.FromCol);

            // Forward move
            if (colDiff == 0)
            {
                if (rowDiff == direction && board[move.ToRow, move.ToCol] == null)
                    return true;
                if (move.FromRow == startRow && rowDiff == 2 * direction &&
                    board[move.ToRow, move.ToCol] == null &&
                    board[move.FromRow + direction, move.FromCol] == null)
                    return true;
            }
            // Capture
            else if (colDiff == 1 && rowDiff == direction)
            {
                var target = board[move.ToRow, move.ToCol];
                if (target != null && target.Color != color)
                    return true;
                // En passant
                if (EnPassantCol == move.ToCol && target == null)
                {
                    var capturedPawn = board[move.FromRow, move.ToCol];
                    if (capturedPawn != null && capturedPawn.Type == PieceType.Pawn && capturedPawn.Color != color)
                        return true;
                }
            }

            return false;
        }

        private bool IsValidKingMove(Move move, Color color)
        {
            int rowDiff = Math.Abs(move.ToRow - move.FromRow);
            int colDiff = Math.Abs(move.ToCol - move.FromCol);

            // Normal king move
            if (rowDiff <= 1 && colDiff <= 1)
            {
                var target = board[move.ToRow, move.ToCol];
                return target == null || target.Color != color;
            }

            // Castling
            if (rowDiff == 0 && colDiff == 2)
            {
                if (IsInCheck(color)) return false;

                if (color == Color.White && move.FromRow == 7 && move.FromCol == 4)
                {
                    // Kingside
                    if (move.ToCol == 6 && WhiteCanCastleKingside)
                    {
                        if (board[7, 5] == null && board[7, 6] == null)
                        {
                            // Check if king passes through check
                            var tempBoard = new ChessBoard();
                            tempBoard.board = DeepCopyBoard();
                            tempBoard.CurrentTurn = CurrentTurn;
                            tempBoard.board[7, 5] = board[7, 4];
                            tempBoard.board[7, 4] = null;
                            if (tempBoard.IsInCheck(Color.White)) return false;
                            return true;
                        }
                    }
                    // Queenside
                    if (move.ToCol == 2 && WhiteCanCastleQueenside)
                    {
                        if (board[7, 1] == null && board[7, 2] == null && board[7, 3] == null)
                        {
                            var tempBoard = new ChessBoard();
                            tempBoard.board = DeepCopyBoard();
                            tempBoard.CurrentTurn = CurrentTurn;
                            tempBoard.board[7, 3] = board[7, 4];
                            tempBoard.board[7, 4] = null;
                            if (tempBoard.IsInCheck(Color.White)) return false;
                            return true;
                        }
                    }
                }
                else if (color == Color.Black && move.FromRow == 0 && move.FromCol == 4)
                {
                    // Kingside
                    if (move.ToCol == 6 && BlackCanCastleKingside)
                    {
                        if (board[0, 5] == null && board[0, 6] == null)
                        {
                            var tempBoard = new ChessBoard();
                            tempBoard.board = DeepCopyBoard();
                            tempBoard.CurrentTurn = CurrentTurn;
                            tempBoard.board[0, 5] = board[0, 4];
                            tempBoard.board[0, 4] = null;
                            if (tempBoard.IsInCheck(Color.Black)) return false;
                            return true;
                        }
                    }
                    // Queenside
                    if (move.ToCol == 2 && BlackCanCastleQueenside)
                    {
                        if (board[0, 1] == null && board[0, 2] == null && board[0, 3] == null)
                        {
                            var tempBoard = new ChessBoard();
                            tempBoard.board = DeepCopyBoard();
                            tempBoard.CurrentTurn = CurrentTurn;
                            tempBoard.board[0, 3] = board[0, 4];
                            tempBoard.board[0, 4] = null;
                            if (tempBoard.IsInCheck(Color.Black)) return false;
                            return true;
                        }
                    }
                }
            }

            return false;
        }

        private bool IsPathClear(Move move)
        {
            int rowStep = Math.Sign(move.ToRow - move.FromRow);
            int colStep = Math.Sign(move.ToCol - move.FromCol);
            int row = move.FromRow + rowStep;
            int col = move.FromCol + colStep;

            while (row != move.ToRow || col != move.ToCol)
            {
                if (board[row, col] != null)
                    return false;
                row += rowStep;
                col += colStep;
            }

            var target = board[move.ToRow, move.ToCol];
            return target == null || target.Color != board[move.FromRow, move.FromCol]!.Color;
        }

        public bool IsInCheck(Color color)
        {
            // Find king position
            int kingRow = -1, kingCol = -1;
            for (int row = 0; row < 8; row++)
            {
                for (int col = 0; col < 8; col++)
                {
                    var piece = board[row, col];
                    if (piece != null && piece.Type == PieceType.King && piece.Color == color)
                    {
                        kingRow = row;
                        kingCol = col;
                        break;
                    }
                }
                if (kingRow != -1) break;
            }

            if (kingRow == -1) return false;

            // Check if any opponent piece can attack the king
            Color opponentColor = color == Color.White ? Color.Black : Color.White;
            for (int row = 0; row < 8; row++)
            {
                for (int col = 0; col < 8; col++)
                {
                    var piece = board[row, col];
                    if (piece != null && piece.Color == opponentColor)
                    {
                        Move move = new Move(row, col, kingRow, kingCol);
                        if (IsValidMove(move))
                            return true;
                    }
                }
            }

            return false;
        }

        public List<Move> GetLegalMoves()
        {
            List<Move> moves = new List<Move>();
            for (int fromRow = 0; fromRow < 8; fromRow++)
            {
                for (int fromCol = 0; fromCol < 8; fromCol++)
                {
                    var piece = board[fromRow, fromCol];
                    if (piece == null || piece.Color != CurrentTurn)
                        continue;

                    for (int toRow = 0; toRow < 8; toRow++)
                    {
                        for (int toCol = 0; toCol < 8; toCol++)
                        {
                            Move move = new Move(fromRow, fromCol, toRow, toCol);
                            if (IsLegalMove(move))
                            {
                                // Check for promotion
                                if (piece.Type == PieceType.Pawn && (toRow == 0 || toRow == 7))
                                {
                                    moves.Add(new Move(fromRow, fromCol, toRow, toCol, PieceType.Queen));
                                    moves.Add(new Move(fromRow, fromCol, toRow, toCol, PieceType.Rook));
                                    moves.Add(new Move(fromRow, fromCol, toRow, toCol, PieceType.Bishop));
                                    moves.Add(new Move(fromRow, fromCol, toRow, toCol, PieceType.Knight));
                                }
                                else
                                {
                                    moves.Add(move);
                                }
                            }
                        }
                    }
                }
            }
            return moves;
        }

        public bool IsCheckmate()
        {
            return IsInCheck(CurrentTurn) && GetLegalMoves().Count == 0;
        }

        public bool IsStalemate()
        {
            return !IsInCheck(CurrentTurn) && GetLegalMoves().Count == 0;
        }

        public int Evaluate()
        {
            int score = 0;
            for (int row = 0; row < 8; row++)
            {
                for (int col = 0; col < 8; col++)
                {
                    var piece = board[row, col];
                    if (piece == null) continue;

                    int value = piece.Type switch
                    {
                        PieceType.Pawn => 100,
                        PieceType.Knight => 320,
                        PieceType.Bishop => 330,
                        PieceType.Rook => 500,
                        PieceType.Queen => 900,
                        PieceType.King => 20000,
                        _ => 0
                    };

                    // Position bonuses
                    if (piece.Type == PieceType.Pawn)
                    {
                        int rank = piece.Color == Color.White ? 7 - row : row;
                        value += rank * 5;
                    }

                    // Center control bonus
                    if ((row >= 3 && row <= 4) && (col >= 3 && col <= 4))
                    {
                        value += 10;
                    }

                    score += piece.Color == Color.White ? value : -value;
                }
            }
            return score;
        }

        private Piece?[,] DeepCopyBoard()
        {
            var copy = new Piece?[8, 8];
            for (int row = 0; row < 8; row++)
            {
                for (int col = 0; col < 8; col++)
                {
                    var piece = board[row, col];
                    if (piece != null)
                    {
                        copy[row, col] = new Piece(piece.Type, piece.Color);
                    }
                }
            }
            return copy;
        }

        public int Perft(int depth)
        {
            if (depth == 0) return 1;

            var moves = GetLegalMoves();
            if (depth == 1) return moves.Count;

            int count = 0;
            foreach (var move in moves)
            {
                var boardCopy = DeepCopyBoard();
                var turn = CurrentTurn;
                var wck = WhiteCanCastleKingside;
                var wcq = WhiteCanCastleQueenside;
                var bck = BlackCanCastleKingside;
                var bcq = BlackCanCastleQueenside;
                var ep = EnPassantCol;
                var hm = HalfMoveClock;
                var fm = FullMoveNumber;

                MakeMove(move);
                count += Perft(depth - 1);

                board = boardCopy;
                CurrentTurn = turn;
                WhiteCanCastleKingside = wck;
                WhiteCanCastleQueenside = wcq;
                BlackCanCastleKingside = bck;
                BlackCanCastleQueenside = bcq;
                EnPassantCol = ep;
                HalfMoveClock = hm;
                FullMoveNumber = fm;
            }

            return count;
        }

        public (Move?, int) GetBestMove(int depth)
        {
            return Minimax(depth, int.MinValue, int.MaxValue, CurrentTurn == Color.White);
        }

        private (Move?, int) Minimax(int depth, int alpha, int beta, bool maximizing)
        {
            if (depth == 0 || IsCheckmate() || IsStalemate())
            {
                if (IsCheckmate())
                    return (null, maximizing ? -100000 : 100000);
                if (IsStalemate())
                    return (null, 0);
                return (null, Evaluate());
            }

            var moves = GetLegalMoves();
            Move? bestMove = null;
            int bestEval = maximizing ? int.MinValue : int.MaxValue;

            foreach (var move in moves)
            {
                var boardCopy = DeepCopyBoard();
                var turn = CurrentTurn;
                var wck = WhiteCanCastleKingside;
                var wcq = WhiteCanCastleQueenside;
                var bck = BlackCanCastleKingside;
                var bcq = BlackCanCastleQueenside;
                var ep = EnPassantCol;
                var hm = HalfMoveClock;
                var fm = FullMoveNumber;

                MakeMove(move);
                var (_, eval) = Minimax(depth - 1, alpha, beta, !maximizing);

                board = boardCopy;
                CurrentTurn = turn;
                WhiteCanCastleKingside = wck;
                WhiteCanCastleQueenside = wcq;
                BlackCanCastleKingside = bck;
                BlackCanCastleQueenside = bcq;
                EnPassantCol = ep;
                HalfMoveClock = hm;
                FullMoveNumber = fm;

                if (maximizing)
                {
                    if (eval > bestEval)
                    {
                        bestEval = eval;
                        bestMove = move;
                    }
                    alpha = Math.Max(alpha, eval);
                }
                else
                {
                    if (eval < bestEval)
                    {
                        bestEval = eval;
                        bestMove = move;
                    }
                    beta = Math.Min(beta, eval);
                }

                if (beta <= alpha)
                    break;
            }

            return (bestMove, bestEval);
        }
    }

    class Program
    {
        static void Main(string[] args)
        {
            ChessBoard board = new ChessBoard();
            Console.WriteLine("Chess Engine Ready");
            board.Display();

            while (true)
            {
                Console.Write("> ");
                string? input = Console.ReadLine();
                if (string.IsNullOrWhiteSpace(input))
                    continue;

                string[] parts = input.Trim().Split(' ', 2);
                string command = parts[0].ToLower();

                try
                {
                    switch (command)
                    {
                        case "new":
                            board = new ChessBoard();
                            Console.WriteLine("New game started");
                            board.Display();
                            break;

                        case "move":
                            if (parts.Length < 2)
                            {
                                Console.WriteLine("ERROR: Invalid move format");
                                break;
                            }
                            if (board.MakeMove(parts[1]))
                            {
                                Console.WriteLine($"OK: {parts[1]}");
                                board.Display();
                                if (board.IsCheckmate())
                                {
                                    Color winner = board.CurrentTurn == Color.White ? Color.Black : Color.White;
                                    Console.WriteLine($"CHECKMATE: {winner} wins");
                                }
                                else if (board.IsStalemate())
                                {
                                    Console.WriteLine("STALEMATE: Draw");
                                }
                            }
                            else
                            {
                                Console.WriteLine("ERROR: Illegal move");
                            }
                            break;

                        case "undo":
                            if (board.Undo())
                            {
                                Console.WriteLine("Move undone");
                                board.Display();
                            }
                            else
                            {
                                Console.WriteLine("ERROR: No moves to undo");
                            }
                            break;

                        case "fen":
                            if (parts.Length < 2)
                            {
                                Console.WriteLine("ERROR: Invalid FEN string");
                                break;
                            }
                            if (board.LoadFEN(parts[1]))
                            {
                                Console.WriteLine("Position loaded from FEN");
                                board.Display();
                            }
                            else
                            {
                                Console.WriteLine("ERROR: Invalid FEN string");
                            }
                            break;

                        case "export":
                            Console.WriteLine($"FEN: {board.ToFEN()}");
                            break;

                        case "eval":
                            Console.WriteLine($"Evaluation: {board.Evaluate()}");
                            break;

                        case "ai":
                            if (parts.Length < 2 || !int.TryParse(parts[1], out int depth))
                            {
                                Console.WriteLine("ERROR: AI depth must be 1-5");
                                break;
                            }
                            if (depth < 1 || depth > 5)
                            {
                                Console.WriteLine("ERROR: AI depth must be 1-5");
                                break;
                            }

                            var startTime = DateTime.Now;
                            var (bestMove, eval) = board.GetBestMove(depth);
                            var elapsed = (DateTime.Now - startTime).TotalMilliseconds;

                            if (bestMove != null)
                            {
                                string moveStr = bestMove.ToString();
                                board.MakeMove(moveStr);
                                Console.WriteLine($"AI: {moveStr} (depth={depth}, eval={eval}, time={elapsed:F0}ms)");
                                board.Display();
                                if (board.IsCheckmate())
                                {
                                    Color winner = board.CurrentTurn == Color.White ? Color.Black : Color.White;
                                    Console.WriteLine($"CHECKMATE: {winner} wins");
                                }
                                else if (board.IsStalemate())
                                {
                                    Console.WriteLine("STALEMATE: Draw");
                                }
                            }
                            else
                            {
                                Console.WriteLine("No legal moves available");
                            }
                            break;

                        case "perft":
                            if (parts.Length < 2 || !int.TryParse(parts[1], out int perftDepth))
                            {
                                Console.WriteLine("ERROR: Invalid perft depth");
                                break;
                            }
                            var perftStart = DateTime.Now;
                            int nodeCount = board.Perft(perftDepth);
                            var perftElapsed = (DateTime.Now - perftStart).TotalMilliseconds;
                            Console.WriteLine($"Perft({perftDepth}): {nodeCount} nodes in {perftElapsed:F0}ms");
                            break;

                        case "moves":
                            var legalMoves = board.GetLegalMoves();
                            Console.WriteLine($"Legal moves ({legalMoves.Count}):");
                            foreach (var move in legalMoves)
                            {
                                Console.WriteLine($"  {move}");
                            }
                            break;

                        case "help":
                            Console.WriteLine("Available commands:");
                            Console.WriteLine("  new              - Start a new game");
                            Console.WriteLine("  move <from><to>  - Make a move (e.g., move e2e4)");
                            Console.WriteLine("  undo             - Undo last move");
                            Console.WriteLine("  fen <string>     - Load position from FEN");
                            Console.WriteLine("  export           - Export current position as FEN");
                            Console.WriteLine("  eval             - Display position evaluation");
                            Console.WriteLine("  ai <depth>       - AI makes a move (depth 1-5)");
                            Console.WriteLine("  perft <depth>    - Run perft test");
                            Console.WriteLine("  help             - Display this help");
                            Console.WriteLine("  quit             - Exit the program");
                            break;

                        case "quit":
                        case "exit":
                            Console.WriteLine("Goodbye!");
                            return;

                        default:
                            Console.WriteLine("ERROR: Invalid command");
                            break;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"ERROR: {ex.Message}");
                }
            }
        }
    }
}
