# frozen_string_literal: true

module Chess
  module Eval
    module PawnStructure
      PASSED_PAWN_BONUS = [0, 10, 20, 40, 60, 90, 120, 0].freeze
      DOUBLED_PAWN_PENALTY = -20
      ISOLATED_PAWN_PENALTY = -15
      BACKWARD_PAWN_PENALTY = -10
      CONNECTED_PAWN_BONUS = 5
      PAWN_CHAIN_BONUS = 10

      def self.evaluate(board)
        score = 0
        score += evaluate_color(board, :white)
        score -= evaluate_color(board, :black)
        score
      end

      def self.evaluate_color(board, color)
        score = 0
        pawn_files = Array.new(8, 0)
        pawn_positions = []

        64.times do |square|
          piece = board.get_piece(square)
          next unless piece && piece.color == color && piece.type == :pawn

          file = square % 8
          rank = square / 8
          pawn_files[file] += 1
          pawn_positions << [square, rank, file]
        end

        pawn_positions.each do |square, rank, file|
          # Doubled pawn penalty
          score += DOUBLED_PAWN_PENALTY if pawn_files[file] > 1

          # Isolated pawn penalty
          score += ISOLATED_PAWN_PENALTY if isolated?(file, pawn_files)

          # Passed pawn bonus
          if passed?(board, square, rank, file, color)
            bonus_rank = color == :white ? rank : 7 - rank
            score += PASSED_PAWN_BONUS[bonus_rank]
          end

          # Connected pawn bonus
          score += CONNECTED_PAWN_BONUS if connected?(board, square, file, color)

          # Pawn chain bonus
          score += PAWN_CHAIN_BONUS if in_chain?(board, square, rank, file, color)

          # Backward pawn penalty
          score += BACKWARD_PAWN_PENALTY if backward?(board, square, rank, file, color, pawn_files)
        end

        score
      end

      def self.isolated?(file, pawn_files)
        left_file = file > 0 ? pawn_files[file - 1] : 0
        right_file = file < 7 ? pawn_files[file + 1] : 0
        left_file == 0 && right_file == 0
      end

      def self.passed?(board, square, rank, file, color)
        if color == :white
          start_rank = rank + 1
          end_rank = 8
        else
          start_rank = 0
          end_rank = rank
        end

        check_files = [[file - 1, 0].max, file, [file + 1, 7].min].uniq

        check_files.each do |check_file|
          current_rank = start_rank
          loop do
            break if color == :white && current_rank >= end_rank
            break if color == :black && current_rank >= end_rank

            check_square = current_rank * 8 + check_file
            piece = board.get_piece(check_square)

            if piece && piece.type == :pawn && piece.color != color
              return false
            end

            current_rank += color == :white ? 1 : -1
            break if color == :white && current_rank >= 8
            break if color == :black && current_rank < 0
          end
        end

        true
      end

      def self.connected?(board, square, file, color)
        rank = square / 8

        [[file - 1, 0].max, [file + 1, 7].min].each do |adjacent_file|
          next if adjacent_file == file

          adjacent_square = rank * 8 + adjacent_file
          piece = board.get_piece(adjacent_square)

          return true if piece && piece.color == color && piece.type == :pawn
        end

        false
      end

      def self.in_chain?(board, square, rank, file, color)
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

      def self.backward?(board, square, rank, file, color, pawn_files)
        left_file = [file - 1, 0].max
        right_file = [file + 1, 7].min

        [left_file, right_file].each do |adjacent_file|
          next if adjacent_file == file || pawn_files[adjacent_file] == 0

          64.times do |check_square|
            piece = board.get_piece(check_square)
            next unless piece && piece.color == color && piece.type == :pawn

            check_file = check_square % 8
            check_rank = check_square / 8

            next unless check_file == adjacent_file

            is_ahead = if color == :white
                         check_rank > rank
                       else
                         check_rank < rank
                       end

            return false if is_ahead
          end
        end

        false
      end
    end
  end
end
