# Chess AI with minimax and alpha-beta pruning

require "./types"
require "./board"
require "./move_generator"

class ChessAI
  @move_generator : MoveGenerator

  def initialize
    @move_generator = MoveGenerator.new
  end

  def search(game_state : GameState, depth : Int32, maximize : Bool = true) : SearchResult
    start_time = Time.monotonic
    nodes = 0
    
    best_move, evaluation = minimax(
      game_state, depth, Int32::MIN + 1, Int32::MAX - 1, 
      maximize, pointerof(nodes)
    )
    
    time_ms = (Time.monotonic - start_time).total_milliseconds.to_i64
    
    SearchResult.new(best_move, evaluation, nodes, time_ms)
  end

  private def minimax(game_state : GameState, depth : Int32, alpha : Int32, beta : Int32, 
                     maximize : Bool, nodes : Int32*) : {Move?, Int32}
    nodes.value += 1
    
    if depth == 0
      return {nil, evaluate(game_state)}
    end
    
    color = maximize ? game_state.turn : game_state.turn.opposite
    moves = @move_generator.get_legal_moves(game_state, color)
    
    if moves.empty?
      if @move_generator.in_check?(game_state, color)
        # Checkmate
        return {nil, maximize ? Int32::MIN + 1000 : Int32::MAX - 1000}
      else
        # Stalemate
        return {nil, 0}
      end
    end
    
    best_move : Move? = nil
    
    if maximize
      max_eval = Int32::MIN + 1
      
      moves.each do |move|
        new_state = Board.make_move(game_state, move)
        _, evaluation = minimax(new_state, depth - 1, alpha, beta, false, nodes)
        
        if evaluation > max_eval
          max_eval = evaluation
          best_move = move
        end
        
        alpha = [alpha, evaluation].max
        break if beta <= alpha  # Alpha-beta pruning
      end
      
      {best_move, max_eval}
    else
      min_eval = Int32::MAX - 1
      
      moves.each do |move|
        new_state = Board.make_move(game_state, move)
        _, evaluation = minimax(new_state, depth - 1, alpha, beta, true, nodes)
        
        if evaluation < min_eval
          min_eval = evaluation
          best_move = move
        end
        
        beta = [beta, evaluation].min
        break if beta <= alpha  # Alpha-beta pruning
      end
      
      {best_move, min_eval}
    end
  end

  private def evaluate(game_state : GameState) : Int32
    score = 0
    
    # Material evaluation
    game_state.board.each do |piece|
      next unless piece
      
      piece_value = piece.type.value
      if piece.color.white?
        score += piece_value
      else
        score -= piece_value
      end
    end
    
    # Position evaluation
    score += evaluate_position(game_state)
    
    score
  end

  private def evaluate_position(game_state : GameState) : Int32
    score = 0
    
    # Center control bonus
    center_squares = [27, 28, 35, 36]  # d4, e4, d5, e5
    
    center_squares.each do |square|
      if piece = game_state.board[square]
        bonus = piece.type.pawn? ? 20 : 10
        if piece.color.white?
          score += bonus
        else
          score -= bonus
        end
      end
    end
    
    # King safety (basic)
    score += evaluate_king_safety(game_state, Color::White)
    score -= evaluate_king_safety(game_state, Color::Black)
    
    # Mobility (number of legal moves)
    white_moves = @move_generator.get_legal_moves(game_state, Color::White).size
    black_moves = @move_generator.get_legal_moves(game_state, Color::Black).size
    score += (white_moves - black_moves) * 2
    
    score
  end

  private def evaluate_king_safety(game_state : GameState, color : Color) : Int32
    safety = 0
    king_square = nil
    
    # Find king
    64.times do |square|
      piece = game_state.board[square]
      if piece && piece.type.king? && piece.color == color
        king_square = square
        break
      end
    end
    
    return 0 unless king_square
    
    # Penalty for king in center during opening/middlegame
    file = king_square % 8
    rank = king_square // 8
    expected_rank = color.white? ? 0 : 7
    
    if rank != expected_rank
      safety -= 30  # King not on back rank
    end
    
    if file >= 2 && file <= 5
      safety -= 20  # King in center files
    end
    
    # Bonus for castling rights
    rights = game_state.castling_rights
    if color.white?
      if rights.white_kingside || rights.white_queenside
        safety += 15
      end
    else
      if rights.black_kingside || rights.black_queenside
        safety += 15
      end
    end
    
    safety
  end

  def get_best_move(game_state : GameState, depth : Int32 = 4) : Move?
    maximize = game_state.turn.white?
    result = search(game_state, depth, maximize)
    result.best_move
  end

  # Quiescence search for better tactical evaluation
  private def quiesce(game_state : GameState, alpha : Int32, beta : Int32, depth : Int32, nodes : Int32*) : Int32
    nodes.value += 1
    
    return evaluate(game_state) if depth <= 0
    
    stand_pat = evaluate(game_state)
    return stand_pat if stand_pat >= beta
    
    new_alpha = [alpha, stand_pat].max
    
    # Only consider captures and checks
    moves = @move_generator.get_legal_moves(game_state, game_state.turn)
    capture_moves = moves.select { |move| move.captured }
    
    capture_moves.each do |move|
      new_state = Board.make_move(game_state, move)
      score = -quiesce(new_state, -beta, -new_alpha, depth - 1, nodes)
      
      return score if score >= beta
      new_alpha = [new_alpha, score].max
    end
    
    new_alpha
  end
end