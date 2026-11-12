extends Node
## First scene of the app. It puts the game's own loading screen up straight away (the same
## picture, "加载中..." and progress bar every run's loading uses), loads the game once that
## screen is showing (on the main thread: a background-thread load made parts of the game
## touch the scene tree from the wrong thread), then hands over to main, which builds and prepares everything
## else while this screen keeps the bar moving. Nothing heavy happens on a screen the player
## can see: the street, the lobby, the shop, the zombies, the vehicles and their lamps are
## all ready before this screen fades out.

const MAIN := "res://scenes/main.tscn"
const ARTS := ["res://assets/ui/loading/loading_1_corn.png", "res://assets/ui/loading/loading_2_snowroad.png",
	"res://assets/ui/loading/loading_3_graveyard.png", "res://assets/ui/loading/loading_4_city.png"]
const INK := Color(0.023529412, 0.047058824, 0.043137256, 1.0)
const LOAD_SHARE := 0.25          # the bar's first quarter is reading the game files

var layer: CanvasLayer
var canvas: Control
var art: Texture2D
var font: Font
var zh := true
var shown := 0.0
var target := 0.0
var elapsed := 0.0
var handed_over := false
var finishing := false
var fade := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var cfg := ConfigFile.new()
	var lang := OS.get_locale()
	if cfg.load("user://deadfrontier.cfg") == OK: lang = String(cfg.get_value("ui", "language", lang))
	zh = lang.begins_with("zh")
	var rng := RandomNumberGenerator.new(); rng.randomize()
	art = load(ARTS[rng.randi_range(0, ARTS.size() - 1)])
	font = load("res://scripts/run_text.gd").font()
	layer = CanvasLayer.new(); layer.layer = 120; add_child(layer)
	canvas = Control.new(); canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP   # taps cannot reach the game underneath
	canvas.draw.connect(_paint)
	layer.add_child(canvas)

var frames_shown := 0


func _process(delta: float) -> void:
	elapsed += delta
	if not handed_over:
		frames_shown += 1
		if frames_shown >= 3:   # the loading picture is on screen before the long read starts
			handed_over = true
			var packed := load(MAIN) as PackedScene
			if packed == null:
				get_tree().change_scene_to_file(MAIN); queue_free(); return
			var main: Node = packed.instantiate()
			main.set("boot_screen", self)
			get_tree().root.add_child(main)
			get_tree().current_scene = main
			target = LOAD_SHARE
	# the bar glides towards the real figure instead of jumping
	shown = minf(target, shown + maxf(0.35, (target - shown) * 4.0) * delta)
	if finishing and shown >= 0.999:
		fade -= delta * 4.0
		if fade <= 0.0:
			queue_free()
			return
	canvas.queue_redraw()


## Called by main as it gets through its own preparation (0..1).
func set_progress(p: float) -> void:
	target = maxf(target, LOAD_SHARE + (1.0 - LOAD_SHARE) * clampf(p, 0.0, 1.0))

func finish() -> void:
	target = 1.0
	finishing = true


func _paint() -> void:
	var size := canvas.size
	var a := clampf(fade, 0.0, 1.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(INK, a))
	if art != null:
		var tw := float(art.get_width()); var th := float(art.get_height())
		var k := minf(size.x / tw, size.y / th)
		var sz := Vector2(tw * k, th * k)
		canvas.draw_texture_rect(art, Rect2((size - sz) * 0.5, sz), false, Color(1, 1, 1, a))
	var sx := size.x / 540.0; var sy := size.y / 960.0
	var dots := "..." if int(elapsed * 2.0) % 4 < 3 else "."
	var label := ("加载中%s" % dots) if zh else ("LOADING%s" % dots)
	_center(label, Vector2(270 * sx, 868 * sy), 22, a)
	var bar := Rect2(108 * sx, 884 * sy, 324 * sx, 10 * sy)
	canvas.draw_rect(bar, Color(1, 1, 1, 0.22 * a))
	canvas.draw_rect(bar, Color(1, 1, 1, 0.6 * a), false, 1.0)
	canvas.draw_rect(Rect2(bar.position, Vector2(maxf(1.0, bar.size.x * shown), bar.size.y)), Color(1.0, 0.3137, 0.1882, a))
	_center("%d%%" % int(shown * 100.0), Vector2(270 * sx, 914 * sy), 13, a)

func _center(text: String, at: Vector2, size: int, a: float) -> void:
	if font == null: return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string_outline(font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.7 * a))
	canvas.draw_string(font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, a))
