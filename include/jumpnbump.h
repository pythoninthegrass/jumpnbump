/*
 * jumpnbump.h — the frozen C ABI contract for the jumpnbump Zig simulation
 * core (TASK-012.01).
 *
 * This is the ONLY header any consumer (GDExtension shim, native binding,
 * conformance test) is allowed to depend on. core/abi.zig (TASK-012.02) is
 * the only Zig file that may export the jnb_* symbols declared here, and
 * every export it makes must have a matching declaration here — nothing
 * more, nothing less (docs/build-layout.md).
 *
 * Modeled on ~/git/neo_snake/include/neo_snake.h's discipline: opaque
 * caller-owned world handle, uint8_t/int32_t-typedef'd value spaces (never a
 * bare C enum crossing the ABI, since a C enum's underlying width is
 * unspecified), a static_assert on every ABI struct's sizeof, and a
 * two-call length-then-fill convention for every buffer whose required
 * length isn't a compile-time constant.
 *
 * ---------------------------------------------------------------------
 * Divergence from neo_snake: why jnb_world is not fully relocatable
 * ---------------------------------------------------------------------
 * neo_snake's ns_world is genuinely caller-relocatable: the caller
 * allocates ns_world_size(config) bytes anywhere and every accessor reaches
 * it through the passed-in pointer. jumpnbump's Phase 3 simulation modules
 * (core/steer.zig, core/objects.zig, core/collision.zig, core/flies.zig,
 * core/cpu_move.zig — all already ported and differential-tested,
 * TASK-011.*, before this ABI existed) instead reach the live simulation
 * state — player[], objects[], ban_map[], keyb[] — through `extern var`
 * declarations, which the linker binds to one fixed global symbol, not a
 * runtime pointer. That memory cannot be relocated into caller-supplied
 * storage without rewriting every already-shipped ported module, so
 * core/abi.zig owns it itself, as singleton storage.
 *
 * The practical consequence: **at most one jnb_world exists per process.**
 * What jnb_world_size() bytes of caller-owned storage actually holds is the
 * genuinely per-instance bookkeeping core/game_loop.zig's step()/pump()
 * already take as explicit parameters rather than module-level state — the
 * event classifier's previous-tick edge detection and the fixed-timestep
 * accumulator (core/game_loop.zig's State and PumpState). This keeps the
 * caller-owned-memory contract meaningful for the part of the state that
 * really is per-instance, while being honest that the simulation arrays
 * are not. A second concurrent jnb_world would silently share the same
 * player[]/objects[]/ban_map[] as the first; nothing here is safe to call
 * from more than one such handle at a time.
 */

#ifndef JUMPNBUMP_H
#define JUMPNBUMP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__cplusplus)
#define JNB_STATIC_ASSERT(cond, msg) static_assert(cond, msg)
#else
#define JNB_STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
#endif

/* ---------------------------------------------------------------------- */
/* Versioning                                                              */
/* ---------------------------------------------------------------------- */

/* Bump on any change to this header's function signatures, calling
 * convention, or exported semantics. Every binding must be rebuilt and
 * relinked when this changes.
 *
 * 2: added the jnb_dat_find / jnb_gob_... / jnb_level_layers_... surface
 * (TASK-016.01, runtime .dat asset decoding) alongside the pre-existing
 * jnb_world_... simulation surface. jnb_config's own layout is unchanged. */
#define JNB_ABI_VERSION 2u

/* core/world.zig's fixed simulation dimensions (JNB_MAX_PLAYERS,
 * NUM_OBJECTS, and the ban_map's 17x22 grid — 17 rows because
 * core/levelmap.zig force-fills a floor row past the 16 the level file
 * encodes). Frozen: every ABI struct below is sized against these. */
#define JNB_MAX_PLAYERS 4u
#define JNB_NUM_OBJECTS 200u
#define JNB_BAN_ROWS 17u
#define JNB_BAN_COLS 22u

/* core/asset_runtime.zig's fixed asset dimensions (TASK-016.01): main.c's
 * screen resolution (sdl/gfx.c), which every level/menu PCX pair and every
 * sprite atlas this ABI builds is packed into. */
#define JNB_ASSET_SCREEN_W 400u
#define JNB_ASSET_SCREEN_H 256u
#define JNB_ASSET_RGBA_LEN (JNB_ASSET_SCREEN_W * JNB_ASSET_SCREEN_H * 4u)
#define JNB_ASSET_PALETTE_SIZE 768u

/* ---------------------------------------------------------------------- */
/* Result codes                                                           */
/*                                                                         */
/* Plain int32_t, not a C enum: a C enum's underlying integer width is     */
/* unspecified by the language, which is exactly the kind of ambiguity a   */
/* frozen cross-language (C / C++ / Zig / GDExtension) ABI cannot afford.  */
/* ---------------------------------------------------------------------- */

typedef int32_t jnb_result;

enum {
    JNB_OK = 0,
    /* An out-of-range or malformed argument: an unknown player index, an
     * out-of-range object index, a config->abi_version mismatch handled
     * separately below, etc. */
    JNB_ERR_INVALID_ARGUMENT = 1,
    /* An output buffer's capacity was smaller than the required length.
     * The call still reports the true required length so the caller can
     * retry (the two-call length-then-fill contract; see jnb_objects_copy,
     * jnb_world_dump, jnb_event_drain). */
    JNB_ERR_BUFFER_TOO_SMALL = 2,
    /* config->abi_version did not equal JNB_ABI_VERSION. */
    JNB_ERR_ABI_VERSION_MISMATCH = 3,
    /* jnb_world_init was given level bytes core/levelmap.zig's parser
     * could not read (truncated levelmap.txt content). */
    JNB_ERR_LEVEL_PARSE_FAILED = 4,
    /* jnb_dat_find found no entry whose name prefix-matches the query
     * (core/dat.zig's prefixMatch semantics -- see jnb_dat_find). */
    JNB_ERR_ASSET_NOT_FOUND = 5,
    /* A .gob/.pcx buffer was malformed or truncated (core/gob.zig's or
     * core/pcx.zig's DecodeError), or a .gob's frames don't fit the fixed
     * JNB_ASSET_SCREEN_W x JNB_ASSET_SCREEN_H atlas grid
     * (core/asset_runtime.zig's TooManyFrames). */
    JNB_ERR_ASSET_DECODE_FAILED = 6,
};

/* ---------------------------------------------------------------------- */
/* Ordered event kinds                                                     */
/*                                                                         */
/* Mirrors core/game_loop.zig's EventKind enum(c_int) verbatim, same       */
/* numeric values, so core/abi.zig can @intFromEnum directly with no       */
/* remapping table.                                                        */
/* ---------------------------------------------------------------------- */

typedef uint8_t jnb_event_kind;
enum {
    JNB_EVENT_SFX = 1,
    JNB_EVENT_OBJECT_SPAWN = 2,
    JNB_EVENT_PLAYER_DEATH = 3,
    JNB_EVENT_SCORE_CHANGE = 4,
    JNB_EVENT_DRAW = 5,
    JNB_EVENT_SFX_VOLUME = 6,
};

/* ---------------------------------------------------------------------- */
/* Opaque world handle                                                    */
/* ---------------------------------------------------------------------- */

/* Never defined — callers only ever hold a pointer. The caller allocates
 * jnb_world_size() bytes aligned to jnb_world_align() and passes that
 * storage to jnb_world_init(); nothing on this side of the ABI allocates,
 * and there is deliberately no jnb_world_destroy (adding one later is
 * additive; removing one later is not). See the file header comment for
 * why this storage is smaller than "the whole simulation" — at most one
 * jnb_world is meaningful per process regardless of this handle's size. */
typedef struct jnb_world jnb_world;

/* ---------------------------------------------------------------------- */
/* Config                                                                  */
/* ---------------------------------------------------------------------- */

typedef struct jnb_config {
    uint16_t abi_version; /* must equal JNB_ABI_VERSION */
    uint16_t _pad0;        /* specified-zero; pads rng_seed to a 4-byte offset */
    uint32_t rng_seed;     /* core/rnd.zig's seed(); must be nonzero */
    uint8_t flies_enabled; /* 0 or 1; core/game_loop.zig's flies_enabled flag */
    /* Number of players jnb_world_init enables, indices 0..player_count-1
     * (main.c's own headless setup, main.c:1549-1561, only ever enables a
     * contiguous run starting at player 0). Clamped to
     * [0, JNB_MAX_PLAYERS]. */
    uint8_t player_count;
    /* Bit i set means player i is AI-controlled (core/cpu_move.zig drives
     * it instead of jnb_step/jnb_pump's per-tick input) -- main.c's ai[]
     * (main.c:1559). Bits at or past player_count are ignored. */
    uint8_t player_ai_mask;
    /* 0 or 1; core/collision.zig's no_gore flag (main.c's `-nogore` CLI
     * flag) -- suppresses OBJ_FUR/OBJ_FLESH gore object spawns on a kill
     * without changing whether the kill itself happens. */
    uint8_t no_gore;
} jnb_config;
JNB_STATIC_ASSERT(sizeof(jnb_config) == 12, "jnb_config layout changed");

/* ---------------------------------------------------------------------- */
/* Per-tick input                                                         */
/*                                                                         */
/* One bit per player (bit i = player i), matching                        */
/* core/game_loop.zig's Inputs{left,right,jump: [4]bool}. An AI-driven     */
/* player's bits are ignored -- core/cpu_move.zig's cpu_move() drives that */
/* player instead, exactly as it does for the ported simulation today.    */
/* ---------------------------------------------------------------------- */

typedef struct jnb_input {
    uint8_t left;
    uint8_t right;
    uint8_t jump;
    uint8_t _pad;
} jnb_input;
JNB_STATIC_ASSERT(sizeof(jnb_input) == 4, "jnb_input layout changed");

/* ---------------------------------------------------------------------- */
/* Per-player view                                                        */
/*                                                                         */
/* Wire-exact mirror of the fields of core/world.zig's Player a consumer   */
/* actually needs to render/react to one player -- not every field         */
/* (frame_tick and the per-victim bumped[] tally are internal-only).       */
/* ---------------------------------------------------------------------- */

typedef struct jnb_player_view {
    uint8_t enabled;
    uint8_t dead_flag;
    uint8_t direction;
    uint8_t jump_ready;
    uint8_t jump_abort;
    uint8_t in_water;
    uint8_t _pad0[2]; /* specified-zero; pads x to a 4-byte offset */
    int32_t x;
    int32_t y;
    int32_t x_add;
    int32_t y_add;
    int32_t bumps;
    int32_t anim;
    int32_t frame;
    int32_t image;
} jnb_player_view;
JNB_STATIC_ASSERT(sizeof(jnb_player_view) == 40, "jnb_player_view layout changed");

/* ---------------------------------------------------------------------- */
/* Per-object view                                                        */
/*                                                                         */
/* Wire-exact mirror of core/world.zig's Object, sans x_acc/y_acc/ticks    */
/* (internal-only physics scratch a renderer never needs).                */
/* ---------------------------------------------------------------------- */

typedef struct jnb_object_view {
    uint8_t used;
    uint8_t _pad0[3]; /* specified-zero; pads type to a 4-byte offset */
    int32_t type;
    int32_t x;
    int32_t y;
    int32_t x_add;
    int32_t y_add;
    int32_t anim;
    int32_t frame;
    int32_t image;
} jnb_object_view;
JNB_STATIC_ASSERT(sizeof(jnb_object_view) == 36, "jnb_object_view layout changed");

/* ---------------------------------------------------------------------- */
/* Ordered events                                                         */
/*                                                                         */
/* Wire-exact mirror of core/game_loop.zig's GameEvent{kind,a,b,c,d}. A    */
/* consumer (audio, Godot presentation) drains discrete, ordered events    */
/* produced by the tick that just ran, in the order the tick produced      */
/* them -- see core/game_loop.zig's own doc comment for exactly what each  */
/* event kind's a/b/c/d payload means.                                     */
/* ---------------------------------------------------------------------- */

typedef struct jnb_event {
    jnb_event_kind kind;
    uint8_t _pad[3]; /* specified-zero; pads a to a 4-byte offset */
    int32_t a;
    int32_t b;
    int32_t c;
    int32_t d;
} jnb_event;
JNB_STATIC_ASSERT(sizeof(jnb_event) == 20, "jnb_event layout changed");

/* ---------------------------------------------------------------------- */
/* World lifecycle                                                        */
/* ---------------------------------------------------------------------- */

/* Bytes the caller must allocate for one world (see the file header
 * comment for what this storage actually holds and why it is not the
 * whole simulation). Fixed -- unlike neo_snake's board-size-dependent
 * ns_world_size, jumpnbump's dimensions (JNB_MAX_PLAYERS/JNB_NUM_OBJECTS/
 * the ban_map grid) are compile-time constants, so this takes no config
 * argument. */
size_t jnb_world_size(void);

/* Required alignment for the storage passed to jnb_world_init. */
size_t jnb_world_align(void);

/* Initializes caller-supplied storage (jnb_world_size() bytes, aligned to
 * jnb_world_align()) as a fresh world, replicating main.c's own headless
 * startup sequence in order (main.c:1549-1598): seeds the RNG stream from
 * config->rng_seed (core/rnd.zig's seed()); parses level_bytes (raw
 * levelmap.txt-format content, core/levelmap.zig's parse()) into the
 * simulation's ban_map; resets player/object state; enables
 * config->player_count players (indices 0..player_count-1) and sets their
 * AI bit from config->player_ai_mask; positions each enabled player
 * (main.c's position_player(), avoiding overlap with already-positioned
 * players); seeds the level's spring/butterfly objects (main.c's
 * init_level() object seeding); and spawns the fly swarm if
 * config->flies_enabled. The last three steps draw from the same rnd()
 * stream this call just seeded, so a caller that needs bit-for-bit parity
 * with a recorded trace must not skip or reorder them.
 *
 * Returns JNB_ERR_ABI_VERSION_MISMATCH if config->abi_version !=
 * JNB_ABI_VERSION, JNB_ERR_INVALID_ARGUMENT if config->rng_seed == 0,
 * JNB_ERR_LEVEL_PARSE_FAILED if level_bytes is too short for
 * core/levelmap.zig's parser to read a full grid from. */
jnb_result jnb_world_init(jnb_world *world, const jnb_config *config, const uint8_t *level_bytes, size_t level_len);

/* Resets an already-initialized world to a fresh game: players, objects,
 * frame_num, and queued events are cleared. The already-loaded ban_map and
 * the RNG stream are NOT reset (the RNG continues from its current state,
 * matching neo_snake's ns_world_reset precedent) -- call jnb_world_init
 * again to load a different level or reseed. */
jnb_result jnb_world_reset(jnb_world *world);

/* ---------------------------------------------------------------------- */
/* Stepping                                                                */
/* ---------------------------------------------------------------------- */

/* Advances exactly one simulation tick (core/game_loop.zig's step()),
 * applying `inputs` for the tick. Any event the tick produced is queued;
 * drain it with jnb_event_drain. */
jnb_result jnb_step(jnb_world *world, jnb_input inputs);

/* Fixed-timestep convenience for local play (core/game_loop.zig's pump()):
 * advances every whole 60Hz tick delta_ms is worth, applying the same
 * `inputs` to each. *out_ticks receives how many ticks actually ran. */
jnb_result jnb_pump(jnb_world *world, uint32_t delta_ms, jnb_input inputs, uint32_t *out_ticks);

/* ---------------------------------------------------------------------- */
/* Per-player / per-object state                                          */
/* ---------------------------------------------------------------------- */

/* Fills *out_view for `player` (must be < JNB_MAX_PLAYERS). */
jnb_result jnb_player_view_get(const jnb_world *world, uint8_t player, jnb_player_view *out_view);

/* Two-call length-then-fill contract: pass out_objects == NULL (or
 * out_capacity == 0) to learn the required length via *out_required
 * without copying -- always JNB_NUM_OBJECTS, since every slot (used or
 * not) is copied, matching core/world.zig's World.objects layout. Pass a
 * real buffer of at least that length to copy every object slot into
 * out_objects. Returns JNB_ERR_BUFFER_TOO_SMALL (still setting
 * *out_required) if out_capacity is smaller than required. */
jnb_result jnb_objects_copy(const jnb_world *world, jnb_object_view *out_objects, size_t out_capacity, size_t *out_required);

/* ---------------------------------------------------------------------- */
/* Canonical serialization (docs/checksum-format.md)                       */
/* ---------------------------------------------------------------------- */

/* Exact byte length jnb_world_dump will write -- core/world.zig's
 * dump_len, a fixed constant (frame_num + rnd_call_count + all 4 players +
 * all 200 objects + the 374-cell ban_map, 4 bytes per field). Takes no
 * world argument since the length never varies. */
size_t jnb_world_dump_len(void);

/* Encodes the world's current canonical state (core/world.zig's dumpTo())
 * as the exact byte sequence docs/checksum-format.md's fold consumes.
 * Two-call contract identical in spirit to jnb_objects_copy: call
 * jnb_world_dump_len first, or retry with a larger buffer on
 * JNB_ERR_BUFFER_TOO_SMALL (*out_written is left at the required length in
 * that case). There is deliberately no matching load/deserialize function:
 * core/world.zig implements dumpTo() only, not a reverse parse, so this
 * ABI does not invent round-trip behavior the ported simulation doesn't
 * have yet. */
jnb_result jnb_world_dump(const jnb_world *world, uint8_t *out_buf, size_t out_capacity, size_t *out_written);

/* Computes core/world.zig's fnv1a32() over an already-dumped buffer
 * (typically the exact bytes jnb_world_dump just wrote) -- operates on
 * bytes, not a live world, so a checksum received from elsewhere (e.g. the
 * C oracle's CHECKSUM line) can be reproduced without a live world at
 * hand. */
jnb_result jnb_checksum(const uint8_t *bytes, size_t len, uint32_t *out_checksum);

/* ---------------------------------------------------------------------- */
/* Ordered event drain                                                    */
/* ---------------------------------------------------------------------- */

/* Number of events currently queued, without draining them. */
size_t jnb_event_count(const jnb_world *world);

/* Drains up to out_capacity queued events, in the order the tick(s) that
 * produced them ran, into out_events; *out_count receives how many were
 * actually written. Any events beyond out_capacity remain queued for a
 * subsequent call -- nothing is dropped by a too-small buffer, matching
 * core/game_loop.zig's own per-tick Events (silent truncation only past
 * 256 events in a single tick, an existing Phase 3 limit this ABI does
 * not change). */
jnb_result jnb_event_drain(jnb_world *world, jnb_event *out_events, size_t out_capacity, size_t *out_count);

/* ---------------------------------------------------------------------- */
/* Runtime .dat asset decoding (TASK-016.01)                               */
/*                                                                         */
/* Pure buffer-in/buffer-out functions: no world, no allocation visible to */
/* the caller, no file I/O. A consumer (the GDExtension shim) reads a      */
/* custom .dat's raw bytes itself, uses jnb_dat_find to locate each named  */
/* entry inside it, and feeds those entry bytes to the gob/pcx functions   */
/* below to get back RGBA8 pixel buffers ready to wrap in a Godot Image -- */
/* the same atlas/layer layout tools/build_sprite_atlas.py and             */
/* tools/build_level_layers.py produce at build time (core/asset_runtime.zig */
/* is the single implementation both share).                              */
/* ---------------------------------------------------------------------- */

/* One packed sprite frame's placement inside the RGBA8 atlas jnb_gob_atlas_build
 * writes, plus its hotspot (core/gob.zig's Image.hs_x/hs_y, sign preserved). */
typedef struct jnb_atlas_frame {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
    int32_t hotspot_x;
    int32_t hotspot_y;
} jnb_atlas_frame;
JNB_STATIC_ASSERT(sizeof(jnb_atlas_frame) == 24, "jnb_atlas_frame layout changed");

/* dat_open/dat_filelen (main.c): find the .dat entry whose 12-byte name
 * field case-insensitively PREFIX-matches `name` (core/dat.zig's
 * prefixMatch -- not equality; "menu" matches "menumask.pcx"), and report
 * its byte offset/size within `buf`. Returns JNB_ERR_ASSET_NOT_FOUND if no
 * entry matches (out_offset/out_size left unmodified in that case). */
jnb_result jnb_dat_find(const uint8_t *buf, size_t buf_len, const char *name, size_t name_len, size_t *out_offset, size_t *out_size);

/* Number of images a .gob buffer decodes to (core/gob.zig's decode()),
 * without building an atlas -- use this to size out_frames before calling
 * jnb_gob_atlas_build. Returns JNB_ERR_ASSET_DECODE_FAILED if gob_buf is
 * malformed or truncated. */
jnb_result jnb_gob_frame_count(const uint8_t *gob_buf, size_t gob_len, size_t *out_count);

/* Decodes menu.pcx's embedded palette, display-scaled (core/asset_runtime.zig's
 * scaleDisplayPalette -- undoes core/pcx.zig's VGA 6-bit DAC read-side
 * scaling), into out_palette_rgb768 (exactly JNB_ASSET_PALETTE_SIZE bytes).
 * main.c loads menu.pcx once at startup and shares that single palette
 * across rabbit.gob/objects.gob/numbers.gob/font.gob, so decode it once per
 * .dat and reuse the result for every jnb_gob_atlas_build call against that
 * .dat. Returns JNB_ERR_INVALID_ARGUMENT if palette_capacity !=
 * JNB_ASSET_PALETTE_SIZE, or JNB_ERR_ASSET_DECODE_FAILED if pcx_buf is
 * malformed, truncated, or carries no palette. */
jnb_result jnb_pcx_palette_decode(const uint8_t *pcx_buf, size_t pcx_len, uint8_t *out_palette_rgb768, size_t palette_capacity);

/* Decodes a .gob sprite sheet and packs every frame into a single
 * JNB_ASSET_SCREEN_W x JNB_ASSET_SCREEN_H RGBA8 atlas (core/asset_runtime.zig's
 * buildSpriteAtlas -- a uniform tile grid sized to the .gob's largest frame,
 * color index 0 transparent). palette_rgb768 must be JNB_ASSET_PALETTE_SIZE
 * display-scaled bytes, e.g. jnb_pcx_palette_decode's output for the same
 * .dat's menu.pcx.
 *
 * Two-call length-then-fill contract for out_frames, matching
 * jnb_objects_copy: pass out_frames == NULL (or frames_capacity == 0) to
 * learn the required length via *out_frame_count without decoding pixels.
 * Pass a real buffer of at least that length, plus an out_pixels buffer of
 * exactly JNB_ASSET_RGBA_LEN bytes, to build the atlas. Returns
 * JNB_ERR_BUFFER_TOO_SMALL (still setting *out_frame_count) if
 * frames_capacity is smaller than required, JNB_ERR_INVALID_ARGUMENT if
 * out_frames is non-NULL but pixels_capacity != JNB_ASSET_RGBA_LEN, and
 * JNB_ERR_ASSET_DECODE_FAILED if gob_buf is malformed, truncated, or its
 * frames don't fit the fixed atlas grid. */
jnb_result jnb_gob_atlas_build(
    const uint8_t *gob_buf,
    size_t gob_len,
    const uint8_t *palette_rgb768,
    jnb_atlas_frame *out_frames,
    size_t frames_capacity,
    size_t *out_frame_count,
    uint8_t *out_pixels,
    size_t pixels_capacity
);

/* Decodes a level/menu PCX pair (pcx_buf carrying its own embedded,
 * display-scaled palette; mask_buf a paletteless boolean stencil, main.c's
 * mask.pcx/menumask.pcx) into an opaque background RGBA8 buffer and an
 * alpha-keyed foreground RGBA8 buffer that must draw on top of sprites
 * (core/asset_runtime.zig's buildLevelLayers -- see tools/build_level_layers.py's
 * module docstring for the put_pob occlusion semantics this reproduces).
 * Both output buffers must be exactly JNB_ASSET_RGBA_LEN bytes -- the size
 * is fixed, so unlike jnb_objects_copy there is no separate length query.
 * Returns JNB_ERR_INVALID_ARGUMENT if either capacity is wrong, or
 * JNB_ERR_ASSET_DECODE_FAILED if pcx_buf or mask_buf is malformed or
 * truncated. */
jnb_result jnb_level_layers_build(
    const uint8_t *pcx_buf,
    size_t pcx_len,
    const uint8_t *mask_buf,
    size_t mask_len,
    uint8_t *out_background_rgba,
    size_t background_capacity,
    uint8_t *out_foreground_rgba,
    size_t foreground_capacity
);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* JUMPNBUMP_H */
