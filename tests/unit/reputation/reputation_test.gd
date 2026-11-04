## Faction Reputation (narrative bible §6, 2026-11-04): standing, shop
## prices and the recruit aside come from street cred vs alien points. The
## save round trip is `boss_choice_test.gd`'s.
extends GdUnitTestSuite


func _ws(cred: int, alien: int) -> WorldState:
	var ws := WorldState.new()
	ws.street_cred = cred
	ws.alien_points = alien
	return ws


func _cfg() -> ReputationConfig:
	var cfg := ReputationConfig.new()
	cfg.price_step = 0.1
	cfg.price_min_multiplier = 0.7
	cfg.price_max_multiplier = 1.3
	return cfg


func test_standing_follows_the_lead() -> void:
	assert_int(Reputation.standing(_ws(0, 0))).is_equal(Reputation.Standing.EVEN)
	assert_int(Reputation.standing(_ws(2, 1))).is_equal(Reputation.Standing.HUMAN)
	assert_int(Reputation.standing(_ws(1, 2))).is_equal(Reputation.Standing.ALIEN)
	assert_int(Reputation.standing(_ws(2, 2))).is_equal(Reputation.Standing.EVEN)
	assert_int(Reputation.standing(null)).is_equal(Reputation.Standing.EVEN)


func test_street_cred_makes_prices_cheaper_and_alien_points_dearer() -> void:
	assert_float(Reputation.price_multiplier(_ws(0, 0), _cfg())).is_equal_approx(1.0, 0.0001)
	assert_float(Reputation.price_multiplier(_ws(2, 0), _cfg())).is_equal_approx(0.8, 0.0001)
	assert_float(Reputation.price_multiplier(_ws(0, 2), _cfg())).is_equal_approx(1.2, 0.0001)
	assert_int(Reputation.price_of(20, _ws(2, 0), _cfg())).is_equal(16)
	assert_int(Reputation.price_of(20, _ws(0, 2), _cfg())).is_equal(24)


func test_price_multiplier_is_clamped() -> void:
	assert_float(Reputation.price_multiplier(_ws(9, 0), _cfg())).is_equal_approx(0.7, 0.0001)
	assert_float(Reputation.price_multiplier(_ws(0, 9), _cfg())).is_equal_approx(1.3, 0.0001)


func test_a_price_never_drops_below_one_and_free_stays_free() -> void:
	assert_int(Reputation.price_of(1, _ws(9, 0), _cfg())).is_equal(1)
	assert_int(Reputation.price_of(0, _ws(0, 9), _cfg())).is_equal(0)


func test_shop_charges_the_reputation_price() -> void:
	var rec := ItemData.new()
	rec.id = "item_croissant"
	rec.price = 20
	var ws := _ws(2, 0)
	ws.money = 16
	assert_int(Shop.price(ws, rec)).is_equal(16)
	assert_int(Shop.buy(ws, rec)).is_equal(Shop.Result.OK)
	assert_int(ws.money).is_equal(0)


func test_alien_points_can_price_an_item_out_of_reach() -> void:
	var rec := ItemData.new()
	rec.id = "item_croissant"
	rec.price = 20
	var ws := _ws(0, 2)
	ws.money = 20
	assert_int(Shop.check(ws, rec)).is_equal(Shop.Result.NOT_ENOUGH_MONEY)


func test_recruit_aside_and_status_line() -> void:
	var cfg := _cfg()
	assert_str(Reputation.recruit_aside(_ws(1, 0), cfg)).is_equal(cfg.recruit_aside_human)
	assert_str(Reputation.recruit_aside(_ws(0, 1), cfg)).is_equal(cfg.recruit_aside_alien)
	assert_str(Reputation.recruit_aside(_ws(1, 1), cfg)).is_empty()
	assert_str(Reputation.status_line(_ws(2, 1))).is_equal("Street cred 2   Alien points 1")


func test_shipped_config_loads() -> void:
	var cfg: ReputationConfig = ReputationConfig.load_default()
	assert_float(cfg.price_min_multiplier).is_less(1.0)
	assert_float(cfg.price_max_multiplier).is_greater(1.0)
