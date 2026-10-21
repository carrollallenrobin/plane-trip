class_name UiTheme
## The game's one Theme, built in code from the fonts under assets/fonts (ADR 0008): a stencil
## for headings and the wordmark, a typewriter for everything on paper, and a condensed
## grotesque for the dials' small labels, where typewriter digits would smear. Every Sheet,
## the Instrument Panel and the Bands set this as their theme. Type variations, by name:
## Heading, Wordmark, Small, Dial, Band, Card, Row.

const STENCIL := preload("res://assets/fonts/AllertaStencil-Regular.ttf")
const TYPEWRITER := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const GROTESQUE := preload("res://assets/fonts/Oswald-Variable.ttf")

const BODY_SIZE := 19
const HEADING_SIZE := 44
const WORDMARK_SIZE := 132
const SMALL_SIZE := 16
const DIAL_SIZE := 13
const BAND_SIZE := 56
const BUTTON_SIZE := 21
const CARD_SIZE := 24

static var _theme: Theme


## The shared Theme, built once.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


## The grotesque at a weight; the file is a variable font.
static func grotesque(weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = GROTESQUE
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	font.variation_opentype = {tag: weight}
	return font


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = TYPEWRITER
	theme.default_font_size = BODY_SIZE
	_labels(theme)
	_buttons(theme)
	return theme


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiPalette.INK)
	theme.set_type_variation("Heading", "Label")
	theme.set_font("font", "Heading", STENCIL)
	theme.set_font_size("font_size", "Heading", HEADING_SIZE)
	theme.set_color("font_color", "Heading", UiPalette.INK)
	theme.set_type_variation("Wordmark", "Label")
	theme.set_font("font", "Wordmark", STENCIL)
	theme.set_font_size("font_size", "Wordmark", WORDMARK_SIZE)
	theme.set_color("font_color", "Wordmark", UiPalette.CREAM)
	theme.set_color("font_outline_color", "Wordmark", UiPalette.OLIVE_DARK)
	theme.set_constant("outline_size", "Wordmark", 10)
	theme.set_type_variation("Small", "Label")
	theme.set_font_size("font_size", "Small", SMALL_SIZE)
	theme.set_color("font_color", "Small", UiPalette.INK_FADED)
	theme.set_type_variation("Dial", "Label")
	theme.set_font("font", "Dial", grotesque(600))
	theme.set_font_size("font_size", "Dial", DIAL_SIZE)
	theme.set_color("font_color", "Dial", UiPalette.CREAM)
	theme.set_type_variation("Band", "Label")
	theme.set_font("font", "Band", STENCIL)
	theme.set_font_size("font_size", "Band", BAND_SIZE)
	theme.set_color("font_color", "Band", UiPalette.CREAM)


static func _buttons(theme: Theme) -> void:
	theme.set_font_size("font_size", "Button", BUTTON_SIZE)
	theme.set_color("font_color", "Button", UiPalette.INK)
	theme.set_color("font_hover_color", "Button", UiPalette.INK)
	theme.set_color("font_pressed_color", "Button", UiPalette.STAMP_RED)
	theme.set_color("font_focus_color", "Button", UiPalette.INK)
	theme.set_color("font_disabled_color", "Button", UiPalette.INK_FADED)
	theme.set_stylebox("normal", "Button", paper_box(UiPalette.CREAM_DARK, UiPalette.INK, 1))
	theme.set_stylebox("hover", "Button", paper_box(UiPalette.CREAM_SHADE, UiPalette.INK, 1))
	theme.set_stylebox("pressed", "Button", paper_box(UiPalette.KHAKI, UiPalette.INK, 1))
	theme.set_stylebox("disabled", "Button", paper_box(UiPalette.CREAM, UiPalette.INK_FADED, 1))
	theme.set_stylebox("focus", "Button", focus_box())
	# A mission's index card: wide, typed large, text at the left.
	theme.set_type_variation("Card", "Button")
	theme.set_font_size("font_size", "Card", CARD_SIZE)
	theme.set_stylebox("normal", "Card", paper_box(UiPalette.CREAM, UiPalette.INK, 1, 16))
	theme.set_stylebox("hover", "Card", paper_box(UiPalette.CREAM_DARK, UiPalette.INK, 1, 16))
	theme.set_stylebox("pressed", "Card", paper_box(UiPalette.CREAM_SHADE, UiPalette.INK, 1, 16))
	# A line of the Refit form: a ruled paper line that draws its own words.
	theme.set_type_variation("Row", "Button")
	theme.set_stylebox("normal", "Row", paper_box(UiPalette.CREAM, UiPalette.CREAM_SHADE, 1, 12))
	theme.set_stylebox(
		"hover", "Row", paper_box(UiPalette.CREAM_DARK, UiPalette.CREAM_SHADE, 1, 12)
	)
	theme.set_stylebox("pressed", "Row", paper_box(UiPalette.CREAM_DARK, UiPalette.INK, 1, 12))


## A flat paper-coloured box with an ink rule around it.
static func paper_box(fill: Color, border: Color, width: int, padding := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(padding)
	return box


## The focus marker: a heavy red rule drawn over whatever has the keys, like a grease pencil
## ring on a form.
static func focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = UiPalette.STAMP_RED
	box.set_border_width_all(3)
	box.set_corner_radius_all(2)
	box.set_expand_margin_all(3)
	return box


## A sheet of paper: cream, a hairline rule, a soft shadow as if it lay on a desk.
static func sheet_box(padding: int) -> StyleBoxFlat:
	var box := paper_box(UiPalette.CREAM, UiPalette.CREAM_SHADE, 1, padding)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	box.shadow_size = 14
	box.shadow_offset = Vector2(6.0, 9.0)
	return box
