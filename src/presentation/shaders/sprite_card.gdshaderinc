// The upright actor card's projection (ADR-0005 §2): its uniforms, helpers
// and vertex(). Shared by `sprite_actor.gdshader` and
// `sprite_actor_xray.gdshader`, so the x-ray silhouette lands on exactly the
// card's pixels. `CharacterSprite` feeds the uniforms to both materials.

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
