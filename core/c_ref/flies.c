/*
 * TASK-011.06 differential-test reference.
 *
 * main.c's get_closest_player_to_point() (main.c:1007), update_flies()
 * (main.c:1025) and the flies_enabled spawn block from main_loop
 * (main.c:1581-1595, extracted as spawn_flies_ref) — extracted verbatim.
 * player_raw[]/ban_map_raw[] are core/c_ref/flies_harness.c's shared
 * storage; flies[]/lord_of_the_flies are core/flies.zig's own exports;
 * rnd() is rnd.zig's real, unrenamed export, so both sides of the
 * differential draw from the exact same PRNG stream when the test
 * reseeds identically before each side's run.
 *
 * get_closest_player_to_point/update_flies/spawn_flies are renamed to
 * c_* by compileRenamedCRef so they don't collide with core/flies.zig's
 * exports of the same names.
 */

#include <math.h>

#define JNB_MAX_PLAYERS 4
#define NUM_FLIES 20
#define BAN_VOID 0

typedef struct
{
	int action_left;
	int action_up;
	int action_right;
	int enabled;
	int dead_flag;
	int bumps;
	int bumped[JNB_MAX_PLAYERS];
	int x;
	int y;
	int x_add;
	int y_add;
	int direction;
	int jump_ready;
	int jump_abort;
	int in_water;
	int anim;
	int frame;
	int frame_tick;
	int image;
} player_t;

typedef struct
{
	int x;
	int y;
	int old_x;
	int old_y;
	int old_draw_x;
	int old_draw_y;
} fly_t;

extern player_t player_raw[JNB_MAX_PLAYERS];
extern unsigned int ban_map_raw[17][22];
extern fly_t flies[NUM_FLIES];
extern int lord_of_the_flies;
extern unsigned short rnd(unsigned short max);

#define GET_BAN_MAP_XY(x,y) ban_map_raw[(y) >> 4][(x) >> 4]

void get_closest_player_to_point(int x, int y, int *dist, int *closest_player)
{
	int c1;
	int cur_dist = 0;

	*dist = 0x7fff;
	for (c1 = 0; c1 < JNB_MAX_PLAYERS; c1++) {
		if (player_raw[c1].enabled == 1) {
			cur_dist = (int)sqrt((x - ((player_raw[c1].x >> 16) + 8)) * (x - ((player_raw[c1].x >> 16) + 8)) + (y - ((player_raw[c1].y >> 16) + 8)) * (y - ((player_raw[c1].y >> 16) + 8)));
			if (cur_dist < *dist) {
				*closest_player = c1;
				*dist = cur_dist;
			}
		}
	}
}

void update_flies(int update_count)
{
	int c1;
	int closest_player = 0, dist;
	int s1, s2, s3, s4;

	/* get center of fly swarm */
	s1 = s2 = 0;
	for (c1 = 0; c1 < NUM_FLIES; c1++) {
		s1 += flies[c1].x;
		s2 += flies[c1].y;
	}
	s1 /= NUM_FLIES;
	s2 /= NUM_FLIES;

	if (update_count == 1) {
		/* get closest player to fly swarm */
		get_closest_player_to_point(s1, s2, &dist, &closest_player);
		/* update fly swarm sound -- dj_set_sfx_channel_volume is audio, out of
		 * scope for this differential (core purity: no audio in the sim). */
		s3 = 32 - dist / 3;
		if (s3 < 0)
			s3 = 0;
	}

	for (c1 = 0; c1 < NUM_FLIES; c1++) {
		/* get closest player to fly */
		get_closest_player_to_point(flies[c1].x, flies[c1].y, &dist, &closest_player);
		flies[c1].old_x = flies[c1].x;
		flies[c1].old_y = flies[c1].y;
		s3 = 0;
		if ((s1 - flies[c1].x) > 30)
			s3 += 1;
		else if ((s1 - flies[c1].x) < -30)
			s3 -= 1;
		if (dist < 30) {
			if (((player_raw[closest_player].x >> 16) + 8) > flies[c1].x) {
				if (lord_of_the_flies == 0)
					s3 -= 1;
				else
					s3 += 1;
			} else {
				if (lord_of_the_flies == 0)
					s3 += 1;
				else
					s3 -= 1;
			}
		}
		s4 = rnd(3) - 1 + s3;
		if ((flies[c1].x + s4) < 16)
			s4 = 0;
		if ((flies[c1].x + s4) > 351)
			s4 = 0;
		if (GET_BAN_MAP_XY(flies[c1].x + s4, flies[c1].y) != BAN_VOID)
			s4 = 0;
		flies[c1].x += s4;
		s3 = 0;
		if ((s2 - flies[c1].y) > 30)
			s3 += 1;
		else if ((s2 - flies[c1].y) < -30)
			s3 -= 1;
		if (dist < 30) {
			if (((player_raw[closest_player].y >> 16) + 8) > flies[c1].y) {
				if (lord_of_the_flies == 0)
					s3 -= 1;
				else
					s3 += 1;
			} else {
				if (lord_of_the_flies == 0)
					s3 += 1;
				else
					s3 -= 1;
			}
		}
		s4 = rnd(3) - 1 + s3;
		if ((flies[c1].y + s4) < 0)
			s4 = 0;
		if ((flies[c1].y + s4) > 239)
			s4 = 0;
		if (GET_BAN_MAP_XY(flies[c1].x, flies[c1].y + s4) != BAN_VOID)
			s4 = 0;
		flies[c1].y += s4;
	}
}

void spawn_flies(void)
{
	int c1;
	int s1 = rnd(250) + 50;
	int s2 = rnd(150) + 50;

	for (c1 = 0; c1 < NUM_FLIES; c1++) {
		while (1) {
			flies[c1].x = s1 + rnd(101) - 50;
			flies[c1].y = s2 + rnd(101) - 50;
			if (GET_BAN_MAP_XY(flies[c1].x, flies[c1].y) == BAN_VOID)
				break;
		}
	}
}
