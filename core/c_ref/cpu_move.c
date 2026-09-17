/*
 * TASK-011.05 differential-test reference.
 *
 * main.c's map_tile() (main.c:1852) and cpu_move() (main.c:1866) — the
 * bunny AI — extracted verbatim, with the three state arrays moved from
 * extern globals into static storage inside this TU. The renamed-C side of
 * the pair is a closed system: cpu_move_ref() reads only these arrays and
 * writes only keyb_ref[], so the difftest harness (core/build.zig's
 * compileRenamedCRef renames these to c_*) can drive both the compiled
 * oracle expressions and core/cpu_move.zig from identical state without
 * the two sides aliasing each other's globals.
 *
 * Two deliberate, verified-equivalent condensions of the original text:
 *
 * - The key macros are the USE_SDL values from globals.pre:102 expanded
 *   to their SDLK_* enum numbers (SDL_keysym.h) so this TU needs no SDL
 *   headers, and the apply-movements block's three four-way key if/else
 *   chains are written as the lookup table they compute. `cc -E` diff of
 *   the table form against macro-expanded chains over every index in [0,4)
 *   shows the same expansion; the `key &= 0x7f` and `| 0x8000` release-bit
 *   protocol itself is kept exactly.
 * - cpu_move_ref()'s jump-key test calls key_pressed_ref() directly
 *   instead of the C's four-arm `(i == N && key_pressed(KEY_PLn_JUMP))`
 *   chain (identical truth values per index, same macro expansion).
 *
 * Keep in sync with main.c by hand.
 */

#include <stddef.h> /* NULL */

#define JNB_MAX_PLAYERS 4

#define BAN_VOID    0
#define BAN_SOLID   1
#define BAN_WATER   2
#define BAN_ICE     3
#define BAN_SPRING  4

#define KEY_PL1_LEFT  276 /* SDLK_LEFT */
#define KEY_PL1_RIGHT 275 /* SDLK_RIGHT */
#define KEY_PL1_JUMP  273 /* SDLK_UP */
#define KEY_PL2_LEFT  97  /* SDLK_a */
#define KEY_PL2_RIGHT 100 /* SDLK_d */
#define KEY_PL2_JUMP  119 /* SDLK_w */
#define KEY_PL3_LEFT  106 /* SDLK_j */
#define KEY_PL3_RIGHT 108 /* SDLK_l */
#define KEY_PL3_JUMP  105 /* SDLK_i */
#define KEY_PL4_LEFT  260 /* SDLK_KP4 */
#define KEY_PL4_RIGHT 262 /* SDLK_KP6 */
#define KEY_PL4_JUMP  264 /* SDLK_KP8 */

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

/* Shared simulation state, defined by core/cpu_move_harness.c (the
 * harness) and read/written through the externs below — the Zig side and
 * the reference side then run over literally the same player[], ban_map
 * and keyb arrays, with the harness accessors as the only API in. */
/* sim_harness.c's shared storage under the *_raw link names the rename
 * leaves intact; the #defines below restore main.c's names for the
 * extracted body. */
extern player_t player_raw[JNB_MAX_PLAYERS];
extern unsigned int ban_map_raw[17][22];
#define player player_raw
#define ban_map ban_map_raw
extern int ai[JNB_MAX_PLAYERS];
extern char keyb[256];
#define keyb_ref keyb

/* The jump key per player, from the same macro table as below. */
const int key_pl_jump[JNB_MAX_PLAYERS] = {
	KEY_PL1_JUMP, KEY_PL2_JUMP, KEY_PL3_JUMP, KEY_PL4_JUMP
};

/* addkey() is core/c_ref/cpu_move_harness.c's — that TU already defines
 * the one true addkey() over the same shared keyb; this side only calls
 * it, it must not define a second, colliding copy. */
extern int addkey(unsigned int key);

int key_pressed_ref(int key)
{
	return keyb_ref[(unsigned char) key];
}

/* cpu_move_ref's jump-key test: the C's four-arm per-player chain
 * collapsed to the direct lookup (see the header comment). */
#define JUMP_KEY_PRESSED(i) key_pressed_ref(key_pl_jump[i])

/* The harness (core/cpu_move_harness.c) defines the shared arrays and
 * exposes setters/getters over them; map_tile below and cpu_move_ref
 * below that both run over this TU's copies. */

int map_tile_ref(int pos_x, int pos_y)
{
	int tile;

	pos_x = pos_x >> 4;
	pos_y = pos_y >> 4;

	if(pos_x < 0 || pos_x >= 17 || pos_y < 0 || pos_y >= 22)
		return BAN_VOID;

	tile = ban_map[pos_y][pos_x];
	return tile;
}

void cpu_move_ref(void)
{
	int lm, rm, jm;
	int i, j;
	int cur_posx, cur_posy, tar_posx, tar_posy;
	int players_distance;
	player_t* target = NULL;
	int nearest_distance = -1;

	for (i = 0; i < JNB_MAX_PLAYERS; i++)
		{
	  nearest_distance = -1;
		if(ai[i] && player[i].enabled)		// this player is a computer
			{		// get nearest target
			for (j = 0; j < JNB_MAX_PLAYERS; j++)
				{
				int deltax, deltay;

				if(i == j || !player[j].enabled)
					continue;

				deltax = player[j].x - player[i].x;
				deltay = player[j].y - player[i].y;
				players_distance = deltax*deltax + deltay*deltay;

				if (players_distance < nearest_distance || nearest_distance == -1)
					{
					target = &player[j];
					nearest_distance = players_distance;
					}
				}

			if(target == NULL)
				continue;

			cur_posx = player[i].x >> 16;
			cur_posy = player[i].y >> 16;
			tar_posx = target->x >> 16;
			tar_posy = target->y >> 16;

			/** nearest player found, get him */
			/* here goes the artificial intelligence code */

			/* X-axis movement */
			if(tar_posx > cur_posx)       // if true target is on the right side
				{    // go after him
				lm=0;
				rm=1;
				}
			else    // target on the left side
				{
				lm=1;
				rm=0;
				}

			if(cur_posy - tar_posy < 32 && cur_posy - tar_posy > 0 &&
              tar_posx - cur_posx < 32+8 && tar_posx - cur_posx > -32)
				{
				lm = !lm;
				rm = !rm;
				}
			else if(tar_posx - cur_posx < 4+8 && tar_posx - cur_posx > -4)
				{      // makes the bunnies less "nervous"
				lm=0;
				lm=0;
				}

			/* Y-axis movement */
			if(map_tile_ref(cur_posx, cur_posy+16) != BAN_VOID &&
				(JUMP_KEY_PRESSED(i)))
					jm=0;   // if we are on ground and jump key is being pressed,
									//first we have to release it or else we won't be able to jump more than once

			else if(map_tile_ref(cur_posx, cur_posy-8) != BAN_VOID &&
				map_tile_ref(cur_posx, cur_posy-8) != BAN_WATER)
					jm=0;   // don't jump if there is something over it

			else if(map_tile_ref(cur_posx-(lm*8)+(rm*16), cur_posy) != BAN_VOID &&
				map_tile_ref(cur_posx-(lm*8)+(rm*16), cur_posy) != BAN_WATER &&
				cur_posx > 16 && cur_posx < 352-16-8)  // obstacle, jump
					jm=1;   // if there is something on the way, jump over it

			else if((JUMP_KEY_PRESSED(i)) &&
							(map_tile_ref(cur_posx-(lm*8)+(rm*16), cur_posy+8) != BAN_VOID &&
							map_tile_ref(cur_posx-(lm*8)+(rm*16), cur_posy+8) != BAN_WATER))
					jm=1;   // this makes it possible to jump over 2 tiles

			else if(cur_posy - tar_posy < 32 && cur_posy - tar_posy > 0 &&
              tar_posx - cur_posx < 32+8 && tar_posx - cur_posx > -32)  // don't jump - running away
				jm=0;

			else if(tar_posy <= cur_posy)   // target on the upper side
				jm=1;
			else   // target below
				jm=0;

			/** Artificial intelligence done, now apply movements */
			/* One loop over the three directions: dir_key[i][d] is what the
			 * C's per-direction if/else chains compute, and flags[d] selects
			 * press vs release, exactly like the three if(lm)/if(rm)/if(jm)
			 * blocks in sequence. */
			{
				static const int dir_key[JNB_MAX_PLAYERS][3] = {
					{ KEY_PL1_LEFT,  KEY_PL1_RIGHT,  KEY_PL1_JUMP  },
					{ KEY_PL2_LEFT,  KEY_PL2_RIGHT,  KEY_PL2_JUMP  },
					{ KEY_PL3_LEFT,  KEY_PL3_RIGHT,  KEY_PL3_JUMP  },
					{ KEY_PL4_LEFT,  KEY_PL4_RIGHT,  KEY_PL4_JUMP  }
				};
				int flags[3];
				int d;

				flags[0] = lm;
				flags[1] = rm;
				flags[2] = jm;

				for (d = 0; d < 3; d++) {
					int key = dir_key[i][d];
					key &= 0x7f;
					if (flags[d])
						addkey(key);
					else
						addkey(key | 0x8000);
				}
			}
			}
		}
}
