import XCTest
@testable import Chess

final class ChessTests: XCTestCase {
    func testInitialBoardSetup() {
        let board = Board()
        // Test white pieces
        XCTAssertEqual(board.pieces[0][0]?.type, .rook)
        XCTAssertEqual(board.pieces[0][0]?.color, .white)
        XCTAssertEqual(board.pieces[0][1]?.type, .knight)
        XCTAssertEqual(board.pieces[0][1]?.color, .white)
        XCTAssertEqual(board.pieces[0][2]?.type, .bishop)
        XCTAssertEqual(board.pieces[0][2]?.color, .white)
        XCTAssertEqual(board.pieces[0][3]?.type, .queen)
        XCTAssertEqual(board.pieces[0][3]?.color, .white)
        XCTAssertEqual(board.pieces[0][4]?.type, .king)
        XCTAssertEqual(board.pieces[0][4]?.color, .white)
        XCTAssertEqual(board.pieces[0][5]?.type, .bishop)
        XCTAssertEqual(board.pieces[0][5]?.color, .white)
        XCTAssertEqual(board.pieces[0][6]?.type, .knight)
        XCTAssertEqual(board.pieces[0][6]?.color, .white)
        XCTAssertEqual(board.pieces[0][7]?.type, .rook)
        XCTAssertEqual(board.pieces[0][7]?.color, .white)
        for i in 0...7 {
            XCTAssertEqual(board.pieces[1][i]?.type, .pawn)
            XCTAssertEqual(board.pieces[1][i]?.color, .white)
        }

        // Test black pieces
        XCTAssertEqual(board.pieces[7][0]?.type, .rook)
        XCTAssertEqual(board.pieces[7][0]?.color, .black)
        XCTAssertEqual(board.pieces[7][1]?.type, .knight)
        XCTAssertEqual(board.pieces[7][1]?.color, .black)
        XCTAssertEqual(board.pieces[7][2]?.type, .bishop)
        XCTAssertEqual(board.pieces[7][2]?.color, .black)
        XCTAssertEqual(board.pieces[7][3]?.type, .queen)
        XCTAssertEqual(board.pieces[7][3]?.color, .black)
        XCTAssertEqual(board.pieces[7][4]?.type, .king)
        XCTAssertEqual(board.pieces[7][4]?.color, .black)
        XCTAssertEqual(board.pieces[7][5]?.type, .bishop)
        XCTAssertEqual(board.pieces[7][5]?.color, .black)
        XCTAssertEqual(board.pieces[7][6]?.type, .knight)
        XCTAssertEqual(board.pieces[7][6]?.color, .black)
        XCTAssertEqual(board.pieces[7][7]?.type, .rook)
        XCTAssertEqual(board.pieces[7][7]?.color, .black)
        for i in 0...7 {
            XCTAssertEqual(board.pieces[6][i]?.type, .pawn)
            XCTAssertEqual(board.pieces[6][i]?.color, .black)
        }
    }
}
