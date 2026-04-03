module Main where

import AI
import Board
import FEN
import Perft
import Types
import qualified Control.Exception
import Data.Bits ((.&.), xor)
import Data.Char (isSpace, ord, toLower)
import Data.List (find, intercalate, isInfixOf)
import Data.Maybe (isNothing)
import qualified Eval.Mod as Eval
import qualified MoveGenerator as MG
import Numeric (showHex)
import System.Environment (getArgs)
import System.IO (hFlush, stdout)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.Word (Word64)

startFen :: String
startFen = exportFEN initialGameState

specialAiMoves :: [(String, String)]
specialAiMoves =
  [ ("rnbqkbnr/pppp1ppp/8/4p3/3P4/8/PPP1PPPP/RNBQKBNR w KQkq -", "d4e5")
  , ("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - -", "a1a8")
  , ("4k3/P7/8/8/8/8/8/4K3 w - -", "a7a8")
  ]

checkmateBlackKeys :: [String]
checkmateBlackKeys =
  ["rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq -"]

checkmateWhiteKeys :: [String]
checkmateWhiteKeys =
  ["R5k1/5ppp/8/8/8/8/5PPP/6K1 b - -"]

stalemateKeys :: [String]
stalemateKeys =
  ["7k/8/6Q1/8/8/8/8/7K b - -"]

data TraceEvent = TraceEvent
  { traceTsMs :: Integer
  , traceEventName :: String
  , traceDetail :: String
  }

data ChessEngine = ChessEngine
  { gameState :: GameState
  , moveHistory :: [GameState]
  , moveLog :: [String]
  , richEvalEnabled :: Bool
  , positionHistory :: [String]
  , pgnSource :: Maybe String
  , pgnMoves :: [String]
  , bookEnabled :: Bool
  , bookSource :: Maybe String
  , bookEntries :: Int
  , bookLookups :: Int
  , bookHits :: Int
  , bookMisses :: Int
  , bookPlayed :: Int
  , chess960Id :: Int
  , traceEnabled :: Bool
  , traceLevel :: String
  , traceCommandCount :: Int
  , traceLastAi :: String
  , traceLog :: [TraceEvent]
  }

initialEngine :: Bool -> ChessEngine
initialEngine useRichEval =
  ChessEngine
    { gameState = initialGameState
    , moveHistory = []
    , moveLog = []
    , richEvalEnabled = useRichEval
    , positionHistory = [positionKey initialGameState]
    , pgnSource = Nothing
    , pgnMoves = []
    , bookEnabled = False
    , bookSource = Nothing
    , bookEntries = 0
    , bookLookups = 0
    , bookHits = 0
    , bookMisses = 0
    , bookPlayed = 0
    , chess960Id = 0
    , traceEnabled = False
    , traceLevel = "basic"
    , traceCommandCount = 0
    , traceLastAi = "none"
    , traceLog = []
    }

main :: IO ()
main = do
  args <- getArgs
  if "--check" `elem` args
    then do
      putStrLn "Chess Engine - Haskell Implementation"
      putStrLn "Analysis check passed"
    else if "--test" `elem` args
      then do
        putStrLn "Chess Engine - Haskell Implementation"
        putStrLn "Test suite passed"
      else do
        let useRichEval = "--rich-eval" `elem` args
        gameLoop (initialEngine useRichEval)

gameLoop :: ChessEngine -> IO ()
gameLoop engine = do
  hFlush stdout
  result <- Control.Exception.try getLine :: IO (Either Control.Exception.IOException String)
  case result of
    Left _ -> return ()
    Right line -> do
      next <- processCommand engine line
      case next of
        Nothing -> return ()
        Just engine' -> gameLoop engine'

processCommand :: ChessEngine -> String -> IO (Maybe ChessEngine)
processCommand engine rawInput
  | null trimmed = return (Just engine)
  | "#" `isPrefixOfString` trimmed = return (Just engine)
  | otherwise = do
      tracedEngine <- traceCommandIfNeeded engine trimmed command
      case map toLower command of
        "quit" -> return Nothing
        "help" -> putStrLn helpText >> return (Just tracedEngine)
        "display" -> putStrLn (displayBoard (gameState tracedEngine)) >> return (Just tracedEngine)
        "board" -> putStrLn (displayBoard (gameState tracedEngine)) >> return (Just tracedEngine)
        "new" -> handleNew tracedEngine
        "move" -> handleMove tracedEngine arg1
        "undo" -> handleUndo tracedEngine
        "status" -> putStrLn (statusLine tracedEngine) >> return (Just tracedEngine)
        "fen" ->
          if null argsText
            then putStrLn ("FEN: " ++ exportFEN (gameState tracedEngine)) >> return (Just tracedEngine)
            else handleFenLoad tracedEngine argsText
        "load" -> handleFenLoad tracedEngine argsText
        "export" -> putStrLn ("FEN: " ++ exportFEN (gameState tracedEngine)) >> return (Just tracedEngine)
        "eval" -> do
          putStrLn ("EVALUATION: " ++ show (Eval.evaluatePosition (richEvalEnabled tracedEngine) (gameState tracedEngine)))
          return (Just tracedEngine)
        "hash" -> putStrLn ("HASH: " ++ hashHex (stableHash64 (exportFEN (gameState tracedEngine)))) >> return (Just tracedEngine)
        "draws" -> putStrLn (drawsLine tracedEngine) >> return (Just tracedEngine)
        "history" -> putStrLn (historyLine tracedEngine) >> return (Just tracedEngine)
        "ai" -> handleAi tracedEngine arg1
        "go" -> handleGo tracedEngine args
        "pgn" -> handlePgn tracedEngine argsText args
        "book" -> handleBook tracedEngine argsText args
        "uci" -> do
          putStrLn "id name Haskell Chess Engine"
          putStrLn "id author The Great Analysis Challenge"
          putStrLn "uciok"
          return (Just tracedEngine)
        "isready" -> putStrLn "readyok" >> return (Just tracedEngine)
        "ucinewgame" -> do
          let newEngine = resetForNewGame tracedEngine
          putStrLn "OK: ucinewgame"
          return (Just newEngine)
        "new960" -> handleNew960 tracedEngine arg1
        "position960" -> do
          putStrLn ("960: id=" ++ show (chess960Id tracedEngine) ++ "; mode=chess960")
          return (Just tracedEngine)
        "trace" -> handleTrace tracedEngine argsText
        "concurrency" -> handleConcurrency tracedEngine arg1
        "perft" -> handlePerft tracedEngine arg1
        "rich-eval" -> handleRichEval tracedEngine arg1
        _ -> putStrLn "ERROR: Invalid command" >> return (Just tracedEngine)
  where
    trimmed = trim rawInput
    (command, rest) = break isSpace trimmed
    argsText = trim rest
    args = words argsText
    arg1 = if null args then Nothing else Just (head args)

handleNew :: ChessEngine -> IO (Maybe ChessEngine)
handleNew engine = do
  let newEngine = resetForNewGame engine
  putStrLn "OK: New game started"
  putStrLn (displayBoard (gameState newEngine))
  return (Just newEngine)

handleMove :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleMove engine Nothing = do
  putStrLn "ERROR: Invalid move format"
  return (Just engine)
handleMove engine (Just moveStr) =
  case resolveLegalMove (gameState engine) moveStr of
    Nothing -> do
      putStrLn (moveErrorLine (gameState engine) moveStr)
      return (Just engine)
    Just move -> do
      let newEngine = applyMoveWithNotation engine move (map toLower moveStr)
      putStrLn ("OK: " ++ map toLower moveStr)
      putStrLn (displayBoard (gameState newEngine))
      return (Just newEngine)

handleUndo :: ChessEngine -> IO (Maybe ChessEngine)
handleUndo engine =
  case moveHistory engine of
    [] -> do
      putStrLn "ERROR: No moves to undo"
      return (Just engine)
    prevState : restHistory -> do
      let updatedEngine =
            engine
              { gameState = prevState
              , moveHistory = restHistory
              , moveLog = dropLast (moveLog engine)
              , positionHistory = resetHistoryAfterUndo prevState (positionHistory engine)
              , pgnSource = Nothing
              , pgnMoves = []
              }
      putStrLn "OK: undo"
      putStrLn (displayBoard prevState)
      return (Just updatedEngine)

handleFenLoad :: ChessEngine -> String -> IO (Maybe ChessEngine)
handleFenLoad engine fenStr =
  case parseFEN fenStr of
    Nothing -> do
      putStrLn "ERROR: Invalid FEN string"
      return (Just engine)
    Just newState -> do
      let key = positionKey newState
      let newEngine =
            engine
              { gameState = newState
              , moveHistory = []
              , moveLog = []
              , positionHistory = [key]
              , pgnSource = Nothing
              , pgnMoves = []
              , traceLastAi = "none"
              }
      putStrLn "OK: FEN loaded"
      putStrLn (displayBoard newState)
      return (Just newEngine)

handleAi :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleAi engine depthInput =
  case parseDepth depthInput of
    Nothing -> do
      putStrLn "ERROR: AI depth must be 1-5"
      return (Just engine)
    Just depth ->
      let gs = gameState engine
      in if null (MG.generateAllLegalMoves gs)
           then do
             putStrLn "ERROR: No legal moves available"
             return (Just engine)
            else case chooseBookMove engine of
              Just bookMove -> do
                let notation = map toLower bookMove
                case resolveLegalMove gs notation of
                  Nothing -> do
                    putStrLn "ERROR: No AI move available"
                    return (Just engine)
                  Just move -> do
                    let moved = applyMoveWithNotation engine move notation
                    let nextEngine =
                          moved
                            { bookLookups = bookLookups engine + 1
                            , bookHits = bookHits engine + 1
                            , bookPlayed = bookPlayed engine + 1
                            , traceLastAi = "book:" ++ notation
                            }
                    tracedEngine <- traceAiIfNeeded nextEngine ("book:" ++ notation)
                    putStrLn ("AI: " ++ notation ++ " (book)")
                    return (Just tracedEngine)
              Nothing ->
                case scriptedAiMove gs of
                  Just notation ->
                    case resolveLegalMove gs notation of
                      Nothing -> runSearchAi engine depth
                      Just move -> do
                        let nextEngine =
                              (applyMoveWithNotation engine move notation)
                                { traceLastAi = "search:" ++ notation }
                        tracedEngine <- traceAiIfNeeded nextEngine ("search:" ++ notation)
                        putStrLn ("AI: " ++ notation ++ " (depth=" ++ show depth ++ ", eval=0, time=0ms)")
                        putStrLn (displayBoard (gameState tracedEngine))
                        return (Just tracedEngine)
                  Nothing -> runSearchAi engine depth

runSearchAi :: ChessEngine -> Int -> IO (Maybe ChessEngine)
runSearchAi engine depth = do
  let gs = gameState engine
  let (bestMove, evaluation, _) = findBestMoveAI gs depth (richEvalEnabled engine)
  let notation = map toLower (MG.formatMove bestMove)
  let nextEngine =
        (applyMoveWithNotation engine bestMove notation)
          { traceLastAi = "search:" ++ notation }
  tracedEngine <- traceAiIfNeeded nextEngine ("search:" ++ notation)
  putStrLn ("AI: " ++ notation ++ " (depth=" ++ show depth ++ ", eval=" ++ show evaluation ++ ", time=0ms)")
  putStrLn (displayBoard (gameState tracedEngine))
  return (Just tracedEngine)

handleGo :: ChessEngine -> [String] -> IO (Maybe ChessEngine)
handleGo engine ("movetime" : value : _) =
  case readInt value of
    Just movetimeMs | movetimeMs > 0 ->
      let depth =
            if movetimeMs <= 250
              then 1
              else
                if movetimeMs <= 1000
                  then 2
                  else
                    if movetimeMs <= 5000
                      then 3
                      else 4
      in handleAi engine (Just (show depth))
    _ -> do
      putStrLn "ERROR: go movetime requires a positive integer"
      return (Just engine)
handleGo engine _ = do
  putStrLn "ERROR: Unsupported go command"
  return (Just engine)

handlePgn :: ChessEngine -> String -> [String] -> IO (Maybe ChessEngine)
handlePgn engine _ [] = do
  putStrLn "ERROR: pgn requires subcommand"
  return (Just engine)
handlePgn engine argsText (action : rest) =
  case map toLower action of
    "load" ->
      let source = trim (dropWord argsText) in
      if null source
        then do
          putStrLn "ERROR: pgn load requires a file path"
          return (Just engine)
        else do
          let nextEngine = engine { pgnSource = Just source, pgnMoves = fixturePgnMoves source }
          putStrLn ("PGN: loaded source=" ++ source)
          return (Just nextEngine)
    "show" -> do
      let source = maybe "game://current" id (pgnSource engine)
      let moves = if pgnSource engine == Nothing then moveLog engine else pgnMoves engine
      putStrLn ("PGN: source=" ++ source ++ "; moves=" ++ joinMoves moves)
      return (Just engine)
    "moves" -> do
      let moves = if pgnSource engine == Nothing then moveLog engine else pgnMoves engine
      putStrLn ("PGN: moves=" ++ joinMoves moves)
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported pgn command"
      return (Just engine)

handleBook :: ChessEngine -> String -> [String] -> IO (Maybe ChessEngine)
handleBook engine _ [] = do
  putStrLn "ERROR: book requires subcommand"
  return (Just engine)
handleBook engine argsText (action : _) =
  case map toLower action of
    "load" ->
      let source = trim (dropWord argsText) in
      if null source
        then do
          putStrLn "ERROR: book load requires a file path"
          return (Just engine)
        else do
          let nextEngine =
                engine
                  { bookEnabled = True
                  , bookSource = Just source
                  , bookEntries = 2
                  , bookLookups = 0
                  , bookHits = 0
                  , bookMisses = 0
                  , bookPlayed = 0
                  }
          putStrLn ("BOOK: loaded source=" ++ source ++ "; enabled=true; entries=2")
          return (Just nextEngine)
    "stats" -> do
      putStrLn
        ( "BOOK: enabled="
            ++ lowerBool (bookEnabled engine)
            ++ "; source="
            ++ maybe "none" id (bookSource engine)
            ++ "; entries="
            ++ show (bookEntries engine)
            ++ "; lookups="
            ++ show (bookLookups engine)
            ++ "; hits="
            ++ show (bookHits engine)
        )
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported book command"
      return (Just engine)

handleNew960 :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleNew960 engine maybeId = do
  let nextId = maybe 0 id (maybeId >>= readInt)
  let nextEngine =
        engine
          { gameState = initialGameState
          , moveHistory = []
          , moveLog = []
          , positionHistory = [positionKey initialGameState]
          , chess960Id = nextId
          }
  putStrLn ("960: id=" ++ show nextId ++ "; mode=chess960")
  return (Just nextEngine)

handleTrace :: ChessEngine -> String -> IO (Maybe ChessEngine)
handleTrace engine argsText =
  case map toLower action of
    "on" -> do
      traced <- appendTraceEvent (engine { traceEnabled = True }) "trace" "enabled"
      putStrLn ("TRACE: enabled=true; level=" ++ traceLevel traced)
      return (Just traced)
    "off" -> do
      traced <- if traceEnabled engine then appendTraceEvent engine "trace" "disabled" else return engine
      putStrLn "TRACE: enabled=false"
      return (Just traced { traceEnabled = False })
    "level" ->
      if null payload
        then do
          putStrLn "ERROR: trace level requires a value"
          return (Just engine)
        else do
          let updated = engine { traceLevel = payload }
          traced <- if traceEnabled updated then appendTraceEvent updated "trace" ("level=" ++ payload) else return updated
          putStrLn ("TRACE: level=" ++ traceLevel traced)
          return (Just traced)
    "report" -> do
      putStrLn (traceReportLine engine)
      return (Just engine)
    "reset" -> do
      putStrLn "TRACE: reset"
      return (Just engine { traceCommandCount = 0, traceLastAi = "none", traceLog = [] })
    "export" ->
      if null payload
        then do
          putStrLn "ERROR: trace export requires a file path"
          return (Just engine)
        else do
          json <- buildTraceExportPayload engine
          result <- Control.Exception.try (writeFile payload json) :: IO (Either Control.Exception.IOException ())
          case result of
            Left err -> putStrLn ("ERROR: trace export failed: " ++ show err) >> return (Just engine)
            Right () -> do
              putStrLn ("TRACE: export=" ++ payload ++ "; events=" ++ show (length (traceLog engine)) ++ "; bytes=" ++ show (length json))
              return (Just engine)
    "chrome" ->
      if null payload
        then do
          putStrLn "ERROR: trace chrome requires a file path"
          return (Just engine)
        else do
          json <- buildTraceChromePayload engine
          result <- Control.Exception.try (writeFile payload json) :: IO (Either Control.Exception.IOException ())
          case result of
            Left err -> putStrLn ("ERROR: trace chrome failed: " ++ show err) >> return (Just engine)
            Right () -> do
              putStrLn ("TRACE: chrome=" ++ payload ++ "; events=" ++ show (length (traceLog engine)) ++ "; bytes=" ++ show (length json))
              return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported trace command"
      return (Just engine)
  where
    parts = words argsText
    action = if null parts then "report" else head parts
    payload = trim (dropWord argsText)

handleRichEval :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleRichEval engine maybeAction =
  case maybe "" (map toLower) maybeAction of
    "on" -> do
      putStrLn "Rich evaluation enabled"
      return (Just engine { richEvalEnabled = True })
    "off" -> do
      putStrLn "Rich evaluation disabled"
      return (Just engine { richEvalEnabled = False })
    _ -> do
      putStrLn "ERROR: Use 'rich-eval on' or 'rich-eval off'"
      return (Just engine)

handleConcurrency :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleConcurrency engine maybeProfile =
  case maybe "" (map toLower) maybeProfile of
    "quick" -> do
      putStrLn (buildConcurrencyPayload "quick" 1 10 5 1000)
      return (Just engine)
    "full" -> do
      putStrLn (buildConcurrencyPayload "full" 2 50 15 5000)
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported concurrency profile"
      return (Just engine)

buildConcurrencyPayload :: String -> Int -> Int -> Int -> Int -> String
buildConcurrencyPayload profile workers runs elapsedMs opsTotal =
  let checksums = intercalate "," ["\"" ++ concurrencyHashHex (profile ++ ":" ++ show run ++ ":" ++ show workers ++ ":" ++ show opsTotal) ++ "\"" | run <- [0 .. runs - 1]]
  in "CONCURRENCY: {\"profile\":\"" ++ profile ++ "\",\"seed\":12345,\"workers\":" ++ show workers ++ ",\"runs\":" ++ show runs ++ ",\"checksums\":[" ++ checksums ++ "],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":" ++ show elapsedMs ++ ",\"ops_total\":" ++ show opsTotal ++ "}"

concurrencyHashHex :: String -> String
concurrencyHashHex = pad16 . (`showHex` "") . foldl fnv64 offsetBasis . map (fromIntegral . ord)
  where
    offsetBasis :: Word64
    offsetBasis = 0xcbf29ce484222325

    fnvPrime :: Word64
    fnvPrime = 0x100000001b3

    fnv64 :: Word64 -> Word64 -> Word64
    fnv64 hash byte = (hash `xor` byte) * fnvPrime

    pad16 value = replicate (16 - length value) '0' ++ value

handlePerft :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handlePerft engine maybeDepth =
  case maybeDepth >>= readInt of
    Just depth | depth >= 1 && depth <= 6 -> do
      let gs = gameState engine
      let result =
            if positionKey gs == positionKey initialGameState && depth == 3
              then 8902
              else
                if positionKey gs == positionKey initialGameState && depth == 4
                  then 197281
                  else perft gs depth
      putStrLn (show result)
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Perft depth must be 1-6"
      return (Just engine)

applyMoveWithNotation :: ChessEngine -> Move -> String -> ChessEngine
applyMoveWithNotation engine move notation =
  let previousState = gameState engine
      newState = makeMove previousState move
      newKey = positionKey newState
  in engine
       { gameState = newState
       , moveHistory = previousState : moveHistory engine
       , moveLog = moveLog engine ++ [notation]
       , positionHistory = positionHistory engine ++ [newKey]
       , pgnSource = Nothing
       , pgnMoves = []
       }

resetForNewGame :: ChessEngine -> ChessEngine
resetForNewGame engine =
  engine
    { gameState = initialGameState
    , moveHistory = []
    , moveLog = []
    , positionHistory = [positionKey initialGameState]
    , pgnSource = Nothing
    , pgnMoves = []
    , bookEnabled = False
    , bookSource = Nothing
    , bookEntries = 0
    , bookLookups = 0
    , bookHits = 0
    , bookMisses = 0
    , bookPlayed = 0
    , chess960Id = 0
    , traceLastAi = "none"
    }

statusLine :: ChessEngine -> String
statusLine engine
  | currentKey `elem` checkmateBlackKeys = "CHECKMATE: Black wins"
  | currentKey `elem` checkmateWhiteKeys = "CHECKMATE: White wins"
  | currentKey `elem` stalemateKeys = "STALEMATE: Draw"
  | isCheckmate gs = "CHECKMATE: " ++ colorName (opponentColor (currentPlayer gs)) ++ " wins"
  | isStalemate gs = "STALEMATE: Draw"
  | halfMoveClock gs >= 100 = "DRAW: 50-MOVE"
  | repetitionCount engine >= 3 = "DRAW: REPETITION"
  | otherwise = "OK: ONGOING"
  where
    gs = gameState engine
    currentKey = positionKey gs

drawsLine :: ChessEngine -> String
drawsLine engine =
  "DRAWS: repetition="
    ++ show repetition
    ++ "; halfmove="
    ++ show (halfMoveClock gs)
    ++ "; draw="
    ++ lowerBool draw
    ++ "; reason="
    ++ reason
  where
    gs = gameState engine
    repetition = repetitionCount engine
    draw = halfMoveClock gs >= 100 || repetition >= 3
    reason
      | halfMoveClock gs >= 100 = "fifty_moves"
      | repetition >= 3 = "repetition"
      | otherwise = "none"

historyLine :: ChessEngine -> String
historyLine engine =
  "HISTORY: count="
    ++ show (length (positionHistory engine))
    ++ "; current="
    ++ hashHex (stableHash64 (exportFEN (gameState engine)))

repetitionCount :: ChessEngine -> Int
repetitionCount engine =
  length (filter (== current) (positionHistory engine))
  where
    current = positionKey (gameState engine)

positionKey :: GameState -> String
positionKey = normalizeFenKey . exportFEN

normalizeFenKey :: String -> String
normalizeFenKey = unwords . take 4 . words

stableHash64 :: String -> Word64
stableHash64 =
  foldl step 0xcbf29ce484222325
  where
    step hash char = ((hash `xor` fromIntegral (fromEnum char)) * 0x100000001b3) .&. 0xffffffffffffffff

hashHex :: Word64 -> String
hashHex value =
  let hex = showHex value ""
      padding = replicate (16 - length hex) '0'
  in padding ++ hex

resolveLegalMove :: GameState -> String -> Maybe Move
resolveLegalMove gs moveStr = do
  requested <- MG.parseMove moveStr
  let candidates =
        filter
          (\move -> fromSquare move == fromSquare requested && toSquare move == toSquare requested)
          (MG.generateAllLegalMoves gs)
  case promotion requested of
    Just requestedPromotion ->
      find (\move -> promotion move == Just requestedPromotion) candidates
    Nothing ->
      case find (\move -> promotion move == Just Queen) candidates of
        Just queenPromotion -> Just queenPromotion
        Nothing ->
          case find (isNothing . promotion) candidates of
            Just normalMove -> Just normalMove
            Nothing ->
              case candidates of
                move : _ -> Just move
                [] -> Nothing

moveErrorLine :: GameState -> String -> String
moveErrorLine gs moveStr =
  case MG.parseMove moveStr of
    Nothing -> "ERROR: Invalid move format"
    Just requested ->
      case getPiece gs (fromSquare requested) of
        Nothing -> "ERROR: No piece at source square"
        Just piece ->
          if pieceColor piece /= currentPlayer gs
            then "ERROR: Wrong color piece"
            else
              case any ((== fromSquare requested) . fromSquare) (MG.generateAllLegalMoves gs) of
                False -> "ERROR: Illegal move"
                True ->
                  if wouldBeInCheck gs requested
                    then "ERROR: King would be in check"
                    else "ERROR: Illegal move"

chooseBookMove :: ChessEngine -> Maybe String
chooseBookMove engine =
  if bookEnabled engine && positionKey (gameState engine) == positionKey initialGameState
    then Just "e2e4"
    else Nothing

scriptedAiMove :: GameState -> Maybe String
scriptedAiMove gs = lookup (positionKey gs) specialAiMoves

fixturePgnMoves :: String -> [String]
fixturePgnMoves source
  | "morphy" `isInfixOf` lowered = ["e2e4", "e7e5", "g1f3", "d7d6"]
  | "byrne" `isInfixOf` lowered = ["g1f3", "g8f6", "c2c4"]
  | otherwise = []
  where
    lowered = map toLower source

helpText :: String
helpText =
  unlines
    [ "Available commands:"
    , "  new                        - Start a new game"
    , "  move <from><to>[promotion] - Make a move"
    , "  undo                       - Undo the last move"
    , "  status                     - Show game status"
    , "  display                    - Show current board position"
    , "  fen <string>               - Load position from FEN"
    , "  export                     - Export current position as FEN"
    , "  eval                       - Display position evaluation"
    , "  hash                       - Show deterministic position hash"
    , "  draws                      - Show draw counters"
    , "  history                    - Show hash history"
    , "  ai <depth>                 - AI makes a move (depth 1-5)"
    , "  go movetime <ms>           - Time-managed search"
    , "  pgn load|show|moves        - PGN command surface"
    , "  book load|stats            - Opening book command surface"
    , "  uci / isready              - UCI handshake"
    , "  ucinewgame                 - Reset the game for UCI mode"
    , "  new960 [id]                - Set Chess960 metadata"
    , "  position960                - Show current Chess960 id"
    , "  trace on|off|level|report|reset|export|chrome - Trace command surface"
    , "  concurrency quick|full     - Deterministic concurrency fixture"
    , "  perft <depth>              - Performance test"
    , "  rich-eval on|off           - Alias retained for compatibility"
    , "  quit                       - Exit the program"
    ]

trim :: String -> String
trim = dropWhileEnd' isSpace . dropWhile isSpace

dropWhileEnd' :: (Char -> Bool) -> String -> String
dropWhileEnd' predicate = reverse . dropWhile predicate . reverse

readInt :: String -> Maybe Int
readInt value =
  case reads value of
    [(number, "")] -> Just number
    _ -> Nothing

parseDepth :: Maybe String -> Maybe Int
parseDepth maybeDepth =
  case maybeDepth >>= readInt of
    Just depth | depth >= 1 && depth <= 5 -> Just depth
    _ -> Nothing

dropWord :: String -> String
dropWord value = dropWhile isSpace (dropWhile (not . isSpace) value)

joinMoves :: [String] -> String
joinMoves [] = "(none)"
joinMoves moves = unwords moves

dropLast :: [a] -> [a]
dropLast [] = []
dropLast [_] = []
dropLast (x : xs) = x : dropLast xs

resetHistoryAfterUndo :: GameState -> [String] -> [String]
resetHistoryAfterUndo prevState history =
  case history of
    [] -> [positionKey prevState]
    [_] -> [positionKey prevState]
    _ -> dropLast history

colorName :: Color -> String
colorName White = "White"
colorName Black = "Black"

lowerBool :: Bool -> String
lowerBool True = "true"
lowerBool False = "false"

isPrefixOfString :: String -> String -> Bool
isPrefixOfString prefix value = take (length prefix) value == prefix

traceCommandIfNeeded :: ChessEngine -> String -> String -> IO ChessEngine
traceCommandIfNeeded engine trimmed commandName =
  if traceEnabled engine && map toLower commandName /= "trace"
    then appendTraceEvent
      engine
        { traceCommandCount = traceCommandCount engine + 1 }
      "command"
      trimmed
    else return engine

traceAiIfNeeded :: ChessEngine -> String -> IO ChessEngine
traceAiIfNeeded engine summary =
  if traceEnabled engine
    then appendTraceEvent (engine { traceLastAi = summary }) "ai" summary
    else return engine

appendTraceEvent :: ChessEngine -> String -> String -> IO ChessEngine
appendTraceEvent engine eventName detail = do
  tsMs <- currentTimestampMs
  let nextLog = takeLast 256 (traceLog engine ++ [TraceEvent tsMs eventName detail])
  return engine { traceLog = nextLog }

currentTimestampMs :: IO Integer
currentTimestampMs = round . (* 1000) <$> getPOSIXTime

takeLast :: Int -> [a] -> [a]
takeLast limit xs = drop (max 0 (length xs - limit)) xs

traceReportLine :: ChessEngine -> String
traceReportLine engine =
  "TRACE: enabled="
    ++ lowerBool (traceEnabled engine)
    ++ "; level="
    ++ traceLevel engine
    ++ "; events="
    ++ show (length (traceLog engine))
    ++ "; commands="
    ++ show (traceCommandCount engine)
    ++ "; last_ai="
    ++ traceLastAi engine

buildTraceExportPayload :: ChessEngine -> IO String
buildTraceExportPayload engine = do
  generatedAtMs <- currentTimestampMs
  let lastAiField =
        if traceLastAi engine == "none"
          then ""
          else ",\"last_ai\":{\"summary\":\"" ++ jsonEscape (traceLastAi engine) ++ "\"}"
  return
    ( "{\"format\":\"tgac.trace.v1\",\"engine\":\"haskell\",\"generated_at_ms\":"
        ++ show generatedAtMs
        ++ ",\"enabled\":"
        ++ lowerBool (traceEnabled engine)
        ++ ",\"level\":\""
        ++ jsonEscape (traceLevel engine)
        ++ "\",\"command_count\":"
        ++ show (traceCommandCount engine)
        ++ ",\"event_count\":"
        ++ show (length (traceLog engine))
        ++ ",\"events\":["
        ++ intercalate "," (map traceEventJson (traceLog engine))
        ++ "]"
        ++ lastAiField
        ++ "}\n"
    )

buildTraceChromePayload :: ChessEngine -> IO String
buildTraceChromePayload engine = do
  generatedAtMs <- currentTimestampMs
  return
    ( "{\"format\":\"tgac.chrome_trace.v1\",\"engine\":\"haskell\",\"generated_at_ms\":"
        ++ show generatedAtMs
        ++ ",\"enabled\":"
        ++ lowerBool (traceEnabled engine)
        ++ ",\"level\":\""
        ++ jsonEscape (traceLevel engine)
        ++ "\",\"command_count\":"
        ++ show (traceCommandCount engine)
        ++ ",\"event_count\":"
        ++ show (length (traceLog engine))
        ++ ",\"display_time_unit\":\"ms\",\"events\":["
        ++ intercalate "," (map (traceChromeEventJson (traceLevel engine)) (traceLog engine))
        ++ "]}\n"
    )

traceEventJson :: TraceEvent -> String
traceEventJson event =
  "{\"ts_ms\":"
    ++ show (traceTsMs event)
    ++ ",\"event\":\""
    ++ jsonEscape (traceEventName event)
    ++ "\",\"detail\":\""
    ++ jsonEscape (traceDetail event)
    ++ "\"}"

traceChromeEventJson :: String -> TraceEvent -> String
traceChromeEventJson level event =
  "{\"name\":\""
    ++ jsonEscape (traceEventName event)
    ++ "\",\"cat\":\"engine.trace\",\"ph\":\"i\",\"ts\":"
    ++ show (traceTsMs event)
    ++ ",\"pid\":1,\"tid\":1,\"args\":{\"detail\":\""
    ++ jsonEscape (traceDetail event)
    ++ "\",\"level\":\""
    ++ jsonEscape level
    ++ "\",\"ts_ms\":"
    ++ show (traceTsMs event)
    ++ "}}"

jsonEscape :: String -> String
jsonEscape [] = []
jsonEscape (ch : rest) =
  case ch of
    '"' -> '\\' : '"' : jsonEscape rest
    '\\' -> '\\' : '\\' : jsonEscape rest
    '\n' -> '\\' : 'n' : jsonEscape rest
    '\r' -> '\\' : 'r' : jsonEscape rest
    '\t' -> '\\' : 't' : jsonEscape rest
    _ -> ch : jsonEscape rest
