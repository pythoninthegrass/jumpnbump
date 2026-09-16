/*
 * Declarations for the TASK-011.05 cpu_move differential harness
 * (core/c_ref/cpu_move_harness.c), included by core/c_ref/cpu_move.c and
 * importable from Zig via @cImport.
 */

#ifndef JNB_CPU_MOVE_HARNESS_H
#define JNB_CPU_MOVE_HARNESS_H

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

extern player_t player[JNB_MAX_PLAYERS];
extern unsigned int ban_map[17][22];
extern int ai[JNB_MAX_PLAYERS];
extern char keyb[256];

int addkey(unsigned int key);
int key_pressed(int key);

void cpu_move_set_player_xy(int n, int x, int y);
void cpu_move_set_player_enabled(int n, int enabled);
int cpu_move_get_player_x(int n);
int cpu_move_get_player_y(int n);
void cpu_move_set_ban(int row, int col, unsigned int v);
void cpu_move_set_ai(int n, int v);
int cpu_move_get_keyb(int idx);
void cpu_move_clear_keyb(void);

#endif /* JNB_CPU_MOVE_HARNESS_H */
