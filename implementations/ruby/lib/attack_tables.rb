# frozen_string_literal: true

module Chess
  module AttackTables
    module_function

    KNIGHT_DELTAS = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1]
    ].freeze

    KING_DELTAS = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],           [0, 1],
      [1, -1], [1, 0], [1, 1]
    ].freeze

    BISHOP_DELTAS = [[-1, -1], [-1, 1], [1, -1], [1, 1]].freeze
    ROOK_DELTAS = [[-1, 0], [1, 0], [0, -1], [0, 1]].freeze
    QUEEN_DELTAS = (BISHOP_DELTAS + ROOK_DELTAS).freeze

    def knight_attacks(row, col)
      KNIGHT_ATTACKS[square_index(row, col)]
    end

    def king_attacks(row, col)
      KING_ATTACKS[square_index(row, col)]
    end

    def bishop_rays(row, col)
      BISHOP_RAYS[square_index(row, col)]
    end

    def rook_rays(row, col)
      ROOK_RAYS[square_index(row, col)]
    end

    def queen_rays(row, col)
      QUEEN_RAYS[square_index(row, col)]
    end

    def chebyshev_distance(from_row, from_col, to_row, to_col)
      CHEBYSHEV_DISTANCE[square_index(from_row, from_col)][square_index(to_row, to_col)]
    end

    def manhattan_distance(from_row, from_col, to_row, to_col)
      MANHATTAN_DISTANCE[square_index(from_row, from_col)][square_index(to_row, to_col)]
    end

    def build_attack_table(deltas)
      (0..7).flat_map do |row|
        (0..7).map do |col|
          deltas.filter_map do |row_delta, col_delta|
            next_row = row + row_delta
            next_col = col + col_delta
            [next_row, next_col] if valid_position?(next_row, next_col)
          end.freeze
        end
      end.freeze
    end

    def build_ray_table(deltas)
      (0..7).flat_map do |row|
        (0..7).map do |col|
          deltas.map { |delta| build_ray(row, col, delta) }.freeze
        end
      end.freeze
    end

    def build_ray(row, col, delta)
      row_delta, col_delta = delta
      ray = []
      next_row = row + row_delta
      next_col = col + col_delta

      while valid_position?(next_row, next_col)
        ray << [next_row, next_col]
        next_row += row_delta
        next_col += col_delta
      end

      ray.freeze
    end

    def build_distance_table
      (0..63).map do |from_index|
        from_row, from_col = index_to_square(from_index)
        (0..63).map do |to_index|
          to_row, to_col = index_to_square(to_index)
          yield((from_row - to_row).abs, (from_col - to_col).abs)
        end.freeze
      end.freeze
    end

    def square_index(row, col)
      (row * 8) + col
    end

    def index_to_square(index)
      [index / 8, index % 8]
    end

    def valid_position?(row, col)
      row.between?(0, 7) && col.between?(0, 7)
    end

    KNIGHT_ATTACKS = build_attack_table(KNIGHT_DELTAS).freeze
    KING_ATTACKS = build_attack_table(KING_DELTAS).freeze
    BISHOP_RAYS = build_ray_table(BISHOP_DELTAS).freeze
    ROOK_RAYS = build_ray_table(ROOK_DELTAS).freeze
    QUEEN_RAYS = build_ray_table(QUEEN_DELTAS).freeze
    CHEBYSHEV_DISTANCE = build_distance_table { |dr, dc| [dr, dc].max }.freeze
    MANHATTAN_DISTANCE = build_distance_table { |dr, dc| dr + dc }.freeze
  end
end
