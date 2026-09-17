/*
 * Shared simulation state for the TASK-011.06 flies differential
 * (core/flies_difftest.zig): player_raw[]/ban_map_raw[] are the arrays
 * core/flies.zig declares extern (owned by whichever module ports
 * steer_players/the level loader), defined here once so the Zig module
 * under test and core/c_ref/flies.c read/write the very same memory.
 * flies[] and lord_of_the_flies are core/flies.zig's own exports, not
 * defined here.
 */

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

player_t player_raw[JNB_MAX_PLAYERS];
unsigned int ban_map_raw[17][22];
