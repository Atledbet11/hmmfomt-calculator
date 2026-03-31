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


# Returns total seed cost for one crop across all throws in a season plan.
# Groups entries by (plant_day, throw_center) to count throws, not tiles.
# Falls back to treating each tile as its own throw for old entries without throw_center.
func get_throw_seed_cost_for_crop(crop_id: String, plan_entries: Array) -> int:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty():
		return 0
	var throw_keys: Dictionary = {}
	for entry in plan_entries:
		if entry.get("crop_id", "") != crop_id:
			continue
		var pd: int = entry.get("plant_day", 1)
		var tc: Vector2i = entry.get("throw_center", entry.get("tile", Vector2i(-999, -999)))
		var key: String = str(pd) + "|" + str(tc)
		if not throw_keys.has(key):
			throw_keys[key] = pd
	var total: int = 0
	for key in throw_keys:
		var pd: int = int(throw_keys[key])
		total += crop.seed_cost * get_planting_days(crop_id, pd).size()
	return total


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


# Returns which growth stage (0 = seeds, last = ripe) a crop is in on current_day.
# Returns -1 if the crop hasn't been planted yet or is finished for the season.
func get_crop_stage(crop_id: String, plant_day: int, current_day: int) -> int:
	var crop: Dictionary = CropsData.get_crop(crop_id)
	if crop.is_empty() or current_day < plant_day:
		return -1

	var stage_days: Array  = crop.get("stage_days",    []) as Array
	var first_harvest: int = int(crop.get("first_harvest", 0))
	var regrow_days: int   = int(crop.get("regrow_days",   0))
	var ripe_stage: int    = stage_days.size()  # index of the "ripe" state
	var elapsed: int       = current_day - plant_day

	# Harvest day → always show ripe regardless of cycle arithmetic
	if current_day in get_harvest_days(crop_id, plant_day):
		return ripe_stage

	if regrow_days > 0:
		# Regrow crop: grows, harvests, then cycles back through a portion of stages
		if elapsed < first_harvest:
			return _stage_from_elapsed(elapsed, stage_days)
		else:
			var cycle_pos: int   = (elapsed - first_harvest) % regrow_days
			var regrow_start: int = first_harvest - regrow_days
			return _stage_from_elapsed(regrow_start + cycle_pos, stage_days)
	else:
		# Non-regrow (replant) crop
		var harvest_days: Array = get_harvest_days(crop_id, plant_day)
		if harvest_days.is_empty():
			# Planted too late to ever harvest — show growing up to ripe-1
			return _stage_from_elapsed(min(elapsed, first_harvest - 1), stage_days)
		var last_harvest: int = int(harvest_days[harvest_days.size() - 1])
		if current_day > last_harvest:
			return -1  # done for the season
		var cycle_pos: int = elapsed % first_harvest
		return _stage_from_elapsed(cycle_pos, stage_days)


# Maps elapsed days since planting to a stage index using the stage_days array.
func _stage_from_elapsed(elapsed: int, stage_days: Array) -> int:
	var cumulative: int = 0
	for i in range(stage_days.size()):
		var d: int = int(stage_days[i])
		if elapsed < cumulative + d:
			return i
		cumulative += d
	return stage_days.size()  # at or past ripe


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
