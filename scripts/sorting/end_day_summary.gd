extends Control
## End-of-day summary — Papers Please register: cream paper, monospace,
## with a red "DAY COMPLETE" stamp. Shown when the tray is empty and all
## placed letters are correct.

signal finish_pressed

const CREAM       := Color(0.96, 0.93, 0.82, 1)
const INK         := Color(0.18, 0.14, 0.10, 1)
const WARM_GRAY   := Color(0.38, 0.32, 0.24, 1)
const STAMP_RED   := Color(0.78, 0.14, 0.12, 0.88)

var _panel: Control
var _title_label: Label
var _stats_label: RichTextLabel
var _finish_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = Control.new()
	_panel.custom_minimum_size = Vector2(460, 320)
	_panel.size = Vector2(460, 320)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_right = 230
	_panel.offset_top = -160
	_panel.offset_bottom = 160
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var paper := ColorRect.new()
	paper.color = CREAM
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(paper)

	var border := ColorRect.new()
	border.color = WARM_GRAY
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = -1
	_panel.add_child(border)
	paper.offset_left = 3
	paper.offset_right = -3
	paper.offset_top = 3
	paper.offset_bottom = -3

	_title_label = Label.new()
	_title_label.text = "DAY COMPLETE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", STAMP_RED)
	_title_label.add_theme_color_override("font_outline_color", Color(0.36, 0.06, 0.04, 0.55))
	_title_label.add_theme_constant_override("outline_size", 4)
	_title_label.size = Vector2(460, 48)
	_title_label.position = Vector2(0, 34)
	_title_label.rotation = deg_to_rad(-4.0)
	_title_label.pivot_offset = Vector2(230, 24)
	_panel.add_child(_title_label)

	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.scroll_active = false
	_stats_label.size = Vector2(420, 160)
	_stats_label.position = Vector2(20, 100)
	_stats_label.add_theme_color_override("default_color", INK)
	_stats_label.add_theme_font_size_override("normal_font_size", 18)
	_panel.add_child(_stats_label)

	_finish_button = Button.new()
	_finish_button.text = "NEXT DAY"
	_finish_button.add_theme_font_size_override("font_size", 16)
	_finish_button.add_theme_color_override("font_color", INK)
	_finish_button.size = Vector2(160, 36)
	_finish_button.position = Vector2(150, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = WARM_GRAY
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_finish_button.add_theme_stylebox_override("normal", style)
	_finish_button.pressed.connect(func(): finish_pressed.emit())
	_panel.add_child(_finish_button)


func show_for_day(day_number: int, total: int, correct_first_try: int, final_correct: int) -> void:
	var re_delivered := final_correct - correct_first_try
	var lines := [
		"  DAY %d — SORTING REPORT" % day_number,
		"",
		"  TOTAL LETTERS . . . . . . %d" % total,
		"  CORRECT ON FIRST TRY  . . %d" % correct_first_try,
		"  RE-DELIVERED AFTER FIX  . %d" % max(0, re_delivered),
		"  FINAL CORRECTNESS . . . . %d / %d" % [final_correct, total],
	]
	_stats_label.text = "[font_size=17]" + "\n".join(lines) + "[/font_size]"
	visible = true
