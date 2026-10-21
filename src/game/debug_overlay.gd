class_name DebugOverlay
extends CanvasLayer
## Shows the player's plane state as text while the flight model is being tuned. Reads the
## simulation; never writes it.

var world: World

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(12.0, 260.0)
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible


func _process(_dt: float) -> void:
	if world == null or world.player == null or world.player.state == null:
		return
	var target := world.player
	var s := target.state
	var flags := PackedStringArray()
	if s.thrust_on:
		flags.append("THRUST")
	if s.stalled:
		flags.append("STALL")
	if s.in_spin:
		flags.append("SPIN")
	if s.on_airfield:
		flags.append("ON AIRFIELD")
	if s.upside_down:
		flags.append("ROLLED")
	if target.rearm.is_active():
		flags.append("REARMING %d%%" % int(target.rearm.progress * 100.0))
	if not target.is_alive():
		flags.append("DESTROYED")
	_label.text = (
		(
			"mass %3.0f  speed %5.1f m/s  angle %5.1f  aoa %5.1f  g %4.1f  pos %6.1f, %5.1f\n"
			% [s.mass(), s.speed, s.angle, s.angle_of_attack, s.g_load, s.position.x, s.position.y]
		)
		+ (
			"fuel %5.1f s  rounds %3d  bombs %d  hp %2d  losses %d  kills %d  enemies %d (+%s)  wingmen %d\n"
			% [
				s.fuel,
				s.rounds,
				s.bombs,
				s.hit_points,
				world.player_losses,
				world.kills,
				world.enemies_alive(),
				"any" if world.enemies_left() < 0 else str(world.enemies_left()),
				world.wingmen_alive()
			]
		)
		+ " ".join(flags)
	)
