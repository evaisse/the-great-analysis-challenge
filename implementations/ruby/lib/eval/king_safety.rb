# frozen_string_literal: true

module Chess
  module Eval
    module KingSafety
      PAWN_SHIELD_BONUS = 20
      OPEN_FILE_PENALTY = -30
      SEMI_OPEN_FILE_PENALTY = -15
      ATTACKER_WEIGHT = 10

      def self.evaluate(board)
        score = 0
        score += evaluate_king_safety(board, :white)
        score -= evaluate_king_safety(board, :black)
        score
      end

      def self.evaluate_king_safety(board, color)
        king_square = find_king(board, color)
        return 0 unless king_square

        score = 0
        score += evaluate_pawn_shield(board, king_square, color)
        score += evaluate_open_files(board, king_square, color)
        score -= evaluate_attackers(board, king_square, color)
        score
      end

      def self.find_king(board, color)
        64.times do |square|
          piece = board.get_piece(square)
          return square if piece && piece.color == color && piece.type == :king
        end
        nil
      end

      def self.evaluate_pawn_shield(board, king_square, color)
        king_file = king_square % 8
        king_rank = king_square / 8
        shield_count = 0

        shield_ranks = if color == :white
                         [king_rank + 1, king_rank + 2]
                       else
                         [[king_rank - 1, 0].max, [king_rank - 2, 0].max]
                       end

        ([king_file - 1, 0].max..[king_file + 1, 7].min).each do |file|
          shield_ranks.each do |rank|
            next if rank >= 8

            square = rank * 8 + file
            piece = board.get_piece(square)

            shield_count += 1 if piece && piece.color == color && piece.type == :pawn
          end
        end

        shield_count * PAWN_SHIELD_BONUS
      end

      def self.evaluate_open_files(board, king_square, color)
        king_file = king_square % 8
        penalty = 0

        ([king_file - 1, 0].max..[king_file + 1, 7].min).each do |file|
          own_pawns, enemy_pawns = count_pawns_on_file(board, file, color)

          if own_pawns == 0 && enemy_pawns == 0
            penalty += OPEN_FILE_PENALTY
          elsif own_pawns == 0
            penalty += SEMI_OPEN_FILE_PENALTY
          end
        end

        penalty
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

      def self.evaluate_attackers(board, king_square, color)
        king_file = king_square % 8
        king_rank = king_square / 8
        attacker_count = 0

        adjacent_squares = [
          [-1, -1], [-1, 0], [-1, 1],
          [0, -1],           [0, 1],
          [1, -1],  [1, 0],  [1, 1]
        ]

        adjacent_squares.each do |dr, df|
          new_rank = king_rank + dr
          new_file = king_file + df

          next unless new_rank >= 0 && new_rank < 8 && new_file >= 0 && new_file < 8

          target_square = new_rank * 8 + new_file
          attacker_count += 1 if attacked_by_enemy?(board, target_square, color)
        end

        attacker_count * ATTACKER_WEIGHT
      end

      def self.attacked_by_enemy?(board, square, color)
        64.times do |attacker_square|
          piece = board.get_piece(attacker_square)
          next unless piece && piece.color != color

          return true if can_attack?(board, attacker_square, square, piece.type, piece.color)
        end
        false
      end

      def self.can_attack?(board, from, to, piece_type, color)
        from_rank = from / 8
        from_file = from % 8
        to_rank = to / 8
        to_file = to % 8
        rank_diff = (to_rank - from_rank).abs
        file_diff = (to_file - from_file).abs

        case piece_type
        when :pawn
          forward = color == :white ? 1 : -1
          to_rank - from_rank == forward && file_diff == 1
        when :knight
          (rank_diff == 2 && file_diff == 1) || (rank_diff == 1 && file_diff == 2)
        when :king
          rank_diff <= 1 && file_diff <= 1
        else
          false
        end
      end
    end
  end
end
