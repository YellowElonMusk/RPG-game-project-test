// spatial_actor_xray (overworld squad, 2026-11-19)
//
// The squad's silhouette where set geometry hides it: a `next_pass` of the
// actor's own material, on the same card (`sprite_card.gdshaderinc`). It
// draws after the scene with no depth test and, per pixel, compares the
// card's depth with the opaque scene depth: where something nearer than
// the card was drawn (a wall, a roof), it paints a flat translucent
// silhouette; where the card itself is what was drawn (or nothing hid it),
// it discards, so a visible actor is never tinted.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

#include "res://src/presentation/shaders/sprite_card.gdshaderinc"

uniform sampler2D frame_tex : source_color, filter_nearest;
uniform bool flip_h = false;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
// The silhouette's colour and opacity.
uniform vec4 xray_color : source_color = vec4(0.16, 0.18, 0.32, 0.55);
// How much nearer (in reversed-Z depth) the scene must be to count as
// hiding the card: above the card's own depth jitter.
uniform float depth_bias = 0.00002;

const float ALPHA_CUTOFF = 0.5;

void fragment() {
	vec2 uv = clamp((FRAGCOORD.xy - sprite_rect.xy) / sprite_rect.zw, 0.0, 1.0);
	if (flip_h) {
		uv.x = 1.0 - uv.x;
	}
	if (texture(frame_tex, uv).a <= ALPHA_CUTOFF) {
		discard;
	}
	// Reversed-Z (Vulkan, Forward+): a larger value is nearer the camera.
	if (texture(scene_depth, SCREEN_UV).r <= FRAGCOORD.z + depth_bias) {
		discard;
	}
	ALBEDO = xray_color.rgb;
	ALPHA = xray_color.a;
}
