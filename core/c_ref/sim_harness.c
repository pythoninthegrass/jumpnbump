/*
 * Shared world storage for the TASK-011.* differentials.
 *
 * player_raw[]/objects_raw[]/ban_map_raw[] are main.c's player[]/
 * objects[]/ban_map[] (globals.pre:207/237, main.c:74), aliased to distinct
 * link names because compileRenamedCRef renames every token in the C
 * references' translation units (the extern declarations included):
 * `#define player player_raw` and friends there restore the names the
 * extracted text uses, while the Zig modules (core/steer.zig,
 * core/collision.zig, core/cpu_move.zig) reach this same memory through
 * their own extern mirrors. One definition, one world, both sides.
 *
 * player_anims[]/object_anims[] keep their original names: the rename
 * leaves references to symbols defined in other translation units alone,
 * so the C references' externs bind directly to core/steer.zig's exports.
 * keyb[] is sdl/interrpt.c's array (char keyb[256], sdl/interrpt.c:42),
 * mirrored by core/cpu_move.zig's extern.
 */

#define JNB_MAX_PLAYERS 4
#define NUM_OBJECTS 200

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
	int used, type;
	int x, y;
	int x_add, y_add;
	int x_acc, y_acc;
	int anim;
	int frame, ticks;
	int image;
} object_t;

player_t player_raw[JNB_MAX_PLAYERS];
object_t objects_raw[NUM_OBJECTS];
unsigned int ban_map_raw[17][22];
char keyb[256];
