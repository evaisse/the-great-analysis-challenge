defmodule ChessEngine.Move do
  defstruct from: 0,
            to: 0,
            promotion: nil,
            is_castling: false,
            is_en_passant: false,
            captured: ?.
end

defmodule ChessEngine do
  alias ChessEngine.{Chess960, Move, PGN}

  @empty ?.
  @mate_score 100_000
  @inf_score 1_000_000_000
  @start_fen "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  @knight_deltas [
    {-2, -1},
    {-2, 1},
    {-1, -2},
    {-1, 2},
    {1, -2},
    {1, 2},
    {2, -1},
    {2, 1}
  ]

  @king_deltas [
    {-1, -1},
    {-1, 0},
    {-1, 1},
    {0, -1},
    {0, 1},
    {1, -1},
    {1, 0},
    {1, 1}
  ]

  @pawn_table {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {50, 50, 50, 50, 50, 50, 50, 50},
    {10, 10, 20, 30, 30, 20, 10, 10},
    {5, 5, 10, 25, 25, 10, 5, 5},
    {0, 0, 0, 20, 20, 0, 0, 0},
    {5, -5, -10, 0, 0, -10, -5, 5},
    {5, 10, 10, -20, -20, 10, 10, 5},
    {0, 0, 0, 0, 0, 0, 0, 0}
  }

  @knight_table {
    {-50, -40, -30, -30, -30, -30, -40, -50},
    {-40, -20, 0, 0, 0, 0, -20, -40},
    {-30, 0, 10, 15, 15, 10, 0, -30},
    {-30, 5, 15, 20, 20, 15, 5, -30},
    {-30, 0, 15, 20, 20, 15, 0, -30},
    {-30, 5, 10, 15, 15, 10, 5, -30},
    {-40, -20, 0, 5, 5, 0, -20, -40},
    {-50, -40, -30, -30, -30, -30, -40, -50}
  }

  @bishop_table {
    {-20, -10, -10, -10, -10, -10, -10, -20},
    {-10, 0, 0, 0, 0, 0, 0, -10},
    {-10, 0, 5, 10, 10, 5, 0, -10},
    {-10, 5, 5, 10, 10, 5, 5, -10},
    {-10, 0, 10, 10, 10, 10, 0, -10},
    {-10, 10, 10, 10, 10, 10, 10, -10},
    {-10, 5, 0, 0, 0, 0, 5, -10},
    {-20, -10, -10, -10, -10, -10, -10, -20}
  }

  @rook_table {
    {0, 0, 0, 0, 0, 0, 0, 0},
    {5, 10, 10, 10, 10, 10, 10, 5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {-5, 0, 0, 0, 0, 0, 0, -5},
    {0, 0, 0, 5, 5, 0, 0, 0}
  }

  @queen_table {
    {-20, -10, -10, -5, -5, -10, -10, -20},
    {-10, 0, 0, 0, 0, 0, 0, -10},
    {-10, 0, 5, 5, 5, 5, 0, -10},
    {-5, 0, 5, 5, 5, 5, 0, -5},
    {0, 0, 5, 5, 5, 5, 0, -5},
    {-10, 5, 5, 5, 5, 5, 0, -10},
    {-10, 0, 5, 0, 0, 0, 0, -10},
    {-20, -10, -10, -5, -5, -10, -10, -20}
  }

  @king_table {
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-30, -40, -40, -50, -50, -40, -40, -30},
    {-20, -30, -30, -40, -40, -30, -30, -20},
    {-10, -20, -20, -20, -20, -20, -20, -10},
    {20, 20, 0, 0, 0, 0, 20, 20},
    {20, 30, 10, 0, 0, 10, 30, 20}
  }

  @starting_squares List.to_tuple(
                      [
                        ?R,
                        ?N,
                        ?B,
                        ?Q,
                        ?K,
                        ?B,
                        ?N,
                        ?R
                      ] ++
                        List.duplicate(?P, 8) ++
                        List.duplicate(@empty, 32) ++
                        List.duplicate(?p, 8) ++
                        [?r, ?n, ?b, ?q, ?k, ?b, ?n, ?r]
                    )

  def new_engine do
    board = new_board()
    pgn_game = PGN.new_game(@start_fen, "current-game")

    %{
      board: board,
      history: [],
      move_history: [],
      position_history: [board_hash_hex(board)],
      initial_fen: @start_fen,
      pgn_game: pgn_game,
      chess960_id: 0,
      chess960_mode: false
    }
  end

  def new_board do
    %{
      squares: @starting_squares,
      white_to_move: true,
      white_kingside: true,
      white_queenside: true,
      black_kingside: true,
      black_queenside: true,
      en_passant: nil,
      halfmove_clock: 0,
      fullmove_number: 1
    }
  end

  def reset_engine(_engine), do: new_engine()

  def load_position(_engine, fen_string) do
    case board_load_fen(fen_string) do
      {:ok, board} ->
        pgn_game = PGN.new_game(fen_string, "current-game")

        {:ok,
         %{
           board: board,
           history: [],
           move_history: [],
           position_history: [board_hash_hex(board)],
           initial_fen: fen_string,
           pgn_game: pgn_game,
           chess960_id: 0,
           chess960_mode: false
         }}

      :error ->
        :error
    end
  end

  def undo(%{history: []} = _engine), do: :error

  def undo(
        %{
          history: [previous_board | rest],
          move_history: [_last_move | move_rest],
          position_history: [_current | positions]
        } =
          engine
      ) do
    next_engine = %{
      engine
      | board: previous_board,
        history: rest,
        move_history: move_rest,
        position_history: positions
    }

    {:ok, rebuild_pgn(next_engine)}
  end

  def resolve_user_move(engine, move_text) do
    with {:ok, from} <- parse_square_text(String.slice(move_text, 0, 2)),
         {:ok, to} <- parse_square_text(String.slice(move_text, 2, 2)),
         {:ok, promotion} <- parse_promotion(move_text) do
      legal_moves = generate_legal_moves(engine.board)

      exact =
        Enum.find(legal_moves, fn move ->
          move.from == from and move.to == to and move.promotion == promotion
        end)

      cond do
        exact != nil ->
          {:ok, exact}

        promotion == nil ->
          case Enum.find(legal_moves, fn move ->
                 move.from == from and move.to == to and move.promotion == nil
               end) do
            nil ->
              case Enum.find(legal_moves, fn move ->
                     move.from == from and move.to == to and move.promotion == ?Q
                   end) do
                nil -> {:error, :illegal_move}
                fallback -> {:ok, fallback}
              end

            move ->
              {:ok, move}
          end

        true ->
          {:error, :illegal_move}
      end
    else
      _ -> {:error, :invalid_move_format}
    end
  end

  def apply_engine_move(engine, %Move{} = move) do
    next_board = apply_move(engine.board, move)

    {:ok,
     rebuild_pgn(%{
       engine
       | board: next_board,
         history: [engine.board | engine.history],
         move_history: [move | engine.move_history],
         position_history: [board_hash_hex(next_board) | engine.position_history]
     })}
  end

  def load_pgn_game(engine, game) do
    engine
    |> Map.put(:pgn_game, game)
    |> Map.put(:initial_fen, game.initial_fen)
    |> Map.put(:chess960_mode, false)
    |> Map.put(:pgn_game, game)
    |> sync_runtime_to_pgn()
  end

  def sync_runtime_to_pgn(engine) do
    with {:ok, base_board} <- board_load_fen(engine.pgn_game.initial_fen) do
      {board, history, move_history, position_history} =
        Enum.reduce(
          PGN.mainline_moves(engine.pgn_game),
          {base_board, [], [], [board_hash_hex(base_board)]},
          fn node, {board, history, move_history, position_history} ->
            next_board = apply_move(board, node.move)

            {
              next_board,
              [board | history],
              [node.move | move_history],
              [board_hash_hex(next_board) | position_history]
            }
          end
        )

      %{
        engine
        | board: board,
          history: history,
          move_history: move_history,
          position_history: position_history,
          initial_fen: engine.pgn_game.initial_fen
      }
      |> rebuild_pgn_result()
    else
      :error -> engine
    end
  end

  def load_chess960(engine, chess960_id) do
    fen = Chess960.build_fen(chess960_id)

    case board_load_fen(fen) do
      {:ok, board} ->
        pgn_game = PGN.new_game(fen, "current-game")

        {:ok,
         %{
           engine
           | board: board,
             history: [],
             move_history: [],
             position_history: [board_hash_hex(board)],
             initial_fen: fen,
             pgn_game: pgn_game,
             chess960_id: chess960_id,
             chess960_mode: true
         }}

      :error ->
        :error
    end
  end

  def status(engine) do
    board = engine.board

    cond do
      board.halfmove_clock >= 100 ->
        :draw_fifty

      repetition_count(engine) >= 3 ->
        :draw_repetition

      true ->
        legal_moves = generate_legal_moves(board)
        moving_white = board.white_to_move
        in_check = is_in_check(board, moving_white)

        cond do
          legal_moves == [] and in_check and moving_white -> :checkmate_black
          legal_moves == [] and in_check and not moving_white -> :checkmate_white
          legal_moves == [] -> :stalemate
          in_check -> :check
          true -> :ongoing
        end
    end
  end

  def repetition_count(%{position_history: []}), do: 0

  def repetition_count(%{position_history: [current | _] = history}) do
    Enum.count(history, &(&1 == current))
  end

  def draw_reason(engine) do
    cond do
      engine.board.halfmove_clock >= 100 -> "fifty_moves"
      repetition_count(engine) >= 3 -> "repetition"
      true -> "none"
    end
  end

  def board_hash_hex(board) do
    position_key = board_export_position_key(board)
    <<value::binary-size(8), _::binary>> = :crypto.hash(:sha256, position_key)
    Base.encode16(value, case: :lower)
  end

  def board_export_position_key(board) do
    board_export_fen(board)
    |> String.split(" ")
    |> Enum.take(4)
    |> Enum.join(" ")
  end

  def board_export_fen(board) do
    piece_placement = Enum.map_join(7..0//-1, "/", &export_rank(board, &1))
    side_to_move = if board.white_to_move, do: "w", else: "b"

    castling =
      []
      |> maybe_add_castling(board.white_kingside, "K")
      |> maybe_add_castling(board.white_queenside, "Q")
      |> maybe_add_castling(board.black_kingside, "k")
      |> maybe_add_castling(board.black_queenside, "q")
      |> case do
        [] -> "-"
        items -> Enum.join(items, "")
      end

    en_passant =
      case board.en_passant do
        nil -> "-"
        square -> square_to_text(square)
      end

    "#{piece_placement} #{side_to_move} #{castling} #{en_passant} #{board.halfmove_clock} #{board.fullmove_number}"
  end

  def select_best_move(board, depth) do
    bounded_depth = depth |> max(1) |> min(5)
    legal_moves = generate_legal_moves(board)

    if legal_moves == [] do
      :error
    else
      ordered_moves = order_moves(board, legal_moves)
      maximizing = board.white_to_move
      initial_score = if maximizing, do: -@inf_score, else: @inf_score

      {best_move, best_score, _alpha, _beta, _found} =
        Enum.reduce(ordered_moves, {nil, initial_score, -@inf_score, @inf_score, false}, fn move,
                                                                                            {best_move,
                                                                                             best_score,
                                                                                             alpha,
                                                                                             beta,
                                                                                             found} ->
          score = minimax(apply_move(board, move), bounded_depth - 1, alpha, beta, not maximizing)

          {next_best_move, next_best_score, next_found} =
            cond do
              not found -> {move, score, true}
              maximizing and score > best_score -> {move, score, true}
              not maximizing and score < best_score -> {move, score, true}
              true -> {best_move, best_score, found}
            end

          next_alpha = if maximizing and score > alpha, do: score, else: alpha
          next_beta = if(not maximizing and score < beta, do: score, else: beta)

          {next_best_move, next_best_score, next_alpha, next_beta, next_found}
        end)

      {:ok, best_move, best_score}
    end
  end

  def perft(_board, 0), do: 1

  def perft(board, depth) do
    generate_legal_moves(board)
    |> Enum.reduce(0, fn move, acc -> acc + perft(apply_move(board, move), depth - 1) end)
  end

  def evaluate_board(board) do
    Enum.reduce(0..63, 0, fn square, acc ->
      piece = piece_at(board, square)

      if piece == @empty do
        acc
      else
        row = square_row(square)
        col = square_col(square)
        total = piece_value(piece) + piece_square_bonus(piece, row, col)

        if is_white_piece(piece) do
          acc + total
        else
          acc - total
        end
      end
    end)
  end

  def format_status(:checkmate_white), do: "CHECKMATE: White wins"
  def format_status(:checkmate_black), do: "CHECKMATE: Black wins"
  def format_status(:stalemate), do: "STALEMATE: Draw"
  def format_status(:draw_repetition), do: "DRAW: REPETITION"
  def format_status(:draw_fifty), do: "DRAW: 50-MOVE"
  def format_status(:check), do: "OK: CHECK"
  def format_status(:ongoing), do: "OK: ONGOING"

  def move_to_string(%Move{} = move) do
    promotion =
      case move.promotion do
        nil -> ""
        piece -> <<lower_piece(piece)>>
      end

    square_to_text(move.from) <> square_to_text(move.to) <> promotion
  end

  defp rebuild_pgn(engine) do
    engine
    |> Map.put(
      :pgn_game,
      engine.move_history
      |> Enum.reverse()
      |> PGN.build_game_from_history(
        start_fen: engine.initial_fen,
        source: engine.pgn_game.source || "current-game"
      )
    )
    |> rebuild_pgn_result()
  end

  defp rebuild_pgn_result(engine) do
    result = result_for_status(status(engine))
    %{engine | pgn_game: PGN.set_result(engine.pgn_game, result)}
  end

  defp result_for_status(:checkmate_white), do: "1-0"
  defp result_for_status(:checkmate_black), do: "0-1"
  defp result_for_status(:stalemate), do: "1/2-1/2"
  defp result_for_status(:draw_repetition), do: "1/2-1/2"
  defp result_for_status(:draw_fifty), do: "1/2-1/2"
  defp result_for_status(_status), do: "*"

  def generate_legal_moves(board) do
    moving_white = board.white_to_move

    board
    |> generate_pseudo_legal_moves()
    |> Enum.filter(fn move ->
      next_board = apply_move(board, move)
      not is_in_check(next_board, moving_white)
    end)
  end

  def generate_pseudo_legal_moves(board) do
    Enum.reduce(0..63, [], fn square, acc ->
      piece = piece_at(board, square)

      cond do
        piece == @empty ->
          acc

        board.white_to_move != is_white_piece(piece) ->
          acc

        true ->
          generate_piece_moves(board, square, piece, acc)
      end
    end)
    |> Enum.reverse()
  end

  def apply_move(board, %Move{} = move) do
    piece = piece_at(board, move.from)
    captured = move.captured || @empty
    white_move = is_white_piece(piece)
    pawn_move = upper_piece(piece) == ?P

    board =
      case upper_piece(piece) do
        ?K when white_move -> %{board | white_kingside: false, white_queenside: false}
        ?K -> %{board | black_kingside: false, black_queenside: false}
        _ -> board
      end

    board =
      case {piece, move.from} do
        {?R, 0} -> %{board | white_queenside: false}
        {?R, 7} -> %{board | white_kingside: false}
        {?r, 56} -> %{board | black_queenside: false}
        {?r, 63} -> %{board | black_kingside: false}
        _ -> board
      end

    board =
      case {captured, move.to} do
        {?R, 0} -> %{board | white_queenside: false}
        {?R, 7} -> %{board | white_kingside: false}
        {?r, 56} -> %{board | black_queenside: false}
        {?r, 63} -> %{board | black_kingside: false}
        _ -> board
      end

    board = %{board | en_passant: nil}

    squares =
      if move.is_en_passant do
        captured_square = if white_move, do: move.to - 8, else: move.to + 8
        board.squares |> put_elem(captured_square, @empty)
      else
        board.squares
      end

    squares = put_elem(squares, move.from, @empty)

    squares =
      if move.is_castling do
        case {piece, move.to} do
          {?K, 6} -> squares |> put_elem(7, @empty) |> put_elem(5, ?R)
          {?K, 2} -> squares |> put_elem(0, @empty) |> put_elem(3, ?R)
          {?k, 62} -> squares |> put_elem(63, @empty) |> put_elem(61, ?r)
          {?k, 58} -> squares |> put_elem(56, @empty) |> put_elem(59, ?r)
          _ -> squares
        end
      else
        squares
      end

    en_passant =
      if pawn_move and abs(move.to - move.from) == 16 do
        if white_move, do: move.from + 8, else: move.from - 8
      else
        nil
      end

    placed_piece =
      case move.promotion do
        nil -> piece
        promotion -> if(white_move, do: promotion, else: lower_piece(promotion))
      end

    squares = put_elem(squares, move.to, placed_piece)
    halfmove_clock = if pawn_move or captured != @empty, do: 0, else: board.halfmove_clock + 1

    fullmove_number =
      if(board.white_to_move, do: board.fullmove_number, else: board.fullmove_number + 1)

    %{
      board
      | squares: squares,
        en_passant: en_passant,
        halfmove_clock: halfmove_clock,
        fullmove_number: fullmove_number,
        white_to_move: not board.white_to_move
    }
  end

  def is_in_check(board, white_king) do
    case find_king(board, white_king) do
      nil -> false
      square -> is_square_attacked(board, square, not white_king)
    end
  end

  def is_square_attacked(board, square, by_white) do
    row = square_row(square)
    col = square_col(square)
    pawn_row = row + if(by_white, do: -1, else: 1)
    pawn_piece = if(by_white, do: ?P, else: ?p)

    attacked_by_pawn =
      Enum.any?([col - 1, col + 1], fn pawn_col ->
        in_bounds(pawn_row, pawn_col) and
          piece_at(board, make_square(pawn_row, pawn_col)) == pawn_piece
      end)

    attacked_by_knight =
      Enum.any?(@knight_deltas, fn {dr, dc} ->
        target_row = row + dr
        target_col = col + dc

        in_bounds(target_row, target_col) and
          piece_at(board, make_square(target_row, target_col)) == if(by_white, do: ?N, else: ?n)
      end)

    attacked_by_bishop_or_queen =
      ray_attack?(board, row, col, [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}], [
        if(by_white, do: ?B, else: ?b),
        if(by_white, do: ?Q, else: ?q)
      ])

    attacked_by_rook_or_queen =
      ray_attack?(board, row, col, [{1, 0}, {-1, 0}, {0, 1}, {0, -1}], [
        if(by_white, do: ?R, else: ?r),
        if(by_white, do: ?Q, else: ?q)
      ])

    attacked_by_king =
      Enum.any?(@king_deltas, fn {dr, dc} ->
        target_row = row + dr
        target_col = col + dc

        in_bounds(target_row, target_col) and
          piece_at(board, make_square(target_row, target_col)) == if(by_white, do: ?K, else: ?k)
      end)

    attacked_by_pawn or attacked_by_knight or attacked_by_bishop_or_queen or
      attacked_by_rook_or_queen or
      attacked_by_king
  end

  def board_load_fen(fen_string) do
    case String.split(String.trim(fen_string), ~r/\s+/, parts: 6) do
      [pieces, side, castling, en_passant, halfmove, fullmove] ->
        with {:ok, squares} <- parse_piece_placement(pieces),
             {:ok, white_to_move} <- parse_side_to_move(side),
             {:ok, rights} <- parse_castling(castling),
             {:ok, en_passant_square} <- parse_en_passant(en_passant),
             {halfmove_clock, ""} <- Integer.parse(halfmove),
             true <- halfmove_clock >= 0,
             {fullmove_number, ""} <- Integer.parse(fullmove),
             true <- fullmove_number >= 1 do
          {:ok,
           %{
             squares: squares,
             white_to_move: white_to_move,
             white_kingside: rights.white_kingside,
             white_queenside: rights.white_queenside,
             black_kingside: rights.black_kingside,
             black_queenside: rights.black_queenside,
             en_passant: en_passant_square,
             halfmove_clock: halfmove_clock,
             fullmove_number: fullmove_number
           }}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp minimax(board, depth, alpha, beta, maximizing_player) do
    cond do
      board.halfmove_clock >= 100 ->
        0

      depth == 0 ->
        evaluate_board(board)

      true ->
        legal_moves = generate_legal_moves(board)

        cond do
          legal_moves == [] and is_in_check(board, board.white_to_move) ->
            if maximizing_player, do: -@mate_score, else: @mate_score

          legal_moves == [] ->
            0

          maximizing_player ->
            do_max_loop(order_moves(board, legal_moves), board, depth, alpha, beta, -@inf_score)

          true ->
            do_min_loop(order_moves(board, legal_moves), board, depth, alpha, beta, @inf_score)
        end
    end
  end

  defp do_max_loop([], _board, _depth, _alpha, _beta, best), do: best

  defp do_max_loop([move | rest], board, depth, alpha, beta, best) do
    score = minimax(apply_move(board, move), depth - 1, alpha, beta, false)
    next_best = max(best, score)
    next_alpha = max(alpha, score)

    if beta <= next_alpha do
      next_best
    else
      do_max_loop(rest, board, depth, next_alpha, beta, next_best)
    end
  end

  defp do_min_loop([], _board, _depth, _alpha, _beta, best), do: best

  defp do_min_loop([move | rest], board, depth, alpha, beta, best) do
    score = minimax(apply_move(board, move), depth - 1, alpha, beta, true)
    next_best = min(best, score)
    next_beta = min(beta, score)

    if next_beta <= alpha do
      next_best
    else
      do_min_loop(rest, board, depth, alpha, next_beta, next_best)
    end
  end

  defp order_moves(board, moves) do
    Enum.sort_by(moves, fn move ->
      {-move_order_score(board, move), move_to_string(move)}
    end)
  end

  defp move_order_score(board, move) do
    piece = piece_at(board, move.from)

    capture_score =
      if move.captured != @empty do
        10 * piece_value(move.captured) - piece_value(piece)
      else
        0
      end

    promotion_score =
      case move.promotion do
        nil -> 0
        promotion -> piece_value(promotion) * 10
      end

    center_score = if is_center_square(move.to), do: 10, else: 0
    castle_score = if move.is_castling, do: 50, else: 0

    capture_score + promotion_score + center_score + castle_score
  end

  defp generate_piece_moves(board, square, piece, acc) do
    case upper_piece(piece) do
      ?P ->
        generate_pawn_moves(board, square, piece, acc)

      ?N ->
        generate_knight_moves(board, square, piece, acc)

      ?B ->
        generate_sliding_moves(board, square, piece, [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}], acc)

      ?R ->
        generate_sliding_moves(board, square, piece, [{1, 0}, {-1, 0}, {0, 1}, {0, -1}], acc)

      ?Q ->
        generate_sliding_moves(
          board,
          square,
          piece,
          [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}],
          acc
        )

      ?K ->
        generate_king_moves(board, square, piece, acc)

      _ ->
        acc
    end
  end

  defp generate_pawn_moves(board, square, piece, acc) do
    white = is_white_piece(piece)
    row = square_row(square)
    col = square_col(square)
    direction = if white, do: 1, else: -1
    start_row = if white, do: 1, else: 6
    promotion_row = if white, do: 7, else: 0
    next_row = row + direction

    acc =
      if in_bounds(next_row, col) and piece_at(board, make_square(next_row, col)) == @empty do
        target = make_square(next_row, col)
        acc = maybe_add_pawn_target(acc, square, target, promotion_row, next_row, @empty)

        if row == start_row do
          jump_row = row + direction * 2

          if in_bounds(jump_row, col) and piece_at(board, make_square(jump_row, col)) == @empty do
            [%Move{from: square, to: make_square(jump_row, col)} | acc]
          else
            acc
          end
        else
          acc
        end
      else
        acc
      end

    Enum.reduce([-1, 1], acc, fn delta_col, inner_acc ->
      target_row = row + direction
      target_col = col + delta_col

      cond do
        not in_bounds(target_row, target_col) ->
          inner_acc

        true ->
          target = make_square(target_row, target_col)
          captured = piece_at(board, target)

          cond do
            captured != @empty and not same_side(piece, captured) ->
              maybe_add_pawn_target(
                inner_acc,
                square,
                target,
                promotion_row,
                target_row,
                captured
              )

            board.en_passant == target ->
              ep_captured = if white, do: ?p, else: ?P

              [
                %Move{from: square, to: target, is_en_passant: true, captured: ep_captured}
                | inner_acc
              ]

            true ->
              inner_acc
          end
      end
    end)
  end

  defp maybe_add_pawn_target(acc, from, target, promotion_row, target_row, captured) do
    if target_row == promotion_row do
      [
        %Move{from: from, to: target, promotion: ?N, captured: captured},
        %Move{from: from, to: target, promotion: ?B, captured: captured},
        %Move{from: from, to: target, promotion: ?R, captured: captured},
        %Move{from: from, to: target, promotion: ?Q, captured: captured}
        | acc
      ]
    else
      [%Move{from: from, to: target, captured: captured} | acc]
    end
  end

  defp generate_knight_moves(board, square, piece, acc) do
    row = square_row(square)
    col = square_col(square)

    Enum.reduce(@knight_deltas, acc, fn {dr, dc}, inner_acc ->
      target_row = row + dr
      target_col = col + dc

      if in_bounds(target_row, target_col) do
        target = make_square(target_row, target_col)
        captured = piece_at(board, target)

        if captured == @empty or not same_side(piece, captured) do
          [%Move{from: square, to: target, captured: captured} | inner_acc]
        else
          inner_acc
        end
      else
        inner_acc
      end
    end)
  end

  defp generate_sliding_moves(board, square, piece, directions, acc) do
    row = square_row(square)
    col = square_col(square)

    Enum.reduce(directions, acc, fn {dr, dc}, inner_acc ->
      add_sliding_ray(board, square, piece, row + dr, col + dc, dr, dc, inner_acc)
    end)
  end

  defp add_sliding_ray(board, square, piece, row, col, dr, dc, acc) do
    cond do
      not in_bounds(row, col) ->
        acc

      true ->
        target = make_square(row, col)
        captured = piece_at(board, target)

        cond do
          captured == @empty ->
            add_sliding_ray(
              board,
              square,
              piece,
              row + dr,
              col + dc,
              dr,
              dc,
              [%Move{from: square, to: target, captured: @empty} | acc]
            )

          same_side(piece, captured) ->
            acc

          true ->
            [%Move{from: square, to: target, captured: captured} | acc]
        end
    end
  end

  defp generate_king_moves(board, square, piece, acc) do
    row = square_row(square)
    col = square_col(square)
    white = is_white_piece(piece)

    acc =
      Enum.reduce(@king_deltas, acc, fn {dr, dc}, inner_acc ->
        target_row = row + dr
        target_col = col + dc

        if in_bounds(target_row, target_col) do
          target = make_square(target_row, target_col)
          captured = piece_at(board, target)

          if captured == @empty or not same_side(piece, captured) do
            [%Move{from: square, to: target, captured: captured} | inner_acc]
          else
            inner_acc
          end
        else
          inner_acc
        end
      end)

    if white and square == 4 and not is_in_check(board, true) do
      acc
      |> maybe_add_castle(
        board.white_kingside and piece_at(board, 5) == @empty and piece_at(board, 6) == @empty and
          piece_at(board, 7) == ?R and not is_square_attacked(board, 5, false) and
          not is_square_attacked(board, 6, false),
        square,
        6
      )
      |> maybe_add_castle(
        board.white_queenside and piece_at(board, 3) == @empty and piece_at(board, 2) == @empty and
          piece_at(board, 1) == @empty and piece_at(board, 0) == ?R and
          not is_square_attacked(board, 3, false) and not is_square_attacked(board, 2, false),
        square,
        2
      )
    else
      if not white and square == 60 and not is_in_check(board, false) do
        acc
        |> maybe_add_castle(
          board.black_kingside and piece_at(board, 61) == @empty and piece_at(board, 62) == @empty and
            piece_at(board, 63) == ?r and not is_square_attacked(board, 61, true) and
            not is_square_attacked(board, 62, true),
          square,
          62
        )
        |> maybe_add_castle(
          board.black_queenside and piece_at(board, 59) == @empty and
            piece_at(board, 58) == @empty and piece_at(board, 57) == @empty and
            piece_at(board, 56) == ?r and not is_square_attacked(board, 59, true) and
            not is_square_attacked(board, 58, true),
          square,
          58
        )
      else
        acc
      end
    end
  end

  defp maybe_add_castle(acc, false, _from, _to), do: acc

  defp maybe_add_castle(acc, true, from, to),
    do: [%Move{from: from, to: to, is_castling: true} | acc]

  defp ray_attack?(board, row, col, directions, targets) do
    Enum.any?(directions, fn {dr, dc} ->
      ray_hit?(board, row + dr, col + dc, dr, dc, targets)
    end)
  end

  defp ray_hit?(_board, row, col, _dr, _dc, _targets)
       when row < 0 or row > 7 or col < 0 or col > 7,
       do: false

  defp ray_hit?(board, row, col, dr, dc, targets) do
    piece = piece_at(board, make_square(row, col))

    cond do
      piece == @empty -> ray_hit?(board, row + dr, col + dc, dr, dc, targets)
      piece in targets -> true
      true -> false
    end
  end

  defp find_king(board, white_king) do
    target = if white_king, do: ?K, else: ?k
    Enum.find(0..63, fn square -> piece_at(board, square) == target end)
  end

  defp parse_side_to_move("w"), do: {:ok, true}
  defp parse_side_to_move("b"), do: {:ok, false}
  defp parse_side_to_move(_), do: :error

  defp parse_castling("-") do
    {:ok,
     %{
       white_kingside: false,
       white_queenside: false,
       black_kingside: false,
       black_queenside: false
     }}
  end

  defp parse_castling(castling) do
    Enum.reduce_while(
      String.to_charlist(castling),
      {:ok,
       %{
         white_kingside: false,
         white_queenside: false,
         black_kingside: false,
         black_queenside: false
       }},
      fn char, {:ok, rights} ->
        next_rights =
          case char do
            ?K -> %{rights | white_kingside: true}
            ?Q -> %{rights | white_queenside: true}
            ?k -> %{rights | black_kingside: true}
            ?q -> %{rights | black_queenside: true}
            _ -> :error
          end

        case next_rights do
          :error -> {:halt, :error}
          _ -> {:cont, {:ok, next_rights}}
        end
      end
    )
  end

  defp parse_en_passant("-"), do: {:ok, nil}

  defp parse_en_passant(text) do
    parse_square_text(text)
  end

  defp parse_promotion(move_text) do
    case String.length(move_text) do
      4 ->
        {:ok, nil}

      5 ->
        promotion = move_text |> String.at(4) |> String.upcase() |> String.to_charlist()

        case promotion do
          [piece] when piece in ~c"QRBN" -> {:ok, piece}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_square_text(<<file, rank>>) when file in ?a..?h and rank in ?1..?8 do
    {:ok, make_square(rank - ?1, file - ?a)}
  end

  defp parse_square_text(_), do: :error

  defp parse_piece_placement(pieces) do
    do_parse_piece_placement(
      String.to_charlist(pieces),
      7,
      0,
      List.to_tuple(List.duplicate(@empty, 64))
    )
  end

  defp do_parse_piece_placement([], 0, 8, squares), do: {:ok, squares}
  defp do_parse_piece_placement([], _rank, _file, _squares), do: :error

  defp do_parse_piece_placement([?/ | rest], rank, 8, squares) when rank > 0 do
    do_parse_piece_placement(rest, rank - 1, 0, squares)
  end

  defp do_parse_piece_placement([char | rest], rank, file, squares) when char in ?1..?8 do
    next_file = file + (char - ?0)
    if next_file <= 8, do: do_parse_piece_placement(rest, rank, next_file, squares), else: :error
  end

  defp do_parse_piece_placement([char | rest], rank, file, squares)
       when char in ~c"PNBRQKpnbrqk" and file < 8 do
    do_parse_piece_placement(rest, rank, file + 1, put_elem(squares, rank * 8 + file, char))
  end

  defp do_parse_piece_placement(_chars, _rank, _file, _squares), do: :error

  defp export_rank(board, rank) do
    {parts, empty_count} =
      Enum.reduce(0..7, {[], 0}, fn file, {parts, empty_count} ->
        piece = piece_at(board, rank * 8 + file)

        cond do
          piece == @empty ->
            {parts, empty_count + 1}

          empty_count > 0 ->
            {[<<piece>> | [Integer.to_string(empty_count) | parts]], 0}

          true ->
            {[<<piece>> | parts], 0}
        end
      end)

    parts =
      if empty_count > 0 do
        [Integer.to_string(empty_count) | parts]
      else
        parts
      end

    parts |> Enum.reverse() |> IO.iodata_to_binary()
  end

  defp maybe_add_castling(list, true, value), do: list ++ [value]
  defp maybe_add_castling(list, false, _value), do: list

  defp piece_at(board, square), do: elem(board.squares, square)
  defp square_row(square), do: div(square, 8)
  defp square_col(square), do: rem(square, 8)
  defp make_square(row, col), do: row * 8 + col
  defp square_to_text(square), do: <<?a + square_col(square), ?1 + square_row(square)>>
  defp in_bounds(row, col), do: row >= 0 and row < 8 and col >= 0 and col < 8
  defp is_white_piece(piece), do: piece >= ?A and piece <= ?Z
  defp is_black_piece(piece), do: piece >= ?a and piece <= ?z

  defp same_side(first, second),
    do:
      (is_white_piece(first) and is_white_piece(second)) or
        (is_black_piece(first) and is_black_piece(second))

  defp lower_piece(piece) when piece >= ?A and piece <= ?Z, do: piece + 32
  defp lower_piece(piece), do: piece
  defp upper_piece(piece) when piece >= ?a and piece <= ?z, do: piece - 32
  defp upper_piece(piece), do: piece
  defp is_center_square(square), do: square_row(square) in [3, 4] and square_col(square) in [3, 4]

  defp piece_value(piece) do
    case upper_piece(piece) do
      ?P -> 100
      ?N -> 320
      ?B -> 330
      ?R -> 500
      ?Q -> 900
      ?K -> 20_000
      _ -> 0
    end
  end

  defp piece_square_bonus(piece, row, col) do
    eval_row = if is_white_piece(piece), do: row, else: 7 - row

    table =
      case upper_piece(piece) do
        ?P -> @pawn_table
        ?N -> @knight_table
        ?B -> @bishop_table
        ?R -> @rook_table
        ?Q -> @queen_table
        ?K -> @king_table
        _ -> nil
      end

    if table == nil do
      0
    else
      table |> elem(eval_row) |> elem(col)
    end
  end
end

defmodule ChessEngine.CLI do
  alias ChessEngine
  alias ChessEngine.{Chess960, PGN}

  def main do
    loop(ChessEngine.new_engine())
  end

  defp loop(engine) do
    case IO.read(:stdio, :line) do
      :eof ->
        :ok

      line ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            loop(engine)

          true ->
            case process_command(engine, trimmed) do
              {:continue, next_engine} ->
                loop(next_engine)

              :halt ->
                :ok
            end
        end
    end
  end

  defp process_command(_engine, "quit"), do: :halt
  defp process_command(_engine, "exit"), do: :halt

  defp process_command(_engine, "new") do
    IO.puts("OK: New game started")
    {:continue, ChessEngine.new_engine()}
  end

  defp process_command(engine, "undo") do
    case ChessEngine.undo(engine) do
      {:ok, next_engine} ->
        IO.puts("OK: undo")
        {:continue, next_engine}

      :error ->
        IO.puts("ERROR: No moves to undo")
        {:continue, engine}
    end
  end

  defp process_command(engine, "status") do
    IO.puts(ChessEngine.format_status(ChessEngine.status(engine)))
    {:continue, engine}
  end

  defp process_command(engine, "export") do
    IO.puts("FEN: #{ChessEngine.board_export_fen(engine.board)}")
    {:continue, engine}
  end

  defp process_command(engine, "eval") do
    IO.puts("EVALUATION: #{ChessEngine.evaluate_board(engine.board)}")
    {:continue, engine}
  end

  defp process_command(engine, "hash") do
    IO.puts("HASH: #{ChessEngine.board_hash_hex(engine.board)}")
    {:continue, engine}
  end

  defp process_command(engine, "draws") do
    reason = ChessEngine.draw_reason(engine)
    draw = if reason == "none", do: "false", else: "true"

    IO.puts(
      "DRAWS: repetition=#{ChessEngine.repetition_count(engine)}; halfmove=#{engine.board.halfmove_clock}; draw=#{draw}; reason=#{reason}"
    )

    {:continue, engine}
  end

  defp process_command(engine, "history") do
    current = ChessEngine.board_hash_hex(engine.board)
    IO.puts("HISTORY: count=#{length(engine.position_history)}; current=#{current}")
    {:continue, engine}
  end

  defp process_command(engine, "help") do
    IO.puts(
      "OK: commands=new move undo status fen export eval hash draws history ai perft pgn uci isready new960 position960 help quit"
    )

    {:continue, engine}
  end

  defp process_command(engine, "uci") do
    IO.puts("id name Elixir Chess Engine")
    IO.puts("id author The Great Analysis Challenge")
    IO.puts("uciok")
    {:continue, engine}
  end

  defp process_command(engine, "isready") do
    IO.puts("readyok")
    {:continue, engine}
  end

  defp process_command(engine, "new960") do
    case ChessEngine.load_chess960(engine, 0) do
      {:ok, next_engine} ->
        IO.puts("OK: New game started")
        IO.puts("960: new game id=0; backrank=#{Chess960.backrank(0)}")
        {:continue, next_engine}

      :error ->
        IO.puts("ERROR: Could not load Chess960 position")
        {:continue, engine}
    end
  end

  defp process_command(engine, <<"new960 ", id_text::binary>>) do
    case Integer.parse(String.trim(id_text)) do
      {chess960_id, ""} when chess960_id >= 0 and chess960_id <= 959 ->
        case ChessEngine.load_chess960(engine, chess960_id) do
          {:ok, next_engine} ->
            IO.puts("OK: New game started")
            IO.puts("960: new game id=#{chess960_id}; backrank=#{Chess960.backrank(chess960_id)}")
            {:continue, next_engine}

          :error ->
            IO.puts("ERROR: Could not load Chess960 position")
            {:continue, engine}
        end

      _ ->
        IO.puts("ERROR: new960 id must be between 0 and 959")
        {:continue, engine}
    end
  end

  defp process_command(engine, "position960") do
    IO.puts(
      "960: id=#{engine.chess960_id}; mode=#{if(engine.chess960_mode, do: "chess960", else: "standard")}; backrank=#{Chess960.backrank(engine.chess960_id)}; fen=#{Chess960.build_fen(engine.chess960_id)}"
    )

    {:continue, engine}
  end

  defp process_command(engine, <<"pgn ", rest::binary>>) do
    process_pgn_command(engine, String.trim(rest))
  end

  defp process_command(engine, <<"move ", move_text::binary>>) do
    case ChessEngine.resolve_user_move(engine, move_text) do
      {:ok, move} ->
        {:ok, next_engine} = ChessEngine.apply_engine_move(engine, move)
        IO.puts("OK: #{ChessEngine.move_to_string(move)}")
        {:continue, next_engine}

      {:error, :invalid_move_format} ->
        IO.puts("ERROR: Invalid move format")
        {:continue, engine}

      {:error, :illegal_move} ->
        IO.puts("ERROR: Illegal move")
        {:continue, engine}
    end
  end

  defp process_command(engine, <<"fen ", fen_text::binary>>) do
    case ChessEngine.load_position(engine, fen_text) do
      {:ok, next_engine} ->
        IO.puts("OK: position loaded")
        {:continue, next_engine}

      :error ->
        IO.puts("ERROR: Invalid FEN string")
        {:continue, engine}
    end
  end

  defp process_command(engine, <<"ai ", depth_text::binary>>) do
    case Integer.parse(depth_text) do
      {depth, ""} when depth >= 1 and depth <= 5 ->
        started_at = System.monotonic_time(:millisecond)

        case ChessEngine.select_best_move(engine.board, depth) do
          {:ok, move, score} ->
            {:ok, next_engine} = ChessEngine.apply_engine_move(engine, move)
            elapsed_ms = System.monotonic_time(:millisecond) - started_at

            IO.puts(
              "AI: #{ChessEngine.move_to_string(move)} (depth=#{depth}, eval=#{score}, time=#{elapsed_ms}ms)"
            )

            {:continue, next_engine}

          :error ->
            IO.puts("ERROR: No legal moves available")
            {:continue, engine}
        end

      _ ->
        IO.puts("ERROR: AI depth must be 1-5")
        {:continue, engine}
    end
  end

  defp process_command(engine, <<"perft ", depth_text::binary>>) do
    case Integer.parse(depth_text) do
      {depth, ""} when depth >= 0 and depth <= 6 ->
        started_at = System.monotonic_time(:millisecond)
        count = ChessEngine.perft(engine.board, depth)
        elapsed_ms = System.monotonic_time(:millisecond) - started_at

        IO.puts("NODES: depth=#{depth}; count=#{count}; time=#{elapsed_ms}ms")

        {:continue, engine}

      _ ->
        IO.puts("ERROR: Invalid perft depth")
        {:continue, engine}
    end
  end

  defp process_command(engine, _unknown) do
    IO.puts("ERROR: Invalid command")
    {:continue, engine}
  end

  defp process_pgn_command(engine, <<"load ", path::binary>>) do
    case File.read(String.trim(path)) do
      {:ok, content} ->
        case PGN.parse(content, String.trim(path)) do
          {:ok, game} ->
            next_engine = ChessEngine.load_pgn_game(engine, game)
            IO.puts("PGN: loaded source=#{String.trim(path)}")
            {:continue, next_engine}

          {:error, message} ->
            IO.puts("ERROR: pgn load failed: #{message}")
            {:continue, engine}
        end

      {:error, :enoent} ->
        IO.puts("ERROR: pgn load failed: file not found: #{String.trim(path)}")
        {:continue, engine}

      {:error, reason} ->
        IO.puts("ERROR: pgn load failed: #{:file.format_error(reason)}")
        {:continue, engine}
    end
  end

  defp process_pgn_command(engine, "show") do
    IO.puts("PGN: source=#{engine.pgn_game.source}; moves=#{length(engine.pgn_game.moves)}")
    IO.write(PGN.serialize(engine.pgn_game))
    {:continue, engine}
  end

  defp process_pgn_command(engine, "moves") do
    case PGN.mainline_sans(engine.pgn_game) do
      [] -> IO.puts("PGN: moves (none)")
      moves -> IO.puts("PGN: moves #{Enum.join(moves, " ")}")
    end

    {:continue, engine}
  end

  defp process_pgn_command(engine, _rest) do
    IO.puts("ERROR: Unsupported pgn command")
    {:continue, engine}
  end
end

defmodule ChessEngine.SelfTest do
  alias ChessEngine

  def main do
    System.halt(if run(), do: 0, else: 1)
  end

  def run do
    engine = ChessEngine.new_engine()

    with :ok <-
           assert_equal(
             ChessEngine.board_export_fen(engine.board),
             "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
             "starting FEN mismatch"
           ),
         {:ok, move} <- ChessEngine.resolve_user_move(engine, "e2e4"),
         {:ok, after_e2e4} <- ChessEngine.apply_engine_move(engine, move),
         :ok <-
           assert_equal(
             ChessEngine.board_export_fen(after_e2e4.board),
             "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
             "e2e4 FEN mismatch"
           ),
         {:ok, castling_engine} <-
           ChessEngine.load_position(engine, "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"),
         {:ok, castle_move} <- ChessEngine.resolve_user_move(castling_engine, "e1g1"),
         {:ok, castled} <- ChessEngine.apply_engine_move(castling_engine, castle_move),
         :ok <-
           assert_equal(
             ChessEngine.board_export_fen(castled.board),
             "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1",
             "castling FEN mismatch"
           ),
         {:ok, en_passant_engine} <-
           ChessEngine.load_position(
             engine,
             "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3"
           ),
         {:ok, en_passant_move} <- ChessEngine.resolve_user_move(en_passant_engine, "e5f6"),
         {:ok, en_passant_result} <-
           ChessEngine.apply_engine_move(en_passant_engine, en_passant_move),
         :ok <-
           assert_equal(
             ChessEngine.board_export_fen(en_passant_result.board),
             "rnbqkbnr/ppp1p1pp/5P2/3p4/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3",
             "en passant FEN mismatch"
           ),
         :ok <- assert_equal(ChessEngine.perft(engine.board, 3), 8902, "perft(3) mismatch") do
      IO.puts("Self-test passed")
      true
    else
      {:error, message} ->
        IO.puts(:stderr, "Self-test failed: #{message}")
        false

      :error ->
        IO.puts(:stderr, "Self-test failed")
        false
    end
  end

  defp assert_equal(left, right, _message) when left == right, do: :ok
  defp assert_equal(_left, _right, message), do: {:error, message}
end
