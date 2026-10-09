extends Node
## Game time. `minutes` counts from day 1, 00:00. One game minute is `SEC_PER_MIN` real seconds.

signal hour_changed(hour: int)
signal day_changed(day: int)

const SEC_PER_MIN := 1.1
const DAY_NAMES: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

var minutes: float = 7.0 * 60.0
var running := true
var rate := 1.0  # fast-forward multiplier (sleep, work shift)


func _process(delta: float) -> void:
	if running:
		advance(delta / SEC_PER_MIN * rate)


func advance(mins: float) -> void:
	var h0 := int(minutes / 60.0)
	minutes += mins
	var h1 := int(minutes / 60.0)
	for h in range(h0 + 1, h1 + 1):
		if h % 24 == 0:
			day_changed.emit(h / 24 + 1)
		hour_changed.emit(h % 24)


func hour() -> float:
	return fmod(minutes, 1440.0) / 60.0


func day() -> int:
	return int(minutes / 1440.0) + 1


func weekday() -> int:
	return (day() - 1) % 7


func is_weekend() -> bool:
	return weekday() >= 5


## Minutes until the next time the clock reads `h` (0 if it reads it now).
func until(h: float) -> float:
	return fposmod(h - hour(), 24.0) * 60.0


## Daylight 0 (night) to 1 (day), with dawn 5:30–7:30 and dusk 18:30–20:30.
func daylight() -> float:
	var h := hour()
	if h < 5.5 or h >= 20.5:
		return 0.0
	if h < 7.5:
		return (h - 5.5) / 2.0
	if h < 18.5:
		return 1.0
	return 1.0 - (h - 18.5) / 2.0


func is_night() -> bool:
	return daylight() < 0.3


func stamp() -> String:
	var h := int(hour())
	var m := int(fmod(minutes, 60.0))
	return "%s %d:%02d %s" % [DAY_NAMES[weekday()], (h + 11) % 12 + 1, m, "AM" if h < 12 else "PM"]
