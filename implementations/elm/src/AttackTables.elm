module AttackTables exposing
    ( bishopRays
    , chebyshevDistance
    , kingAttacks
    , knightAttacks
    , manhattanDistance
    , queenRays
    , rookRays
    )

import Array exposing (Array)
import Types exposing (Square)
import Utils exposing (isValidSquare, positionToSquare, squareToPosition)


type alias Delta =
    ( Int, Int )


knightDeltas : List Delta
knightDeltas =
    [ ( -2, -1 ), ( -2, 1 ), ( -1, -2 ), ( -1, 2 ), ( 1, -2 ), ( 1, 2 ), ( 2, -1 ), ( 2, 1 ) ]


kingDeltas : List Delta
kingDeltas =
    [ ( -1, -1 ), ( -1, 0 ), ( -1, 1 ), ( 0, -1 ), ( 0, 1 ), ( 1, -1 ), ( 1, 0 ), ( 1, 1 ) ]


bishopDeltas : List Delta
bishopDeltas =
    [ ( -1, -1 ), ( -1, 1 ), ( 1, -1 ), ( 1, 1 ) ]


rookDeltas : List Delta
rookDeltas =
    [ ( -1, 0 ), ( 0, -1 ), ( 0, 1 ), ( 1, 0 ) ]


queenDeltas : List Delta
queenDeltas =
    bishopDeltas ++ rookDeltas


buildAttackTable : List Delta -> Array (List Square)
buildAttackTable deltas =
    List.range 0 63
        |> List.map
            (\square ->
                let
                    pos =
                        squareToPosition square
                in
                deltas
                    |> List.filterMap
                        (\( rowDelta, colDelta ) ->
                            let
                                row =
                                    pos.row + rowDelta

                                col =
                                    pos.col + colDelta
                            in
                            if isValidSquare row col then
                                Just (positionToSquare row col)

                            else
                                Nothing
                        )
            )
        |> Array.fromList


buildRay : Square -> Delta -> List Square
buildRay square ( rowDelta, colDelta ) =
    let
        pos =
            squareToPosition square

        step row col acc =
            if isValidSquare row col then
                step (row + rowDelta) (col + colDelta) (positionToSquare row col :: acc)

            else
                List.reverse acc
    in
    step (pos.row + rowDelta) (pos.col + colDelta) []


buildRayTable : List Delta -> Array (List (List Square))
buildRayTable deltas =
    List.range 0 63
        |> List.map (\square -> List.map (buildRay square) deltas)
        |> Array.fromList


buildDistanceTable : (Int -> Int -> Int) -> Array (Array Int)
buildDistanceTable metric =
    List.range 0 63
        |> List.map
            (\from ->
                let
                    fromPos =
                        squareToPosition from
                in
                List.range 0 63
                    |> List.map
                        (\to ->
                            let
                                toPos =
                                    squareToPosition to
                            in
                            metric (abs (fromPos.col - toPos.col)) (abs (fromPos.row - toPos.row))
                        )
                    |> Array.fromList
            )
        |> Array.fromList


knightAttackTable : Array (List Square)
knightAttackTable =
    buildAttackTable knightDeltas


kingAttackTable : Array (List Square)
kingAttackTable =
    buildAttackTable kingDeltas


bishopRayTable : Array (List (List Square))
bishopRayTable =
    buildRayTable bishopDeltas


rookRayTable : Array (List (List Square))
rookRayTable =
    buildRayTable rookDeltas


queenRayTable : Array (List (List Square))
queenRayTable =
    buildRayTable queenDeltas


chebyshevDistanceTable : Array (Array Int)
chebyshevDistanceTable =
    buildDistanceTable max


manhattanDistanceTable : Array (Array Int)
manhattanDistanceTable =
    buildDistanceTable (+)


arrayEntry : Int -> Array a -> a -> a
arrayEntry index table fallback =
    Array.get index table |> Maybe.withDefault fallback


knightAttacks : Square -> List Square
knightAttacks square =
    arrayEntry square knightAttackTable []


kingAttacks : Square -> List Square
kingAttacks square =
    arrayEntry square kingAttackTable []


bishopRays : Square -> List (List Square)
bishopRays square =
    arrayEntry square bishopRayTable []


rookRays : Square -> List (List Square)
rookRays square =
    arrayEntry square rookRayTable []


queenRays : Square -> List (List Square)
queenRays square =
    arrayEntry square queenRayTable []


chebyshevDistance : Square -> Square -> Int
chebyshevDistance from to =
    arrayEntry to (arrayEntry from chebyshevDistanceTable Array.empty) 0


manhattanDistance : Square -> Square -> Int
manhattanDistance from to =
    arrayEntry to (arrayEntry from manhattanDistanceTable Array.empty) 0
