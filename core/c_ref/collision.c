/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/collision.zig (TASK-011.03): main.c lines
 * 559-601 (processKillPacket), 1111-1122
 * (player_kill) and 1169-1244 (collision_check),
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

#define BAN_VOID	0
#define BAN_SOLID	1
#define BAN_WATER	2
#define BAN_ICE	3
#define BAN_SPRING	4

#define OBJ_FUR 5
#define OBJ_FLESH 6

#define SFX_DEATH 2
#define SFX_DEATH_FREQ 20000

typedef struct {
	int num_frames;
	int restart_frame;
	struct {
		int image;
		int ticks;
	} frame[4];
} player_anim_t;

typedef struct {
	int action_left, action_up, action_right;
	int enabled, dead_flag;
	int bumps;
	int bumped[JNB_MAX_PLAYERS];
	int x, y;
	int x_add, y_add;
	int direction, jump_ready, jump_abort, in_water;
	int anim, frame, frame_tick, image;
} player_t;

typedef struct {
	int used, type;
	int x, y;
	int x_add, y_add;
	int x_acc, y_acc;
	int anim;
	int frame, ticks;
	int image;
} object_t;

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
struct main_info_t {
	int no_gore;
};
extern struct main_info_t main_info;

typedef struct {
	unsigned long cmd;
	long arg, arg2, arg3, arg4;
/* Field types copied from main.c's NetPacket; the real struct
	 * carries no trailing field processKillPacket reads. The
	 * harness's kill_dispatch wrapper builds one byte-for-byte. */
} NetPacket;

void processKillPacket(NetPacket *pkt)
{
	int c1 = pkt->arg;
	int c2 = pkt->arg2;
	int x = pkt->arg3;
	int y = pkt->arg4;
	int c4 = 0;
	int s1 = 0;

	player[c1].y_add = -player[c1].y_add;
	if (player[c1].y_add > -262144L)
		player[c1].y_add = -262144L;
	player[c1].jump_abort = 1;
	player[c2].dead_flag = 1;
	if (player[c2].anim != 6) {
		player[c2].anim = 6;
		player[c2].frame = 0;
		player[c2].frame_tick = 0;
		player[c2].image = player_anims[player[c2].anim].frame[player[c2].frame].image + player[c2].direction * 9;
		if (main_info.no_gore == 0) {
			for (c4 = 0; c4 < 6; c4++)
				add_object(OBJ_FUR, (x >> 16) + 6 + rnd(5), (y >> 16) + 6 + rnd(5), (rnd(65535) - 32768) * 3, (rnd(65535) - 32768) * 3, 0, 44 + c2 * 8);
			for (c4 = 0; c4 < 6; c4++)
				add_object(OBJ_FLESH, (x >> 16) + 6 + rnd(5), (y >> 16) + 6 + rnd(5), (rnd(65535) - 32768) * 3, (rnd(65535) - 32768) * 3, 0, 76);
			for (c4 = 0; c4 < 6; c4++)
				add_object(OBJ_FLESH, (x >> 16) + 6 + rnd(5), (y >> 16) + 6 + rnd(5), (rnd(65535) - 32768) * 3, (rnd(65535) - 32768) * 3, 0, 77);
			for (c4 = 0; c4 < 8; c4++)
				add_object(OBJ_FLESH, (x >> 16) + 6 + rnd(5), (y >> 16) + 6 + rnd(5), (rnd(65535) - 32768) * 3, (rnd(65535) - 32768) * 3, 0, 78);
			for (c4 = 0; c4 < 10; c4++)
				add_object(OBJ_FLESH, (x >> 16) + 6 + rnd(5), (y >> 16) + 6 + rnd(5), (rnd(65535) - 32768) * 3, (rnd(65535) - 32768) * 3, 0, 79);
		}
		dj_play_sfx(SFX_DEATH, (unsigned short)(SFX_DEATH_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
		player[c1].bumps++;
		player[c1].bumped[c2]++;
		s1 = player[c1].bumps % 100;
		add_leftovers(0, 360, 34 + c1 * 64, s1 / 10, &number_gobs);
		add_leftovers(1, 360, 34 + c1 * 64, s1 / 10, &number_gobs);
		add_leftovers(0, 376, 34 + c1 * 64, s1 - (s1 / 10) * 10, &number_gobs);
		add_leftovers(1, 376, 34 + c1 * 64, s1 - (s1 / 10) * 10, &number_gobs);
	}
}

static void player_kill(int c1, int c2)
{
	if (player[c1].y_add >= 0) {
		if (is_server)
			serverSendKillPacket(c1, c2);
	} else {
		if (player[c2].y_add < 0)
			player[c2].y_add = 0;
	}
}

static void collision_check(void)
{
	int c1 = 0, c2 = 0, c3 = 0;
	int l1;

	/* collision check */
	for (c3 = 0; c3 < 6; c3++) {
		if (c3 == 0) {
			c1 = 0;
			c2 = 1;
		} else if (c3 == 1) {
			c1 = 0;
			c2 = 2;
		} else if (c3 == 2) {
			c1 = 0;
			c2 = 3;
		} else if (c3 == 3) {
			c1 = 1;
			c2 = 2;
		} else if (c3 == 4) {
			c1 = 1;
			c2 = 3;
		} else if (c3 == 5) {
			c1 = 2;
			c2 = 3;
		}
		if (player[c1].enabled == 1 && player[c2].enabled == 1) {
			if (labs(player[c1].x - player[c2].x) < (12L << 16) && labs(player[c1].y - player[c2].y) < (12L << 16)) {
				if ((labs(player[c1].y - player[c2].y) >> 16) > 5) {
					if (player[c1].y < player[c2].y) {
						player_kill(c1,c2);
					} else {
						player_kill(c2,c1);
					}
				} else {
					if (player[c1].x < player[c2].x) {
						if (player[c1].x_add > 0)
							player[c1].x = player[c2].x - (12L << 16);
						else if (player[c2].x_add < 0)
							player[c2].x = player[c1].x + (12L << 16);
						else {
							player[c1].x -= player[c1].x_add;
							player[c2].x -= player[c2].x_add;
						}
						l1 = player[c2].x_add;
						player[c2].x_add = player[c1].x_add;
						player[c1].x_add = l1;
						if (player[c1].x_add > 0)
							player[c1].x_add = -player[c1].x_add;
						if (player[c2].x_add < 0)
							player[c2].x_add = -player[c2].x_add;
					} else {
						if (player[c1].x_add > 0)
							player[c2].x = player[c1].x - (12L << 16);
						else if (player[c2].x_add < 0)
							player[c1].x = player[c2].x + (12L << 16);
						else {
							player[c1].x -= player[c1].x_add;
							player[c2].x -= player[c2].x_add;
						}
						l1 = player[c2].x_add;
						player[c2].x_add = player[c1].x_add;
						player[c1].x_add = l1;
						if (player[c1].x_add < 0)
							player[c1].x_add = -player[c1].x_add;
						if (player[c2].x_add > 0)
							player[c2].x_add = -player[c2].x_add;
					}
				}
			}
		}
	}
}

/* FNV-1a 32-bit, folding in `value` as 4 little-endian bytes regardless of
 * host endianness. See docs/checksum-format.md for the full byte layout. */

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
