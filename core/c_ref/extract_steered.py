"""Generate core/c_ref/steer.c from main.c.

TASK-011.02's renamed-C reference is not a hand-copied excerpt: it is
main.c's steer_players() and position_player() function text extracted
verbatim from the current checkout, so the differential cannot drift from the
oracle through transcription the way a hand-ported `.c` copy would. main.c
itself is never modified.

The cut ranges are found by scanning for the two definition lines and the
definition lines that follow them (not hardcoded line numbers), so small
edits elsewhere in main.c don't break the extraction. Regenerate after any
change to those two functions:

    python3 core/c_ref/extract_steered.py

The generated file's header records the main.c line range it came from, so a
reviewer can diff it against the oracle directly.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN_C = ROOT / "main.c"
OUT = Path(__file__).resolve().parent / "steer.c"

# steer.c's preamble: the macros, struct twins and harness-owned globals the
# two extracted functions reference. Everything declared here is defined
# either in this file (the typedefs/macros) or in the difftest harness
# (core/steer_difftest.zig), which shares one copy of the world state with
# the Zig port so both sides run against identical inputs.
PREAMBLE = """/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/steer.zig (TASK-011.02): main.c lines
 * {start}-{end}, extracted verbatim by core/c_ref/extract_steered.py.
 * Re-run that script if either function changes; editing this file by hand
 * reintroduces exactly the transcription drift the extraction exists to
 * prevent. core/build.zig compiles it through compileRenamedCRef, which
 * prefixes every symbol below with c_ so it links alongside the Zig port
 * (which owns the original names).
 *
 * What the two functions touch that main.c keeps outside themselves:
 * player_anims[] (built in init_program() from a local table), the
 * ban_map[]/player[]/objects[] world state, the cheat/mode globals
 * (pogostick, jetpack, bunnies_in_space, blood_is_thicker_than_water),
 * rnd(), dj_play_sfx() and add_object(). The harness owns all of that -
 * one shared world both sides mutate, a pre-generated rnd() stream both
 * sides draw from through c_rnd_from() (the rnd(max) macro below), and no-op
 * audio - so the only difference the differential can detect is the ported
 * logic itself.
 *
 * The player[]/ban_map[]/objects[] declarations carry a _raw suffix
 * because compileRenamedCRef renames every token in this translation unit
 * - the extern declarations included. The #define player player_raw /
 * #define ban_map ban_map_raw / #define objects objects_raw below restore
 * the names the extracted text uses, so the function bodies stay verbatim.
 * (player_anims[] needs no alias: the rename leaves references to symbols
 * defined in *other* translation units alone, so that extern keeps binding
 * to core/steer.zig's export.)
 */

#include <stdlib.h>

#define BAN_VOID\t0
#define BAN_SOLID\t1
#define BAN_WATER\t2
#define BAN_ICE\t3
#define BAN_SPRING\t4

#define JNB_MAX_PLAYERS 4
#define NUM_OBJECTS 200

#define OBJ_SPRING 0
#define OBJ_SPLASH 1
#define OBJ_SMOKE 2
#define OBJ_ANIM_SPLASH 1
#define OBJ_ANIM_SMOKE 2

#define SFX_JUMP 1
#define SFX_SPRING 2
#define SFX_SPLASH 3
#define SFX_JUMP_FREQ 15000
#define SFX_SPRING_FREQ 15000
#define SFX_SPLASH_FREQ 12000

#define GET_BAN_MAP_XY(x,y) ban_map[(y) >> 4][(x) >> 4]

typedef struct {{
\tint num_frames;
\tint restart_frame;
\tstruct {{
\t\tint image;
\t\tint ticks;
\t}} frame[4];
}} player_anim_t;

typedef struct {{
\tint action_left, action_up, action_right;
\tint enabled, dead_flag;
\tint bumps;
\tint bumped[JNB_MAX_PLAYERS];
\tint x, y;
\tint x_add, y_add;
\tint direction, jump_ready, jump_abort, in_water;
\tint anim, frame, frame_tick, image;
}} player_t;

typedef struct {{
\tint used, type;
\tint x, y;
\tint x_add, y_add;
\tint x_acc, y_acc;
\tint anim;
\tint frame, ticks;
\tint image;
}} object_t;

/* Defined by the harness (core/steer_difftest.zig): the one world both sides
 * mutate, in the layout docs/checksum-format.md fixes. */
extern player_t player_raw[JNB_MAX_PLAYERS];
extern object_t objects_raw[NUM_OBJECTS];
extern unsigned int ban_map_raw[17][22];
extern player_anim_t player_anims[7];

#define player player_raw
#define ban_map ban_map_raw
#define objects objects_raw
extern int pogostick, bunnies_in_space, jetpack, blood_is_thicker_than_water;
extern int is_server, is_net;
extern unsigned int rnd_call_count;

/* main.c's object_anims (main.c:96-103) — harness-owned, loaded with the
 * same table values (core/steer_difftest.zig). */
typedef struct {{
	int num_frames;
	int restart_frame;
	struct {{
		int image;
		int ticks;
	}} frame[10];
}} object_anim_t;
extern object_anim_t object_anims[8];

/* Harness-provided. c_rnd_from() serves both sides the same pre-generated
 * draw sequence; dj_play_sfx() drops its arguments (the C's argument
 * evaluation, and with it the checksummed rnd() draws, still happens at the
 * call sites); add_object() is main.c's own, mirrored on the Zig side. */
unsigned short c_rnd_from(unsigned short max);
void dj_play_sfx(int id, int freq, int vol, int pan, int unused, int channel);
void add_object(int type, int x, int y, int x_add, int y_add, int anim, int frame);
#define rnd(max) c_rnd_from((max))

/* steer_players calls position_player directly; the build renames both,
 * forward-declare so the intra-reference call resolves without needing
 * declaration order. The two action handlers are extracted verbatim above
 * steer_players (main.c keeps them static ahead of it), so they need no
 * declaration of their own. */
void position_player(int player_num);
/* steer_players' prologue calls (cpu_move is TASK-011.05,
 * update_player_actions the input layer); the harness defines both away so
 * the extracted tick body starts where the port's does. */
void cpu_move(void);
void update_player_actions(void);
"""


def find_line(lines, prefix, start=0):
    for i in range(start, len(lines)):
        if lines[i].startswith(prefix):
            return i
    sys.exit(f"main.c: no line starting with {prefix!r}")


def main() -> None:
    lines = MAIN_C.read_text().split("\n")

    steer_start = find_line(lines, "void steer_players(void)")
    steer_end = find_line(lines, "void position_player(int player_num)", steer_start)
    pos_end = find_line(lines, "void add_object(int type", steer_end)

    # steer_players() calls main.c's two static action helpers (main.c:1771,
    # main.c:1812); they live outside the steer/position range, so cut them
    # out too and keep them verbatim, ahead of the entry points that call
    # them.
    action_start = find_line(lines, "static void player_action_left(int c1)")
    action_end = find_line(lines, "int map_tile(int pos_x, int pos_y)", action_start)
    assert action_start < steer_start, "player_action_* moved below steer_players()?"

    # Each range runs from a definition line up to the next top-level
    # definition, which is exactly that function's text including its closing
    # brace. steer_players() also loses the GET_BAN_MAP_IN_WATER macro it
    # uses; steer.c re-declares it below the preamble rather than in it, so
    # the extracted text stays untouched.
    actions = "\n".join(lines[action_start:action_end]).rstrip("\n")
    entry = "\n".join(lines[steer_start:pos_end]).rstrip("\n")
    functions = actions + "\n\n" + entry

    macro = (
        "\n\n#define GET_BAN_MAP_IN_WATER(s1, s2) "
        "(GET_BAN_MAP_XY((s1), ((s2) + 7)) == BAN_VOID || GET_BAN_MAP_XY(((s1) + 15), ((s2) + 7)) == BAN_VOID)"
        " && (GET_BAN_MAP_XY((s1), ((s2) + 8)) == BAN_WATER || GET_BAN_MAP_XY(((s1) + 15), ((s2) + 8)) == BAN_WATER)\n"
    )
    start_of_macro = find_line(lines, "#define GET_BAN_MAP_IN_WATER")
    assert start_of_macro < steer_start, "GET_BAN_MAP_IN_WATER moved below steer_players()?"
    macro = "\n" + lines[start_of_macro] + "\n"

    OUT.write_text(
        PREAMBLE.format(start=steer_start + 1, end=pos_end) + macro + "\n" + functions + "\n"
    )
    print(f"{OUT.name}: main.c lines {steer_start + 1}-{pos_end} extracted")


if __name__ == "__main__":
    main()
