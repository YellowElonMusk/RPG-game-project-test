## Pure damage math from the Stats & Damage Resolution GDD
## (design/gdd/stats-damage-resolution.md), pipeline steps F3, F5 (Defending
## and Viral Stunt amount modifiers — Story 003 adds the second), F6 and F7.
##
## Stateless: every call takes its RNG as a parameter per F6 ("The RNG is
## passed in, never global, so tests seed it or stub it to return 1.0").
##
## Usage example:
## [codeblock]
## var rng := RandomNumberGenerator.new()
## rng.seed = 1
## var dmg := DamageCalculator.calculate_damage(attacker, defender, 10, rng)
## [/codeblock]
class_name DamageCalculator
extends RefCounted

const POWER_SCALE: float = 10.0       # F3
const DAMAGE_VARIANCE: float = 0.10   # F6
const DEFEND_PCT: float = -0.5        # F5: Defend halves incoming damage
const VULNERABLE_PCT: float = 0.5     # F5: Florida Man's Viral Stunt (Story 003) — +50% damage taken
const MULT_MIN: float = 0.1           # F5
const MULT_MAX: float = 3.0           # F5
const MIN_DAMAGE: int = 1             # F7
const DAMAGE_CAP: int = 999           # F7


## Resolves one hit: F3 base damage -> F5 Defend/Viral Stunt modifiers -> F6
## variance -> F7 round-half-up and clamp. Returns the final damage amount,
## always >= 1.
static func calculate_damage(attacker: Combatant, defender: Combatant,
		power: int, rng: RandomNumberGenerator) -> int:
	var attack_eff := float(maxi(1, attacker.attack))
	var defense_eff := float(maxi(0, defender.defense))
	var base: float = (float(power) / POWER_SCALE) * attack_eff * attack_eff \
			/ (attack_eff + defense_eff)  # F3

	var pct: float = 0.0  # F5
	if defender.is_defending:
		pct += DEFEND_PCT
	if defender.vulnerable_rounds_left > 0:
		pct += VULNERABLE_PCT
	var modified := maxf(0.0, base) * clampf(1.0 + pct, MULT_MIN, MULT_MAX)  # F5

	var varied: float = modified * rng.randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)  # F6

	return clampi(int(floorf(varied + 0.5)), MIN_DAMAGE, DAMAGE_CAP)  # F7
