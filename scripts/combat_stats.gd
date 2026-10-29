extends RefCounted
## Caractéristiques réellement employées par le combat et le briefing, selon le monde et la difficulté.
const Data = preload("res://scripts/data.gd")

static func enemy(kind: String, is_boss: bool, tier: int, difficulty: String) -> Dictionary:
	var stats := _base(kind, is_boss, tier)
	var multiplier: Dictionary = Data.DIFFICULTY[difficulty]
	stats.hp = maxi(1, roundi(stats.hp * multiplier.hp))
	stats.dmg = maxi(1, roundi(stats.dmg * multiplier.dmg))
	return stats


static func _base(k: String, is_boss: bool, tier: int) -> Dictionary:
	if is_boss:
		return {"hp": 30 + 18 * tier, "dmg": 6 + 3 * tier, "range": 6}
	match k:
		"beast":
			return {"hp": 10 + 4 * tier, "dmg": 5 + 2 * tier, "range": 1}
		"replic":
			return {"hp": 8 + 4 * tier, "dmg": 4 + 2 * tier, "range": 1}
		"swarm":
			return {"hp": 14 + 5 * tier, "dmg": 5 + 2 * tier, "range": 1}
		"kull":
			return {"hp": 20 + 6 * tier, "dmg": 6 + 2 * tier, "range": 6}
		"prisoner":
			return {"hp": 10 + 4 * tier, "dmg": 4 + 2 * tier, "range": 1}
	return {"hp": 12 + 5 * tier, "dmg": 4 + 2 * tier, "range": 6}
