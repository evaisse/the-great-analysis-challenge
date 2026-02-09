# frozen_string_literal: true

module Chess
  module Eval
    module Positional
      BISHOP_PAIR_BONUS = 30
      ROOK_OPEN_FILE_BONUS = 25
      ROOK_SEMI_OPEN_FILE_BONUS = 15
      ROOK_SEVENTH_RANK_BONUS = 20
      KNIGHT_OUTPOST_BONUS = 20

      def self.evaluate(board)
        score = 0
        score += evaluate_color(board, :white)
        score -= evaluate_color(board, :black)
        score
      end

      def self.evaluate_color(board, color)
        score = 0

        score += BISHOP_PAIR_BONUS if bishop_pair?(board, color)

        64.times do |square|
          piece = board.get_piece(square)
          next unless piece && piece.color == color

          case piece.type
          when :rook
            score += evaluate_rook(board, square, color)
          when :knight
            score += evaluate_knight(board, square, color)
          end
        end

        score
      end

      def self.bishop_pair?(board, color)
        bishop_count = 0

        64.times do |square|
          piece = board.get_piece(square)
          bishop_count += 1 if piece && piece.color == color && piece.type == :bishop
        end

        bishop_count >= 2
      end

      def self.evaluate_rook(board, square, color)
        file = square % 8
        rank = square / 8
        bonus = 0

        own_pawns, enemy_pawns = count_pawns_on_file(board, file, color)

        if own_pawns == 0 && enemy_pawns == 0
          bonus += ROOK_OPEN_FILE_BONUS
        elsif own_pawns == 0
          bonus += ROOK_SEMI_OPEN_FILE_BONUS
        end

        seventh_rank = color == :white ? 6 : 1
        bonus += ROOK_SEVENTH_RANK_BONUS if rank == seventh_rank

        bonus
      end

      def self.evaluate_knight(board, square, color)
        outpost?(board, square, color) ? KNIGHT_OUTPOST_BONUS : 0
      end

      def self.outpost?(board, square, color)
        file = square % 8
        rank = square / 8

        protected_by_pawn = protected_by_pawn?(board, square, color)
        return false unless protected_by_pawn

        cannot_be_attacked = !can_be_attacked_by_enemy_pawn?(board, square, file, rank, color)

        protected_by_pawn && cannot_be_attacked
      end

      def self.protected_by_pawn?(board, square, color)
        file = square % 8
        rank = square / 8

        behind_rank = if color == :white
                        [rank - 1, 0].max
                      else
                        [rank + 1, 7].min
                      end

        [[file - 1, 0].max, [file + 1, 7].min].each do |adjacent_file|
          next if adjacent_file == file

          check_square = behind_rank * 8 + adjacent_file
          piece = board.get_piece(check_square)

          return true if piece && piece.color == color && piece.type == :pawn
        end

        false
      end

      def self.can_be_attacked_by_enemy_pawn?(board, square, file, rank, color)
        ahead_ranks = if color == :white
                        (rank + 1)...8
                      else
                        0...rank
                      end

        ahead_ranks.each do |check_rank|
          [[file - 1, 0].max, [file + 1, 7].min].each do |adjacent_file|
            next if adjacent_file == file

            check_square = check_rank * 8 + adjacent_file
            piece = board.get_piece(check_square)

            return true if piece && piece.color != color && piece.type == :pawn
          end
        end

        false
      end

      def self.count_pawns_on_file(board, file, color)
        own_pawns = 0
        enemy_pawns = 0

        8.times do |rank|
          square = rank * 8 + file
          piece = board.get_piece(square)

          if piece && piece.type == :pawn
            if piece.color == color
              own_pawns += 1
            else
              enemy_pawns += 1
            end
          end
        end

        [own_pawns, enemy_pawns]
      end
    end
  end
end
