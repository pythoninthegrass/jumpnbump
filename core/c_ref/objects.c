/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/objects.zig (TASK-011.04): main.c lines
 * 2408-2764, extracted verbatim by core/c_ref/extract_objects.py.
 * Re-run that script if either function changes; editing this file by hand
 * reintroduces exactly the transcription drift the extraction exists to
 * prevent. core/build.zig compiles it through compileRenamedCRef, which
 * prefixes every symbol below with c_ so it links alongside the Zig port
 * (which owns the original names).
 *
 * What the two functions touch that main.c keeps outside themselves:
 * objects[]/object_anims[]/ban_map[] world state, rnd(), add_pob() and
 * add_leftovers() (both draw-side), and (through add_object) the object_t
 * layout. The harness owns all of that - one shared world both sides mutate,
 * a pre-generated rnd() stream both sides draw from through c_rnd_from()
 * (the rnd(max) macro below), and no-op draw/leftover sinks - so the only
 * difference the differential can detect is the ported logic itself.
 */

#include <stdlib.h>
#include <math.h>

#define NUM_OBJECTS 200

#define OBJ_SPRING 0
#define OBJ_SPLASH 1
#define OBJ_SMOKE 2
#define OBJ_YEL_BUTFLY 3
#define OBJ_PINK_BUTFLY 4
#define OBJ_FUR 5
#define OBJ_FLESH 6
#define OBJ_FLESH_TRACE 7

#define OBJ_ANIM_SPLASH 1
#define OBJ_ANIM_SMOKE 2
#define OBJ_ANIM_YEL_BUTFLY_RIGHT 3
#define OBJ_ANIM_YEL_BUTFLY_LEFT 4
#define OBJ_ANIM_PINK_BUTFLY_RIGHT 5
#define OBJ_ANIM_PINK_BUTFLY_LEFT 6
#define OBJ_ANIM_FLESH_TRACE 7

typedef struct {
	int num_frames;
	int restart_frame;
	struct {
		int image;
		int ticks;
	} frame[10];
} object_anim_t;

typedef struct {
	int used, type;
	int x, y;
	int x_add, y_add;
	int x_acc, y_acc;
	int anim;
	int frame, ticks;
	int image;
} object_t;

/* Defined by the harness (core/objects_difftest.zig, which rebinds them onto
 * core/objects.zig's own exported storage): the one world both sides mutate,
 * in the layout docs/checksum-format.md fixes. */
extern object_t objects[NUM_OBJECTS];
extern object_anim_t object_anims[8];
extern unsigned int ban_map[17][22];

/* main_info.draw_page and &object_gobs are the two draw-boundary operands the
 * extracted add_pob()/add_leftovers() call sites pass through. They never
 * reach the simulation (the sinks below drop them), so opaque placeholders
 * declared here are enough for the extracted text to compile; the harness
 * defines the real (unused) object_gobs it takes the address of. */
typedef struct { void *draw_page; } main_info_t;
extern main_info_t main_info;
extern int object_gobs;

/* Harness-provided. c_rnd_from() serves both sides the same pre-generated
 * draw sequence; add_pob() drops its arguments (the draw boundary stays out
 * of the simulation, so the only observable effect of the octant/atan2 math
 * is the frame index the port computes); add_leftovers() likewise drops its
 * arguments but is counted so the differential sees its side effects. */
unsigned short c_rnd_from(unsigned short max);
void add_pob(void *page, int x, int y, int image, void *gobs);
void add_leftovers(int which, int x, int y, int frame, void *gobs);
#define rnd(max) c_rnd_from((max))

void add_object(int type, int x, int y, int x_add, int y_add, int anim, int frame)
{
	int c1;

	for (c1 = 0; c1 < NUM_OBJECTS; c1++) {
		if (objects[c1].used == 0) {
			objects[c1].used = 1;
			objects[c1].type = type;
			objects[c1].x = (long) x << 16;
			objects[c1].y = (long) y << 16;
			objects[c1].x_add = x_add;
			objects[c1].y_add = y_add;
			objects[c1].x_acc = 0;
			objects[c1].y_acc = 0;
			objects[c1].anim = anim;
			objects[c1].frame = frame;
			objects[c1].ticks = object_anims[anim].frame[frame].ticks;
			objects[c1].image = object_anims[anim].frame[frame].image;
			break;
		}
	}

}

void update_objects(void)
{
	int c1;
	int s1 = 0;

	for (c1 = 0; c1 < NUM_OBJECTS; c1++) {
		if (objects[c1].used == 1) {
			switch (objects[c1].type) {
			case OBJ_SPRING:
				objects[c1].ticks--;
				if (objects[c1].ticks <= 0) {
					objects[c1].frame++;
					if (objects[c1].frame >= object_anims[objects[c1].anim].num_frames) {
						objects[c1].frame--;
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
					} else {
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].image, &object_gobs);
				break;
			case OBJ_SPLASH:
				objects[c1].ticks--;
				if (objects[c1].ticks <= 0) {
					objects[c1].frame++;
					if (objects[c1].frame >= object_anims[objects[c1].anim].num_frames)
						objects[c1].used = 0;
					else {
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].image, &object_gobs);
				break;
			case OBJ_SMOKE:
				objects[c1].x += objects[c1].x_add;
				objects[c1].y += objects[c1].y_add;
				objects[c1].ticks--;
				if (objects[c1].ticks <= 0) {
					objects[c1].frame++;
					if (objects[c1].frame >= object_anims[objects[c1].anim].num_frames)
						objects[c1].used = 0;
					else {
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].image, &object_gobs);
				break;
			case OBJ_YEL_BUTFLY:
			case OBJ_PINK_BUTFLY:
				objects[c1].x_acc += rnd(128) - 64;
				if (objects[c1].x_acc < -1024)
					objects[c1].x_acc = -1024;
				if (objects[c1].x_acc > 1024)
					objects[c1].x_acc = 1024;
				objects[c1].x_add += objects[c1].x_acc;
				if (objects[c1].x_add < -32768)
					objects[c1].x_add = -32768;
				if (objects[c1].x_add > 32768)
					objects[c1].x_add = 32768;
				objects[c1].x += objects[c1].x_add;
				if ((objects[c1].x >> 16) < 16) {
					objects[c1].x = 16 << 16;
					objects[c1].x_add = -objects[c1].x_add >> 2;
					objects[c1].x_acc = 0;
				} else if ((objects[c1].x >> 16) > 350) {
					objects[c1].x = 350 << 16;
					objects[c1].x_add = -objects[c1].x_add >> 2;
					objects[c1].x_acc = 0;
				}
				if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 0) {
					if (objects[c1].x_add < 0) {
						objects[c1].x = (((objects[c1].x >> 16) + 16) & 0xfff0) << 16;
					} else {
						objects[c1].x = ((((objects[c1].x >> 16) - 16) & 0xfff0) + 15) << 16;
					}
					objects[c1].x_add = -objects[c1].x_add >> 2;
					objects[c1].x_acc = 0;
				}
				objects[c1].y_acc += rnd(64) - 32;
				if (objects[c1].y_acc < -1024)
					objects[c1].y_acc = -1024;
				if (objects[c1].y_acc > 1024)
					objects[c1].y_acc = 1024;
				objects[c1].y_add += objects[c1].y_acc;
				if (objects[c1].y_add < -32768)
					objects[c1].y_add = -32768;
				if (objects[c1].y_add > 32768)
					objects[c1].y_add = 32768;
				objects[c1].y += objects[c1].y_add;
				if ((objects[c1].y >> 16) < 0) {
					objects[c1].y = 0;
					objects[c1].y_add = -objects[c1].y_add >> 2;
					objects[c1].y_acc = 0;
				} else if ((objects[c1].y >> 16) > 255) {
					objects[c1].y = 255 << 16;
					objects[c1].y_add = -objects[c1].y_add >> 2;
					objects[c1].y_acc = 0;
				}
				if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 0) {
					if (objects[c1].y_add < 0) {
						objects[c1].y = (((objects[c1].y >> 16) + 16) & 0xfff0) << 16;
					} else {
						objects[c1].y = ((((objects[c1].y >> 16) - 16) & 0xfff0) + 15) << 16;
					}
					objects[c1].y_add = -objects[c1].y_add >> 2;
					objects[c1].y_acc = 0;
				}
				if (objects[c1].type == OBJ_YEL_BUTFLY) {
					if (objects[c1].x_add < 0 && objects[c1].anim != OBJ_ANIM_YEL_BUTFLY_LEFT) {
						objects[c1].anim = OBJ_ANIM_YEL_BUTFLY_LEFT;
						objects[c1].frame = 0;
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					} else if (objects[c1].x_add > 0 && objects[c1].anim != OBJ_ANIM_YEL_BUTFLY_RIGHT) {
						objects[c1].anim = OBJ_ANIM_YEL_BUTFLY_RIGHT;
						objects[c1].frame = 0;
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				} else {
					if (objects[c1].x_add < 0 && objects[c1].anim != OBJ_ANIM_PINK_BUTFLY_LEFT) {
						objects[c1].anim = OBJ_ANIM_PINK_BUTFLY_LEFT;
						objects[c1].frame = 0;
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					} else if (objects[c1].x_add > 0 && objects[c1].anim != OBJ_ANIM_PINK_BUTFLY_RIGHT) {
						objects[c1].anim = OBJ_ANIM_PINK_BUTFLY_RIGHT;
						objects[c1].frame = 0;
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				objects[c1].ticks--;
				if (objects[c1].ticks <= 0) {
					objects[c1].frame++;
					if (objects[c1].frame >= object_anims[objects[c1].anim].num_frames)
						objects[c1].frame = object_anims[objects[c1].anim].restart_frame;
					else {
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].image, &object_gobs);
				break;
			case OBJ_FUR:
				if (rnd(100) < 30)
					add_object(OBJ_FLESH_TRACE, objects[c1].x >> 16, objects[c1].y >> 16, 0, 0, OBJ_ANIM_FLESH_TRACE, 0);
				if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 0) {
					objects[c1].y_add += 3072;
					if (objects[c1].y_add > 196608L)
						objects[c1].y_add = 196608L;
				} else if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 2) {
					if (objects[c1].x_add < 0) {
						if (objects[c1].x_add < -65536L)
							objects[c1].x_add = -65536L;
						objects[c1].x_add += 1024;
						if (objects[c1].x_add > 0)
							objects[c1].x_add = 0;
					} else {
						if (objects[c1].x_add > 65536L)
							objects[c1].x_add = 65536L;
						objects[c1].x_add -= 1024;
						if (objects[c1].x_add < 0)
							objects[c1].x_add = 0;
					}
					objects[c1].y_add += 1024;
					if (objects[c1].y_add < -65536L)
						objects[c1].y_add = -65536L;
					if (objects[c1].y_add > 65536L)
						objects[c1].y_add = 65536L;
				}
				objects[c1].x += objects[c1].x_add;
				if ((objects[c1].y >> 16) > 0 && (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 1 || ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 3)) {
					if (objects[c1].x_add < 0) {
						objects[c1].x = (((objects[c1].x >> 16) + 16) & 0xfff0) << 16;
						objects[c1].x_add = -objects[c1].x_add >> 2;
					} else {
						objects[c1].x = ((((objects[c1].x >> 16) - 16) & 0xfff0) + 15) << 16;
						objects[c1].x_add = -objects[c1].x_add >> 2;
					}
				}
				objects[c1].y += objects[c1].y_add;
				if ((objects[c1].x >> 16) < -5 || (objects[c1].x >> 16) > 405 || (objects[c1].y >> 16) > 260)
					objects[c1].used = 0;
				if ((objects[c1].y >> 16) > 0 && (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 0)) {
					if (objects[c1].y_add < 0) {
						if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 2) {
							objects[c1].y = (((objects[c1].y >> 16) + 16) & 0xfff0) << 16;
							objects[c1].x_add >>= 2;
							objects[c1].y_add = -objects[c1].y_add >> 2;
						}
					} else {
						if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 1) {
							if (objects[c1].y_add > 131072L) {
								objects[c1].y = ((((objects[c1].y >> 16) - 16) & 0xfff0) + 15) << 16;
								objects[c1].x_add >>= 2;
								objects[c1].y_add = -objects[c1].y_add >> 2;
							} else
								objects[c1].used = 0;
						} else if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 3) {
							objects[c1].y = ((((objects[c1].y >> 16) - 16) & 0xfff0) + 15) << 16;
							if (objects[c1].y_add > 131072L)
								objects[c1].y_add = -objects[c1].y_add >> 2;
							else
								objects[c1].y_add = 0;
						}
					}
				}
				if (objects[c1].x_add < 0 && objects[c1].x_add > -16384)
					objects[c1].x_add = -16384;
				if (objects[c1].x_add > 0 && objects[c1].x_add < 16384)
					objects[c1].x_add = 16384;
				if (objects[c1].used == 1) {
					s1 = (int)(atan2(objects[c1].y_add, objects[c1].x_add) * 4 / M_PI);
					if (s1 < 0)
						s1 += 8;
					if (s1 < 0)
						s1 = 0;
					if (s1 > 7)
						s1 = 7;
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].frame + s1, &object_gobs);
				}
				break;
			case OBJ_FLESH:
				if (rnd(100) < 30) {
					if (objects[c1].frame == 76)
						add_object(OBJ_FLESH_TRACE, objects[c1].x >> 16, objects[c1].y >> 16, 0, 0, OBJ_ANIM_FLESH_TRACE, 1);
					else if (objects[c1].frame == 77)
						add_object(OBJ_FLESH_TRACE, objects[c1].x >> 16, objects[c1].y >> 16, 0, 0, OBJ_ANIM_FLESH_TRACE, 2);
					else if (objects[c1].frame == 78)
						add_object(OBJ_FLESH_TRACE, objects[c1].x >> 16, objects[c1].y >> 16, 0, 0, OBJ_ANIM_FLESH_TRACE, 3);
				}
				if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 0) {
					objects[c1].y_add += 3072;
					if (objects[c1].y_add > 196608L)
						objects[c1].y_add = 196608L;
				} else if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 2) {
					if (objects[c1].x_add < 0) {
						if (objects[c1].x_add < -65536L)
							objects[c1].x_add = -65536L;
						objects[c1].x_add += 1024;
						if (objects[c1].x_add > 0)
							objects[c1].x_add = 0;
					} else {
						if (objects[c1].x_add > 65536L)
							objects[c1].x_add = 65536L;
						objects[c1].x_add -= 1024;
						if (objects[c1].x_add < 0)
							objects[c1].x_add = 0;
					}
					objects[c1].y_add += 1024;
					if (objects[c1].y_add < -65536L)
						objects[c1].y_add = -65536L;
					if (objects[c1].y_add > 65536L)
						objects[c1].y_add = 65536L;
				}
				objects[c1].x += objects[c1].x_add;
				if ((objects[c1].y >> 16) > 0 && (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 1 || ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 3)) {
					if (objects[c1].x_add < 0) {
						objects[c1].x = (((objects[c1].x >> 16) + 16) & 0xfff0) << 16;
						objects[c1].x_add = -objects[c1].x_add >> 2;
					} else {
						objects[c1].x = ((((objects[c1].x >> 16) - 16) & 0xfff0) + 15) << 16;
						objects[c1].x_add = -objects[c1].x_add >> 2;
					}
				}
				objects[c1].y += objects[c1].y_add;
				if ((objects[c1].x >> 16) < -5 || (objects[c1].x >> 16) > 405 || (objects[c1].y >> 16) > 260)
					objects[c1].used = 0;
				if ((objects[c1].y >> 16) > 0 && (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 0)) {
					if (objects[c1].y_add < 0) {
						if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] != 2) {
							objects[c1].y = (((objects[c1].y >> 16) + 16) & 0xfff0) << 16;
							objects[c1].x_add >>= 2;
							objects[c1].y_add = -objects[c1].y_add >> 2;
						}
					} else {
						if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 1) {
							if (objects[c1].y_add > 131072L) {
								objects[c1].y = ((((objects[c1].y >> 16) - 16) & 0xfff0) + 15) << 16;
								objects[c1].x_add >>= 2;
								objects[c1].y_add = -objects[c1].y_add >> 2;
							} else {
								if (rnd(100) < 10) {
									s1 = rnd(4) - 2;
									add_leftovers(0, objects[c1].x >> 16, (objects[c1].y >> 16) + s1, objects[c1].frame, &object_gobs);
									add_leftovers(1, objects[c1].x >> 16, (objects[c1].y >> 16) + s1, objects[c1].frame, &object_gobs);
								}
								objects[c1].used = 0;
							}
						} else if (ban_map[objects[c1].y >> 20][objects[c1].x >> 20] == 3) {
							objects[c1].y = ((((objects[c1].y >> 16) - 16) & 0xfff0) + 15) << 16;
							if (objects[c1].y_add > 131072L)
								objects[c1].y_add = -objects[c1].y_add >> 2;
							else
								objects[c1].y_add = 0;
						}
					}
				}
				if (objects[c1].x_add < 0 && objects[c1].x_add > -16384)
					objects[c1].x_add = -16384;
				if (objects[c1].x_add > 0 && objects[c1].x_add < 16384)
					objects[c1].x_add = 16384;
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].frame, &object_gobs);
				break;
			case OBJ_FLESH_TRACE:
				objects[c1].ticks--;
				if (objects[c1].ticks <= 0) {
					objects[c1].frame++;
					if (objects[c1].frame >= object_anims[objects[c1].anim].num_frames)
						objects[c1].used = 0;
					else {
						objects[c1].ticks = object_anims[objects[c1].anim].frame[objects[c1].frame].ticks;
						objects[c1].image = object_anims[objects[c1].anim].frame[objects[c1].frame].image;
					}
				}
				if (objects[c1].used == 1)
					add_pob(main_info.draw_page, objects[c1].x >> 16, objects[c1].y >> 16, objects[c1].image, &object_gobs);
				break;
			}
		}
	}

}
