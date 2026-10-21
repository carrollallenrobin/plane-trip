class_name TestLoadouts
## Loadouts built in code for the suites, mirroring the presets in data/loadouts/, so no test
## loads a resource file (CLAUDE.md: rules are tested with a World built in code).


static func bomb_rack() -> Fitting:
	return Fitting.create("Bomb Rack", 2)


static func ammunition_box() -> Fitting:
	return Fitting.create("Ammunition Box", 0, 50, 0.0, 0, 6.0)


static func fuel_tank() -> Fitting:
	return Fitting.create("Fuel Tank", 0, 0, 20.0, 0, 12.0)


static func armour_plate() -> Fitting:
	return Fitting.create("Armour Plate", 0, 0, 0.0, 8, 40.0)


## Two racks, a box and two tanks: 4 bombs, 90 rounds, 70 s, 25 hit points, one Slot free.
static func fighter() -> Loadout:
	return Loadout.of([bomb_rack(), bomb_rack(), ammunition_box(), fuel_tank(), fuel_tank()])


## A full fighter on the default airframe.
static func plane(side: int = Side.BLUE, id := 0) -> PlaneState:
	return PlaneState.create(Airframe.new(), fighter(), side, id)
