## Sprite-camera story 073, GDD AC-68 [C]: `CardOcclusionCheck.verdict()`
## against synthetic ID passes. A correct card (in front of the wall, behind
## the prop) passes; a card drawn behind the wall, one drawn in front of the
## prop, and fixtures that don't actually stand behind/in front of the
## sprite all fail (the check can't pass vacuously).
extends GdUnitTestSuite

const _SIZE := Vector2i(40, 40)
const _T: int = 2
## 6 x 8 texels at T = 2.
const _RECT := Rect2i(14, 10, 12, 16)


func _actor() -> Color:
	return PresentationCapture.palette()[PresentationCapture.CLASS_ACTOR]


func _set_color() -> Color:
	return PresentationCapture.palette()[PresentationCapture.CLASS_SET]


func _blank(fill: Color) -> Image:
	var img := Image.create(_SIZE.x, _SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


## The sprite alone: actor over the whole rect, floor elsewhere.
func _alone() -> Image:
	var img: Image = _blank(_set_color())
	img.fill_rect(_RECT, _actor())
	return img


## Wall behind everything above the prop; the prop over the rect's bottom
## `prop_rows` pixel rows (and a little wider than the sprite).
func _behind(prop_rows: int, wall: bool = true) -> Image:
	var img: Image = _blank(_set_color())
	if wall:
		img.fill_rect(Rect2i(4, 0, 32, _RECT.end.y), CardOcclusionCheck.WALL_COLOR)
	img.fill_rect(Rect2i(8, _RECT.end.y - prop_rows, 24, prop_rows + 2), CardOcclusionCheck.PROP_COLOR)
	return img


## The fixture pass: `behind`, with the actor drawn over the rows it wins.
func _fixture(behind: Image, actor_rows: Rect2i) -> Image:
	var img: Image = behind.duplicate() as Image
	img.fill_rect(actor_rows, _actor())
	return img


func _correct_rows(prop_rows: int) -> Rect2i:
	return Rect2i(_RECT.position, Vector2i(_RECT.size.x, _RECT.size.y - prop_rows))


func test_verdict_card_between_wall_and_prop_passes() -> void:
	var behind: Image = _behind(5)
	var v: Dictionary = CardOcclusionCheck.verdict(_alone(), _fixture(behind, _correct_rows(5)), behind, _RECT, _T)
	assert_bool(v["pass"]).override_failure_message(str(v)).is_true()
	assert_int(v["upper"]).is_equal(12 * 8)
	assert_int(v["band"]).is_equal(12 * 4)
	assert_int(v["band_behind_prop"]).is_equal(12 * 4)
	assert_int(v["upper_missing"]).is_equal(0)
	assert_int(v["band_present"]).is_equal(0)


## Negative control: the card drawn behind the wall (the wall cuts the body).
func test_verdict_card_behind_wall_fails() -> void:
	var behind: Image = _behind(5)
	var fixture: Image = behind.duplicate() as Image
	var v: Dictionary = CardOcclusionCheck.verdict(_alone(), fixture, behind, _RECT, _T)
	assert_bool(v["pass"]).is_false()
	assert_int(v["upper_missing"]).is_equal(12 * 8)


## Negative control: the card drawn in front of the prop (feet over it).
func test_verdict_card_in_front_of_prop_fails() -> void:
	var behind: Image = _behind(5)
	var v: Dictionary = CardOcclusionCheck.verdict(_alone(), _fixture(behind, _RECT), behind, _RECT, _T)
	assert_bool(v["pass"]).is_false()
	assert_int(v["band_present"]).is_equal(12 * 4)


## A prop lower than the 2-texel band leaves band pixels it does not cover:
## the fixture is invalid, so the verdict fails rather than judging less.
func test_verdict_prop_short_of_band_fails_as_invalid_fixture() -> void:
	var behind: Image = _behind(2)
	var v: Dictionary = CardOcclusionCheck.verdict(_alone(), _fixture(behind, _correct_rows(2)), behind, _RECT, _T)
	assert_bool(v["pass"]).is_false()
	assert_int(v["band_behind_prop"]).is_equal(12 * 2)


## No wall behind the sprite: nothing to occlude, so the check is vacuous.
func test_verdict_no_wall_behind_fails_as_vacuous() -> void:
	var behind: Image = _behind(5, false)
	var v: Dictionary = CardOcclusionCheck.verdict(_alone(), _fixture(behind, _correct_rows(5)), behind, _RECT, _T)
	assert_bool(v["pass"]).is_false()
	assert_int(v["upper_wall_behind"]).is_equal(0)


## No actor pixel in the rect at all: vacuous, fails.
func test_verdict_empty_sprite_fails_as_vacuous() -> void:
	var behind: Image = _behind(5)
	var v: Dictionary = CardOcclusionCheck.verdict(_blank(_set_color()), behind, behind, _RECT, _T)
	assert_bool(v["pass"]).is_false()
