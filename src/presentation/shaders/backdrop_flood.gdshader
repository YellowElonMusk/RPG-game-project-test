// The boss takeover's dusk flood on the painted battle backdrop (story 038;
// GDD AC-34 "the flooded sky"; ADR-0005 §7). The backdrop is a 2D painting,
// so the profile's sky gradient never reached the screen. This floods the
// painting's sky -- its bright, low-saturation pixels above the horizon --
// toward the gradient, keeping the painted cloud detail, and tints the rest
// of the set toward the dusk. `flood` is the blended profile's `sky_flood`:
// 0 draws the painting exactly as painted.
shader_type canvas_item;

uniform vec3 sky_top : source_color = vec3(0.0);
uniform vec3 sky_bottom : source_color = vec3(0.0);
uniform vec3 sky_horizon : source_color = vec3(0.0);
// The painting's horizon, as a fraction of its height from the top.
uniform float horizon_y = 0.62;
uniform float horizon_width = 0.1;
uniform float horizon_intensity = 1.0;
uniform float flood : hint_range(0.0, 1.0) = 0.0;
// How far the non-sky set is tinted toward the dusk at full flood.
uniform float set_tint : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (flood <= 0.0) {
		COLOR = tex;
	} else {
		float lum = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
		float hi = max(tex.r, max(tex.g, tex.b));
		float lo = min(tex.r, min(tex.g, tex.b));
		float sat = hi > 0.0 ? (hi - lo) / hi : 0.0;
		float above = smoothstep(horizon_y + 0.02, horizon_y - 0.10, UV.y);
		float bright = smoothstep(0.45, 0.70, lum) * (1.0 - smoothstep(0.35, 0.60, sat));
		float sky_mask = above * bright;
		vec3 grad = mix(sky_top, sky_bottom, clamp(UV.y / horizon_y, 0.0, 1.0));
		float band_d = (UV.y - (horizon_y - horizon_width * 0.5)) / max(horizon_width, 0.001);
		grad = mix(grad, sky_horizon * horizon_intensity, clamp(exp(-band_d * band_d), 0.0, 1.0));
		vec3 sky_col = grad * (0.55 + 0.7 * lum);
		vec3 set_col = tex.rgb * mix(vec3(1.0), sky_bottom * 1.8 + vec3(0.2), set_tint);
		vec3 flooded = mix(set_col, sky_col, sky_mask);
		COLOR = vec4(mix(tex.rgb, flooded, flood), tex.a);
	}
}
