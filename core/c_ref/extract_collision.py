"""Generate core/c_ref/collision.c from main.c.

TASK-011.03's renamed-C reference is not a hand-copied excerpt: it is
main.c's collision_check(), player_kill() and processKillPacket() function
text extracted verbatim from the current checkout, so the differential
cannot drift from the oracle through transcription the way a hand-ported
`.c` copy would. main.c itself is never modified.

The cut ranges are found by scanning for the three definition lines and the
definition lines that follow them (not hardcoded line numbers), so small
edits elsewhere in main.c don't break the extraction. Regenerate after any
change to those three functions:

    python3 core/c_ref/extract_collision.py

The generated file's header records the main.c line ranges it came from, so
a reviewer can diff it against the oracle directly.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN_C = ROOT / "main.c"
OUT = Path(__file__).resolve().parent / "collision.c"

# collision.c's preamble: the macros, struct twins and harness-owned globals
# the three extracted functions reference. Everything declared here is
# defined either in this file (the typedefs/macros) or in the difftest
# harness (core/collision_difftest.zig), which shares one copy of the world
# state with the Zig port so both sides run against identical inputs.
PREAMBLE = """/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/collision.zig (TASK-011.03): main.c lines
 * {kill_start}-{kill_end} (processKillPacket), {player_kill_start}-{player_kill_end}
 * (player_kill) and {collision_start}-{collision_end} (collision_check),
 * extracted verbatim by core/c_ref/extract_collision.py. Re-run that script
 * if any of the three functions changes; editing this file by hand
 * reintroduces exactly the transcription drift the extraction exists to
 * prevent. core/build.zig compiles it through compileRenamedCRef, which
 * prefixes every symbol below with c_ so it links alongside the Zig port
 * (which owns the original names).
 *
 * What the three functions touch that main.c keeps outside themselves:
 * player[]/objects[]/ban_map[] world state (shared with the port through
 * the *_raw storage the harness defines), player_anims[] (built in
 * init_program()), the no_gore flag (main_info.no_gore in the C; a plain
 * global here, same value on both sides), rnd(), add_object() and
 * dj_play_sfx(). The four add_leftovers() score-digit pushes are dropped:
 * pob bookkeeping is presentation and never enters the canonical state
 * (docs/porting-playbook.md "Core purity").
 * One deliberate stub: serverSendKillPacket() is a macro over
 * kill_dispatch(), which the harness supplies. It stands in for main.c's
 * serverSendKillPacket, which after filling a NETCMD_KILL packet from the
 * victim's live x/y calls processKillPacket() with it — so the harness gets
 * the killer, victim and *current* victim position, and the real net layer
 * (assert(is_server), packet encode, sendPacketToAll) stays out of the
 * differential.
 */

#include <stdlib.h>

#define JNB_MAX_PLAYERS 4
#define NUM_OBJECTS 200

#define BAN_VOID\t0
#define BAN_SOLID\t1
#define BAN_WATER\t2
#define BAN_ICE\t3
#define BAN_SPRING\t4

#define OBJ_FUR 5
#define OBJ_FLESH 6

#define SFX_DEATH 2
#define SFX_DEATH_FREQ 20000

typedef struct {{
	int num_frames;
	int restart_frame;
	struct {{
		int image;
		int ticks;
	}} frame[4];
}} player_anim_t;

typedef struct {{
	int action_left, action_up, action_right;
	int enabled, dead_flag;
	int bumps;
	int bumped[JNB_MAX_PLAYERS];
	int x, y;
	int x_add, y_add;
	int direction, jump_ready, jump_abort, in_water;
	int anim, frame, frame_tick, image;
}} player_t;

typedef struct {{
	int used, type;
	int x, y;
	int x_add, y_add;
	int x_acc, y_acc;
	int anim;
	int frame, ticks;
	int image;
}} object_t;

/* Defined by the harness (core/collision_difftest.zig): the one world both
 * sides mutate, in the layout docs/checksum-format.md fixes. player[] and
 * ban_map[] carry the _raw suffix (the linker alias below maps it back for
 * the extracted text), because compileRenamedCRef renames every token in
 * this translation unit — including the declaration itself. objects[] is
 * core/steer.zig's export under its own name and stays unaliased; so does
 * is_server, which steer_difftest-style the harness pins to the headless
 * server value. */
/* main.c's player[]/objects[]/ban_map[], aliased to _raw link names:
 * compileRenamedCRef renames every token in this translation unit (the
 * extern declarations included), so the declarations get the suffix and
 * the #defines below restore the names the extracted text uses. All three
 * arrays are core/c_ref/sim_harness.c's shared storage, which every Zig
 * module under test reaches through its own extern mirror. */
extern player_t player_raw[JNB_MAX_PLAYERS];
extern object_t objects_raw[NUM_OBJECTS];
extern unsigned int ban_map_raw[17][22];
/* player_anims[] is core/steer.zig's export under its own name, so the
 * harness does not define it and it needs no _raw alias. */
extern player_anim_t player_anims[7];
extern int no_gore;
extern int is_server;
extern unsigned int rnd_call_count;

#define player player_raw
#define ban_map ban_map_raw
#define objects objects_raw

/* Harness-provided. c_rnd_from() serves both sides the same libc rand()
 * stream; dj_play_sfx() only records (its argument expression, and with it
 * the checksummed rnd() draw, still evaluates at the call site);
 * add_object() is main.c's own, mirrored on the Zig side;
 * kill_dispatch(killer, victim, x, y) stands in for serverSendKillPacket;
 * add_leftovers() is dropped. */
unsigned short c_rnd_from(unsigned short max);
void dj_play_sfx(int id, int freq, int vol, int pan, int unused, int channel);
void add_object(int type, int x, int y, int x_add, int y_add, int anim, int frame);
/* The extracted functions call each other one way only:
 * collision_check -> player_kill -> serverSendKillPacket ->
 * processKillPacket. The last hop goes through kill_dispatch, which the
 * harness owns: it stands in for main.c's serverSendKillPacket, which
 * after filling a NETCMD_KILL packet from the victim's live x/y calls
 * processKillPacket() with it. The real net layer (assert(is_server),
 * packet encode, sendPacketToAll) stays out of the differential. */
void kill_dispatch(int killer, int victim, int x, int y);
#define rnd(max) c_rnd_from((max))
#define serverSendKillPacket(killer, victim) kill_dispatch((killer), (victim), player[(victim)].x, player[(victim)].y)
#define add_leftovers(page, x, y, image, pob_data) 0

/* main_info.no_gore in the extracted text; only the no_gore field is read
 * on this path, so the harness (core/collision_difftest.zig) owns a struct
 * twin with exactly that field — this TU only declares it. */
struct main_info_t {{
	int no_gore;
}};
extern struct main_info_t main_info;
"""


def find_line(lines, prefix, start=0):
    for i in range(start, len(lines)):
        if lines[i].startswith(prefix):
            return i
    sys.exit(f"main.c: no line starting with {prefix!r}")


def main() -> None:
    lines = MAIN_C.read_text().split("\n")

    # processKillPacket() lives in the netcode block and carries no `static`;
    # player_kill()/collision_check() are file-static. Each range runs from a
    # definition line up to the next top-level definition line, which is
    # exactly that function's text including its closing brace.
    kill_start = find_line(lines, "void processKillPacket(NetPacket *pkt)")
    kill_end = find_line(lines, "#ifdef USE_NET", kill_start)
    kill = "\n".join(lines[kill_start:kill_end]).rstrip("\n")
    # The extracted body keeps the NetPacket parameter; the harness never
    # builds one, so the typedef is spelled out in front of it instead of
    # pulling globals.pre's whole net struct in.
    kill = (
        "typedef struct {\n"
        "\tunsigned long cmd;\n"
        "\tlong arg, arg2, arg3, arg4;\n"
        "/* Field types copied from main.c's NetPacket; the real struct\n"
        "\t * carries no trailing field processKillPacket reads. The\n"
        "\t * harness's kill_dispatch wrapper builds one byte-for-byte. */\n"
        "} NetPacket;\n\n"
        + kill
    )

    player_kill_start = find_line(lines, "static void player_kill(int c1, int c2)")
    player_kill_end = find_line(lines, "static void check_cheats(void)", player_kill_start)
    player_kill = "\n".join(lines[player_kill_start:player_kill_end]).rstrip("\n")

    collision_start = find_line(lines, "static void collision_check(void)")
    collision_end = find_line(lines, "static unsigned int checksum_fold_u32(", collision_start)
    collision = "\n".join(lines[collision_start:collision_end]).rstrip("\n")

    # After the three extracted definitions: the harness entry points.
    # compileRenamedCRef's -D renames already turn the extracted
    # definitions into c_collision_check / c_player_kill /
    # c_processKillPacket; collision_check and player_kill are file-static
    # in main.c, so a non-static definition of each goes through the
    # renamed name, and processKillPacket gets a wrapper spelled so the
    # rename leaves it (kill_packet_entry) reachable by the harness.
    wrappers = """

/* ---- harness entry points (not from main.c) ---- */

int kill_packet_entry(int killer, int victim, int x, int y)
{
	NetPacket pkt;

	pkt.cmd = 0;
	pkt.arg = killer;
	pkt.arg2 = victim;
	pkt.arg3 = x;
	pkt.arg4 = y;
	processKillPacket(&pkt);
	return 0;
}

void collision_tick(void)
{
	collision_check();
}

void player_kill_gate(int c1, int c2)
{
	player_kill(c1, c2);
}
"""

    OUT.write_text(
        PREAMBLE.format(
            kill_start=kill_start + 1,
            kill_end=kill_end,
            player_kill_start=player_kill_start + 1,
            player_kill_end=player_kill_end,
            collision_start=collision_start + 1,
            collision_end=collision_end,
        )
        + "\n"
        + kill
        + "\n\n"
        + player_kill
        + "\n\n"
        + collision
        + wrappers
    )
    print(
        f"{OUT.name}: main.c lines {kill_start + 1}-{kill_end}, "
        f"{player_kill_start + 1}-{player_kill_end}, "
        f"{collision_start + 1}-{collision_end} extracted"
    )


if __name__ == "__main__":
    main()
