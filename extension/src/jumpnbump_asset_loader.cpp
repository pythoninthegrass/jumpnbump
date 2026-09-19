#include "jumpnbump_asset_loader.hpp"

#include <cstring>
#include <vector>

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

namespace godot {

namespace {

// dat.zig's prefixMatch is a case-insensitive PREFIX match against a 12-byte
// name field, so a short, unambiguous name (never longer than 12 bytes)
// suffices here exactly as it does in main.c's own dat_open calls.

Dictionary make_error(jnb_result result) {
	Dictionary out;
	out["result"] = result;
	return out;
}

// Locates `name` inside dat_bytes via jnb_dat_find and returns its payload
// as a raw pointer/length pair into dat_bytes (no copy) -- callable only
// while dat_bytes stays alive. found is set false (not an error) when
// `required` is false and the entry is simply absent.
bool find_entry(const PackedByteArray &dat_bytes, const char *name, size_t *out_offset, size_t *out_size) {
	jnb_result result = jnb_dat_find(dat_bytes.ptr(), static_cast<size_t>(dat_bytes.size()), name, strlen(name), out_offset, out_size);
	return result == JNB_OK;
}

Ref<Image> make_rgba_image(const std::vector<uint8_t> &pixels) {
	PackedByteArray data;
	data.resize(static_cast<int>(pixels.size()));
	memcpy(data.ptrw(), pixels.data(), pixels.size());
	return Image::create_from_data(static_cast<int32_t>(JNB_ASSET_SCREEN_W), static_cast<int32_t>(JNB_ASSET_SCREEN_H), false, Image::FORMAT_RGBA8, data);
}

// Decodes one sprite gob (already display-scaled palette in hand) into a
// Dictionary {"image": Image, "frames": Array of per-frame Dictionaries}.
// Returns an empty Dictionary (leaving *out_result untouched) if the gob
// isn't present in the archive at all -- callers treat that as "no sprites
// of this kind", not a decode failure.
Dictionary decode_gob_atlas(const PackedByteArray &dat_bytes, const char *name, const uint8_t palette[JNB_ASSET_PALETTE_SIZE], jnb_result *out_result) {
	size_t offset = 0, size = 0;
	if (!find_entry(dat_bytes, name, &offset, &size)) {
		return Dictionary();
	}
	const uint8_t *gob_buf = dat_bytes.ptr() + offset;

	size_t frame_count = 0;
	jnb_result result = jnb_gob_atlas_build(gob_buf, size, palette, nullptr, 0, &frame_count, nullptr, 0);
	if (result != JNB_OK) {
		*out_result = result;
		return Dictionary();
	}

	std::vector<jnb_atlas_frame> frames(frame_count);
	std::vector<uint8_t> pixels(JNB_ASSET_RGBA_LEN);
	result = jnb_gob_atlas_build(gob_buf, size, palette, frames.data(), frames.size(), &frame_count, pixels.data(), pixels.size());
	if (result != JNB_OK) {
		*out_result = result;
		return Dictionary();
	}

	Array frames_out;
	for (const jnb_atlas_frame &f : frames) {
		Dictionary entry;
		entry["x"] = f.x;
		entry["y"] = f.y;
		entry["width"] = f.width;
		entry["height"] = f.height;
		entry["hotspot_x"] = f.hotspot_x;
		entry["hotspot_y"] = f.hotspot_y;
		frames_out.push_back(entry);
	}

	Dictionary out;
	out["image"] = make_rgba_image(pixels);
	out["frames"] = frames_out;
	return out;
}

// Decodes a background/mask PCX pair into {"background": Image,
// "foreground": Image}. Returns an empty Dictionary if either half is
// missing from the archive.
Dictionary decode_layer_pair(const PackedByteArray &dat_bytes, const char *bg_name, const char *mask_name, jnb_result *out_result) {
	size_t bg_offset = 0, bg_size = 0, mask_offset = 0, mask_size = 0;
	if (!find_entry(dat_bytes, bg_name, &bg_offset, &bg_size) || !find_entry(dat_bytes, mask_name, &mask_offset, &mask_size)) {
		return Dictionary();
	}

	std::vector<uint8_t> background(JNB_ASSET_RGBA_LEN);
	std::vector<uint8_t> foreground(JNB_ASSET_RGBA_LEN);
	jnb_result result = jnb_level_layers_build(
			dat_bytes.ptr() + bg_offset, bg_size,
			dat_bytes.ptr() + mask_offset, mask_size,
			background.data(), background.size(),
			foreground.data(), foreground.size());
	if (result != JNB_OK) {
		*out_result = result;
		return Dictionary();
	}

	Dictionary out;
	out["background"] = make_rgba_image(background);
	out["foreground"] = make_rgba_image(foreground);
	return out;
}

} // namespace

void JumpnbumpAssetLoader::_bind_methods() {
	ClassDB::bind_static_method(get_class_static(), D_METHOD("load_dat", "dat_path"), &JumpnbumpAssetLoader::load_dat);
}

Dictionary JumpnbumpAssetLoader::load_dat(const String &dat_path) {
	Ref<FileAccess> file = FileAccess::open(dat_path, FileAccess::READ);
	if (file.is_null()) {
		return make_error(JNB_ERR_INVALID_ARGUMENT);
	}
	PackedByteArray dat_bytes = file->get_buffer(static_cast<int64_t>(file->get_length()));
	file->close();

	uint8_t palette[JNB_ASSET_PALETTE_SIZE] = { 0 };
	size_t menu_offset = 0, menu_size = 0;
	if (find_entry(dat_bytes, "menu.pcx", &menu_offset, &menu_size)) {
		jnb_result result = jnb_pcx_palette_decode(dat_bytes.ptr() + menu_offset, menu_size, palette, sizeof(palette));
		if (result != JNB_OK) {
			return make_error(result);
		}
	}

	jnb_result decode_result = JNB_OK;
	Dictionary sprites;
	static const char *gob_names[] = { "rabbit.gob", "objects.gob", "numbers.gob", "font.gob" };
	for (const char *name : gob_names) {
		Dictionary atlas = decode_gob_atlas(dat_bytes, name, palette, &decode_result);
		if (decode_result != JNB_OK) {
			return make_error(decode_result);
		}
		if (!atlas.is_empty()) {
			// Strip the ".gob" extension for the Dictionary key ("rabbit", not "rabbit.gob").
			String key = String(name).get_basename();
			sprites[key] = atlas;
		}
	}

	Dictionary level = decode_layer_pair(dat_bytes, "level.pcx", "mask.pcx", &decode_result);
	if (decode_result != JNB_OK) {
		return make_error(decode_result);
	}
	Dictionary menu = decode_layer_pair(dat_bytes, "menu.pcx", "menumask.pcx", &decode_result);
	if (decode_result != JNB_OK) {
		return make_error(decode_result);
	}

	PackedByteArray levelmap_bytes;
	size_t levelmap_offset = 0, levelmap_size = 0;
	if (find_entry(dat_bytes, "levelmap.txt", &levelmap_offset, &levelmap_size)) {
		levelmap_bytes.resize(static_cast<int>(levelmap_size));
		memcpy(levelmap_bytes.ptrw(), dat_bytes.ptr() + levelmap_offset, levelmap_size);
	}

	Dictionary out;
	out["result"] = JNB_OK;
	out["sprites"] = sprites;
	out["level"] = level;
	out["menu"] = menu;
	out["levelmap_bytes"] = levelmap_bytes;
	return out;
}

} // namespace godot
