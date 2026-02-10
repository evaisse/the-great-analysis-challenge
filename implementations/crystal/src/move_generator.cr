# Move generation and validation

require "./types"

class MoveGenerator
  def generate_moves(game_state : GameState, color : Color) : Array(Move)
    moves = Array(Move).new
    
    64.times do |square|
      piece = game_state.board[square]
      if piece && piece.color == color
        moves.concat(generate_piece_moves(game_state, square, piece))
      end
    end
    
    moves
  end

  private def generate_piece_moves(game_state : GameState, from : Square, piece : Piece) : Array(Move)
    case piece.type
    in .pawn?
      generate_pawn_moves(game_state, from, piece.color)
    in .knight?
      generate_knight_moves(game_state, from, piece.color)
    in .bishop?
      generate_bishop_moves(game_state, from, piece.color)
    in .rook?
      generate_rook_moves(game_state, from, piece.color)
    in .queen?
      generate_queen_moves(game_state, from, piece.color)
    in .king?
      generate_king_moves(game_state, from, piece.color)
    end
  end

  private def generate_pawn_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    moves = Array(Move).new
    direction = color.white? ? 8 : -8
    start_rank = color.white? ? 1 : 6
    promotion_rank = color.white? ? 7 : 0
    
    rank = from // 8
    file = from % 8
    
    # One square forward
    one_forward = from + direction
    if valid_square?(one_forward) && !game_state.board[one_forward]
      if one_forward // 8 == promotion_rank
        # Promotion moves
        [PieceType::Queen, PieceType::Rook, PieceType::Bishop, PieceType::Knight].each do |promotion|
          moves << Move.new(from, one_forward, PieceType::Pawn, nil, promotion)
        end
      else
        moves << Move.new(from, one_forward, PieceType::Pawn)
      end
      
      # Two squares forward from starting position
      if rank == start_rank
        two_forward = from + 2 * direction
        if valid_square?(two_forward) && !game_state.board[two_forward]
          moves << Move.new(from, two_forward, PieceType::Pawn)
        end
      end
    end
    
    # Captures
    [direction - 1, direction + 1].each do |offset|
      to = from + offset
      to_file = to % 8
      
      if valid_square?(to) && (to_file - file).abs == 1
        target = game_state.board[to]
        if target && target.color != color
          if to // 8 == promotion_rank
            # Promotion captures
            [PieceType::Queen, PieceType::Rook, PieceType::Bishop, PieceType::Knight].each do |promotion|
              moves << Move.new(from, to, PieceType::Pawn, target.type, promotion)
            end
          else
            moves << Move.new(from, to, PieceType::Pawn, target.type)
          end
        end
      end
    end
    
    # En passant
    if target = game_state.en_passant_target
      expected_rank = color.white? ? 4 : 3
      if rank == expected_rank
        [direction - 1, direction + 1].each do |offset|
          to = from + offset
          if to == target
            moves << Move.new(from, to, PieceType::Pawn, PieceType::Pawn, nil, false, true)
          end
        end
      end
    end
    
    moves
  end

  private def generate_knight_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    moves = Array(Move).new
    offsets = [-17, -15, -10, -6, 6, 10, 15, 17]
    file = from % 8
    
    offsets.each do |offset|
      to = from + offset
      to_file = to % 8
      
      if valid_square?(to) && (to_file - file).abs <= 2
        target = game_state.board[to]
        if !target
          moves << Move.new(from, to, PieceType::Knight)
        elsif target.color != color
          moves << Move.new(from, to, PieceType::Knight, target.type)
        end
      end
    end
    
    moves
  end

  private def generate_sliding_moves(game_state : GameState, from : Square, color : Color, directions : Array(Int32), piece_type : PieceType) : Array(Move)
    moves = Array(Move).new
    
    directions.each do |direction|
      to = from + direction
      prev_file = from % 8
      
      while valid_square?(to)
        to_file = to % 8
        
        # Check for wrapping
        if direction % 8 != 0
          break if (to_file - prev_file).abs != 1
        end
        
        target = game_state.board[to]
        if !target
          moves << Move.new(from, to, piece_type)
        else
          if target.color != color
            moves << Move.new(from, to, piece_type, target.type)
          end
          break
        end
        
        prev_file = to_file
        to += direction
      end
    end
    
    moves
  end

  private def generate_bishop_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    generate_sliding_moves(game_state, from, color, [-9, -7, 7, 9], PieceType::Bishop)
  end

  private def generate_rook_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    generate_sliding_moves(game_state, from, color, [-8, -1, 1, 8], PieceType::Rook)
  end

  private def generate_queen_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    generate_sliding_moves(game_state, from, color, [-9, -8, -7, -1, 1, 7, 8, 9], PieceType::Queen)
  end

  private def generate_king_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    moves = Array(Move).new
    offsets = [-9, -8, -7, -1, 1, 7, 8, 9]
    file = from % 8
    
    offsets.each do |offset|
      to = from + offset
      to_file = to % 8
      
      if valid_square?(to) && (to_file - file).abs <= 1
        target = game_state.board[to]
        if !target
          moves << Move.new(from, to, PieceType::King)
        elsif target.color != color
          moves << Move.new(from, to, PieceType::King, target.type)
        end
      end
    end
    
    # Castling
    moves.concat(generate_castling_moves(game_state, from, color))
    
    moves
  end

  private def generate_castling_moves(game_state : GameState, from : Square, color : Color) : Array(Move)
    moves = Array(Move).new
    
    case {color, from}
    when {Color::White, 4}
      # White kingside
      if game_state.castling_rights.white_kingside &&
         !game_state.board[5] &&
         !game_state.board[6] &&
         rook_at?(game_state, 7, Color::White) &&
         !square_attacked?(game_state, 4, Color::Black) &&
         !square_attacked?(game_state, 5, Color::Black) &&
         !square_attacked?(game_state, 6, Color::Black)
        moves << Move.new(4, 6, PieceType::King, nil, nil, true)
      end
      
      # White queenside
      if game_state.castling_rights.white_queenside &&
         !game_state.board[3] &&
         !game_state.board[2] &&
         !game_state.board[1] &&
         rook_at?(game_state, 0, Color::White) &&
         !square_attacked?(game_state, 4, Color::Black) &&
         !square_attacked?(game_state, 3, Color::Black) &&
         !square_attacked?(game_state, 2, Color::Black)
        moves << Move.new(4, 2, PieceType::King, nil, nil, true)
      end
    when {Color::Black, 60}
      # Black kingside
      if game_state.castling_rights.black_kingside &&
         !game_state.board[61] &&
         !game_state.board[62] &&
         rook_at?(game_state, 63, Color::Black) &&
         !square_attacked?(game_state, 60, Color::White) &&
         !square_attacked?(game_state, 61, Color::White) &&
         !square_attacked?(game_state, 62, Color::White)
        moves << Move.new(60, 62, PieceType::King, nil, nil, true)
      end
      
      # Black queenside
      if game_state.castling_rights.black_queenside &&
         !game_state.board[59] &&
         !game_state.board[58] &&
         !game_state.board[57] &&
         rook_at?(game_state, 56, Color::Black) &&
         !square_attacked?(game_state, 60, Color::White) &&
         !square_attacked?(game_state, 59, Color::White) &&
         !square_attacked?(game_state, 58, Color::White)
        moves << Move.new(60, 58, PieceType::King, nil, nil, true)
      end
    end
    
    moves
  end

  private def rook_at?(game_state : GameState, square : Square, color : Color) : Bool
    piece = game_state.board[square]
    return false unless piece
    piece.type.rook? && piece.color == color
  end

  def square_attacked?(game_state : GameState, square : Square, by_color : Color) : Bool
    64.times do |from_square|
      piece = game_state.board[from_square]
      if piece && piece.color == by_color
        moves = generate_piece_moves(game_state, from_square, piece)
        return true if moves.any? { |move| move.to == square }
      end
    end
    false
  end

  def in_check?(game_state : GameState, color : Color) : Bool
    64.times do |square|
      piece = game_state.board[square]
      if piece && piece.type.king? && piece.color == color
        return square_attacked?(game_state, square, color.opposite)
      end
    end
    false
  end

  def get_legal_moves(game_state : GameState, color : Color) : Array(Move)
    pseudo_legal_moves = generate_moves(game_state, color)
    legal_moves = Array(Move).new
    
    pseudo_legal_moves.each do |move|
      new_state = Board.make_move(game_state, move)
      unless in_check?(new_state, color)
        legal_moves << move
      end
    end
    
    legal_moves
  end

  def checkmate?(game_state : GameState, color : Color) : Bool
    in_check?(game_state, color) && get_legal_moves(game_state, color).empty?
  end

  def stalemate?(game_state : GameState, color : Color) : Bool
    !in_check?(game_state, color) && get_legal_moves(game_state, color).empty?
  end
end