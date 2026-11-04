// Stand-in set dressing for the overworld's walk-grid geometry (OverworldMap
// .build_set()): procedural pixel-stepped surfaces in world space, so
// neighbouring wall boxes read as one continuous street front. No TIME
// (world shaders read mode_time; this one is static).
// TODO(art): authored textures and props replace this
// (production/asset-requests/art.md).
shader_type spatial;
render_mode cull_back;

// 0 = street (cobbles; limestone fronts, windows, slate roofs),
// 1 = interior (carpet tiles; office panels, filing drawers, grey tops),
// 2 = London street (flagstones; glass curtain walls, cyan ad strips),
// 3 = MegaCorp Tower (polished tiles; white panels, server racks),
// 4 = Sydney harbour (boardwalk planks; whitewashed fronts, magenta awnings),
// 5 = the Content House (pink terrazzo; pastel panels, ring lights, neon).
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


vec3 paving(vec2 p) {
	// London: large grey flagstones, 1 m x 0.5 m, staggered, thin joints.
	vec2 s = p * vec2(1.0, 2.0);
	s.x += step(1.0, mod(floor(s.y), 2.0)) * 0.5;
	vec2 cell = floor(s);
	vec2 f = fract(s);
	float joint = step(f.x, 0.03) + step(f.y, 0.06);
	vec3 slab = floor_tint * (0.9 + 0.14 * hash(cell));
	return mix(slab, floor_tint * 0.6, clamp(joint, 0.0, 1.0));
}

vec3 glass_front(float u, float v) {
	// London: curtain-wall glass in a steel grid, a dark plinth, a thin
	// Terminal Cyan ad strip at the top of each bay.
	if (v < 0.2) {
		return vec3(0.18, 0.2, 0.24);
	}
	float bay = fract(u * 2.0);
	float floor_line = fract(v / 0.3);
	if (bay < 0.06 || floor_line < 0.08) {
		return wall_tint * 0.55;
	}
	if (v > 1.0) {
		return vec3(0.1, 0.76, 0.84) * (0.8 + 0.2 * hash(vec2(floor(u * 2.0), 1.0)));
	}
	float sky = 0.25 + 0.35 * v + 0.08 * hash(vec2(floor(u * 2.0), floor(v / 0.3)));
	return mix(vec3(0.16, 0.24, 0.32), wall_tint, sky);
}

vec3 tower_wall(float u, float v) {
	// Inside MegaCorp Tower: white panels, a cyan stripe at waist height,
	// dark server racks with blinking dots along the base.
	float bay = fract(u * 2.0);
	if (v < 0.5) {
		vec2 led = floor(vec2(u * 16.0, v * 16.0));
		float dot_on = step(0.86, hash(led));
		vec3 rack = vec3(0.14, 0.16, 0.2);
		if (bay < 0.05) {
			return rack * 0.6;
		}
		return mix(rack, vec3(0.1, 0.76, 0.84), dot_on);
	}
	if (v > 0.56 && v < 0.62) {
		return vec3(0.1, 0.76, 0.84);
	}
	return wall_tint * (bay < 0.03 ? 0.8 : 1.0);
}

vec3 tower_floor(vec2 p) {
	// Polished grey tiles, 1 m, with a faint sheen line.
	vec2 f = fract(p);
	float seam = step(f.x, 0.02) + step(f.y, 0.02);
	vec3 c = floor_tint * (0.96 + 0.06 * hash(floor(p)));
	c += vec3(0.05) * step(0.48, f.x) * step(f.x, 0.52);
	return mix(c, floor_tint * 0.75, clamp(seam, 0.0, 1.0));
}


vec3 boardwalk(vec2 p) {
	// Sydney: sun-bleached boardwalk planks, 25 cm wide, staggered butt joints.
	vec2 s = vec2(p.x * 0.5, p.y * 4.0);
	s.x += hash(vec2(0.0, floor(s.y))) * 0.9;
	vec2 cell = floor(s);
	vec2 f = fract(s);
	float joint = step(f.y, 0.1) + step(f.x, 0.015);
	vec3 plank = floor_tint * (0.88 + 0.16 * hash(cell));
	return mix(plank, floor_tint * 0.58, clamp(joint, 0.0, 1.0));
}

vec3 harbour_front(float u, float v) {
	// Sydney: whitewashed shopfronts, a big shop window, and a Feed Magenta
	// and white striped awning over each bay.
	float bay = fract(u * 0.5);
	if (v < 0.16) {
		return wall_tint * 0.7;
	}
	if (v > 0.66 && v < 0.84) {
		float stripe = step(0.5, fract(u * 4.0));
		vec3 awning = mix(vec3(0.91, 0.24, 0.61), vec3(0.97, 0.94, 0.9), stripe);
		return awning * (v < 0.7 ? 0.8 : 1.0);
	}
	if (bay > 0.12 && bay < 0.88 && v > 0.22 && v < 0.62) {
		bool mullion = abs(bay - 0.5) < 0.02;
		return mullion ? wall_tint * 0.8 : vec3(0.32, 0.56, 0.66) * (0.8 + 0.4 * v);
	}
	return wall_tint * (0.95 + 0.06 * hash(vec2(floor(u * 8.0), floor(v * 8.0))));
}

vec3 terrazzo(vec2 p) {
	// The Content House: pink terrazzo with flecks and a 1 m grid.
	vec2 f = fract(p);
	float seam = step(f.x, 0.015) + step(f.y, 0.015);
	float fleck = step(0.9, hash(floor(p * 16.0)));
	vec3 c = floor_tint * (0.95 + 0.05 * hash(floor(p)));
	c = mix(c, vec3(0.97, 0.94, 0.92), fleck * 0.6);
	return mix(c, floor_tint * 0.75, clamp(seam, 0.0, 1.0));
}

vec3 content_wall(float u, float v) {
	// Pastel panels, a ring light (a glowing circle) in every other bay and a
	// Feed Magenta neon strip at the top.
	float bay = fract(u * 0.5);
	if (v > 1.0) {
		return vec3(0.91, 0.24, 0.61);
	}
	vec2 c = vec2(bay - 0.5, (v - 0.62) * 0.5);
	float r = length(c);
	bool lit = mod(floor(u * 0.5), 2.0) < 1.0;
	if (lit && r > 0.13 && r < 0.18) {
		return vec3(1.0, 0.97, 0.93);
	}
	if (v < 0.12) {
		return wall_tint * 0.72;
	}
	return wall_tint * (fract(u * 2.0) < 0.03 ? 0.88 : 1.0);
}

void fragment() {
	vec3 p = floor(world_pos * texels_per_m) / texels_per_m + 0.5 / texels_per_m;
	vec3 col;
	bool interior = style == 1 || style == 3;
	if (surface == 0) {
		if (style == 2) {
			col = paving(p.xz);
		} else if (style == 4) {
			col = boardwalk(p.xz);
		} else if (style == 5) {
			col = terrazzo(p.xz);
		} else if (style == 3) {
			col = tower_floor(p.xz);
		} else {
			col = style == 0 ? cobbles(p.xz) : carpet(p.xz);
		}
	} else if (world_normal.y > 0.5) {
		if (style == 4) {
			col = vec3(0.86, 0.5, 0.36);
		} else if (style == 5) {
			col = vec3(0.96, 0.84, 0.9);
		} else if (style == 2) {
			col = vec3(0.3, 0.33, 0.37);
		} else {
			col = style == 0 ? roof(p.xz) : vec3(0.42, 0.43, 0.45);
		}
	} else {
		float u = abs(world_normal.x) > 0.5 ? p.z : p.x;
		if (style == 4) {
			col = harbour_front(u, p.y);
		} else if (style == 5) {
			col = content_wall(u, p.y);
		} else if (style == 2) {
			col = glass_front(u, p.y);
		} else if (style == 3) {
			col = tower_wall(u, p.y);
		} else {
			col = interior ? office_wall(u, p.y) : facade(u, p.y);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
