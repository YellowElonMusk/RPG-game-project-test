// Fixture (story 051): a world shader under a mode-scene path reading TIME. The lint must fail it.
shader_type spatial;

void fragment() {
	ALBEDO = vec3(fract(TIME));
}
