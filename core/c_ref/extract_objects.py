"""Generate core/c_ref/objects.c from main.c.

TASK-011.04's renamed-C reference is not a hand-copied excerpt: it is
main.c's add_object() and update_objects() function text extracted verbatim
from the current checkout, so the differential cannot drift from the oracle
through transcription the way a hand-ported `.c` copy would. main.c itself is
never modified.

The cut ranges are found by scanning for the two definition lines and the
definition lines that follow them (not hardcoded line numbers), so small edits
elsewhere in main.c don't break the extraction. Regenerate after any change to
those two functions:

    python3 core/c_ref/extract_objects.py

The generated file's header records the main.c line range it came from, so a
reviewer can diff it against the oracle directly.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAIN_C = ROOT / "main.c"
OUT = Path(__file__).resolve().parent / "objects.c"

# objects.c's preamble: the macros, struct twins and harness-owned globals the
# two extracted functions reference. Everything declared here is defined
# either in this file (the typedefs/macros) or in the difftest harness
# (core/objects_difftest.zig), which shares one copy of the world state with
# the Zig port so both sides run against identical inputs.
PREAMBLE = """/*
 * GENERATED FILE - do not edit by hand.
 *
 * Renamed-C reference for core/objects.zig (TASK-011.04): main.c lines
 * {start}-{end}, extracted verbatim by core/c_ref/extract_objects.py.
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

typedef struct {{
	int num_frames;
	int restart_frame;
	struct {{
		int image;
		int ticks;
	}} frame[10];
}} object_anim_t;

typedef struct {{
	int used, type;
	int x, y;
	int x_add, y_add;
	int x_acc, y_acc;
	int anim;
	int frame, ticks;
	int image;
}} object_t;

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
typedef struct {{ void *draw_page; }} main_info_t;
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
"""


def find_line(lines, prefix, start=0):
   for i in range(start, len(lines)):
      if lines[i].startswith(prefix):
         return i
   sys.exit(f"main.c: no line starting with {prefix!r}")


def main() -> None:
   lines = MAIN_C.read_text().split("\n")

   add_start = find_line(lines, "void add_object(int type")
   update_start = find_line(lines, "void update_objects(void)", add_start)
   # update_objects() runs until the next top-level definition after it.
   update_end = find_line_after_brace(lines, update_start)

   add_text = "\n".join(lines[add_start:update_start]).rstrip("\n")
   update_text = "\n".join(lines[update_start:update_end]).rstrip("\n")
   functions = add_text + "\n\n" + update_text

   OUT.write_text(
      PREAMBLE.format(start=add_start + 1, end=update_end) + "\n" + functions + "\n"
   )
   print(f"{OUT.name}: main.c lines {add_start + 1}-{update_end} extracted")


def find_line_after_brace(lines, start):
   """Index just past the closing brace of the function whose definition
   starts at `start` (the first column-0 '}' line at or after `start`)."""
   for i in range(start, len(lines)):
      if lines[i] == "}":
         return i + 1
   sys.exit(f"main.c: no closing brace found for function at line {start + 1}")


if __name__ == "__main__":
   main()
