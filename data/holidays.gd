# data/holidays.gd
# Autoloaded as HolidaysData
# Festival calendar for Harvest Moon: More Friends of Mineral Town
# Source: Franck Knight guide v0.2 + user verification
extends Node

# Festival types:
#   "blocking"      - 10am–6pm event, full day lost for harvesting
#   "morning_safe"  - 6pm–midnight event, morning is free for harvesting
#   "risky"         - split times (e.g. 10am–noon then 4pm–6pm), partial window
#   "unknown"       - timing/impact not yet confirmed
#
# zack_no_pickup: true on ALL festival days (Zack picks up NEXT day instead)
# sprite_hut_open: true on ALL festival days (9am–7pm instead of normal 9am–6pm)

const FESTIVALS: Dictionary = {
	"spring": [
		{
			"day": 1,
			"name": "New Year's Day",
			"type": "morning_safe",
			"time": "6pm–midnight",
			"notes": "Morning free for harvesting. Zack picks up next day.",
		},
		{
			"day": 14,
			"name": "Spring Thanksgiving",
			"type": "unknown",
			"time": "All day",
			"notes": "Boys visit your farm. Harvest window uncertain.",
		},
		{
			"day": 18,
			"name": "Spring Horse Race",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 22,
			"name": "Cooking Festival",
			"type": "risky",
			"time": "10am–noon, 4pm–6pm",
			"notes": "Partial window. Harvesting before 10am may be possible but risky.",
		},
	],
	"summer": [
		{
			"day": 1,
			"name": "Beach Opening Day",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked. Cannot buy seeds on this day either.",
		},
		{
			"day": 7,
			"name": "Chicken Festival",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 20,
			"name": "Cow Festival",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 24,
			"name": "Fireworks",
			"type": "morning_safe",
			"time": "6pm–midnight",
			"notes": "Morning free for harvesting. Zack picks up next day.",
		},
	],
	"fall": [
		{
			"day": 3,
			"name": "Music Festival",
			"type": "morning_safe",
			"time": "6pm–midnight",
			"notes": "Morning free for harvesting. Zack picks up next day.",
		},
		{
			"day": 5,
			"name": "Ann's Mom's Memorial",
			"type": "unknown",
			"time": "Unknown",
			"notes": "Minor event — impact on day unclear. Flagged for caution.",
		},
		{
			"day": 9,
			"name": "Harvest Festival",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 13,
			"name": "Festival at Mother's Hill",
			"type": "morning_safe",
			"time": "6pm–midnight",
			"notes": "Morning free for harvesting. Zack picks up next day.",
		},
		{
			"day": 18,
			"name": "Fall Horse Race",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 21,
			"name": "Sheep Festival",
			"type": "blocking",
			"time": "10am–6pm",
			"notes": "Full day blocked for harvesting.",
		},
		{
			"day": 30,
			"name": "Pumpkin Festival",
			"type": "morning_safe",
			"time": "All day (kids visit farm)",
			"notes": "Likely free — kids come to you.",
		},
	],
	"winter": [
		{
			"day": 2,
			"name": "Thomas' Winter Request",
			"type": "unknown",
			"time": "Unknown",
			"notes": "No crops in winter.",
		},
		{
			"day": 14,
			"name": "Valentine's Day",
			"type": "unknown",
			"time": "Unknown",
			"notes": "No crops in winter.",
		},
		{
			"day": 24,
			"name": "Starry Festival",
			"type": "unknown",
			"time": "Unknown",
			"notes": "No crops in winter.",
		},
		{
			"day": 25,
			"name": "Stocking Festival",
			"type": "unknown",
			"time": "Unknown",
			"notes": "No crops in winter.",
		},
		{
			"day": 30,
			"name": "New Year's Eve",
			"type": "morning_safe",
			"time": "6pm–midnight",
			"notes": "Morning free. No crops in winter.",
		},
	],
}

# ── Helper functions ──────────────────────────────────────────────────────────

# Returns festival dict for a given day/season, or empty dict if none.
func get_festival(season: String, day: int) -> Dictionary:
	var list: Array = FESTIVALS.get(season, [])
	for f in list:
		if f.day == day:
			return f
	return {}


# Returns true if any festival falls on this day.
func is_festival_day(season: String, day: int) -> bool:
	return not get_festival(season, day).is_empty()


# Returns the festival type string, or "" if no festival.
func get_festival_type(season: String, day: int) -> String:
	var f = get_festival(season, day)
	return f.get("type", "")


# Returns all festival days for a season as an array of day ints.
func get_festival_days(season: String) -> Array:
	var days: Array = []
	for f in FESTIVALS.get(season, []):
		days.append(f.day)
	return days


# Color to use for a festival type in the calendar UI.
func get_festival_color(festival_type: String) -> Color:
	match festival_type:
		"blocking":
			return Color(0.85, 0.15, 0.15, 0.70)   # red
		"morning_safe":
			return Color(0.95, 0.75, 0.10, 0.70)   # yellow
		"risky":
			return Color(0.90, 0.50, 0.10, 0.70)   # orange
		"unknown":
			return Color(0.60, 0.60, 0.60, 0.70)   # grey
	return Color.TRANSPARENT
