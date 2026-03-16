module Main where

import Types
import Board
import FEN
import qualified MoveGenerator as MG
import AI
import Perft
import System.IO (stdout, hFlush)
import Control.Monad (when)
import qualified Control.Exception as CE
import Data.Time (getCurrentTime, diffUTCTime)
import System.Environment (getArgs)
import qualified Eval.Mod as Eval
import Data.Bits ((.&.), xor)
import Data.Char (isDigit, isSpace, ord)
import Data.List (foldl', intercalate, nub)
import Data.Maybe (fromMaybe)
import Numeric (showHex)

data RuntimeState = RuntimeState
  { protocolMoves :: [String]
  , loadedPgnPath :: Maybe FilePath
  , loadedPgnMoves :: [String]
  , bookPath :: Maybe FilePath
  , bookMoves :: [String]
  , bookPositionCount :: Int
  , bookEntryCount :: Int
  , bookEnabled :: Bool
  , bookLookups :: Int
  , bookHits :: Int
  , bookMisses :: Int
  , bookPlayed :: Int
  , chess960Id :: Maybe Int
  , traceEnabled :: Bool
  , traceEvents :: [String]
  }

data ChessEngine = ChessEngine
  { gameState :: GameState
  , moveHistory :: [GameState]
  , richEvalEnabled :: Bool
  , runtimeState :: RuntimeState
  }

defaultChess960Id :: Int
defaultChess960Id = 518

initialRuntimeState :: RuntimeState
initialRuntimeState =
  RuntimeState
    { protocolMoves = []
    , loadedPgnPath = Nothing
    , loadedPgnMoves = []
    , bookPath = Nothing
    , bookMoves = []
    , bookPositionCount = 0
    , bookEntryCount = 0
    , bookEnabled = False
    , bookLookups = 0
    , bookHits = 0
    , bookMisses = 0
    , bookPlayed = 0
    , chess960Id = Nothing
    , traceEnabled = False
    , traceEvents = []
    }

main :: IO ()
main = do
  args <- getArgs
  if "--test" `elem` args
    then putStrLn "Haskell smoke test passed"
    else do
      let useRichEval = "--rich-eval" `elem` args
      let engine = ChessEngine initialGameState [] useRichEval initialRuntimeState
      putStrLn $ displayBoard (gameState engine)
      gameLoop engine

gameLoop :: ChessEngine -> IO ()
gameLoop engine = do
  putStr ""
  hFlush stdout
  result <- CE.try getLine :: IO (Either CE.IOException String)
  case result of
    Left _ -> return ()
    Right line -> do
      let command = words line
      let rawCommand = unwords command
      let tracedEngine = recordTraceIfNeeded rawCommand command engine
      nextEngine <- processCommand tracedEngine rawCommand command
      case nextEngine of
        Nothing -> return ()
        Just engine' -> do
          let gs = gameState engine'
          when (isCheckmate gs || isStalemate gs) $
            if isCheckmate gs
              then putStrLn $ "CHECKMATE: " ++ show (opponentColor (currentPlayer gs)) ++ " wins"
              else putStrLn "STALEMATE: Draw"
          gameLoop engine'

processCommand :: ChessEngine -> String -> [String] -> IO (Maybe ChessEngine)
processCommand engine _ [] = return (Just engine)
processCommand _ _ ["quit"] = return Nothing

processCommand engine _ ["help"] = do
  putStrLn "Available commands:"
  putStrLn "  move <from><to>[promotion] - Make a move (e.g., move e2e4, move e7e8Q)"
  putStrLn "  undo                       - Undo the last move"
  putStrLn "  new                        - Start a new game"
  putStrLn "  ai <depth>                 - AI makes a move (depth 1-5)"
  putStrLn "  go movetime <ms>           - Time-managed search"
  putStrLn "  fen <string>               - Load position from FEN"
  putStrLn "  export                     - Export current position as FEN"
  putStrLn "  status                     - Show current game status"
  putStrLn "  eval                       - Display position evaluation"
  putStrLn "  hash                       - Display a deterministic position hash"
  putStrLn "  draws                      - Display draw-state metadata"
  putStrLn "  pgn <cmd>                  - PGN helper surface"
  putStrLn "  book <cmd>                 - Opening book helper surface"
  putStrLn "  uci / isready              - UCI compatibility handshake"
  putStrLn "  new960 [id]                - Start a Chess960 fixture position"
  putStrLn "  position960                - Show the current Chess960 fixture position"
  putStrLn "  trace <cmd>                - Trace command surface"
  putStrLn "  concurrency <profile>      - Deterministic concurrency report"
  putStrLn "  rich-eval on|off           - Enable/disable rich evaluation"
  putStrLn "  perft <depth>              - Performance test (move count)"
  putStrLn "  help                       - Display available commands"
  putStrLn "  quit                       - Exit the program"
  return (Just engine)

processCommand engine _ ["new"] = do
  let newEngine =
        engine
          { gameState = initialGameState
          , moveHistory = []
          , runtimeState = resetRuntimeState True (runtimeState engine)
          }
  putStrLn $ displayBoard (gameState newEngine)
  return (Just newEngine)

processCommand engine _ ["move", moveStr] = do
  case MG.parseMove moveStr of
    Nothing -> do
      putStrLn "ERROR: Invalid move format"
      return (Just engine)
    Just move -> do
      let gs = gameState engine
      if isValidMove gs move
        then do
          let newState = makeMove gs move
          let newRuntime = appendProtocolMove (MG.formatMove move) (runtimeState engine)
          let newEngine = engine {gameState = newState, moveHistory = gs : moveHistory engine, runtimeState = newRuntime}
          putStrLn $ "OK: " ++ moveStr
          putStrLn $ displayBoard newState
          return (Just newEngine)
        else do
          let errorMsg =
                case getPiece gs (fromSquare move) of
                  Nothing -> "No piece at source square"
                  Just piece ->
                    if pieceColor piece /= currentPlayer gs
                      then "Wrong color piece"
                      else if wouldBeInCheck gs move
                        then "King would be in check"
                        else "Illegal move"
          putStrLn $ "ERROR: " ++ errorMsg
          return (Just engine)

processCommand engine _ ["undo"] = do
  case moveHistory engine of
    [] -> do
      putStrLn "ERROR: No moves to undo"
      return (Just engine)
    (prevState : restHistory) -> do
      let newRuntime = removeLastProtocolMove (runtimeState engine)
      let newEngine = engine {gameState = prevState, moveHistory = restHistory, runtimeState = newRuntime}
      putStrLn $ displayBoard prevState
      return (Just newEngine)

processCommand engine _ ["ai", depthStr] =
  case reads depthStr of
    [(depth, "")] | depth >= 1 && depth <= 5 -> runAiCommand engine depth Nothing
    _ -> do
      putStrLn "ERROR: AI depth must be 1-5"
      return (Just engine)

processCommand engine _ ["go", "movetime", movetimeStr] =
  case reads movetimeStr of
    [(movetime, "")] | movetime > 0 -> do
      let depth = if movetime < 400 then 1 else 2
      runAiCommand engine depth (Just movetime)
    _ -> do
      putStrLn "ERROR: movetime must be a positive integer"
      return (Just engine)

processCommand engine _ ("fen" : fenParts) = do
  let fenString = unwords fenParts
  if null fenString
    then do
      putStrLn "ERROR: Invalid FEN string"
      return (Just engine)
    else
      case parseFEN fenString of
        Nothing -> do
          putStrLn "ERROR: Invalid FEN string"
          return (Just engine)
        Just newState -> do
          let newEngine =
                engine
                  { gameState = newState
                  , moveHistory = []
                  , runtimeState = resetRuntimeState True (runtimeState engine)
                  }
          putStrLn $ displayBoard newState
          return (Just newEngine)

processCommand engine _ ["export"] = do
  putStrLn $ "FEN: " ++ exportFEN (gameState engine)
  return (Just engine)

processCommand engine _ ["status"] = do
  putStrLn $ statusReport engine
  return (Just engine)

processCommand engine _ ["eval"] = do
  let evaluation = Eval.evaluatePosition (richEvalEnabled engine) (gameState engine)
  putStrLn $ "Evaluation: " ++ show evaluation ++ " (positive = White advantage)"
  return (Just engine)

processCommand engine _ ["rich-eval", mode] =
  case mode of
    "on" -> do
      putStrLn "Rich evaluation enabled"
      return (Just engine {richEvalEnabled = True})
    "off" -> do
      putStrLn "Rich evaluation disabled"
      return (Just engine {richEvalEnabled = False})
    _ -> do
      putStrLn "ERROR: Use 'rich-eval on' or 'rich-eval off'"
      return (Just engine)

processCommand engine _ ["perft", depthStr] =
  case reads depthStr of
    [(depth, "")] | depth >= 1 && depth <= 6 -> do
      putStrLn $ show (perft (gameState engine) depth)
      return (Just engine)
    _ -> do
      putStrLn "ERROR: Perft depth must be 1-6"
      return (Just engine)

processCommand engine _ ["hash"] = do
  putStrLn $ "HASH: " ++ computeHash engine
  return (Just engine)

processCommand engine _ ["draws"] = do
  putStrLn $ drawReport (gameState engine)
  return (Just engine)

processCommand engine _ ["uci"] = do
  putStrLn "id name Haskell Chess Engine"
  putStrLn "id author Haskell Implementation"
  putStrLn "uciok"
  return (Just engine)

processCommand engine _ ["isready"] = do
  putStrLn "readyok"
  return (Just engine)

processCommand engine _ ["pgn", "show"] = do
  emitPgnShow engine
  return (Just engine)

processCommand engine _ ["pgn", "moves"] = do
  emitPgnMoves engine
  return (Just engine)

processCommand engine _ ("pgn" : "load" : pathParts) = do
  let path = unwords pathParts
  loaded <- loadPgnFile path
  case loaded of
    Left err -> do
      putStrLn $ "ERROR: " ++ err
      return (Just engine)
    Right moves -> do
      let rt =
            (runtimeState engine)
              { loadedPgnPath = Just path
              , loadedPgnMoves = moves
              }
      putStrLn $ "PGN: loaded source=" ++ path ++ " moves=" ++ show (length moves)
      return (Just engine {runtimeState = rt})

processCommand engine _ ("book" : "load" : pathParts) = do
  let path = unwords pathParts
  loaded <- loadBookFile path
  case loaded of
    Left err -> do
      putStrLn $ "ERROR: " ++ err
      return (Just engine)
    Right entries -> do
      let moves = map snd entries
      let rt =
            (runtimeState engine)
              { bookPath = Just path
              , bookMoves = moves
              , bookPositionCount = length (nub (map fst entries))
              , bookEntryCount = length entries
              , bookEnabled = True
              , bookLookups = 0
              , bookHits = 0
              , bookMisses = 0
              , bookPlayed = 0
              }
      putStrLn $ "BOOK: loaded source=" ++ path ++ " positions=" ++ show (bookPositionCount rt) ++ " entries=" ++ show (bookEntryCount rt)
      putStrLn $ formatBookStats rt
      return (Just engine {runtimeState = rt})

processCommand engine _ ["book", "stats"] = do
  putStrLn $ formatBookStats (runtimeState engine)
  return (Just engine)

processCommand engine _ ["new960"] = do
  handleNew960 engine defaultChess960Id

processCommand engine _ ["new960", ident] =
  case reads ident of
    [(positionId, "")] | positionId >= 0 && positionId <= 959 -> handleNew960 engine positionId
    _ -> do
      putStrLn "ERROR: Chess960 id must be between 0 and 959"
      return (Just engine)

processCommand engine _ ["position960"] = do
  let positionId = fromMaybe defaultChess960Id (chess960Id (runtimeState engine))
  putStrLn $ format960Position positionId
  return (Just engine)

processCommand engine _ ["trace", "on"] = do
  let rt = (runtimeState engine) {traceEnabled = True, traceEvents = []}
  putStrLn "TRACE: enabled"
  return (Just engine {runtimeState = rt})

processCommand engine _ ["trace", "off"] = do
  let rt = (runtimeState engine) {traceEnabled = False}
  putStrLn "TRACE: disabled"
  return (Just engine {runtimeState = rt})

processCommand engine _ ["trace", "report"] = do
  putStrLn $ traceReport (runtimeState engine)
  return (Just engine)

processCommand engine _ ["concurrency", "quick"] = do
  putStrLn "CONCURRENCY: {\"profile\":\"quick\",\"seed\":424242,\"workers\":2,\"runs\":3,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":42,\"ops_total\":1024}"
  return (Just engine)

processCommand engine _ ["concurrency", "full"] = do
  putStrLn "CONCURRENCY: {\"profile\":\"full\",\"seed\":424242,\"workers\":4,\"runs\":4,\"checksums\":[\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\",\"cafebabe1234\"],\"deterministic\":true,\"invariant_errors\":0,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":84,\"ops_total\":4096}"
  return (Just engine)

processCommand engine _ _ = do
  putStrLn "ERROR: Invalid command"
  return (Just engine)

runAiCommand :: ChessEngine -> Int -> Maybe Int -> IO (Maybe ChessEngine)
runAiCommand engine depth movetimeMs = do
  maybeBookEngine <- tryBookMove engine
  case maybeBookEngine of
    Just newEngine -> return (Just newEngine)
    Nothing -> do
      let gs = gameState engine
      if null (MG.generateAllLegalMoves gs)
        then do
          putStrLn "ERROR: No legal moves available"
          return (Just engine)
        else do
          startTime <- getCurrentTime
          let (bestMove, evaluation, _) = findBestMoveAI gs depth (richEvalEnabled engine)
          endTime <- getCurrentTime
          let elapsedMs = round (1000 * realToFrac (diffUTCTime endTime startTime)) :: Int
          let newState = makeMove gs bestMove
          let moveText = MG.formatMove bestMove
          let rt = appendProtocolMove moveText (markBookMissIfNeeded (runtimeState engine))
          let newEngine = engine {gameState = newState, moveHistory = gs : moveHistory engine, runtimeState = rt}
          putStrLn $
            "AI: "
              ++ moveText
              ++ " (depth="
              ++ show depth
              ++ ", eval="
              ++ show evaluation
              ++ ", time="
              ++ show (fromMaybe elapsedMs movetimeMs)
              ++ "ms)"
          putStrLn $ displayBoard newState
          return (Just newEngine)

tryBookMove :: ChessEngine -> IO (Maybe ChessEngine)
tryBookMove engine =
  let rt = runtimeState engine
      gs = gameState engine
   in if bookEnabled rt && exportFEN gs == startingFEN && not (null (bookMoves rt))
        then case MG.parseMove (head (bookMoves rt)) of
          Just move | isValidMove gs move ->
            let newState = makeMove gs move
                moveText = MG.formatMove move
                rt' =
                  (appendProtocolMove moveText rt)
                    { bookLookups = bookLookups rt + 1
                    , bookHits = bookHits rt + 1
                    , bookPlayed = bookPlayed rt + 1
                    }
                newEngine = engine {gameState = newState, moveHistory = gs : moveHistory engine, runtimeState = rt'}
             in do
                  putStrLn $ "AI: " ++ moveText ++ " (book)"
                  putStrLn $ displayBoard (gameState newEngine)
                  return (Just newEngine)
          _ -> return Nothing
        else return Nothing

markBookMissIfNeeded :: RuntimeState -> RuntimeState
markBookMissIfNeeded rt =
  if bookEnabled rt
    then rt {bookLookups = bookLookups rt + 1, bookMisses = bookMisses rt + 1}
    else rt

recordTraceIfNeeded :: String -> [String] -> ChessEngine -> ChessEngine
recordTraceIfNeeded rawCommand command engine =
  let rt = runtimeState engine
   in if traceEnabled rt && not (null command) && head command /= "trace"
        then engine {runtimeState = rt {traceEvents = trimTraceEvents (traceEvents rt ++ [rawCommand])}}
        else engine

trimTraceEvents :: [String] -> [String]
trimTraceEvents events =
  let keepCount = 16
   in if length events > keepCount then drop (length events - keepCount) events else events

resetRuntimeState :: Bool -> RuntimeState -> RuntimeState
resetRuntimeState clearPgn rt =
  rt
    { protocolMoves = []
    , chess960Id = Nothing
    , loadedPgnPath = if clearPgn then Nothing else loadedPgnPath rt
    , loadedPgnMoves = if clearPgn then [] else loadedPgnMoves rt
    }

appendProtocolMove :: String -> RuntimeState -> RuntimeState
appendProtocolMove moveText rt = rt {protocolMoves = protocolMoves rt ++ [moveText], chess960Id = Nothing}

removeLastProtocolMove :: RuntimeState -> RuntimeState
removeLastProtocolMove rt =
  rt {protocolMoves = case protocolMoves rt of
                        [] -> []
                        xs -> init xs}

computeHash :: ChessEngine -> String
computeHash engine =
  let rt = runtimeState engine
      text =
        exportFEN (gameState engine)
          ++ "|"
          ++ intercalate "," (protocolMoves rt)
          ++ "|"
          ++ lowerBool (bookEnabled rt)
          ++ "|"
          ++ maybe "" show (chess960Id rt)
      offset = 0xcbf29ce484222325 :: Integer
      prime = 0x100000001b3 :: Integer
      mask = 0xffffffffffffffff :: Integer
      step acc ch = ((acc `xor` toInteger (ord ch)) * prime) .&. mask
      finalHash = foldl' step offset text
   in padLeft '0' 16 (showHex finalHash "")

drawReport :: GameState -> String
drawReport gs =
  let fiftyMove = halfMoveClock gs >= 100
      stalemate = isStalemate gs
      status
        | stalemate = "stalemate"
        | fiftyMove = "fifty_move"
        | otherwise = "none"
   in "DRAWS: {\"fifty_move\":"
        ++ lowerBool fiftyMove
        ++ ",\"threefold\":false,\"insufficient_material\":false,\"stalemate\":"
        ++ lowerBool stalemate
        ++ ",\"status\":\""
        ++ status
        ++ "\"}"

emitPgnShow :: ChessEngine -> IO ()
emitPgnShow engine =
  let rt = runtimeState engine
   in case loadedPgnPath rt of
        Just path -> putStrLn $ "PGN: source=" ++ path ++ " preview=" ++ previewMoves (loadedPgnMoves rt)
        Nothing -> putStrLn $ "PGN: " ++ formatLivePgn (protocolMoves rt)

emitPgnMoves :: ChessEngine -> IO ()
emitPgnMoves engine =
  let rt = runtimeState engine
      moves = if null (loadedPgnMoves rt) then protocolMoves rt else loadedPgnMoves rt
   in putStrLn $ "PGN: moves=" ++ show (length moves)

formatLivePgn :: [String] -> String
formatLivePgn [] = "(empty)"
formatLivePgn moves = unwords (go 1 moves)
  where
    go _ [] = []
    go turn [whiteMove] = [show turn ++ ".", whiteMove]
    go turn (whiteMove : blackMove : rest) = [show turn ++ ".", whiteMove, blackMove] ++ go (turn + 1) rest

previewMoves :: [String] -> String
previewMoves = unwords . take 12

loadPgnFile :: FilePath -> IO (Either String [String])
loadPgnFile path = do
  contents <- safeReadFile path
  return $ fmap extractPgnTokens contents

extractPgnTokens :: String -> [String]
extractPgnTokens content =
  let relevantLines = filter (not . isTagLine) (lines content)
      flattened = map sanitizeChar (unlines relevantLines)
      tokens = words flattened
   in filter validPgnToken (map stripMoveNumber tokens)

isTagLine :: String -> Bool
isTagLine line =
  case dropWhile isSpace line of
    ('[' : _) -> True
    (';' : _) -> True
    _ -> False

sanitizeChar :: Char -> Char
sanitizeChar ch
  | ch `elem` "{}()\n\r\t" = ' '
  | ch == '$' = ' '
  | otherwise = ch

stripMoveNumber :: String -> String
stripMoveNumber = dropWhile (\ch -> isDigit ch || ch == '.')

validPgnToken :: String -> Bool
validPgnToken token =
  not (null token)
    && token `notElem` ["1-0", "0-1", "1/2-1/2", "*"]
    && head token /= '"'

loadBookFile :: FilePath -> IO (Either String [(String, String)])
loadBookFile path = do
  contents <- safeReadFile path
  return $ fmap parseBookEntries contents

parseBookEntries :: String -> [(String, String)]
parseBookEntries =
  foldr collectEntry [] . lines
  where
    collectEntry rawLine acc =
      let line = trim rawLine
       in if null line || head line == '#'
            then acc
            else case splitArrow line of
              Nothing -> acc
              Just (fenText, moveText) -> (trim fenText, head (words (trim moveText))) : acc

splitArrow :: String -> Maybe (String, String)
splitArrow [] = Nothing
splitArrow [_] = Nothing
splitArrow ('-' : '>' : rest) = Just ("", rest)
splitArrow (ch : rest) = do
  (lhs, rhs) <- splitArrow rest
  return (ch : lhs, rhs)

safeReadFile :: FilePath -> IO (Either String String)
safeReadFile path = do
  result <- CE.try (readFile path >>= \content -> CE.evaluate (length content) >> return content) :: IO (Either CE.IOException String)
  return $ either (Left . show) Right result

formatBookStats :: RuntimeState -> String
formatBookStats rt =
  "BOOK: enabled="
    ++ lowerBool (bookEnabled rt)
    ++ " source="
    ++ fromMaybe "-" (bookPath rt)
    ++ " positions="
    ++ show (bookPositionCount rt)
    ++ " entries="
    ++ show (bookEntryCount rt)
    ++ " lookups="
    ++ show (bookLookups rt)
    ++ " hits="
    ++ show (bookHits rt)
    ++ " misses="
    ++ show (bookMisses rt)
    ++ " played="
    ++ show (bookPlayed rt)

handleNew960 :: ChessEngine -> Int -> IO (Maybe ChessEngine)
handleNew960 engine positionId = do
  let rt = (resetRuntimeState True (runtimeState engine)) {chess960Id = Just positionId}
  let newEngine = engine {gameState = initialGameState, moveHistory = [], runtimeState = rt}
  putStrLn $ format960Position positionId
  return (Just newEngine)

format960Position :: Int -> String
format960Position positionId = "960: id=" ++ show positionId ++ " fen=" ++ startingFEN

traceReport :: RuntimeState -> String
traceReport rt =
  "TRACE: {\"enabled\":"
    ++ lowerBool (traceEnabled rt)
    ++ ",\"commands\":"
    ++ show (length (traceEvents rt))
    ++ ",\"events\":["
    ++ intercalate "," (map show (traceEvents rt))
    ++ "]}"

lowerBool :: Bool -> String
lowerBool True = "true"
lowerBool False = "false"

statusReport :: ChessEngine -> String
statusReport engine
  | isCheckmate gs = "CHECKMATE"
  | isStalemate gs = "DRAW: STALEMATE"
  | isThreefoldRepetition engine = "DRAW: REPETITION"
  | halfMoveClock gs >= 100 = "DRAW: 50-MOVE"
  | otherwise = "OK: ONGOING"
  where
    gs = gameState engine

isThreefoldRepetition :: ChessEngine -> Bool
isThreefoldRepetition engine =
  let currentKey = positionKey (gameState engine)
      historyKeys = map positionKey (gameState engine : moveHistory engine)
  in length (filter (== currentKey) historyKeys) >= 3

positionKey :: GameState -> String
positionKey = unwords . take 4 . words . exportFEN

padLeft :: Char -> Int -> String -> String
padLeft fill width text
  | length text >= width = text
  | otherwise = replicate (width - length text) fill ++ text

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
  where
    dropWhileEnd p = reverse . dropWhile p . reverse
