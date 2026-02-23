const std = @import("std");
const posix = std.posix;

pub const StdoutWriter = struct {
    pub fn print(self: StdoutWriter, comptime fmt: []const u8, args: anytype) !void {
        _ = self;
        var buffer: [4096]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buffer, fmt, args);
        try writeAll(msg);
    }
};

pub fn stdoutWriter() StdoutWriter {
    return .{};
}

pub fn readLine(buf: []u8) !?[]const u8 {
    var idx: usize = 0;
    while (idx < buf.len) {
        const n = try posix.read(posix.STDIN_FILENO, buf[idx .. idx + 1]);
        if (n == 0) {
            if (idx == 0) return null;
            break;
        }
        if (buf[idx] == '\n') {
            break;
        }
        idx += 1;
    }
    return buf[0..idx];
}

fn writeAll(data: []const u8) !void {
    var offset: usize = 0;
    while (offset < data.len) {
        const rc = posix.system.write(posix.STDOUT_FILENO, data[offset..].ptr, data.len - offset);
        if (rc < 0) {
            const err = posix.errno(rc);
            if (err == .INTR) continue;
            return error.WriteFailed;
        }
        if (rc == 0) return error.WriteFailed;
        offset += @intCast(rc);
    }
}
