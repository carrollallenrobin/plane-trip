class_name Terrain
extends RefCounted
## The ground of a World as a heightfield: one surface height per horizontal position,
## no overhangs (ADR 0003). Stretches can be marked as Water, which is fatal like ground.
## Pure data and queries; the mesh is built elsewhere.

## Surface points sorted by x. Height is interpolated linearly between them and held flat
## beyond the first and last point.
var points := PackedVector2Array()
## Horizontal spans [start_x, end_x] whose surface is water.
var water_spans: Array[Vector2] = []


static func from_points(surface_points: PackedVector2Array) -> Terrain:
	var terrain := Terrain.new()
	terrain.points = surface_points.duplicate()
	terrain.points.sort()
	return terrain


func add_water(start_x: float, end_x: float) -> void:
	water_spans.append(Vector2(minf(start_x, end_x), maxf(start_x, end_x)))


func height_at(x: float) -> float:
	if points.is_empty():
		return 0.0
	if x <= points[0].x:
		return points[0].y
	var last := points[points.size() - 1]
	if x >= last.x:
		return last.y
	var i := _segment_index(x)
	var a := points[i]
	var b := points[i + 1]
	if is_equal_approx(a.x, b.x):
		return maxf(a.y, b.y)
	return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))


func is_water_at(x: float) -> bool:
	for span in water_spans:
		if x >= span.x and x <= span.y:
			return true
	return false


## True when the point is at or below the surface.
func is_below_surface(point: Vector2) -> bool:
	return point.y <= height_at(point.x)


## The highest surface within radius metres of x. The original AI looks at a terrain
## profile widened by 25 px to each side so it clears hills with margin.
func highest_within(x: float, radius: float) -> float:
	var highest := maxf(height_at(x - radius), height_at(x + radius))
	highest = maxf(highest, height_at(x))
	for p in points:
		if p.x >= x - radius and p.x <= x + radius:
			highest = maxf(highest, p.y)
	return highest


## Index of the segment [i, i + 1] containing x, by binary search.
func _segment_index(x: float) -> int:
	var low := 0
	var high := points.size() - 2
	while low < high:
		var mid := (low + high + 1) / 2
		if points[mid].x <= x:
			low = mid
		else:
			high = mid - 1
	return low
