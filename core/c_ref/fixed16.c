/*
 * TASK-011.01 differential-test reference.
 *
 * The C integer expressions over 16.16 fixed-point values (player[].x/y,
 * x_add/y_add, x_acc/y_acc — all plain `int` in globals.pre) extracted
 * verbatim from their call sites in main.c — player integration in
 * steer_players() (main.c:2189-2214), the butterfly/particle wall bounce
 * in update_objects() (main.c:2501, 2644) and the level spawn/reset
 * shifts (main.c:2208, 2382, add_object at main.c:2416). Compiled here as
 * the renamed-C-reference side of the difftest harness (core/build.zig's
 * compileRenamedCRef prefixes these with c_), so core/fixed16.zig has the
 * compiled oracle's own answers to diff against for every
 * overflow/truncation case the port has to reproduce.
 */

int fp_add_ref(int a, int b)
{
	return a + b;
}

int fp_sub_ref(int a, int b)
{
	return a - b;
}

int fp_neg_ref(int a)
{
	return -a;
}

int fp_mul_small_ref(int a, int m)
{
	return a * m;
}

int fp_pixel_shr16_ref(int v)
{
	return v >> 16;
}

int fp_pixel_shr20_ref(int v)
{
	return v >> 20;
}

int fp_sar_int_ref(int v, int n)
{
	return v >> n;
}

int fp_bounce_quarter_ref(int v)
{
	return -v >> 2;
}

int fp_to_fixed_ref(int pixel)
{
	return (long) pixel << 16;
}

int fp_from_pixel_shl_ref(int pixel)
{
	return pixel << 16;
}

int fp_wrap_mask_shl16_ref(int v)
{
	return ((v + 16) & 0xfff0) << 16;
}

int fp_wrap_mask_sub_shl16_ref(int v)
{
	return (((v + 16) & 0xfff0) - 16) << 16;
}

int fp_wrap_hi_shl16_ref(int v)
{
	return ((v - 16) & 0xfff0) << 16;
}

int fp_wrap_hi_plus15_shl16_ref(int v)
{
	return (((v - 16) & 0xfff0) + 15) << 16;
}

int fp_pixel_shl4_ref(int v)
{
	return v << 4;
}

int fp_to_tile20_ref(int v)
{
	// (v >> 16) & 0xfff0) << 16 — the player.y snap at main.c:2224, in its
	// full form; masking without re-shifting has no meaning in the C.
	return ((v >> 16) & 0xfff0) << 16;
}
