#!/usr/bin/env lua5.4
-- Chess Engine Implementation in Lua
-- Implements a complete command-line chess engine with AI

-- Board representation: 8x8 array, indexed 1-8
-- Piece encoding: uppercase = white, lowercase = black
-- P/p = pawn, N/n = knight, B/b = bishop, R/r = rook, Q/q = queen, K/k = king
-- "." = empty square

-- Global state
local START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

local board = {}
local white_to_move = true
local castling_rights = {white_king = true, white_queen = true, black_king = true, black_queen = true}
local castling_config = default_castling_config and default_castling_config() or {
    white_king_file = 5,
    white_kingside_rook_file = 8,
    white_queenside_rook_file = 1,
    black_king_file = 5,
    black_kingside_rook_file = 8,
    black_queenside_rook_file = 1,
}
local chess960_mode = false
local en_passant_target = nil
local halfmove_clock = 0
local fullmove_number = 1
local move_history = {}
local zobrist_hash = 0
local position_history = {}
local irreversible_history = {}
local pgn_path = nil
local pgn_game = nil
local pgn_variation_stack = {}
local book_path = nil
local book_enabled = false
local book_entries = {}
local book_entry_count = 0
local book_lookups = 0
local book_hits = 0
local book_misses = 0
local book_played = 0
local uci_hash_mb = 16
local uci_threads = 1
local uci_analyse_mode = false
local rich_eval_enabled = false
local protocol_mode = "boot"
local uci_state = "boot"
local uci_last_bestmove = nil
local chess960_id = 0
local trace_enabled = false
local trace_level = "info"
local trace_events = {}
local trace_command_count = 0
local trace_export_count = 0
local trace_chrome_count = 0
local trace_last_export_target = "(none)"
local trace_last_export_bytes = 0
local trace_last_chrome_target = "(none)"
local trace_last_chrome_bytes = 0
local trace_last_ai_source = nil
local trace_last_ai_move = nil
local trace_last_ai_depth = 0
local trace_last_ai_score_cp = 0
local trace_last_ai_elapsed_ms = 0
local trace_last_ai_timed_out = false
local trace_last_ai_nodes = 0
local trace_last_ai_eval_calls = 0
local trace_last_ai_nps = 0
local trace_last_ai_tt_hits = 0
local trace_last_ai_tt_misses = 0
local trace_last_ai_beta_cutoffs = 0

local function select_protocol_mode(cmd)
    if protocol_mode == "boot" then
        protocol_mode = cmd == "uci" and "uci" or "custom"
    elseif cmd == "uci" then
        protocol_mode = "uci"
    end
end

local function set_uci_state(state)
    uci_state = state
end

local function uci_bool_default(value)
    return value and "true" or "false"
end

local function parse_uci_check_value(raw)
    local normalized = raw:lower()
    if normalized == "true" or normalized == "1" or normalized == "on" or normalized == "yes" then
        return true
    end
    if normalized == "false" or normalized == "0" or normalized == "off" or normalized == "no" then
        return false
    end
    return nil
end

local chess960_knight_table = {
    {0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 2},
    {1, 3}, {1, 4}, {2, 3}, {2, 4}, {3, 4}
}

local function decode_chess960_backrank(id)
    local pieces = {nil, nil, nil, nil, nil, nil, nil, nil}
    local n = id

    local remainder = n % 4
    n = math.floor(n / 4)
    pieces[2 * remainder + 2] = "b"

    remainder = n % 4
    n = math.floor(n / 4)
    pieces[2 * remainder + 1] = "b"

    local empty = {}
    for i = 1, 8 do
        if pieces[i] == nil then
            empty[#empty + 1] = i
        end
    end
    remainder = n % 6
    n = math.floor(n / 6)
    pieces[empty[remainder + 1]] = "q"

    local knight_pair = chess960_knight_table[n + 1]
    empty = {}
    for i = 1, 8 do
        if pieces[i] == nil then
            empty[#empty + 1] = i
        end
    end
    pieces[empty[knight_pair[1] + 1]] = "n"
    pieces[empty[knight_pair[2] + 1]] = "n"

    empty = {}
    for i = 1, 8 do
        if pieces[i] == nil then
            empty[#empty + 1] = i
        end
    end
    pieces[empty[1]] = "r"
    pieces[empty[2]] = "k"
    pieces[empty[3]] = "r"

    return table.concat(pieces)
end

local function build_chess960_fen(id)
    local white = string.upper(decode_chess960_backrank(id))
    local black = string.lower(white)
    local castling = ""
    for i = 1, #white do
        if string.sub(white, i, i) == "R" then
            castling = castling .. string.char(string.byte("A") + i - 1)
        end
    end
    return string.format("%s/pppppppp/8/8/8/8/PPPPPPPP/%s w %s - 0 1", black, white, castling .. string.lower(castling))
end
local tt = {}
local search_deadline = nil
local search_timed_out = false
local search_stop_requested = false
local record_trace_ai
local reset_pgn_state
local current_pgn_game
local current_pgn_moves
local current_pgn_sequence
local current_pgn_sequence_ref
local sync_runtime_to_pgn_cursor
local record_pgn_move
local build_game_from_history
local snapshot_engine_state
local restore_engine_state
local search_nodes_visited = 0
local search_eval_calls = 0
local search_tt_hits = 0
local search_tt_misses = 0
local search_beta_cutoffs = 0

local KNIGHT_DELTAS = {{2,1},{2,-1},{-2,1},{-2,-1},{1,2},{1,-2},{-1,2},{-1,-2}}
local KING_DELTAS = {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}
local RAY_DIRECTIONS = {
    {1, 0}, {-1, 0}, {0, 1}, {0, -1},
    {1, 1}, {1, -1}, {-1, 1}, {-1, -1}
}
local KNIGHT_ATTACKS = {}
local KING_ATTACKS = {}
local RAY_TABLES = {}
local CHEBYSHEV_DISTANCE = {}
local MANHATTAN_DISTANCE = {}

local zobrist_keys = {
    pieces = {},
    side_to_move = 0,
    castling = {},
    en_passant = {}
}

local function xorshift64(state)
    state = state ~ ((state << 13) & 0xFFFFFFFFFFFFFFFF)
    state = state ~ (state >> 7)
    state = state ~ ((state << 17) & 0xFFFFFFFFFFFFFFFF)
    return state & 0xFFFFFFFFFFFFFFFF
end

local function init_zobrist()
    local state = 0x123456789ABCDEF0
    for p = 1, 12 do
        zobrist_keys.pieces[p] = {}
        for s = 1, 64 do
            state = xorshift64(state)
            zobrist_keys.pieces[p][s] = state
        end
    end
    state = xorshift64(state)
    zobrist_keys.side_to_move = state
    for i = 1, 4 do
        state = xorshift64(state)
        zobrist_keys.castling[i] = state
    end
    for i = 1, 8 do
        state = xorshift64(state)
        zobrist_keys.en_passant[i] = state
    end
end

init_zobrist()

local function get_piece_index(piece)
    local types = {P=1, N=2, B=3, R=4, Q=5, K=6, p=7, n=8, b=9, r=10, q=11, k=12}
    return types[piece]
end

local function compute_hash()
    local hash = 0
    for rank = 1, 8 do
        for file = 1, 8 do
            local piece = board[rank][file]
            if piece ~= "." then
                local square = (rank - 1) * 8 + file -- a1=1, b1=2...
                hash = hash ~ zobrist_keys.pieces[get_piece_index(piece)][square]
            end
        end
    end
    if not white_to_move then
        hash = hash ~ zobrist_keys.side_to_move
    end
    if castling_rights.white_king then hash = hash ~ zobrist_keys.castling[1] end
    if castling_rights.white_queen then hash = hash ~ zobrist_keys.castling[2] end
    if castling_rights.black_king then hash = hash ~ zobrist_keys.castling[3] end
    if castling_rights.black_queen then hash = hash ~ zobrist_keys.castling[4] end
    if en_passant_target then
        hash = hash ~ zobrist_keys.en_passant[en_passant_target[2]]
    end
    return hash
end

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
    castling_config = {
        white_king_file = 5,
        white_kingside_rook_file = 8,
        white_queenside_rook_file = 1,
        black_king_file = 5,
        black_kingside_rook_file = 8,
        black_queenside_rook_file = 1,
    }
    chess960_mode = false
    en_passant_target = nil
    halfmove_clock = 0
    fullmove_number = 1
    move_history = {}
    zobrist_hash = compute_hash()
    position_history = {}
    irreversible_history = {}
    reset_pgn_state(START_FEN, "current-game")
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

local function square_index(rank, file)
    return (rank - 1) * 8 + file
end

local function build_attack_table(deltas)
    local table_out = {}
    for rank = 1, 8 do
        table_out[rank] = {}
        for file = 1, 8 do
            local attacks = {}
            for _, delta in ipairs(deltas) do
                local r, f = rank + delta[1], file + delta[2]
                if r >= 1 and r <= 8 and f >= 1 and f <= 8 then
                    attacks[#attacks + 1] = {r, f}
                end
            end
            table_out[rank][file] = attacks
        end
    end
    return table_out
end

local function build_ray_table(drank, dfile)
    local table_out = {}
    for rank = 1, 8 do
        table_out[rank] = {}
        for file = 1, 8 do
            local ray = {}
            local r, f = rank + drank, file + dfile
            while r >= 1 and r <= 8 and f >= 1 and f <= 8 do
                ray[#ray + 1] = {r, f}
                r, f = r + drank, f + dfile
            end
            table_out[rank][file] = ray
        end
    end
    return table_out
end

local function build_distance_table(metric)
    local table_out = {}
    for from_rank = 1, 8 do
        for from_file = 1, 8 do
            local from_idx = square_index(from_rank, from_file)
            table_out[from_idx] = {}
            for to_rank = 1, 8 do
                for to_file = 1, 8 do
                    local to_idx = square_index(to_rank, to_file)
                    local rank_distance = math.abs(from_rank - to_rank)
                    local file_distance = math.abs(from_file - to_file)
                    table_out[from_idx][to_idx] = metric(rank_distance, file_distance)
                end
            end
        end
    end
    return table_out
end

local function knight_attacks(rank, file)
    return KNIGHT_ATTACKS[rank][file]
end

local function king_attacks(rank, file)
    return KING_ATTACKS[rank][file]
end

local function ray_attacks(rank, file, drank, dfile)
    return RAY_TABLES[drank .. "," .. dfile][rank][file]
end

local function chebyshev_distance(a_rank, a_file, b_rank, b_file)
    return CHEBYSHEV_DISTANCE[square_index(a_rank, a_file)][square_index(b_rank, b_file)]
end

local function manhattan_distance(a_rank, a_file, b_rank, b_file)
    return MANHATTAN_DISTANCE[square_index(a_rank, a_file)][square_index(b_rank, b_file)]
end

local function clone_castling_config(source)
    return {
        white_king_file = source.white_king_file,
        white_kingside_rook_file = source.white_kingside_rook_file,
        white_queenside_rook_file = source.white_queenside_rook_file,
        black_king_file = source.black_king_file,
        black_kingside_rook_file = source.black_kingside_rook_file,
        black_queenside_rook_file = source.black_queenside_rook_file,
    }
end

local function castling_config_is_classical(config)
    return config.white_king_file == 5 and
        config.white_kingside_rook_file == 8 and
        config.white_queenside_rook_file == 1 and
        config.black_king_file == 5 and
        config.black_kingside_rook_file == 8 and
        config.black_queenside_rook_file == 1
end

local function get_castle_details(is_white, kingside)
    local rank = is_white and 1 or 8
    local king_file = is_white and castling_config.white_king_file or castling_config.black_king_file
    local rook_file
    if is_white then
        rook_file = kingside and castling_config.white_kingside_rook_file or castling_config.white_queenside_rook_file
    else
        rook_file = kingside and castling_config.black_kingside_rook_file or castling_config.black_queenside_rook_file
    end
    return {
        king_start = {rank, king_file},
        rook_start = {rank, rook_file},
        king_target = {rank, kingside and 7 or 3},
        rook_target = {rank, kingside and 6 or 4},
    }
end

local function line_path(start_rank, start_file, target_rank, target_file)
    if start_rank == target_rank and start_file == target_file then
        return {}
    end
    local rank_step = target_rank == start_rank and 0 or (target_rank > start_rank and 1 or -1)
    local file_step = target_file == start_file and 0 or (target_file > start_file and 1 or -1)
    local rank = start_rank + rank_step
    local file = start_file + file_step
    local path = {}
    while rank ~= target_rank or file ~= target_file do
        path[#path + 1] = {rank, file}
        rank = rank + rank_step
        file = file + file_step
    end
    path[#path + 1] = {target_rank, target_file}
    return path
end

local function find_home_rank_piece(is_white, piece_char)
    local rank = is_white and 1 or 8
    local target = is_white and string.upper(piece_char) or string.lower(piece_char)
    for file = 1, 8 do
        if board[rank][file] == target then
            return file
        end
    end
    return nil
end

local function select_rook_file(files, king_file, kingside, fallback)
    local selected = fallback
    local found = false
    for _, file in ipairs(files) do
        if kingside then
            if file > king_file and (not found or file > selected) then
                selected = file
                found = true
            end
        else
            if file < king_file and (not found or file < selected) then
                selected = file
                found = true
            end
        end
    end
    return selected
end

local function configure_chess960_from_board()
    local white_king_file = find_home_rank_piece(true, "K")
    local black_king_file = find_home_rank_piece(false, "K")
    if not white_king_file or not black_king_file then
        castling_config = clone_castling_config({
            white_king_file = 5,
            white_kingside_rook_file = 8,
            white_queenside_rook_file = 1,
            black_king_file = 5,
            black_kingside_rook_file = 8,
            black_queenside_rook_file = 1,
        })
        chess960_mode = false
        return
    end

    local white_rooks = {}
    local black_rooks = {}
    for file = 1, 8 do
        if board[1][file] == "R" then white_rooks[#white_rooks + 1] = file end
        if board[8][file] == "r" then black_rooks[#black_rooks + 1] = file end
    end
    if #white_rooks == 0 or #black_rooks == 0 then
        castling_config = clone_castling_config({
            white_king_file = 5,
            white_kingside_rook_file = 8,
            white_queenside_rook_file = 1,
            black_king_file = 5,
            black_kingside_rook_file = 8,
            black_queenside_rook_file = 1,
        })
        chess960_mode = false
        return
    end

    castling_config = {
        white_king_file = white_king_file,
        white_kingside_rook_file = select_rook_file(white_rooks, white_king_file, true, 8),
        white_queenside_rook_file = select_rook_file(white_rooks, white_king_file, false, 1),
        black_king_file = black_king_file,
        black_kingside_rook_file = select_rook_file(black_rooks, black_king_file, true, 8),
        black_queenside_rook_file = select_rook_file(black_rooks, black_king_file, false, 1),
    }
    chess960_mode = not castling_config_is_classical(castling_config)
end

local function current_castling_fen()
    if chess960_mode then
        local result = ""
        if castling_rights.white_queen then result = result .. string.char(string.byte("A") + castling_config.white_queenside_rook_file - 1) end
        if castling_rights.white_king then result = result .. string.char(string.byte("A") + castling_config.white_kingside_rook_file - 1) end
        if castling_rights.black_queen then result = result .. string.char(string.byte("a") + castling_config.black_queenside_rook_file - 1) end
        if castling_rights.black_king then result = result .. string.char(string.byte("a") + castling_config.black_kingside_rook_file - 1) end
        return result ~= "" and result or "-"
    end

    local castling = ""
    if castling_rights.white_king then castling = castling .. "K" end
    if castling_rights.white_queen then castling = castling .. "Q" end
    if castling_rights.black_king then castling = castling .. "k" end
    if castling_rights.black_queen then castling = castling .. "q" end
    return castling ~= "" and castling or "-"
end

KNIGHT_ATTACKS = build_attack_table(KNIGHT_DELTAS)
KING_ATTACKS = build_attack_table(KING_DELTAS)
for _, dir in ipairs(RAY_DIRECTIONS) do
    RAY_TABLES[dir[1] .. "," .. dir[2]] = build_ray_table(dir[1], dir[2])
end
CHEBYSHEV_DISTANCE = build_distance_table(function(rank_distance, file_distance)
    return math.max(rank_distance, file_distance)
end)
MANHATTAN_DISTANCE = build_distance_table(function(rank_distance, file_distance)
    return rank_distance + file_distance
end)

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
    for _, square in ipairs(knight_attacks(rank, file)) do
        local r, f = square[1], square[2]
        if board[r][f] == knight then
            return true
        end
    end
    
    -- Check king attacks
    local king = by_white and "K" or "k"
    for _, square in ipairs(king_attacks(rank, file)) do
        local r, f = square[1], square[2]
        if board[r][f] == king then
            return true
        end
    end
    
    -- Check sliding pieces (bishop, rook, queen)
    local directions = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},  -- rook directions
        {1, 1}, {1, -1}, {-1, 1}, {-1, -1}  -- bishop directions
    }
    
    for _, dir in ipairs(directions) do
        for _, square in ipairs(ray_attacks(rank, file, dir[1], dir[2])) do
            local r, f = square[1], square[2]
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
    
    -- Save irreversible state
    table.insert(irreversible_history, {
        castling_rights = {white_king = castling_rights.white_king, white_queen = castling_rights.white_queen,
                          black_king = castling_rights.black_king, black_queen = castling_rights.black_queen},
        castling_config = clone_castling_config(castling_config),
        chess960_mode = chess960_mode,
        en_passant_target = en_passant_target and {en_passant_target[1], en_passant_target[2]} or nil,
        halfmove_clock = halfmove_clock,
        zobrist_hash = zobrist_hash
    })
    table.insert(position_history, zobrist_hash)

    local hash = zobrist_hash
    
    -- 1. Remove moving piece from source
    hash = hash ~ zobrist_keys.pieces[get_piece_index(piece)][(from_rank - 1) * 8 + from_file]

    -- Handle capture
    local move_record = {
        from_rank = from_rank, from_file = from_file,
        to_rank = to_rank, to_file = to_file,
        piece = piece, captured = captured,
        white_to_move = white_to_move,
        promotion = promotion
    }
    local castle_details = nil
    local is_castling = string.upper(piece) == "K" and from_rank == to_rank and (to_file == 3 or to_file == 7)

    if en_passant_target and to_rank == en_passant_target[1] and to_file == en_passant_target[2] then
        if piece == "P" or piece == "p" then
            local capture_rank = (piece == "P") and to_rank - 1 or to_rank + 1
            local ep_captured = board[capture_rank][to_file]
            hash = hash ~ zobrist_keys.pieces[get_piece_index(ep_captured)][(capture_rank - 1) * 8 + to_file]
            board[capture_rank][to_file] = "."
            move_record.en_passant_captured = ep_captured
        end
    elseif (not is_castling) and captured ~= "." then
        hash = hash ~ zobrist_keys.pieces[get_piece_index(captured)][(to_rank - 1) * 8 + to_file]
    end

    -- 3. Place piece at destination
    local final_piece = piece
    if promotion then
        final_piece = promotion
    elseif (piece == "P" and to_rank == 8) or (piece == "p" and to_rank == 1) then
        final_piece = white_to_move and "Q" or "q"
        move_record.promotion = final_piece
    end
    hash = hash ~ zobrist_keys.pieces[get_piece_index(final_piece)][(to_rank - 1) * 8 + to_file]
    board[to_rank][to_file] = final_piece
    board[from_rank][from_file] = "."

    -- 4. Handle castling rook
    if is_castling then
        castle_details = get_castle_details(piece == "K", to_file == 7)
        local rook = board[castle_details.rook_start[1]][castle_details.rook_start[2]]
        hash = hash ~ zobrist_keys.pieces[get_piece_index(rook)][(castle_details.rook_start[1] - 1) * 8 + castle_details.rook_start[2]]
        hash = hash ~ zobrist_keys.pieces[get_piece_index(rook)][(castle_details.rook_target[1] - 1) * 8 + castle_details.rook_target[2]]
        if not (castle_details.rook_start[1] == from_rank and castle_details.rook_start[2] == from_file) and
           not (castle_details.rook_start[1] == to_rank and castle_details.rook_start[2] == to_file) then
            board[castle_details.rook_start[1]][castle_details.rook_start[2]] = "."
        end
        board[castle_details.rook_target[1]][castle_details.rook_target[2]] = rook
        move_record.castling = to_file == 7 and "kingside" or "queenside"
    end

    if castling_rights.white_king then hash = hash ~ zobrist_keys.castling[1] end
    if castling_rights.white_queen then hash = hash ~ zobrist_keys.castling[2] end
    if castling_rights.black_king then hash = hash ~ zobrist_keys.castling[3] end
    if castling_rights.black_queen then hash = hash ~ zobrist_keys.castling[4] end

    if piece == "K" then
        castling_rights.white_king = false
        castling_rights.white_queen = false
    elseif piece == "k" then
        castling_rights.black_king = false
        castling_rights.black_queen = false
    elseif piece == "R" then
        if from_rank == 1 and from_file == castling_config.white_queenside_rook_file then castling_rights.white_queen = false end
        if from_rank == 1 and from_file == castling_config.white_kingside_rook_file then castling_rights.white_king = false end
    elseif piece == "r" then
        if from_rank == 8 and from_file == castling_config.black_queenside_rook_file then castling_rights.black_queen = false end
        if from_rank == 8 and from_file == castling_config.black_kingside_rook_file then castling_rights.black_king = false end
    end
    if to_rank == 1 and to_file == castling_config.white_queenside_rook_file then castling_rights.white_queen = false end
    if to_rank == 1 and to_file == castling_config.white_kingside_rook_file then castling_rights.white_king = false end
    if to_rank == 8 and to_file == castling_config.black_queenside_rook_file then castling_rights.black_queen = false end
    if to_rank == 8 and to_file == castling_config.black_kingside_rook_file then castling_rights.black_king = false end

    if castling_rights.white_king then hash = hash ~ zobrist_keys.castling[1] end
    if castling_rights.white_queen then hash = hash ~ zobrist_keys.castling[2] end
    if castling_rights.black_king then hash = hash ~ zobrist_keys.castling[3] end
    if castling_rights.black_queen then hash = hash ~ zobrist_keys.castling[4] end

    -- 6. Update en passant target in hash
    if en_passant_target then
        hash = hash ~ zobrist_keys.en_passant[en_passant_target[2]]
    end
    
    en_passant_target = nil
    if (piece == "P" and from_rank == 2 and to_rank == 4) or
       (piece == "p" and from_rank == 7 and to_rank == 5) then
        local ep_rank = white_to_move and 3 or 6
        en_passant_target = {ep_rank, from_file}
        hash = hash ~ zobrist_keys.en_passant[from_file]
    end
    
    -- 7. Update active color and clocks
    hash = hash ~ zobrist_keys.side_to_move
    if captured ~= "." or move_record.en_passant_captured or piece == "P" or piece == "p" then
        halfmove_clock = 0
    else
        halfmove_clock = halfmove_clock + 1
    end
    
    white_to_move = not white_to_move
    if white_to_move then
        fullmove_number = fullmove_number + 1
    end
    
    zobrist_hash = hash
    table.insert(move_history, move_record)
    
    return true
end

-- Undo last move
local function undo_move()
    if #move_history == 0 then return false end
    
    local move = table.remove(move_history)
    local old = table.remove(irreversible_history)
    table.remove(position_history)
    
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
        local details = get_castle_details(move.piece == "K", true)
        board[details.rook_start[1]][details.rook_start[2]] = board[details.rook_target[1]][details.rook_target[2]]
        if not (details.rook_target[1] == move.from_rank and details.rook_target[2] == move.from_file) then
            board[details.rook_target[1]][details.rook_target[2]] = "."
        end
    elseif move.castling == "queenside" then
        local details = get_castle_details(move.piece == "K", false)
        board[details.rook_start[1]][details.rook_start[2]] = board[details.rook_target[1]][details.rook_target[2]]
        if not (details.rook_target[1] == move.from_rank and details.rook_target[2] == move.from_file) then
            board[details.rook_target[1]][details.rook_target[2]] = "."
        end
    end
    
    -- Restore state
    castling_rights = old.castling_rights
    castling_config = old.castling_config
    chess960_mode = old.chess960_mode
    en_passant_target = old.en_passant_target
    halfmove_clock = old.halfmove_clock
    zobrist_hash = old.zobrist_hash
    white_to_move = move.white_to_move
    if white_to_move == false then -- It was black's turn to move, so it became white's turn. Fullmove was incremented.
        fullmove_number = fullmove_number - 1
    end
    
    return true
end

local function get_repetition_count()
    local count = 1
    local start_idx = math.max(1, #position_history - halfmove_clock + 1)
    for i = #position_history, start_idx, -1 do
        if position_history[i] == zobrist_hash then
            count = count + 1
        end
    end
    return count
end

local function is_draw_by_repetition()
    return get_repetition_count() >= 3
end

local function is_draw_by_fifty_moves()
    return halfmove_clock >= 100
end

local function is_draw()
    return is_draw_by_repetition() or is_draw_by_fifty_moves()
end
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
        elseif dr == 0 and (to_file == 3 or to_file == 7) then
            local kingside = to_file == 7
            if is_white and not (castling_rights.white_king and kingside or castling_rights.white_queen and not kingside) then
                return false, "Cannot castle"
            end
            if (not is_white) and not (castling_rights.black_king and kingside or castling_rights.black_queen and not kingside) then
                return false, "Cannot castle"
            end
            local details = get_castle_details(is_white, kingside)
            if from_rank ~= details.king_start[1] or from_file ~= details.king_start[2] then
                return false, "Illegal king move"
            end
            local rook_piece = board[details.rook_start[1]][details.rook_start[2]]
            if rook_piece == "." or string.upper(rook_piece) ~= "R" or (rook_piece == string.upper(rook_piece)) ~= is_white then
                return false, "Cannot castle"
            end

            local seen = {}
            for _, square in ipairs(line_path(details.king_start[1], details.king_start[2], details.king_target[1], details.king_target[2])) do
                seen[square[1] .. ":" .. square[2]] = square
            end
            for _, square in ipairs(line_path(details.rook_start[1], details.rook_start[2], details.rook_target[1], details.rook_target[2])) do
                seen[square[1] .. ":" .. square[2]] = square
            end
            for _, square in pairs(seen) do
                if not (square[1] == details.king_start[1] and square[2] == details.king_start[2]) and
                   not (square[1] == details.rook_start[1] and square[2] == details.rook_start[2]) and
                   board[square[1]][square[2]] ~= "." then
                    return false, "Path blocked"
                end
            end

            if is_in_check(is_white) then
                return false, "Cannot castle through check"
            end
            local attack_seen = {}
            attack_seen[details.king_start[1] .. ":" .. details.king_start[2]] = details.king_start
            for _, square in ipairs(line_path(details.king_start[1], details.king_start[2], details.king_target[1], details.king_target[2])) do
                attack_seen[square[1] .. ":" .. square[2]] = square
            end
            for _, square in pairs(attack_seen) do
                if is_square_attacked(square[1], square[2], not is_white) then
                    return false, "Cannot castle through check"
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
local function execute_move(move_str, options)
    options = options or {}
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
    
    local piece = board[from_rank][from_file]
    if piece == "." then return false, "ERROR: No piece at source square" end
    
    -- Auto-promote to Queen if not specified
    if not promotion_piece and string.upper(piece) == "P" then
        if (white_to_move and to_rank == 8) or (not white_to_move and to_rank == 1) then
            promotion_piece = white_to_move and "Q" or "q"
        end
    end

    if promotion_piece then
        promotion_piece = white_to_move and string.upper(promotion_piece) or string.lower(promotion_piece)
    end
    
    local legal, msg = is_legal_move(from_rank, from_file, to_rank, to_file, promotion_piece)
    if not legal then
        return false, "ERROR: " .. msg
    end

    local resolved = {from_rank, from_file, to_rank, to_file, promotion_piece}
    if options.record_pgn == false then
        make_move_internal(from_rank, from_file, to_rank, to_file, promotion_piece)
    else
        record_pgn_move(resolved)
    end
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
    fen = fen .. " " .. current_castling_fen()
    
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
    configure_chess960_from_board()
    chess960_mode = false
    if parts[3] ~= "-" then
        for i = 1, #parts[3] do
            local c = string.sub(parts[3], i, i)
            if c == "K" then castling_rights.white_king = true
            elseif c == "Q" then castling_rights.white_queen = true
            elseif c == "k" then castling_rights.black_king = true
            elseif c == "q" then castling_rights.black_queen = true
            elseif c >= "A" and c <= "H" then
                local rook_file = string.byte(c) - string.byte("A") + 1
                chess960_mode = true
                if rook_file > castling_config.white_king_file then
                    castling_rights.white_king = true
                    castling_config.white_kingside_rook_file = rook_file
                else
                    castling_rights.white_queen = true
                    castling_config.white_queenside_rook_file = rook_file
                end
            elseif c >= "a" and c <= "h" then
                local rook_file = string.byte(c) - string.byte("a") + 1
                chess960_mode = true
                if rook_file > castling_config.black_king_file then
                    castling_rights.black_king = true
                    castling_config.black_kingside_rook_file = rook_file
                else
                    castling_rights.black_queen = true
                    castling_config.black_queenside_rook_file = rook_file
                end
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
    position_history = {}
    irreversible_history = {}
    zobrist_hash = compute_hash()
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
    search_eval_calls = search_eval_calls + 1
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
local function move_key(move)
    local promo = move[5] or ""
    return string.format("%d:%d:%d:%d:%s", move[1], move[2], move[3], move[4], promo)
end

local function search_time_exceeded()
    if search_stop_requested then
        search_timed_out = true
        return true
    end
    if not search_deadline then
        return false
    end
    if os.clock() >= search_deadline then
        search_timed_out = true
        return true
    end
    return false
end

local function order_moves(moves, tt_move_key)
    local scored = {}
    for _, move in ipairs(moves) do
        local score = 0
        if tt_move_key and move_key(move) == tt_move_key then
            score = score + 100000
        end
        local target = board[move[3]][move[4]]
        if target and target ~= "." then
            score = score + 10000 + math.abs(PIECE_VALUES[target] or 0)
        end
        if move[5] then
            score = score + 9000 + math.abs(PIECE_VALUES[move[5]] or 0)
        end
        table.insert(scored, {move = move, score = score})
    end
    table.sort(scored, function(a, b) return a.score > b.score end)

    local ordered = {}
    for _, item in ipairs(scored) do
        table.insert(ordered, item.move)
    end
    return ordered
end

local function negamax(depth, alpha, beta)
    if search_time_exceeded() then
        return 0, nil, false
    end
    search_nodes_visited = search_nodes_visited + 1

    if is_draw() then
        return 0, nil, true
    end

    local original_alpha = alpha
    local key = string.format("%u", zobrist_hash)
    local best_from_tt = nil
    local entry = tt[key]

    if entry and entry.depth >= depth then
        search_tt_hits = search_tt_hits + 1
        if entry.flag == "exact" then
            return entry.score, entry.best_move_key, true
        elseif entry.flag == "lower" then
            alpha = math.max(alpha, entry.score)
        elseif entry.flag == "upper" then
            beta = math.min(beta, entry.score)
        end
        if alpha >= beta then
            search_beta_cutoffs = search_beta_cutoffs + 1
            return entry.score, entry.best_move_key, true
        end
        best_from_tt = entry.best_move_key
    else
        search_tt_misses = search_tt_misses + 1
    end

    if depth == 0 then
        local eval = evaluate_position()
        if not white_to_move then
            eval = -eval
        end
        return eval, nil, true
    end

    local moves = generate_legal_moves()
    if #moves == 0 then
        if is_in_check(white_to_move) then
            return -100000 + depth, nil, true
        end
        return 0, nil, true
    end

    local ordered = order_moves(moves, best_from_tt)
    local best_score = -math.huge
    local best_move_key = move_key(ordered[1])

    for _, move in ipairs(ordered) do
        if search_time_exceeded() then
            return 0, nil, false
        end
        make_move_internal(move[1], move[2], move[3], move[4], move[5])
        local score, _, ok = negamax(depth - 1, -beta, -alpha)
        undo_move()
        if not ok then
            return 0, nil, false
        end
        score = -score

        if score > best_score then
            best_score = score
            best_move_key = move_key(move)
        end
        if score > alpha then
            alpha = score
        end
        if alpha >= beta then
            search_beta_cutoffs = search_beta_cutoffs + 1
            break
        end
    end

    local flag = "exact"
    if best_score <= original_alpha then
        flag = "upper"
    elseif best_score >= beta then
        flag = "lower"
    end
    tt[key] = {
        depth = depth,
        score = best_score,
        flag = flag,
        best_move_key = best_move_key
    }

    return best_score, best_move_key, true
end

local function search_root(depth)
    if search_time_exceeded() then
        return 0, nil, false
    end
    search_nodes_visited = search_nodes_visited + 1

    local moves = generate_legal_moves()
    if #moves == 0 then
        return 0, nil, true
    end

    local entry = tt[string.format("%u", zobrist_hash)]
    if entry then
        search_tt_hits = search_tt_hits + 1
    else
        search_tt_misses = search_tt_misses + 1
    end
    local ordered = order_moves(moves, entry and entry.best_move_key or nil)
    local best_score = -math.huge
    local best_move = ordered[1]
    local alpha = -math.huge
    local beta = math.huge

    for _, move in ipairs(ordered) do
        if search_time_exceeded() then
            return 0, nil, false
        end
        make_move_internal(move[1], move[2], move[3], move[4], move[5])
        local score, _, ok = negamax(depth - 1, -beta, -alpha)
        undo_move()
        if not ok then
            return 0, nil, false
        end
        score = -score

        if score > best_score then
            best_score = score
            best_move = move
        end
        if score > alpha then
            alpha = score
        end
    end

    return best_score, best_move, true
end

local function search_best_move(max_depth, movetime_ms)
    max_depth = tonumber(max_depth) or 3
    if max_depth < 1 then max_depth = 1 end
    if max_depth > 5 then max_depth = 5 end

    local legal_moves = generate_legal_moves()
    if #legal_moves == 0 then
        return nil, 0, 0, 0, false, 0, 0, 0, 0, 0
    end

    local start_clock = os.clock()
    search_timed_out = false
    search_stop_requested = false
    search_nodes_visited = 0
    search_eval_calls = 0
    search_tt_hits = 0
    search_tt_misses = 0
    search_beta_cutoffs = 0
    search_deadline = nil
    if movetime_ms and movetime_ms > 0 then
        search_deadline = start_clock + (movetime_ms / 1000.0)
    end

    local best_move = legal_moves[1]
    local best_score = evaluate_position()
    if not white_to_move then
        best_score = -best_score
    end
    local completed_depth = 0

    for depth = 1, max_depth do
        local score, move, complete = search_root(depth)
        if not complete then
            break
        end
        if move then
            best_move = move
            best_score = score
            completed_depth = depth
        end
    end

    if completed_depth == 0 then
        completed_depth = 1
    end

    local elapsed = math.floor((os.clock() - start_clock) * 1000)
    return best_move, best_score, completed_depth, elapsed, search_timed_out, search_nodes_visited, search_eval_calls, search_tt_hits, search_tt_misses, search_beta_cutoffs
end

-- AI move
local function ai_move(max_depth, movetime_ms)
    max_depth = tonumber(max_depth) or 3
    if max_depth < 1 or max_depth > 5 then
        return false, "ERROR: AI depth must be 1-5"
    end

    local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(max_depth, movetime_ms or 0)
    if not best_move then
        return false, "ERROR: No legal moves"
    end
    
    local move_str = indices_to_algebraic(best_move[1], best_move[2]) .. 
                     indices_to_algebraic(best_move[3], best_move[4])
    if best_move[5] then
        move_str = move_str .. best_move[5]
    end

    record_pgn_move(best_move)
    record_trace_ai("search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
    
    return true, string.format("AI: %s (depth=%d, eval=%d, time=%d)", move_str, depth_used, eval, elapsed)
end

local function derive_movetime_from_clock_args(tokens)
    local values = {winc = 0, binc = 0, movestogo = 30}

    local i = 1
    while i <= #tokens do
        local key = tokens[i]:lower()
        local value_raw = tokens[i + 1]
        if not value_raw then
            return nil, string.format("go %s requires a value", key)
        end
        local value = tonumber(value_raw)
        if not value then
            return nil, string.format("go %s requires an integer value", key)
        end

        if key ~= "wtime" and key ~= "btime" and key ~= "winc" and key ~= "binc" and key ~= "movestogo" then
            return nil, string.format("unsupported go parameter: %s", key)
        end
        values[key] = math.floor(value)
        i = i + 2
    end

    if not values.wtime or not values.btime then
        return nil, "go wtime/btime parameters are required"
    end
    if values.wtime <= 0 or values.btime <= 0 then
        return nil, "go wtime/btime must be > 0"
    end
    if values.movestogo <= 0 then
        values.movestogo = 30
    end

    local base = white_to_move and values.wtime or values.btime
    local inc = white_to_move and values.winc or values.binc
    local budget = math.floor(base / (values.movestogo + 1) + inc / 2)

    if budget < 50 then
        budget = 50
    end
    if budget >= base then
        budget = math.floor(base / 2)
    end
    if budget <= 0 then
        return nil, "unable to derive positive movetime from clocks"
    end

    return budget, nil
end

local function book_position_key_from_fen(fen)
    local fields = {}
    for token in tostring(fen):gmatch("%S+") do
        table.insert(fields, token)
    end
    if #fields >= 4 then
        return table.concat({fields[1], fields[2], fields[3], fields[4]}, " ")
    end
    return tostring(fen):gsub("^%s*(.-)%s*$", "%1")
end

local function parse_book_entries(content)
    local parsed = {}
    local total_entries = 0
    local line_no = 0

    for raw_line in tostring(content):gmatch("[^\r\n]+") do
        line_no = line_no + 1
        local line = raw_line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" and not line:match("^#") then
            local left, right = line:match("^(.-)%s*%-%>%s*(.+)$")
            if not left or not right then
                return nil, nil, string.format("line %d: expected '<fen> -> <move> [weight]'", line_no)
            end

            local key = book_position_key_from_fen(left)
            if key == "" then
                return nil, nil, string.format("line %d: empty position key", line_no)
            end

            local rhs_tokens = {}
            for token in right:gmatch("%S+") do
                table.insert(rhs_tokens, token)
            end
            if #rhs_tokens == 0 then
                return nil, nil, string.format("line %d: missing move", line_no)
            end

            local move = rhs_tokens[1]:lower()
            if not move:match("^[a-h][1-8][a-h][1-8][qrbn]?$") then
                return nil, nil, string.format("line %d: invalid move '%s'", line_no, move)
            end

            local weight = 1
            if rhs_tokens[2] then
                local parsed_weight = tonumber(rhs_tokens[2])
                if not parsed_weight or parsed_weight % 1 ~= 0 then
                    return nil, nil, string.format("line %d: invalid weight '%s'", line_no, rhs_tokens[2])
                end
                if parsed_weight <= 0 then
                    return nil, nil, string.format("line %d: weight must be > 0", line_no)
                end
                weight = math.floor(parsed_weight)
            end

            if not parsed[key] then
                parsed[key] = {}
            end
            table.insert(parsed[key], {move = move, weight = weight})
            total_entries = total_entries + 1
        end
    end

    return parsed, total_entries, nil
end

local function book_positions_count()
    local count = 0
    for _ in pairs(book_entries) do
        count = count + 1
    end
    return count
end

local function choose_book_move()
    book_lookups = book_lookups + 1
    if not book_enabled or next(book_entries) == nil then
        book_misses = book_misses + 1
        return nil, nil
    end

    local key = book_position_key_from_fen(export_fen())
    local entries = book_entries[key]
    if not entries or #entries == 0 then
        book_misses = book_misses + 1
        return nil, nil
    end

    local legal_moves = generate_legal_moves()
    local legal_by_notation = {}
    for _, move in ipairs(legal_moves) do
        local notation = indices_to_algebraic(move[1], move[2]) .. indices_to_algebraic(move[3], move[4])
        if move[5] then
            notation = notation .. tostring(move[5])
        end
        legal_by_notation[notation:lower()] = move
    end

    local weighted = {}
    local total_weight = 0
    for _, entry in ipairs(entries) do
        local legal = legal_by_notation[entry.move]
        if legal then
            local weight = tonumber(entry.weight) or 1
            if weight <= 0 then weight = 1 end
            weight = math.floor(weight)
            table.insert(weighted, {move = legal, notation = entry.move, weight = weight})
            total_weight = total_weight + weight
        end
    end

    if #weighted == 0 or total_weight <= 0 then
        book_misses = book_misses + 1
        return nil, nil
    end

    local selector = (math.abs(zobrist_hash) + book_lookups) % total_weight
    local acc = 0
    local chosen = weighted[1]
    for _, item in ipairs(weighted) do
        acc = acc + item.weight
        if selector < acc then
            chosen = item
            break
        end
    end

    book_hits = book_hits + 1
    return chosen.move, chosen.notation
end

local function apply_book_move(best_move, move_str)
    if not best_move then
        return false
    end

    record_pgn_move(best_move)
    book_played = book_played + 1
    record_trace_ai("book", move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
    print("AI: " .. move_str .. " (book)")
    display_board()

    local legal_moves = generate_legal_moves()
    if #legal_moves == 0 then
        if is_in_check(white_to_move) then
            print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
        else
            print("STALEMATE: Draw")
        end
    elseif is_draw() then
        local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
        print("DRAW: by " .. reason)
    end

    return true
end

local function color_name(is_white)
    return is_white and "white" or "black"
end

local function non_king_material(counts)
    return (counts.P or 0) + (counts.N or 0) + (counts.B or 0) + (counts.R or 0) + (counts.Q or 0)
end

local function detect_endgame_state()
    local counts = {
        white = {P = 0, N = 0, B = 0, R = 0, Q = 0, K = 0},
        black = {P = 0, N = 0, B = 0, R = 0, Q = 0, K = 0},
    }
    local kings = {}
    local pawns = {}
    local rooks = {}
    local queens = {}

    for rank = 1, 8 do
        for file = 1, 8 do
            local piece = board[rank][file]
            if piece ~= "." then
                local upper = piece:upper()
                local is_white = piece:match("%u") ~= nil
                local color = is_white and "white" or "black"
                counts[color][upper] = (counts[color][upper] or 0) + 1
                if upper == "K" then
                    kings[color] = {rank, file}
                elseif upper == "P" and not pawns[color] then
                    pawns[color] = {rank, file}
                elseif upper == "R" and not rooks[color] then
                    rooks[color] = {rank, file}
                elseif upper == "Q" and not queens[color] then
                    queens[color] = {rank, file}
                end
            end
        end
    end

    if not kings.white or not kings.black then
        return nil
    end

    local white_material = non_king_material(counts.white)
    local black_material = non_king_material(counts.black)

    -- KQK
    if counts.white.Q == 1 and white_material == 1 and black_material == 0 then
        local weak_king = kings.black
        local strong_king = kings.white
        local edge = math.min(weak_king[1] - 1, 8 - weak_king[1], weak_king[2] - 1, 8 - weak_king[2])
        local king_distance = manhattan_distance(strong_king[1], strong_king[2], weak_king[1], weak_king[2])
        local score = 900 + (14 - king_distance) * 6 + (3 - edge) * 20
        return {
            type = "KQK",
            strong_white = true,
            weak_white = false,
            score_white = score,
            detail = "queen=" .. indices_to_algebraic(queens.white[1], queens.white[2]),
        }
    end
    if counts.black.Q == 1 and black_material == 1 and white_material == 0 then
        local weak_king = kings.white
        local strong_king = kings.black
        local edge = math.min(weak_king[1] - 1, 8 - weak_king[1], weak_king[2] - 1, 8 - weak_king[2])
        local king_distance = manhattan_distance(strong_king[1], strong_king[2], weak_king[1], weak_king[2])
        local score = 900 + (14 - king_distance) * 6 + (3 - edge) * 20
        return {
            type = "KQK",
            strong_white = false,
            weak_white = true,
            score_white = -score,
            detail = "queen=" .. indices_to_algebraic(queens.black[1], queens.black[2]),
        }
    end

    -- KPK
    if counts.white.P == 1 and white_material == 1 and black_material == 0 then
        local pawn = pawns.white
        local strong_king = kings.white
        local weak_king = kings.black
        local promotion_rank, promotion_file = 8, pawn[2]
        local pawn_steps = 8 - pawn[1]
        local score = 120 + (6 - pawn_steps) * 35 +
            manhattan_distance(weak_king[1], weak_king[2], promotion_rank, promotion_file) * 6 -
            manhattan_distance(strong_king[1], strong_king[2], pawn[1], pawn[2]) * 8
        if pawn_steps <= 1 then
            score = score + 80
        end
        if score < 30 then
            score = 30
        end
        return {
            type = "KPK",
            strong_white = true,
            weak_white = false,
            score_white = score,
            detail = "pawn=" .. indices_to_algebraic(pawn[1], pawn[2]),
        }
    end
    if counts.black.P == 1 and black_material == 1 and white_material == 0 then
        local pawn = pawns.black
        local strong_king = kings.black
        local weak_king = kings.white
        local promotion_rank, promotion_file = 1, pawn[2]
        local pawn_steps = pawn[1] - 1
        local score = 120 + (6 - pawn_steps) * 35 +
            manhattan_distance(weak_king[1], weak_king[2], promotion_rank, promotion_file) * 6 -
            manhattan_distance(strong_king[1], strong_king[2], pawn[1], pawn[2]) * 8
        if pawn_steps <= 1 then
            score = score + 80
        end
        if score < 30 then
            score = 30
        end
        return {
            type = "KPK",
            strong_white = false,
            weak_white = true,
            score_white = -score,
            detail = "pawn=" .. indices_to_algebraic(pawn[1], pawn[2]),
        }
    end

    -- KRKP
    if counts.white.R == 1 and white_material == 1 and counts.black.P == 1 and black_material == 1 then
        local strong_king = kings.white
        local weak_king = kings.black
        local weak_pawn = pawns.black
        local pawn_steps = weak_pawn[1] - 1
        local score = 380 - pawn_steps * 25 +
            (manhattan_distance(weak_king[1], weak_king[2], weak_pawn[1], weak_pawn[2]) -
                manhattan_distance(strong_king[1], strong_king[2], weak_pawn[1], weak_pawn[2])) * 12
        if score < 50 then
            score = 50
        end
        return {
            type = "KRKP",
            strong_white = true,
            weak_white = false,
            score_white = score,
            detail = "rook=" .. indices_to_algebraic(rooks.white[1], rooks.white[2]) ..
                ",pawn=" .. indices_to_algebraic(weak_pawn[1], weak_pawn[2]),
        }
    end
    if counts.black.R == 1 and black_material == 1 and counts.white.P == 1 and white_material == 1 then
        local strong_king = kings.black
        local weak_king = kings.white
        local weak_pawn = pawns.white
        local pawn_steps = 8 - weak_pawn[1]
        local score = 380 - pawn_steps * 25 +
            (manhattan_distance(weak_king[1], weak_king[2], weak_pawn[1], weak_pawn[2]) -
                manhattan_distance(strong_king[1], strong_king[2], weak_pawn[1], weak_pawn[2])) * 12
        if score < 50 then
            score = 50
        end
        return {
            type = "KRKP",
            strong_white = false,
            weak_white = true,
            score_white = -score,
            detail = "rook=" .. indices_to_algebraic(rooks.black[1], rooks.black[2]) ..
                ",pawn=" .. indices_to_algebraic(weak_pawn[1], weak_pawn[2]),
        }
    end

    return nil
end

local function choose_endgame_move()
    local root_info = detect_endgame_state()
    if not root_info then
        return nil, nil, nil
    end

    local legal_moves = generate_legal_moves()
    if #legal_moves == 0 then
        return nil, nil, nil
    end

    local root_white = white_to_move
    local best_move = legal_moves[1]
    local best_move_str = indices_to_algebraic(best_move[1], best_move[2]) .. indices_to_algebraic(best_move[3], best_move[4])
    if best_move[5] then
        best_move_str = best_move_str .. best_move[5]
    end
    best_move_str = best_move_str:lower()
    local best_score = -math.huge

    for _, candidate in ipairs(legal_moves) do
        make_move_internal(candidate[1], candidate[2], candidate[3], candidate[4], candidate[5])
        local next_info = detect_endgame_state()
        local score = next_info and next_info.score_white or evaluate_position()
        if not root_white then
            score = -score
        end
        local move_str = indices_to_algebraic(candidate[1], candidate[2]) .. indices_to_algebraic(candidate[3], candidate[4])
        if candidate[5] then
            move_str = move_str .. candidate[5]
        end
        move_str = move_str:lower()
        if score > best_score or (score == best_score and move_str < best_move_str) then
            best_score = score
            best_move = candidate
            best_move_str = move_str
        end
        undo_move()
    end

    return best_move, root_info, best_move_str
end

local function apply_endgame_move(best_move, info, move_str)
    if not best_move then
        return false
    end

    record_pgn_move(best_move)
    record_trace_ai("endgame", move_str, 0, info.score_white, 0, false, 0, 0, 0, 0, 0)
    print(string.format("AI: %s (endgame %s, score=%d)", move_str, info.type, info.score_white))
    display_board()

    local legal_moves = generate_legal_moves()
    if #legal_moves == 0 then
        if is_in_check(white_to_move) then
            print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
        else
            print("STALEMATE: Draw")
        end
    elseif is_draw() then
        local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
        print("DRAW: by " .. reason)
    end

    return true
end

local function trim(value)
    return tostring(value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function copy_move_array(move)
    return {move[1], move[2], move[3], move[4], move[5]}
end

local function moves_equal(a, b)
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
end

local function is_move_castling(move)
    local piece = board[move[1]][move[2]]
    return (piece == "K" or piece == "k") and math.abs(move[4] - move[2]) == 2
end

local function is_move_en_passant(move)
    local piece = board[move[1]][move[2]]
    return en_passant_target ~= nil and
        (piece == "P" or piece == "p") and
        move[3] == en_passant_target[1] and
        move[4] == en_passant_target[2] and
        board[move[3]][move[4]] == "." and
        move[2] ~= move[4]
end

local function pgn_piece_letter(piece)
    local upper = tostring(piece or ""):upper()
    if upper == "P" then
        return ""
    end
    return upper
end

local function normalize_san(token)
    local cleaned = trim(token)
    cleaned = cleaned:gsub("^(%d+)%.%.%.", "")
    cleaned = cleaned:gsub("^(%d+)%.", "")
    cleaned = cleaned:gsub("[!?]+$", "")
    cleaned = cleaned:gsub("[+#]+$", "")
    cleaned = cleaned:gsub("0%-0%-0", "O-O-O")
    cleaned = cleaned:gsub("0%-0", "O-O")
    cleaned = cleaned:gsub("e%.p%.", "")
    cleaned = cleaned:gsub("ep", "")
    return trim(cleaned)
end

local function move_disambiguation(move)
    local piece = board[move[1]][move[2]]
    local clash_found = false
    local same_file = false
    local same_rank = false

    for _, candidate in ipairs(generate_legal_moves()) do
        if not moves_equal(candidate, move) then
            local candidate_piece = board[candidate[1]][candidate[2]]
            if candidate_piece == piece and candidate[3] == move[3] and candidate[4] == move[4] then
                clash_found = true
                if candidate[2] == move[2] then
                    same_file = true
                end
                if candidate[1] == move[1] then
                    same_rank = true
                end
            end
        end
    end

    if not clash_found then
        return ""
    end
    if not same_file then
        return string.char(string.byte("a") + move[2] - 1)
    end
    if not same_rank then
        return tostring(move[1])
    end
    return string.char(string.byte("a") + move[2] - 1) .. tostring(move[1])
end

local function move_to_san(move)
    local piece = board[move[1]][move[2]]
    if piece == "." then
        error("missing moving piece for SAN serialization")
    end

    local san
    local capture = board[move[3]][move[4]] ~= "." or is_move_en_passant(move)
    if is_move_castling(move) then
        san = move[4] == 7 and "O-O" or "O-O-O"
    else
        local destination = indices_to_algebraic(move[3], move[4])
        local promotion = move[5] and ("=" .. pgn_piece_letter(move[5])) or ""
        if piece:upper() == "P" then
            if capture then
                san = string.char(string.byte("a") + move[2] - 1) .. "x" .. destination .. promotion
            else
                san = destination .. promotion
            end
        else
            local prefix = pgn_piece_letter(piece) .. move_disambiguation(move)
            if capture then
                prefix = prefix .. "x"
            end
            san = prefix .. destination .. promotion
        end
    end

    make_move_internal(move[1], move[2], move[3], move[4], move[5])
    local replies = generate_legal_moves()
    if is_in_check(white_to_move) then
        san = san .. ((#replies == 0) and "#" or "+")
    end
    undo_move()

    return san
end

local function san_to_move(san)
    local normalized = normalize_san(san)
    for _, move in ipairs(generate_legal_moves()) do
        if normalize_san(move_to_san(move)) == normalized then
            return copy_move_array(move)
        end
    end
    error("unresolved SAN move: " .. tostring(san))
end

local function starting_ply_from_fen(fen)
    local parts = {}
    for token in tostring(fen or ""):gmatch("%S+") do
        table.insert(parts, token)
    end

    local move_number = tonumber(parts[6]) or 1
    local side = (parts[2] == "b") and "black" or "white"
    return math.max(1, move_number), side
end

local function serialize_sequence(sequence, move_number, side)
    local parts = {}
    local current_number = move_number
    local current_side = side

    for _, node in ipairs(sequence) do
        if current_side == "white" then
            table.insert(parts, tostring(current_number) .. ". " .. node.san)
        else
            local last = parts[#parts]
            if not last or not last:match("^" .. tostring(current_number) .. "%.%s") then
                table.insert(parts, tostring(current_number) .. "... " .. node.san)
            else
                table.insert(parts, node.san)
            end
        end

        for _, nag in ipairs(node.nags) do
            table.insert(parts, nag)
        end
        for _, comment in ipairs(node.comments) do
            table.insert(parts, "{" .. comment .. "}")
        end
        for _, variation in ipairs(node.variations) do
            table.insert(parts, "(" .. serialize_sequence(variation, current_number, current_side) .. ")")
        end

        if current_side == "black" then
            current_number = current_number + 1
            current_side = "white"
        else
            current_side = "black"
        end
    end

    return trim(table.concat(parts, " "))
end

local function serialize_game(game)
    local lines = {}
    for _, tag in ipairs(game.tag_order) do
        local value = tostring(game.tags[tag] or ""):gsub('"', '\\"')
        table.insert(lines, string.format("[%s \"%s\"]", tag, value))
    end
    if #lines > 0 then
        table.insert(lines, "")
    end

    local move_number, side = starting_ply_from_fen(game.initial_fen)
    local move_text = serialize_sequence(game.moves, move_number, side)
    if #game.initial_comments > 0 then
        local comments = {}
        for _, comment in ipairs(game.initial_comments) do
            table.insert(comments, "{" .. comment .. "}")
        end
        move_text = trim(table.concat(comments, " ") .. " " .. move_text)
    end
    if game.result and game.result ~= "" then
        move_text = trim(move_text .. " " .. game.result)
    end
    table.insert(lines, move_text ~= "" and move_text or (game.result or "*"))

    return trim(table.concat(lines, "\n")) .. "\n"
end

local function tokenize_pgn(content)
    local tokens = {}
    local length = #content
    local index = 1
    local result_tokens = {
        ["1-0"] = true,
        ["0-1"] = true,
        ["1/2-1/2"] = true,
        ["*"] = true,
    }

    while index <= length do
        local char = content:sub(index, index)
        if char:match("%s") then
            index = index + 1
        elseif char == "[" then
            local end_index = content:find("]", index, true)
            if not end_index then
                error("unterminated PGN tag")
            end
            local raw = trim(content:sub(index + 1, end_index - 1))
            local name, value = raw:match('^([A-Za-z0-9_]+)%s+"(.*)"$')
            if not name then
                error("invalid PGN tag: [" .. raw .. "]")
            end
            value = value:gsub('\\"', '"')
            table.insert(tokens, {kind = "TAG", name = name, value = value})
            index = end_index + 1
        elseif char == "{" then
            local end_index = content:find("}", index, true)
            if not end_index then
                error("unterminated PGN comment")
            end
            table.insert(tokens, {kind = "COMMENT", value = trim(content:sub(index + 1, end_index - 1))})
            index = end_index + 1
        elseif char == ";" then
            local end_index = content:find("\n", index, true) or (length + 1)
            table.insert(tokens, {kind = "COMMENT", value = trim(content:sub(index + 1, end_index - 1))})
            index = end_index
        elseif char == "(" then
            table.insert(tokens, {kind = "LPAREN", value = "("})
            index = index + 1
        elseif char == ")" then
            table.insert(tokens, {kind = "RPAREN", value = ")"})
            index = index + 1
        elseif char == "$" then
            local start_index = index
            index = index + 1
            while index <= length and content:sub(index, index):match("%d") do
                index = index + 1
            end
            table.insert(tokens, {kind = "NAG", value = content:sub(start_index, index - 1)})
        else
            local start_index = index
            while index <= length do
                local current = content:sub(index, index)
                if current:match("%s") or current == "[" or current == "]" or current == "{" or current == "}" or current == "(" or current == ")" or current == ";" then
                    break
                end
                index = index + 1
            end
            local value = content:sub(start_index, index - 1)
            if result_tokens[value] then
                table.insert(tokens, {kind = "RESULT", value = value})
            elseif value:match("^%d+%.%.%.$") or value:match("^%d+%.$") then
                table.insert(tokens, {kind = "MOVE_NO", value = value})
            else
                table.insert(tokens, {kind = "SAN", value = value})
            end
        end
    end

    return tokens
end

local parse_pgn_sequence

parse_pgn_sequence = function(tokens, index)
    local moves = {}
    local trailing_comments = {}
    local result = "*"

    while index <= #tokens do
        local token = tokens[index]
        if token.kind == "RPAREN" then
            break
        elseif token.kind == "RESULT" then
            result = token.value
            index = index + 1
            break
        elseif token.kind == "MOVE_NO" then
            index = index + 1
        elseif token.kind == "COMMENT" then
            if #moves > 0 then
                table.insert(moves[#moves].comments, token.value)
            else
                table.insert(trailing_comments, token.value)
            end
            index = index + 1
        elseif token.kind == "NAG" then
            if #moves == 0 then
                error("NAG without move")
            end
            table.insert(moves[#moves].nags, token.value)
            index = index + 1
        elseif token.kind == "LPAREN" then
            if #moves == 0 then
                error("variation without anchor move")
            end
            index = index + 1
            local anchor = moves[#moves]
            local snapshot = snapshot_engine_state()
            local ok, variation_moves, variation_result, pending, next_index = pcall(function()
                local success, msg = import_fen(anchor.fen_before)
                if not success then
                    error(msg)
                end
                local parsed_moves, parsed_result, parsed_pending, parsed_index = parse_pgn_sequence(tokens, index)
                return parsed_moves, parsed_result, parsed_pending, parsed_index
            end)
            restore_engine_state(snapshot)
            if not ok then
                error(variation_moves)
            end
            index = next_index
            if index > #tokens or tokens[index].kind ~= "RPAREN" then
                error("unterminated PGN variation")
            end
            index = index + 1
            if #pending > 0 and #variation_moves > 0 then
                for _, comment in ipairs(pending) do
                    table.insert(variation_moves[#variation_moves].comments, comment)
                end
            end
            if variation_result ~= "*" and #variation_moves > 0 then
                table.insert(variation_moves[#variation_moves].comments, "result " .. variation_result)
            end
            table.insert(anchor.variations, variation_moves)
        elseif token.kind == "SAN" then
            local fen_before = export_fen()
            local move = san_to_move(token.value)
            local canonical = move_to_san(move)
            make_move_internal(move[1], move[2], move[3], move[4], move[5])
            local fen_after = export_fen()
            table.insert(moves, {
                san = canonical,
                move = copy_move_array(move),
                fen_before = fen_before,
                fen_after = fen_after,
                nags = {},
                comments = {},
                variations = {},
            })
            index = index + 1
        else
            error("unexpected PGN token: " .. tostring(token.kind))
        end
    end

    return moves, result, trailing_comments, index
end

local function parse_pgn(content, source)
    local tokens = tokenize_pgn(content)
    local index = 1
    local tags = {}
    local tag_order = {}

    while index <= #tokens and tokens[index].kind == "TAG" do
        local token = tokens[index]
        tags[token.name] = token.value
        table.insert(tag_order, token.name)
        index = index + 1
    end

    local initial_fen = tags.FEN or START_FEN
    local snapshot = snapshot_engine_state()
    local ok, moves, result, initial_comments = pcall(function()
        local success, msg = import_fen(initial_fen)
        if not success then
            error(msg)
        end
        local parsed_moves, parsed_result, parsed_comments = parse_pgn_sequence(tokens, index)
        return parsed_moves, parsed_result, parsed_comments
    end)
    restore_engine_state(snapshot)
    if not ok then
        error(moves)
    end

    if result == "*" and tags.Result then
        result = tags.Result
    end
    if not tags.Result then
        tags.Result = result
        table.insert(tag_order, "Result")
    end

    return {
        tags = tags,
        tag_order = tag_order,
        moves = moves,
        result = result,
        source = source or "current-game",
        initial_fen = initial_fen,
        initial_comments = initial_comments,
    }
end

build_game_from_history = function(history, start_fen, source)
    local snapshot = snapshot_engine_state()
    local ok, moves = pcall(function()
        local success, msg = import_fen(start_fen or START_FEN)
        if not success then
            error(msg)
        end

        local built = {}
        for _, raw_move in ipairs(history or {}) do
            local move = raw_move[1] and copy_move_array(raw_move) or {
                raw_move.from_rank,
                raw_move.from_file,
                raw_move.to_rank,
                raw_move.to_file,
                raw_move.promotion,
            }
            local fen_before = export_fen()
            local san = move_to_san(move)
            make_move_internal(move[1], move[2], move[3], move[4], move[5])
            local fen_after = export_fen()
            table.insert(built, {
                san = san,
                move = copy_move_array(move),
                fen_before = fen_before,
                fen_after = fen_after,
                nags = {},
                comments = {},
                variations = {},
            })
        end
        return built
    end)
    restore_engine_state(snapshot)
    if not ok then
        error(moves)
    end

    local effective_start_fen = start_fen or START_FEN
    local tags = {
        Event = "CLI Game",
        Site = "Local",
        Result = "*",
    }
    local tag_order = {"Event", "Site", "Result"}
    if effective_start_fen ~= START_FEN then
        tags.SetUp = "1"
        tags.FEN = effective_start_fen
        table.insert(tag_order, "SetUp")
        table.insert(tag_order, "FEN")
    end

    return {
        tags = tags,
        tag_order = tag_order,
        moves = moves,
        result = "*",
        source = source or "current-game",
        initial_fen = effective_start_fen,
        initial_comments = {},
    }
end

reset_pgn_state = function(start_fen, source)
    pgn_path = nil
    pgn_game = build_game_from_history({}, start_fen or START_FEN, source or "current-game")
    pgn_variation_stack = {}
end

current_pgn_game = function()
    return pgn_game
end

current_pgn_sequence_ref = function()
    local sequence = pgn_game.moves
    for _, frame in ipairs(pgn_variation_stack) do
        local anchor = sequence[frame[1]]
        if not anchor or not anchor.variations[frame[2]] then
            return pgn_game.moves
        end
        sequence = anchor.variations[frame[2]]
    end
    return sequence
end

current_pgn_sequence = function()
    return current_pgn_sequence_ref()
end

current_pgn_moves = function()
    local moves = {}
    for _, node in ipairs(current_pgn_sequence()) do
        table.insert(moves, node.san)
    end
    return moves
end

local function active_line_nodes()
    local nodes = {}
    local sequence = pgn_game.moves
    for _, frame in ipairs(pgn_variation_stack) do
        local anchor_index = frame[1]
        local variation_index = frame[2]
        for index = 1, anchor_index - 1 do
            if sequence[index] then
                table.insert(nodes, sequence[index])
            end
        end
        local anchor = sequence[anchor_index]
        if not anchor or not anchor.variations[variation_index] then
            break
        end
        sequence = anchor.variations[variation_index]
    end
    for _, node in ipairs(sequence) do
        table.insert(nodes, node)
    end
    return nodes
end

local function apply_move_object_silent(move)
    local legal = generate_legal_moves()
    for _, candidate in ipairs(legal) do
        if moves_equal(candidate, move) then
            make_move_internal(candidate[1], candidate[2], candidate[3], candidate[4], candidate[5])
            return nil
        end
    end
    return "Illegal move"
end

local function apply_move_silent(move_str)
    if #move_str < 4 then
        return "Invalid move format"
    end
    local from_rank, from_file = algebraic_to_indices(move_str:sub(1, 2))
    local to_rank, to_file = algebraic_to_indices(move_str:sub(3, 4))
    if not from_rank or not from_file or not to_rank or not to_file then
        return "Invalid move format"
    end
    local promotion = (#move_str >= 5) and move_str:sub(5, 5) or nil
    if promotion and promotion ~= "" then
        promotion = white_to_move and promotion:upper() or promotion:lower()
    else
        promotion = nil
    end
    local requested = {from_rank, from_file, to_rank, to_file, promotion}
    return apply_move_object_silent(requested)
end

sync_runtime_to_pgn_cursor = function()
    local success, msg = import_fen(pgn_game.initial_fen)
    if not success then
        error("failed to load PGN base position: " .. tostring(msg))
    end
    for _, node in ipairs(active_line_nodes()) do
        local err = apply_move_object_silent(node.move)
        if err ~= nil then
            error("failed to replay PGN move " .. node.san .. ": " .. tostring(err))
        end
    end
end

record_pgn_move = function(move)
    local san = move_to_san(move)
    local fen_before = export_fen()
    make_move_internal(move[1], move[2], move[3], move[4], move[5])
    local fen_after = export_fen()
    table.insert(current_pgn_sequence_ref(), {
        san = san,
        move = copy_move_array(move),
        fen_before = fen_before,
        fen_after = fen_after,
        nags = {},
        comments = {},
        variations = {},
    })
end

local function load_pgn(path)
    local file = io.open(path, "r")
    if not file then
        return false, "ERROR: pgn load failed: file not found: " .. tostring(path)
    end

    local content = file:read("*a")
    file:close()

    local ok, game = pcall(function()
        return parse_pgn(content, path)
    end)
    if not ok then
        return false, "ERROR: pgn load failed: " .. tostring(game)
    end

    local sync_ok, sync_err = pcall(function()
        pgn_game = game
        pgn_path = path
        pgn_variation_stack = {}
        sync_runtime_to_pgn_cursor()
    end)
    if not sync_ok then
        return false, "ERROR: pgn load failed: " .. tostring(sync_err)
    end
    return true, "PGN: loaded source=" .. tostring(path)
end

local function trace_event(event, detail)
    if not trace_enabled then
        return
    end

    table.insert(trace_events, {
        ts_ms = math.floor(os.time() * 1000),
        event = event,
        detail = detail
    })

    if #trace_events > 256 then
        table.remove(trace_events, 1)
    end
end

local function json_escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\"", "\\\"")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\t", "\\t")
    value = value:gsub(string.char(8), "\\b")
    value = value:gsub(string.char(12), "\\f")
    return value
end

local function reset_trace_ai_state()
    trace_last_ai_source = nil
    trace_last_ai_move = nil
    trace_last_ai_depth = 0
    trace_last_ai_score_cp = 0
    trace_last_ai_elapsed_ms = 0
    trace_last_ai_timed_out = false
    trace_last_ai_nodes = 0
    trace_last_ai_eval_calls = 0
    trace_last_ai_nps = 0
    trace_last_ai_tt_hits = 0
    trace_last_ai_tt_misses = 0
    trace_last_ai_beta_cutoffs = 0
end

local function format_trace_ai_summary()
    if not trace_last_ai_source or not trace_last_ai_move then
        return "none"
    end

    local summary = string.format("%s:%s", trace_last_ai_source, trace_last_ai_move)
    if trace_last_ai_source:find("search", 1, true) then
        summary = summary ..
            string.format("@d%d/%dcp/%dms/n%d/e%d/nps%d", trace_last_ai_depth, trace_last_ai_score_cp, trace_last_ai_elapsed_ms, trace_last_ai_nodes, trace_last_ai_eval_calls, trace_last_ai_nps)
        if trace_last_ai_timed_out then
            summary = summary .. "/timeout"
        end
    elseif trace_last_ai_source:find("endgame", 1, true) then
        summary = summary .. string.format("/%dcp", trace_last_ai_score_cp)
    end

    return summary
end

local function format_trace_search_metrics()
    if not trace_last_ai_source or not trace_last_ai_source:find("search", 1, true) then
        return nil
    end

    return string.format(
        "nodes=%d,eval_calls=%d,tt_hits=%d,tt_misses=%d,beta_cutoffs=%d,nps=%d",
        trace_last_ai_nodes,
        trace_last_ai_eval_calls,
        trace_last_ai_tt_hits,
        trace_last_ai_tt_misses,
        trace_last_ai_beta_cutoffs,
        trace_last_ai_nps
    )
end

record_trace_ai = function(source, move, depth, score_cp, elapsed_ms, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
    trace_last_ai_source = source
    trace_last_ai_move = move
    trace_last_ai_depth = depth or 0
    trace_last_ai_score_cp = score_cp or 0
    trace_last_ai_elapsed_ms = elapsed_ms or 0
    trace_last_ai_timed_out = timed_out == true
    trace_last_ai_nodes = nodes or 0
    trace_last_ai_eval_calls = eval_calls or 0
    trace_last_ai_tt_hits = tt_hits or 0
    trace_last_ai_tt_misses = tt_misses or 0
    trace_last_ai_beta_cutoffs = beta_cutoffs or 0
    local divisor = (trace_last_ai_elapsed_ms and trace_last_ai_elapsed_ms > 0) and trace_last_ai_elapsed_ms or 1
    if trace_last_ai_nodes > 0 then
        trace_last_ai_nps = math.floor((trace_last_ai_nodes * 1000) / divisor)
    else
        trace_last_ai_nps = 0
    end
    trace_event("ai", format_trace_ai_summary())
end

local function build_trace_last_ai_json()
    if not trace_last_ai_source or not trace_last_ai_move then
        return "null"
    end

    return string.format(
        "{\"source\":\"%s\",\"move\":\"%s\",\"depth\":%d,\"score_cp\":%d,\"elapsed_ms\":%d,\"timed_out\":%s,\"nodes\":%d,\"eval_calls\":%d,\"nps\":%d,\"tt_hits\":%d,\"tt_misses\":%d,\"beta_cutoffs\":%d,\"summary\":\"%s\"}",
        json_escape(trace_last_ai_source),
        json_escape(trace_last_ai_move),
        trace_last_ai_depth,
        trace_last_ai_score_cp,
        trace_last_ai_elapsed_ms,
        trace_last_ai_timed_out and "true" or "false",
        trace_last_ai_nodes,
        trace_last_ai_eval_calls,
        trace_last_ai_nps,
        trace_last_ai_tt_hits,
        trace_last_ai_tt_misses,
        trace_last_ai_beta_cutoffs,
        json_escape(format_trace_ai_summary())
    )
end

local function build_trace_export_payload()
    local event_entries = {}
    for index, event in ipairs(trace_events) do
        event_entries[#event_entries + 1] = string.format(
            "{\"ts_ms\":%d,\"event\":\"%s\",\"detail\":\"%s\"}",
            event.ts_ms or 0,
            json_escape(event.event),
            json_escape(event.detail)
        )
    end

    return string.format(
        "{\"format\":\"tgac.trace.v1\",\"engine\":\"lua\",\"generated_at_ms\":%d,\"enabled\":%s,\"level\":\"%s\",\"command_count\":%d,\"event_count\":%d,\"events\":[%s],\"last_ai\":%s}\n",
        math.floor(os.time() * 1000),
        trace_enabled and "true" or "false",
        json_escape(trace_level),
        trace_command_count,
        #trace_events,
        table.concat(event_entries, ","),
        build_trace_last_ai_json()
    )
end

local function build_trace_chrome_payload()
    local chrome_events = {}
    local base_ts = (#trace_events > 0 and (trace_events[1].ts_ms or 0)) or 0

    for index, event in ipairs(trace_events) do
        local ts_us = ((event.ts_ms or 0) - base_ts) * 1000
        chrome_events[#chrome_events + 1] = string.format(
            "{\"name\":\"%s\",\"cat\":\"engine.trace\",\"ph\":\"i\",\"pid\":1,\"tid\":1,\"ts\":%d,\"args\":{\"detail\":\"%s\",\"level\":\"%s\",\"ts_ms\":%d}}",
            json_escape(event.event),
            ts_us,
            json_escape(event.detail),
            json_escape(trace_level),
            event.ts_ms or 0
        )
    end

    return string.format(
        "{\"format\":\"tgac.chrome_trace.v1\",\"engine\":\"lua\",\"generated_at_ms\":%d,\"enabled\":%s,\"level\":\"%s\",\"command_count\":%d,\"event_count\":%d,\"display_time_unit\":\"ms\",\"events\":[%s]}\n",
        math.floor(os.time() * 1000),
        trace_enabled and "true" or "false",
        json_escape(trace_level),
        trace_command_count,
        #trace_events,
        table.concat(chrome_events, ",")
    )
end

local function write_trace_payload(target, payload)
    local bytes = #payload
    if target == "(memory)" then
        return true, bytes, nil
    end

    local file, open_err = io.open(target, "w")
    if not file then
        return false, bytes, open_err or "unable to open target"
    end

    local ok, write_err = file:write(payload)
    if not ok then
        file:close()
        return false, bytes, write_err or "unable to write payload"
    end

    local close_ok, close_err = file:close()
    if close_ok == nil then
        return false, bytes, close_err or "unable to close target"
    end

    return true, bytes, nil
end

local function reset_trace_export_state()
    trace_export_count = 0
    trace_chrome_count = 0
    trace_last_export_target = "(none)"
    trace_last_export_bytes = 0
    trace_last_chrome_target = "(none)"
    trace_last_chrome_bytes = 0
end

local function trace_report_line()
    local report = string.format(
        "TRACE: enabled=%s; level=%s; events=%d; commands=%d; exports=%d; export_bytes=%d; last_export=%s; chrome_exports=%d; chrome_bytes=%d; last_chrome=%s; last_ai=%s",
        tostring(trace_enabled),
        trace_level,
        #trace_events,
        trace_command_count,
        trace_export_count,
        trace_last_export_bytes,
        trace_last_export_target,
        trace_chrome_count,
        trace_last_chrome_bytes,
        trace_last_chrome_target,
        format_trace_ai_summary()
    )
    local search_metrics = format_trace_search_metrics()
    if search_metrics then
        report = report .. "; search_metrics=" .. search_metrics
    end
    return report
end

local function clone_board_state(source)
    local copy = {}
    for rank = 1, 8 do
        copy[rank] = {}
        for file = 1, 8 do
            copy[rank][file] = source[rank][file]
        end
    end
    return copy
end

local function clone_castling_state(source)
    return {
        white_king = source.white_king,
        white_queen = source.white_queen,
        black_king = source.black_king,
        black_queen = source.black_queen,
    }
end

local function default_castling_config()
    return {
        white_king_file = 5,
        white_kingside_rook_file = 8,
        white_queenside_rook_file = 1,
        black_king_file = 5,
        black_kingside_rook_file = 8,
        black_queenside_rook_file = 1,
    }
end

local function clone_square(square)
    if not square then
        return nil
    end
    return {square[1], square[2]}
end

local function clone_move_history(source)
    local copy = {}
    for i, entry in ipairs(source) do
        copy[i] = {}
        for key, value in pairs(entry) do
            copy[i][key] = value
        end
    end
    return copy
end

local function clone_irreversible_history(source)
    local copy = {}
    for i, entry in ipairs(source) do
        copy[i] = {
            castling_rights = clone_castling_state(entry.castling_rights),
            en_passant_target = clone_square(entry.en_passant_target),
            halfmove_clock = entry.halfmove_clock,
            zobrist_hash = entry.zobrist_hash,
        }
    end
    return copy
end

snapshot_engine_state = function()
    local history_copy = {}
    for i, hash in ipairs(position_history) do
        history_copy[i] = hash
    end

    return {
        board = clone_board_state(board),
        white_to_move = white_to_move,
        castling_rights = clone_castling_state(castling_rights),
        castling_config = clone_castling_config(castling_config),
        chess960_mode = chess960_mode,
        en_passant_target = clone_square(en_passant_target),
        halfmove_clock = halfmove_clock,
        fullmove_number = fullmove_number,
        move_history = clone_move_history(move_history),
        zobrist_hash = zobrist_hash,
        position_history = history_copy,
        irreversible_history = clone_irreversible_history(irreversible_history),
    }
end

restore_engine_state = function(state)
    board = clone_board_state(state.board)
    white_to_move = state.white_to_move
    castling_rights = clone_castling_state(state.castling_rights)
    castling_config = clone_castling_config(state.castling_config)
    chess960_mode = state.chess960_mode
    en_passant_target = clone_square(state.en_passant_target)
    halfmove_clock = state.halfmove_clock
    fullmove_number = state.fullmove_number
    move_history = clone_move_history(state.move_history)
    zobrist_hash = state.zobrist_hash

    position_history = {}
    for i, hash in ipairs(state.position_history) do
        position_history[i] = hash
    end

    irreversible_history = clone_irreversible_history(state.irreversible_history)
end

local function workload_move_notation(move)
    local notation = indices_to_algebraic(move[1], move[2]) .. indices_to_algebraic(move[3], move[4])
    if move[5] then
        notation = notation .. tostring(move[5]):lower()
    end
    return notation:lower()
end

local function is_workload_castling_move(move)
    local piece = board[move[1]][move[2]]
    return (piece == "K" or piece == "k") and math.abs(move[4] - move[2]) == 2
end

local function is_workload_en_passant_move(move)
    local piece = board[move[1]][move[2]]
    return en_passant_target
        and (piece == "P" or piece == "p")
        and move[3] == en_passant_target[1]
        and move[4] == en_passant_target[2]
        and board[move[3]][move[4]] == "."
end

local function is_workload_promotion_move(move)
    local piece = board[move[1]][move[2]]
    return move[5] ~= nil or ((piece == "P" and move[3] == 8) or (piece == "p" and move[3] == 1))
end

local function workload_move_priority(move)
    local score = 0
    if is_workload_castling_move(move) then
        score = score + 400
    end
    if is_workload_en_passant_move(move) then
        score = score + 300
    end
    if is_workload_promotion_move(move) then
        score = score + 200
    end

    local target = board[move[3]][move[4]]
    if target and target ~= "." then
        score = score + 100 + math.abs(PIECE_VALUES[target] or 0)
    end

    return score
end

local function choose_workload_move(moves, mode, salt)
    local filtered = {}
    for _, move in ipairs(moves) do
        local include = true
        if mode == "castle" then
            include = is_workload_castling_move(move)
        elseif mode == "en_passant" then
            include = is_workload_en_passant_move(move)
        elseif mode == "promotion" then
            include = is_workload_promotion_move(move)
        end
        if include then
            table.insert(filtered, move)
        end
    end

    if #filtered == 0 then
        filtered = moves
    end

    local decorated = {}
    for _, move in ipairs(filtered) do
        table.insert(decorated, {
            move = move,
            notation = workload_move_notation(move),
            priority = workload_move_priority(move),
        })
    end

    table.sort(decorated, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.notation < b.notation
    end)

    local index = (salt % #decorated) + 1
    return decorated[index].move, decorated[index].notation
end

local function benchmark_mix_int(checksum, value)
    return xorshift64((checksum ~ (value & 0xFFFFFFFFFFFFFFFF)) & 0xFFFFFFFFFFFFFFFF)
end

local function benchmark_mix_string(checksum, value)
    local mixed = benchmark_mix_int(checksum, #value)
    for i = 1, #value do
        mixed = benchmark_mix_int(mixed, string.byte(value, i))
    end
    return mixed
end

local function count_kings_on_board()
    local white_kings = 0
    local black_kings = 0
    for rank = 1, 8 do
        for file = 1, 8 do
            local piece = board[rank][file]
            if piece == "K" then
                white_kings = white_kings + 1
            elseif piece == "k" then
                black_kings = black_kings + 1
            end
        end
    end
    return white_kings, black_kings
end

local function load_benchmark_position(fen)
    local success, msg = import_fen(fen)
    if not success then
        return false, msg
    end

    move_history = {}
    position_history = {}
    irreversible_history = {}
    zobrist_hash = compute_hash()
    return true, "OK"
end

local function run_concurrency_workload(profile, seed, run_index)
    local scenarios = {
        {
            name = "opening",
            fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            mode = "any",
        },
        {
            name = "castling",
            fen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1",
            mode = "castle",
        },
        {
            name = "en_passant",
            fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1",
            mode = "en_passant",
        },
        {
            name = "promotion",
            fen = "4k3/P7/8/8/8/8/7p/4K3 w - - 0 1",
            mode = "promotion",
        },
    }

    local plies_per_scenario = profile == "quick" and 2 or 4
    local checksum = xorshift64((seed + run_index * 97) & 0xFFFFFFFFFFFFFFFF)
    local invariant_errors = 0
    local ops_total = 0

    local function record_invariant(condition, detail)
        if not condition then
            invariant_errors = invariant_errors + 1
            checksum = benchmark_mix_string(checksum, "ERR:" .. detail)
            return false
        end
        return true
    end

    for scenario_index, scenario in ipairs(scenarios) do
        local ok, msg = load_benchmark_position(scenario.fen)
        ops_total = ops_total + 2 -- load + recompute hash
        if not ok then
            record_invariant(false, scenario.name .. ":load:" .. tostring(msg))
            break
        end

        local baseline_fen = export_fen()
        local baseline_hash = zobrist_hash
        ops_total = ops_total + 2 -- export + baseline hash validation

        checksum = benchmark_mix_string(checksum, scenario.name)
        checksum = benchmark_mix_string(checksum, baseline_fen)
        checksum = benchmark_mix_int(checksum, baseline_hash)

        record_invariant(compute_hash() == zobrist_hash, scenario.name .. ":baseline-hash")

        local white_kings, black_kings = count_kings_on_board()
        record_invariant(white_kings == 1 and black_kings == 1, scenario.name .. ":king-count")

        for ply = 1, plies_per_scenario do
            local pre_fen = export_fen()
            local pre_hash = zobrist_hash
            local pre_white_to_move = white_to_move
            local pre_move_history_len = #move_history
            local pre_position_history_len = #position_history
            ops_total = ops_total + 1

            local moves = generate_legal_moves()
            ops_total = ops_total + 1
            if not record_invariant(#moves > 0, scenario.name .. ":no-legal-moves:" .. tostring(ply)) then
                break
            end

            local salt = seed + run_index * 37 + scenario_index * 11 + ply * 5
            local move, notation = choose_workload_move(moves, scenario.mode, salt)
            if not record_invariant(move ~= nil, scenario.name .. ":no-selected-move:" .. tostring(ply)) then
                break
            end

            local moving_side = white_to_move
            local moving_piece = board[move[1]][move[2]]
            checksum = benchmark_mix_string(checksum, notation)

            make_move_internal(move[1], move[2], move[3], move[4], move[5])
            ops_total = ops_total + 1

            local post_fen = export_fen()
            local post_hash = zobrist_hash
            local recomputed_hash = compute_hash()
            ops_total = ops_total + 3 -- export + hash read + recompute

            checksum = benchmark_mix_string(checksum, post_fen)
            checksum = benchmark_mix_int(checksum, post_hash)

            record_invariant(white_to_move ~= pre_white_to_move, scenario.name .. ":turn-toggle:" .. tostring(ply))
            record_invariant(recomputed_hash == zobrist_hash, scenario.name .. ":post-hash:" .. tostring(ply))
            record_invariant(post_fen ~= pre_fen, scenario.name .. ":post-fen-unchanged:" .. tostring(ply))
            record_invariant(#move_history == pre_move_history_len + 1, scenario.name .. ":move-history:" .. tostring(ply))
            record_invariant(#position_history == pre_position_history_len + 1, scenario.name .. ":position-history:" .. tostring(ply))
            record_invariant(not is_in_check(moving_side), scenario.name .. ":self-check:" .. tostring(ply))
            record_invariant(moving_piece ~= ".", scenario.name .. ":moved-empty-piece:" .. tostring(ply))

            local post_white_kings, post_black_kings = count_kings_on_board()
            record_invariant(post_white_kings == 1 and post_black_kings == 1, scenario.name .. ":post-king-count:" .. tostring(ply))

            local undone = undo_move()
            ops_total = ops_total + 1
            if not record_invariant(undone, scenario.name .. ":undo-failed:" .. tostring(ply)) then
                break
            end

            local undo_fen = export_fen()
            local undo_hash = zobrist_hash
            local undo_recomputed_hash = compute_hash()
            ops_total = ops_total + 3 -- export + hash read + recompute

            record_invariant(undo_fen == pre_fen, scenario.name .. ":undo-fen:" .. tostring(ply))
            record_invariant(undo_hash == pre_hash, scenario.name .. ":undo-hash:" .. tostring(ply))
            record_invariant(undo_recomputed_hash == zobrist_hash, scenario.name .. ":undo-recompute:" .. tostring(ply))
            record_invariant(white_to_move == pre_white_to_move, scenario.name .. ":undo-turn:" .. tostring(ply))
            record_invariant(#move_history == pre_move_history_len, scenario.name .. ":undo-move-history:" .. tostring(ply))
            record_invariant(#position_history == pre_position_history_len, scenario.name .. ":undo-position-history:" .. tostring(ply))

            local reload_ok, reload_msg = load_benchmark_position(pre_fen)
            ops_total = ops_total + 2 -- reload + recompute hash
            if not record_invariant(reload_ok, scenario.name .. ":reload:" .. tostring(reload_msg)) then
                break
            end

            local reload_fen = export_fen()
            ops_total = ops_total + 1
            record_invariant(reload_fen == pre_fen, scenario.name .. ":reload-fen:" .. tostring(ply))
            record_invariant(zobrist_hash == pre_hash, scenario.name .. ":reload-hash:" .. tostring(ply))

            local reload_white_kings, reload_black_kings = count_kings_on_board()
            record_invariant(reload_white_kings == 1 and reload_black_kings == 1, scenario.name .. ":reload-king-count:" .. tostring(ply))

            checksum = benchmark_mix_int(checksum, pre_hash)
            checksum = benchmark_mix_int(checksum, #moves)
        end

        checksum = benchmark_mix_int(checksum, get_repetition_count())
        checksum = benchmark_mix_int(checksum, halfmove_clock)
    end

    return checksum & 0xFFFFFFFFFFFFFFFF, invariant_errors, ops_total
end

local function build_concurrency_payload(profile)
    local start_clock = os.clock()
    local seed = 12345
    local workers = 1
    local runs = profile == "quick" and 10 or 50
    local checksums = {}
    local deterministic = true
    local invariant_errors = 0
    local ops_total = 0
    local snapshot = snapshot_engine_state()

    local ok, err = pcall(function()
        for i = 1, runs do
            local checksum_a, errors_a, ops_a = run_concurrency_workload(profile, seed, i)
            local checksum_b, errors_b, ops_b = run_concurrency_workload(profile, seed, i)

            checksums[i] = string.format("%016x", checksum_a)
            if checksum_a ~= checksum_b or errors_a ~= errors_b then
                deterministic = false
            end

            invariant_errors = invariant_errors + math.max(errors_a, errors_b)
            ops_total = ops_total + ops_a + ops_b
        end
    end)

    restore_engine_state(snapshot)

    if not ok then
        deterministic = false
        invariant_errors = invariant_errors + 1
        checksums = {string.format("%016x", benchmark_mix_string(seed, tostring(err)))}
    end

    local elapsed_ms = math.floor((os.clock() - start_clock) * 1000)
    local checksums_json = "\"" .. table.concat(checksums, "\",\"") .. "\""

    return string.format(
        "{\"profile\":\"%s\",\"seed\":%d,\"workers\":%d,\"runs\":%d,\"checksums\":[%s],\"deterministic\":%s,\"invariant_errors\":%d,\"deadlocks\":0,\"timeouts\":0,\"elapsed_ms\":%d,\"ops_total\":%d}",
        profile,
        seed,
        workers,
        runs,
        checksums_json,
        deterministic and "true" or "false",
        invariant_errors,
        elapsed_ms,
        ops_total
    )
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
    -- display_board() -- Removed to prevent duplicate display when 'new' is received

    while true do
        local line = io.read()
        if not line then break end
        
        local input = line:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
        if input == "" then goto continue end
        
        local cmd, arg = input:match("^(%S+)%s*(.*)$")
        if not cmd then cmd = input end
        cmd = cmd:lower()
        select_protocol_mode(cmd)
        if cmd ~= "trace" then
            trace_command_count = trace_command_count + 1
            trace_event("command", input)
        end
        
        if cmd == "quit" or cmd == "exit" then
            print("Goodbye!")
            break
        elseif cmd == "new" then
            new_game()
            print("OK: New game started")
            display_board()
        elseif cmd == "move" then
            if arg and arg ~= "" then
                local success, msg = execute_move(arg)
                print(msg)
                if success then
                    display_board()
                    
                    -- Check for game end
                    local legal_moves = generate_legal_moves()
                    if #legal_moves == 0 then
                        if is_in_check(white_to_move) then
                            print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                        else
                            print("STALEMATE: Draw")
                        end
                    elseif is_draw() then
                        local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                        print("DRAW: by " .. reason)
                    end
                end
            else
                print("ERROR: Move requires argument (e.g., 'move e2e4')")
            end
        elseif cmd == "undo" then
            local sequence = current_pgn_sequence()
            if #sequence > 0 then
                table.remove(sequence)
                sync_runtime_to_pgn_cursor()
                print("OK: undo")
                display_board()
            else
                print("ERROR: No moves to undo")
            end
        elseif cmd == "status" then
            local legal_moves = generate_legal_moves()
            if #legal_moves == 0 then
                if is_in_check(white_to_move) then
                    print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                else
                    print("STALEMATE: Draw")
                end
            elseif is_draw() then
                local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                print("DRAW: by " .. reason)
            else
                print("OK: ongoing")
            end
        elseif cmd == "display" or cmd == "show" or cmd == "board" then
            display_board()
        elseif cmd == "hash" then
            print(string.format("HASH: %016x", zobrist_hash))
        elseif cmd == "draws" then
            local repetition = get_repetition_count()
            local draw = repetition >= 3 or halfmove_clock >= 100
            local reason = "none"
            if halfmove_clock >= 100 then
                reason = "fifty_moves"
            elseif repetition >= 3 then
                reason = "repetition"
            end
            print(
                string.format(
                    "DRAWS: repetition=%d; halfmove=%d; draw=%s; reason=%s",
                    repetition,
                    halfmove_clock,
                    tostring(draw),
                    reason
                )
            )
        elseif cmd == "history" then
            print(string.format("HISTORY: count=%d; current=%016x", #position_history + 1, zobrist_hash))
            print(string.format("Position History (%d positions):", #position_history + 1))
            for i, h in ipairs(position_history) do
                print(string.format("  %d: %016x", i - 1, h))
            end
            print(string.format("  %d: %016x (current)", #position_history, zobrist_hash))
        elseif cmd == "go" then
            if protocol_mode == "uci" then
                local tokens = {}
                for token in arg:gmatch("%S+") do
                    table.insert(tokens, token)
                end
                local subcmd = tokens[1] and tokens[1]:lower() or ""

                if subcmd == "depth" then
                    local depth = tonumber(tokens[2])
                    if not depth then
                        print("ERROR: go depth requires an integer value")
                    else
                        depth = math.floor(depth)
                        if depth < 1 then depth = 1 end
                        if depth > 5 then depth = 5 end
                        set_uci_state("searching")
                        local book_move, book_move_str = choose_book_move()
                        if book_move and book_move_str then
                            uci_last_bestmove = book_move_str
                            record_trace_ai("uci-book", book_move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
                            print("info string bookmove " .. book_move_str)
                            print("bestmove " .. book_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                        if endgame_move and endgame_info and endgame_move_str then
                            uci_last_bestmove = endgame_move_str
                            record_trace_ai("uci-endgame", endgame_move_str, 0, endgame_info.score_white, 0, false, 0, 0, 0, 0, 0)
                            print(string.format("info string endgame %s score cp %d", endgame_info.type, endgame_info.score_white))
                            print("bestmove " .. endgame_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(depth, 0)
                        if not best_move then
                            uci_last_bestmove = "0000"
                            print("bestmove 0000")
                        else
                            local move_str = indices_to_algebraic(best_move[1], best_move[2]) ..
                                             indices_to_algebraic(best_move[3], best_move[4])
                            if best_move[5] then
                                move_str = move_str .. best_move[5]
                            end
                            uci_last_bestmove = move_str
                            record_trace_ai("uci-search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
                            print(string.format("info depth %d score cp %d time %d nodes %d", depth_used, eval, elapsed, nodes))
                            print("bestmove " .. move_str)
                        end
                        set_uci_state("idle")
                    end
                    goto continue
                elseif subcmd == "movetime" then
                    local movetime = tonumber(tokens[2])
                    if not movetime then
                        print("ERROR: go movetime requires an integer value")
                    elseif movetime <= 0 then
                        print("ERROR: go movetime must be > 0")
                    else
                        set_uci_state("searching")
                        local book_move, book_move_str = choose_book_move()
                        if book_move and book_move_str then
                            uci_last_bestmove = book_move_str
                            record_trace_ai("uci-book", book_move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
                            print("info string bookmove " .. book_move_str)
                            print("bestmove " .. book_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                        if endgame_move and endgame_info and endgame_move_str then
                            uci_last_bestmove = endgame_move_str
                            record_trace_ai("uci-endgame", endgame_move_str, 0, endgame_info.score_white, 0, false, 0, 0, 0, 0, 0)
                            print(string.format("info string endgame %s score cp %d", endgame_info.type, endgame_info.score_white))
                            print("bestmove " .. endgame_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(5, movetime)
                        if not best_move then
                            uci_last_bestmove = "0000"
                            print("bestmove 0000")
                        else
                            local move_str = indices_to_algebraic(best_move[1], best_move[2]) ..
                                             indices_to_algebraic(best_move[3], best_move[4])
                            if best_move[5] then
                                move_str = move_str .. best_move[5]
                            end
                            uci_last_bestmove = move_str
                            record_trace_ai("uci-search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
                            print(string.format("info depth %d score cp %d time %d nodes %d", depth_used, eval, elapsed, nodes))
                            print("bestmove " .. move_str)
                        end
                        set_uci_state("idle")
                    end
                    goto continue
                elseif subcmd == "wtime" then
                    local movetime, err = derive_movetime_from_clock_args(tokens)
                    if not movetime then
                        print("ERROR: " .. err)
                    else
                        set_uci_state("searching")
                        local book_move, book_move_str = choose_book_move()
                        if book_move and book_move_str then
                            uci_last_bestmove = book_move_str
                            record_trace_ai("uci-book", book_move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
                            print("info string bookmove " .. book_move_str)
                            print("bestmove " .. book_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                        if endgame_move and endgame_info and endgame_move_str then
                            uci_last_bestmove = endgame_move_str
                            record_trace_ai("uci-endgame", endgame_move_str, 0, endgame_info.score_white, 0, false, 0, 0, 0, 0, 0)
                            print(string.format("info string endgame %s score cp %d", endgame_info.type, endgame_info.score_white))
                            print("bestmove " .. endgame_move_str)
                            set_uci_state("idle")
                            goto continue
                        end
                        local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(5, movetime)
                        if not best_move then
                            uci_last_bestmove = "0000"
                            print("bestmove 0000")
                        else
                            local move_str = indices_to_algebraic(best_move[1], best_move[2]) ..
                                             indices_to_algebraic(best_move[3], best_move[4])
                            if best_move[5] then
                                move_str = move_str .. best_move[5]
                            end
                            uci_last_bestmove = move_str
                            record_trace_ai("uci-search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
                            print(string.format("info depth %d score cp %d time %d nodes %d", depth_used, eval, elapsed, nodes))
                            print("bestmove " .. move_str)
                        end
                        set_uci_state("idle")
                    end
                    goto continue
                elseif subcmd == "infinite" then
                    print("info string infinite search bounded to 15000 ms in synchronous mode")
                    set_uci_state("searching")
                    local book_move, book_move_str = choose_book_move()
                    if book_move and book_move_str then
                        uci_last_bestmove = book_move_str
                        record_trace_ai("uci-book", book_move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
                        print("info string bookmove " .. book_move_str)
                        print("bestmove " .. book_move_str)
                        set_uci_state("idle")
                        goto continue
                    end
                    local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                    if endgame_move and endgame_info and endgame_move_str then
                        uci_last_bestmove = endgame_move_str
                        record_trace_ai("uci-endgame", endgame_move_str, 0, endgame_info.score_white, 0, false, 0, 0, 0, 0, 0)
                        print(string.format("info string endgame %s score cp %d", endgame_info.type, endgame_info.score_white))
                        print("bestmove " .. endgame_move_str)
                        set_uci_state("idle")
                        goto continue
                    end
                    local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(5, 15000)
                    if not best_move then
                        uci_last_bestmove = "0000"
                        print("bestmove 0000")
                    else
                        local move_str = indices_to_algebraic(best_move[1], best_move[2]) ..
                                         indices_to_algebraic(best_move[3], best_move[4])
                        if best_move[5] then
                            move_str = move_str .. best_move[5]
                        end
                        uci_last_bestmove = move_str
                        record_trace_ai("uci-search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
                        print(string.format("info depth %d score cp %d time %d nodes %d", depth_used, eval, elapsed, nodes))
                        print("bestmove " .. move_str)
                    end
                    set_uci_state("idle")
                    goto continue
                else
                    print("ERROR: Unsupported go command")
                    goto continue
                end
            end
            local tokens = {}
            for token in arg:gmatch("%S+") do
                table.insert(tokens, token)
            end
            local subcmd = tokens[1] and tokens[1]:lower() or ""

            if subcmd == "depth" then
                local depth = tonumber(tokens[2])
                if not depth then
                    print("ERROR: go depth requires an integer value")
                else
                    depth = math.floor(depth)
                    if depth < 1 then depth = 1 end
                    if depth > 5 then depth = 5 end
                    local book_move, book_move_str = choose_book_move()
                    if book_move and book_move_str then
                        record_trace_ai("uci-book", book_move_str, 0, 0, 0, false, 0, 0, 0, 0, 0)
                        print("info string bookmove " .. book_move_str)
                        print("bestmove " .. book_move_str)
                        goto continue
                    end
                    local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                    if endgame_move and endgame_info and endgame_move_str then
                        record_trace_ai("uci-endgame", endgame_move_str, 0, endgame_info.score_white, 0, false, 0, 0, 0, 0, 0)
                        print(string.format("info string endgame %s score cp %d", endgame_info.type, endgame_info.score_white))
                        print("bestmove " .. endgame_move_str)
                        goto continue
                    end
                    local best_move, eval, depth_used, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs = search_best_move(depth, 0)
                    if not best_move then
                        print("bestmove 0000")
                    else
                        local move_str = indices_to_algebraic(best_move[1], best_move[2]) ..
                                         indices_to_algebraic(best_move[3], best_move[4])
                        if best_move[5] then
                            move_str = move_str .. best_move[5]
                        end
                        record_trace_ai("uci-search", move_str, depth_used, eval, elapsed, timed_out, nodes, eval_calls, tt_hits, tt_misses, beta_cutoffs)
                        print(string.format("info depth %d score cp %d time %d nodes %d", depth_used, eval, elapsed, nodes))
                        print("bestmove " .. move_str)
                    end
                end
            elseif subcmd == "movetime" then
                local movetime = tonumber(tokens[2])
                if not movetime then
                    print("ERROR: go movetime requires an integer value")
                elseif movetime <= 0 then
                    print("ERROR: go movetime must be > 0")
                else
                    local book_move, book_move_str = choose_book_move()
                    if book_move and book_move_str then
                        apply_book_move(book_move, book_move_str)
                    else
                        local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                        if endgame_move and endgame_info and endgame_move_str then
                            apply_endgame_move(endgame_move, endgame_info, endgame_move_str)
                        else
                            local success, msg = ai_move(5, movetime)
                            print(msg)
                            if success then
                                display_board()

                                local legal_moves = generate_legal_moves()
                                if #legal_moves == 0 then
                                    if is_in_check(white_to_move) then
                                        print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                                    else
                                        print("STALEMATE: Draw")
                                    end
                                elseif is_draw() then
                                    local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                                    print("DRAW: by " .. reason)
                                end
                            end
                        end
                    end
                end
            elseif subcmd == "wtime" then
                local movetime, err = derive_movetime_from_clock_args(tokens)
                if not movetime then
                    print("ERROR: " .. err)
                else
                    local book_move, book_move_str = choose_book_move()
                    if book_move and book_move_str then
                        apply_book_move(book_move, book_move_str)
                    else
                        local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                        if endgame_move and endgame_info and endgame_move_str then
                            apply_endgame_move(endgame_move, endgame_info, endgame_move_str)
                        else
                            local success, msg = ai_move(5, movetime)
                            print(msg)
                            if success then
                                display_board()

                                local legal_moves = generate_legal_moves()
                                if #legal_moves == 0 then
                                    if is_in_check(white_to_move) then
                                        print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                                    else
                                        print("STALEMATE: Draw")
                                    end
                                elseif is_draw() then
                                    local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                                    print("DRAW: by " .. reason)
                                end
                            end
                        end
                    end
                end
            elseif subcmd == "infinite" then
                print("OK: go infinite acknowledged (bounded search mode)")
                local book_move, book_move_str = choose_book_move()
                if book_move and book_move_str then
                    apply_book_move(book_move, book_move_str)
                else
                    local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                    if endgame_move and endgame_info and endgame_move_str then
                        apply_endgame_move(endgame_move, endgame_info, endgame_move_str)
                    else
                        local success, msg = ai_move(5, 15000)
                        print(msg)
                        if success then
                            display_board()

                            local legal_moves = generate_legal_moves()
                            if #legal_moves == 0 then
                                if is_in_check(white_to_move) then
                                    print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                                else
                                    print("STALEMATE: Draw")
                                end
                            elseif is_draw() then
                                local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                                print("DRAW: by " .. reason)
                            end
                        end
                    end
                end
            else
                print("ERROR: Unsupported go command")
            end
        elseif cmd == "stop" then
            search_stop_requested = true
            if protocol_mode == "uci" then
                if uci_state == "searching" then
                    print("bestmove " .. (uci_last_bestmove or "0000"))
                    set_uci_state("idle")
                else
                    print("info string stop ignored (no active async search)")
                end
            else
                print("OK: stop")
            end
        elseif cmd == "pgn" then
            local subcmd, subarg = arg:match("^(%S+)%s*(.*)$")
            subcmd = subcmd and subcmd:lower() or ""

            if subcmd == "load" then
                if not subarg or subarg == "" then
                    print("ERROR: pgn load requires a file path")
                else
                    local _, msg = load_pgn(trim(subarg))
                    print(msg)
                end
            elseif subcmd == "save" then
                local path = trim(subarg)
                if path == "" then
                    print("ERROR: pgn save requires a file path")
                else
                    local file = io.open(path, "w")
                    if not file then
                        print("ERROR: pgn save failed: unable to write file")
                    else
                        file:write(serialize_game(current_pgn_game()))
                        file:close()
                        pgn_path = path
                        current_pgn_game().source = path
                        print(string.format("PGN: saved path=\"%s\"", path))
                    end
                end
            elseif subcmd == "show" then
                local game = current_pgn_game()
                local source = game.source ~= "" and game.source or "current-game"
                print(string.format("PGN: source=%s; moves=%d", source, #current_pgn_moves()))
                io.write(serialize_game(game):gsub("\n$", "") .. "\n")
            elseif subcmd == "moves" then
                local moves = current_pgn_moves()
                if #moves > 0 then
                    print("PGN: moves " .. table.concat(moves, " "))
                else
                    print("PGN: moves (none)")
                end
            elseif subcmd == "variation" then
                local action = trim(subarg):match("^(%S+)")
                action = action and action:lower() or ""
                if action == "enter" then
                    local sequence = current_pgn_sequence_ref()
                    if #sequence == 0 then
                        print("ERROR: No variation available")
                    else
                        local anchor_index = #sequence
                        local target = sequence[anchor_index]
                        if #target.variations == 0 then
                            table.insert(target.variations, {})
                        end
                        table.insert(pgn_variation_stack, {anchor_index, #target.variations})
                        sync_runtime_to_pgn_cursor()
                        print("PGN: variation depth=" .. tostring(#pgn_variation_stack))
                    end
                elseif action == "exit" then
                    if #pgn_variation_stack == 0 then
                        print("ERROR: Not inside a variation")
                    else
                        table.remove(pgn_variation_stack)
                        sync_runtime_to_pgn_cursor()
                        print("PGN: variation depth=" .. tostring(#pgn_variation_stack))
                    end
                else
                    print("ERROR: pgn variation requires enter or exit")
                end
            elseif subcmd == "comment" then
                local text = trim(subarg)
                text = text:gsub('^"(.*)"$', '%1')
                if text == "" then
                    print("ERROR: pgn comment requires text")
                else
                    local sequence = current_pgn_sequence_ref()
                    if #sequence == 0 then
                        table.insert(current_pgn_game().initial_comments, text)
                    else
                        table.insert(sequence[#sequence].comments, text)
                    end
                    print("PGN: comment added")
                end
            else
                print("ERROR: Unsupported pgn command")
            end
        elseif cmd == "book" then
            local subcmd, subarg = arg:match("^(%S+)%s*(.*)$")
            subcmd = subcmd and subcmd:lower() or ""

            if subcmd == "load" then
                if not subarg or subarg == "" then
                    print("ERROR: book load requires a file path")
                else
                    local file = io.open(subarg, "r")
                    if not file then
                        print("ERROR: book load failed: file unavailable")
                    else
                        local content = file:read("*a")
                        file:close()
                        local parsed, total_entries, err = parse_book_entries(content)
                        if not parsed then
                            print("ERROR: book load failed: " .. err)
                        else
                            book_path = subarg
                            book_entries = parsed
                            book_entry_count = total_entries
                            book_enabled = true
                            book_lookups = 0
                            book_hits = 0
                            book_misses = 0
                            book_played = 0
                            print(string.format(
                                "BOOK: loaded path=\"%s\"; positions=%d; entries=%d; enabled=true",
                                subarg,
                                book_positions_count(),
                                book_entry_count
                            ))
                        end
                    end
                end
            elseif subcmd == "on" then
                book_enabled = true
                print("BOOK: enabled=true")
            elseif subcmd == "off" then
                book_enabled = false
                print("BOOK: enabled=false")
            elseif subcmd == "stats" then
                local source = book_path or "(none)"
                print(string.format(
                    "BOOK: enabled=%s; path=%s; positions=%d; entries=%d; lookups=%d; hits=%d; misses=%d; played=%d",
                    tostring(book_enabled),
                    source,
                    book_positions_count(),
                    book_entry_count,
                    book_lookups,
                    book_hits,
                    book_misses,
                    book_played
                ))
            else
                print("ERROR: Unsupported book command")
            end
        elseif cmd == "endgame" then
            local info = detect_endgame_state()
            if not info then
                print(string.format("ENDGAME: type=none; active=%s; score=0", color_name(white_to_move)))
            else
                local best_move, _, best_move_str = choose_endgame_move()
                local output = string.format(
                    "ENDGAME: type=%s; strong=%s; weak=%s; score=%d",
                    info.type,
                    color_name(info.strong_white),
                    color_name(info.weak_white),
                    info.score_white
                )
                if best_move and best_move_str then
                    output = output .. "; bestmove=" .. best_move_str
                end
                output = output .. "; detail=" .. info.detail
                print(output)
            end
        elseif cmd == "uci" then
            protocol_mode = "uci"
            set_uci_state("uci_sent")
            print("id name Lua Chess Engine")
            print("id author The Great Analysis Challenge")
            print(string.format("option name Hash type spin default %d min 1 max 1024", uci_hash_mb))
            print(string.format("option name Threads type spin default %d min 1 max 64", uci_threads))
            print("option name UCI_AnalyseMode type check default " .. uci_bool_default(uci_analyse_mode))
            print("option name RichEval type check default " .. uci_bool_default(rich_eval_enabled))
            print("uciok")
        elseif cmd == "isready" then
            if protocol_mode == "uci" and uci_state ~= "searching" then
                set_uci_state("idle")
            end
            print("readyok")
        elseif cmd == "setoption" then
            local tokens = {}
            for token in arg:gmatch("%S+") do
                table.insert(tokens, token)
            end
            if #tokens < 4 or tokens[1]:lower() ~= "name" then
                print("ERROR: setoption format is 'setoption name <Hash|Threads> value <n>'")
            else
                local value_idx = nil
                for i = 2, #tokens do
                    if tokens[i]:lower() == "value" then
                        value_idx = i
                        break
                    end
                end
                if not value_idx or value_idx <= 2 or value_idx + 1 > #tokens then
                    print("ERROR: setoption requires 'value <n>'")
                else
                    local option_name_parts = {}
                    for i = 2, value_idx - 1 do
                        table.insert(option_name_parts, tokens[i])
                    end
                    local raw_name = table.concat(option_name_parts, " ")
                    local option_name = raw_name:lower()
                    local raw_value = table.concat(tokens, " ", value_idx + 1)
                    if option_name == "hash" or option_name == "threads" then
                        local value = tonumber(tokens[value_idx + 1])
                        if not value then
                            print("ERROR: setoption value must be an integer")
                        else
                            value = math.floor(value)
                            if option_name == "hash" then
                                if value < 1 then value = 1 end
                                if value > 1024 then value = 1024 end
                                uci_hash_mb = value
                                print(string.format("info string option Hash=%d", uci_hash_mb))
                            else
                                if value < 1 then value = 1 end
                                if value > 64 then value = 64 end
                                uci_threads = value
                                print(string.format("info string option Threads=%d", uci_threads))
                            end
                        end
                    elseif option_name == "uci_analysemode" then
                        local parsed = parse_uci_check_value(raw_value)
                        if parsed == nil then
                            print("ERROR: setoption value must be true/false")
                        else
                            uci_analyse_mode = parsed
                            print("info string option UCI_AnalyseMode=" .. uci_bool_default(parsed))
                        end
                    elseif option_name == "richeval" then
                        local parsed = parse_uci_check_value(raw_value)
                        if parsed == nil then
                            print("ERROR: setoption value must be true/false")
                        else
                            rich_eval_enabled = parsed
                            print("info string option RichEval=" .. uci_bool_default(parsed))
                        end
                    else
                        print("info string unsupported option " .. raw_name)
                    end
                end
            end
        elseif cmd == "ucinewgame" then
            new_game()
            tt = {}
            uci_last_bestmove = nil
            if protocol_mode == "uci" then
                set_uci_state("idle")
            end
        elseif cmd == "position" then
            local tokens = {}
            for token in arg:gmatch("%S+") do
                table.insert(tokens, token)
            end
            if #tokens == 0 then
                print("ERROR: position requires 'startpos' or 'fen <...>'")
            else
                local idx = 1
                local keyword = tokens[1]:lower()
                local start_fen = START_FEN
                if keyword == "startpos" then
                    new_game()
                    tt = {}
                    idx = 2
                elseif keyword == "fen" then
                    idx = 2
                    local fen_parts = {}
                    while idx <= #tokens and tokens[idx]:lower() ~= "moves" do
                        table.insert(fen_parts, tokens[idx])
                        idx = idx + 1
                    end
                    if #fen_parts == 0 then
                        print("ERROR: position fen requires a FEN string")
                        goto continue
                    end
                    start_fen = table.concat(fen_parts, " ")
                    local success, msg = import_fen(start_fen)
                    if not success then
                        print(msg)
                        goto continue
                    end
                else
                    print("ERROR: position requires 'startpos' or 'fen <...>'")
                    goto continue
                end

                if idx <= #tokens and tokens[idx]:lower() == "moves" then
                    idx = idx + 1
                    while idx <= #tokens do
                        local move_str = tokens[idx]
                        local success, msg = execute_move(move_str, {record_pgn = false})
                        if not success then
                            print("ERROR: position move " .. move_str .. " failed: " .. msg)
                            break
                        end
                        idx = idx + 1
                    end
                end
                pgn_path = nil
                pgn_variation_stack = {}
                local current_start_fen = (#move_history == 0) and export_fen() or start_fen
                pgn_game = build_game_from_history(move_history, current_start_fen, "current-game")
                if protocol_mode == "uci" then
                    set_uci_state("idle")
                end
            end
        elseif cmd == "new960" then
            local id = tonumber(arg) or 0
            if id < 0 or id > 959 then
                print("ERROR: new960 id must be between 0 and 959")
            else
                chess960_id = math.floor(id)
                local fen = build_chess960_fen(chess960_id)
                local success, msg = import_fen(fen)
                if not success then
                    print("ERROR: Invalid Chess960 FEN: " .. msg)
                    goto continue
                end
                print("OK: New game started")
                display_board()
                print(string.format("960: new game id=%d; backrank=%s", chess960_id, decode_chess960_backrank(chess960_id)))
            end
        elseif cmd == "position960" then
            print(string.format(
                "960: id=%d; mode=chess960; backrank=%s; fen=%s",
                chess960_id,
                decode_chess960_backrank(chess960_id),
                build_chess960_fen(chess960_id)
            ))
        elseif cmd == "trace" then
            local subcmd, subarg = arg:match("^(%S+)%s*(.*)$")
            subcmd = subcmd and subcmd:lower() or ""

            if subcmd == "on" then
                trace_enabled = true
                trace_event("trace", "enabled")
                print(string.format("TRACE: enabled=true; level=%s; events=%d", trace_level, #trace_events))
            elseif subcmd == "off" then
                trace_event("trace", "disabled")
                trace_enabled = false
                print(string.format("TRACE: enabled=false; level=%s; events=%d", trace_level, #trace_events))
            elseif subcmd == "level" then
                if not subarg or subarg == "" then
                    print("ERROR: trace level requires a value")
                else
                    local new_level = subarg:match("^(%S+)")
                    trace_level = (new_level or "info"):lower()
                    trace_event("trace", "level=" .. trace_level)
                    print("TRACE: level=" .. trace_level)
                end
            elseif subcmd == "report" then
                print(trace_report_line())
            elseif subcmd == "reset" then
                trace_events = {}
                trace_command_count = 0
                reset_trace_export_state()
                reset_trace_ai_state()
                print("TRACE: reset")
            elseif subcmd == "export" then
                local target = (subarg and subarg ~= "") and subarg or "(memory)"
                local payload = build_trace_export_payload()
                local ok, byte_count, err = write_trace_payload(target, payload)
                if not ok then
                    print("ERROR: trace export failed: " .. tostring(err))
                else
                    trace_export_count = trace_export_count + 1
                    trace_last_export_target = target
                    trace_last_export_bytes = byte_count
                    print(string.format("TRACE: export=%s; events=%d; bytes=%d", target, #trace_events, byte_count))
                end
            elseif subcmd == "chrome" then
                local target = (subarg and subarg ~= "") and subarg or "(memory)"
                local payload = build_trace_chrome_payload()
                local ok, byte_count, err = write_trace_payload(target, payload)
                if not ok then
                    print("ERROR: trace chrome failed: " .. tostring(err))
                else
                    trace_chrome_count = trace_chrome_count + 1
                    trace_last_chrome_target = target
                    trace_last_chrome_bytes = byte_count
                    print(string.format("TRACE: chrome=%s; events=%d; bytes=%d", target, #trace_events, byte_count))
                end
            else
                print("ERROR: Unsupported trace command")
            end
        elseif cmd == "concurrency" then
            local profile = (arg and arg:match("^(%S+)") or ""):lower()
            if profile ~= "quick" and profile ~= "full" then
                print("ERROR: Unsupported concurrency profile")
            else
                print("CONCURRENCY: " .. build_concurrency_payload(profile))
            end
        elseif cmd == "export" then
            print("FEN: " .. export_fen())
        elseif cmd == "fen" then
            if arg and arg ~= "" then
                local success, msg = import_fen(arg)
                if success then
                    local start_fen = export_fen()
                    reset_pgn_state(start_fen, "current-game")
                    print("OK: FEN loaded")
                    display_board()
                else
                    print(msg)
                end
            else
                print("ERROR: FEN command requires argument")
            end
        elseif cmd == "ai" then
            local depth = tonumber(arg) or 3
            local book_move, book_move_str = choose_book_move()
            if book_move and book_move_str then
                apply_book_move(book_move, book_move_str)
            else
                local endgame_move, endgame_info, endgame_move_str = choose_endgame_move()
                if endgame_move and endgame_info and endgame_move_str then
                    apply_endgame_move(endgame_move, endgame_info, endgame_move_str)
                else
                    local success, msg = ai_move(depth)
                    print(msg)
                    if success then
                        display_board()
                        
                        -- Check for game end
                        local legal_moves = generate_legal_moves()
                        if #legal_moves == 0 then
                            if is_in_check(white_to_move) then
                                print("CHECKMATE: " .. (white_to_move and "Black" or "White") .. " wins")
                            else
                                print("STALEMATE: Draw")
                            end
                        elseif is_draw() then
                            local reason = is_draw_by_fifty_moves() and "50-move rule" or "repetition"
                            print("DRAW: by " .. reason)
                        end
                    end
                end
            end
        elseif cmd == "eval" then
            local score = evaluate_position()
            print(string.format("EVALUATION: %d", score))
        elseif cmd == "perft" then
            local depth = tonumber(arg) or 4
            local start_time = os.clock()
            local nodes = perft(depth)
            local elapsed = math.floor((os.clock() - start_time) * 1000)
            print(string.format("Perft %d: %d", depth, nodes))
        elseif cmd == "help" then
            print("Available commands:")
            print("  new              - Start a new game")
            print("  move <from><to>  - Make a move (e.g., 'move e2e4')")
            print("  undo             - Undo last move")
            print("  status           - Show game status")
            print("  hash             - Show Zobrist hash")
            print("  draws            - Show draw detection status")
            print("  history          - Show position hash history")
            print("  go movetime <ms> - Time-managed AI move")
            print("  go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>] - Clock-based timed move")
            print("  go depth <n>     - UCI-style depth search (prints info/bestmove)")
            print("  go infinite      - Start bounded long search mode")
            print("  stop             - Stop infinite search mode")
            print("  pgn load|save|show|moves - PGN command family")
            print("  pgn variation enter|exit - Enter or exit current variation")
            print("  pgn comment \"text\" - Add comment to current PGN node")
            print("  book load|on|off|stats - Native opening book controls")
            print("  endgame          - Detect specialized endgame and best move hint")
            print("  uci              - Enter/respond to UCI handshake")
            print("  isready          - UCI readiness probe")
            print("  setoption name <Hash|Threads> value <n> - Set UCI option")
            print("  setoption name <Hash|Threads|UCI_AnalyseMode|RichEval> value <x> - Set UCI option")
            print("  ucinewgame       - Reset internal state for UCI game")
            print("  position startpos|fen ... [moves ...] - Load UCI position")
            print("  new960 [id]      - Start Chess960 game by id (0-959)")
            print("  position960      - Show current Chess960 metadata")
            print("  trace ...        - Trace controls and reports")
            print("  concurrency quick|full - Deterministic concurrency contract")
            print("  export           - Export position as FEN")
            print("  fen <string>     - Load position from FEN")
            print("  ai <depth>       - AI makes a move")
            print("  eval             - Show evaluation")
            print("  perft <depth>    - Performance test")
            print("  quit             - Exit")
        else
            print("ERROR: Invalid command. Type 'help' for available commands.")
        end
        ::continue::
    end
end

-- Run the chess engine
main()
