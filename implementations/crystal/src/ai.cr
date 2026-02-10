# Chess AI following Standard AI Algorithm Specification v1.0

require "./types"
require "./board"
require "./move_generator"

class ChessAI
  @move_generator : MoveGenerator

  # Piece-Square Tables (from AI Specification)
  PAWN_TABLE = [
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0
  ]

  KNIGHT_TABLE = [
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50
  ]

  BISHOP_TABLE = [
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -20,-10,-10,-10,-10,-10,-10,-20
  ]

  ROOK_TABLE = [
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
     0,  0,  0,  5,  5,  0,  0,  0
  ]

  QUEEN_TABLE = [
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5,  5,  5,  5,  0,-10,
     -5,  0,  5,  5,  5,  5,  0, -5,
      0,  0,  5,  5,  5,  5,  0, -5,
    -10,  5,  5,  5,  5,  5,  0,-10,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20
  ]

  KING_TABLE = [
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -10,-20,-20,-20,-20,-20,-20,-10,
     20, 20,  0,  0,  0,  0, 20, 20,
     20, 30, 10,  0,  0, 10, 30, 20
  ]

  def initialize
    @move_generator = MoveGenerator.new
  end

  def search(game_state : GameState, depth : Int32, maximize : Bool = true) : SearchResult
    start_time = Time.monotonic
    nodes = 0
    
    best_move, evaluation = minimax_root(game_state, depth, Int32::MIN + 1, Int32::MAX - 1, pointerof(nodes))
    
    time_ms = (Time.monotonic - start_time).total_milliseconds.to_i64
    
    SearchResult.new(best_move, evaluation, nodes, time_ms)
  end

  private def minimax_root(game_state : GameState, depth : Int32, alpha : Int32, beta : Int32, nodes : Int32*) : {Move?, Int32}
    moves = @move_generator.get_legal_moves(game_state, game_state.turn)
    return {nil, evaluate(game_state)} if moves.empty? || depth == 0

    ordered_moves = order_moves(moves, game_state)
    
    best_move : Move? = nil
    maximizing = game_state.turn.white?
    best_score = maximizing ? Int32::MIN + 1 : Int32::MAX - 1
    
    current_alpha = alpha
    current_beta = beta

    ordered_moves.each do |move|
      new_state = Board.make_move(game_state, move)
      score = minimax(new_state, depth - 1, current_alpha, current_beta, !maximizing, nodes)
      
      if maximizing
        if score > best_score || best_move.nil?
          best_score = score
          best_move = move
        end
        current_alpha = [current_alpha, score].max
      else
        if score < best_score || best_move.nil?
          best_score = score
          best_move = move
        end
        current_beta = [current_beta, score].min
      end
      
      break if current_beta <= current_alpha
    end
    
    {best_move, best_score}
  end

  private def minimax(game_state : GameState, depth : Int32, alpha : Int32, beta : Int32, maximizing : Bool, nodes : Int32*) : Int32
    nodes.value += 1
    
    if depth == 0
      return evaluate(game_state)
    end
    
    moves = @move_generator.get_legal_moves(game_state, game_state.turn)
    
    if moves.empty?
      if @move_generator.in_check?(game_state, game_state.turn)
        return maximizing ? -100000 : 100000
      else
        return 0
      end
    end
    
    ordered_moves = order_moves(moves, game_state)
    
    if maximizing
      max_eval = Int32::MIN + 1
      current_alpha = alpha
      
      ordered_moves.each do |move|
        new_state = Board.make_move(game_state, move)
        evaluation = minimax(new_state, depth - 1, current_alpha, beta, false, nodes)
        max_eval = [max_eval, evaluation].max
        current_alpha = [current_alpha, evaluation].max
        break if beta <= current_alpha
      end
      max_eval
    else
      min_eval = Int32::MAX - 1
      current_beta = beta
      
      ordered_moves.each do |move|
        new_state = Board.make_move(game_state, move)
        evaluation = minimax(new_state, depth - 1, alpha, current_beta, true, nodes)
        min_eval = [min_eval, evaluation].min
        current_beta = [current_beta, evaluation].min
        break if current_beta <= alpha
      end
      min_eval
    end
  end

  private def evaluate(game_state : GameState) : Int32
    score = 0
    
    game_state.board.each_with_index do |piece, square|
      next unless piece
      
      piece_value = piece.type.material_value
      
      row = square // 8
      col = square % 8
      eval_row = piece.color.white? ? row : 7 - row
      table_idx = eval_row * 8 + col
      
      position_bonus = case piece.type
                       when PieceType::Pawn   then PAWN_TABLE[table_idx]
                       when PieceType::Knight then KNIGHT_TABLE[table_idx]
                       when PieceType::Bishop then BISHOP_TABLE[table_idx]
                       when PieceType::Rook   then ROOK_TABLE[table_idx]
                       when PieceType::Queen  then QUEEN_TABLE[table_idx]
                       when PieceType::King   then KING_TABLE[table_idx]
                       else 0
                       end
      
      total_value = piece_value + position_bonus
      
      if piece.color.white?
        score += total_value
      else
        score -= total_value
      end
    end
    
    score
  end

  private def order_moves(moves : Array(Move), game_state : GameState) : Array(Move)
    scored_moves = moves.map do |move|
      {move, score_move(move, game_state), move.to_s}
    end
    
    # Sort by score descending, then notation ascending
    scored_moves.sort! do |a, b|
      if a[1] != b[1]
        b[1] <=> a[1]
      else
        a[2] <=> b[2]
      end
    end
    
    scored_moves.map { |m| m[0] }
  end

  private def score_move(move : Move, game_state : GameState) : Int32
    score = 0
    
    # 1. Captures (MVV-LVA)
    if move.captured
      victim_value = move.captured.not_nil!.material_value
      attacker_value = move.piece.material_value
      score += (victim_value * 10) - attacker_value
    end
    
    # 2. Promotions
    if move.promotion
      score += move.promotion.not_nil!.material_value * 10
    end
    
    # 3. Center control
    to_row = move.to // 8
    to_col = move.to % 8
    if (to_row == 3 || to_row == 4) && (to_col == 3 || to_col == 4)
      score += 10
    end
    
    # 4. Castling
    if move.is_castling
      score += 50
    end
    
    score
  end
end
