# frozen_string_literal: true

module Chess
  class ZobristKeys
    attr_reader :pieces, :side_to_move, :castling, :en_passant

    def initialize
      @pieces = Array.new(12) { Array.new(64, 0) }
      @side_to_move = 0
      @castling = Array.new(4, 0)
      @en_passant = Array.new(8, 0)

      state = 0x123456789ABCDEF0
      mask64 = 0xFFFFFFFFFFFFFFFF

      next_rand = lambda {
        state ^= (state << 13) & mask64
        state ^= (state >> 7)
        state ^= (state << 17) & mask64
        state
      }

      12.times do |p|
        64.times do |s|
          @pieces[p][s] = next_rand.call
        end
      end

      @side_to_move = next_rand.call

      4.times do |i|
        @castling[i] = next_rand.call
      end

      8.times do |i|
        @en_passant[i] = next_rand.call
      end
    end

    def piece_index(piece)
      type_to_idx = {
        pawn: 0, knight: 1, bishop: 2, rook: 3, queen: 4, king: 5
      }
      idx = type_to_idx[piece.type]
      idx += 6 if piece.color == :black
      idx
    end

    def compute_hash(board)
      hash_val = 0
      8.times do |row|
        8.times do |col|
          piece = board.piece_at(row, col)
          if piece
            # Map row 0-7 (rank 8-1) to square 0-63 (a1-h8)
            square = (7 - row) * 8 + col
            idx = piece_index(piece)
            hash_val ^= @pieces[idx][square]
          end
        end
      end

      hash_val ^= @side_to_move if board.current_turn == :black

      rights = board.castling_rights
      hash_val ^= @castling[0] if rights.white_kingside
      hash_val ^= @castling[1] if rights.white_queenside
      hash_val ^= @castling[2] if rights.black_kingside
      hash_val ^= @castling[3] if rights.black_queenside

      if board.en_passant_target
        _, col = board.en_passant_target
        hash_val ^= @en_passant[col]
      end

      hash_val
    end
  end

  ZOBRIST = ZobristKeys.new
end
