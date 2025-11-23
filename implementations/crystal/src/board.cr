# Board representation and game state management

require "./types"

class Board
  def self.initial_position : GameState
    board = Array(Piece?).new(64, nil)
    
    # White pieces (bottom ranks)
    pieces = [
      PieceType::Rook, PieceType::Knight, PieceType::Bishop, PieceType::Queen,
      PieceType::King, PieceType::Bishop, PieceType::Knight, PieceType::Rook
    ]
    
    # Place white pieces
    pieces.each_with_index do |piece_type, i|
      board[i] = Piece.new(piece_type, Color::White)
    end
    
    # White pawns
    8.times do |i|
      board[8 + i] = Piece.new(PieceType::Pawn, Color::White)
    end
    
    # Black pawns
    8.times do |i|
      board[48 + i] = Piece.new(PieceType::Pawn, Color::Black)
    end
    
    # Place black pieces
    pieces.each_with_index do |piece_type, i|
      board[56 + i] = Piece.new(piece_type, Color::Black)
    end
    
    GameState.new(board)
  end

  def self.display(game_state : GameState) : String
    result = String.build do |io|
      io << "  a b c d e f g h\n"
      
      7.downto(0) do |rank|
        io << "#{rank + 1} "
        
        8.times do |file|
          square = rank * 8 + file
          piece = game_state.board[square]
          
          char = piece ? piece.to_char : '.'
          io << "#{char} "
        end
        
        io << "#{rank + 1}\n"
      end
      
      io << "  a b c d e f g h\n\n"
      
      turn_name = game_state.turn.white? ? "White" : "Black"
      io << "#{turn_name} to move"
    end
    
    result
  end

  def self.make_move(game_state : GameState, move : Move) : GameState
    new_state = game_state.dup
    piece = new_state.board[move.from]
    return new_state unless piece
    
    # Move piece
    new_state.board[move.to] = piece
    new_state.board[move.from] = nil
    
    # Handle special moves
    if move.is_castling
      rank = piece.color.white? ? 0 : 7
      rook_from, rook_to = if move.to == rank * 8 + 6
                             {rank * 8 + 7, rank * 8 + 5}
                           else
                             {rank * 8, rank * 8 + 3}
                           end
      
      rook = new_state.board[rook_from]
      if rook
        new_state.board[rook_to] = rook
        new_state.board[rook_from] = nil
      end
    end
    
    if move.is_en_passant
      captured_pawn_square = piece.color.white? ? move.to - 8 : move.to + 8
      new_state.board[captured_pawn_square] = nil
    end
    
    if promotion = move.promotion
      new_state.board[move.to] = Piece.new(promotion, piece.color)
    end
    
    # Update en passant target
    new_state.en_passant_target = nil
    if piece.type.pawn? && (move.to - move.from).abs == 16
      new_state.en_passant_target = piece.color.white? ? move.from + 8 : move.from - 8
    end
    
    # Update castling rights
    new_rights = update_castling_rights(new_state.castling_rights, move, piece)
    new_state.castling_rights = new_rights
    
    # Update clocks
    if move.captured || piece.type.pawn?
      new_state.halfmove_clock = 0
    else
      new_state.halfmove_clock += 1
    end
    
    if piece.color.black?
      new_state.fullmove_number += 1
    end
    
    # Switch turn and add move to history
    new_state.turn = piece.color.opposite
    new_state.move_history << move
    
    new_state
  end

  private def self.update_castling_rights(rights : CastlingRights, move : Move, piece : Piece) : CastlingRights
    new_white_kingside = rights.white_kingside
    new_white_queenside = rights.white_queenside
    new_black_kingside = rights.black_kingside
    new_black_queenside = rights.black_queenside
    
    # King moves
    if piece.type.king?
      if piece.color.white?
        new_white_kingside = false
        new_white_queenside = false
      else
        new_black_kingside = false
        new_black_queenside = false
      end
    end
    
    # Rook moves or captures
    case move.from
    when 0
      new_white_queenside = false
    when 7
      new_white_kingside = false
    when 56
      new_black_queenside = false
    when 63
      new_black_kingside = false
    end
    
    case move.to
    when 0
      new_white_queenside = false
    when 7
      new_white_kingside = false
    when 56
      new_black_queenside = false
    when 63
      new_black_kingside = false
    end
    
    CastlingRights.new(new_white_kingside, new_white_queenside, new_black_kingside, new_black_queenside)
  end

  def self.is_game_over(game_state : GameState) : {Bool, String?}
    # Draw by fifty-move rule
    if game_state.halfmove_clock >= 100
      return {true, "Draw by fifty-move rule"}
    end
    
    # Draw by insufficient material (basic check)
    if insufficient_material?(game_state)
      return {true, "Draw by insufficient material"}
    end
    
    {false, nil}
  end

  private def self.insufficient_material?(game_state : GameState) : Bool
    pieces = game_state.board.compact
    return true if pieces.size <= 2  # Only kings
    
    # King vs King + Bishop/Knight
    return true if pieces.size == 3 && pieces.any? { |p| p.type.bishop? || p.type.knight? }
    
    false
  end
end