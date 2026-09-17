/*
 * Compile-only smoke check for include/jumpnbump.h (TASK-012.01). Proves the
 * header is self-consistent and that every declared type/function is
 * genuinely usable -- not just that it parses -- before core/abi.zig
 * (TASK-012.02) provides a real implementation to link against.
 *
 * Deliberately compiled to an object file, never linked or run: with no
 * implementation behind these symbols yet, referencing them is only valid
 * as long as nothing tries to resolve them.
 */

#include "../include/jumpnbump.h"

static void exercise_header(void) {
    jnb_config config = {0};
    config.abi_version = JNB_ABI_VERSION;
    config.rng_seed = 12345;
    config.flies_enabled = 1;

    size_t world_bytes = jnb_world_size();
    size_t world_align = jnb_world_align();
    (void)world_bytes;
    (void)world_align;

    /* Never actually sized/aligned per jnb_world_size/jnb_world_align (no
     * implementation exists yet to allocate correctly for) -- a fixed
     * storage buffer is enough for a compile-only reference. */
    static unsigned char storage[1];
    jnb_world *world = (jnb_world *)(void *)storage;

    static const uint8_t level_bytes[1] = {0};
    jnb_result r = jnb_world_init(world, &config, level_bytes, sizeof(level_bytes));
    r = jnb_world_reset(world);

    jnb_input input = {1, 0, 1, 0};
    r = jnb_step(world, input);

    uint32_t ticks = 0;
    r = jnb_pump(world, 16u, input, &ticks);

    jnb_player_view player_view = {0};
    r = jnb_player_view_get(world, 0, &player_view);

    jnb_object_view objects[JNB_NUM_OBJECTS];
    size_t objects_required = 0;
    r = jnb_objects_copy(world, objects, JNB_NUM_OBJECTS, &objects_required);
    r = jnb_objects_copy(world, NULL, 0, &objects_required);

    size_t dump_len = jnb_world_dump_len();
    static uint8_t dump_buf[16384];
    size_t dump_written = 0;
    r = jnb_world_dump(world, dump_buf, sizeof(dump_buf), &dump_written);
    (void)dump_len;

    uint32_t checksum = 0;
    r = jnb_checksum(dump_buf, dump_written, &checksum);

    jnb_event events[8];
    size_t event_count = 0;
    r = jnb_event_drain(world, events, 8, &event_count);
    size_t queued = jnb_event_count(world);

    (void)r;
    (void)queued;
    (void)checksum;
}

/* Never invoked (there is nothing to run this against yet) -- its only job
 * is to force the compiler to type-check every call above. */
void (*jnb_abi_header_smoke_entry)(void) = exercise_header;
