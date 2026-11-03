// Stand-in set dressing for the overworld's walk-grid geometry (OverworldMap
// .build_set()): procedural pixel-stepped surfaces in world space, so
// neighbouring wall boxes read as one continuous street front. No TIME
// (world shaders read mode_time; this one is static).
// TODO(art): authored textures and props replace this
// (production/asset-requests/art.md).
shader_type spatial;
render_mode cull_back;

// 0 = street (cobbles; limestone fronts, windows, slate roofs),
// 1 = interior (carpet tiles; office panels, filing drawers, grey tops).
uniform int style = 0;
// 0 = floor, 1 = wall.
uniform int surface = 0;
// The map's own floor and wall tints (OverworldMap.floor_color / wall_color).
uniform vec3 floor_tint : source_color = vec3(0.62, 0.58, 0.5);
uniform vec3 wall_tint : source_color = vec3(0.78, 0.7, 0.55);
// Texels per metre: everything is snapped to this grid so it reads as pixels.
uniform float texels_per_m = 16.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 cobbles(vec2 p) {
	// Staggered rows of 4 stones per metre with dark joints.
	vec2 s = p * 4.0;
	s.x += step(1.0, mod(floor(s.y), 2.0)) * 0.5;
	vec2 cell = floor(s);
	vec2 f = fract(s);
	float joint = step(f.x, 0.07) + step(f.y, 0.09);
	float shade = 0.86 + 0.22 * hash(cell);
	vec3 stone = floor_tint * shade;
	return mix(stone, floor_tint * 0.55, clamp(joint, 0.0, 1.0));
}

vec3 carpet(vec2 p) {
	// 50 cm carpet tiles, alternating grain.
	vec2 cell = floor(p * 2.0);
	float alt = mod(cell.x + cell.y, 2.0);
	vec2 f = fract(p * 2.0);
	float seam = step(f.x, 0.04) + step(f.y, 0.04);
	vec3 c = floor_tint * (0.92 + 0.1 * alt + 0.04 * hash(floor(p * 16.0)));
	return mix(c, floor_tint * 0.7, clamp(seam, 0.0, 1.0));
}

vec3 facade(float u, float v) {
	// One window bay per metre: limestone, a darker shop plinth, a cornice
	// line, and a tall window with a cream frame and a balcony rail.
	vec3 stone = wall_tint * (0.94 + 0.08 * hash(vec2(floor(u * 8.0), floor(v * 8.0))));
	float bay = fract(u);
	if (v < 0.22) {
		return wall_tint * 0.62;
	}
	if (v > 1.08) {
		return wall_tint * 0.8;
	}
	bool in_frame = bay > 0.24 && bay < 0.76 && v > 0.38 && v < 0.98;
	bool in_glass = bay > 0.3 && bay < 0.7 && v > 0.44 && v < 0.94;
	if (in_glass) {
		bool mullion = abs(bay - 0.5) < 0.035 || abs(v - 0.7) < 0.03;
		return mullion ? vec3(0.86, 0.82, 0.72) : vec3(0.2, 0.25, 0.34);
	}
	if (in_frame) {
		return vec3(0.9, 0.86, 0.76);
	}
	if (v > 0.36 && v < 0.42 && bay > 0.18 && bay < 0.82) {
		return vec3(0.16, 0.15, 0.17);
	}
	return stone;
}

vec3 office_wall(float u, float v) {
	// Panelled wall with a run of filing-cabinet drawers along the base.
	float bay = fract(u * 2.0);
	if (v < 0.62) {
		float drawer = fract(v / 0.2);
		vec3 metal = vec3(0.56, 0.58, 0.6);
		if (drawer < 0.08 || bay < 0.05) {
			return metal * 0.6;
		}
		if (drawer > 0.45 && drawer < 0.6 && bay > 0.4 && bay < 0.6) {
			return vec3(0.85, 0.85, 0.82);
		}
		return metal;
	}
	return wall_tint * (bay < 0.03 ? 0.8 : 1.0);
}

vec3 roof(vec2 p) {
	// Zinc/slate roof: grey-blue rows of tiles.
	float row = fract(p.y * 5.0);
	vec3 slate = vec3(0.36, 0.4, 0.48) * (0.92 + 0.12 * hash(floor(p * vec2(6.0, 5.0))));
	return row < 0.12 ? slate * 0.7 : slate;
}

void fragment() {
	vec3 p = floor(world_pos * texels_per_m) / texels_per_m + 0.5 / texels_per_m;
	vec3 col;
	if (surface == 0) {
		col = style == 0 ? cobbles(p.xz) : carpet(p.xz);
	} else if (world_normal.y > 0.5) {
		col = style == 0 ? roof(p.xz) : vec3(0.42, 0.43, 0.45);
	} else {
		float u = abs(world_normal.x) > 0.5 ? p.z : p.x;
		col = style == 0 ? facade(u, p.y) : office_wall(u, p.y);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
