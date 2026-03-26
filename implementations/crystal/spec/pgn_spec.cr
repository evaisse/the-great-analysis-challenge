require "spec"
require "../src/pgn"

describe PGN do
  it "parses fixture mainline moves and tags" do
    content = <<-PGN
[Event "Paris Opera"]
[Site "Paris FRA"]
[Date "1858.01.01"]
[Round "?"]
[White "Paul Morphy"]
[Black "Duke Karl / Count Isouard"]
[Result "1-0"]
[Opening "Philidor Defense"]

1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6
7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7
12. O-O-O Rd8 13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7
16. Qb8+ Nxb8 17. Rd8# 1-0
PGN
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
