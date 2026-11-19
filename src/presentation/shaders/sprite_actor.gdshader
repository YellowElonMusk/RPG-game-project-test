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

#include "res://src/presentation/shaders/sprite_card.gdshaderinc"

group_uniforms appearance;
// The current animation frame (ADR-0005 §2: "Frame texture").
uniform sampler2D frame_tex : source_color, filter_nearest;
// Shader-flip mirroring (ADR-0005 §1). Never set true for a `no_mirror`
// animation -- `character_sprite.gd` substitutes the authored
// `<id>_<facing>_mirrored` clip instead (Story 005).
uniform bool flip_h = false;
// The finished-boss gag (narrative bible §6.2): 0 draws the sprite as is,
// 1 a pile of purple goo. `character_sprite.gd` also squashes the card's
// rect toward the feet by the same amount.
uniform float goo : hint_range(0.0, 1.0) = 0.0;
uniform vec3 goo_color : source_color = vec3(0.69, 0.42, 0.88);
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
	ALBEDO = mix(ALBEDO, goo_color * (0.55 + 0.6 * dot(tex.rgb, vec3(0.3333))), goo);
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
