defmodule ChessEngine.PGN do
  alias ChessEngine
  alias ChessEngine.Move

  @start_fen "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  @result_tokens MapSet.new(["1-0", "0-1", "1/2-1/2", "*"])

  def start_fen, do: @start_fen

  def new_game(start_fen \\ @start_fen, source \\ "current-game") do
    %{
      tags: default_tags(start_fen),
      moves: [],
      result: "*",
      source: source,
      initial_fen: start_fen
    }
  end

  def build_game_from_history(move_history, opts \\ []) do
    start_fen = Keyword.get(opts, :start_fen, @start_fen)
    source = Keyword.get(opts, :source, "current-game")
    board = load_board!(start_fen)

    {moves, _board} =
      Enum.map_reduce(move_history, board, fn move, current_board ->
        san = move_to_san(current_board, move)
        next_board = ChessEngine.apply_move(current_board, move)

        {
          %{
            san: san,
            move: clone_move(move),
            fen_before: ChessEngine.board_export_fen(current_board),
            fen_after: ChessEngine.board_export_fen(next_board)
          },
          next_board
        }
      end)

    %{new_game(start_fen, source) | moves: moves}
  end

  def set_result(game, result) do
    %{game | result: result, tags: put_tag(game.tags, "Result", result)}
  end

  def parse(content, source \\ "current-game") do
    {tags, movetext} = parse_tags(content)
    initial_fen = get_tag(tags, "FEN") || @start_fen
    result = get_tag(tags, "Result") || "*"
    board = load_board!(initial_fen)
    tokens = tokenize_movetext(movetext)

    try do
      {moves, parsed_result, _board} =
        Enum.reduce(tokens, {[], result, board}, fn token,
                                                    {moves, current_result, current_board} ->
          cond do
            move_number_token?(token) or nag_token?(token) ->
              {moves, current_result, current_board}

            MapSet.member?(@result_tokens, token) ->
              {moves, token, current_board}

            true ->
              move = san_to_move(current_board, token)
              san = move_to_san(current_board, move)
              next_board = ChessEngine.apply_move(current_board, move)

              {
                moves ++
                  [
                    %{
                      san: san,
                      move: clone_move(move),
                      fen_before: ChessEngine.board_export_fen(current_board),
                      fen_after: ChessEngine.board_export_fen(next_board)
                    }
                  ],
                current_result,
                next_board
              }
          end
        end)

      normalized_tags =
        tags
        |> ensure_tag("Event", "CLI Game")
        |> ensure_tag("Site", "Local")
        |> ensure_tag("Result", parsed_result)

      {:ok,
       %{
         tags: normalized_tags,
         moves: moves,
         result: parsed_result,
         source: source,
         initial_fen: initial_fen
       }}
    rescue
      error in RuntimeError ->
        {:error, Exception.message(error)}
    end
  end

  def serialize(game) do
    tag_lines = Enum.map(game.tags, fn {name, value} -> ~s([#{name} "#{value}"]) end)
    move_text = serialize_moves(game.moves, game.initial_fen)

    [Enum.join(tag_lines, "\n"), "", String.trim("#{move_text} #{game.result}")]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  def mainline_sans(game) do
    Enum.map(game.moves, & &1.san)
  end

  def mainline_moves(game), do: game.moves

  def move_to_san(board, %Move{} = move) do
    piece = piece_at(board, move.from)
    destination = square_to_text(move.to)
    capture? = move.is_en_passant or piece_at(board, move.to) != ?.

    san =
      cond do
        move.is_castling and square_col(move.to) == 6 ->
          "O-O"

        move.is_castling ->
          "O-O-O"

        upper_piece(piece) == ?P ->
          pawn_san(move, capture?, destination)

        true ->
          prefix =
            <<upper_piece(piece)>> <>
              disambiguation(board, move) <>
              if(capture?, do: "x", else: "")

          prefix <> destination <> promotion_suffix(move.promotion)
      end

    next_board = ChessEngine.apply_move(board, move)

    cond do
      ChessEngine.is_in_check(next_board, next_board.white_to_move) and
          ChessEngine.generate_legal_moves(next_board) == [] ->
        san <> "#"

      ChessEngine.is_in_check(next_board, next_board.white_to_move) ->
        san <> "+"

      true ->
        san
    end
  end

  defp pawn_san(move, capture?, destination) do
    prefix =
      if capture? do
        <<?a + square_col(move.from), ?x>>
      else
        ""
      end

    prefix <> destination <> promotion_suffix(move.promotion)
  end

  def san_to_move(board, san) do
    normalized = normalize_san(san)

    board
    |> ChessEngine.generate_legal_moves()
    |> Enum.find(fn move -> normalize_san(move_to_san(board, move)) == normalized end)
    |> case do
      nil -> raise("unresolved SAN move: #{san}")
      move -> move
    end
  end

  defp parse_tags(content) do
    {tag_lines, movetext_lines} =
      content
      |> String.split(~r/\r?\n/)
      |> Enum.reduce({[], []}, fn line, {tags, movetext} ->
        trimmed = String.trim(line)

        cond do
          String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]") ->
            {[trimmed | tags], movetext}

          true ->
            {tags, [line | movetext]}
        end
      end)

    tags =
      tag_lines
      |> Enum.reverse()
      |> Enum.map(fn line ->
        case Regex.run(~r/^\[([A-Za-z0-9_]+)\s+"((?:\\.|[^"])*)"\]$/, line,
               capture: :all_but_first
             ) do
          [name, value] -> {name, String.replace(value, ~s(\\"), ~s("))}
          _ -> raise("invalid PGN tag: #{line}")
        end
      end)

    {tags, Enum.reverse(movetext_lines) |> Enum.join("\n")}
  end

  defp tokenize_movetext(movetext) do
    movetext
    |> strip_comments_and_variations()
    |> String.split(~r/\s+/, trim: true)
  end

  defp strip_comments_and_variations(text) do
    do_strip(text, 0, false, false, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp do_strip(text, index, _in_braces, _in_semicolon, acc) when index >= byte_size(text) do
    acc
  end

  defp do_strip(text, index, in_braces, in_semicolon, acc) do
    byte = :binary.at(text, index)

    cond do
      in_semicolon and byte == ?\n ->
        do_strip(text, index + 1, false, false, [<<byte>> | acc])

      in_semicolon ->
        do_strip(text, index + 1, false, true, acc)

      in_braces and byte == ?} ->
        do_strip(text, index + 1, false, false, acc)

      in_braces ->
        do_strip(text, index + 1, true, false, acc)

      byte == ?{ ->
        do_strip(text, index + 1, true, false, acc)

      byte == ?; ->
        do_strip(text, index + 1, false, true, acc)

      byte == ?( ->
        do_strip_variation(text, index + 1, 1, acc)

      true ->
        do_strip(text, index + 1, false, false, [<<byte>> | acc])
    end
  end

  defp do_strip_variation(text, index, depth, acc) when index >= byte_size(text) or depth == 0 do
    do_strip(text, index, false, false, acc)
  end

  defp do_strip_variation(text, index, depth, acc) do
    byte = :binary.at(text, index)

    cond do
      byte == ?( -> do_strip_variation(text, index + 1, depth + 1, acc)
      byte == ?) -> do_strip_variation(text, index + 1, depth - 1, acc)
      true -> do_strip_variation(text, index + 1, depth, acc)
    end
  end

  defp serialize_moves(moves, initial_fen) do
    {move_number, white_to_move} = starting_ply(initial_fen)

    {parts, _move_number, _white_to_move} =
      Enum.reduce(moves, {[], move_number, white_to_move}, fn node,
                                                              {parts, current_number,
                                                               current_white} ->
        next_parts =
          cond do
            current_white ->
              parts ++ ["#{current_number}. #{node.san}"]

            parts == [] or not String.starts_with?(List.last(parts), "#{current_number}.") ->
              parts ++ ["#{current_number}... #{node.san}"]

            true ->
              parts ++ [node.san]
          end

        next_number = if current_white, do: current_number, else: current_number + 1
        {next_parts, next_number, not current_white}
      end)

    Enum.join(parts, " ")
  end

  defp starting_ply(fen) do
    parts = String.split(fen)

    move_number =
      case Enum.at(parts, 5) do
        nil ->
          1

        value ->
          case Integer.parse(value) do
            {parsed, ""} -> max(parsed, 1)
            _ -> 1
          end
      end

    white_to_move = Enum.at(parts, 1, "w") == "w"
    {move_number, white_to_move}
  end

  defp disambiguation(board, move) do
    moving_piece = piece_at(board, move.from)

    conflicts =
      board
      |> ChessEngine.generate_legal_moves()
      |> Enum.filter(fn candidate ->
        candidate != move and candidate.to == move.to and
          piece_at(board, candidate.from) == moving_piece
      end)

    same_file = Enum.any?(conflicts, &(square_col(&1.from) == square_col(move.from)))
    same_rank = Enum.any?(conflicts, &(square_row(&1.from) == square_row(move.from)))

    cond do
      conflicts == [] -> ""
      not same_file -> <<?a + square_col(move.from)>>
      not same_rank -> Integer.to_string(square_row(move.from) + 1)
      true -> square_to_text(move.from)
    end
  end

  defp normalize_san(token) do
    token
    |> String.trim()
    |> String.replace(~r/^(\d+)\.(\.\.)?/, "")
    |> String.replace(~r/[!?]+$/, "")
    |> String.replace(~r/(?:\+|#)+$/, "")
    |> String.replace("0-0-0", "O-O-O")
    |> String.replace("0-0", "O-O")
    |> String.replace("e.p.", "")
    |> String.replace("ep", "")
    |> String.trim()
  end

  defp move_number_token?(token), do: String.match?(token, ~r/^\d+\.(\.\.)?$/)
  defp nag_token?(token), do: String.match?(token, ~r/^\$\d+$/)

  defp default_tags(start_fen) do
    base = [{"Event", "CLI Game"}, {"Site", "Local"}]

    tags =
      if start_fen == @start_fen do
        base
      else
        base ++ [{"SetUp", "1"}, {"FEN", start_fen}]
      end

    tags ++ [{"Result", "*"}]
  end

  defp ensure_tag(tags, name, value) do
    if Enum.any?(tags, fn {current_name, _current_value} -> current_name == name end) do
      put_tag(tags, name, value)
    else
      tags ++ [{name, value}]
    end
  end

  defp put_tag(tags, name, value) do
    Enum.map(tags, fn
      {^name, _current_value} -> {name, value}
      tag -> tag
    end)
  end

  defp get_tag(tags, name) do
    Enum.find_value(tags, fn
      {^name, value} -> value
      _ -> nil
    end)
  end

  defp load_board!(fen) do
    case ChessEngine.board_load_fen(fen) do
      {:ok, board} -> board
      :error -> raise("invalid FEN: #{fen}")
    end
  end

  defp clone_move(%Move{} = move) do
    %Move{
      from: move.from,
      to: move.to,
      promotion: move.promotion,
      is_castling: move.is_castling,
      is_en_passant: move.is_en_passant,
      captured: move.captured
    }
  end

  defp piece_at(board, square), do: elem(board.squares, square)
  defp square_row(square), do: div(square, 8)
  defp square_col(square), do: rem(square, 8)
  defp square_to_text(square), do: <<?a + square_col(square), ?1 + square_row(square)>>
  defp upper_piece(piece) when piece >= ?a and piece <= ?z, do: piece - 32
  defp upper_piece(piece), do: piece

  defp promotion_suffix(nil), do: ""
  defp promotion_suffix(piece), do: "=" <> <<upper_piece(piece)>>
end
