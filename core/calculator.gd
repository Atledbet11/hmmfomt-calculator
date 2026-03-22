# core/calculator.gd
# Autoloaded as Calculator
# Core harvest math — decoupled from UI.
extends Node

const SEASON_LENGTH: int = 30


# Returns an array of harvest day numbers (1–30) for a crop planted on plant_day.
# For non-regrow crops (regrow_days == 0), replanting on each harvest day is modelled:
# the crop cycles every first_harvest days from the initial plant_day.
# plant_day: the day the seed is planted (1–30)
# crop_id: key into CropsData.CROPS
# Season ends at day 30; no harvests after that are included.
func get_harvest_days(crop_id: String, plant_day: int) -> Array:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return []

	var harvests: Array = []
	var first: int = plant_day + crop.first_harvest

	if first > SEASON_LENGTH:
		return harvests  # never reaches harvest before season ends

	harvests.append(first)

	if crop.regrow_days > 0:
		# Regrow crop: subsequent harvests every regrow_days after first
		var next: int = first + crop.regrow_days
		while next <= SEASON_LENGTH:
			harvests.append(next)
			next += crop.regrow_days
	else:
		# Non-regrow crop: replant on harvest day, next harvest first_harvest days later
		var next: int = first + crop.first_harvest
		while next <= SEASON_LENGTH:
			harvests.append(next)
			next += crop.first_harvest

	return harvests


# Returns the days on which seeds must be purchased (initial plant + each replant).
# For regrow crops there is only ever one planting. For non-regrow crops, a new
# seed is needed on every harvest day except the last one of the season.
func get_planting_days(crop_id: String, plant_day: int) -> Array:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return [plant_day]

	if crop.regrow_days > 0:
		return [plant_day]  # single planting for regrow crops

	# Non-regrow: plant on initial day + every harvest day except the last
	var harvests: Array = get_harvest_days(crop_id, plant_day)
	var plant_days: Array = [plant_day]
	for idx in range(harvests.size() - 1):
		plant_days.append(harvests[idx])  # replant on harvest day (last excluded)
	return plant_days


# Total seed cost for one tile of a crop given its planting schedule.
func get_seed_cost_total(crop_id: String, plant_day: int) -> int:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return 0
	return crop.seed_cost * get_planting_days(crop_id, plant_day).size()


# Returns total number of harvests for a crop planted on plant_day.
func get_harvest_count(crop_id: String, plant_day: int) -> int:
	return get_harvest_days(crop_id, plant_day).size()


# Returns the latest plant day that still allows at least one harvest.
func last_viable_plant_day(crop_id: String) -> int:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return 0
	return SEASON_LENGTH - crop.first_harvest


# Returns the latest plant day that still yields the maximum possible harvests.
# Scans backward from day 30 to find the last day with the peak harvest count.
func latest_max_plant_day(crop_id: String) -> int:
	var max_count: int = 0
	for day in range(1, SEASON_LENGTH + 1):
		var c: int = get_harvest_count(crop_id, day)
		if c > max_count:
			max_count = c
	if max_count == 0:
		return 0
	for day in range(SEASON_LENGTH, 0, -1):
		if get_harvest_count(crop_id, day) >= max_count:
			return day
	return 1


# Given a full season plan (array of {crop_id, plant_day, tile}),
# returns a dict keyed by day (1–30) containing:
#   {
#     "harvests": [ {crop_id, tile, sell_price}, ... ],
#     "count": int,
#     "gold": int,
#     "festival": Dictionary (or empty),
#     "festival_type": String,
#   }
func build_daily_schedule(season: String, plan_entries: Array) -> Dictionary:
	var schedule: Dictionary = {}

	for day in range(1, SEASON_LENGTH + 1):
		schedule[day] = {
			"harvests": [],
			"count": 0,
			"gold": 0,
			"festival": HolidaysData.get_festival(season, day),
			"festival_type": HolidaysData.get_festival_type(season, day),
		}

	for entry in plan_entries:
		var crop_id: String = entry.get("crop_id", "")
		var plant_day: int = entry.get("plant_day", 1)
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		var crop: Dictionary = CropsData.get_crop(crop_id)
		if crop.is_empty():
			continue

		for harvest_day in get_harvest_days(crop_id, plant_day):
			var day_data = schedule[harvest_day]
			day_data["harvests"].append({
				"crop_id": crop_id,
				"tile": tile,
				"sell_price": crop.sell_price,
			})
			day_data["count"] += 1
			if crop.sellable:
				day_data["gold"] += crop.sell_price

	return schedule


# For a given season plan, returns optimal plant days per crop to maximise
# total harvests before day 30. Returns dict: crop_id -> best_plant_day.
func optimal_plant_days(season: String) -> Dictionary:
	var result: Dictionary = {}
	var season_crops = CropsData.get_season_crops(season)
	for crop_id in season_crops:
		var best_day: int = 1
		var best_count: int = 0
		for day in range(1, SEASON_LENGTH + 1):
			var count = get_harvest_count(crop_id, day)
			if count > best_count:
				best_count = count
				best_day = day
		result[crop_id] = {"plant_day": best_day, "harvest_count": best_count}
	return result


# Returns a list of harvest days that conflict with festivals, grouped by type.
# Returns array of { day, crop_id, tile, festival_type, festival_name }
func get_festival_conflicts(season: String, plan_entries: Array) -> Array:
	var conflicts: Array = []
	for entry in plan_entries:
		var crop_id: String = entry.get("crop_id", "")
		var plant_day: int = entry.get("plant_day", 1)
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		for harvest_day in get_harvest_days(crop_id, plant_day):
			var festival = HolidaysData.get_festival(season, harvest_day)
			if not festival.is_empty():
				conflicts.append({
					"day": harvest_day,
					"crop_id": crop_id,
					"tile": tile,
					"festival_type": festival.get("type", ""),
					"festival_name": festival.get("name", ""),
				})
	return conflicts
