const fs = require("fs");
const { Board } = require("./dist/board");
const { MoveGenerator } = require("./dist/moveGenerator");
const { FenParser } = require("./dist/fen");
const { AI } = require("./dist/ai");

function buildContext(setup) {
  const board = new Board();
  const moveGenerator = new MoveGenerator(board);
  const fenParser = new FenParser(board);
  const ai = new AI(board, moveGenerator);

  if (setup.type === "fen") {
    fenParser.parseFen(setup.value);
  }

  return { board, moveGenerator, fenParser, ai };
}

function moveToUci(board, move) {
  return (
    board.squareToAlgebraic(move.from) +
    board.squareToAlgebraic(move.to) +
    (move.promotion ? move.promotion.toLowerCase() : "")
  );
}

function findLegalMove(context, moveText) {
  if (typeof moveText !== "string" || moveText.length < 4) {
    throw new Error(`Invalid move: ${moveText}`);
  }

  const from = context.board.algebraicToSquare(moveText.slice(0, 2));
  const to = context.board.algebraicToSquare(moveText.slice(2, 4));
  const promotion =
    moveText.length > 4 ? moveText.slice(4, 5).toUpperCase() : undefined;

  const legalMoves = context.moveGenerator.getLegalMoves(context.board.getTurn());
  const move = legalMoves.find(
    (candidate) =>
      candidate.from === from &&
      candidate.to === to &&
      candidate.promotion === promotion,
  );

  if (!move) {
    throw new Error(`Illegal move: ${moveText}`);
  }

  return move;
}

function getGameStatus(context) {
  const color = context.board.getTurn();
  if (context.moveGenerator.isCheckmate(color)) {
    return "checkmate";
  }
  if (context.moveGenerator.isStalemate(color)) {
    return "stalemate";
  }
  return "ongoing";
}

function executeCase(testCase) {
  const caseId = testCase.id;

  try {
    const context = buildContext(testCase.setup);
    const operation = testCase.operation;
    let actual;

    switch (operation.type) {
      case "export_fen":
        actual = context.fenParser.exportFen();
        break;
      case "legal_move_count":
        actual = context.moveGenerator.getLegalMoves(context.board.getTurn()).length;
        break;
      case "apply_move_export_fen": {
        const move = findLegalMove(context, operation.move);
        context.board.makeMove(move);
        actual = context.fenParser.exportFen();
        break;
      }
      case "apply_move_undo_export_fen": {
        const move = findLegalMove(context, operation.move);
        context.board.makeMove(move);
        context.board.undoMove();
        actual = context.fenParser.exportFen();
        break;
      }
      case "apply_move_status": {
        const move = findLegalMove(context, operation.move);
        context.board.makeMove(move);
        actual = getGameStatus(context);
        break;
      }
      case "ai_best_move": {
        const result = context.ai.findBestMove(operation.depth);
        if (!result.move) {
          throw new Error("AI did not return a move");
        }
        actual = moveToUci(context.board, result.move);
        break;
      }
      default:
        throw new Error(`Unsupported operation: ${operation.type}`);
    }

    return {
      id: caseId,
      status: "passed",
      normalized_actual: actual,
    };
  } catch (error) {
    return {
      id: caseId,
      status: "failed",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function parseArgs(argv) {
  const args = {};
  for (let index = 2; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key.startsWith("--") || value === undefined) {
      throw new Error("Expected --suite <path> --report <path>");
    }
    args[key.slice(2)] = value;
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.suite || !args.report) {
    throw new Error("Missing --suite or --report");
  }

  const suite = JSON.parse(fs.readFileSync(args.suite, "utf8"));
  const report = {
    schema_version: "1.0",
    suite: suite.suite,
    implementation: "typescript",
    cases: suite.cases.map(executeCase),
  };
  fs.writeFileSync(args.report, JSON.stringify(report, null, 2));
}

main();
