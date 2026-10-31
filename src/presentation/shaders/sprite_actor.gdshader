// spatial_actor_sprite (ADR-0005 Decision §2, Story 005)
//
// Owns every actor sprite's projection, texturing and lighting. One
// `ShaderMaterial` instance per `CharacterSprite` (a sampler can't be an
// `instance uniform`); `character_sprite.gd` re-establishes every uniform
// below every frame, because the `material_override` receives nothing from
// the sprite node on 4.7.2 (verified).
//
// vertex(): builds the pixel-exact "upright card" quad directly in clip
// space from `sprite_rect`/`viewport_size` (ADR-0005 §2's `SpriteProjection`
// output) by ray-casting each corner through the inverse projection and
// intersecting the upright plane with normal `card_normal` through the
// ground point under the ROUNDED bottom edge (story 039,
// `SpriteProjection.card_plane_point()`), not `foot_anchor` itself, so the
// card meets the floor exactly on the bottom pixel edge and no MSAA sample
// of the bottom row falls below the foot line.
// No `DEPTH` write: the card is planar, so the rasterizer's
// perspective-correct interpolation already gives exact per-pixel depth.
//
// fragment(): derives the texel UV from `FRAGCOORD` and `sprite_rect`
// (never from the mesh's own interpolated UV — required under a pitched
// camera, where perspective-correct UV interpolation on a tilted card gives
// non-uniform on-screen texels), applies the shader-flip mirror, hard
// alpha-cuts, and adds the rim on the one-texel ring just inside the
// Outline Ink outline (GDD rule 1, `edge_tx` = 1).
//
// Lighting: `ambient_light_disabled` -- actors take no environment ambient,
// ever (GDD rule 1). Only the stage's `KeyLight` (and an `actor_lighting`
// practical) reach an actor; no shadows are received or cast (actors use a
// blob shadow instead, ADR-0005 §3).
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_disabled, ambient_light_disabled, shadows_disabled;

group_uniforms projection;
// The on-screen pixel rectangle from `SpriteProjection.screen_rect()`: x, y
// (top-left, screen px, y-down) and z, w (width, height, screen px). Godot
// converts the `Rect2` `CharacterSprite` passes via `set_shader_parameter()`
// to this `vec4` layout.
uniform vec4 sprite_rect = vec4(0.0);
// `get_viewport().size`, in window pixels, matching `sprite_rect`'s space.
uniform vec2 viewport_size = vec2(1.0, 1.0);
// The foot anchor's world position. Its height sets the ground plane the
// card stands on; the card plane itself passes through the ground point
// under the rounded bottom edge (`_card_plane_point()`, story 039).
uniform vec3 foot_anchor = vec3(0.0);
// The upright card's world-space normal (camera forward, ground-projected;
// `SpriteProjection.card_normal()`). Only its direction as a plane matters
// here -- sign is resolved for lighting in fragment() via `FRONT_FACING`.
uniform vec3 card_normal = vec3(0.0, 0.0, -1.0);
group_uniforms;

group_uniforms appearance;
// The current animation frame (ADR-0005 §2: "Frame texture").
uniform sampler2D frame_tex : source_color, filter_nearest;
// Shader-flip mirroring (ADR-0005 §1). Never set true for a `no_mirror`
// animation -- `character_sprite.gd` substitutes the authored
// `<id>_<facing>_mirrored` clip instead (Story 005).
uniform bool flip_h = false;
group_uniforms;

// The stage's current blended rim values (`project.godot` Shader Globals,
// written every frame by `PresentationDirector`). Never a per-material
// uniform: every actor shares the same stage rim.
global uniform vec4 actor_rim_color : source_color;
global uniform float actor_rim_strength;

// Outline Ink, matched within a small tolerance (ADR-0005 §2, art bible):
// the rim never lands on the outline itself (GDD rule 1).
const vec3 OUTLINE_INK = vec3(26.0, 20.0, 24.0) / 255.0; // #1A1418
const float OUTLINE_TOLERANCE = 0.03;
// Hard pixel edges: actors never use alpha-to-coverage or alpha AA.
const float ALPHA_CUTOFF = 0.5;


// Ray-casts a window-pixel corner through the camera and returns the
// view-space point where that ray meets the upright card (ADR-0005 §2).
// Mirrors `SpriteProjection.card_depth()`'s construction on the CPU side.
// `inv_projection`/`view_matrix` are passed in rather than read from
// `PROJECTION_MATRIX`/`VIEW_MATRIX` directly: those built-ins are not
// visible inside a user-defined function on 4.7.2 (probed: "SHADER ERROR:
// Unknown identifier in expression: 'PROJECTION_MATRIX'" when referenced
// here directly) -- only inside `vertex()`/`fragment()` themselves.
// Below this |cosine| a ray counts as parallel to a plane.
const float PARALLEL_EPSILON = 0.0000001;

// The view-space direction of the eye ray through a window pixel.
vec3 _pixel_ray(vec2 pixel_xy, mat4 inv_projection) {
	// Probed on 4.7.2: this shader stage's NDC is y-down, matching window
	// pixels directly (no y-flip), or the quad comes out mirrored.
	vec2 ndc = (pixel_xy / viewport_size) * 2.0 - 1.0;
	// Any ray through this NDC column passes through the view-space origin
	// (the eye), so a single unprojected point (any ndc_z) gives the ray's
	// direction.
	vec4 unprojected = inv_projection * vec4(ndc, 0.0, 1.0);
	return normalize(unprojected.xyz / unprojected.w);
}


// Story 039: the view-space point the card plane passes through -- where
// the ray through the middle of the rect's rounded bottom edge meets the
// ground plane at the foot anchor's height. Mirrors
// `SpriteProjection.card_plane_point()`; falls back to the foot anchor when
// that ray never reaches the ground (at or above the horizon).
vec3 _card_plane_point(mat4 inv_projection, mat4 view_matrix) {
	vec3 view_anchor = (view_matrix * vec4(foot_anchor, 1.0)).xyz;
	vec3 view_up = normalize((view_matrix * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec2 bottom_mid = vec2(sprite_rect.x + sprite_rect.z * 0.5, sprite_rect.y + sprite_rect.w);
	vec3 ray = _pixel_ray(bottom_mid, inv_projection);
	float down = dot(ray, view_up);
	float hit_t = (down < -PARALLEL_EPSILON) ? dot(view_anchor, view_up) / down : -1.0;
	return (hit_t > 0.0) ? ray * hit_t : view_anchor;
}


vec3 _corner_view_point(vec2 pixel_xy, vec3 view_plane_point, mat4 inv_projection, mat4 view_matrix) {
	vec3 ray_dir = _pixel_ray(pixel_xy, inv_projection);
	vec3 view_normal = normalize((view_matrix * vec4(card_normal, 0.0)).xyz);

	float denom = dot(ray_dir, view_normal);
	float hit_t = (abs(denom) > PARALLEL_EPSILON) ? dot(view_plane_point, view_normal) / denom : 0.0;
	return ray_dir * hit_t;
}


void vertex() {
	// Which rect corner this vertex is: taken from the source quad's local
	// sign, never `UV` (a `SpriteFrames` built from an `AtlasTexture` hands
	// the override region's UVs, not 0..1 -- ADR-0005 §2).
	vec2 corner_sign = sign(VERTEX.xy);
	float pixel_x = sprite_rect.x + ((corner_sign.x > 0.0) ? sprite_rect.z : 0.0);
	float pixel_y = sprite_rect.y + ((corner_sign.y > 0.0) ? 0.0 : sprite_rect.w);

	mat4 inv_projection = inverse(PROJECTION_MATRIX);
	vec3 plane_point = _card_plane_point(inv_projection, VIEW_MATRIX);
	vec3 view_point = _corner_view_point(vec2(pixel_x, pixel_y), plane_point, inv_projection, VIEW_MATRIX);

	POSITION = PROJECTION_MATRIX * vec4(view_point, 1.0);
	// So omni/spot practicals (the campfire) and fog see the card, not the
	// original mesh (ADR-0005 §2). Sign is resolved in fragment().
	VERTEX = view_point;
	NORMAL = normalize((VIEW_MATRIX * vec4(card_normal, 0.0)).xyz);
}


// True when `texel` is opaque Outline Ink.
bool _is_outline_ink(vec4 texel) {
	return texel.a > ALPHA_CUTOFF && distance(texel.rgb, OUTLINE_INK) < OUTLINE_TOLERANCE;
}


// True when the texel at `uv` is Outline Ink AND at least one of ITS
// 4-neighbors is transparent -- i.e. this outline texel borders the
// silhouette's edge, not an interior ink line (GDD rule 1).
bool _outline_borders_transparency(vec2 uv, vec2 texel_step) {
	if (!_is_outline_ink(texture(frame_tex, uv))) {
		return false;
	}
	return texture(frame_tex, uv + vec2(texel_step.x, 0.0)).a <= ALPHA_CUTOFF
			|| texture(frame_tex, uv - vec2(texel_step.x, 0.0)).a <= ALPHA_CUTOFF
			|| texture(frame_tex, uv + vec2(0.0, texel_step.y)).a <= ALPHA_CUTOFF
			|| texture(frame_tex, uv - vec2(0.0, texel_step.y)).a <= ALPHA_CUTOFF;
}


void fragment() {
	// Texel UV from FRAGCOORD, not the interpolated mesh UV (ADR-0005 §2:
	// required under a pitched camera, where perspective-correct UV
	// interpolation on a tilted card gives non-uniform on-screen texels).
	vec2 local_px = FRAGCOORD.xy - sprite_rect.xy;
	vec2 uv = clamp(local_px / sprite_rect.zw, 0.0, 1.0);
	if (flip_h) {
		uv.x = 1.0 - uv.x;
	}

	vec4 tex = texture(frame_tex, uv);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = ALPHA_CUTOFF;

	// Rim: opaque, non-outline texels 4-adjacent to an Outline Ink texel
	// that borders transparency (GDD rule 1, `edge_tx` = 1 -- one texel
	// ring). TODO(godot-shader-specialist): bake this as an import-time
	// mask if the per-pixel neighbor sampling costs too much (ADR-0005 §2
	// leaves that swap in reserve for Step 1).
	if (tex.a > ALPHA_CUTOFF && !_is_outline_ink(tex)) {
		vec2 texel_step = 1.0 / vec2(textureSize(frame_tex, 0));
		bool on_rim = _outline_borders_transparency(uv + vec2(texel_step.x, 0.0), texel_step)
				|| _outline_borders_transparency(uv - vec2(texel_step.x, 0.0), texel_step)
				|| _outline_borders_transparency(uv + vec2(0.0, texel_step.y), texel_step)
				|| _outline_borders_transparency(uv - vec2(0.0, texel_step.y), texel_step);
		if (on_rim) {
			EMISSION = actor_rim_color.rgb * actor_rim_strength;
		}
	}

	// The upright card always faces the camera by construction, but
	// `cull_disabled` renders both winding orders; flip the shading normal
	// to whichever side is actually being viewed (matches the spike,
	// `prototypes/sprite_camera_spike/shaders/sprite_actor_spike.gdshader`).
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
