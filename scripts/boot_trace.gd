extends Node
## Boot trace / crash breadcrumbs.
##
## A device crash often happens before the game draws anything, so an on-screen hint is
## useless in that run. Instead every launch writes a progress log, and the NEXT launch
## shows what the previous one managed to reach — a screenshot of that is enough to see
## which step killed it.

const LOG_PATH := "user://boot_trace.log"
const SHOW_SECONDS := 9.0

var layer: CanvasLayer
var panel: PanelContainer
var label: Label
var _prev: PackedStringArray = []
var _file: FileAccess


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev = _read_previous()
	_open_new_log()
	_build_overlay()
	mark("boot: autoload ready")
	# A swipe-up kill is a normal way to leave the app on iOS; only show the card when the
	# previous run really died without a clean exit line.
	# the crash card is no longer shown: it covered the login art with a dark panel
	if false:
		_show_previous()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _file != null:
			_file.store_line("exit: clean")
			_file.flush()

func _read_previous() -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(LOG_PATH):
		return out
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		if line != "":
			out.append(line)
	f.close()
	return out


func _open_new_log() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file != null:
		_file.store_line("--- launch %s" % Time.get_datetime_string_from_system())
		_file.flush()


## Records one step. Cheap enough to call anywhere; flushes immediately so a hard crash
## still leaves the last line on disk.
func mark(text: String) -> void:
	if _file == null:
		return
	_file.store_line(text)
	_file.flush()


func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 100
	layer.visible = false
	add_child(layer)

	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.02, 0.93)
	sb.border_color = Color(0.9, 0.35, 0.3, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(20, 20)
	layer.add_child(panel)

	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.8))
	panel.add_child(label)


func _show_previous() -> void:
	var tail := _prev
	if tail.size() > 14:
		tail = tail.slice(tail.size() - 14, tail.size())
	label.text = "PREVIOUS RUN STOPPED AT:\n" + "\n".join(tail) + "\n\n(tap to continue)"
	layer.visible = true

	# Freeze the game while the card is up: a build that dies during the Godot splash then
	# still shows the previous run's last step on the next launch, with no race.
	get_tree().paused = true
	var t := 0.0
	while t < SHOW_SECONDS:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Input.is_action_just_pressed("ui_accept"):
			break
	get_tree().paused = false
	layer.visible = false
