class_name BackdropPlan
extends RefCounted
## Where every piece of the Backdrop goes and what moves in it: trees on the back of the
## terrain slab, four layers behind the action, each at a depth with a seeded scatter of
## pieces that covers whatever the camera can see at that depth, the ground sheet they stand
## on, and the smoke and distant artillery that play out in the hills as advance() is
## called. Pure: no nodes, so the coverage and the timing are tested without a scene.
## BackdropNode renders a plan; nothing in it is part of the World (ADR 0006).

## How the pieces of a layer are scattered.
enum Scatter { SLAB, LINE, RIDGE, FIELD }

## Height of the ground sheet the layers stand on, just under the lowest terrain.
const GROUND_Y := 3.0
## How far behind the action the ground sheet reaches. Its far edge is on screen a little
## below the horizon from any camera height, and the farther it reaches the less so.
const GROUND_DEPTH := 4000.0
## How far pieces sink into the ground, so their base caps never fight the sheet.
const SINK := 1.0
## Widest screen the Backdrop is laid out for, so a wider window never shows a layer's end.
const WIDEST_ASPECT := 21.0 / 9.0
## The slab's trees stand this far behind the action, at least and at most: behind anything
## on the ground, in front of the slab's back edge.
const SLAB_DEPTH_MIN := 10.0
const SLAB_DEPTH_MAX := 36.0
## Trees keep this far from Water.
const SLAB_WATER_MARGIN := 3.0
## How far things fade toward the sky: never more than HAZE_MAX of the way, reached only
## well past HAZE_DISTANCE metres back. The sky's horizon is near white, so a full fade
## washed the whole Backdrop out.
const HAZE_MAX := 0.5
const HAZE_DISTANCE := 1800.0
## Smoke: one column per this much World width, rising from the hills.
const COLUMN_SPACING := 240.0
## Seconds between a column's puffs, and how a puff lives: rising, growing and thinning.
const PUFF_INTERVAL := 1.2
const PUFF_LIFE := 14.0
const PUFF_RISE := 2.5
const PUFF_WIND := 1.0
## How many times a puff grows over its life.
const PUFF_GROWTH := 3.0
## Most puffs there can be at once; BackdropNode draws that many instances.
const MAX_PUFFS := 96
## Smoke and flashes sit this far in front of their hill's front face, so the hill never
## hides them.
const SMOKE_LIFT := 3.0
## Distant artillery: seconds between salvoes, how long a flash lasts, how many puffs it
## leaves and how long those live.
const SALVO_MIN := 6.0
const SALVO_MAX := 20.0
const FLASH_LIFE := 0.25
const BURST_PUFFS := 4
const BURST_LIFE := 9.0
const MAX_FLASHES := 4
## Lowest cloud centre.
const CLOUD_FLOOR := 70.0
## Grid the clouds are jittered from.
const CLOUD_COLUMN := 130.0
const CLOUD_ROW := 90.0
const CLOUD_JITTER := 12.0

## The pieces by model: the variant nodes in each .glb, the width and height each is built
## at, and how far the thickest of them reaches toward the camera from its centre line,
## mirrored in the art/models/ scripts. Trees, hills and mountains stand on their origin;
## clouds are centred on it.
const PIECES := {
	"tree":
	{
		"variants": ["TreeA", "TreeB", "TreeC"],
		"sizes": [Vector2(5.2, 8.5), Vector2(7.6, 7.2), Vector2(3.2, 12.0)],
		"thickness": 4.0,
		"centred": false,
	},
	"hill":
	{
		"variants": ["HillA", "HillB"],
		"sizes": [Vector2(100.0, 25.0), Vector2(70.0, 35.0)],
		"thickness": 21.0,
		"centred": false,
	},
	"mountain":
	{
		"variants": ["MountainA", "MountainB"],
		"sizes": [Vector2(300.0, 300.0), Vector2(420.0, 230.0)],
		"thickness": 47.0,
		"centred": false,
	},
	"cloud":
	{
		"variants": ["CloudA", "CloudB"],
		"sizes": [Vector2(66.0, 30.0), Vector2(44.0, 22.0)],
		"thickness": 16.0,
		"centred": true,
	},
}

## The features: single built things with a place of their own rather than a scatter. The
## windmill stands in the Near layer with its sails turning; the factory stands clear in
## front of the hills, which reach 21 m times their scale toward the camera, with its chimney
## top, at the given offset from its origin, feeding a smoke column. Built sizes are
## mirrored in art/models/.
const FEATURES := {
	"windmill": {"size": Vector2(16.0, 24.0), "depth": 80.0 - SMOKE_LIFT, "sails": "Sails"},
	"factory": {"size": Vector2(36.0, 24.0), "depth": 250.0 - 40.0, "chimney": Vector2(14.0, 24.0)},
}
## One windmill per this much World width.
const WINDMILL_SPACING := 600.0
## How fast the sails turn, radians per second.
const SAIL_RATE := 0.8

## The layers from the action backwards: name, depth behind the action, piece and how the
## pieces are scattered. The SLAB is sparse trees on the terrain itself, each at its own
## depth; a LINE is trees at random spacing; a RIDGE overlaps each piece with the last so the
## skyline has no gaps; a FIELD is a jittered grid across the whole rect. A skyline layer is
## also made to reach the top of what the camera can see, so there is always a peak above
## the player at the Ceiling. The Far range exists to stand between the peaks of the
## Mountains and the horizon: a ground sheet ends on screen below the horizon from any
## height, and the sky's flat ground colour showed through the gaps; a ridge tall enough has
## its lowest dip above the horizon everywhere. A layer with a drift range moves: every
## piece in it drifts along x at its own speed from that range, in metres per second, and
## wraps at the layer's ends.
const LAYERS := [
	{"name": "Slab", "depth": 20.0, "piece": "tree", "scatter": Scatter.SLAB},
	{"name": "Near", "depth": 80.0, "piece": "tree", "scatter": Scatter.LINE},
	{"name": "Hills", "depth": 250.0, "piece": "hill", "scatter": Scatter.RIDGE},
	{
		"name": "Clouds",
		"depth": 400.0,
		"piece": "cloud",
		"scatter": Scatter.FIELD,
		"drift": Vector2(1.5, 4.0),
	},
	{
		"name": "Mountains",
		"depth": 700.0,
		"piece": "mountain",
		"scatter": Scatter.RIDGE,
		"skyline": true,
	},
	{
		"name": "Far",
		"depth": 1400.0,
		"piece": "mountain",
		"scatter": Scatter.RIDGE,
		"height": Vector2(1.7, 2.3),
	},
]
## How much a ridge piece is stretched in height unless its layer says otherwise.
const RIDGE_HEIGHT := Vector2(0.75, 1.25)

var layers: Array[Layer] = []
## Horizontal span of the ground sheet: wide enough for the camera at its far edge.
var ground_span := Vector2.ZERO
## Whether distant artillery plays out: on for a mission on the front line.
var front_line := true
## The windmills and the factory, placed from the seed.
var features: Array[Feature] = []
## The smoke columns rising from the hills, the factory's chimney among them.
var columns: Array[Column] = []
## Every puff of smoke in the air, columns and bursts alike, oldest first.
var puffs: Array[Puff] = []
## Artillery flashes under way.
var flashes: Array[Flash] = []
## Salvoes fired so far, for whoever wants to know.
var salvos := 0

var _rng := RandomNumberGenerator.new()
var _next_salvo := 0.0


## One placed feature: a windmill or the factory, by its key in FEATURES.
class Feature:
	var kind: String
	var position: Vector2
	var depth: float
	var scale: float
	var turned: bool


## A source of smoke: a wreck in the hills or the factory's chimney.
class Column:
	var position: Vector2
	var depth: float
	## Seconds until the next puff.
	var next_puff: float


## One puff of smoke: rises, drifts with the wind, grows and thins until it is gone.
class Puff:
	var position: Vector2
	var depth: float
	var age := 0.0
	var life: float
	## Scale when fresh; it grows PUFF_GROWTH times over its life.
	var size: float
	var rise: float

	## How much is left of it, 1 fresh to 0 gone.
	func remaining() -> float:
		return clampf(1.0 - age / life, 0.0, 1.0)

	func scale() -> float:
		return size * (1.0 + (PUFF_GROWTH - 1.0) * (1.0 - remaining()))


## The flash of a distant gun: there and gone.
class Flash:
	var position: Vector2
	var depth: float
	var age := 0.0

	func remaining() -> float:
		return clampf(1.0 - age / FLASH_LIFE, 0.0, 1.0)


## One placed piece.
class Placement:
	var variant: int
	var position: Vector2
	## Metres behind the action: the layer's depth, or its own on the slab.
	var depth: float
	var scale: Vector2
	## Turned to show its other side, for variety without mirroring.
	var turned: bool
	## Metres per second along x, for a piece that moves. Zero for one that stands.
	var drift := 0.0

	## The rectangle the piece fills, for coverage.
	func rect(piece: Dictionary) -> Rect2:
		var size: Vector2 = piece["sizes"][variant] * scale
		var corner := position - Vector2(size.x / 2.0, size.y / 2.0 if piece["centred"] else 0.0)
		return Rect2(corner, size)


## One layer: its pieces and what the camera can see there.
class Layer:
	var name: String
	var depth: float
	var piece: String
	var required: Rect2
	var placements: Array[Placement] = []
	## Union of the placed pieces.
	var extent: Rect2

	func haze() -> float:
		return BackdropPlan.haze_at(depth)


## Lay the Backdrop out for a World of the given bounds, seen by a camera camera_distance in
## front of the action that shows view_half (half width and height) of the action plane.
## The slab's trees stand on terrain; without one they stand on the ground sheet's height.
static func create(
	bounds: WorldBounds,
	camera_distance: float,
	view_half: Vector2,
	seed_value: int,
	terrain: Terrain = null,
	front_line := true
) -> BackdropPlan:
	var plan := BackdropPlan.new()
	plan.front_line = front_line
	var rng := plan._rng
	rng.seed = seed_value
	if terrain == null:
		terrain = Terrain.from_points(
			PackedVector2Array([Vector2(0.0, GROUND_Y), Vector2(bounds.width, GROUND_Y)])
		)
	for spec in LAYERS:
		var layer := Layer.new()
		layer.name = spec["name"]
		layer.depth = spec["depth"]
		layer.piece = spec["piece"]
		layer.required = required_rect(bounds, camera_distance, view_half, layer.depth)
		match spec["scatter"]:
			Scatter.SLAB:
				layer.required = required_rect(bounds, camera_distance, view_half, 0.0)
				_scatter_slab(layer, rng, terrain)
			Scatter.LINE:
				_scatter_line(layer, rng)
			Scatter.RIDGE:
				_scatter_ridge(layer, rng, spec.get("height", RIDGE_HEIGHT))
			Scatter.FIELD:
				_scatter_field(layer, rng)
		if spec.get("skyline", false):
			_raise_skyline(layer)
		if spec.has("drift"):
			for placement in layer.placements:
				placement.drift = rng.randf_range(spec["drift"].x, spec["drift"].y)
		layer.extent = _union(layer)
		plan.layers.append(layer)
	var far := required_rect(bounds, camera_distance, view_half, GROUND_DEPTH)
	plan.ground_span = Vector2(far.position.x, far.end.x)
	plan._place_features(bounds)
	plan._place_columns(bounds)
	plan._next_salvo = rng.randf_range(SALVO_MIN, SALVO_MAX)
	return plan


## Move the Backdrop on by dt seconds: the clouds drift, the columns smoke, the puffs rise
## and thin, and on the front line the guns fire now and then. A piece that has left the far
## end of what the camera can see at its layer comes back in at the other end; it never pops
## into view. Returns the placements that moved, in no particular order.
func advance(dt: float) -> Array[Placement]:
	_advance_smoke(dt)
	var moved: Array[Placement] = []
	for layer in layers:
		var piece: Dictionary = PIECES[layer.piece]
		for placement in layer.placements:
			if placement.drift == 0.0:
				continue
			var half: float = piece["sizes"][placement.variant].x * placement.scale.x / 2.0
			var left := layer.required.position.x - half
			var right := layer.required.end.x + half
			placement.position.x += placement.drift * dt
			if placement.position.x > right:
				placement.position.x -= right - left
			elif placement.position.x < left:
				placement.position.x += right - left
			moved.append(placement)
	return moved


func _advance_smoke(dt: float) -> void:
	for column in columns:
		column.next_puff -= dt
		while column.next_puff <= 0.0:
			_emit(column.position, column.depth, PUFF_LIFE, _rng.randf_range(1.5, 2.5))
			column.next_puff += PUFF_INTERVAL * _rng.randf_range(0.8, 1.2)
	for puff in puffs:
		puff.age += dt
		puff.position += Vector2(PUFF_WIND, puff.rise) * dt
	puffs = puffs.filter(func(p: Puff) -> bool: return p.age < p.life)
	for flash in flashes:
		flash.age += dt
	flashes = flashes.filter(func(f: Flash) -> bool: return f.age < FLASH_LIFE)
	if not front_line:
		return
	_next_salvo -= dt
	while _next_salvo <= 0.0:
		_fire()
		_next_salvo += _rng.randf_range(SALVO_MIN, SALVO_MAX)


## One distant gun fires: a flash on a hill or mountain, and a burst of smoke that lingers.
func _fire() -> void:
	var layer: Layer = _layer_named("Hills" if _rng.randf() < 0.6 else "Mountains")
	var at := _slope_point(layer)
	if flashes.size() < MAX_FLASHES:
		var flash := Flash.new()
		flash.position = Vector2(at.x, at.y)
		flash.depth = at.z
		flashes.append(flash)
	for i in BURST_PUFFS:
		var offset := Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(0.0, 4.0))
		_emit(Vector2(at.x, at.y) + offset, at.z, BURST_LIFE, _rng.randf_range(1.0, 2.0))
	salvos += 1


func _emit(position: Vector2, depth: float, life: float, size: float) -> void:
	if puffs.size() >= MAX_PUFFS:
		puffs.pop_front()
	var puff := Puff.new()
	puff.position = position
	puff.depth = depth
	puff.life = life
	puff.size = size
	puff.rise = PUFF_RISE * _rng.randf_range(0.8, 1.2)
	puffs.append(puff)


## The windmills along the Near layer and the one factory in front of the hills, each
## somewhere in its stretch of the World, on the ground sheet.
func _place_features(bounds: WorldBounds) -> void:
	var mills := maxi(1, ceili(bounds.width / WINDMILL_SPACING))
	for i in mills:
		var x := bounds.width * (i + _rng.randf_range(0.2, 0.8)) / mills
		features.append(_feature("windmill", x))
	features.append(_feature("factory", bounds.width * _rng.randf_range(0.1, 0.9)))


func _feature(kind: String, x: float) -> Feature:
	var feature := Feature.new()
	feature.kind = kind
	feature.position = Vector2(x, GROUND_Y - SINK)
	feature.depth = FEATURES[kind]["depth"]
	feature.scale = _rng.randf_range(0.9, 1.1)
	feature.turned = _rng.randf() < 0.5
	return feature


## The smoke columns: the factory's chimney, and wreck sites on the hills spread along the
## rest of the World.
func _place_columns(bounds: WorldBounds) -> void:
	var hills := _layer_named("Hills")
	var count := ceili(bounds.width / COLUMN_SPACING)
	for feature in features:
		if FEATURES[feature.kind].has("chimney"):
			var offset: Vector2 = FEATURES[feature.kind]["chimney"] * feature.scale
			if feature.turned:
				offset.x = -offset.x
			_add_column(feature.position + offset, feature.depth - SMOKE_LIFT)
			count -= 1
	for i in maxi(count, 0):
		var at := _slope_point(hills, Vector2(i * COLUMN_SPACING, (i + 1) * COLUMN_SPACING))
		_add_column(Vector2(at.x, at.y), at.z)


func _add_column(position: Vector2, depth: float) -> void:
	var column := Column.new()
	column.position = position
	column.depth = depth
	column.next_puff = _rng.randf_range(0.0, PUFF_INTERVAL)
	columns.append(column)


## A point on the face of one of the layer's pieces, (x, y, depth): part of the way up a
## random hill, within its silhouette, just in front of its front face. With a span, a hill
## whose centre lies in it is preferred.
func _slope_point(layer: Layer, span := Vector2(-INF, INF)) -> Vector3:
	var piece: Dictionary = PIECES[layer.piece]
	var candidates := layer.placements.filter(
		func(p: Placement) -> bool: return p.position.x >= span.x and p.position.x <= span.y
	)
	if candidates.is_empty():
		candidates = layer.placements
	var hill: Placement = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var size: Vector2 = piece["sizes"][hill.variant] * hill.scale
	var up := _rng.randf_range(0.15, 0.6)
	var dx := size.x / 2.0 * (1.0 - up) * _rng.randf_range(-0.8, 0.8)
	var front: float = hill.depth - piece["thickness"] * hill.scale.x
	return Vector3(hill.position.x + dx, hill.position.y + size.y * up, front - SMOKE_LIFT)


func _layer_named(layer_name: String) -> Layer:
	for layer in layers:
		if layer.name == layer_name:
			return layer
	return null


## The slice of a layer at depth that the camera can show: the World grown by what the
## perspective adds at that distance, with the camera clamped to the World's edges.
static func required_rect(
	bounds: WorldBounds, camera_distance: float, view_half: Vector2, depth: float
) -> Rect2:
	var half := Vector2(maxf(view_half.x, view_half.y * WIDEST_ASPECT), view_half.y)
	var grow := half * depth / camera_distance
	return Rect2(-grow.x, -grow.y, bounds.width + 2.0 * grow.x, bounds.ceiling_y + 2.0 * grow.y)


## How far a layer at depth fades toward the sky: 0 at the action, HAZE_MAX far back.
static func haze_at(depth: float) -> float:
	return HAZE_MAX * (1.0 - exp(-depth / HAZE_DISTANCE))


## Sparse trees along the terrain, each at its own depth on the back of the slab, at the
## terrain's height, never on or beside Water.
static func _scatter_slab(layer: Layer, rng: RandomNumberGenerator, terrain: Terrain) -> void:
	var piece: Dictionary = PIECES[layer.piece]
	var cursor := layer.required.position.x
	var right := cursor
	while right < layer.required.end.x:
		var p := _place(piece, rng, Vector2.ONE * rng.randf_range(0.8, 1.2))
		var width: float = piece["sizes"][p.variant].x * p.scale.x
		var x := cursor + width / 2.0
		p.position = Vector2(x, terrain.height_at(x) - SINK)
		p.depth = rng.randf_range(SLAB_DEPTH_MIN, SLAB_DEPTH_MAX)
		if not _near_water(terrain, x):
			layer.placements.append(p)
		right = cursor + width
		cursor += rng.randf_range(5.0, 16.0)


static func _near_water(terrain: Terrain, x: float) -> bool:
	return terrain.is_water_at(x - SLAB_WATER_MARGIN) or terrain.is_water_at(x + SLAB_WATER_MARGIN)


static func _scatter_line(layer: Layer, rng: RandomNumberGenerator) -> void:
	var piece: Dictionary = PIECES[layer.piece]
	var cursor := layer.required.position.x
	var right := cursor
	while right < layer.required.end.x:
		var p := _place(piece, rng, Vector2.ONE * rng.randf_range(0.8, 1.3))
		var width: float = piece["sizes"][p.variant].x * p.scale.x
		p.position = Vector2(cursor + width / 2.0, GROUND_Y - SINK)
		p.depth = layer.depth
		layer.placements.append(p)
		right = cursor + width
		cursor += rng.randf_range(2.5, 6.0)


static func _scatter_ridge(layer: Layer, rng: RandomNumberGenerator, height: Vector2) -> void:
	var piece: Dictionary = PIECES[layer.piece]
	var cursor := layer.required.position.x
	var right := cursor
	while right < layer.required.end.x:
		var p := _place(
			piece, rng, Vector2(rng.randf_range(0.8, 1.3), rng.randf_range(height.x, height.y))
		)
		var width: float = piece["sizes"][p.variant].x * p.scale.x
		p.position = Vector2(cursor + width / 2.0, GROUND_Y - SINK)
		p.depth = layer.depth
		layer.placements.append(p)
		right = cursor + width
		cursor += width * rng.randf_range(0.5, 0.75)


static func _scatter_field(layer: Layer, rng: RandomNumberGenerator) -> void:
	var piece: Dictionary = PIECES[layer.piece]
	var rect := layer.required
	var columns := ceili(rect.size.x / CLOUD_COLUMN)
	var rows := ceili((rect.end.y - CLOUD_FLOOR) / CLOUD_ROW)
	for column in columns + 1:
		for row in rows + 1:
			var p := _place(piece, rng, Vector2.ONE * rng.randf_range(0.6, 1.1))
			p.position = Vector2(
				rect.position.x + rect.size.x * column / columns,
				CLOUD_FLOOR + (rect.end.y - CLOUD_FLOOR) * row / rows
			)
			p.position += Vector2(
				rng.randf_range(-CLOUD_JITTER, CLOUD_JITTER),
				rng.randf_range(-CLOUD_JITTER, CLOUD_JITTER)
			)
			p.depth = layer.depth
			layer.placements.append(p)


## Stretch the layer's tallest piece, if need be, until it reaches the top of the required
## rect: the one peak that is always there above the player at the Ceiling.
static func _raise_skyline(layer: Layer) -> void:
	var piece: Dictionary = PIECES[layer.piece]
	var tallest: Placement = null
	var tallest_height := 0.0
	for placement in layer.placements:
		var height: float = piece["sizes"][placement.variant].y * placement.scale.y
		if height > tallest_height:
			tallest = placement
			tallest_height = height
	var needed := layer.required.end.y - tallest.position.y
	if tallest_height < needed:
		tallest.scale.y = needed / piece["sizes"][tallest.variant].y


static func _place(piece: Dictionary, rng: RandomNumberGenerator, scale: Vector2) -> Placement:
	var p := Placement.new()
	p.variant = rng.randi_range(0, piece["variants"].size() - 1)
	p.scale = scale
	p.turned = rng.randf() < 0.5
	return p


static func _union(layer: Layer) -> Rect2:
	var piece: Dictionary = PIECES[layer.piece]
	var extent := Rect2()
	for i in layer.placements.size():
		var rect := layer.placements[i].rect(piece)
		extent = rect if i == 0 else extent.merge(rect)
	return extent
