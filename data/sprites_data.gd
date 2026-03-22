# data/sprites_data.gd
# Autoloaded as SpritesData
# Harvest Sprite data for Harvest Moon: More Friends of Mineral Town
# Source: Franck Knight guide v0.2 + in-game verification
extends Node

# All 7 Harvest Sprites with birthdays and display color.
const SPRITES: Dictionary = {
	"bold": {
		"name": "Bold",
		"color_name": "Purple",
		"birth_season": "spring",
		"birth_day": 4,
		"color": Color(0.60, 0.20, 0.80),
	},
	"staid": {
		"name": "Staid",
		"color_name": "Blue",
		"birth_season": "spring",
		"birth_day": 15,
		"color": Color(0.20, 0.40, 0.90),
	},
	"aqua": {
		"name": "Aqua",
		"color_name": "Teal/Indigo",
		"birth_season": "spring",
		"birth_day": 26,
		"color": Color(0.10, 0.70, 0.75),
	},
	"timid": {
		"name": "Timid",
		"color_name": "Green",
		"birth_season": "summer",
		"birth_day": 16,
		"color": Color(0.20, 0.72, 0.25),
	},
	"hoggy": {
		"name": "Hoggy",
		"color_name": "Yellow",
		"birth_season": "fall",
		"birth_day": 10,
		"color": Color(0.90, 0.85, 0.15),
	},
	"chef": {
		"name": "Chef",
		"color_name": "Red",
		"birth_season": "fall",
		"birth_day": 14,
		"color": Color(0.85, 0.15, 0.15),
	},
	"nappy": {
		"name": "Nappy",
		"color_name": "Orange",
		"birth_season": "winter",
		"birth_day": 22,
		"color": Color(0.95, 0.50, 0.10),
	},
}

# Contract lengths available for hire (in days).
const CONTRACT_LENGTHS: Array = [1, 3, 7]

# Minimum friendship hearts required to hire a sprite.
const MIN_HEARTS_TO_HIRE: int = 3

# Max friendship hearts.
const MAX_HEARTS: int = 10

# Best gift for sprites: Flour (wrap it for the birthday boost).
const BEST_GIFT: String = "Flour"
const BEST_GIFT_COST: int = 50  # Gold, bought at Supermarket

# Sprite hut hours.
const HUT_OPEN_NORMAL: String = "9am–6pm"
const HUT_OPEN_FESTIVAL: String = "9am–7pm"

# Days of rest required between contracts.
const REST_DAYS_AFTER_CONTRACT: int = 1

# Work starts the NEXT day after hiring.
const WORK_DELAY_DAYS: int = 1

# Baseline capacity (improves with use — user will input actual skill level).
# These are rough estimates; the real skill system is stubbed.
const BASELINE_CAPACITY: Dictionary = {
	"watering": {
		"sprites_needed": 2,
		"tiles_covered": 288,  # 12x24 garden at low skill
		"notes": "Upgrades significantly with use",
	},
	"harvesting": {
		"sprites_needed": 1,
		"notes": "More needed if all crops ready same day",
	},
	"animals": {
		"sprites_needed": 1,
		"notes": "Never assign to Makers — sprite ships raw milk/wool",
	},
}

# ── Helper functions ──────────────────────────────────────────────────────────

func get_sprite(id: String) -> Dictionary:
	return SPRITES.get(id, {})


func get_all_ids() -> Array:
	return SPRITES.keys()


# Returns sprite IDs whose birthday falls in the given season.
func get_birthdays_in_season(season: String) -> Array:
	var result: Array = []
	for id in SPRITES:
		if SPRITES[id].birth_season == season:
			result.append(id)
	return result


# Returns the sprite ID whose birthday is on a specific season+day, or "".
func get_birthday_sprite(season: String, day: int) -> String:
	for id in SPRITES:
		var s = SPRITES[id]
		if s.birth_season == season and s.birth_day == day:
			return id
	return ""


# Given hearts (0-10), returns whether this sprite can be hired.
func can_hire(hearts: int) -> bool:
	return hearts >= MIN_HEARTS_TO_HIRE
