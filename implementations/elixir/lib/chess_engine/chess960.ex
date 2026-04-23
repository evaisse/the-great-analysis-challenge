defmodule ChessEngine.Chess960 do
  @knight_table [
    {0, 1},
    {0, 2},
    {0, 3},
    {0, 4},
    {1, 2},
    {1, 3},
    {1, 4},
    {2, 3},
    {2, 4},
    {3, 4}
  ]

  def backrank(chess960_id) when chess960_id >= 0 and chess960_id <= 959 do
    pieces = List.duplicate(nil, 8)

    remainder = rem(chess960_id, 4)
    value = div(chess960_id, 4)
    pieces = List.replace_at(pieces, 2 * remainder + 1, "b")

    remainder = rem(value, 4)
    value = div(value, 4)
    pieces = List.replace_at(pieces, 2 * remainder, "b")

    remainder = rem(value, 6)
    value = div(value, 6)
    empty = empty_indexes(pieces)
    pieces = List.replace_at(pieces, Enum.at(empty, remainder), "q")

    {knight_a, knight_b} = Enum.at(@knight_table, value)
    empty = empty_indexes(pieces)
    pieces = List.replace_at(pieces, Enum.at(empty, knight_a), "n")
    pieces = List.replace_at(pieces, Enum.at(empty, knight_b), "n")

    empty = empty_indexes(pieces)

    pieces
    |> List.replace_at(Enum.at(empty, 0), "r")
    |> List.replace_at(Enum.at(empty, 1), "k")
    |> List.replace_at(Enum.at(empty, 2), "r")
    |> Enum.join()
  end

  def build_fen(chess960_id) when chess960_id >= 0 and chess960_id <= 959 do
    white_backrank = String.upcase(backrank(chess960_id))
    black_backrank = String.downcase(white_backrank)
    "#{black_backrank}/pppppppp/8/8/8/8/PPPPPPPP/#{white_backrank} w - - 0 1"
  end

  defp empty_indexes(pieces) do
    pieces
    |> Enum.with_index()
    |> Enum.filter(fn {piece, _index} -> is_nil(piece) end)
    |> Enum.map(fn {_piece, index} -> index end)
  end
end
