extends Control
## A speaker's portrait. Real art, when it exists, is res://art/portraits/<speaker_id>.png (or .jpg / .webp) and is
## shown as it is. Until then a placeholder stands in: a panel in a colour that is stable for the speaker, with their
## initial, so the scene screen and its layout are final before the paintings arrive.

const ART_DIR := "res://art/portraits/"
const SIZE := Vector2(132, 164)

var speaker_id := ""
var speaker_name := ""
var _texture: Texture2D = null

func _init() -> void:
	custom_minimum_size = SIZE

## Shows a speaker (empty id and name: nothing, for narration).
func show_speaker(id: String, display_name: String) -> void:
	speaker_id = id
	speaker_name = display_name
	_texture = art_for(id)
	visible = display_name != ""
	queue_redraw()

## The painted portrait for a speaker id, or null if none has been added yet.
static func art_for(id: String) -> Texture2D:
	if id == "":
		return null
	for ext in ["png", "jpg", "webp"]:
		var path := "%s%s.%s" % [ART_DIR, id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null

## A colour per speaker that never changes between runs: warm, muted, painterly.
static func tint_for(id: String) -> Color:
	var h := float(hash(id) % 360) / 360.0
	return Color.from_hsv(h, 0.32, 0.55)

func _draw() -> void:
	if speaker_name == "":
		return
	var rect := Rect2(Vector2.ZERO, SIZE)
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
		return
	var base := tint_for(speaker_id if speaker_id != "" else speaker_name)
	draw_rect(rect, base.darkened(0.35))
	# a few broad strokes, so the placeholder reads as a painting-to-come rather than a hole
	for i in 5:
		var y := 18.0 + i * 30.0
		draw_rect(Rect2(6, y, SIZE.x - 12, 18), base.lightened(0.04 * i), true)
	draw_circle(Vector2(SIZE.x / 2, 66), 34, base.lightened(0.25))
	draw_rect(Rect2(SIZE.x / 2 - 44, 104, 88, 60), base.lightened(0.15))
	var font := ThemeDB.fallback_font
	var initial := speaker_name.substr(0, 1).to_upper()
	draw_string(font, Vector2(SIZE.x / 2 - 13, 80), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, base.darkened(0.55))
	draw_rect(rect, Color(0.85, 0.75, 0.45, 0.8), false, 1.0)
