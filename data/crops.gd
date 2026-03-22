# data/crops.gd
# Autoloaded as CropsData
# Source of truth: in-game library (typed manually by user, 2025-03)
extends Node

# Crop entry fields:
#   name         : display name
#   season       : "spring" | "summer" | "fall"
#   stages       : array of stage names (for display)
#   stage_days   : days spent in each stage (length = len(stages) - 1)
#   first_harvest: sum of stage_days = days from planting to first harvest
#   regrow_days  : days from harvest back to ready (0 = no regrow, harvest once)
#   seed_cost    : gold per bag (each bag = 1 tile)
#   sell_price   : gold per crop sold to Jack (shipment box)
#   shop         : where seeds are bought
#   unlock       : shipping condition to unlock (empty = always available)
#   color        : placeholder Color for grid display (swapped for sprites later)
#   sellable     : false for flowers that cannot be sold

const CROPS: Dictionary = {
	# ── SPRING ───────────────────────────────────────────────────────────────
	"turnip": {
		"name": "Turnip",
		"season": "spring",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [2, 2],
		"first_harvest": 4,
		"regrow_days": 0,
		"seed_cost": 120,
		"sell_price": 60,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.95, 0.95, 0.55),
	},
	"potato": {
		"name": "Potato",
		"season": "spring",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [3, 4],
		"first_harvest": 7,
		"regrow_days": 0,
		"seed_cost": 150,
		"sell_price": 80,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.72, 0.52, 0.30),
	},
	"cucumber": {
		"name": "Cucumber",
		"season": "spring",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [4, 3, 2],
		"first_harvest": 9,
		"regrow_days": 5,   # returns to X (3+2)
		"seed_cost": 200,
		"sell_price": 60,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.30, 0.80, 0.35),
	},
	"strawberry": {
		"name": "Strawberry",
		"season": "spring",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [3, 3, 2],
		"first_harvest": 8,
		"regrow_days": 2,   # returns to Y (2)
		"seed_cost": 150,
		"sell_price": 30,
		"shop": "supermarket",
		"unlock": "Ship 100 each: Turnip, Potato, Cucumber",
		"sellable": true,
		"color": Color(0.90, 0.20, 0.25),
	},
	"cabbage": {
		"name": "Cabbage",
		"season": "spring",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [4, 5, 5],
		"first_harvest": 14,
		"regrow_days": 0,
		"seed_cost": 500,
		"sell_price": 250,
		"shop": "won",
		"unlock": "",
		"sellable": true,
		"color": Color(0.20, 0.60, 0.25),
	},
	"moondrop_flower": {
		"name": "Moondrop Flower",
		"season": "spring",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [2, 2, 2],
		"first_harvest": 6,
		"regrow_days": 0,
		"seed_cost": 500,
		"sell_price": 0,
		"shop": "won",
		"unlock": "",
		"sellable": false,
		"color": Color(0.25, 0.45, 0.90),
	},
	"toy_flower": {
		"name": "Toy Flower",
		"season": "spring",
		"stages": ["Seeds", "X", "Y", "Z", "Ripe"],
		"stage_days": [3, 3, 3, 3],
		"first_harvest": 12,
		"regrow_days": 0,
		"seed_cost": 400,
		"sell_price": 0,
		"shop": "won",
		"unlock": "",
		"sellable": false,
		"color": Color(0.90, 0.42, 0.80),
	},

	# ── SUMMER ───────────────────────────────────────────────────────────────
	"tomato": {
		"name": "Tomato",
		"season": "summer",
		"stages": ["Seeds", "X", "Y", "Z", "Flowers"],
		"stage_days": [2, 2, 2, 3],
		"first_harvest": 9,
		"regrow_days": 3,   # returns to Z (3)
		"seed_cost": 200,
		"sell_price": 60,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.90, 0.28, 0.10),
	},
	"corn": {
		"name": "Corn",
		"season": "summer",
		"stages": ["Seeds", "X", "Y", "Z", "Flowers"],
		"stage_days": [3, 4, 4, 3],
		"first_harvest": 14,
		"regrow_days": 3,   # returns to Z (3)
		"seed_cost": 300,
		"sell_price": 100,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.95, 0.90, 0.20),
	},
	"onion": {
		"name": "Onion",
		"season": "summer",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [3, 4],
		"first_harvest": 7,
		"regrow_days": 0,
		"seed_cost": 150,
		"sell_price": 80,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.70, 0.52, 0.80),
	},
	"pineapple": {
		"name": "Pineapple",
		"season": "summer",
		"stages": ["Seeds", "X", "Y", "Z", "Flowers"],
		"stage_days": [5, 5, 5, 5],
		"first_harvest": 20,
		"regrow_days": 5,   # returns to Z (5)
		"seed_cost": 1000,
		"sell_price": 500,
		"shop": "won",
		"unlock": "",
		"sellable": true,
		"color": Color(0.80, 0.90, 0.22),
	},
	"pumpkin": {
		"name": "Pumpkin",
		"season": "summer",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [4, 5, 5],
		"first_harvest": 14,
		"regrow_days": 0,
		"seed_cost": 500,
		"sell_price": 250,
		"shop": "supermarket",
		"unlock": "Ship 100 each: Tomato, Corn, Onion",
		"sellable": true,
		"color": Color(0.90, 0.50, 0.10),
	},
	"pinkcat_flower": {
		"name": "Pinkcat Flower",
		"season": "summer",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [2, 2, 2],
		"first_harvest": 6,
		"regrow_days": 0,
		"seed_cost": 300,
		"sell_price": 0,
		"shop": "won",
		"unlock": "",
		"sellable": false,
		"color": Color(0.95, 0.52, 0.72),
	},

	# ── FALL ─────────────────────────────────────────────────────────────────
	"eggplant": {
		"name": "Eggplant",
		"season": "fall",
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [3, 3, 3],
		"first_harvest": 9,
		"regrow_days": 3,   # returns to Y (3)
		"seed_cost": 120,
		"sell_price": 80,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.38, 0.10, 0.50),
	},
	"sweet_potato": {
		"name": "Sweet Potato",
		"season": "fall",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [3, 2],
		"first_harvest": 5,
		"regrow_days": 2,   # returns to X (2)
		"seed_cost": 300,
		"sell_price": 120,
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.85, 0.45, 0.20),
		# Note: most profitable crop per in-game library
	},
	"green_pepper": {
		"name": "Green Pepper",
		"season": "fall",
		"stages": ["Seeds", "X", "Y", "Z", "Flowers"],
		"stage_days": [2, 1, 2, 2],
		"first_harvest": 7,
		"regrow_days": 2,   # returns to Z (2)
		"seed_cost": 150,
		"sell_price": 40,
		"shop": "won",
		"unlock": "",
		"sellable": true,
		"color": Color(0.22, 0.72, 0.22),
	},
	"carrot": {
		"name": "Carrot",
		"season": "fall",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [3, 4],
		"first_harvest": 7,
		"regrow_days": 0,
		"seed_cost": 300,
		"sell_price": 120,  # user confirmed 120G (guides split 60G vs 120G)
		"shop": "supermarket",
		"unlock": "",
		"sellable": true,
		"color": Color(0.95, 0.50, 0.12),
	},
	"spinach": {
		"name": "Spinach",
		"season": "fall",
		"stages": ["Seeds", "X", "Ripe"],
		"stage_days": [2, 3],
		"first_harvest": 5,
		"regrow_days": 0,
		"seed_cost": 200,
		"sell_price": 80,
		"shop": "supermarket",
		"unlock": "Ship 100 each: Eggplant, Carrot, Sweet Potato",
		"sellable": true,
		"color": Color(0.15, 0.52, 0.15),
	},
	"magic_red_flower": {
		"name": "Magic Red Flower",
		"season": "fall",
		"stages": ["Seeds", "X", "Y", "Z", "Flowers"],
		"stage_days": [3, 2, 2, 2],
		"first_harvest": 9,
		"regrow_days": 0,
		"seed_cost": 600,
		"sell_price": 200,  # red sells for 200G; blue is unsellable (random)
		"shop": "won",
		"unlock": "",
		"sellable": true,  # only the red variant
		"color": Color(0.80, 0.10, 0.12),
		# Note: color is random per bag; save/reload trick guarantees at least 1 red
	},

	# ── MULTI-SEASON ─────────────────────────────────────────────────────────
	"farm_grass": {
		"name": "Farm Grass",
		"season": "any",  # grows in spring, summer, fall
		"stages": ["Seeds", "X", "Y", "Ripe"],
		"stage_days": [3, 4, 4],
		"first_harvest": 11,
		"regrow_days": 4,   # approximate — return stage unconfirmed, guides say ~4 days
		"seed_cost": 500,
		"sell_price": 0,    # cut with sickle → grain silo, not sold directly
		"shop": "supermarket",
		"unlock": "",
		"sellable": false,
		"color": Color(0.40, 0.72, 0.20),
		# Note: does NOT need watering; safe to plant in 3x3 blocks
	},
}

# ── Helper functions ──────────────────────────────────────────────────────────

func get_season_crops(season: String) -> Dictionary:
	var result: Dictionary = {}
	for id in CROPS:
		var c = CROPS[id]
		if c.season == season or c.season == "any":
			result[id] = c
	return result


func get_crop(id: String) -> Dictionary:
	return CROPS.get(id, {})


func get_all_ids() -> Array:
	return CROPS.keys()
