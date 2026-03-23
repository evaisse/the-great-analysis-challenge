const std = @import("std");

pub const AttackEntry = struct {
    squares: [8]u8 = [_]u8{0} ** 8,
    len: usize = 0,

    pub fn slice(self: *const AttackEntry) []const u8 {
        return self.squares[0..self.len];
    }
};

pub const RayEntry = struct {
    squares: [7]u8 = [_]u8{0} ** 7,
    len: usize = 0,

    pub fn slice(self: *const RayEntry) []const u8 {
        return self.squares[0..self.len];
    }
};

const knight_deltas = [_][2]i8{
    .{ -1, -2 },
    .{ 1, -2 },
    .{ -2, -1 },
    .{ 2, -1 },
    .{ -2, 1 },
    .{ 2, 1 },
    .{ -1, 2 },
    .{ 1, 2 },
};

const king_deltas = [_][2]i8{
    .{ -1, -1 },
    .{ 0, -1 },
    .{ 1, -1 },
    .{ -1, 0 },
    .{ 1, 0 },
    .{ -1, 1 },
    .{ 0, 1 },
    .{ 1, 1 },
};

pub const knight_attacks = buildAttackTable(knight_deltas);
pub const king_attacks = buildAttackTable(king_deltas);

pub const southwest_rays = buildRayTable(.{ -1, -1 });
pub const south_rays = buildRayTable(.{ 0, -1 });
pub const southeast_rays = buildRayTable(.{ 1, -1 });
pub const west_rays = buildRayTable(.{ -1, 0 });
pub const east_rays = buildRayTable(.{ 1, 0 });
pub const northwest_rays = buildRayTable(.{ -1, 1 });
pub const north_rays = buildRayTable(.{ 0, 1 });
pub const northeast_rays = buildRayTable(.{ 1, 1 });

pub const chebyshev_distance = buildDistanceTable(.chebyshev);
pub const manhattan_distance = buildDistanceTable(.manhattan);

const DistanceMetric = enum {
    chebyshev,
    manhattan,
};

pub fn rayTable(direction: i8) *const [64]RayEntry {
    return switch (direction) {
        -9 => &southwest_rays,
        -8 => &south_rays,
        -7 => &southeast_rays,
        -1 => &west_rays,
        1 => &east_rays,
        7 => &northwest_rays,
        8 => &north_rays,
        9 => &northeast_rays,
        else => @panic("unsupported ray direction"),
    };
}

fn buildAttackTable(comptime deltas: anytype) [64]AttackEntry {
    var table = [_]AttackEntry{AttackEntry{}} ** 64;
    for (0..64) |square| {
        table[square] = buildAttackEntry(@intCast(square), deltas);
    }
    return table;
}

fn buildAttackEntry(square: u8, comptime deltas: anytype) AttackEntry {
    const file: i8 = @intCast(square % 8);
    const rank: i8 = @intCast(square / 8);
    var entry = AttackEntry{};
    for (deltas) |delta| {
        const target_file = file + delta[0];
        const target_rank = rank + delta[1];
        if (target_file >= 0 and target_file < 8 and target_rank >= 0 and target_rank < 8) {
            entry.squares[entry.len] = @as(u8, @intCast(target_rank)) * 8 +
                @as(u8, @intCast(target_file));
            entry.len += 1;
        }
    }
    return entry;
}

fn buildRayTable(delta: [2]i8) [64]RayEntry {
    var table = [_]RayEntry{RayEntry{}} ** 64;
    for (0..64) |square| {
        table[square] = buildRayEntry(@intCast(square), delta);
    }
    return table;
}

fn buildRayEntry(square: u8, delta: [2]i8) RayEntry {
    const file: i8 = @intCast(square % 8);
    const rank: i8 = @intCast(square / 8);
    var entry = RayEntry{};
    var target_file = file + delta[0];
    var target_rank = rank + delta[1];
    while (target_file >= 0 and target_file < 8 and target_rank >= 0 and target_rank < 8) {
        entry.squares[entry.len] = @as(u8, @intCast(target_rank)) * 8 +
            @as(u8, @intCast(target_file));
        entry.len += 1;
        target_file += delta[0];
        target_rank += delta[1];
    }
    return entry;
}

fn buildDistanceTable(comptime metric: DistanceMetric) [64][64]u8 {
    @setEvalBranchQuota(20000);
    var table = [_][64]u8{[_]u8{0} ** 64} ** 64;
    for (0..64) |from| {
        const from_file: i8 = @intCast(from % 8);
        const from_rank: i8 = @intCast(from / 8);
        for (0..64) |to| {
            const to_file: i8 = @intCast(to % 8);
            const to_rank: i8 = @intCast(to / 8);
            const file_distance = absDiff(from_file, to_file);
            const rank_distance = absDiff(from_rank, to_rank);
            table[from][to] = switch (metric) {
                .chebyshev => @max(file_distance, rank_distance),
                .manhattan => file_distance + rank_distance,
            };
        }
    }
    return table;
}

fn absDiff(a: i8, b: i8) u8 {
    return @intCast(if (a > b) a - b else b - a);
}

test "attack tables cover center and corners" {
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 17 }, knight_attacks[0].slice());
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 18, 19, 20, 26, 28, 34, 35, 36 },
        king_attacks[27].slice(),
    );
    try std.testing.expectEqualSlices(u8, &[_]u8{ 36, 45, 54, 63 }, northeast_rays[27].slice());
    try std.testing.expectEqual(@as(u8, 14), manhattan_distance[0][63]);
}
