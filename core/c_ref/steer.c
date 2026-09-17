/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/steer.zig (TASK-011.02): main.c lines
 * 2069-2407, extracted verbatim by core/c_ref/extract_steered.py.
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

#define BAN_VOID	0
#define BAN_SOLID	1
#define BAN_WATER	2
#define BAN_ICE	3
#define BAN_SPRING	4

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
typedef struct {
	int num_frames;
	int restart_frame;
	struct {
		int image;
		int ticks;
	} frame[10];
} object_anim_t;
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

#define GET_BAN_MAP_IN_WATER(s1, s2) (GET_BAN_MAP_XY((s1), ((s2) + 7)) == BAN_VOID || GET_BAN_MAP_XY(((s1) + 15), ((s2) + 7)) == BAN_VOID) && (GET_BAN_MAP_XY((s1), ((s2) + 8)) == BAN_WATER || GET_BAN_MAP_XY(((s1) + 15), ((s2) + 8)) == BAN_WATER)

static void player_action_left(int c1)
{
	int s1 = 0, s2 = 0;
	int below_left, below, below_right;

    s1 = (player[c1].x >> 16);
    s2 = (player[c1].y >> 16);
	below_left = GET_BAN_MAP_XY(s1, s2 + 16);
	below = GET_BAN_MAP_XY(s1 + 8, s2 + 16);
	below_right = GET_BAN_MAP_XY(s1 + 15, s2 + 16);

    if (below == BAN_ICE) {
        if (player[c1].x_add > 0)
            player[c1].x_add -= 1024;
        else
            player[c1].x_add -= 768;
    } else if ((below_left != BAN_SOLID && below_right == BAN_ICE) || (below_left == BAN_ICE && below_right != BAN_SOLID)) {
        if (player[c1].x_add > 0)
            player[c1].x_add -= 1024;
        else
            player[c1].x_add -= 768;
    } else {
        if (player[c1].x_add > 0) {
            player[c1].x_add -= 16384;
            if (player[c1].x_add > -98304L && player[c1].in_water == 0 && below == BAN_SOLID)
{ int gore_ya = -16384 - rnd(8192); int gore_y = (player[c1].y >> 16) + 13 + rnd(5); int gore_x = (player[c1].x >> 16) + 2 + rnd(9); add_object(OBJ_SMOKE, gore_x, gore_y, 0, gore_ya, OBJ_ANIM_SMOKE, 0); }
        } else
            player[c1].x_add -= 12288;
    }
    if (player[c1].x_add < -98304L)
        player[c1].x_add = -98304L;
    player[c1].direction = 1;
    if (player[c1].anim == 0) {
        player[c1].anim = 1;
        player[c1].frame = 0;
        player[c1].frame_tick = 0;
        player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
    }
}


static void player_action_right(int c1)
{
	int s1 = 0, s2 = 0;
	int below_left, below, below_right;

    s1 = (player[c1].x >> 16);
    s2 = (player[c1].y >> 16);
	below_left = GET_BAN_MAP_XY(s1, s2 + 16);
	below = GET_BAN_MAP_XY(s1 + 8, s2 + 16);
	below_right = GET_BAN_MAP_XY(s1 + 15, s2 + 16);

    if (below == BAN_ICE) {
        if (player[c1].x_add < 0)
            player[c1].x_add += 1024;
        else
            player[c1].x_add += 768;
    } else if ((below_left != BAN_SOLID && below_right == BAN_ICE) || (below_left == BAN_ICE && below_right != BAN_SOLID)) {
        if (player[c1].x_add > 0)
            player[c1].x_add += 1024;
        else
            player[c1].x_add += 768;
    } else {
        if (player[c1].x_add < 0) {
            player[c1].x_add += 16384;
            if (player[c1].x_add < 98304L && player[c1].in_water == 0 && below == BAN_SOLID)
{ int gore_ya = -16384 - rnd(8192); int gore_y = (player[c1].y >> 16) + 13 + rnd(5); int gore_x = (player[c1].x >> 16) + 2 + rnd(9); add_object(OBJ_SMOKE, gore_x, gore_y, 0, gore_ya, OBJ_ANIM_SMOKE, 0); }
        } else
            player[c1].x_add += 12288;
    }
    if (player[c1].x_add > 98304L)
        player[c1].x_add = 98304L;
    player[c1].direction = 0;
    if (player[c1].anim == 0) {
        player[c1].anim = 1;
        player[c1].frame = 0;
        player[c1].frame_tick = 0;
        player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
    }
}

void steer_players(void)
{
	int c1, c2;
	int s1 = 0, s2 = 0;

	cpu_move();
	update_player_actions();

	for (c1 = 0; c1 < JNB_MAX_PLAYERS; c1++) {

		if (player[c1].enabled == 1) {

			if (player[c1].dead_flag == 0) {

				if (player[c1].action_left && player[c1].action_right) {
					if (player[c1].direction == 0) {
						if (player[c1].action_right) {
							player_action_right(c1);
						}
					} else {
						if (player[c1].action_left) {
							player_action_left(c1);
						}
					}
				} else if (player[c1].action_left) {
					player_action_left(c1);
				} else if (player[c1].action_right) {
					player_action_right(c1);
				} else if ((!player[c1].action_left) && (!player[c1].action_right)) {
					int below_left, below, below_right;

					s1 = (player[c1].x >> 16);
					s2 = (player[c1].y >> 16);
					below_left = GET_BAN_MAP_XY(s1, s2 + 16);
					below = GET_BAN_MAP_XY(s1 + 8, s2 + 16);
					below_right = GET_BAN_MAP_XY(s1 + 15, s2 + 16);
					if (below == BAN_SOLID || below == BAN_SPRING || (((below_left == BAN_SOLID || below_left == BAN_SPRING) && below_right != BAN_ICE) || (below_left != BAN_ICE && (below_right == BAN_SOLID || below_right == BAN_SPRING)))) {
						if (player[c1].x_add < 0) {
							player[c1].x_add += 16384;
							if (player[c1].x_add > 0)
								player[c1].x_add = 0;
						} else {
							player[c1].x_add -= 16384;
							if (player[c1].x_add < 0)
								player[c1].x_add = 0;
						}
						if (player[c1].x_add != 0 && GET_BAN_MAP_XY((s1 + 8), (s2 + 16)) == BAN_SOLID)
							{ int gore_ya = -16384 - rnd(8192); int gore_y = (player[c1].y >> 16) + 13 + rnd(5); int gore_x = (player[c1].x >> 16) + 2 + rnd(9); add_object(OBJ_SMOKE, gore_x, gore_y, 0, gore_ya, OBJ_ANIM_SMOKE, 0); }
					}
					if (player[c1].anim == 1) {
						player[c1].anim = 0;
						player[c1].frame = 0;
						player[c1].frame_tick = 0;
						player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
					}
				}
				if (jetpack == 0) {
					/* no jetpack */
					if (pogostick == 1 || (player[c1].jump_ready == 1 && player[c1].action_up)) {
						s1 = (player[c1].x >> 16);
						s2 = (player[c1].y >> 16);
						if (s2 < -16)
							s2 = -16;
						/* jump */
						if (GET_BAN_MAP_XY(s1, (s2 + 16)) == BAN_SOLID || GET_BAN_MAP_XY(s1, (s2 + 16)) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), (s2 + 16)) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), (s2 + 16)) == BAN_ICE) {
							player[c1].y_add = -280000L;
							player[c1].anim = 2;
							player[c1].frame = 0;
							player[c1].frame_tick = 0;
							player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
							player[c1].jump_ready = 0;
							player[c1].jump_abort = 1;
							if (pogostick == 0)
								dj_play_sfx(SFX_JUMP, (unsigned short)(SFX_JUMP_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
							else
								dj_play_sfx(SFX_SPRING, (unsigned short)(SFX_SPRING_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
						}
						/* jump out of water */
						if (GET_BAN_MAP_IN_WATER(s1, s2)) {
							player[c1].y_add = -196608L;
							player[c1].in_water = 0;
							player[c1].anim = 2;
							player[c1].frame = 0;
							player[c1].frame_tick = 0;
							player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
							player[c1].jump_ready = 0;
							player[c1].jump_abort = 1;
							if (pogostick == 0)
								dj_play_sfx(SFX_JUMP, (unsigned short)(SFX_JUMP_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
							else
								dj_play_sfx(SFX_SPRING, (unsigned short)(SFX_SPRING_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
						}
					}
					/* fall down by gravity */
					if (pogostick == 0 && (!player[c1].action_up)) {
						player[c1].jump_ready = 1;
						if (player[c1].in_water == 0 && player[c1].y_add < 0 && player[c1].jump_abort == 1) {
							if (bunnies_in_space == 0)
								/* normal gravity */
								player[c1].y_add += 32768;
							else
								/* light gravity */
								player[c1].y_add += 16384;
							if (player[c1].y_add > 0)
								player[c1].y_add = 0;
						}
					}
				} else {
					/* with jetpack */
					if (player[c1].action_up) {
						player[c1].y_add -= 16384;
						if (player[c1].y_add < -400000L)
							player[c1].y_add = -400000L;
						if (GET_BAN_MAP_IN_WATER(s1, s2))
							player[c1].in_water = 0;
						if (rnd(100) < 50)
							{ int gore_ya = 16384 + rnd(8192); int gore_y = (player[c1].y >> 16) + 10 + rnd(5); int gore_x = (player[c1].x >> 16) + 6 + rnd(5); add_object(OBJ_SMOKE, gore_x, gore_y, 0, gore_ya, OBJ_ANIM_SMOKE, 0); }
					}
				}

				player[c1].x += player[c1].x_add;
				if ((player[c1].x >> 16) < 0) {
					player[c1].x = 0;
					player[c1].x_add = 0;
				}
				if ((player[c1].x >> 16) + 15 > 351) {
					player[c1].x = 336L << 16;
					player[c1].x_add = 0;
				}
				{
					if (player[c1].y > 0) {
						s2 = (player[c1].y >> 16);
					} else {
						/* check top line only */
						s2 = 0;
					}

					s1 = (player[c1].x >> 16);
					if (GET_BAN_MAP_XY(s1, s2) == BAN_SOLID || GET_BAN_MAP_XY(s1, s2) == BAN_ICE || GET_BAN_MAP_XY(s1, s2) == BAN_SPRING || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_ICE || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SPRING) {
						player[c1].x = (((s1 + 16) & 0xfff0)) << 16;
						player[c1].x_add = 0;
					}

					s1 = (player[c1].x >> 16);
					if (GET_BAN_MAP_XY((s1 + 15), s2) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), s2) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), s2) == BAN_SPRING || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SPRING) {
						player[c1].x = (((s1 + 16) & 0xfff0) - 16) << 16;
						player[c1].x_add = 0;
					}
				}

				player[c1].y += player[c1].y_add;

				s1 = (player[c1].x >> 16);
				s2 = (player[c1].y >> 16);
				if (GET_BAN_MAP_XY((s1 + 8), (s2 + 15)) == BAN_SPRING || ((GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SPRING && GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) != BAN_SOLID) || (GET_BAN_MAP_XY(s1, (s2 + 15)) != BAN_SOLID && GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SPRING))) {
					player[c1].y = ((player[c1].y >> 16) & 0xfff0) << 16;
					player[c1].y_add = -400000L;
					player[c1].anim = 2;
					player[c1].frame = 0;
					player[c1].frame_tick = 0;
					player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
					player[c1].jump_ready = 0;
					player[c1].jump_abort = 0;
					for (c2 = 0; c2 < NUM_OBJECTS; c2++) {
						if (objects[c2].used == 1 && objects[c2].type == OBJ_SPRING) {
							if (GET_BAN_MAP_XY((s1 + 8), (s2 + 15)) == BAN_SPRING) {
								if ((objects[c2].x >> 20) == ((s1 + 8) >> 4) && (objects[c2].y >> 20) == ((s2 + 15) >> 4)) {
									objects[c2].frame = 0;
									objects[c2].ticks = object_anims[objects[c2].anim].frame[objects[c2].frame].ticks;
									objects[c2].image = object_anims[objects[c2].anim].frame[objects[c2].frame].image;
									break;
								}
							} else {
								if (GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SPRING) {
									if ((objects[c2].x >> 20) == (s1 >> 4) && (objects[c2].y >> 20) == ((s2 + 15) >> 4)) {
										objects[c2].frame = 0;
										objects[c2].ticks = object_anims[objects[c2].anim].frame[objects[c2].frame].ticks;
										objects[c2].image = object_anims[objects[c2].anim].frame[objects[c2].frame].image;
										break;
									}
								} else if (GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SPRING) {
									if ((objects[c2].x >> 20) == ((s1 + 15) >> 4) && (objects[c2].y >> 20) == ((s2 + 15) >> 4)) {
										objects[c2].frame = 0;
										objects[c2].ticks = object_anims[objects[c2].anim].frame[objects[c2].frame].ticks;
										objects[c2].image = object_anims[objects[c2].anim].frame[objects[c2].frame].image;
										break;
									}
								}
							}
						}
					}
					dj_play_sfx(SFX_SPRING, (unsigned short)(SFX_SPRING_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
				}
				s1 = (player[c1].x >> 16);
				s2 = (player[c1].y >> 16);
				if (s2 < 0)
					s2 = 0;
				if (GET_BAN_MAP_XY(s1, s2) == BAN_SOLID || GET_BAN_MAP_XY(s1, s2) == BAN_ICE || GET_BAN_MAP_XY(s1, s2) == BAN_SPRING || GET_BAN_MAP_XY((s1 + 15), s2) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), s2) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), s2) == BAN_SPRING) {
					player[c1].y = (((s2 + 16) & 0xfff0)) << 16;
					player[c1].y_add = 0;
					player[c1].anim = 0;
					player[c1].frame = 0;
					player[c1].frame_tick = 0;
					player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
				}
				s1 = (player[c1].x >> 16);
				s2 = (player[c1].y >> 16);
				if (s2 < 0)
					s2 = 0;
				if (GET_BAN_MAP_XY((s1 + 8), (s2 + 8)) == BAN_WATER) {
					if (player[c1].in_water == 0) {
						/* falling into water */
						player[c1].in_water = 1;
						player[c1].anim = 4;
						player[c1].frame = 0;
						player[c1].frame_tick = 0;
						player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
						if (player[c1].y_add >= 32768) {
							add_object(OBJ_SPLASH, (player[c1].x >> 16) + 8, ((player[c1].y >> 16) & 0xfff0) + 15, 0, 0, OBJ_ANIM_SPLASH, 0);
							if (blood_is_thicker_than_water == 0)
								dj_play_sfx(SFX_SPLASH, (unsigned short)(SFX_SPLASH_FREQ + rnd(2000) - 1000), 64, 0, 0, -1);
							else
								dj_play_sfx(SFX_SPLASH, (unsigned short)(SFX_SPLASH_FREQ + rnd(2000) - 5000), 64, 0, 0, -1);
						}
					}
					/* slowly move up to water surface */
					player[c1].y_add -= 1536;
					if (player[c1].y_add < 0 && player[c1].anim != 5) {
						player[c1].anim = 5;
						player[c1].frame = 0;
						player[c1].frame_tick = 0;
						player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
					}
					if (player[c1].y_add < -65536L)
						player[c1].y_add = -65536L;
					if (player[c1].y_add > 65535L)
						player[c1].y_add = 65535L;
					if (GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_ICE) {
						player[c1].y = (((s2 + 16) & 0xfff0) - 16) << 16;
						player[c1].y_add = 0;
					}
				} else if (GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_ICE || GET_BAN_MAP_XY(s1, (s2 + 15)) == BAN_SPRING || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SOLID || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_ICE || GET_BAN_MAP_XY((s1 + 15), (s2 + 15)) == BAN_SPRING) {
					player[c1].in_water = 0;
					player[c1].y = (((s2 + 16) & 0xfff0) - 16) << 16;
					player[c1].y_add = 0;
					if (player[c1].anim != 0 && player[c1].anim != 1) {
						player[c1].anim = 0;
						player[c1].frame = 0;
						player[c1].frame_tick = 0;
						player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
					}
				} else {
					if (player[c1].in_water == 0) {
						if (bunnies_in_space == 0)
							player[c1].y_add += 12288;
						else
							player[c1].y_add += 6144;
						if (player[c1].y_add > 327680L)
							player[c1].y_add = 327680L;
					} else {
						player[c1].y = (player[c1].y & 0xffff0000) + 0x10000;
						player[c1].y_add = 0;
					}
					player[c1].in_water = 0;
				}
				if (player[c1].y_add > 36864 && player[c1].anim != 3 && player[c1].in_water == 0) {
					player[c1].anim = 3;
					player[c1].frame = 0;
					player[c1].frame_tick = 0;
					player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;
				}

			}

			player[c1].frame_tick++;
			if (player[c1].frame_tick >= player_anims[player[c1].anim].frame[player[c1].frame].ticks) {
				player[c1].frame++;
				if (player[c1].frame >= player_anims[player[c1].anim].num_frames) {
					if (player[c1].anim != 6)
						player[c1].frame = player_anims[player[c1].anim].restart_frame;
					else
						position_player(c1);
				}
				player[c1].frame_tick = 0;
			}
			player[c1].image = player_anims[player[c1].anim].frame[player[c1].frame].image + player[c1].direction * 9;

		}

	}

}


void position_player(int player_num)
{
	int c1;
	int s1, s2;

	while (1) {
		while (1) {
			s1 = rnd(22);
			s2 = rnd(16);
			if (ban_map[s2][s1] == BAN_VOID && (ban_map[s2 + 1][s1] == BAN_SOLID || ban_map[s2 + 1][s1] == BAN_ICE))
				break;
		}
		for (c1 = 0; c1 < JNB_MAX_PLAYERS; c1++) {
			if (c1 != player_num && player[c1].enabled == 1) {
				if (abs((s1 << 4) - (player[c1].x >> 16)) < 32 && abs((s2 << 4) - (player[c1].y >> 16)) < 32)
					break;
			}
		}
		if (c1 == JNB_MAX_PLAYERS) {
			player[player_num].x = (long) s1 << 20;
			player[player_num].y = (long) s2 << 20;
			player[player_num].x_add = player[player_num].y_add = 0;
			player[player_num].direction = 0;
			player[player_num].jump_ready = 1;
			player[player_num].in_water = 0;
			player[player_num].anim = 0;
			player[player_num].frame = 0;
			player[player_num].frame_tick = 0;
			player[player_num].image = player_anims[player[player_num].anim].frame[player[player_num].frame].image;

			if (is_server) {
#ifdef USE_NET
				if (is_net)
					serverSendAlive(player_num);
#endif
				player[player_num].dead_flag = 0;
			}

			break;
		}
	}

}
