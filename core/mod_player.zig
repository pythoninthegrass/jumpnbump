// Minimal ProTracker/NoiseTracker .mod playback engine (TASK-016.03),
// written from scratch: unlike every other core/*.zig module, there is no
// working C reference in this codebase to port. sdl/sound.c's own
// dj_load_mod/dj_free_mod are empty stubs -- real .mod playback in this port
// goes entirely through SDL_mixer's Mix_LoadMUS/Mix_PlayMusic (libmodplug/
// xmp underneath), so docs/porting-playbook.md's Tier-B oracle-diff
// procedure does not apply here. This module is verified by parser-
// correctness unit tests against real .mod files plus manual listening, not
// bit-exact differential testing.
//
// Scope (confirmed with Lance as the "minimal player" option, see
// TASK-016.03's recorded plan): standard 31-instrument MOD variants only
// (M.K./M!K!/FLT4/FLT8/xCHN/xxCH signatures) -- no 15-sample Soundtracker-
// era format. Effects: 0 arpeggio, 1/2 portamento up/down, 3/5 tone
// portamento (+volslide), 4/6 vibrato (+volslide), 9 sample offset, A volume
// slide, B position jump, C set volume, D pattern break, F set speed/tempo,
// E1/E2 fine portamento, EA/EB fine volume slide, EC note cut. NOT
// implemented: 7 tremolo, 8 panning (channels are summed center, no
// stereo separation), EE pattern delay, any other E-subcommand. A future
// task can extend this set if a real community level needs one of them.
//
// Pitch handling is deliberately table-free (unlike genuine Amiga hardware
// and most faithful trackers, which snap to a fixed period table per
// finetune): note pitch and every pitch-affecting effect (arpeggio,
// portamento, vibrato, finetune) are computed as continuous period/frequency
// arithmetic instead. This is a legitimate simplification for a "minimal"
// player -- it reproduces the same semitone/finetune shifts a table lookup
// would, just without table quantization -- and avoids needing to embed and
// verify the ~600-entry Amiga finetune period table from memory.
//
// Playback model: renders the position-order table exactly once, start to
// end (matching sdl/sound.c's dj_start_mod -> Mix_PlayMusic(mus, -1), which
// loops the *entire* decoded track from its start -- see
// tools/render_music.py's documented "loop point is (0, full length)"
// convention for the build-time OGG path this mirrors). A position-jump/
// pattern-break effect that targets an order index at or before the current
// one would create the .mod's own internal loop; since the caller already
// loops the whole rendered buffer, following that backward jump here would
// render forever. Instead, a non-forward jump ends the render (treated as
// the song's natural end) -- documented at the point it's implemented below.
const std = @import("std");

pub const ModError = error{
    TooShort,
    UnknownSignature,
    Malformed,
    TooManyChannels,
};

const header_size = 20 + 31 * 30; // title + 31 sample headers = 950
const order_table_offset = header_size + 2; // + song_length byte + restart byte
const signature_offset = order_table_offset + 128; // 1080
const pattern_data_offset = signature_offset + 4; // 1084

const max_channels = 32;
const rows_per_pattern = 64;

pub const SampleInfo = struct {
    finetune: i8, // -8..7
    volume: u8, // 0..64
    repeat_offset_bytes: u32,
    repeat_length_bytes: u32, // > 2 means "genuinely loops" (1 word = no loop)
    data: []const u8, // signed 8-bit PCM, sliced from ModFile.owned_buf
};

pub const ModFile = struct {
    allocator: std.mem.Allocator,
    // Owns a duplicate of the decoded input buffer; every slice below
    // (pattern_data, each sample's data) points into this.
    owned_buf: []u8,
    num_channels: u8,
    song_length: u8,
    position_order: [128]u8,
    num_patterns: u16,
    pattern_data: []const u8, // num_patterns * rows_per_pattern * num_channels * 4 bytes
    samples: [31]SampleInfo,

    pub fn deinit(self: *ModFile) void {
        self.allocator.free(self.owned_buf);
        self.* = undefined;
    }

    fn cell(self: *const ModFile, pattern: u8, row: usize, channel: usize) [4]u8 {
        const base = @as(usize, pattern) * rows_per_pattern * self.num_channels * 4 +
            row * self.num_channels * 4 + channel * 4;
        return self.pattern_data[base..][0..4].*;
    }
};

fn channelCountFromSignature(sig: *const [4]u8) ?u8 {
    if (std.mem.eql(u8, sig, "M.K.") or std.mem.eql(u8, sig, "M!K!") or
        std.mem.eql(u8, sig, "FLT4") or std.mem.eql(u8, sig, "N.T."))
        return 4;
    if (std.mem.eql(u8, sig, "6CHN")) return 6;
    if (std.mem.eql(u8, sig, "8CHN") or std.mem.eql(u8, sig, "FLT8") or
        std.mem.eql(u8, sig, "CD81") or std.mem.eql(u8, sig, "OCTA"))
        return 8;
    // "xCHN" (2-9 channels) and "xxCH" (10-99 channels), the two other
    // conventional signature shapes real-world trackers emit.
    if (sig[1] == 'C' and sig[2] == 'H' and sig[3] == 'N' and std.ascii.isDigit(sig[0])) {
        return sig[0] - '0';
    }
    if (sig[2] == 'C' and sig[3] == 'H' and std.ascii.isDigit(sig[0]) and std.ascii.isDigit(sig[1])) {
        return (sig[0] - '0') * 10 + (sig[1] - '0');
    }
    return null;
}

fn readU16Be(buf: []const u8, ofs: usize) u16 {
    return (@as(u16, buf[ofs]) << 8) | buf[ofs + 1];
}

// Parses a raw .mod file's bytes into a ModFile. buf is duplicated
// internally (mirrors core/gob.zig's decode()), so the result outlives the
// caller's buffer.
pub fn parse(allocator: std.mem.Allocator, buf: []const u8) !ModFile {
    if (buf.len < pattern_data_offset) return ModError.TooShort;

    const owned_buf = try allocator.dupe(u8, buf);
    errdefer allocator.free(owned_buf);

    const signature: *const [4]u8 = owned_buf[signature_offset..][0..4];
    const num_channels = channelCountFromSignature(signature) orelse return ModError.UnknownSignature;
    if (num_channels == 0 or num_channels > max_channels) return ModError.TooManyChannels;

    var song_length = owned_buf[header_size];
    if (song_length == 0) song_length = 1;
    if (song_length > 128) song_length = 128;

    var position_order: [128]u8 = undefined;
    @memcpy(&position_order, owned_buf[order_table_offset..][0..128]);

    // Real-world files sometimes carry pattern indices beyond song_length in
    // the unused tail of the order table; scanning the whole table (not just
    // [0..song_length)) for the highest referenced pattern matches what most
    // MOD loaders do, and only affects how much pattern data we expect to
    // find before sample data starts.
    var max_pattern: u16 = 0;
    for (position_order) |p| max_pattern = @max(max_pattern, @as(u16, p));
    const num_patterns: u16 = max_pattern + 1;

    const pattern_bytes = @as(usize, num_patterns) * rows_per_pattern * @as(usize, num_channels) * 4;
    if (pattern_data_offset + pattern_bytes > owned_buf.len) return ModError.Malformed;
    const pattern_data = owned_buf[pattern_data_offset..][0..pattern_bytes];

    var samples: [31]SampleInfo = undefined;
    var data_ofs: usize = pattern_data_offset + pattern_bytes;
    for (0..31) |i| {
        const h = 20 + i * 30;
        const length_words = readU16Be(owned_buf, h + 22);
        const length_bytes: u32 = @as(u32, length_words) * 2;
        const finetune_raw: u8 = owned_buf[h + 24] & 0x0F;
        const finetune: i8 = if (finetune_raw > 7) @as(i8, @intCast(finetune_raw)) - 16 else @intCast(finetune_raw);
        const volume: u8 = @min(owned_buf[h + 25], 64);
        const repeat_offset_words = readU16Be(owned_buf, h + 26);
        const repeat_length_words = readU16Be(owned_buf, h + 28);

        if (data_ofs + length_bytes > owned_buf.len) return ModError.Malformed;
        samples[i] = .{
            .finetune = finetune,
            .volume = volume,
            .repeat_offset_bytes = @as(u32, repeat_offset_words) * 2,
            .repeat_length_bytes = @as(u32, repeat_length_words) * 2,
            .data = owned_buf[data_ofs..][0..length_bytes],
        };
        data_ofs += length_bytes;
    }

    return .{
        .allocator = allocator,
        .owned_buf = owned_buf,
        .num_channels = num_channels,
        .song_length = song_length,
        .position_order = position_order,
        .num_patterns = num_patterns,
        .pattern_data = pattern_data,
        .samples = samples,
    };
}

// PAL Amiga CIA clock, the conventional constant used by continuous-period
// (non-table) MOD players to turn an Amiga period into a playback
// frequency: freq = clock / (period * 2).
const amiga_pal_clock: f64 = 7093789.2;

fn periodToFreq(period_f: f64, finetune: i8) f64 {
    const base = amiga_pal_clock / (period_f * 2.0);
    // 8 finetune steps span one semitone (2^(1/12)); each step is therefore
    // a 2^(1/96) frequency multiplier.
    return base * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(finetune)) / 96.0);
}

// Shifts a period by `semitones` (arpeggio), staying in period space so the
// same periodToFreq() call applies finetune consistently afterward.
fn periodForSemitoneOffset(period: u32, semitones: i32) f64 {
    const period_f: f64 = @floatFromInt(period);
    return period_f / std.math.pow(f64, 2.0, @as(f64, @floatFromInt(semitones)) / 12.0);
}

fn clampPeriod(p: f64) f64 {
    return std.math.clamp(p, 56.0, 3424.0);
}

// Standard 32-entry ProTracker vibrato sine table (amplitude -255..255 for a
// full-depth wave); index wraps mod 32 via a 6-bit position counter that
// covers a full cycle in 64 steps (mirrored second half).
const vibrato_sine = [32]i16{
    0,   24,  49,  74,  97,  120, 141, 161,
    180, 197, 212, 224, 235, 244, 250, 253,
    255, 253, 250, 244, 235, 224, 212, 197,
    180, 161, 141, 120, 97,  74,  49,  24,
};

fn vibratoOffset(pos: u8, depth: u8) f64 {
    const idx = pos & 0x1F;
    const mag: i32 = vibrato_sine[idx];
    const signed_mag: i32 = if (pos & 0x20 != 0) -mag else mag;
    return @as(f64, @floatFromInt(signed_mag * @as(i32, depth))) / 128.0;
}

const ChannelState = struct {
    sample_idx: ?u8 = null,
    period: u32 = 0, // last note-triggered period (the "base" pitch)
    porta_target: u32 = 0,
    porta_speed: u8 = 0,
    volume: u8 = 0,
    pos: usize = 0, // byte offset into the sample's data
    pos_frac: u32 = 0, // 16.16 fixed-point remainder, mirrors sdl/sound.c's stepremainder
    vibrato_pos: u8 = 0,
    vibrato_speed: u8 = 0,
    vibrato_depth: u8 = 0,
    porta_up_speed: u8 = 0,
    porta_down_speed: u8 = 0,
    volslide_speed: u8 = 0, // packed (x<<4)|y memory, reused when a later Axy/5xy/6xy has param 0
    note_cut_tick: ?u8 = null,
};

pub const RenderResult = struct {
    pcm: []i16, // empty (no allocation) when synthesize=false
    frame_count: usize, // stereo frames; pcm.len == frame_count*2 when synthesize=true
};

// Renders `mod`'s position-order table exactly once (see module doc comment)
// into an owned interleaved 16-bit stereo PCM buffer at `sample_rate` Hz.
pub fn renderToPcm(allocator: std.mem.Allocator, mod: *const ModFile, sample_rate: u32) ![]i16 {
    const r = try renderImpl(allocator, mod, sample_rate, true);
    return r.pcm;
}

// Frame count renderToPcm would produce for the same (mod, sample_rate),
// without synthesizing any audio -- the ABI's two-call length-then-fill
// convention (jnb_gob_atlas_build, jnb_level_layers_build) needs this to
// size a caller-allocated PCM buffer before the real render. Shares
// renderImpl's row/order/speed/tempo traversal (the only thing that
// determines total length) instead of a second hand-maintained copy of that
// control flow, which would drift out of sync with renderToPcm over time.
pub fn countFrames(mod: *const ModFile, sample_rate: u32) usize {
    // synthesize=false never allocates (see renderImpl), so this can't fail.
    const r = renderImpl(std.heap.page_allocator, mod, sample_rate, false) catch unreachable;
    std.debug.assert(r.pcm.len == 0);
    std.heap.page_allocator.free(r.pcm);
    return r.frame_count;
}

fn renderImpl(allocator: std.mem.Allocator, mod: *const ModFile, sample_rate: u32, synthesize: bool) !RenderResult {
    var channels: [max_channels]ChannelState = [_]ChannelState{.{}} ** max_channels;
    const nchan: usize = mod.num_channels;
    // Headroom divisor: each channel's contribution can reach +-32512 at
    // full volume (127*256), so summing all `nchan` channels without
    // attenuation clips badly on real-world tracks where several channels
    // hit high volume simultaneously (observed against the repo's own
    // bump.mod/scores.mod during manual verification). Dividing the summed
    // mix by nchan/2 gives comfortable headroom for the common case (not
    // every channel loud at once) while still clamping the rare true peak,
    // the same way a real Amiga's analog mixer saturates rather than wraps.
    const headroom: i32 = @max(@divTrunc(@as(i32, @intCast(nchan)), 2), 1);

    var out = std.ArrayList(i16).empty;
    errdefer out.deinit(allocator);

    var speed: u8 = 6;
    var tempo: u16 = 125;
    var order_idx: usize = 0;
    var row: usize = 0;

    // Generous safety cap: every row of every order-table entry, playable
    // once, plus margin for forward jumps that revisit an earlier row
    // number (but never an earlier order index -- see module doc comment).
    var rows_processed: usize = 0;
    const max_rows_processed: usize = @as(usize, mod.song_length) * rows_per_pattern * 4 + 64;

    var mix_buf = std.ArrayList(i32).empty;
    defer mix_buf.deinit(allocator);

    // Samples-per-tick timing (ProTracker: one tick = 2.5/tempo seconds),
    // accumulated as a float and truncated per tick (not per row) so
    // rounding doesn't drift the song's total length across many rows.
    var tick_acc: f64 = 0;
    var prev_acc_floor: usize = 0;

    while (order_idx < mod.song_length and rows_processed < max_rows_processed) {
        rows_processed += 1;
        const pattern_idx = mod.position_order[order_idx];
        if (pattern_idx >= mod.num_patterns) break; // malformed order entry: stop, don't crash

        var pattern_break_to: ?usize = null;
        var position_jump_to: ?usize = null;

        // Tick 0: note triggers and one-shot effect parameters.
        for (0..nchan) |c| {
            const raw = mod.cell(pattern_idx, row, c);
            const sample_num = (raw[0] & 0xF0) | (raw[2] >> 4);
            const period_raw: u32 = (@as(u32, raw[0] & 0x0F) << 8) | raw[1];
            const effect = raw[2] & 0x0F;
            const param = raw[3];
            var ch = &channels[c];

            if (sample_num != 0 and sample_num <= 31) {
                ch.sample_idx = sample_num - 1;
                ch.volume = mod.samples[sample_num - 1].volume;
            }

            const is_tone_porta = effect == 0x3 or effect == 0x5;
            if (period_raw != 0) {
                if (is_tone_porta) {
                    ch.porta_target = period_raw;
                    if (effect == 0x3 and (param >> 4 != 0 or param & 0xF != 0)) ch.porta_speed = param;
                } else {
                    ch.period = period_raw;
                    ch.pos = 0;
                    ch.pos_frac = 0;
                }
            }

            switch (effect) {
                0x9 => if (period_raw != 0 or sample_num != 0) {
                    const off: usize = @as(usize, param) * 256;
                    if (ch.sample_idx) |si| {
                        const len = mod.samples[si].data.len;
                        ch.pos = @min(off, len);
                    }
                },
                0xB => position_jump_to = param,
                0xC => ch.volume = @min(param, 64),
                0xD => pattern_break_to = (@as(usize, param >> 4) * 10) + (param & 0xF),
                0xF => if (param < 32) {
                    speed = if (param == 0) 1 else param;
                } else {
                    tempo = param;
                },
                0x4 => {
                    if (param >> 4 != 0) ch.vibrato_speed = param >> 4;
                    if (param & 0xF != 0) ch.vibrato_depth = param & 0xF;
                },
                0x1 => if (param != 0) {
                    ch.porta_up_speed = param;
                },
                0x2 => if (param != 0) {
                    ch.porta_down_speed = param;
                },
                0xA, 0x5, 0x6 => if (param != 0) {
                    ch.volslide_speed = param;
                },
                0xE => {
                    const sub = param >> 4;
                    const subparam = param & 0xF;
                    switch (sub) {
                        0x1 => ch.period = @intFromFloat(clampPeriod(@as(f64, @floatFromInt(ch.period)) - @as(f64, @floatFromInt(subparam)))),
                        0x2 => ch.period = @intFromFloat(clampPeriod(@as(f64, @floatFromInt(ch.period)) + @as(f64, @floatFromInt(subparam)))),
                        0xA => ch.volume = @min(ch.volume + subparam, 64),
                        0xB => ch.volume = if (subparam > ch.volume) 0 else ch.volume - subparam,
                        0xC => ch.note_cut_tick = subparam,
                        else => {},
                    }
                },
                else => {},
            }
        }

        var tick: u8 = 0;
        while (tick < speed) : (tick += 1) {
            for (0..nchan) |c| {
                var ch = &channels[c];
                if (ch.note_cut_tick) |cut_tick| {
                    if (tick == cut_tick) ch.volume = 0;
                }
                if (tick > 0) {
                    const raw = mod.cell(pattern_idx, row, c);
                    const effect = raw[2] & 0x0F;
                    switch (effect) {
                        0x1 => ch.period = @intFromFloat(clampPeriod(@as(f64, @floatFromInt(ch.period)) - @as(f64, @floatFromInt(ch.porta_up_speed)))),
                        0x2 => ch.period = @intFromFloat(clampPeriod(@as(f64, @floatFromInt(ch.period)) + @as(f64, @floatFromInt(ch.porta_down_speed)))),
                        0x3, 0x5 => slideTonePorta(ch),
                        else => {},
                    }
                    if (effect == 0x5 or effect == 0x6 or effect == 0xA) applyVolSlide(ch);
                }
            }

            tick_acc += @as(f64, @floatFromInt(sample_rate)) * 2.5 / @as(f64, @floatFromInt(tempo));
            const acc_floor: usize = @intFromFloat(@floor(tick_acc));
            const frames = acc_floor - prev_acc_floor;
            prev_acc_floor = acc_floor;
            if (frames == 0 or !synthesize) continue;

            mix_buf.clearRetainingCapacity();
            try mix_buf.appendNTimes(allocator, 0, frames * 2);

            for (0..nchan) |c| {
                const raw = mod.cell(pattern_idx, row, c);
                const effect = raw[2] & 0x0F;
                const x = raw[3] >> 4;
                const y = raw[3] & 0xF;
                var ch = &channels[c];
                if (ch.sample_idx == null) continue;
                const sample = mod.samples[ch.sample_idx.?];
                if (sample.data.len == 0) continue;

                var mix_period_f: f64 = @floatFromInt(ch.period);
                if (effect == 0x0 and (x != 0 or y != 0)) {
                    const step_in_cycle = tick % 3;
                    if (step_in_cycle == 1) mix_period_f = periodForSemitoneOffset(ch.period, x);
                    if (step_in_cycle == 2) mix_period_f = periodForSemitoneOffset(ch.period, y);
                } else if (effect == 0x4 or effect == 0x6) {
                    mix_period_f = @as(f64, @floatFromInt(ch.period)) + vibratoOffset(ch.vibrato_pos, ch.vibrato_depth);
                    ch.vibrato_pos +%= ch.vibrato_speed;
                }
                mix_period_f = clampPeriod(mix_period_f);

                const freq = periodToFreq(mix_period_f, sample.finetune);
                const step_f = freq / @as(f64, @floatFromInt(sample_rate)) * 65536.0;
                const step: u32 = if (step_f < 0) 0 else @intFromFloat(@min(step_f, @as(f64, std.math.maxInt(u32))));

                mixChannelTick(ch, sample, step, frames, mix_buf.items);
            }

            for (mix_buf.items) |v| {
                const scaled = @divTrunc(v, headroom);
                const clamped: i16 = @intCast(std.math.clamp(scaled, std.math.minInt(i16), std.math.maxInt(i16)));
                try out.append(allocator, clamped);
            }
        }

        if (position_jump_to) |target| {
            if (target <= order_idx) break; // would loop backward -- see module doc comment
            order_idx = target;
            row = pattern_break_to orelse 0;
        } else if (pattern_break_to) |target| {
            order_idx += 1;
            row = target;
        } else {
            row += 1;
            if (row >= rows_per_pattern) {
                row = 0;
                order_idx += 1;
            }
        }
    }

    return .{ .pcm = try out.toOwnedSlice(allocator), .frame_count = prev_acc_floor };
}

fn slideTonePorta(ch: *ChannelState) void {
    if (ch.period == ch.porta_target) return;
    const speed: f64 = @floatFromInt(ch.porta_speed);
    var period_f: f64 = @floatFromInt(ch.period);
    const target_f: f64 = @floatFromInt(ch.porta_target);
    if (period_f < target_f) {
        period_f = @min(period_f + speed, target_f);
    } else {
        period_f = @max(period_f - speed, target_f);
    }
    ch.period = @intFromFloat(period_f);
}

fn applyVolSlide(ch: *ChannelState) void {
    const x: i16 = ch.volslide_speed >> 4;
    const y: i16 = ch.volslide_speed & 0xF;
    const v: i16 = @as(i16, ch.volume) + x - y;
    ch.volume = @intCast(std.math.clamp(v, 0, 64));
}

fn mixChannelTick(ch: *ChannelState, sample: SampleInfo, step: u32, frames: usize, out: []i32) void {
    const loop_end = sample.repeat_offset_bytes + sample.repeat_length_bytes;
    var i: usize = 0;
    while (i < frames) : (i += 1) {
        if (sample.repeat_length_bytes > 2 and ch.pos >= loop_end) {
            ch.pos = sample.repeat_offset_bytes + (ch.pos - loop_end);
        } else if (ch.pos >= sample.data.len) {
            ch.sample_idx = null;
            return;
        }

        const raw_byte = sample.data[ch.pos];
        const signed: i8 = @bitCast(raw_byte);
        const amp: i32 = @divTrunc(@as(i32, signed) * 256 * @as(i32, ch.volume), 64);
        out[i * 2 + 0] += amp;
        out[i * 2 + 1] += amp;

        ch.pos_frac += step;
        ch.pos += ch.pos_frac >> 16;
        ch.pos_frac &= 0xFFFF;
    }
}

// -- Tests -------------------------------------------------------------

fn buildMinimalMod(allocator: std.mem.Allocator, comptime num_channels: u8, comptime signature: *const [4]u8) ![]u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(allocator);

    try buf.appendNTimes(allocator, 0, 20); // title

    // Sample 1: 4 bytes of PCM (2 words), finetune 0, volume 64, no loop.
    try buf.appendNTimes(allocator, 0, 22); // name (unused by the parser)
    try buf.append(allocator, 0x00);
    try buf.append(allocator, 0x02); // length = 2 words = 4 bytes
    try buf.append(allocator, 0x00); // finetune
    try buf.append(allocator, 64); // volume
    try buf.append(allocator, 0x00);
    try buf.append(allocator, 0x00); // repeat offset
    try buf.append(allocator, 0x00);
    try buf.append(allocator, 0x01); // repeat length = 1 word (no loop)

    // Samples 2-31: empty.
    for (0..30) |_| {
        try buf.appendNTimes(allocator, 0, 22);
        try buf.appendNTimes(allocator, 0, 8);
    }

    try buf.append(allocator, 1); // song_length
    try buf.append(allocator, 0); // restart byte (unused)
    try buf.appendNTimes(allocator, 0, 128); // position order: all pattern 0

    try buf.appendSlice(allocator, signature);

    // One pattern: row 0 channel 0 plays sample 1 at period 428 (C-2);
    // row 0 channel 1 carries a pattern-break (Dxx, param 0) so the song
    // ends after this single row instead of playing all 64 (mostly silent)
    // rows of the pattern -- keeps the render short and deterministic for
    // tests that assert on its length. Every other cell is empty.
    const pattern_bytes = rows_per_pattern * @as(usize, num_channels) * 4;
    var pattern: [pattern_bytes]u8 = [_]u8{0} ** pattern_bytes;
    // Cell encoding: sample_num = (b0&0xF0)|(b2>>4), period = ((b0&0x0F)<<8)|b1.
    // Sample #1, period 0x1AC (428, C-2): b0's low nibble is the period's
    // high nibble (0x1), b2's high nibble is the sample number (0x1).
    pattern[0] = 0x01;
    pattern[1] = 0xAC; // period low byte -> period 0x1AC = 428
    pattern[2] = 0x10; // sample number low nibble = 1 (channel 0, row 0)
    pattern[4 + 2] = 0x0D; // channel 1, row 0: effect D (pattern break)
    pattern[4 + 3] = 0x00; // break to row 0 of the next order
    try buf.appendSlice(allocator, &pattern);

    try buf.appendSlice(allocator, &[_]u8{ 10, 20, 30, 40 }); // sample 1's 4 bytes of PCM

    return buf.toOwnedSlice(allocator);
}

test "parse reads a minimal 4-channel M.K. file" {
    const allocator = std.testing.allocator;
    const bytes = try buildMinimalMod(allocator, 4, "M.K.");
    defer allocator.free(bytes);

    var mod = try parse(allocator, bytes);
    defer mod.deinit();

    try std.testing.expectEqual(@as(u8, 4), mod.num_channels);
    try std.testing.expectEqual(@as(u8, 1), mod.song_length);
    try std.testing.expectEqual(@as(u16, 1), mod.num_patterns);
    try std.testing.expectEqual(@as(usize, 4), mod.samples[0].data.len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 20, 30, 40 }, mod.samples[0].data);
}

test "parse recognizes xCHN and xxCH signatures" {
    const allocator = std.testing.allocator;
    {
        const bytes = try buildMinimalMod(allocator, 6, "6CHN");
        defer allocator.free(bytes);
        var mod = try parse(allocator, bytes);
        defer mod.deinit();
        try std.testing.expectEqual(@as(u8, 6), mod.num_channels);
    }
    {
        const bytes = try buildMinimalMod(allocator, 8, "OCTA");
        defer allocator.free(bytes);
        var mod = try parse(allocator, bytes);
        defer mod.deinit();
        try std.testing.expectEqual(@as(u8, 8), mod.num_channels);
    }
}

test "parse rejects a too-short buffer" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(ModError.TooShort, parse(allocator, &[_]u8{ 1, 2, 3 }));
}

test "parse rejects an unrecognized signature" {
    const allocator = std.testing.allocator;
    const bytes = try buildMinimalMod(allocator, 4, "XXXX");
    defer allocator.free(bytes);
    try std.testing.expectError(ModError.UnknownSignature, parse(allocator, bytes));
}

test "renderToPcm produces non-empty, non-silent stereo PCM for a one-row song" {
    const allocator = std.testing.allocator;
    const bytes = try buildMinimalMod(allocator, 4, "M.K.");
    defer allocator.free(bytes);

    var mod = try parse(allocator, bytes);
    defer mod.deinit();

    const pcm = try renderToPcm(allocator, &mod, 44100);
    defer allocator.free(pcm);

    // One row at the default speed=6/tempo=125 is 6 * 2.5/125 = 0.12s ->
    // ~5292 stereo frames (10584 i16 samples); assert it's in that ballpark
    // rather than pinning the exact rounding.
    try std.testing.expect(pcm.len > 8000 and pcm.len < 14000);

    var saw_nonzero = false;
    for (pcm) |s| {
        if (s != 0) {
            saw_nonzero = true;
            break;
        }
    }
    try std.testing.expect(saw_nonzero);
}

test "renderToPcm does not hang on a backward position jump" {
    const allocator = std.testing.allocator;
    var bytes = try buildMinimalMod(allocator, 4, "M.K.");
    defer allocator.free(bytes);

    // Overwrite channel 0's effect to Bxx (position jump to order 0, i.e.
    // "jump to where we already are") -- a from-scratch infinite-loop hazard
    // this test exists to guard against.
    const pattern_ofs = pattern_data_offset;
    bytes[pattern_ofs + 2] = 0x0B; // effect B
    bytes[pattern_ofs + 3] = 0x00; // param 0

    var mod = try parse(allocator, bytes);
    defer mod.deinit();

    const pcm = try renderToPcm(allocator, &mod, 44100);
    defer allocator.free(pcm);
    // Should stop promptly (song end on the non-forward jump), not run
    // until the safety cap.
    try std.testing.expect(pcm.len < 14000);
}

test "countFrames matches renderToPcm's actual output length" {
    const allocator = std.testing.allocator;
    const bytes = try buildMinimalMod(allocator, 4, "M.K.");
    defer allocator.free(bytes);

    var mod = try parse(allocator, bytes);
    defer mod.deinit();

    const predicted = countFrames(&mod, 44100);
    const pcm = try renderToPcm(allocator, &mod, 44100);
    defer allocator.free(pcm);

    try std.testing.expectEqual(predicted, pcm.len / 2);
}
