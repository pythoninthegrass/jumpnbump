/*
 * Renamed-C reference for core/rnd.zig (TASK-011.01).
 *
 * main.c's rnd() (main.c:3562) with the rnd_call_count bookkeeping
 * stripped — that counter is checksum scaffolding (docs/checksum-format.md),
 * not part of the RNG formula, and it lives in the ported module instead.
 * Compiled as the renamed-C-reference side of the difftest harness
 * (core/build.zig's compileRenamedCRef renames this to c_rnd) so
 * core/rnd_difftest.zig can drive both sides over 10,000+-call sequences.
 * Keep in sync with main.c's rnd() by hand.
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
