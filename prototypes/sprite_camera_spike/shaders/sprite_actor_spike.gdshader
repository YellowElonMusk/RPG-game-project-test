// PROTOTYPE - NOT FOR PRODUCTION
// Throwaway spike shader for story-001-windowed-engine-spike.
// Exercises ADR-0005 §2's "shader owns lighting" rule for items (12)-(14):
// ambient disabled + key-only actor lighting, manual frame texture (not
// TEXTURE/UV from the sprite), and shader-side flip mirroring.
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_disabled, ambient_light_disabled, shadows_disabled;

uniform sampler2D frame_tex : source_color, filter_nearest;
uniform bool flip_h = false;

void fragment() {
	vec2 uv = UV;
	if (flip_h) {
		uv.x = 1.0 - uv.x;
	}
	vec4 tex = texture(frame_tex, uv);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
