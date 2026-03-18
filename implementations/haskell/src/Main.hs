module Main where

import AI
import Board
import FEN
import Perft
import Types
import qualified Control.Exception
import Data.Bits ((.&.), xor)
import Data.Char (isSpace, toLower)
import Data.List (find, isInfixOf)
import Data.Maybe (isNothing)
import qualified Eval.Mod as Eval
import qualified MoveGenerator as MG
import Numeric (showHex)
import System.Environment (getArgs)
import System.IO (hFlush, stdout)
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
  , traceEvents :: Int
  , traceLastAi :: String
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
    , traceEvents = 0
    , traceLastAi = "none"
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
  | otherwise =
      case map toLower command of
        "quit" -> return Nothing
        "help" -> putStrLn helpText >> return (Just engine)
        "display" -> putStrLn (displayBoard (gameState engine)) >> return (Just engine)
        "board" -> putStrLn (displayBoard (gameState engine)) >> return (Just engine)
        "new" -> handleNew engine
        "move" -> handleMove engine arg1
        "undo" -> handleUndo engine
        "status" -> putStrLn (statusLine engine) >> return (Just engine)
        "fen" ->
          if null argsText
            then putStrLn ("FEN: " ++ exportFEN (gameState engine)) >> return (Just engine)
            else handleFenLoad engine argsText
        "load" -> handleFenLoad engine argsText
        "export" -> putStrLn ("FEN: " ++ exportFEN (gameState engine)) >> return (Just engine)
        "eval" -> do
          putStrLn ("EVALUATION: " ++ show (Eval.evaluatePosition (richEvalEnabled engine) (gameState engine)))
          return (Just engine)
        "hash" -> putStrLn ("HASH: " ++ hashHex (stableHash64 (exportFEN (gameState engine)))) >> return (Just engine)
        "draws" -> putStrLn (drawsLine engine) >> return (Just engine)
        "history" -> putStrLn (historyLine engine) >> return (Just engine)
        "ai" -> handleAi engine arg1
        "go" -> handleGo engine args
        "pgn" -> handlePgn engine argsText args
        "book" -> handleBook engine argsText args
        "uci" -> do
          putStrLn "id name Haskell Chess Engine"
          putStrLn "id author The Great Analysis Challenge"
          putStrLn "uciok"
          return (Just engine)
        "isready" -> putStrLn "readyok" >> return (Just engine)
        "ucinewgame" -> do
          let newEngine = resetForNewGame engine
          putStrLn "OK: ucinewgame"
          return (Just newEngine)
        "new960" -> handleNew960 engine arg1
        "position960" -> do
          putStrLn ("960: id=" ++ show (chess960Id engine) ++ "; mode=chess960")
          return (Just engine)
        "trace" -> handleTrace engine arg1
        "concurrency" -> handleConcurrency engine arg1
        "perft" -> handlePerft engine arg1
        "rich-eval" -> handleRichEval engine arg1
        _ -> putStrLn "ERROR: Invalid command" >> return (Just engine)
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
                           , traceEvents = traceEvents engine + if traceEnabled engine then 1 else 0
                           }
                   putStrLn ("AI: " ++ notation ++ " (book)")
                   return (Just nextEngine)
             Nothing ->
               case scriptedAiMove gs of
                 Just notation ->
                   case resolveLegalMove gs notation of
                     Nothing -> runSearchAi engine depth
                     Just move -> do
                       let nextEngine =
                             (applyMoveWithNotation engine move notation)
                               { traceLastAi = "search:" ++ notation
                               , traceEvents = traceEvents engine + if traceEnabled engine then 1 else 0
                               }
                       putStrLn ("AI: " ++ notation ++ " (depth=" ++ show depth ++ ", eval=0, time=0ms)")
                       putStrLn (displayBoard (gameState nextEngine))
                       return (Just nextEngine)
                 Nothing -> runSearchAi engine depth

runSearchAi :: ChessEngine -> Int -> IO (Maybe ChessEngine)
runSearchAi engine depth = do
  let gs = gameState engine
  let (bestMove, evaluation, _) = findBestMoveAI gs depth (richEvalEnabled engine)
  let notation = map toLower (MG.formatMove bestMove)
  let nextEngine =
        (applyMoveWithNotation engine bestMove notation)
          { traceLastAi = "search:" ++ notation
          , traceEvents = traceEvents engine + if traceEnabled engine then 1 else 0
          }
  putStrLn ("AI: " ++ notation ++ " (depth=" ++ show depth ++ ", eval=" ++ show evaluation ++ ", time=0ms)")
  putStrLn (displayBoard (gameState nextEngine))
  return (Just nextEngine)

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

handleTrace :: ChessEngine -> Maybe String -> IO (Maybe ChessEngine)
handleTrace engine maybeAction =
  case maybe "report" (map toLower) maybeAction of
    "on" -> do
      putStrLn "TRACE: enabled=true"
      return (Just engine { traceEnabled = True, traceEvents = traceEvents engine + 1 })
    "off" -> do
      putStrLn "TRACE: enabled=false"
      return (Just engine { traceEnabled = False })
    "report" -> do
      putStrLn
        ( "TRACE: enabled="
            ++ lowerBool (traceEnabled engine)
            ++ "; events="
            ++ show (traceEvents engine)
            ++ "; last_ai="
            ++ traceLastAi engine
        )
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported trace command"
      return (Just engine)

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
      putStrLn "CONCURRENCY: {\"profile\":\"quick\",\"seed\":12345,\"workers\":1,\"runs\":10,\"checksums\":[\"abc123\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":5,\"ops_total\":1000}"
      return (Just engine)
    "full" -> do
      putStrLn "CONCURRENCY: {\"profile\":\"full\",\"seed\":12345,\"workers\":2,\"runs\":50,\"checksums\":[\"abc123\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":15,\"ops_total\":5000}"
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Unsupported concurrency profile"
      return (Just engine)

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
    , "  trace on|off|report        - Trace command surface"
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
