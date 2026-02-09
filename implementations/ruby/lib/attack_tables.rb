# frozen_string_literal: true

module Chess
  module AttackTables
    # Convert row, col to square index (0-63, where 0 = a1, 63 = h8)
    # Note: The Ruby chess engine uses row 0 = rank 8 (black's back rank)
    # and row 7 = rank 1 (white's back rank), so we convert:
    # square_index = (7 - row) * 8 + col
    # This maps: row=7, col=0 (a1) -> square 0
    #            row=0, col=7 (h8) -> square 63
    def self.square_index(row, col)
      (7 - row) * 8 + col
    end

    # Convert square index to row, col
    # Inverse of square_index: converts back from 0-63 to row/col coordinates
    def self.row_col(square)
      row = 7 - (square / 8)
      col = square % 8
      [row, col]
    end

    # Check if position is valid
    def self.valid_position?(row, col)
      row.between?(0, 7) && col.between?(0, 7)
    end

    # Generate knight attack table
    def self.generate_knight_attacks
      knight_offsets = [
        [-2, -1], [-2, 1], [-1, -2], [-1, 2],
        [1, -2], [1, 2], [2, -1], [2, 1]
      ]

      attacks = Array.new(64) { [] }

      64.times do |square|
        row, col = row_col(square)
        attacked_squares = []

        knight_offsets.each do |row_offset, col_offset|
          new_row = row + row_offset
          new_col = col + col_offset

          if valid_position?(new_row, new_col)
            attacked_squares << square_index(new_row, new_col)
          end
        end

        attacks[square] = attacked_squares.freeze
      end

      attacks.freeze
    end

    # Generate king attack table
    def self.generate_king_attacks
      king_offsets = [
        [-1, -1], [-1, 0], [-1, 1],
        [0, -1],           [0, 1],
        [1, -1],  [1, 0],  [1, 1]
      ]

      attacks = Array.new(64) { [] }

      64.times do |square|
        row, col = row_col(square)
        attacked_squares = []

        king_offsets.each do |row_offset, col_offset|
          new_row = row + row_offset
          new_col = col + col_offset

          if valid_position?(new_row, new_col)
            attacked_squares << square_index(new_row, new_col)
          end
        end

        attacks[square] = attacked_squares.freeze
      end

      attacks.freeze
    end

    # Generate ray tables for sliding pieces
    # Returns a 3D array: [direction][square] => array of squares in that direction
    # Directions: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
    def self.generate_ray_tables
      directions = [
        [-1, 0],  # North
        [-1, 1],  # North-East
        [0, 1],   # East
        [1, 1],   # South-East
        [1, 0],   # South
        [1, -1],  # South-West
        [0, -1],  # West
        [-1, -1]  # North-West
      ]

      rays = Array.new(8) { Array.new(64) { [] } }

      8.times do |dir|
        row_offset, col_offset = directions[dir]

        64.times do |square|
          row, col = row_col(square)
          ray_squares = []

          new_row = row + row_offset
          new_col = col + col_offset

          while valid_position?(new_row, new_col)
            ray_squares << square_index(new_row, new_col)
            new_row += row_offset
            new_col += col_offset
          end

          rays[dir][square] = ray_squares.freeze
        end
      end

      rays.each(&:freeze)
      rays.freeze
    end

    # Generate Chebyshev distance table (max of row/col distance)
    def self.generate_chebyshev_distance
      distances = Array.new(64) { Array.new(64, 0) }

      64.times do |sq1|
        row1, col1 = row_col(sq1)

        64.times do |sq2|
          row2, col2 = row_col(sq2)

          row_dist = (row1 - row2).abs
          col_dist = (col1 - col2).abs
          distances[sq1][sq2] = [row_dist, col_dist].max
        end

        distances[sq1].freeze
      end

      distances.freeze
    end

    # Generate Manhattan distance table (sum of row/col distance)
    def self.generate_manhattan_distance
      distances = Array.new(64) { Array.new(64, 0) }

      64.times do |sq1|
        row1, col1 = row_col(sq1)

        64.times do |sq2|
          row2, col2 = row_col(sq2)

          row_dist = (row1 - row2).abs
          col_dist = (col1 - col2).abs
          distances[sq1][sq2] = row_dist + col_dist
        end

        distances[sq1].freeze
      end

      distances.freeze
    end

    # Pre-calculated attack tables
    KNIGHT_ATTACKS = generate_knight_attacks
    KING_ATTACKS = generate_king_attacks
    RAY_TABLES = generate_ray_tables
    CHEBYSHEV_DISTANCE = generate_chebyshev_distance
    MANHATTAN_DISTANCE = generate_manhattan_distance

    # Direction constants for ray tables
    NORTH = 0
    NORTH_EAST = 1
    EAST = 2
    SOUTH_EAST = 3
    SOUTH = 4
    SOUTH_WEST = 5
    WEST = 6
    NORTH_WEST = 7
  end
end
