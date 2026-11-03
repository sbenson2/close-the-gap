extends RefCounted

# Match rules have no scene or network dependencies.
const ROUND_SECONDS: float = 150.0
const WIN_SCORE: int = 3
const KNIFE_REACH: float = 2.5
const SHOT_COOLDOWN: float = 2.2
const KNIFE_COOLDOWN: float = 0.65
const HANDGUN_COOLDOWN: float = 0.4
const HANDGUN_RANGE: float = 45.0
const HANDGUN_DAMAGE: int = 40
const HANDGUN_MAGAZINE: int = 6
const HANDGUN_RESERVE: int = 12
const RELOAD_SECONDS: float = 1.6
const CLASSIC := "classic_v1"
const DUEL := "duel_v2"
const RELAY := "relay_v1"
const RULESETS := {DUEL: "Paired duel", RELAY: "Relay infiltration", CLASSIC: "Classic / first to 3"}
const RIFLE_MAGAZINE := 3
const RIFLE_RESERVE := 9
const RIFLE_RELOAD_SECONDS := 2.8
const PEBBLES := 3
const THROW_SECONDS := 1.0
const BUILD_ID := "demo-20261102"
const ENVIRONMENTS := {"breezy": "Wind gusts", "rain": "Rain and gusts", "clear": "Calm weather"}

static func modern(ruleset: String) -> bool:
	return ruleset != CLASSIC

static func knife_damage(attacker: Vector3, victim: Vector3, facing: float, ruleset: String) -> int:
	if ruleset == CLASSIC:
		return 100
	var offset := Vector3(attacker.x - victim.x, 0, attacker.z - victim.z)
	var forward := Vector3(-sin(facing), 0, -cos(facing))
	return 100 if offset.length_squared() > 0.01 and offset.normalized().dot(forward) < -0.4 else 35

static func match_finished(index: int, points: Dictionary, ruleset: String, pairs: int = 1) -> bool:
	return index % 2 == 1 and index + 1 >= clampi(pairs, 1, 3) * 2 if modern(ruleset) else points.values().any(func(value): return int(value) >= WIN_SCORE)
const LEVELS := {"yard": "East Yard", "forest": "Pine Hollow", "mountain": "Crow's Ridge"}

static func role_for_slot(round_index: int, slot: int) -> String:
	return "stalker" if (round_index + slot) % 2 == 0 else "sniper"

static func segment_intersects_sphere(start: Vector3, end: Vector3, center: Vector3, radius: float) -> bool:
	var segment := end - start
	var length_sq := segment.length_squared()
	var fraction := clampf((center - start).dot(segment) / length_sq, 0.0, 1.0) if length_sq > 0.0001 else 0.0
	return (start + segment * fraction).distance_squared_to(center) <= radius * radius

static func weapon_allowed(role: String, weapon: String) -> bool:
	return weapon == "rifle" if role == "sniper" else weapon in ["knife", "handgun"]

static func valid_aim(aim: Vector2) -> bool:
	return aim.is_finite() and absf(aim.y) <= 1.45 and absf(aim.x) < 10000.0
