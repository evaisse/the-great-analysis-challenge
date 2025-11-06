#!/usr/bin/env lua5.4
-- Chess Engine Implementation in Lua
-- Implements a complete command-line chess engine with AI

-- Board representation: 8x8 array, indexed 1-8
-- Piece encoding: uppercase = white, lowercase = black
-- P/p = pawn, N/n = knight, B/b = bishop, R/r = rook, Q/q = queen, K/k = king
-- "." = empty square

-- Global state
local board = {}
local white_to_move = true
local castling_rights = {white_king = true, white_queen = true, black_king = true, black_queen = true}
local en_passant_target = nil
local halfmove_clock = 0
local fullmove_number = 1
local move_history = {}

-- Piece values for AI evaluation
local PIECE_VALUES = {
    P = 100, N = 320, B = 330, R = 500, Q = 900, K = 20000,
    p = -100, n = -320, b = -330, r = -500, q = -900, k = -20000
}

-- Initialize new game
local function new_game()
    board = {
        {"R", "N", "B", "Q", "K", "B", "N", "R"},
        {"P", "P", "P", "P", "P", "P", "P", "P"},
        {".", ".", ".", ".", ".", ".", ".", "."},
        {".", ".", ".", ".", ".", ".", ".", "."},
        {".", ".", ".", ".", ".", ".", ".", "."},
        {".", ".", ".", ".", ".", ".", ".", "."},
        {"p", "p", "p", "p", "p", "p", "p", "p"},
        {"r", "n", "b", "q", "k", "b", "n", "r"}
    }
    white_to_move = true
    castling_rights = {white_king = true, white_queen = true, black_king = true, black_queen = true}
    en_passant_target = nil
    halfmove_clock = 0
    fullmove_number = 1
    move_history = {}
end

-- Display board
local function display_board()
    print("  a b c d e f g h")
    for i = 8, 1, -1 do
        io.write(i .. " ")
        for j = 1, 8 do
            io.write(board[i][j] .. " ")
        end
        io.write(i .. "\n")
    end
    print("  a b c d e f g h")
    print()
    if white_to_move then
        print("White to move")
    else
        print("Black to move")
    end
end

-- Convert algebraic notation to board indices
local function algebraic_to_indices(pos)
    local file = string.byte(pos, 1) - string.byte("a") + 1
    local rank = tonumber(string.sub(pos, 2, 2))
    return rank, file
end

-- Convert indices to algebraic notation
local function indices_to_algebraic(rank, file)
    return string.char(string.byte("a") + file - 1) .. tostring(rank)
end

-- Check if a square is attacked by opponent
local function is_square_attacked(rank, file, by_white)
    -- Check pawn attacks
    local pawn_dir = by_white and 1 or -1
    local pawn = by_white and "P" or "p"
    if rank + pawn_dir >= 1 and rank + pawn_dir <= 8 then
        if file > 1 and board[rank + pawn_dir][file - 1] == pawn then return true end
        if file < 8 and board[rank + pawn_dir][file + 1] == pawn then return true end
    end
    
    -- Check knight attacks
    local knight = by_white and "N" or "n"
    local knight_moves = {{2,1},{2,-1},{-2,1},{-2,-1},{1,2},{1,-2},{-1,2},{-1,-2}}
    for _, move in ipairs(knight_moves) do
        local r, f = rank + move[1], file + move[2]
        if r >= 1 and r <= 8 and f >= 1 and f <= 8 and board[r][f] == knight then
            return true
        end
    end
    
    -- Check king attacks
    local king = by_white and "K" or "k"
    for dr = -1, 1 do
        for df = -1, 1 do
            if dr ~= 0 or df ~= 0 then
                local r, f = rank + dr, file + df
                if r >= 1 and r <= 8 and f >= 1 and f <= 8 and board[r][f] == king then
                    return true
                end
            end
        end
    end
    
    -- Check sliding pieces (bishop, rook, queen)
    local directions = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},  -- rook directions
        {1, 1}, {1, -1}, {-1, 1}, {-1, -1}  -- bishop directions
    }
    
    for _, dir in ipairs(directions) do
        local r, f = rank + dir[1], file + dir[2]
        while r >= 1 and r <= 8 and f >= 1 and f <= 8 do
            local piece = board[r][f]
            if piece ~= "." then
                local is_rook_dir = dir[1] == 0 or dir[2] == 0
                local is_bishop_dir = not is_rook_dir
                
                if by_white then
                    if (is_rook_dir and (piece == "R" or piece == "Q")) or
                       (is_bishop_dir and (piece == "B" or piece == "Q")) then
                        return true
                    end
                else
                    if (is_rook_dir and (piece == "r" or piece == "q")) or
                       (is_bishop_dir and (piece == "b" or piece == "q")) then
                        return true
                    end
                end
                break
            end
            r, f = r + dir[1], f + dir[2]
        end
    end
    
    return false
end

-- Find king position
local function find_king(is_white)
    local king = is_white and "K" or "k"
    for rank = 1, 8 do
        for file = 1, 8 do
            if board[rank][file] == king then
                return rank, file
            end
        end
    end
    return nil, nil
end

-- Check if current player is in check
local function is_in_check(is_white)
    local rank, file = find_king(is_white)
    if not rank then return false end
    return is_square_attacked(rank, file, not is_white)
end

-- Make a move (without validation)
local function make_move_internal(from_rank, from_file, to_rank, to_file, promotion)
    local piece = board[from_rank][from_file]
    local captured = board[to_rank][to_file]
    
    -- Store move for undo
    local move_record = {
        from_rank = from_rank, from_file = from_file,
        to_rank = to_rank, to_file = to_file,
        piece = piece, captured = captured,
        castling_rights = {white_king = castling_rights.white_king, white_queen = castling_rights.white_queen,
                          black_king = castling_rights.black_king, black_queen = castling_rights.black_queen},
        en_passant_target = en_passant_target,
        halfmove_clock = halfmove_clock,
        promotion = promotion
    }
    
    -- Handle en passant capture
    if en_passant_target and to_rank == en_passant_target[1] and to_file == en_passant_target[2] then
        if piece == "P" or piece == "p" then
            local capture_rank = white_to_move and to_rank - 1 or to_rank + 1
            move_record.en_passant_captured = board[capture_rank][to_file]
            board[capture_rank][to_file] = "."
        end
    end
    
    -- Move piece
    board[to_rank][to_file] = piece
    board[from_rank][from_file] = "."
    
    -- Handle promotion
    if promotion then
        board[to_rank][to_file] = promotion
    elseif (piece == "P" and to_rank == 8) or (piece == "p" and to_rank == 1) then
        board[to_rank][to_file] = white_to_move and "Q" or "q"
        move_record.promotion = board[to_rank][to_file]
    end
    
    -- Handle castling
    if piece == "K" and from_file == 5 then
        if to_file == 7 then  -- Kingside
            board[1][6] = board[1][8]
            board[1][8] = "."
            move_record.castling = "kingside"
        elseif to_file == 3 then  -- Queenside
            board[1][4] = board[1][1]
            board[1][1] = "."
            move_record.castling = "queenside"
        end
    elseif piece == "k" and from_file == 5 then
        if to_file == 7 then  -- Kingside
            board[8][6] = board[8][8]
            board[8][8] = "."
            move_record.castling = "kingside"
        elseif to_file == 3 then  -- Queenside
            board[8][4] = board[8][1]
            board[8][1] = "."
            move_record.castling = "queenside"
        end
    end
    
    -- Update castling rights
    if piece == "K" then
        castling_rights.white_king = false
        castling_rights.white_queen = false
    elseif piece == "k" then
        castling_rights.black_king = false
        castling_rights.black_queen = false
    elseif piece == "R" then
        if from_rank == 1 and from_file == 1 then castling_rights.white_queen = false end
        if from_rank == 1 and from_file == 8 then castling_rights.white_king = false end
    elseif piece == "r" then
        if from_rank == 8 and from_file == 1 then castling_rights.black_queen = false end
        if from_rank == 8 and from_file == 8 then castling_rights.black_king = false end
    end
    
    -- Update en passant target
    en_passant_target = nil
    if (piece == "P" and from_rank == 2 and to_rank == 4) or
       (piece == "p" and from_rank == 7 and to_rank == 5) then
        local ep_rank = white_to_move and 3 or 6
        en_passant_target = {ep_rank, from_file}
    end
    
    -- Update clocks
    if captured ~= "." or piece == "P" or piece == "p" then
        halfmove_clock = 0
    else
        halfmove_clock = halfmove_clock + 1
    end
    
    if not white_to_move then
        fullmove_number = fullmove_number + 1
    end
    
    white_to_move = not white_to_move
    table.insert(move_history, move_record)
    
    return true
end

-- Undo last move
local function undo_move()
    if #move_history == 0 then return false end
    
    local move = table.remove(move_history)
    
    -- Restore piece
    board[move.from_rank][move.from_file] = move.piece
    board[move.to_rank][move.to_file] = move.captured
    
    -- Restore en passant capture
    if move.en_passant_captured then
        local capture_rank = move.piece == "P" and move.to_rank - 1 or move.to_rank + 1
        board[capture_rank][move.to_file] = move.en_passant_captured
    end
    
    -- Undo castling
    if move.castling == "kingside" then
        if move.piece == "K" then
            board[1][8] = board[1][6]
            board[1][6] = "."
        else
            board[8][8] = board[8][6]
            board[8][6] = "."
        end
    elseif move.castling == "queenside" then
        if move.piece == "K" then
            board[1][1] = board[1][4]
            board[1][4] = "."
        else
            board[8][1] = board[8][4]
            board[8][4] = "."
        end
    end
    
    -- Restore state
    castling_rights = move.castling_rights
    en_passant_target = move.en_passant_target
    halfmove_clock = move.halfmove_clock
    white_to_move = not white_to_move
    
    if white_to_move then
        fullmove_number = fullmove_number - 1
    end
    
    return true
end

-- Check if a move is legal
local function is_legal_move(from_rank, from_file, to_rank, to_file, promotion)
    local piece = board[from_rank][from_file]
    if piece == "." then return false, "No piece at source square" end
    
    local is_white = piece == string.upper(piece)
    if is_white ~= white_to_move then return false, "Wrong color piece" end
    
    local target = board[to_rank][to_file]
    if target ~= "." then
        local target_is_white = target == string.upper(target)
        if target_is_white == is_white then return false, "Cannot capture own piece" end
    end
    
    local piece_type = string.upper(piece)
    
    -- Validate piece-specific moves
    if piece_type == "P" then
        local direction = is_white and 1 or -1
        local start_rank = is_white and 2 or 7
        
        -- Forward move
        if from_file == to_file then
            if to_rank == from_rank + direction and board[to_rank][to_file] == "." then
                -- Valid
            elseif from_rank == start_rank and to_rank == from_rank + 2 * direction and
                   board[from_rank + direction][from_file] == "." and board[to_rank][to_file] == "." then
                -- Valid
            else
                return false, "Illegal pawn move"
            end
        -- Capture
        elseif math.abs(to_file - from_file) == 1 and to_rank == from_rank + direction then
            if board[to_rank][to_file] ~= "." then
                -- Normal capture
            elseif en_passant_target and to_rank == en_passant_target[1] and to_file == en_passant_target[2] then
                -- En passant
            else
                return false, "Illegal pawn capture"
            end
        else
            return false, "Illegal pawn move"
        end
    elseif piece_type == "N" then
        local dr = math.abs(to_rank - from_rank)
        local df = math.abs(to_file - from_file)
        if not ((dr == 2 and df == 1) or (dr == 1 and df == 2)) then
            return false, "Illegal knight move"
        end
    elseif piece_type == "B" then
        if math.abs(to_rank - from_rank) ~= math.abs(to_file - from_file) then
            return false, "Illegal bishop move"
        end
        -- Check path is clear
        local dr = (to_rank > from_rank) and 1 or -1
        local df = (to_file > from_file) and 1 or -1
        local r, f = from_rank + dr, from_file + df
        while r ~= to_rank do
            if board[r][f] ~= "." then return false, "Path blocked" end
            r, f = r + dr, f + df
        end
    elseif piece_type == "R" then
        if to_rank ~= from_rank and to_file ~= from_file then
            return false, "Illegal rook move"
        end
        -- Check path is clear
        local dr = (to_rank > from_rank) and 1 or ((to_rank < from_rank) and -1 or 0)
        local df = (to_file > from_file) and 1 or ((to_file < from_file) and -1 or 0)
        local r, f = from_rank + dr, from_file + df
        while r ~= to_rank or f ~= to_file do
            if board[r][f] ~= "." then return false, "Path blocked" end
            r, f = r + dr, f + df
        end
    elseif piece_type == "Q" then
        local is_diagonal = math.abs(to_rank - from_rank) == math.abs(to_file - from_file)
        local is_straight = to_rank == from_rank or to_file == from_file
        if not (is_diagonal or is_straight) then
            return false, "Illegal queen move"
        end
        -- Check path is clear
        local dr = (to_rank > from_rank) and 1 or ((to_rank < from_rank) and -1 or 0)
        local df = (to_file > from_file) and 1 or ((to_file < from_file) and -1 or 0)
        local r, f = from_rank + dr, from_file + df
        while r ~= to_rank or f ~= to_file do
            if board[r][f] ~= "." then return false, "Path blocked" end
            r, f = r + dr, f + df
        end
    elseif piece_type == "K" then
        local dr = math.abs(to_rank - from_rank)
        local df = math.abs(to_file - from_file)
        
        -- Normal king move
        if dr <= 1 and df <= 1 then
            -- Valid
        -- Castling
        elseif dr == 0 and df == 2 and from_file == 5 then
            if is_white then
                if to_file == 7 then
                    if not castling_rights.white_king then return false, "Cannot castle" end
                    if board[1][6] ~= "." or board[1][7] ~= "." then return false, "Path blocked" end
                    if is_in_check(true) or is_square_attacked(1, 6, false) or is_square_attacked(1, 7, false) then
                        return false, "Cannot castle through check"
                    end
                elseif to_file == 3 then
                    if not castling_rights.white_queen then return false, "Cannot castle" end
                    if board[1][2] ~= "." or board[1][3] ~= "." or board[1][4] ~= "." then return false, "Path blocked" end
                    if is_in_check(true) or is_square_attacked(1, 3, false) or is_square_attacked(1, 4, false) then
                        return false, "Cannot castle through check"
                    end
                else
                    return false, "Illegal king move"
                end
            else
                if to_file == 7 then
                    if not castling_rights.black_king then return false, "Cannot castle" end
                    if board[8][6] ~= "." or board[8][7] ~= "." then return false, "Path blocked" end
                    if is_in_check(false) or is_square_attacked(8, 6, true) or is_square_attacked(8, 7, true) then
                        return false, "Cannot castle through check"
                    end
                elseif to_file == 3 then
                    if not castling_rights.black_queen then return false, "Cannot castle" end
                    if board[8][2] ~= "." or board[8][3] ~= "." or board[8][4] ~= "." then return false, "Path blocked" end
                    if is_in_check(false) or is_square_attacked(8, 3, true) or is_square_attacked(8, 4, true) then
                        return false, "Cannot castle through check"
                    end
                else
                    return false, "Illegal king move"
                end
            end
        else
            return false, "Illegal king move"
        end
    end
    
    -- Test if move leaves king in check
    make_move_internal(from_rank, from_file, to_rank, to_file, promotion)
    local in_check = is_in_check(not white_to_move)
    undo_move()
    
    if in_check then
        return false, "King would be in check"
    end
    
    return true, "OK"
end

-- Execute a move
local function execute_move(move_str)
    if #move_str < 4 then
        return false, "ERROR: Invalid move format"
    end
    
    local from = string.sub(move_str, 1, 2)
    local to = string.sub(move_str, 3, 4)
    local promotion_piece = #move_str >= 5 and string.sub(move_str, 5, 5) or nil
    
    local from_rank, from_file = algebraic_to_indices(from)
    local to_rank, to_file = algebraic_to_indices(to)
    
    if not from_rank or not to_rank or 
       from_rank < 1 or from_rank > 8 or to_rank < 1 or to_rank > 8 or
       from_file < 1 or from_file > 8 or to_file < 1 or to_file > 8 then
        return false, "ERROR: Invalid move format"
    end
    
    if promotion_piece then
        promotion_piece = white_to_move and string.upper(promotion_piece) or string.lower(promotion_piece)
    end
    
    local legal, msg = is_legal_move(from_rank, from_file, to_rank, to_file, promotion_piece)
    if not legal then
        return false, "ERROR: " .. msg
    end
    
    make_move_internal(from_rank, from_file, to_rank, to_file, promotion_piece)
    return true, "OK: " .. move_str
end

-- Export to FEN
local function export_fen()
    local fen = ""
    
    -- Board position
    for rank = 8, 1, -1 do
        local empty = 0
        for file = 1, 8 do
            local piece = board[rank][file]
            if piece == "." then
                empty = empty + 1
            else
                if empty > 0 then
                    fen = fen .. tostring(empty)
                    empty = 0
                end
                fen = fen .. piece
            end
        end
        if empty > 0 then
            fen = fen .. tostring(empty)
        end
        if rank > 1 then
            fen = fen .. "/"
        end
    end
    
    -- Active color
    fen = fen .. " " .. (white_to_move and "w" or "b")
    
    -- Castling rights
    local castling = ""
    if castling_rights.white_king then castling = castling .. "K" end
    if castling_rights.white_queen then castling = castling .. "Q" end
    if castling_rights.black_king then castling = castling .. "k" end
    if castling_rights.black_queen then castling = castling .. "q" end
    if castling == "" then castling = "-" end
    fen = fen .. " " .. castling
    
    -- En passant target
    if en_passant_target then
        fen = fen .. " " .. indices_to_algebraic(en_passant_target[1], en_passant_target[2])
    else
        fen = fen .. " -"
    end
    
    -- Halfmove and fullmove clocks
    fen = fen .. " " .. tostring(halfmove_clock) .. " " .. tostring(fullmove_number)
    
    return fen
end

-- Import from FEN
local function import_fen(fen_str)
    local parts = {}
    for part in string.gmatch(fen_str, "%S+") do
        table.insert(parts, part)
    end
    
    if #parts < 4 then
        return false, "ERROR: Invalid FEN string"
    end
    
    -- Parse board
    local ranks = {}
    for rank in string.gmatch(parts[1], "[^/]+") do
        table.insert(ranks, rank)
    end
    
    if #ranks ~= 8 then
        return false, "ERROR: Invalid FEN string"
    end
    
    board = {}
    for i = 1, 8 do
        board[9 - i] = {}
        local file = 1
        for j = 1, #ranks[i] do
            local c = string.sub(ranks[i], j, j)
            if tonumber(c) then
                for k = 1, tonumber(c) do
                    board[9 - i][file] = "."
                    file = file + 1
                end
            else
                board[9 - i][file] = c
                file = file + 1
            end
        end
    end
    
    -- Parse active color
    white_to_move = parts[2] == "w"
    
    -- Parse castling rights
    castling_rights = {white_king = false, white_queen = false, black_king = false, black_queen = false}
    if parts[3] ~= "-" then
        for i = 1, #parts[3] do
            local c = string.sub(parts[3], i, i)
            if c == "K" then castling_rights.white_king = true
            elseif c == "Q" then castling_rights.white_queen = true
            elseif c == "k" then castling_rights.black_king = true
            elseif c == "q" then castling_rights.black_queen = true
            end
        end
    end
    
    -- Parse en passant
    en_passant_target = nil
    if parts[4] ~= "-" then
        local rank, file = algebraic_to_indices(parts[4])
        en_passant_target = {rank, file}
    end
    
    -- Parse clocks
    halfmove_clock = tonumber(parts[5]) or 0
    fullmove_number = tonumber(parts[6]) or 1
    
    move_history = {}
    return true, "OK"
end

-- Generate all legal moves
local function generate_legal_moves()
    local moves = {}
    
    for from_rank = 1, 8 do
        for from_file = 1, 8 do
            local piece = board[from_rank][from_file]
            if piece ~= "." then
                local is_white = piece == string.upper(piece)
                if is_white == white_to_move then
                    for to_rank = 1, 8 do
                        for to_file = 1, 8 do
                            local legal, _ = is_legal_move(from_rank, from_file, to_rank, to_file, nil)
                            if legal then
                                table.insert(moves, {from_rank, from_file, to_rank, to_file})
                            end
                            
                            -- Check promotions
                            if (piece == "P" and to_rank == 8) or (piece == "p" and to_rank == 1) then
                                local promo_pieces = is_white and {"Q", "R", "B", "N"} or {"q", "r", "b", "n"}
                                for _, promo in ipairs(promo_pieces) do
                                    legal, _ = is_legal_move(from_rank, from_file, to_rank, to_file, promo)
                                    if legal then
                                        table.insert(moves, {from_rank, from_file, to_rank, to_file, promo})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return moves
end

-- Evaluate board position
local function evaluate_position()
    local score = 0
    
    for rank = 1, 8 do
        for file = 1, 8 do
            local piece = board[rank][file]
            if piece ~= "." then
                score = score + (PIECE_VALUES[piece] or 0)
                
                -- Position bonuses
                if (file >= 4 and file <= 5) and (rank >= 4 and rank <= 5) then
                    score = score + (piece == string.upper(piece) and 10 or -10)
                end
                
                -- Pawn advancement bonus
                if piece == "P" then
                    score = score + (rank - 2) * 5
                elseif piece == "p" then
                    score = score - (7 - rank) * 5
                end
            end
        end
    end
    
    return score
end

-- Minimax with alpha-beta pruning
local function minimax(depth, alpha, beta, maximizing)
    if depth == 0 then
        return evaluate_position(), nil
    end
    
    local moves = generate_legal_moves()
    
    if #moves == 0 then
        if is_in_check(white_to_move) then
            return maximizing and -100000 or 100000, nil
        else
            return 0, nil  -- Stalemate
        end
    end
    
    local best_move = nil
    
    if maximizing then
        local max_eval = -math.huge
        for _, move in ipairs(moves) do
            make_move_internal(move[1], move[2], move[3], move[4], move[5])
            local eval, _ = minimax(depth - 1, alpha, beta, false)
            undo_move()
            
            if eval > max_eval then
                max_eval = eval
                best_move = move
            end
            
            alpha = math.max(alpha, eval)
            if beta <= alpha then
                break
            end
        end
        return max_eval, best_move
    else
        local min_eval = math.huge
        for _, move in ipairs(moves) do
            make_move_internal(move[1], move[2], move[3], move[4], move[5])
            local eval, _ = minimax(depth - 1, alpha, beta, true)
            undo_move()
            
            if eval < min_eval then
                min_eval = eval
                best_move = move
            end
            
            beta = math.min(beta, eval)
            if beta <= alpha then
                break
            end
        end
        return min_eval, best_move
    end
end

-- AI move
local function ai_move(depth)
    depth = tonumber(depth) or 3
    if depth < 1 or depth > 5 then
        return false, "ERROR: AI depth must be 1-5"
    end
    
    local start_time = os.clock()
    local eval, best_move = minimax(depth, -math.huge, math.huge, white_to_move)
    local elapsed = math.floor((os.clock() - start_time) * 1000)
    
    if not best_move then
        return false, "ERROR: No legal moves"
    end
    
    local move_str = indices_to_algebraic(best_move[1], best_move[2]) .. 
                     indices_to_algebraic(best_move[3], best_move[4])
    if best_move[5] then
        move_str = move_str .. best_move[5]
    end
    
    make_move_internal(best_move[1], best_move[2], best_move[3], best_move[4], best_move[5])
    
    return true, string.format("AI: %s (depth=%d, eval=%d, time=%dms)", move_str, depth, eval, elapsed)
end

-- Perft (performance test)
local function perft(depth)
    if depth == 0 then return 1 end
    
    local moves = generate_legal_moves()
    local nodes = 0
    
    for _, move in ipairs(moves) do
        make_move_internal(move[1], move[2], move[3], move[4], move[5])
        nodes = nodes + perft(depth - 1)
        undo_move()
    end
    
    return nodes
end

-- Main command loop
local function main()
    new_game()
    
    while true do
        io.write("> ")
        io.flush()
        local input = io.read()
        
        if not input then break end
        
        input = input:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
        
        local cmd, arg = input:match("^(%S+)%s*(.*)$")
        if not cmd then cmd = input end
        
        if cmd == "quit" or cmd == "exit" then
            break
        elseif cmd == "new" then
            new_game()
            display_board()
        elseif cmd == "move" then
            if arg and arg ~= "" then
                local success, msg = execute_move(arg)
                print(msg)
                if success then
                    display_board()
                    
                    -- Check for game end
                    if #generate_legal_moves() == 0 then
                        if is_in_check(white_to_move) then
                            print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                        else
                            print("STALEMATE: Draw")
                        end
                    end
                end
            else
                print("ERROR: Move requires argument (e.g., 'move e2e4')")
            end
        elseif cmd == "undo" then
            if undo_move() then
                print("OK: Move undone")
                display_board()
            else
                print("ERROR: No moves to undo")
            end
        elseif cmd == "display" or cmd == "show" then
            display_board()
        elseif cmd == "export" then
            print("FEN: " .. export_fen())
        elseif cmd == "fen" then
            if arg and arg ~= "" then
                local success, msg = import_fen(arg)
                print(msg)
                if success then
                    display_board()
                end
            else
                print("ERROR: FEN command requires argument")
            end
        elseif cmd == "ai" then
            local depth = tonumber(arg) or 3
            local success, msg = ai_move(depth)
            print(msg)
            if success then
                display_board()
                
                -- Check for game end
                if #generate_legal_moves() == 0 then
                    if is_in_check(white_to_move) then
                        print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                    else
                        print("STALEMATE: Draw")
                    end
                end
            end
        elseif cmd == "eval" then
            local score = evaluate_position()
            print(string.format("Evaluation: %+d", score))
        elseif cmd == "perft" then
            local depth = tonumber(arg) or 4
            local start_time = os.clock()
            local nodes = perft(depth)
            local elapsed = math.floor((os.clock() - start_time) * 1000)
            print(string.format("Nodes: %d (time=%dms)", nodes, elapsed))
        elseif cmd == "help" then
            print("Available commands:")
            print("  new              - Start a new game")
            print("  move <from><to>  - Make a move (e.g., 'move e2e4')")
            print("  undo             - Undo last move")
            print("  display          - Show the board")
            print("  export           - Export position as FEN")
            print("  fen <string>     - Load position from FEN")
            print("  ai <depth>       - AI makes a move (depth 1-5)")
            print("  eval             - Show position evaluation")
            print("  perft <depth>    - Performance test")
            print("  help             - Show this help")
            print("  quit             - Exit the program")
        else
            print("ERROR: Invalid command. Type 'help' for available commands.")
        end
    end
end

-- Run the chess engine
main()
