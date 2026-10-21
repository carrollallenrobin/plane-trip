class_name WebTuning
## What the web build does without. The browser's GL compiles every shader program on the
## main thread, slowly, and a shadow-casting sun doubles the programs (a depth variant per
## material) and renders four shadow cascades a frame on top. So on the web the sun casts
## no shadows; on the desktop it does. Every scene with a sun asks here.


## True when running in a browser.
static func is_web() -> bool:
	return OS.has_feature("web")


## Shadows on the desktop, none on the web.
static func tune_sun(sun: DirectionalLight3D) -> void:
	if sun != null and is_web():
		sun.shadow_enabled = false
