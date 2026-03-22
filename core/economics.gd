# core/economics.gd
# Autoloaded as Economics
# Income and cost calculations for a season plan.
extends Node


# Returns a per-crop breakdown for the whole season.
# plan_entries: array of { crop_id, plant_day, tile }
# Returns array of dicts, one per unique crop_id planted:
# {
#   crop_id, name, tiles_planted, total_harvests,
#   seed_cost_total, gross_revenue, net_profit,
#   break_even_day,  (-1 if never profitable)
#   sell_price, seed_cost_per_tile
# }
func season_breakdown(season: String, plan_entries: Array) -> Array:
	# Aggregate per crop_id
	var by_crop: Dictionary = {}

	for entry in plan_entries:
		var crop_id: String = entry.get("crop_id", "")
		var plant_day: int = entry.get("plant_day", 1)
		var crop: Dictionary = CropsData.get_crop(crop_id)
		if crop.is_empty():
			continue

		if not by_crop.has(crop_id):
			by_crop[crop_id] = {
				"crop_id": crop_id,
				"name": crop.name,
				"sell_price": crop.sell_price,
				"seed_cost_per_tile": crop.seed_cost,
				"sellable": crop.sellable,
				"tiles_planted": 0,
				"total_harvests": 0,
				"seed_cost_total": 0,
				"gross_revenue": 0,
			}

		var harvests: int = Calculator.get_harvest_count(crop_id, plant_day)
		by_crop[crop_id]["tiles_planted"] += 1
		by_crop[crop_id]["total_harvests"] += harvests
		by_crop[crop_id]["seed_cost_total"] += crop.seed_cost
		if crop.sellable:
			by_crop[crop_id]["gross_revenue"] += harvests * crop.sell_price

	# Calculate net profit and break-even day per crop
	var result: Array = []
	for crop_id in by_crop:
		var row = by_crop[crop_id]
		row["net_profit"] = row["gross_revenue"] - row["seed_cost_total"]
		row["break_even_day"] = _break_even_day(season, crop_id, plan_entries)
		result.append(row)

	# Sort by net profit descending
	result.sort_custom(func(a, b): return a.net_profit > b.net_profit)
	return result


# Returns a daily running total of cumulative gold for the season.
# Returns dict: day -> { earned_today, cumulative_gross, cumulative_net }
func daily_gold_timeline(season: String, plan_entries: Array) -> Dictionary:
	var schedule = Calculator.build_daily_schedule(season, plan_entries)
	var seed_cost_by_day: Dictionary = {}

	for entry in plan_entries:
		var crop_id: String = entry.get("crop_id", "")
		var plant_day: int = entry.get("plant_day", 1)
		var crop: Dictionary = CropsData.get_crop(crop_id)
		if crop.is_empty():
			continue
		if not seed_cost_by_day.has(plant_day):
			seed_cost_by_day[plant_day] = 0
		seed_cost_by_day[plant_day] += crop.seed_cost

	var timeline: Dictionary = {}
	var running_gross: int = 0
	var running_costs: int = 0

	for day in range(1, Calculator.SEASON_LENGTH + 1):
		var earned: int = schedule[day].get("gold", 0)
		var spent: int = seed_cost_by_day.get(day, 0)
		running_gross += earned
		running_costs += spent
		timeline[day] = {
			"earned_today": earned,
			"spent_today": spent,
			"cumulative_gross": running_gross,
			"cumulative_costs": running_costs,
			"cumulative_net": running_gross - running_costs,
		}

	return timeline


# Returns the earliest day by which a specific crop_id covers all its seed costs.
func _break_even_day(season: String, crop_id: String, plan_entries: Array) -> int:
	var crop = CropsData.get_crop(crop_id)
	if crop.is_empty() or not crop.sellable:
		return -1

	# Total seed cost for this crop across all tiles
	var total_seed_cost: int = 0
	var harvest_days: Array = []

	for entry in plan_entries:
		if entry.get("crop_id", "") != crop_id:
			continue
		total_seed_cost += crop.seed_cost
		for h_day in Calculator.get_harvest_days(crop_id, entry.get("plant_day", 1)):
			harvest_days.append(h_day)

	harvest_days.sort()

	var running: int = 0
	for day in harvest_days:
		running += crop.sell_price
		if running >= total_seed_cost:
			return day

	return -1  # never breaks even this season


# Returns total season summary dict.
func season_summary(season: String, plan_entries: Array) -> Dictionary:
	var breakdown = season_breakdown(season, plan_entries)
	var total_seed_cost: int = 0
	var total_gross: int = 0
	var total_harvests: int = 0
	var total_tiles: int = 0
	for row in breakdown:
		total_seed_cost += row.seed_cost_total
		total_gross += row.gross_revenue
		total_harvests += row.total_harvests
		total_tiles += row.tiles_planted
	return {
		"total_tiles": total_tiles,
		"total_harvests": total_harvests,
		"total_seed_cost": total_seed_cost,
		"total_gross": total_gross,
		"total_net": total_gross - total_seed_cost,
	}
