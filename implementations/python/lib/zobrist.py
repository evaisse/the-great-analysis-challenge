import typing
from lib.types import Piece, Color, PieceType

class ZobristKeys:
    def __init__(self):
        self.pieces = [[0] * 64 for _ in range(12)]
        self.side_to_move = 0
        self.castling = [0] * 4
        self.en_passant = [0] * 8

        state = 0x123456789ABCDEF0
        mask64 = 0xFFFFFFFFFFFFFFFF

        def next_rand():
            nonlocal state
            state ^= (state << 13) & mask64
            state ^= (state >> 7)
            state ^= (state << 17) & mask64
            return state

        for p in range(12):
            for s in range(64):
                self.pieces[p][s] = next_rand()

        self.side_to_move = next_rand()

        for i in range(4):
            self.castling[i] = next_rand()

        for i in range(8):
            self.en_passant[i] = next_rand()

    def get_piece_index(self, piece: Piece) -> int:
        type_to_idx = {
            PieceType.PAWN: 0,
            PieceType.KNIGHT: 1,
            PieceType.BISHOP: 2,
            PieceType.ROOK: 3,
            PieceType.QUEEN: 4,
            PieceType.KING: 5
        }
        idx = type_to_idx[piece.type]
        if piece.color == Color.BLACK:
            idx += 6
        return idx

    def compute_hash(self, board) -> int:
        hash_val = 0
        for row in range(8):
            for col in range(8):
                piece = board.get_piece(row, col)
                if piece:
                    square = row * 8 + col
                    idx = self.get_piece_index(piece)
                    hash_val ^= self.pieces[idx][square]

        if board.to_move == Color.BLACK:
            hash_val ^= self.side_to_move

        rights = board.castling_rights
        if rights.white_kingside: hash_val ^= self.castling[0]
        if rights.white_queenside: hash_val ^= self.castling[1]
        if rights.black_kingside: hash_val ^= self.castling[2]
        if rights.black_queenside: hash_val ^= self.castling[3]

        if board.en_passant_target:
            _, col = board.en_passant_target
            hash_val ^= self.en_passant[col]

        return hash_val

zobrist = ZobristKeys()
