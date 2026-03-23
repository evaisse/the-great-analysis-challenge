# Precomputed attack and distance lookup tables

require "./types"

module AttackTables
  KNIGHT_DELTAS = [
    {-1, -2}, {1, -2},
    {-2, -1}, {2, -1},
    {-2, 1}, {2, 1},
    {-1, 2}, {1, 2},
  ]

  KING_DELTAS = [
    {-1, -1}, {0, -1}, {1, -1},
    {-1, 0}, {1, 0},
    {-1, 1}, {0, 1}, {1, 1},
  ]

  BISHOP_DELTAS = [{-1, -1}, {1, -1}, {-1, 1}, {1, 1}]
  ROOK_DELTAS   = [{0, -1}, {-1, 0}, {1, 0}, {0, 1}]
  QUEEN_DELTAS  = BISHOP_DELTAS + ROOK_DELTAS

  KNIGHT_ATTACKS     = build_attack_table(KNIGHT_DELTAS)
  KING_ATTACKS       = build_attack_table(KING_DELTAS)
  BISHOP_RAYS        = build_ray_table(BISHOP_DELTAS)
  ROOK_RAYS          = build_ray_table(ROOK_DELTAS)
  QUEEN_RAYS         = build_ray_table(QUEEN_DELTAS)
  CHEBYSHEV_DISTANCE = build_distance_table { |file_distance, rank_distance| {file_distance, rank_distance}.max }
  MANHATTAN_DISTANCE = build_distance_table { |file_distance, rank_distance| file_distance + rank_distance }

  def self.knight_attacks(square : Square) : Array(Square)
    KNIGHT_ATTACKS[square]
  end

  def self.king_attacks(square : Square) : Array(Square)
    KING_ATTACKS[square]
  end

  def self.bishop_rays(square : Square) : Array(Array(Square))
    BISHOP_RAYS[square]
  end

  def self.rook_rays(square : Square) : Array(Array(Square))
    ROOK_RAYS[square]
  end

  def self.queen_rays(square : Square) : Array(Array(Square))
    QUEEN_RAYS[square]
  end

  def self.chebyshev_distance(from : Square, to : Square) : Int32
    CHEBYSHEV_DISTANCE[from][to]
  end

  def self.manhattan_distance(from : Square, to : Square) : Int32
    MANHATTAN_DISTANCE[from][to]
  end

  private def self.build_attack_table(deltas : Array(Tuple(Int32, Int32))) : Array(Array(Square))
    Array.new(64) do |square|
      file = square % 8
      rank = square // 8
      attacks = Array(Square).new

      deltas.each do |df, dr|
        target_file = file + df
        target_rank = rank + dr
        if target_file >= 0 && target_file < 8 && target_rank >= 0 && target_rank < 8
          attacks << (target_rank * 8 + target_file).to_i32
        end
      end

      attacks
    end
  end

  private def self.build_ray_table(deltas : Array(Tuple(Int32, Int32))) : Array(Array(Array(Square)))
    Array.new(64) do |square|
      file = square % 8
      rank = square // 8

      deltas.map do |df, dr|
        ray = Array(Square).new
        target_file = file + df
        target_rank = rank + dr

        while target_file >= 0 && target_file < 8 && target_rank >= 0 && target_rank < 8
          ray << (target_rank * 8 + target_file).to_i32
          target_file += df
          target_rank += dr
        end

        ray
      end
    end
  end

  private def self.build_distance_table(&metric : Int32, Int32 -> Int32) : Array(Array(Int32))
    Array.new(64) do |from|
      from_file = from % 8
      from_rank = from // 8

      Array.new(64) do |to|
        file_distance = (from_file - (to % 8)).abs.to_i32
        rank_distance = (from_rank - (to // 8)).abs.to_i32
        yield file_distance, rank_distance
      end
    end
  end
end
