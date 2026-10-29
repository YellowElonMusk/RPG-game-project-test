// PROTOTYPE - NOT FOR PRODUCTION
// Throwaway spike sky card shader (ADR-0005 §3): unshaded gradient + a
// horizon band, so the battle camera's lens-shifted horizon has something
// visible to land on in screenshots.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 sky_top : source_color = vec4(0.15, 0.1, 0.3, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.6, 0.3, 0.5, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float horizon_width : hint_range(0.0, 0.5) = 0.04;

void fragment() {
	float v = UV.y; // 0 top .. 1 bottom of the card quad
	vec3 grad = mix(sky_top.rgb, sky_bottom.rgb, v);
	float band = 1.0 - smoothstep(horizon_width, horizon_width * 2.0, abs(v - 0.5));
	ALBEDO = mix(grad, horizon_color.rgb, band);
}
