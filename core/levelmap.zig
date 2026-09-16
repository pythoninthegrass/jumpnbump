// Port of levelmap.txt parsing (main.c read_level) per
// docs/porting-playbook.md TASK-010.04.
//
// A 16-row by 22-column ASCII grid of digits '0'-'4' mapping to
// BAN_VOID/SOLID/WATER/ICE/SPRING, read into ban_map[17][22] — any non-digit
// byte between cells (newlines, in practice) is skipped. Row 16 (the 17th
// row) is then force-filled as BAN_SOLID regardless of what read_level saw,
// a deliberate floor the level format never actually encodes.
const std = @import("std");

pub const rows = 17;
pub const cols = 22;
pub const parsed_rows = 16; // rows actually read from the file; row 16 is force-filled

pub const ban_void: u8 = 0;
pub const ban_solid: u8 = 1;
pub const ban_water: u8 = 2;
pub const ban_ice: u8 = 3;
pub const ban_spring: u8 = 4;

pub const ParseError = error{Truncated};

pub const BanMap = [rows][cols]u8;

// read_level: parse buf into a ban_map. flip mirrors each row's 22 columns
// (main.c's `flip` global, used for the second-player-side level view).
pub fn parse(buf: []const u8, flip: bool) !BanMap {
    var map: BanMap = undefined;
    var pos: usize = 0;

    var row: usize = 0;
    while (row < parsed_rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const chr = nextDigit(buf, &pos) orelse return ParseError.Truncated;
            const dest_col = if (flip) cols - 1 - col else col;
            map[row][dest_col] = chr;
        }
    }

    for (&map[16]) |*cell| cell.* = ban_solid;

    return map;
}

fn nextDigit(buf: []const u8, pos: *usize) ?u8 {
    while (pos.* < buf.len) {
        const c = buf[pos.*];
        pos.* += 1;
        if (c >= '0' and c <= '4') return c - '0';
    }
    return null;
}

fn gridString(comptime rows_text: []const []const u8) []const u8 {
    var out: []const u8 = "";
    for (rows_text) |r| out = out ++ r ++ "\n";
    return out;
}

const sample_16_rows = [_][]const u8{
    "1110000000000000000000",
    "1000000000001000011000",
    "1000111100001100000000",
    "1000000000011110000011",
    "1100000000111000000001",
    "1110001111110000000001",
    "1000000000000011110001",
    "1000000000000000000011",
    "1110011100000000000111",
    "1000000000003100000001",
    "1000000000031110000001",
    "1011110000311111111001",
    "1000000000000000000001",
    "1100000000000000000011",
    "2222222214000001333111",
    "1111111111111111111111",
};

test "parse matches main.c's hardcoded default ban_map" {
    const text = comptime gridString(&sample_16_rows);
    const map = try parse(text, false);

    try std.testing.expectEqual([_]u8{ 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, map[0]);
    try std.testing.expectEqual([_]u8{ 2, 2, 2, 2, 2, 2, 2, 2, 1, 4, 0, 0, 0, 0, 0, 1, 3, 3, 3, 1, 1, 1 }, map[14]);
}

test "row 16 is force-filled as BAN_SOLID regardless of file content" {
    const text = comptime gridString(&sample_16_rows);
    const map = try parse(text, false);
    for (map[16]) |cell| try std.testing.expectEqual(ban_solid, cell);
}

test "flip mirrors each row's columns" {
    const text = comptime gridString(&sample_16_rows);
    const normal = try parse(text, false);
    const flipped = try parse(text, true);

    for (0..parsed_rows) |r| {
        for (0..cols) |c| {
            try std.testing.expectEqual(normal[r][c], flipped[r][cols - 1 - c]);
        }
    }
}

test "non-digit bytes between cells (newlines) are skipped" {
    // Row 0: "1234" then 18 more zeros = 22 cells, with stray newlines
    // spliced between the first few digits. Rows 1-15: 22 zeros each.
    const row0 = "1\n2\n34" ++ ("0" ** 18) ++ "\n";
    const rest = ("0" ** cols ++ "\n") ** (parsed_rows - 1);
    const text = row0 ++ rest;
    const map = try parse(text, false);
    try std.testing.expectEqual(@as(u8, 1), map[0][0]);
    try std.testing.expectEqual(@as(u8, 2), map[0][1]);
    try std.testing.expectEqual(@as(u8, 3), map[0][2]);
    try std.testing.expectEqual(@as(u8, 4), map[0][3]);
}

test "a truncated file returns Truncated instead of reading out of bounds" {
    try std.testing.expectError(ParseError.Truncated, parse("1110000000000000000000\n", false));
    try std.testing.expectError(ParseError.Truncated, parse("", false));
    try std.testing.expectError(ParseError.Truncated, parse("not digits at all, just prose", false));
}

test "parses the real data/levelmap.txt shape" {
    // Mirrors the shipped file's structure without depending on the repo
    // filesystem layout from inside a unit test.
    const text = comptime gridString(&sample_16_rows);
    const map = try parse(text, false);
    try std.testing.expectEqual(rows, map.len);
    try std.testing.expectEqual(cols, map[0].len);
}
