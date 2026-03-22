require "spec"
require "../src/pgn"

describe PGN do
  it "parses fixture mainline moves and tags" do
    content = File.read("/repo/test/fixtures/pgn/morphy_opera_1858.pgn")
    game = PGN.parse_game(content)

    game.tags["Event"].should eq("Paris Opera")
    game.mainline_san_moves.size.should eq(33)
    game.mainline_san_moves.first.should eq("e4")
    game.mainline_san_moves.last.should eq("Rd8#")
  end

  it "parses nested variations and comments" do
    content = <<-PGN
[Event "Variation Test"]
[Result "*"]

1. e4 e5 (1... c5 {Sicilian} (1... e6) 2. Nf3) 2. Nf3 Nc6 *
PGN

    game = PGN.parse_game(content)
    first_black = game.mainline.moves[1]
    first_black.variations.size.should eq(1)
    nested = first_black.variations.first
    nested.moves.first.san.should eq("c5")
    nested.moves.first.comments.should eq(["Sicilian"])
    nested.moves.first.variations.first.moves.first.san.should eq("e6")
    PGN.serialize(game).should contain("(1... c5 {Sicilian} (1... e6) 2. Nf3)")
  end

  it "serializes live coordinate history as SAN" do
    state = FEN.starting_position
    generator = MoveGenerator.new
    e4 = generator.get_legal_moves(state, state.turn).find { |move| move.to_s == "e2e4" }
    e4.should_not be_nil
    state = Board.make_move(state, e4.not_nil!)
    e5 = generator.get_legal_moves(state, state.turn).find { |move| move.to_s == "e7e5" }
    e5.should_not be_nil

    game = PGN.build_live_game(FEN.starting_position, [e4.not_nil!, e5.not_nil!])
    PGN.serialize(game).should contain("1. e4 1... e5 *")
  end
end
