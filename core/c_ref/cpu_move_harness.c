/*
 * Shared simulation state for the TASK-011.05 cpu_move differential
 * (core/cpu_move_difftest.zig).
 *
 * The arrays main.c owns (player[], ban_map) and sdl/interrpt.c owns
 * (keyb) live here, once, for both sides of the differential: the Zig
 * module under test reads them through `extern var` declarations, and the
 * renamed-C reference (core/c_ref/cpu_move.c) reads the very same symbols.
 * Accessors let each side set up and compare the other's view without
 * aliasing layout assumptions.
 *
 * addkey()/key_pressed() are sdl/interrpt.c's non-kaillera implementations
 * verbatim (the last_keys[] ring addkey maintains feeds only the cheat
 * recognizer and is dropped), so the keyboard protocol is shared ground
 * truth rather than something re-implemented per side. Keep in sync with
 * sdl/interrpt.c by hand.
 */

#include <stddef.h>

#define JNB_MAX_PLAYERS 4

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

player_t player[JNB_MAX_PLAYERS];
unsigned int ban_map[17][22];
/* ai[] is core/cpu_move.zig's `pub export var ai` -- that's the one
 * definition; this side only references it. */
extern int ai[JNB_MAX_PLAYERS];
char keyb[256];

int addkey(unsigned int key)
{
	if (!(key & 0x8000)) {
		keyb[key & 0x7fff] = 1;
	} else
		keyb[key & 0x7fff] = 0;
	return 0;
}

int key_pressed(int key)
{
	return keyb[(unsigned char) key];
}

/* --- accessors for the difftest harness ------------------------------ */

void cpu_move_set_player_xy(int n, int x, int y)
{
	player[n].x = x;
	player[n].y = y;
}

void cpu_move_set_player_enabled(int n, int enabled)
{
	player[n].enabled = enabled;
}

int cpu_move_get_player_x(int n)
{
	return player[n].x;
}

int cpu_move_get_player_y(int n)
{
	return player[n].y;
}

void cpu_move_set_ban(int row, int col, unsigned int v)
{
	ban_map[row][col] = v;
}

void cpu_move_set_ai(int n, int v)
{
	ai[n] = v;
}

int cpu_move_get_keyb(int idx)
{
	return keyb[(unsigned char) idx];
}

void cpu_move_clear_keyb(void)
{
	int c1;
	for (c1 = 0; c1 < 256; c1++)
		keyb[c1] = 0;
}
