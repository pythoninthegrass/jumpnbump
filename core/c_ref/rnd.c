/*
 * Phase 1 (TASK-008.04) differential-test pilot.
 *
 * main.c's rnd() extracted verbatim, compiled here as the renamed-C-reference
 * side of the difftest harness (core/build.zig's compileRenamedCRef renames
 * this to c_rnd) so core/rnd_difftest.zig has something concrete to diff the
 * trivial core/rnd.zig passthrough against before any real TASK-011.* module
 * exists. Keep this in sync with main.c's rnd() by hand; when TASK-011 ports
 * the real RNG call sites, this pilot is retired in favor of the real module.
 */
#include <stdlib.h>

unsigned short rnd(unsigned short max)
{
#if (RAND_MAX < 0x7fff)
#error "rand returns too small values"
#elif (RAND_MAX == 0x7fff)
	return (unsigned short)((rand()*2) % (int)max);
#else
	return (unsigned short)(rand() % (int)max);
#endif
}
