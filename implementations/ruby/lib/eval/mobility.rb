# frozen_string_literal: true

module Chess
  module Eval
    module Mobility
      KNIGHT_MOBILITY = [-15, -5, 0, 5, 10, 15, 20, 22, 24].freeze
      BISHOP_MOBILITY = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34].freeze
      ROOK_MOBILITY = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28].freeze
      QUEEN_MOBILITY = [
        -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
      ].freeze

      def self.evaluate(board)
        score = 0

        64.times do |square|
          piece = board.get_piece(square)
          next unless piece

          mobility = case piece.type
                     when :knight then count_knight_mobility(board, square, piece.color)
                     when :bishop then count_bishop_mobility(board, square, piece.color)
                     when :rook then count_rook_mobility(board, square, piece.color)
                     when :queen then count_queen_mobility(board, square, piece.color)
                     else next
                     end

          bonus = get_mobility_bonus(piece.type, mobility)
          score += piece.color == :white ? bonus : -bonus
        end

        score
      end

      def self.count_knight_mobility(board, square, _color)
        offsets = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1]
        ]

        rank = square / 8
        file = square % 8
        count = 0

        offsets.each do |dr, df|
          new_rank = rank + dr
          new_file = file + df

          next unless new_rank >= 0 && new_rank < 8 && new_file >= 0 && new_file < 8

          target = new_rank * 8 + new_file
          target_piece = board.get_piece(target)

          if target_piece.nil? || target_piece.color != board.get_piece(square).color
            count += 1
          end
        end

        count
      end

      def self.count_bishop_mobility(board, square, color)
        count_sliding_mobility(board, square, color, [[1, 1], [1, -1], [-1, 1], [-1, -1]])
      end

      def self.count_rook_mobility(board, square, color)
        count_sliding_mobility(board, square, color, [[0, 1], [0, -1], [1, 0], [-1, 0]])
      end

      def self.count_queen_mobility(board, square, color)
        count_sliding_mobility(board, square, color, [
          [0, 1], [0, -1], [1, 0], [-1, 0],
          [1, 1], [1, -1], [-1, 1], [-1, -1]
        ])
      end

      def self.count_sliding_mobility(board, square, color, directions)
        rank = square / 8
        file = square % 8
        count = 0

        directions.each do |dr, df|
          current_rank = rank + dr
          current_file = file + df

          while current_rank >= 0 && current_rank < 8 && current_file >= 0 && current_file < 8
            target = current_rank * 8 + current_file
            target_piece = board.get_piece(target)

            if target_piece
              count += 1 if target_piece.color != color
              break
            else
              count += 1
            end

            current_rank += dr
            current_file += df
          end
        end

        count
      end

      def self.get_mobility_bonus(piece_type, mobility)
        case piece_type
        when :knight then KNIGHT_MOBILITY[[mobility, 8].min]
        when :bishop then BISHOP_MOBILITY[[mobility, 13].min]
        when :rook then ROOK_MOBILITY[[mobility, 14].min]
        when :queen then QUEEN_MOBILITY[[mobility, 27].min]
        else 0
        end
      end
    end
  end
end
