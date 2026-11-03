extends RefCounted

# Host-owned objective state. 0 intact, 1 offline, 2 permanently repaired.
var stations: Array[int] = [0, 0, 0]
var elapsed := 0.0
var deadline := 0.0
var result := ""
var revision := 0

func reset() -> void:
	stations = [0, 0, 0]
	elapsed = 0
	deadline = 0
	result = ""
	revision = 0

func change(index: int, role: String) -> bool:
	if not result.is_empty() or index < 0 or index >= 3:
		return false
	if role == "stalker" and stations[index] == 0:
		stations[index] = 1
	elif role == "sniper" and stations[index] == 1:
		stations[index] = 2
	else:
		return false
	revision += 1
	if stations.count(1) < 2:
		deadline = 0
	elif deadline <= 0:
		deadline = minf(30, maxf(0, 180 - elapsed))
	return true

func advance(delta: float) -> String:
	if not result.is_empty():
		return result
	if not is_finite(delta) or delta < 0:
		return ""
	elapsed = minf(180, elapsed + delta)
	if deadline > 0:
		deadline = maxf(0, deadline - delta)
		if deadline <= 0 and stations.count(1) >= 2:
			result = "stalker"
	if elapsed >= 180 and stations.count(1) >= 2:
		result = "stalker"
	elif elapsed >= 150 and deadline <= 0 and result.is_empty():
		result = "draw"
	return result

func snapshot() -> Array:
	return [elapsed, deadline, stations.duplicate(), result, revision]

func restore(value: Array, allow_rewind: bool = false) -> void:
	if not allow_rewind and value.size() >= 5 and int(value[4]) < revision: return
	elapsed = value[0]
	deadline = value[1]
	stations.assign(value[2])
	result = value[3]
	if value.size() >= 5: revision = int(value[4])
