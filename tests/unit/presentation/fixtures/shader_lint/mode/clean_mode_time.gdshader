// Fixture (story 051): reads mode_time only. A comment saying TIME, and an
// identifier merely containing it (TIME_SCALE), must not fail the lint.
shader_type spatial;

global uniform float mode_time;
const float TIME_SCALE = 0.5;

void fragment() {
	/* TIME in a block comment */
	ALBEDO = vec3(fract(mode_time * TIME_SCALE));
}
