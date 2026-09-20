class_name CombatResolver
extends RefCounted

static func select_chain_targets(origin: Node3D, candidates: Array, max_jumps: int, max_distance: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for candidate in candidates:
		if result.size() >= max_jumps:
			break
		if candidate == origin or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("is_wet") or not candidate.is_wet():
			continue
		if origin.global_position.distance_to(candidate.global_position) > max_distance:
			continue
		result.append(candidate)
	return result
