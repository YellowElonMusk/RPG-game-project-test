## Turn Battle System's EffectDescriptor type vocabulary (ADR-0001 Vocabulary
## ownership; TR-content-006; ADR-0004 §1 step 1: owning systems register
## their vocabulary before validation). Registering it is what lets a Move's
## `effects` entries of these five types load without the "not registered by
## any owning system" error `ContentCatalog._check_effect_types()` would
## otherwise raise.
##
## Usage example:
## [codeblock]
## BattleEffectTypes.register(catalog)
## [/codeblock]
class_name BattleEffectTypes
extends RefCounted

## The five migrated squad-special effect types, pinned by content-migration
## story 002 (`stun`, `heal_party`, `heal_single`, `damage_debuff`,
## `direct_damage`). **Provisional** (GDD Rule 5; QQ-02): these names may
## change once the Quirk State System is designed -- story 018 adds
## `PROVISIONAL` beside this constant.
const TURN_BATTLE: PackedStringArray = [
	"stun", "heal_party", "heal_single", "damage_debuff", "direct_damage",
]

## The same five types, named again here (story 018) as the set a Move
## record's descriptor `type` must belong to for a record marked provisional.
## **Provisional** (GDD Rule 5; QQ-02): no `provisional` field exists on the
## record class (a schema change) -- this constant is the marker instead.
const PROVISIONAL: PackedStringArray = [
	"stun", "heal_party", "heal_single", "damage_debuff", "direct_damage",
]


## Registers `TURN_BATTLE` as the `&"turn_battle"` system's effect-type
## vocabulary.
## Example: [code]BattleEffectTypes.register(catalog)[/code]
static func register(catalog: ContentCatalogService) -> void:
	catalog.register_known_effect_types(&"turn_battle", TURN_BATTLE)
