# frozen_string_literal: true

require_relative 'tables'
require_relative 'tapered'
require_relative 'mobility'
require_relative 'pawn_structure'
require_relative 'king_safety'
require_relative 'positional'

module Chess
  module Eval
    class RichEvaluator
      def initialize
        # RichEvaluator is stateless, no initialization needed
      end

      def evaluate(board)
        phase = compute_phase(board)

        mg_score = evaluate_phase(board, true)
        eg_score = evaluate_phase(board, false)

        tapered_score = Tapered.interpolate(mg_score, eg_score, phase)

        mobility_score = Mobility.evaluate(board)
        pawn_score = PawnStructure.evaluate(board)
        king_score = KingSafety.evaluate(board)
        positional_score = Positional.evaluate(board)

        tapered_score + mobility_score + pawn_score + king_score + positional_score
      end

      private

      def compute_phase(board)
        phase = 0

        64.times do |square|
          piece = board.get_piece(square)
          next unless piece

          phase += case piece.type
                   when :knight then 1
                   when :bishop then 1
                   when :rook then 2
                   when :queen then 4
                   else 0
                   end
        end

        [phase, 24].min
      end

      def evaluate_phase(board, middlegame)
        score = 0

        64.times do |square|
          piece = board.get_piece(square)
          next unless piece

          value = piece.value
          position_bonus = if middlegame
                             Tables.get_middlegame_bonus(square, piece.type, piece.color)
                           else
                             Tables.get_endgame_bonus(square, piece.type, piece.color)
                           end

          total_value = value + position_bonus
          score += piece.color == :white ? total_value : -total_value
        end

        score
      end
    end
  end
end
