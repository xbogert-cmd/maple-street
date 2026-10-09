class_name Rules
## The game's judgement calls as plain functions, so they can be tested without a scene.

const HEAT_INVESTIGATOR := 35.0
const HEAT_SEARCH := 65.0


## What a witness makes of the player right now. `ctx` has zone, family, act, night, hour.
## Returns {} for nothing wrong, else {kind, amount, text, severe}.
static func judge(ctx: Dictionary) -> Dictionary:
	var fam: String = ctx.get("family", "")
	var zone: String = ctx.get("zone", "street")
	var night: bool = ctx.get("night", false)
	var hour: float = ctx.get("hour", 12.0)
	match ctx.get("act", ""):
		"carry_body":
			return _j("body", 100.0, "saw you carrying a body", true)
		"attack":
			return _j("attack", 100.0, "saw you attack someone", true)
		"lock":
			if zone != "home":
				return _j("lock", 45.0, "saw you working at the %s door" % fam, true)
		"window":
			if zone != "home":
				return _j("window", 50.0, "saw you climbing through the %s window" % fam, true)
		"snoop":
			if zone != "home":
				return _j("snoop", 10.0, "saw you going through the %s %s" % [fam, ctx.get("what", "things")], false)
	if ctx.get("invited", false):
		return {}
	match zone:
		"inside":
			return _j("inside", 70.0, "saw you inside the %s house" % fam, true)
		"yard":
			if night:
				return _j("yard_night", 22.0, "saw you in the %s yard after dark" % fam, false)
			return _j("yard_day", 8.0, "saw you poking around the %s yard" % fam, false)
		"front":
			if hour >= 22.5 or hour < 5.0:
				return _j("porch_night", 6.0, "saw you at the %s porch late at night" % fam, false)
		"street", "park", "west":
			if hour >= 0.5 and hour < 4.5:
				return _j("late_walk", 3.0, "saw you out walking in the small hours", false)
	return {}


static func _j(kind: String, amount: float, text: String, severe: bool) -> Dictionary:
	return {"kind": kind, "amount": amount, "text": text, "severe": severe}


## Street-wide heat from every neighbour's suspicion plus unsolved incidents.
static func heat(suspicions: Array[float], incident: float) -> float:
	var s := suspicions.duplicate()
	s.sort()
	s.reverse()
	var top := 0.0
	var n := mini(4, s.size())
	for i in n:
		top += s[i]
	return clampf((top / maxf(1.0, n)) * 0.7 + incident, 0.0, 100.0)


## How far a neighbour can make the player out.
static func sight_range(light: float, sneaking: bool) -> float:
	return lerpf(6.0, 24.0, clampf(light, 0.0, 1.0)) * (0.7 if sneaking else 1.0)


## Chance a house search turns up something kept in `place`.
static func find_chance(place: String) -> float:
	match place:
		"stash":
			return 0.25
		"floor_safe":
			return 0.08
	return 1.0   # pockets, drawers, the fridge


## Share of suspicion that spreads to a next-door neighbour overnight.
static func gossip(amount: float) -> float:
	return maxf(0.0, amount - 20.0) * 0.2


## Which contraband a house search turns up. `items` are {name, place}; `rolls` are 0..1 per item.
static func search_finds(items: Array, rolls: Array) -> Array[String]:
	var found: Array[String] = []
	for i in items.size():
		if float(rolls[i]) < find_chance(items[i].place):
			found.append(items[i].name)
	return found
