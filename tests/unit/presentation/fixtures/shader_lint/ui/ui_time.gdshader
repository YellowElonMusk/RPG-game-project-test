// Fixture (story 051): a UI shader outside ModeHost reading TIME. Allowed.
shader_type canvas_item;

void fragment() {
	COLOR.a *= 0.5 + 0.5 * sin(TIME);
}
