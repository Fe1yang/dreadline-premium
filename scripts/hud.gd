extends Control
const ModelFix := preload("res://scripts/model_fix.gd")

const ExtraText=preload("res://scripts/extra_text.gd")
const RunText=preload("res://scripts/run_text.gd")
const ShopText=preload("res://scripts/shop_text.gd")
const Localization=preload("res://scripts/localization.gd")
const GameText=preload("res://scripts/game_text.gd")
const StoreCatalog=preload("res://scripts/store_catalog.gd")
const ProgressCatalog=preload("res://scripts/progress_catalog.gd")
const INK=Color("0b0e0f")
const HEART=Color("a3201f")
const GrungeShader=preload("res://shaders/ui_grunge.gdshader")
const PANEL=Color("15191a")
const WHITE=Color("f6f6f3")
const MUTED=Color("b3b8b6")
const LINE=Color("4b5050")
const RED=Color("b6383e")
const GOLD=Color("d8b56c")
const ARMOR=Color("83b4c0")
# Dead Island palette: charcoal plates, blood red kept for section splashes and the ONE main
# action per screen, aged brass for anything that costs money or plays an ad.
const BRASS:=Color("a8863c")          # aged brass (ad buttons, purchase frames)
const BRASS_LIGHT:=Color("e0bd72")    # brass lettering on dark plates
const BRASS_INK:=Color("1c1508")      # dark text on brass
const PLATE:=Color(0.075,0.08,0.082,0.90)   # standard flat panel
const PLATE_DIM:=Color(0.05,0.055,0.058,0.86)

var game: Node
var font: Font
var bold: Font
var portraits: Array[Texture2D]=[]
var pet_portraits: Array[Texture2D]=[]
var coin_tex: Texture2D
var silver_tex: Texture2D
var can_tex: Texture2D
var airdrop_tex: Texture2D
var voucher_tex: Texture2D
var pack_art:={}
var glow_tex: GradientTexture2D
var hud_portraits: Array[Texture2D]=[]
var skin_portraits: Array[Texture2D]=[]
var menu_art: Texture2D
var loading_art: Array[Texture2D] = []
# Small print and photos are drawn on a child layer without the worn-paint shader so they stay legible.
const CLEAN_TEXT_BELOW:=28 # Latin text smaller than this stays clean
const CLEAN_CJK_BELOW:=44 # dense CJK glyphs need to be much larger before wear is readable
var clean: Control
var clean_ops: Array=[]
## Scrolling lists (store) draw into their own clipped layer under the clean layer, so rows are
## cut off cleanly at the list edges while the dimmed scene still shows behind the header.
var list_clip: Control
var list_ops: Array=[]
var grunge_tex: Texture2D
# Hand-painted brush strokes used for every panel and button (assets/ui/brush_*.png, white
# alpha masks tinted at draw time) instead of thin outlined boxes.
var brush_button: Array[Texture2D]=[]
var brush_panel: Array[Texture2D]=[]
var brush_line: Array[Texture2D]=[]
const PAINT_RED:=Color("a8201c")
const PAINT_DARK:=Color(0.055,0.06,0.062,0.94)
var cjk: SystemFont
var cjk_black: FontFile
var bold_base: FontFile
var cjk_language:=""
const CJK_FONTS:={
	"zh_CN":["Microsoft YaHei","PingFang SC","Noto Sans CJK SC","Source Han Sans SC","Noto Sans SC"],
	"zh_TW":["Microsoft JhengHei","PingFang TC","Noto Sans CJK TC","Source Han Sans TC","Noto Sans TC"],
	"ja":["Yu Gothic UI","Hiragino Sans","Noto Sans CJK JP","Meiryo","Noto Sans JP"],
	"ko":["Malgun Gothic","Apple SD Gothic Neo","Noto Sans CJK KR","Noto Sans KR"]}

func _update_cjk_font() -> void:
	var code: String=game.language_code if game!=null else "zh_CN"
	if code==cjk_language or cjk==null: return
	cjk_language=code
	cjk.font_names=PackedStringArray(CJK_FONTS.get(code,CJK_FONTS["zh_CN"]))
	# The bundled heavy face has Simplified glyph shapes, so only Simplified Chinese uses it.
	if bold_base and cjk_black: bold_base.fallbacks=[cjk_black,cjk,font.fallbacks[-1]] if code=="zh_CN" else [cjk,font.fallbacks[-1]]

func _ready() -> void:
	var system:=SystemFont.new()
	system.font_names=PackedStringArray(["Noto Sans","Segoe UI","Arial"])
	system.allow_system_fallback=true
	# Condensed poster lettering for all UI text. Han characters go to a CJK font picked for the
	# current language first, so Simplified Chinese never borrows Japanese or Traditional glyph shapes.
	cjk=SystemFont.new(); cjk.allow_system_fallback=true
	var display:=load("res://assets/fonts/hud_condensed_bold.otf") as FontFile
	display.fallbacks=[cjk,system]
	font=display
	# Headings and buttons: separate copy whose Chinese falls back to a heavy poster-weight face
	# (Noto Sans CJK SC Black, bundled) instead of the thin system font.
	bold_base=display.duplicate() as FontFile
	cjk_black=load("res://assets/fonts/hud_cjk_black.otf") as FontFile
	bold_base.fallbacks=[cjk_black,cjk,system]
	# Regular-weight CJK used to rely on SystemFont family names ("Microsoft YaHei" etc.).
	# None of those resolve on iOS, so every non-bold Chinese label drew nothing -- that is
	# why the pause menu showed empty buttons while the bold "resume" label was fine.
	# Keep the bundled CJK face in the chain so it can never fall through to nothing.
	display.fallbacks=[cjk_black,cjk,system]
	var heavy:=FontVariation.new(); heavy.base_font=bold_base; heavy.variation_embolden=0.35; bold=heavy
	# Worn paint look on every bright stroke (see shaders/ui_grunge.gdshader).
	var grunge:=ShaderMaterial.new(); grunge.shader=GrungeShader
	grunge.set_shader_parameter("grunge",load("res://assets/ui/ui_grunge.png"))
	material=grunge
	list_clip=Control.new(); list_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE; list_clip.clip_contents=true
	add_child(list_clip); list_clip.draw.connect(_draw_list)
	grunge_tex=load("res://assets/ui/ui_grunge.png")
	clean=Control.new(); clean.mouse_filter=Control.MOUSE_FILTER_IGNORE
	clean.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(clean); clean.draw.connect(_draw_clean)
	portraits=[load("res://assets/ui/male_hd_portrait.png"),load("res://assets/ui/riley_hd_portrait.png"),load("res://assets/ui/medic_hd_portrait.png"),load("res://assets/ui/maya_hd_portrait.png")]
	# Built from the pet table so adding a breed cannot leave the portraits one slot behind.
	pet_portraits=[]
	for _p in preload("res://scripts/lobby_scene_3d.gd").PETS:
		var _file: String = String(_p.asset).get_file().get_basename()
		var _path: String = "res://assets/ui/pets/%s.png" % _file
		pet_portraits.append(load(_path) if ResourceLoader.exists(_path) else null)
	airdrop_tex=load("res://assets/ui/airdrop.png") if ResourceLoader.exists("res://assets/ui/airdrop.png") else null
	can_tex=load("res://assets/ui/currency/can.png")
	coin_tex=load("res://assets/ui/currency/coin.png"); voucher_tex=load("res://assets/ui/currency/voucher.png")
	silver_tex=load("res://assets/ui/currency/silver_coin.png") if ResourceLoader.exists("res://assets/ui/currency/silver_coin.png") else coin_tex
	for p in StoreCatalog.PACKS+StoreCatalog.OFFERS:
		var path: String="res://assets/ui/store/%s.png"%p.id
		pack_art[p.id]=load(path) if ResourceLoader.exists(path) else null
	var grad:=Gradient.new(); grad.set_color(0,Color(1,1,1,1)); grad.set_color(1,Color(1,1,1,0)); grad.add_point(0.45,Color(1,1,1,0.45))
	glow_tex=GradientTexture2D.new(); glow_tex.gradient=grad; glow_tex.fill=GradientTexture2D.FILL_RADIAL; glow_tex.fill_from=Vector2(0.5,0.5); glow_tex.fill_to=Vector2(1.0,0.5); glow_tex.width=128; glow_tex.height=128
	hud_portraits=[load("res://assets/ui/male_hud_gray.png"),load("res://assets/ui/riley_hud_gray.png"),load("res://assets/ui/medic_hud_gray.png"),load("res://assets/ui/maya_hud_gray.png")]
	menu_art=load("res://assets/ui/title_screen.png")
	loading_art=[load("res://assets/ui/loading/loading_1_corn.png"),load("res://assets/ui/loading/loading_2_snowroad.png"),load("res://assets/ui/loading/loading_3_graveyard.png"),load("res://assets/ui/loading/loading_4_city.png")]
	for i in range(3):
		brush_button.append(load("res://assets/ui/brush_button_%d.png"%i))
		brush_panel.append(load("res://assets/ui/brush_panel_%d.png"%i))
		brush_line.append(load("res://assets/ui/brush_line_%d.png"%i))

## Store / lobby card art, loaded on demand.
## pack_art is filled once at HUD start; a card PNG whose import landed after that stays
## null forever, so re-check the path here and cache the hit.
func _store_art(id: String) -> Texture2D:
	var t: Texture2D=pack_art.get(id)
	if t==null:
		var path: String="res://assets/ui/store/%s.png"%id
		if ResourceLoader.exists(path):
			t=load(path)
			if t!=null: pack_art[id]=t
	return t

func _process(_delta: float) -> void:
	_update_cjk_font()
	# The main menu now draws its own HUD lettering (title + buttons), so the worn-paint
	# shader stays on in every state — except the cover: the title poster is finished art
	# and the wear shader tears holes into its bright lettering and sky.
	if material: (material as ShaderMaterial).set_shader_parameter("strength",0.0 if game.state in ["cover","loading","terms"] else 1.0)
	queue_redraw()

func _draw() -> void:
	_draw_missing_assets()
	clean_ops.clear(); list_ops.clear()
	if game==null or font==null: return
	if game.state in ["playing","paused","health_ad"]:
		_draw_hud()
	elif game.state=="intro": _draw_intro()
	elif game.state=="cover": _draw_cover()
	elif game.state=="loading": _draw_loading()
	elif game.state=="terms": _draw_terms()
	elif game.state=="gameover": _draw_hud(); clean_ops.clear(); _draw_gameover()
	elif game.state=="shop": _draw_shop()
	elif game.state=="armory": _draw_armory()
	elif game.state=="lootbox": _draw_lootbox()
	elif game.state=="map": _draw_map()
	elif game.state=="language": _draw_languages()
	elif game.state=="settings": _draw_settings()
	elif game.state=="controls": _draw_controls()
	elif game.state=="store": _draw_store()
	elif game.state=="offer":
		match game.offer_return_state:
			"store": _draw_store()
			"shop": _draw_shop()
			_: _draw_character_select()
		_draw_offer_popup()
	elif game.state=="resource_pack":
		_draw_resource_pack_background()
		_draw_resource_pack_popup()
	elif game.state=="payfail":
		match game.payfail_return_state:
			"store": _draw_store()
			"offer":
				if game.offer_return_state=="store": _draw_store()
				else: _draw_character_select()
				_draw_offer_popup()
			"resource_pack":
				_draw_resource_pack_background()
				_draw_resource_pack_popup()
			_: _draw_character_select()
		_draw_payfail()
	elif game.state=="signin":
		_draw_character_select(); _draw_signin()
	elif game.state=="tasks": _draw_tasks()
	elif game.state=="mail": _draw_mail()
	elif game.state=="bag": _draw_bag()
	elif game.state=="airdrop": _draw_airdrop()
	elif game.state=="character_select": _draw_character_select()
	if game.state=="paused": clean_ops.clear(); _draw_pause() # HUD small print sits under the overlay
	if game.state=="health_ad": clean_ops.clear(); _draw_hud(); _draw_health_ad_prompt() # frozen run behind the offer
	if game.damage_flash>0: draw_rect(Rect2(0,0,540,game.ui_h),Color(0.65,0.025,0.025,game.damage_flash*0.36))
	draw_rect(Rect2(0,0,540,2),Color(0.45,0.04,0.055,0.65))
	_debug_fps()
	if clean: clean.queue_redraw()
	if list_clip: list_clip.queue_redraw()

func _draw_clean() -> void:
	_replay(clean,clean_ops,Vector2.ZERO)

func _draw_list() -> void:
	_replay(list_clip,list_ops,-list_clip.position)

## Draws recorded ops onto a layer. "xf" sets a rotation/offset for what follows (tilted tags).
func _replay(target: Control,ops: Array,offset: Vector2) -> void:
	target.draw_set_transform(offset,0.0,Vector2.ONE)
	for op in ops:
		match op[0]:
			"text": target.draw_string(op[1],op[2],op[3],HORIZONTAL_ALIGNMENT_LEFT,-1,op[4],op[5])
			"texture": target.draw_texture_rect(op[1],op[2],false)
			"region": target.draw_texture_rect_region(op[1],op[2],op[3])
			"tinted": target.draw_texture_rect(op[1],op[2],false,op[3])
			"tiled": target.draw_texture_rect(op[1],op[2],true,op[3])
			"box": target.draw_style_box(op[1],op[2])
			"poly": target.draw_colored_polygon(op[1],op[2])
			"line": target.draw_polyline(op[1],op[2],op[3],true)
			"xf": target.draw_set_transform(offset+op[1],op[2],Vector2.ONE)
			"xf0": target.draw_set_transform(offset,0.0,Vector2.ONE)
			"grad": target.draw_polygon(op[1],op[2])

## Player text-size setting (small / medium / large). Small print is scaled most, since that is
## what is hard to read; big headlines barely change so layouts still fit.
func _scaled(size: int) -> int:
	var choice: int=game.text_size if game!=null else 1
	var factor: float=[0.9,1.0,1.25][choice]
	if size>=40: factor=1.0+(factor-1.0)*0.4
	return maxi(8,roundi(size*factor))

func _string(f: Font,pos: Vector2,value: String,size: int,color: Color) -> void:
	size=_scaled(size)
	var limit:=CLEAN_TEXT_BELOW
	for i in range(value.length()):
		if value.unicode_at(i)>0x2E7F: limit=CLEAN_CJK_BELOW; break
	if size<limit: clean_ops.append(["text",f,pos,value,size,color])
	else: draw_string(f,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_intro() -> void:
	draw_rect(Rect2(0,0,540,78),Color(0.01,0.012,0.013,0.94))
	draw_rect(Rect2(0,game.ui_h-108,540,108),Color(0.01,0.012,0.013,0.94))
	if game.intro_time<1.4:
		_text_center("追杀者来了" if game.language_code.begins_with("zh") else "THE CHASER IS COMING",Vector2(270,902),30,WHITE)
	else:
		_text_center("跑！不要回头" if game.language_code.begins_with("zh") else "RUN! DON'T LOOK BACK",Vector2(270,902),30,WHITE)
	_text_center("点击跳过" if game.language_code.begins_with("zh") else "TAP TO SKIP",Vector2(270,936),12,MUTED)

func _draw_hud() -> void:
	# Minimal survival HUD: hearts top-left, distance and kills top-centre, ammo and pause top-right.
	for i in range(36):
		draw_rect(Rect2(0,i*4,540,4),Color(0,0,0,0.34*(1.0-i/36.0)))
	_draw_hearts(Vector2(26,22))
	# The vehicle bar and armor badge slide down when extra health rows stack up.
	var hud_y: float=46.0+18.0*(_health_rows()-1)
	_draw_vehicle_bar(Vector2(26,hud_y))
	if game.player.has_armor: _draw_armor_badge(Vector2(26,hud_y+20))
	var dist:=_group_thousands(int(game.distance))
	var num_w:=bold.get_string_size(dist,HORIZONTAL_ALIGNMENT_LEFT,-1,62).x
	var unit_w:=bold.get_string_size("m",HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
	var x0:=270.0-(num_w+8+unit_w)/2.0
	# Past the old best the counter turns gold; close to it, a reminder of how far is left.
	var dist_col: Color=Color("ffd36b") if game.new_record else WHITE
	draw_string(bold,Vector2(x0,78),dist,HORIZONTAL_ALIGNMENT_LEFT,-1,62,dist_col)
	draw_string(bold,Vector2(x0+num_w+8,78),"m",HORIZONTAL_ALIGNMENT_LEFT,-1,34,dist_col)
	var lang_r: String=game.language_code
	if not game.new_record and game.run_start_best>0 and game.record_metres_left()<=game.RECORD_HINT_METRES:
		_clean_center(bold,Vector2(270,156),ProgressCatalog.text(lang_r,"rec_left").replace("%d",str(game.record_metres_left())),16,Color("ffd36b"))
	# Kills only, centred under the distance. The coins moved to the top-right column so the
	# middle of the screen stays clean: gold and silver as coloured text, no extra icons.
	var kill_txt:="x %d"%game.kills
	var kw: float=bold.get_string_size(kill_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,36).x
	var rx: float=270.0-(38.0+kw)*0.5
	_draw_skull(Vector2(rx+14,118),16)
	draw_string(bold,Vector2(rx+38,133),kill_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,34,WHITE)
	var gold_txt:="金币 x %d" % game.run_coins if String(game.language_code).begins_with("zh") else "GOLD x %d" % game.run_coins
	var silver_txt:="银币 x %d" % game.run_silver if String(game.language_code).begins_with("zh") else "SILVER x %d" % game.run_silver
	# right aligned, small, both currencies always visible so the player can read the stock
	var gold_w: float=bold.get_string_size(gold_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var silver_w: float=bold.get_string_size(silver_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	var coin_total: float=gold_w+14.0+silver_w
	draw_string(bold,Vector2(534.000000-coin_total,150.0),gold_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2c14e"))
	draw_string(bold,Vector2(534.000000-silver_w,150.0),silver_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("cfd6dd"))
	var pause_pos: Vector2=game.control_pos("pause")
	_draw_pause_button(Rect2(pause_pos-Vector2(23,23),Vector2(46,46)))
	if game.record_banner>0.0: _draw_record_banner()
	_draw_ammo(Vector2(470,52))
	if game.touch_controls and game.state=="playing":
		_draw_joystick(game.left_origin,game.left_knob,false)
		_draw_joystick(game.right_origin,game.right_knob,true)
		_round_button(game.control_pos("btn_reload"),"reload",-1,WHITE)
		var swap_to: String=game.player.swap_target()
		_round_button(game.control_pos("btn_swap"),"swap",-1,WHITE if swap_to!="" else Color(1,1,1,0.35))
		if swap_to!="":
			var short:={"PISTOL":"PST","SMG":"SMG","SHOTGUN":"SG","SNIPER":"SNP","RIFLE":"AR","LAUNCHER":"GL"}
			_text_center(short.get(swap_to,swap_to),game.control_pos("btn_swap")+Vector2(0,52),13,WHITE)
		_round_button(game.control_pos("btn_frag"),"frag",game.player.grenade_count,WHITE)
		_round_button(game.control_pos("btn_flash"),"flash",game.player.flashbang_count,Color("cfefff"))
		if game.player.weapon=="LAUNCHER":
			_round_button(game.control_pos("btn_fire"),"fire",game.player.fire_ammo,Color("ff8a5c"))
	if game.hint_time>0:
		var hint: String=game.localize("aim_stick") if game.touch_controls else GameText.text(game.language_code,"auto_hint")
		_text_center(hint,Vector2(270,186),15,Color(WHITE.r,WHITE.g,WHITE.b,clampf(game.hint_time,0,1)*0.9))
	if game.wave_banner>0:
		var a: float=minf(1,game.wave_banner)
		draw_rect(Rect2(232,214,76,3),Color(0.71,0.12,0.15,a))
		_text_center(game.localize("wave")+" %02d"%game.wave,Vector2(270,256),40,Color(WHITE.r,WHITE.g,WHITE.b,a))
	elif game.wave_clear_banner>0:
		var c: float=minf(1,game.wave_clear_banner)
		draw_rect(Rect2(214,214,112,3),Color(0.38,0.62,0.24,c))
		_text_center(game.localize("wave_cleared"),Vector2(270,256),26,Color(WHITE.r,WHITE.g,WHITE.b,c))
	if game.chase_active:
		# Chase segment: flashing red banner and a proximity bar that drains as the beast closes in.
		var pulse: float=0.70+0.30*sin(Time.get_ticks_msec()/90.0)
		_text_center(RunText.text("chase",lang_r),Vector2(270,212),36,Color(0.88,0.15,0.13,pulse))
		var ratio: float=clampf(game.chase_gap/game.CHASE_START_GAP,0.0,1.0)
		var bar:=Rect2(170,226,200,8)
		draw_rect(bar,Color(0,0,0,0.55))
		draw_rect(Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y)),Color(0.32+0.56*(1.0-ratio),0.72*ratio+0.06,0.12))
		draw_rect(bar,Color(1,1,1,0.25),false,1.0)
	# (No on-screen name for the Banshee: she just turns up, like any other zombie.)

const PAUSE_RECT:=Rect2(482,14,46,46) # drawn box; the tap area is game.PAUSE_BUTTON

func _group_thousands(value: int) -> String:
	var digits:=str(value); var out:=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0: out+=","
		out+=digits[i]
	return out

func _heart_points(center: Vector2,size: float) -> PackedVector2Array:
	var pts:=PackedVector2Array()
	for i in range(48):
		var t:=TAU*i/48.0
		var x:=16.0*pow(sin(t),3.0)
		var y:=13.0*cos(t)-5.0*cos(2.0*t)-2.0*cos(3.0*t)-cos(4.0*t)
		pts.append(center+Vector2(x,-y)*size/34.0)
	return pts

func _health_rows() -> int:
	var count:=int(ceil(game.player.max_health/(100.0/3.0)-0.001))
	return maxi(1,(count+3)/4)

## Deterministic grime: a few soft dark speckles per cell, seeded by the cell index so
## the pattern is stable frame to frame (no shimmer) but different on every rectangle.
func _mottle(r: Rect2,seed_i: int) -> void:
	var rng:=RandomNumberGenerator.new(); rng.seed=0x51ED+seed_i*7919
	for k in range(9):
		var p:=r.position+Vector2(rng.randf()*maxf(1.0,r.size.x-2.5),rng.randf()*maxf(1.0,r.size.y-2.0))
		var s:=rng.randf_range(1.0,2.8)
		draw_rect(Rect2(p,Vector2(s,s*rng.randf_range(0.5,1.3))),Color(0,0,0,rng.randf_range(0.07,0.20)))

func _draw_hearts(origin: Vector2) -> void:
	# Segmented health strip: one mottled rectangle per 33.3 HP, so the default 100 HP
	# shows exactly three. Max-HP upgrades append rectangles — a fractional boost (+1/2,
	# +1/4 ...) shows as a rectangle only that wide. Four rectangles per row; extra rows
	# stack downward along the left edge instead of squeezing the strip thinner.
	var per: float=100.0/3.0
	var segs: float=game.player.max_health/per
	var count: int=int(ceil(segs-0.001))
	var step: float=36.0
	var w: float=step-6.0
	var hp: float=clampf(game.player.health,0.0,game.player.max_health)/per
	var c:=Vector2(origin.x+8,origin.y+10)
	for i in range(count):
		var col: int=i%4; var row: int=i/4
		var part: float=clampf(segs-i,0.0,1.0)   # 1 for whole cells, 0.5 / 0.25 ... for the last
		var r:=Rect2(Vector2(origin.x+col*step,origin.y+4+row*18),Vector2(maxf(6.0,w*part),12))
		draw_rect(r,Color(0.015,0.018,0.019,0.82))
		var fill:=clampf((hp-i)/maxf(part,0.001),0.0,1.0)
		if fill>0.0:
			var inner:=Rect2(r.position+Vector2(2,2),Vector2((r.size.x-4)*fill,r.size.y-4))
			draw_rect(inner,Color("e5e1d8") if hp/segs>0.35 else Color("b94a43"))
		_mottle(r,i)
		draw_rect(r,Color(1,1,1,0.52),false,1.0)
		if col==3 or i==count-1: c=Vector2(r.position.x+r.size.x+8,r.position.y+6)
	# Clean red cross button at the end of the strip: tap offers a rewarded ad for health back.
	# Crisp flat strokes — no mottle/grime on the button itself.
	game.health_plus_rect=Rect2(c-Vector2(11,11),Vector2(22,22))
	draw_rect(Rect2(c+Vector2(-6,-1),Vector2(12,2)),Color("d84b43"))
	draw_rect(Rect2(c+Vector2(-1,-6),Vector2(2,12)),Color("d84b43"))

## Bike durability: a narrow steel-orange strip with a little motorcycle glyph, drawn only
## while riding. It pulses red under 30, when the engine starts smoking.
func _draw_vehicle_bar(origin: Vector2) -> void:
	if game.player.vehicle=="": return
	var d: float=clampf(game.player.vehicle_durability,0.0,100.0)/100.0
	var r:=Rect2(origin+Vector2(0,2),Vector2(170,9))
	draw_rect(r,Color(0.015,0.018,0.019,0.82)); draw_rect(r,Color(1,1,1,0.52),false,1.0)
	var low: bool=game.player.vehicle_durability<30.0
	var col:=Color("d96b43") if low else Color("d9a143")
	if low and int(Time.get_ticks_msec()/180)%2==0: col=Color("e5483c")
	if d>0.0: draw_rect(Rect2(r.position+Vector2(2,2),Vector2((r.size.x-4)*d,r.size.y-4)),col)
	# Glyph: two wheels, a frame bar and handlebars.
	var g:=origin+Vector2(186,6)
	draw_arc(g+Vector2(-8,3),4,0,TAU,14,WHITE,1.8); draw_arc(g+Vector2(8,3),4,0,TAU,14,WHITE,1.8)
	draw_line(g+Vector2(-8,3),g+Vector2(0,-4),WHITE,1.8); draw_line(g+Vector2(0,-4),g+Vector2(8,3),WHITE,1.8)
	draw_line(g+Vector2(-8,3),g+Vector2(2,3),WHITE,1.8); draw_line(g+Vector2(0,-4),g+Vector2(3,-8),WHITE,1.8)

func _draw_armor_badge(pos: Vector2) -> void:
	var shield:=PackedVector2Array([pos+Vector2(0,0),pos+Vector2(16,-4),pos+Vector2(32,0),pos+Vector2(30,18),pos+Vector2(16,30),pos+Vector2(2,18)])
	draw_colored_polygon(shield,Color(0.30,0.48,0.54,0.95)); shield.append(shield[0]); draw_polyline(shield,WHITE,1.5,true)
	_text("ARMOR",pos+Vector2(40,22),16,ARMOR)

func _draw_skull(c: Vector2,r: float) -> void:
	draw_circle(c+Vector2(0,-r*0.12),r,WHITE)
	draw_rect(Rect2(c+Vector2(-r*0.58,r*0.45),Vector2(r*1.16,r*0.62)),WHITE)
	draw_circle(c+Vector2(-r*0.40,-r*0.05),r*0.30,INK); draw_circle(c+Vector2(r*0.40,-r*0.05),r*0.30,INK)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,r*0.25),c+Vector2(-r*0.13,r*0.48),c+Vector2(r*0.13,r*0.48)]),INK)
	for k in range(3): draw_line(c+Vector2(-r*0.30+k*r*0.30,r*0.62),c+Vector2(-r*0.30+k*r*0.30,r*1.05),INK,2)

## Flat coin icon in the same plain style as the skull: three stacked yellow discs.
func _draw_coin_stack(c: Vector2,r: float) -> void:
	var gold:=Color("f2c230"); var rim:=Color("8a5a12"); var shine:=Color("ffe27a")
	for k in [2,1,0]:
		var p:=c+Vector2(0,k*r*0.32)
		draw_circle(p,r+1.5,rim); draw_circle(p,r,gold)
	draw_arc(c,r*0.62,0,TAU,24,rim,2.0)
	draw_arc(c,r*0.78,PI*1.1,PI*1.6,10,shine,2.0)

func _draw_pause_button(rect: Rect2) -> void:
	# Plain rounded frame like the round control buttons (no brush underline under it).
	var box:=StyleBoxFlat.new(); box.bg_color=Color(0,0,0,0.30); box.border_color=WHITE
	box.set_border_width_all(2); box.set_corner_radius_all(6); draw_style_box(box,rect)
	draw_rect(Rect2(rect.position+Vector2(15,12),Vector2(5,22)),WHITE)
	draw_rect(Rect2(rect.position+Vector2(26,12),Vector2(5,22)),WHITE)

func _draw_ammo(right_top: Vector2) -> void:
	# "12/48" plus a cartridge icon, right-aligned beside the pause button.
	var label:="%d/∞"%game.player.ammo if game.player.infinite_ammo() else "%d/%d"%[game.player.ammo,game.player.reserve_ammo]
	var w:=bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,34).x
	var bullet_x:=right_top.x-12
	draw_string(bold,Vector2(bullet_x-14-w,right_top.y),label,HORIZONTAL_ALIGNMENT_LEFT,-1,34,WHITE if game.player.ammo>0 else Color("e66b62"))
	draw_rect(Rect2(bullet_x-4,right_top.y-22,9,20),WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(bullet_x-4,right_top.y-22),Vector2(bullet_x+0.5,right_top.y-34),Vector2(bullet_x+5,right_top.y-22)]),WHITE)
	draw_rect(Rect2(bullet_x-5,right_top.y-4,11,4),WHITE)
	var weapon_label: String=ShopText.text(game.language_code,"n_"+String(game.player.weapon).to_lower())
	if game.player.weapon=="LAUNCHER": weapon_label+="  ·  "+(RunText.text("incendiary")+" ×%d"%game.player.fire_ammo if game.player.fire_mode else RunText.text("l_grenade"))
	_text_right(weapon_label,Vector2(534.000000,right_top.y+26),16,MUTED)
	if not game.touch_controls:
		_text_right("%s ×%d   %s ×%d"%[RunText.text("l_grenade"),game.player.grenade_count,RunText.text("l_flashbang"),game.player.flashbang_count],Vector2(534.000000,right_top.y+48),15,MUTED)
	if game.player.reloading:
		var progress: float=1.0-game.player.reload_timer/game.player.reload_duration
		draw_rect(Rect2(Vector2(right_top.x-110,right_top.y+60),Vector2(116,3)),Color(1,1,1,0.18))
		draw_rect(Rect2(Vector2(right_top.x-110,right_top.y+60),Vector2(116*progress,3)),RED)
		_text_right(game.localize("loading"),Vector2(right_top.x+6,right_top.y+84),15,WHITE)
	elif game.player.ammo==0:
		_text_right(game.localize("auto") if game.auto_reload else game.localize("press_r"),Vector2(right_top.x+6,right_top.y+84),15,Color("e66b62"))

func _btn(p: Vector2) -> Vector2:
	return p + Vector2(0, game.ui_h - 960.0)

func _round_button(center: Vector2,icon: String,count: int,accent: Color) -> void:
	var r:=34.0
	draw_circle(center,r,Color(0.02,0.02,0.02,0.45))
	draw_arc(center,r,0,TAU,48,WHITE,2.5,true)
	match icon:
		"reload":
			draw_arc(center,15,deg_to_rad(200),deg_to_rad(340),20,WHITE,4,true)
			draw_arc(center,15,deg_to_rad(20),deg_to_rad(160),20,WHITE,4,true)
			var a:=center+Vector2(15,0).rotated(deg_to_rad(340)); var b:=center+Vector2(15,0).rotated(deg_to_rad(160))
			draw_colored_polygon(PackedVector2Array([a+Vector2(-6,-6),a+Vector2(6,-4),a+Vector2(1,7)]),WHITE)
			draw_colored_polygon(PackedVector2Array([b+Vector2(6,6),b+Vector2(-6,4),b+Vector2(-1,-7)]),WHITE)
		"frag":
			draw_circle(center+Vector2(0,4),13,WHITE)
			for k in range(3): draw_line(center+Vector2(-12,-1+k*6),center+Vector2(12,-1+k*6),INK,1.5)
			draw_line(center+Vector2(0,-9),center+Vector2(0,13),INK,1.5)
			draw_rect(Rect2(center+Vector2(-5,-15),Vector2(10,7)),WHITE)
			draw_arc(center+Vector2(9,-12),5,PI*0.5,PI*1.8,10,WHITE,2,true)
		"flash":
			draw_rect(Rect2(center+Vector2(-9,-10),Vector2(18,24)),accent)
			draw_rect(Rect2(center+Vector2(-5,-16),Vector2(10,6)),accent)
			for k in range(3): draw_line(center+Vector2(-9,-4+k*7),center+Vector2(9,-4+k*7),INK,1.5)
		"swap":
			# Two opposing arrows: switch guns.
			draw_line(center+Vector2(-13,-6),center+Vector2(11,-6),accent,3.5)
			draw_colored_polygon(PackedVector2Array([center+Vector2(15,-6),center+Vector2(7,-12),center+Vector2(7,0)]),accent)
			draw_line(center+Vector2(13,7),center+Vector2(-11,7),accent,3.5)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-15,7),center+Vector2(-7,1),center+Vector2(-7,13)]),accent)
		"fire":
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-17),center+Vector2(11,4),center+Vector2(0,15),center+Vector2(-11,4)]),accent)
			draw_colored_polygon(PackedVector2Array([center+Vector2(0,-4),center+Vector2(5,6),center+Vector2(0,11),center+Vector2(-5,6)]),INK)
	if count>=0:
		draw_circle(center+Vector2(24,24),11,Color(0.05,0.05,0.05,0.85)); draw_arc(center+Vector2(24,24),11,0,TAU,24,accent,1.5,true)
		_text_center(str(count),center+Vector2(24,30),16,WHITE)

func _draw_joystick(origin: Vector2,knob: Vector2,aim: bool) -> void:
	# Two matching thumbsticks: left steers left/right, right turns the survivor (aim).
	draw_circle(origin,62,Color(0.02,0.02,0.02,0.28))
	draw_arc(origin,62,0,TAU,72,WHITE,3,true)
	if aim:
		# Tick marks all the way round: this stick points the survivor in any direction.
		for i in range(12):
			var a:=i*TAU/12.0; var dir:=Vector2(cos(a),sin(a))
			draw_line(origin+dir*50,origin+dir*(57 if i%3 else 44),WHITE,2.5 if i%3 else 3.0)
	else:
		# Only left and right arrows: this stick only moves the survivor sideways.
		for d in [Vector2.LEFT,Vector2.RIGHT]:
			var dir: Vector2=d; var tip: Vector2=origin+dir*50; var side:=Vector2(-dir.y,dir.x)*8
			draw_colored_polygon(PackedVector2Array([tip,tip-dir*12+side,tip-dir*12-side]),WHITE)
	# Both sticks get the same grey thumb knob.
	draw_circle(knob,26,Color(0.62,0.62,0.60,0.92)); draw_arc(knob,26,0,TAU,40,WHITE,2,true)
	if aim:
		# Small sight on the knob so the two sticks are still easy to tell apart.
		for d: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			draw_line(knob+d*6,knob+d*14,Color(0.1,0.1,0.1,0.85),2.5)

func _draw_cover() -> void:
	# The original start screen, restored: the full-screen title poster does all the talking
	# (title, skull, TAP ANYWHERE TO START, version are painted into the art). The gear in its
	# top-right corner opens settings; any other tap continues to the main menu.
	if menu_art:
		# cover fit: the poster always fills the height, and any extra width is cropped away
		var tw := float(menu_art.get_width())
		var th := float(menu_art.get_height())
		var k := maxf(game.ui_h / th, 540.0 / tw)
		var sz := Vector2(tw * k, th * k)
		draw_texture_rect(menu_art, Rect2(Vector2((540.0 - sz.x) * 0.5, (game.ui_h - sz.y) * 0.5), sz), false)
	else: draw_rect(Rect2(0,0,540,game.ui_h),INK)
	# The Dreadline poster has no prompt painted on it, so draw it here.
	var lang_t: String = game.language_code
	var prompt: String = "点任意处开始" if String(lang_t).begins_with("zh") else "TAP ANYWHERE TO START"
	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.003)
	_clean_center(bold, Vector2(270.0, game.ui_h - 150.0), prompt, 22, Color(1, 1, 1, pulse))
	_clean_center(bold, Vector2(270.0, game.ui_h - 96.0), "v1.0.0", 12, Color(1, 1, 1, 0.45))
func _draw_loading() -> void:
	# ONE loading art per run, full-screen, randomly picked at _begin_loading and kept
	# unchanged until progress reaches 100%. No switching, no black panel.
	# Everything goes through clean_ops (the clean Control has NO grunge shader),
	# so the HD art stays pristine — the main Control's worn-paint shader would
	# chew black holes through the bright moon and sky.
	if game.loading_order.size()>0 and loading_art.size()>0:
		var idx: int=int(game.loading_order[game.loading_idx % game.loading_order.size()])
		if idx>=0 and idx<loading_art.size() and loading_art[idx]:
			# draw the art at its own size, centred: never stretched, never zoomed
			var tex:=loading_art[idx]
			var tw:=float(tex.get_width()); var th:=float(tex.get_height())
			var k:=minf(540.0/tw,game.ui_h/th)
			var sz:=Vector2(tw*k,th*k)
			_box(Rect2(0,0,540,game.ui_h),INK)
			clean_ops.append(["texture",tex,Rect2((Vector2(540,game.ui_h)-sz)*0.5,sz)])
	else:
		_box(Rect2(0,0,540,game.ui_h),INK)
	var zh: bool=game.language_code.begins_with("zh") if game.language_code else true
	var dots: String="..." if int(game.elapsed*2.0)%4<3 else "."
	var label: String=("加载中%s"%dots) if zh else ("LOADING%s"%dots)
	_clean_center(font,Vector2(270,868),label,22,WHITE,true)
	var bar := Rect2(108,884,324,10)
	_box(bar,Color(1,1,1,0.22),Color(1,1,1,0.6),1)
	_box(Rect2(bar.position,Vector2(maxf(1.0,bar.size.x*game.loading_progress),bar.size.y)),Color("ff5030"))
	_clean_center(font,Vector2(270,914),"%d%%"%int(game.loading_progress*100),13,WHITE,true)

func _crate_icon(c: Vector2,col: Color) -> void:
	# Line-art supply crate, same weight as the settings gear on the poster.
	var w:=2.6
	var front:=PackedVector2Array([c+Vector2(-20,-6),c+Vector2(14,-6),c+Vector2(14,20),c+Vector2(-20,20),c+Vector2(-20,-6)])
	draw_polyline(front,col,w,true)
	draw_polyline(PackedVector2Array([c+Vector2(-20,-6),c+Vector2(-12,-16),c+Vector2(22,-16),c+Vector2(14,-6)]),col,w,true)
	draw_polyline(PackedVector2Array([c+Vector2(22,-16),c+Vector2(22,10),c+Vector2(14,20)]),col,w,true)
	draw_line(c+Vector2(-20,7),c+Vector2(14,7),col,w,true)
	draw_rect(Rect2(c+Vector2(-6,3),Vector2(6,8)),col)

func _chip_text(label: String,rect: Rect2,col: Color) -> void:
	var size:=13
	while font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-6 and size>8: size-=1
	_text_center(label,rect.get_center()+Vector2(0,size*0.38),size,col)

func _draw_lootbox() -> void:
	var lang: String=game.language_code
	# Keep the real 3D case visible; only the header and reward console are overlaid.
	draw_rect(Rect2(0,0,540,110),Color(0.018,0.022,0.023,0.84))
	draw_rect(Rect2(0,704,540,256),Color(0.018,0.022,0.023,0.90))
	_button(Rect2(24,24,100,48),"‹  "+game.localize("back"),false)
	_text_center(ShopText.text(lang,"cases_title"),Vector2(328,61),26,WHITE)
	_text_center("DF–07  /  FIELD ISSUE",Vector2(270,132),13,MUTED)
	if game.lootbox_scene.revealed:
		_text_center(ShopText.text(lang,"case_reward"),Vector2(270,742),15,GOLD)
		_bold_text(game.lootbox_reward_title,Vector2(130,778),25,WHITE)
	elif game.lootbox_scene.opening:
		_text_center(ShopText.text(lang,"case_opening"),Vector2(270,756),21,WHITE)
	else:
		_text_center(ShopText.text(lang,"case_hint"),Vector2(270,722),15,MUTED)
	if not game.lootbox_message.is_empty(): _text_center(game.lootbox_message,Vector2(270,786),14,Color("ef9b82"))
	var action: String=ShopText.text(lang,"case_again" if game.lootbox_scene.revealed else "case_open")
	_button(game.LOOTBOX_GOLD_RECT,action+"  ·  %d %s"%[game.LOOTBOX_COST,StoreCatalog.text(lang,"silver")],game.bank_silver>=game.LOOTBOX_COST)
	_button(game.LOOTBOX_VOUCHER_RECT,action+"  ·  1 %s"%ShopText.text(lang,"voucher"),game.bank_vouchers>=1)
	# free open by ad: five a day
	# free open by ad: five a day, painted in the ad yellow
	var left: int = game.lootbox_ads_left()
	var ar: Rect2 = game.LOOTBOX_AD_RECT
	var on: bool = left > 0
	_box(ar, Color(0.98, 0.78, 0.10) if on else Color(0.16, 0.15, 0.11, 0.95))
	_box(Rect2(ar.position, Vector2(64.0, ar.size.y)), Color(0.86, 0.62, 0.04) if on else Color(0.24, 0.21, 0.14))
	_bold_text("AD", Vector2(ar.position.x + 22.0, ar.get_center().y + 7.0), 19, Color(0.12, 0.10, 0.06) if on else Color(0.55, 0.52, 0.45))
	var lbl: String = ("\u770b\u5e7f\u544a\u5f00\u7bb1  %d/%d" % [left, game.LOOTBOX_AD_DAILY]) if String(lang).begins_with("zh") else ("AD OPEN  %d/%d" % [left, game.LOOTBOX_AD_DAILY])
	_bold_text(lbl, Vector2(ar.position.x + 78.0, ar.get_center().y + 8.0), 19, Color(0.10, 0.08, 0.04) if on else Color(0.58, 0.55, 0.48))
	_text_center("%s: %s  ·  %s: %d" % [ShopText.text(lang,"case_balance"),str(game.bank_coins),ShopText.text(lang,"voucher"),game.bank_vouchers],Vector2(270,889),16,GOLD)

func _draw_map() -> void:
	var lang: String=game.language_code
	# The war-room table stays fully visible; only a slim header, the back button and
	# the "coming soon" answer for locked photos are overlaid.
	draw_rect(Rect2(0,0,540,104),Color(0.016,0.014,0.012,0.80))
	_button(Rect2(24,24,100,48),"‹  "+game.localize("back"),false)
	_text_center(ExtraText.text(lang,"map").to_upper(),Vector2(320,61),26,WHITE)
	if game.map_toast>0.0:
		var a:=minf(1.0,game.map_toast)
		_text_center(game.map_toast_text,Vector2(270,856),20,Color(1.0,0.85,0.55,a))

func _draw_settings() -> void:
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.018,0.022,0.023,0.88))
	_bold_text("SETTINGS",Vector2(42,100),32,WHITE)
	_text("AUDIO / GAMEPLAY",Vector2(44,132),14,MUTED)
	var lang: String=game.language_code
	_volume_slider(game.SLIDER_MUSIC,ShopText.text(lang,"vol_music"),game.sound.music_volume)
	_volume_slider(game.SLIDER_SFX,ShopText.text(lang,"vol_sfx"),game.sound.sfx_volume)
	_button(Rect2(66,348,408,70),game.localize("reload_auto") if game.auto_reload else game.localize("reload_manual"),false)
	_button(Rect2(66,436,408,70),"文   "+game.localize("language"),false)
	var sep: String="：" if lang in ["zh_CN","zh_TW","ja"] else ": "
	_button(Rect2(66,524,408,70),"Aa   %s%s%s"%[ShopText.text(lang,"text_size"),sep,ShopText.text(lang,"ts_%d"%game.text_size)],false)
	_button(Rect2(66,612,408,70),Localization.text(lang,"control_layout"),false)
	_button(game.SETTINGS_QUALITY,Localization.text(lang,"quality")+sep+Localization.text(lang,"quality_high" if game.quality_high else "quality_fast"),false)
	_button(Rect2(66,810,408,64),game.localize("back"),true)

## Settings -> Control layout. Draws the same sticks and buttons the run uses, at their
## saved points, so what the player drags here is exactly what they get in a run.
func _draw_controls() -> void:
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.018,0.022,0.023,0.93))
	draw_rect(Rect2(0,0,540,game.ui_h),Color(1,1,1,0.10),false,1.0)
	var lang: String=game.language_code
	_bold_text(Localization.text(lang,"control_layout"),Vector2(42,84),30,WHITE)
	_text(Localization.text(lang,"control_layout_hint"),Vector2(44,114),14,MUTED)
	_button(game.CTRL_RESET,Localization.text(lang,"reset"),false)
	_button(game.CTRL_SAVE,Localization.text(lang,"save"),true)
	var lp: Vector2=game.control_pos("stick_left")
	var rp: Vector2=game.control_pos("stick_right")
	_draw_joystick(lp,lp,false)
	_draw_joystick(rp,rp,true)
	for pair in [[lp,"move_stick"],[rp,"aim_stick"]]:
		var at: Vector2=pair[0]+Vector2(0,86)
		if at.y<game.ui_h-12.0: _text_center(game.localize(str(pair[1])),at,13,Color(1,1,1,0.75))
	_round_button(game.control_pos("btn_reload"),"reload",-1,WHITE)
	_round_button(game.control_pos("btn_swap"),"swap",-1,WHITE)
	_round_button(game.control_pos("btn_frag"),"frag",-1,WHITE)
	_round_button(game.control_pos("btn_flash"),"flash",-1,WHITE)
	_round_button(game.control_pos("btn_fire"),"fire",-1,Color("ff8a5c"))
	var pp: Vector2=game.control_pos("pause")
	_draw_pause_button(Rect2(pp-Vector2(23,23),Vector2(46,46)))
	if game.ctrl_drag!="":
		draw_circle(game.control_pos(game.ctrl_drag),74.0 if game.ctrl_drag.begins_with("stick_") else 46.0,Color(0.86,0.24,0.19,0.20))

## A painted volume bar: name on the left, track with a red fill and a round knob, percent.
func _volume_slider(track: Rect2,label: String,value: float) -> void:
	var row:=Rect2(66,track.position.y-14,408,track.size.y+28)
	_panel(row,Color(0.06,0.07,0.07,0.92),LINE,0)
	_bold_text(label,Vector2(84,track.get_center().y+9),22,WHITE)
	var bar:=Rect2(track.position.x,track.get_center().y-5,track.size.x,10)
	draw_rect(bar,Color(1,1,1,0.16))
	var slider_red:=Color("e8402f")
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*value,bar.size.y)),slider_red)
	var knob:=Vector2(bar.position.x+bar.size.x*value,bar.get_center().y)
	draw_circle(knob,14,WHITE); draw_circle(knob,8,slider_red)
	clean_ops.append(["text",bold,Vector2(track.end.x+12,track.get_center().y+7),"%d%%"%roundi(value*100.0),_scaled(17),WHITE])

## Small switch left of START: ON = the chosen vehicle is taken into the run, OFF = a vanilla
## run with no vehicle at all (the point of a fully unlocked test build).
func _loadout_toggle(r: Rect2) -> void:
	var on: bool=game.loadout_on
	_box(r,Color(0.05,0.058,0.062,0.94))
	_frame(r,Color(1.0,0.82,0.45,0.85) if on else Color(1,1,1,0.16),1.0)
	_clean_center(bold,Vector2(r.get_center().x,r.position.y+26),"GEAR",9,WHITE if on else Color(1,1,1,0.40),false)
	_clean_center(bold,Vector2(r.get_center().x,r.end.y-15),"ON" if on else "OFF",17,Color("ffd27a") if on else Color(1,1,1,0.45),false)
	if not on:
		clean_ops.append(["line",PackedVector2Array([r.position+Vector2(11,15),r.end-Vector2(11,15)]),Color("e0453d"),2.5])

func _draw_equip_menu() -> void:
	# dropdown over a survivor card: tap it to wear them
	if int(game.equip_menu_index)>=0:
		var er: Rect2=game.equip_menu_rect()
		# Grey while the menu is open; the red edge belongs to the equipped card only.
		var equipped_now: bool = int(game.equip_menu_index) == (game.character_choice if int(game.equip_menu_tab)==0 else -1)
		_panel(er, Color(0.03,0.034,0.038,1.0), RED if equipped_now else Color(0.72,0.74,0.75,1.0), 2)
		var etxt: String = ShopText.text(game.language_code, "char_equipped" if equipped_now else "btn_equip")
		_clean_center(bold,Vector2(er.get_center().x,er.position.y+26),etxt,18,WHITE)
		# second row: take it off entirely
		var ur: Rect2 = game.equip_menu_unequip_rect()
		_panel(ur, Color(0.10,0.10,0.11,1.0), Color(0.55,0.55,0.58,0.9), 1)
		_clean_center(bold, Vector2(ur.get_center().x, ur.position.y + 24), "卸下" if String(game.language_code).begins_with("zh") else "REMOVE", 16, Color(0.88,0.88,0.9))


## F3 overlay: frames per second, the worst frame of the last second, and the live object counts.
func _debug_fps() -> void:
	if not game.debug_show_fps:
		return
	var fps: float = Engine.get_frames_per_second()
	var msg: String = "%d fps   %.1f ms   z:%d  fx:%d  pk:%d" % [
		int(fps), 1000.0 / maxf(fps, 1.0),
		(game.get("zombies") as Array).size() if game.get("zombies") != null else 0,
		(game.get("effects") as Array).size() if game.get("effects") != null else 0,
		(game.get("pickups") as Array).size() if game.get("pickups") != null else 0]
	_box(Rect2(6, 66, 330, 26), Color(0, 0, 0, 0.72))
	_clean_text(bold, Vector2(14, 84), msg, 14, Color(0.6, 1.0, 0.6))


func _draw_character_select() -> void:
	# Main screen. The 3D survivor and pet stand in the middle (lobby_scene_3d.gd); this draws the
	# frame: one column on the left with 角色 / 宠物 tabs over a vertically scrolling list.
	var lang: String=game.language_code
	if skin_portraits.is_empty() and game.lobby!=null:
		for sk in game.lobby.SKINS:
			var sp: String="res://assets/ui/%s_hd_portrait.png"%String(sk.get("name",""))
			skin_portraits.append(load(sp) if ResourceLoader.exists(sp) else null)
	draw_rect(Rect2(0,0,540,62),Color(0.015,0.018,0.019,0.72))
	draw_rect(Rect2(0,game.LOBBY_BAND_TOP,540,game.ui_h-game.LOBBY_BAND_TOP),Color(0.015,0.018,0.019,0.82))
	_wallet(game.WALLET_LOBBY,true,game.LOBBY_WALLET_SCALE)
	_energy_refill_timer(game.WALLET_LOBBY,game.LOBBY_WALLET_SCALE)
	if game.offer_active() and game.state=="character_select" and not game.premium_build(): _offer_badge(game.OFFER_BADGE)
	if game.state=="character_select":
		_side_button(game.SIDE_SIGNIN,"signin",ProgressCatalog.text(lang,"signin"),game.signin_available())
		_side_button(game.SIDE_TASKS,"tasks",ProgressCatalog.text(lang,"tasks"),game.missions_ready_count()>0)
		_side_button(game.SIDE_SHOP,"shop",game.localize("shop"),false)
		if not game.premium_build():
			_side_button(game.SIDE_STORE,"store",StoreCatalog.text(lang,"store"),false)
		# no store in this build: the mail button takes its place in the rail
		_side_button(game.SIDE_STORE if game.premium_build() else game.SIDE_MAIL,"mail",ExtraText.text(lang,"mail"),game.mail_unclaimed()>0)
		_side_button(game.SIDE_BAG,"bag",ExtraText.text(lang,"bag"),false)
		_side_button(game.SIDE_MAP,"map",ExtraText.text(lang,"map"),false)
		if not game.premium_build():
			_airdrop_button(lang)
	for t in [0, 1, 3, 4]:
		var tab: Rect2=game.lobby_tab_rect(t); var tab_on: bool=game.lobby_tab==t
		if tab_on: _blood_banner(tab)
		var tlabel: String = "载具" if t==3 else ("武器" if t==4 else ShopText.text(lang,"chars" if t==0 else "pets"))
		_text_center(tlabel,Vector2(tab.get_center().x,tab.end.y-12),15,C_BONE if tab_on else MUTED)
	# The settings gear lives in the same corner on every tab, always white. Equipping happens
	# on the cards themselves, so the per-tab gear toggles are gone.
	_lobby_settings_gear(game.LOBBY_GEAR)
	# Perk tag for the selected survivor, right of the tabs (only Darius has one for now).
	if game.lobby_tab==0 and game.character_choice<game.lobby.CHARACTERS.size():
		var perk_key: String=String(game.lobby.CHARACTERS[game.character_choice].get("perk",""))
		if perk_key!="":
			var pt: String=RunText.text(perk_key,lang)
			var pw: float=bold.get_string_size(pt,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(13)).x
			var pr:=Rect2(522-pw-22,game.LOBBY_BAND_TOP+9,pw+22,30)
			_panel(pr,Color(0.06,0.10,0.075,0.85),Color("6fae7d",0.9),0)
			draw_rect(Rect2(pr.position.x+7,pr.get_center().y-6,4,12),Color("7ed492"))
			draw_rect(Rect2(pr.position.x+3,pr.get_center().y-2,12,4),Color("7ed492"))
			_text(pt,pr.position+Vector2(19,20),13,Color("bfe8c9"))
	var view: Rect2=game.lobby_view_rect()
	for i in range(game.lobby_item_count()):
		var card: Rect2=game.lobby_card_rect(i)
		if card.intersects(view): _lobby_card(card,i,view,lang)

	# hover card for the lobby cards (characters / pets / skins / vehicles)
	if mouse_hover and game.state=="character_select":
		var mpl: Vector2=hover_point
		if game.lobby_view_rect().has_point(mpl):
			for ci in range(game.lobby_item_count()):
				if not (game.lobby_card_rect(ci) as Rect2).has_point(mpl): continue
				if game.lobby_tab==3:
					var vp: Dictionary=game.pack_by_id(["vehicle_bike","vehicle_sport","vehicle_cruiser","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"][clampi(ci,0,6)])
					if not vp.is_empty():
						var vk2: String=String(vp.get("name","bike"))
						_info_tip(mpl,StoreCatalog.text(lang,vk2),StoreCatalog.text(lang,"vehicles"),StoreCatalog.text(lang,vk2+"_desc"))
				elif game.lobby_tab==2 and ci<game.lobby.SKINS.size():
					var sk4: Dictionary=game.lobby.SKINS[ci]
					_info_tip(mpl,RunText.text(String(sk4.get("name","")),lang),game.character_name(int(sk4.get("char",-1))),
						ExtraText.text(lang,"skin_locked"))
				elif game.lobby_tab==1 and ci<game.lobby.PETS.size():
					var psub := ExtraText.text(lang,"pet_locked")
					if game.premium_build():
						psub = ("已拥有" if String(lang).begins_with("zh") else "OWNED") if game.pet_owned(ci) else ("%d %s" % [int(game.pack_by_id("pet_%d" % ci).get("coins",0)), "金币" if String(lang).begins_with("zh") else "coins"])
					_info_tip(mpl,game.pet_name(ci),ShopText.text(lang,"pets"), psub)
				elif game.lobby_tab==0 and ci<game.lobby.CHARACTERS.size():
					var ch: Dictionary=game.lobby.CHARACTERS[ci]
					var perk2: String=String(ch.get("perk",""))
					var sub: String = RunText.text(perk2 if perk2!="" else "perk_mason", lang)
					if game.premium_build():
						# ability first, then what it costs (or that you own it)
						if game.character_owned(ci):
							sub += "   ·   " + ("已拥有" if String(lang).begins_with("zh") else "OWNED")
						else:
							sub += "   ·   " + game.card_price_text(0, ci)
					_info_tip(mpl,game.character_name(ci),ShopText.text(lang,"chars"), sub)
				break
	for side in [-1,1]:
		if not game.lobby_page_visible(side): continue
		var pr: Rect2=game.lobby_page_rect(side)
		_box(pr,Color(0,0,0,0.62))
		var pc:=pr.get_center()
		clean_ops.append(["line",PackedVector2Array([pc+Vector2(-5*side,-12),pc+Vector2(6*side,0),pc+Vector2(-5*side,12)]),WHITE,3.0])
	# (Big switch arrows beside the survivor removed per user request — switch via cards.)
	if game.lobby_toast>0.0:
		var a: float=minf(1.0,game.lobby_toast*2.0)
		_panel(Rect2(170,600,200,46),Color(0.02,0.025,0.026,0.92*a),Color(RED,a),0)
		var tk: String=String(game.lobby_toast_key)
		var tt: String=ExtraText.text(lang,tk) if tk in ["pet_locked","char_locked","skin_locked","stay_tuned","airdrop_tomorrow"] else ShopText.text(lang,tk)
		var tw: float=maxf(200.0,bold.get_string_size(tt,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(16)).x+40.0)
		if tk in ["pet_locked","char_locked","skin_locked","stay_tuned","airdrop_tomorrow"]: _panel(Rect2(270-tw*0.5,600,tw,46),Color(0.02,0.025,0.026,0.92*a),Color(RED,a),0)
		_text_center(tt,Vector2(270,630),16,Color(1,1,1,a))
	var can_start: bool=game.stamina.value>=game.stamina.RUN_COST
	_button(game.LOBBY_START,game.localize("start")+"   ›",can_start)
	# No cans in the buy-once build, so the start button carries no cost badge.
	if not game.premium_build():
		var cost_txt: String="-%d"%game.stamina.RUN_COST
		var ctw: float=bold.get_string_size(cost_txt,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(19)).x
		var icon_sz: float=34.0*game.LOBBY_WALLET_SCALE
		var total_w: float=icon_sz+6+ctw
		var cx0: float=game.LOBBY_START.end.x-14-total_w
		var cy: float=game.LOBBY_START.get_center().y-icon_sz*0.5
		clean_ops.append(["texture",can_tex,Rect2(cx0,cy,icon_sz,icon_sz)])
		_clean_text(bold,Vector2(cx0+icon_sz+6,cy+icon_sz-5),cost_txt,19,WHITE)
	if not can_start and not game.ad_run_used:
		var ad: Rect2=game.LOBBY_AD_RUN
		_box(ad,Color("292316",0.98)); _frame(ad,Color(BRASS_LIGHT,0.85),1.0)
		var c:=ad.get_center()+Vector2(0,-8)
		clean_ops.append(["poly",PackedVector2Array([c+Vector2(-7,-10),c+Vector2(10,0),c+Vector2(-7,10)]),BRASS_LIGHT])
		_clean_center(bold,Vector2(ad.get_center().x,ad.end.y-10),"AD",12,BRASS_LIGHT)
	# The no-cans toast must be visible here: start_run never forces the pack popup anymore.
	_toast(536.0)

## One card of the scrolling list, cut off cleanly where it leaves the visible area.
	_draw_equip_menu()
	_debug_fps()

## The little status row under a card: the price while it is locked, "owned" once bought.
func _card_buy_row(card: Rect2, tab: int, index: int, lang: String) -> void:
	if not game.premium_build():
		return
	var row := Rect2(card.position.x - 4.0, card.end.y + 2.0, card.size.x + 8.0, 16.0)
	if tab == 4:
		row = Rect2(card.position.x - 4.0, card.end.y - 22.0, card.size.x + 8.0, 16.0)
	var owned_now := false
	match tab:
		0: owned_now = game.character_owned(index)
		1: owned_now = game.pet_owned(index)
		3: owned_now = game.vehicle_is_owned(String(["vehicle_bike","vehicle_sport","vehicle_car","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"][clampi(index,0,6)]))
		4: owned_now = game.flame_owned()
	if owned_now:
		_box(row, Color(0.03,0.032,0.035,0.92))
		_text_center("已拥有" if String(lang).begins_with("zh") else "OWNED", row.get_center()+Vector2(0,4), 10, Color(C_BONE.r,C_BONE.g,C_BONE.b,0.55))
	else:
		var price: String = String(game.card_price_text(tab, index))
		if price == "":
			return
		_box(row, Color(0.03,0.032,0.035,0.92)); _box(Rect2(row.position,Vector2(3,row.size.y)),C_BLOOD)
		_text_center(price, row.get_center()+Vector2(0,4), 10, C_ACID)


func _lobby_card(card: Rect2,i: int,view: Rect2,lang: String) -> void:
	var vis:=card.intersection(view)
	if vis.size.y<4.0 or vis.size.x<4.0: return
	var whole: bool=vis.size.y>=card.size.y-0.5 and vis.size.x>=card.size.x-0.5
	if whole: _brackets(card.grow(-1.0), 9.0, C_BONE, 2.0)
	if game.lobby_tab==4:
		# Flamethrower: a gold-framed card, because it is the one high-value weapon in the game.
		var owned: bool=game.flame_owned()
		var gold:=Color("e8b84b")
		_panel(vis,Color(0.16,0.12,0.05,0.95) if owned else Color(0.10,0.08,0.03,0.85),gold if whole else Color(gold,0.55),2)
		var wtex: Texture2D=_store_art("weapon_flame")
		var wr2:=Rect2(card.position+Vector2(5,5),card.size-Vector2(10,30))
		var wvis:=wr2.intersection(view)
		if wtex and wvis.size.y>1.0:
			var wts:=wtex.get_size()
			clean_ops.append(["region",wtex,wvis,Rect2((wvis.position-wr2.position)/wr2.size*wts,wvis.size/wr2.size*wts)])
		if not owned and wvis.size.y>1.0:
			_box(wvis,Color(0,0,0,0.55))
		if whole:
			_text_center("火焰喷射器" if String(lang).begins_with("zh") else "FLAMETHROWER",Vector2(card.get_center().x,card.end.y-34),13,gold)
			if owned:
				draw_rect(Rect2(card.position.x+6,card.end.y-5,card.size.x-12,2),gold)
		_card_buy_row(card, 4, i, lang)
		return

	if game.lobby_tab==3:
		# Vehicle card: same anatomy as the pet/skin cards - art, lock overlay, name.
		var vi: int=clampi(i,0,6)
		var vids: Array=["vehicle_bike","vehicle_sport","vehicle_cruiser","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"]
		var vnames: Array=["BIKE","SPORT","CRUISER","GOLD","TANK","SEDAN","GOLD_CAR"]
		var vid: String=String(vids[vi])
		var von: bool=game.vehicle_owned(String(vnames[vi]))
		var vsel: bool=von or game.vehicle_choice==vi
		_panel(vis,Color(0.10,0.11,0.115,0.94) if vsel else Color(0.05,0.055,0.06,0.80),RED if von and whole else LINE,0)
		var vtex: Texture2D=_store_art(vid)
		var vr2:=Rect2(card.position+Vector2(4,4),card.size-Vector2(8,30))
		var vvis:=vr2.intersection(view)
		if vtex and vvis.size.y>1.0:
			var vts:=vtex.get_size()
			clean_ops.append(["region",vtex,vvis,Rect2((vvis.position-vr2.position)/vr2.size*vts,vvis.size/vr2.size*vts)])
		if not game.vehicle_is_owned(vid) and vvis.size.y>1.0:
			_box(vvis,Color(0,0,0,0.58))
			var vlc:=vr2.get_center()+Vector2(0,6)
			if view.has_point(vlc+Vector2(0,-14)) and view.has_point(vlc+Vector2(0,18)):
				_box(Rect2(vlc+Vector2(-13,-2),Vector2(26,20)),Color(1,1,1,0.9))
				var varc:=PackedVector2Array()
				for kk in range(13): varc.append(vlc+Vector2(cos(PI+PI*kk/12.0),sin(PI+PI*kk/12.0))*8.0+Vector2(0,-2))
				clean_ops.append(["line",varc,Color(1,1,1,0.9),3.0])
				_box(Rect2(vlc+Vector2(-2,5),Vector2(4,7)),Color(0,0,0,0.8))
		if whole:
			_text_center(StoreCatalog.text(lang,String(["bike","sport","cruiser","gold","tank","sedan","gold_car"][vi])),Vector2(card.get_center().x,card.end.y-9),12,WHITE if von else MUTED)
			if von: draw_rect(Rect2(card.position.x+6,card.end.y-5,card.size.x-12,2),Color("b94a43"))
		_card_buy_row(card, 3, i, lang)
		return
	var pets: bool=game.lobby_tab==1
	if game.lobby_tab==2:
		if i>=game.lobby.SKINS.size():
			if whole: _locked_slot(card,false,true)
			else: _panel(vis,Color(0.04,0.045,0.047,0.80),Color(LINE,0.7),0)
			return
		# Outfit skin card: portrait, name, red underline while worn.
		var sk: Dictionary=game.lobby.SKINS[i]
		var on: bool=int(sk.get("char",-1))==game.character_choice and game.selected_skin_index()==i
		_panel(vis,Color(0.10,0.11,0.115,0.94) if on else Color(0.05,0.055,0.06,0.80),RED if on and whole else LINE,0)
		var stex: Texture2D=skin_portraits[i] if skin_portraits.size()>i else null
		var sr:=Rect2(card.position+Vector2(4,4),card.size-Vector2(8,30))
		var svr:=sr.intersection(view)
		if stex and svr.size.y>1.0:
			var sts:=stex.get_size()
			clean_ops.append(["region",stex,svr,Rect2((svr.position-sr.position)/sr.size*sts,svr.size/sr.size*sts)])
		var skin_lock: bool=not game.character_owned(int(sk.get("char",-1))) or not game.skin_owned(i)
		if skin_lock and svr.size.y>1.0:
			_box(svr,Color(0,0,0,0.58))
			var slc:=sr.get_center()+Vector2(0,6)
			if view.has_point(slc+Vector2(0,-14)) and view.has_point(slc+Vector2(0,18)):
				_box(Rect2(slc+Vector2(-13,-2),Vector2(26,20)),Color(1,1,1,0.9))
				var sarc:=PackedVector2Array()
				for kk in range(13): sarc.append(slc+Vector2(cos(PI+PI*kk/12.0),sin(PI+PI*kk/12.0))*8.0+Vector2(0,-2))
				clean_ops.append(["line",sarc,Color(1,1,1,0.9),3.0])
				_box(Rect2(slc+Vector2(-2,5),Vector2(4,7)),Color(0,0,0,0.8))
		if whole:
			_text_center(RunText.text(String(sk.name),lang),Vector2(card.get_center().x,card.end.y-9),12,WHITE if on else MUTED)
			if on: draw_rect(Rect2(card.position.x+6,card.end.y-5,card.size.x-12,2),Color("b94a43"))
		return
	if (not pets and i>=game.lobby.CHARACTERS.size()) or (pets and i>=game.lobby.PETS.size()):
		if whole: _locked_slot(card,pets)
		else: _panel(vis,Color(0.04,0.045,0.047,0.80),Color(LINE,0.7),0)
		return
	var on: bool=(game.pet_equipped and game.pet_choice==i) if pets else (game.character_choice==i)
	_panel(vis,Color(0.10,0.11,0.115,0.94) if on else Color(0.05,0.055,0.06,0.80),RED if on and whole else LINE,0)
	var tex: Texture2D=null
	if pets: tex=pet_portraits[i] if pet_portraits.size()>i else null
	else: tex=portraits[i] if portraits.size()>i else null
	var r:=Rect2(card.position+Vector2(4,4),card.size-Vector2(8,30))
	var vr:=r.intersection(view)
	if tex and vr.size.y>1.0:
		var ts:=tex.get_size()
		clean_ops.append(["region",tex,vr,Rect2((vr.position-r.position)/r.size*ts,vr.size/r.size*ts)])
	var locked_card: bool=(not game.pet_owned(i)) if pets else (not game.character_owned(i))
	if locked_card and vr.size.y>1.0:
		_box(vr,Color(0,0,0,0.58))
		var lc:=r.get_center()+Vector2(0,6)
		if view.has_point(lc+Vector2(0,-14)) and view.has_point(lc+Vector2(0,18)):
			_box(Rect2(lc+Vector2(-13,-2),Vector2(26,20)),Color(1,1,1,0.9))
			var arc:=PackedVector2Array()
			for k in range(13): arc.append(lc+Vector2(cos(PI+PI*k/12.0),sin(PI+PI*k/12.0))*8.0+Vector2(0,-2))
			clean_ops.append(["line",arc,Color(1,1,1,0.9),3.0])
			_box(Rect2(lc+Vector2(-2,5),Vector2(4,7)),Color(0,0,0,0.8))
	if whole:
		var label: String=game.pet_name(i) if pets else game.character_name(i)
		var menu_open: bool = int(game.equip_menu_index)==i
		if not menu_open:
			_text_center(label,Vector2(card.get_center().x,card.end.y-9),11 if pets else 12,WHITE if on else MUTED)
		if game.premium_build():
			# a buy row under the name: "已拥有" when owned, price otherwise
			var row := Rect2(card.position.x - 4.0, card.end.y + 2.0, card.size.x + 8.0, 22.0)
			var owned_now := false
			match game.lobby_tab:
				0: owned_now = game.character_owned(i)
				1: owned_now = game.pet_owned(i)
				2: owned_now = game.skin_owned(i)
				3: owned_now = game.vehicle_is_owned(String(["vehicle_bike","vehicle_sport","vehicle_car","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"][clampi(i,0,6)]))
				4: owned_now = game.flame_owned()
			if owned_now:
				_box(row, Color(0.03,0.032,0.035,0.92))
				_text_center("已拥有" if String(lang).begins_with("zh") else "OWNED", row.get_center()+Vector2(0,5), 11, Color(C_BONE.r,C_BONE.g,C_BONE.b,0.55))
			else:
				_box(row, Color(0.03,0.032,0.035,0.92)); _box(Rect2(row.position,Vector2(3,row.size.y)),C_BLOOD)
				_text_center(game.card_price_text(game.lobby_tab, i), row.get_center()+Vector2(0,5), 11, C_ACID)
		if on: draw_rect(Rect2(card.position.x+6,card.end.y-5,card.size.x-12,2),Color("b94a43"))

func _locked_slot(rect: Rect2,pet:=false,skin:=false) -> void:
	_panel(rect,Color(0.04,0.045,0.047,0.80),Color(LINE,0.7),0)
	var c:=rect.get_center()+Vector2(0,-8)
	if skin:
		# T-shirt outline with a small padlock on it.
		var tee:=PackedVector2Array([c+Vector2(-7,-16),c+Vector2(-20,-9),c+Vector2(-15,0),c+Vector2(-10,-3),c+Vector2(-10,16),c+Vector2(10,16),c+Vector2(10,-3),c+Vector2(15,0),c+Vector2(20,-9),c+Vector2(7,-16),c+Vector2(4,-12),c+Vector2(-4,-12),c+Vector2(-7,-16)])
		draw_polyline(tee,Color(1,1,1,0.24),2.5,true)
		draw_rect(Rect2(c+Vector2(-6,2),Vector2(12,9)),Color(1,1,1,0.3))
		draw_arc(c+Vector2(0,2),4,PI,TAU,10,Color(1,1,1,0.3),2.0)
	elif pet:
		# Paw print.
		draw_circle(c+Vector2(0,8),11,Color(1,1,1,0.22))
		for o in [Vector2(-13,-6),Vector2(-5,-14),Vector2(5,-14),Vector2(13,-6)]: draw_circle(c+o,4.5,Color(1,1,1,0.22))
	else:
		# Padlock.
		draw_rect(Rect2(c+Vector2(-12,-2),Vector2(24,20)),Color(1,1,1,0.22))
		draw_arc(c+Vector2(0,-2),8,PI,TAU,16,Color(1,1,1,0.22),3.0)
	_text_center(ShopText.text(game.language_code,"coming"),Vector2(c.x,rect.end.y-10),10,Color(MUTED,0.8))

## Gear toggle with a visible state: bright ring + "ON" when equipped, dim + "OFF" when not.
## Settings gear in the lobby's top-right corner: same place and look as the in-run pause area.
func _lobby_settings_gear(r: Rect2) -> void:
	_panel(r, Color(0.06,0.07,0.075,0.92), WHITE, 1)
	_gear_icon(r.get_center(), 0.62, WHITE)


func _gear_button(r: Rect2,on: bool) -> void:
	# No ON/OFF text: an equipped item shows a gold ring, an unequipped one a white ring.
	var tint: Color = Color(1.0, 0.86, 0.4) if on else WHITE
	_panel(r, Color(0.06,0.065,0.07,0.9), tint, 1)
	_gear_icon(r.get_center(), 0.62, tint)


func _gear_icon(c: Vector2,k:=1.0,tint: Color=WHITE) -> void:
	# drawn through the clean layer: an immediate draw_arc sits BEHIND the panel fill and the
	# white gear comes out grey
	var ring := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		ring.append(c + Vector2(cos(a), sin(a)) * 13.0 * k)
	clean_ops.append(["line", ring, tint, 3.0 * k])
	for i in range(8):
		var a:=i*TAU/8.0
		clean_ops.append(["line", PackedVector2Array([c+Vector2(cos(a),sin(a))*13*k,c+Vector2(cos(a),sin(a))*19*k]), tint, 5.0*k])
	clean_ops.append(["circle", c, 5.0 * k, tint])

func _character_card(rect: Rect2,index: int) -> void:
	_panel(rect,Color("181b1c"),WHITE if game.character_choice==index else LINE,0)
	if portraits.size()>index and portraits[index]:
		clean_ops.append(["texture",portraits[index],Rect2(rect.position+Vector2(3,3),Vector2(rect.size.x-6,rect.size.y-61))])
	draw_rect(Rect2(rect.position+Vector2(3,rect.size.y-58),Vector2(rect.size.x-6,55)),Color(0.025,0.03,0.031,0.96))
	_text_center("男" if index==0 else "女",rect.position+Vector2(rect.size.x/2,rect.size.y-20),22,WHITE)
	if game.character_choice==index:
		draw_rect(Rect2(rect.position,Vector2(5,rect.size.y)),RED)
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,4)),WHITE)

func _hex_badge(center: Vector2,radius: float,value: String) -> void:
	var points:=PackedVector2Array()
	for i in range(6):
		var angle:=TAU*i/6.0; points.append(center+Vector2(cos(angle),sin(angle))*radius)
	draw_colored_polygon(points,Color(0.04,0.05,0.05,0.88)); points.append(points[0]); draw_polyline(points,LINE,1.5,true)
	_text_center(value,center+Vector2(0,6),17,WHITE)

## Armory overlay: the supply truck dims behind a dark sheet and the weapon card takes the
## centre of the screen. Step 1: panel, name and the three stat bars.
func _draw_armory() -> void:
	_box(Rect2(0, 0, 540, game.ui_h), Color(0, 0, 0, 0.72))
	_panel(Rect2(30, 90, 480, 700), Color(0.03, 0.034, 0.038, 0.97), Color(LINE, 1.0), 0)
	_bold_text("军械库" if String(game.language_code).begins_with("zh") else "ARMORY", Vector2(60, 132), 26, WHITE)
	_text("%d / %d" % [game.armory_index + 1, game.ARMORY_WEAPONS.size()], Vector2(430, 132), 15, MUTED)
	var id: String = game.armory_weapon_id()
	var stats: Dictionary = game.ARMORY_STATS.get(id, {})
	# the 3D weapon, rendered by main into a SubViewport
	if is_instance_valid(game.armory_viewport):
		var tex: Texture2D = game.armory_viewport.get_texture()
		if tex != null:
			clean_ops.append(["texture", tex, Rect2(40, 158, 460, 380)])
	# name
	_bold_text(id, Vector2(60, 552), 24, WHITE)
	# bars: damage / rate / magazine, normalised against the strongest weapon
	var dmg: float = float(stats.get("damage", 0.0))
	var rate: float = 1.0 / maxf(0.05, float(stats.get("rate", 0.3)))
	var mag: float = float(stats.get("mag", 1))
	var rows := [["伤害", dmg / 180.0, str(int(dmg))],
		["攻速", rate / (1.0 / 0.085), "%.1f/s" % rate],
		["容量", mag / 100.0, str(int(mag))]]
	var y: float = 596.0
	for row in rows:
		_text(String(row[0]), Vector2(60, y + 4), 15, MUTED)
		var bar := Rect2(110, y - 12, 280, 16)
		_box(bar, Color(0.10, 0.11, 0.12, 0.95), Color(0.25, 0.26, 0.27, 1.0), 1.0)
		var fill: float = clampf(float(row[1]), 0.0, 1.0)
		if fill > 0.0:
			_box(Rect2(bar.position.x + 1, bar.position.y + 1, (bar.size.x - 2) * fill, bar.size.y - 2), Color("ffd75e"), Color("ffd75e"), 0.0)
		_text(String(row[2]), Vector2(404, y + 4), 15, GOLD)
		y += 34.0
	# upgrade lives here now: level of this weapon plus the buy button
	var lv: int = game.armory_level()
	var lv_max: int = game.armory_max_level()
	if lv_max > 0:
		_text("升级  LV %d / %d" % [lv, lv_max], Vector2(60, 706), 15, GOLD)
		_button(game.ARMORY_UPGRADE, ("升级  %d 银币" % game.armory_price()) if lv < lv_max else "已满级", lv < lv_max)
	else:
		_text("升级  此枪不可升级", Vector2(60, 706), 15, MUTED)
		_button(game.ARMORY_UPGRADE, "不可升级", false)
	# nav
	_box(Rect2(60, 736, 60, 44), Color(0.10, 0.11, 0.12, 1.0), Color(LINE, 1.0), 0)
	_text_center("‹", Vector2(90, 764), 22, WHITE)
	_box(Rect2(420, 736, 60, 44), Color(0.10, 0.11, 0.12, 1.0), Color(LINE, 1.0), 0)
	_text_center("›", Vector2(450, 764), 22, WHITE)
	_button(Rect2(24, 24, 100, 48), "‹  " + game.localize("back"), false)

func _draw_shop() -> void:
	# The 3D window between the panels is a close-up of the gear being upgraded.
	draw_rect(Rect2(0,0,540,118),Color(0.02,0.025,0.026,0.80)); draw_rect(Rect2(0,594,540,366),Color(0.018,0.022,0.023,0.88))
	_button(Rect2(24,24,100,48),"‹  "+game.localize("back"),false)
	_bold_text(game.localize("shop_title"),Vector2(150,62),24,WHITE)
	var lang: String=game.language_code
	_text(ShopText.text(lang,"pick"),Vector2(151,91),13,MUTED)
	_button(Rect2(404,24,112,48),ShopText.text(lang,"cases"),true)
	# armory entry: a second button under the case button
	_box(game.ARMORY_BTN, Color(0.10, 0.11, 0.12, 0.95), Color(LINE, 1.0), 0)
	_text_center("军械库" if String(lang).begins_with("zh") else "ARMORY", game.ARMORY_BTN.get_center() + Vector2(0, 6), 16, WHITE)
	_wallet_shop_only(game.WALLET_SHOP)
	# plain entry into the store, next to the balance
	var sb: Rect2=game.SHOP_STORE_BTN
	var st:=StoreCatalog.text(game.language_code,"store").to_upper()+"  ›"
	var sw:=bold.get_string_size(st,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(22)).x
	_clean_text(bold,Vector2(sb.end.x-sw,sb.get_center().y+8),st,22,HILITE)
	_box(Rect2(sb.end.x-sw,sb.get_center().y+15,sw,3),Color(HILITE,0.85))
	if game.shop_items.is_empty(): return
	var item: Dictionary=game.shop_items[game.shop_index]
	var level: int=game.meta_upgrades.get(item.id,0); var cost: int=game.item_cost(item)
	var maxed: bool=level>=int(item.max_level); var affordable: bool=game.bank_silver>=cost
	# Item card: name, effect, level pips.
	# darker card so the gold level pips and the name read at a glance
	_panel(Rect2(30,642,480,128),Color(0.035,0.04,0.042,0.97),Color(LINE,1.0),0); draw_rect(Rect2(30,642,5,128),RED)
	_bold_text(ShopText.text(lang,item.name_key),Vector2(52,684),26,WHITE)
	_text(ShopText.text(lang,item.detail_key),Vector2(53,714),15,MUTED)
	for i in range(int(item.max_level)):
		# Bigger slots, drawn as hollow boxes when empty: a filled gold block and a bright
		# outline read clearly against the dark card even on a phone at arm's length.
		var pip:=Rect2(53+i*40,732,34,17)
		var filled: bool=i<level
		# White slot, filled yellow once that level is bought. Drawn through _box (the clean
		# layer) because the card background is a clean op too: an immediate draw_rect would
		# sit BEHIND it and come out washed out.
		_box(pip,Color("ffd75e") if filled else Color("f4f6f5"),Color("0b0e0e"),2.0)
	# level text sits just past the last pip and matches the pip height
	var lv_x: float=53.0+float(item.max_level)*40.0+14.0
	_text("LV %d / %d"%[level,item.max_level],Vector2(lv_x,747),16,GOLD)
	_text("%d / %d"%[game.shop_index+1,game.shop_items.size()],Vector2(452,684),13,MUTED)
	# Prev / upgrade / next.
	_button(Rect2(30,786,80,60),"‹",false)
	_button(Rect2(430,786,80,60),"›",false)
	var label: String
	if maxed: label=ShopText.text(lang,"max")
	else: label="%s  %d %s"%[ShopText.text(lang,"upgrade"),cost,ShopText.text(lang,"silver")]
	_button(Rect2(124,786,292,60),label,affordable and not maxed)
	# Quick-pick chips for every item.
	for i in range(game.shop_items.size()):
		var chip: Dictionary=game.shop_items[i]; var rect:=Rect2(30+i*60,862,56,44); var on: bool=i==game.shop_index
		_panel(rect,Color(0.12,0.13,0.13,0.95) if on else Color(0.07,0.075,0.08,0.90),RED if on else LINE,0)
		_chip_text(ShopText.text(lang,chip.name_key),rect,WHITE if on else MUTED)
	_text_center("PREMIUM / "+game.localize("planned"),Vector2(270,936),12,Color("cf8c75"))

func _draw_languages() -> void:
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.018,0.022,0.023,0.88))
	_bold_text(game.localize("language"),Vector2(30,76),30,WHITE); _text("20 LANGUAGES / NATIVE NAMES",Vector2(32,105),10,MUTED)
	_box(Rect2(26,117,108,3),PAINT_RED)
	for i in range(Localization.LANGUAGES.size()):
		var item: Dictionary=Localization.LANGUAGES[i]; var rect:=Rect2(30+(i%2)*245,150+floori(i/2.0)*62,235,50); var selected: bool=item.code==game.language_code
		_panel(rect,Color(0.12,0.13,0.13,0.95) if selected else Color(0.07,0.075,0.08,0.90),RED if selected else LINE,0)
		if selected: draw_rect(Rect2(rect.position,Vector2(3,rect.size.y)),RED)
		_text_center(item.native,rect.get_center()+Vector2(0,6),16,WHITE)
	_button(Rect2(66,840,408,60),game.localize("back"),true)

func _draw_gameover() -> void:
	var zh: bool=game.language_code.begins_with("zh")
	# The street where the run ended stays visible; darkness pools at the top (title) and
	# bottom (buttons) only.
	_box(Rect2(0,0,540,game.ui_h),Color(0.012,0.015,0.016,0.58))
	_box(Rect2(0,0,540,240),Color(0.012,0.015,0.016,0.35))
	_box(Rect2(0,560,540,400),Color(0.012,0.015,0.016,0.45))
	if game.new_record: _draw_new_record()
	else:
		# Red brush splash with white caps — the same section-title language as every menu.
		_section(Vector2(-1,128),game.localize("run_over"),32)
		_clean_center(font,Vector2(270,214),ProgressCatalog.text(game.language_code,"best").replace("%d",_grouped(game.best_distance)),15,MUTED)
	_panel(Rect2(54,238,432,330),Color(0.04,0.045,0.048,0.92),LINE,0)
	_box(Rect2(54,238,4,330),PAINT_RED) # single blood-red edge, like the reference's red marks
	_stat(game.localize("distance"),"%d m"%int(game.distance),Vector2(80,272)); _stat(game.localize("kills"),"%d"%game.kills,Vector2(300,272))
	# Kill breakdown: tougher zombies are worth more coins.
	var lang: String=game.language_code
	var y:=348.0
	for kind in ["banshee","brute","jockey","runner","walker"]:
		var n: int=int(game.kill_counts.get(kind,0))
		if n<=0: continue
		clean_ops.append(["text",font,Vector2(80,y),ShopText.text(lang,"k_"+kind),_scaled(16),Color(1,1,1,0.75)])
		clean_ops.append(["text",font,Vector2(262,y),"× %d"%n,_scaled(16),MUTED])
		var coins:="+%d"%int(game.kill_coins.get(kind,0))
		clean_ops.append(["text",font,Vector2(458-font.get_string_size(coins,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(16)).x,y),coins,_scaled(16),GOLD])
		y+=21.0
	clean_ops.append(["text",font,Vector2(80,y),GameText.text(lang,"survival"),_scaled(16),Color(1,1,1,0.75)])
	var surv:="+%d"%game.survival_bonus
	clean_ops.append(["text",font,Vector2(458-font.get_string_size(surv,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(16)).x,y),surv,_scaled(16),GOLD])
	draw_rect(Rect2(80,y+12,378,1),Color(1,1,1,0.12))
	_text(GameText.text(lang,"total"),Vector2(80,y+38),16,MUTED)
	var total:="+%d"%(game.last_reward+game.run_double_bonus)
	clean_ops.append(["text",bold,Vector2(80,y+78),total,_scaled(36),GOLD])
	if game.run_double_bonus>0:
		var tw: float=bold.get_string_size(total,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(36)).x
		clean_ops.append(["text",bold,Vector2(88+tw,y+78),"200%",_scaled(24),HILITE])
	_text(GameText.text(lang,"wallet")+"  %d"%game.bank_coins,Vector2(80,y+104),14,MUTED)
	if game.last_reward>0:
		var mode:="done" if game.run_double_bonus>0 else ("busy" if game.ad_pending=="run_double" else "ready")
		_ad_x2_button(game.gameover_double_rect(),mode)
	if not game.revive_used:
		_draw_revive_button(Rect2(66,586,408,70))
		# Just the facts next to the revive (no hard sell): a fresh record, or how close it was.
		var nudge:=""
		if game.new_record: nudge=ProgressCatalog.text(lang,"rec_push").replace("%d",_grouped(int(game.distance)))
		elif game.run_start_best>0 and game.record_metres_left()>0 and game.record_metres_left()<=maxi(150,int(game.run_start_best*0.25)):
			nudge=ProgressCatalog.text(lang,"rec_close").replace("%d",str(game.record_metres_left()))
		if nudge!="": _clean_center(bold,Vector2(270,580),nudge,17,HILITE)
	else:
		_text_center("本局复活已使用" if zh else "REVIVE ALREADY USED THIS RUN",Vector2(270,628),16,MUTED)
	_button(Rect2(66,672,408,66),ShopText.text(game.language_code,"to_lobby"),true)
	_button(Rect2(66,758,408,54),game.localize("shop"),false)
	_share_button(game.SHARE_RECT,lang)
	if game.share_toast>0.0: _clean_center(bold,Vector2(270,game.SHARE_RECT.end.y+24),ExtraText.text(lang,"copied"),14,Color(HILITE,minf(1.0,game.share_toast*2.0)))
	if game.new_record: _record_confetti()
	_toast(84) # keyboard retry (Enter) with no cans explains itself here

func _draw_pause() -> void:
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.015,0.019,0.020,0.80))
	_bold_text(game.localize("paused"),Vector2(114,370),42,WHITE)
	_box(Rect2(110,387,94,3),PAINT_RED)
	# Settings leads the list; restarting mid-run is free and says so.
	# Keep running sits on top, so getting back into the run is the first thing under the thumb.
	_button(Rect2(66,468,408,68),game.localize("resume"),true)
	_button(Rect2(66,552,408,58),game.localize("settings"),false)
	_button(Rect2(66,626,408,58),game.localize("reload_auto") if game.auto_reload else game.localize("reload_manual"),false)
	_button(Rect2(66,700,408,58),game.localize("shop"),false)
	_button(Rect2(66,774,408,58),game.localize("restart"),false)
	_button(Rect2(66,848,408,58),GameText.text(game.language_code,"main_menu"),false)

func _draw_revive_button(rect: Rect2) -> void:
	# Rewarded-ad revive: explicit reward and AD label, presented as a restrained brass console.
	var zh: bool=game.language_code.begins_with("zh")
	var ad_status: String=game.revival_ads.status if is_instance_valid(game.revival_ads) else "desktop"
	var busy: bool=game.revive_pending or ad_status=="showing"
	var pulse:=0.5+0.5*sin(Time.get_ticks_msec()/1000.0*4.0)
	var bg:=Color("302817",0.98) if not busy else Color("201e19",0.96)
	_box(Rect2(rect.position+Vector2(0,4),rect.size),Color(0,0,0,0.5))
	_box(rect,bg)
	_frame(rect,Color(BRASS_LIGHT,0.68) if not busy else Color(1,1,1,0.16),1.0)
	_box(Rect2(rect.position,Vector2(3,rect.size.y)),BRASS)
	if not busy: _frame(rect.grow(2),Color(BRASS_LIGHT,0.16+0.18*pulse),1.0)
	_draw_heart_icon(rect.position+Vector2(38,rect.size.y*0.5),BRASS_LIGHT if not busy else MUTED)
	var label:=("看广告复活" if zh else "WATCH AD TO REVIVE")
	var rv: Dictionary=game.REVIVES[mini(game.revive_count,game.REVIVES.size()-1)]
	var pct:=int(float(rv.hp)*100.0); var secs:=int(rv.invuln)
	var sub:=("恢复 %d%% 生命 · 无敌 %d 秒"%[pct,secs] if zh else "%d%% HP · %ds invincible"%[pct,secs])
	if busy: label=("广告播放中…" if zh else "AD PLAYING…"); sub=""
	elif ad_status=="loading": sub=("广告加载中…" if zh else "Loading ad…")
	elif ad_status=="unavailable": sub=("广告暂不可用，点击重试" if zh else "Ad unavailable — tap to retry")
	var ink: Color=BRASS_LIGHT if not busy else MUTED
	clean_ops.append(["text",bold,rect.position+Vector2(70,44 if sub.is_empty() else 36),label,26,ink])
	if not sub.is_empty(): clean_ops.append(["text",font,rect.position+Vector2(70,58),sub,14,Color(ink.r,ink.g,ink.b,0.8)])
	var tag:=Rect2(rect.end.x-58,rect.position.y+20,42,28)
	_box(tag,Color("100e0a",0.95))
	_frame(tag,Color(BRASS_LIGHT,0.55),1.0)
	var aw:=bold.get_string_size("AD",HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	clean_ops.append(["text",bold,tag.get_center()+Vector2(-aw/2,6),"AD",16,BRASS_LIGHT if not busy else MUTED])

func _ad_x2_button(r: Rect2,mode:="ready") -> void:
	var lang: String=game.language_code
	if mode=="done":
		_box(r,Color(1,1,1,0.045))
		var cc:=r.position+Vector2(26,r.size.y*0.5)
		clean_ops.append(["line",PackedVector2Array([cc+Vector2(-9,0),cc+Vector2(-3,7),cc+Vector2(10,-8)]),HILITE,3.0])
		_clean_text(bold,r.position+Vector2(46,r.size.y*0.5+8),ProgressCatalog.text(lang,"doubled"),20,Color(1,1,1,0.58),false)
		return
	var busy: bool=mode=="busy"
	var bg:=Color("332a18",0.98) if not busy else Color("211f1a",0.96)
	_box(Rect2(r.position+Vector2(0,4),r.size),Color(0,0,0,0.5))
	_box(r,bg)
	_frame(r,Color(BRASS_LIGHT,0.76) if not busy else Color(1,1,1,0.18),1.0)
	_box(Rect2(r.position,Vector2(r.size.x,2)),BRASS)
	var c:=r.position+Vector2(28,r.size.y*0.5)
	var disc:=PackedVector2Array()
	for i in range(20): disc.append(c+Vector2(cos(TAU*i/20.0),sin(TAU*i/20.0))*14.0)
	clean_ops.append(["poly",disc,BRASS_LIGHT])
	clean_ops.append(["poly",PackedVector2Array([c+Vector2(-5,-8),c+Vector2(9,0),c+Vector2(-5,8)]),INK_DARK])
	var label: String=ProgressCatalog.text(lang,"ad_playing" if busy else "ad_x2")
	var size:=22
	while bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x>r.size.x-64 and size>12: size-=1
	_clean_text(bold,Vector2(r.position.x+52,r.get_center().y+_scaled(size)*0.36),label,size,BRASS_LIGHT if not busy else MUTED,false)
	var tag:=Rect2(r.end.x-30,r.position.y-9,34,20)
	_box(tag,INK_DARK)
	var aw3: float = bold.get_string_size("AD",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	_clean_text(bold,Vector2(tag.get_center().x-aw3*0.5,tag.get_center().y+4),"AD",13,BRASS_LIGHT,false)

func _swap_ad_button(r: Rect2,busy:=false) -> void:
	_box(r,Color(1,1,1,0.10) if not busy else Color(1,1,1,0.04))
	_box(Rect2(r.position,Vector2(r.size.x,2)),Color(HILITE,0.8))
	var c:=r.get_center()+Vector2(0,2)
	var arc:=PackedVector2Array()
	for i in range(15):
		var a: float=-PI*0.35+TAU*0.78*i/14.0
		arc.append(c+Vector2(cos(a),sin(a))*10.0)
	var col: Color=HILITE if not busy else Color(HILITE,0.4)
	clean_ops.append(["line",arc,col,3.0])
	var tip: Vector2=arc[arc.size()-1]
	clean_ops.append(["poly",PackedVector2Array([tip+Vector2(-1,-7),tip+Vector2(8,1),tip+Vector2(-3,6)]),col])
	var tag:=Rect2(r.end.x-22,r.position.y-8,26,16)
	_box(tag,HILITE)
	# plain text, no shadow: at 11 px the offset copy read as a double "AD"
	var aw2: float = bold.get_string_size("AD",HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	_clean_text(bold,Vector2(tag.get_center().x-aw2*0.5,tag.get_center().y+4),"AD",11,INK_DARK,false)

## Quiet secondary button: dark fill, thin light top edge, white label.
func _plain_button(r: Rect2,label: String) -> void:
	_box(Rect2(r.position+Vector2(0,4),r.size),Color(0,0,0,0.45))
	_box(r,Color(0.16,0.16,0.16,1.0))
	_box(Rect2(r.position,Vector2(r.size.x,2)),Color(1,1,1,0.35))
	_clean_center(bold,Vector2(r.get_center().x,r.get_center().y+8),label,22,WHITE)

func _draw_heart_icon(c: Vector2,col:=WHITE) -> void:
	var shape:=_heart_points(c,40)
	clean_ops.append(["poly",shape,col])
	var outline:=shape.duplicate(); outline.append(shape[0]); clean_ops.append(["line",outline,col,2.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-7,0),c+Vector2(7,0)]),Color("e23a35") if col!=WHITE else WHITE,3.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(0,-7),c+Vector2(0,7)]),Color("e23a35") if col!=WHITE else WHITE,3.0])

func _stat(label: String,value: String,pos: Vector2) -> void:
	# Results must be easy to read: drawn without the worn-paint erosion. Small quiet label,
	# big confident number — the Dead Island results hierarchy.
	clean_ops.append(["text",font,pos,label.to_upper(),_scaled(14),MUTED])
	clean_ops.append(["text",bold,pos+Vector2(0,48),value,_scaled(44),WHITE])

func _icon_button(rect: Rect2,label: String) -> void:
	_panel(rect,Color(0.02,0.025,0.026,0.80),Color(0.32,0.34,0.34,0.65),0); _text_center(label,rect.get_center()+Vector2(0,4),10,WHITE)

## Same rect always picks the same stroke, different rects get different strokes.
func _pick(list: Array[Texture2D],rect: Rect2) -> Texture2D:
	return list[absi(int(rect.position.x*7.0+rect.position.y*13.0+rect.size.x))%list.size()]

func _button(rect: Rect2,label: String,primary: bool) -> void:
	# Flat, tactile survival-game controls. Red is reserved for the single primary action;
	# secondary actions stay charcoal with restrained off-white borders.
	var size:=_scaled(30 if rect.size.y>=56 else 24)
	var f: Font=bold if primary else font
	while f.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-28 and size>14: size-=1
	var width:=f.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_box(Rect2(rect.position+Vector2(0,4),rect.size),Color(0,0,0,0.48))
	if primary:
		_box(rect,Color("782c29",0.98))
		_box(Rect2(rect.position,Vector2(4,rect.size.y)),Color("c64a43"))
		_box(Rect2(rect.position+Vector2(4,0),Vector2(rect.size.x-4,2)),Color("df7770",0.75))
		clean_ops.append(["text",f,rect.get_center()+Vector2(-width/2,size*0.36),label,size,WHITE])
	else:
		_box(rect,Color("171a1b",0.96))
		_frame(rect,Color(1,1,1,0.20),1.0)
		_box(Rect2(rect.position,Vector2(rect.size.x,1)),Color(1,1,1,0.12))
		clean_ops.append(["text",f,rect.get_center()+Vector2(-width/2,size*0.36),label,size,Color("e2dfd7")])

func _brush_underline(rect: Rect2,color:=PAINT_RED) -> void:
	draw_texture_rect(_pick(brush_line,rect),rect,false,color)

func _panel(rect: Rect2,bg: Color,border: Color,radius: int) -> void:
	# Clean charcoal plates with hairline separators. No repeated brush texture on every panel.
	_box(rect,C_PLATE if bg.a>0.5 else bg)
	var edge: Color=Color(1,1,1,0.12)
	if border.is_equal_approx(RED) or border.is_equal_approx(PAINT_RED):
		edge=Color("b84a43",0.85)
	elif border.a>0.05 and not border.is_equal_approx(LINE):
		edge=Color(border,0.48)
	_frame(rect,edge,1.0)
	# Dead Island 2 plate dressing: a bone hairline along the top and a short red rule at the
	# left corner, so every panel reads as the same piece of kit.
	_box(Rect2(rect.position,Vector2(rect.size.x,1)),Color(C_BONE,0.10))
	if rect.size.x >= 320.0:
		# corner rules only on dialogs: on a card they read as stubby half lines
		_box(Rect2(rect.position,Vector2(64,3)),C_BLOOD)
		_box(Rect2(rect.position+Vector2(rect.size.x-64,0),Vector2(64,3)),C_ACID)

func _text(value: String,pos: Vector2,size: int,color: Color) -> void:
	size=maxi(size,12); _string(font,pos,value,size,color)

func _bold_text(value: String,pos: Vector2,size: int,color: Color) -> void:
	size=maxi(size,12); _string(bold,pos,value,size,color)

func _text_center(value: String,pos: Vector2,size: int,color: Color) -> void:
	# Big centred text is a headline: use the heavy poster face.
	size=maxi(size,12); var f: Font=bold if size>=30 else font
	var width:=f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	_string(f,pos-Vector2(width/2,0),value,size,color)

func _text_right(value: String,pos: Vector2,size: int,color: Color) -> void:
	size=maxi(size,12); var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	_string(font,pos-Vector2(width,0),value,size,color)

func _multiline(value: String,pos: Vector2,width: float,size: int,color: Color) -> void:
	size=_scaled(maxi(size,13)); draw_multiline_string(font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,3,color)

## ---- Wallet, store, offers, check-in, missions -------------------------------------------------
## Same visual language as the rest of the game (brush-painted panels and buttons, worn paint):
## red brush slabs for section titles, dark painted panels, thin white outlines for what is
## selected or ready, yellow for highlights and deals, muted painted tiles. No rounded boxes.
const VOUCHER_COL:=Color("e8ddd0")
const HILITE:=Color("c9a24b")          # aged gold highlight (deals, today, ready) — not pure yellow
const INK_DARK:=Color("16130d")        # dark text on gold
const PANEL_TINT:=Color(0.055,0.06,0.065,0.94)

static func _grouped(n: int) -> String:
	var digits:=str(absi(n)); var out:=""
	for i in range(digits.length()):
		if i>0 and (digits.length()-i)%3==0: out+=","
		out+=digits[i]
	return out

static func _compact(n: int) -> String:
	if n>=1000000000: return "%.2fB"%(n/1000000000.0)
	if n>=1000000: return "%.2fM"%(n/1000000.0)
	return _grouped(n)

static func _clock(seconds: int) -> String:
	return "%02d:%02d:%02d"%[seconds/3600,(seconds/60)%60,seconds%60]

## Can refill countdown. Hours stay unpadded ("0:59:00") because a full refill never exceeds a
## couple of hours and the shorter string fits under the lobby's can counter.
static func _clock_refill(seconds: int) -> String:
	return "%d:%02d:%02d"%[seconds/3600,(seconds/60)%60,seconds%60]

func _clean_text(f: Font,pos: Vector2,value: String,size: int,color: Color,shadow:=true) -> void:
	size=_scaled(size)
	if shadow: clean_ops.append(["text",f,pos+Vector2(1,2),value,size,Color(0,0,0,0.6)])
	clean_ops.append(["text",f,pos,value,size,color])

func _clean_center(f: Font,center: Vector2,value: String,size: int,color: Color,shadow:=true) -> void:
	var w:=f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	_clean_text(f,Vector2(center.x-w/2,center.y),value,size,color,shadow)

## Flat fill (only for full-screen dimming and scroll masks).
## Dead Island 2 style palette: bone white text, blood red for the selection, acid yellow for
## currency, near-black plates with a hairline edge.
const C_BONE := Color(0.96, 0.94, 0.88)
const C_BLOOD := Color(0.72, 0.10, 0.12)
const C_ACID := Color(0.95, 0.72, 0.02)
const C_TEAL := Color(0.36, 0.62, 0.64)
const C_PLATE := Color(0.028, 0.030, 0.033, 0.88)


## A red painted banner behind the selected row, with a skewed end so it reads as a brush stroke.
func _blood_banner(r: Rect2) -> void:
	# A flat red slab with one square cut on the left: the skewed polygon version came out as a
	# hard-edged, jagged diamond.
	var slab := Rect2(r.position.x - 10.0, r.position.y + 2.0, r.size.x + 18.0, r.size.y - 4.0)
	_box(slab, C_BLOOD)
	# a slightly darker wedge on the left edge so it does not read as a plain rectangle
	_box(Rect2(slab.position.x, slab.position.y, 5.0, slab.size.y), Color(0.48, 0.05, 0.06))
	# crisp bottom rule
	_box(Rect2(slab.position.x, slab.end.y - 2.0, slab.size.x, 2.0), Color(0.95, 0.24, 0.22))

func _box(rect: Rect2,bg: Color,border:=Color(0,0,0,0),width:=0,radius:=0) -> void:
	var sb:=StyleBoxFlat.new(); sb.bg_color=bg; sb.set_corner_radius_all(radius)
	if width>0: sb.border_color=border; sb.set_border_width_all(width)
	clean_ops.append(["box",sb,rect])

## Dark painted panel with ragged brush edges.
func _paint(rect: Rect2,col:=PANEL_TINT) -> void:
	# A quiet dark surface; visual texture belongs in the background, not on every control.
	_box(rect,col)
	_box(Rect2(rect.position,Vector2(rect.size.x,1)),Color(1,1,1,0.10))
	_box(Rect2(rect.position,Vector2(3,rect.size.y)),Color("8e3934",0.62))

func _slab(rect: Rect2,col: Color) -> void:
	# Selected tab / active marker: a narrow red field rather than a full brush splash.
	_box(rect,Color(col.r*0.42,col.g*0.42,col.b*0.42,0.92))
	_box(Rect2(rect.position,Vector2(rect.size.x,3)),col)
	_box(Rect2(rect.position,Vector2(3,rect.size.y)),col)

func _frame(rect: Rect2,col:=WHITE,w:=2.0) -> void:
	clean_ops.append(["line",PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.position]),col,w])

## Brush-stroke label sized to its text; returns where it went.
func _tag(pos: Vector2,label: String,bg:=PAINT_RED,fg:=WHITE,size:=15) -> Rect2:
	var w:=bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	var r:=Rect2(pos,Vector2(w+22,_scaled(size)+12))
	_box(r,bg)
	_clean_text(bold,r.position+Vector2(12,r.size.y-7),label,size,fg,false)
	return r

## Four L-shaped corner ticks. The cheapest way to make a plain rectangle read as game UI.
func _brackets(r: Rect2, arm := 10.0, col := C_BONE, w := 2.0) -> void:
	var a := arm
	var c := Color(col.r, col.g, col.b, 0.85)
	clean_ops.append(["line", PackedVector2Array([r.position, r.position + Vector2(a, 0)]), c, w])
	clean_ops.append(["line", PackedVector2Array([r.position, r.position + Vector2(0, a)]), c, w])
	clean_ops.append(["line", PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x - a, r.position.y)]), c, w])
	clean_ops.append(["line", PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + a)]), c, w])
	clean_ops.append(["line", PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x + a, r.end.y)]), c, w])
	clean_ops.append(["line", PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - a)]), c, w])
	clean_ops.append(["line", PackedVector2Array([r.end, r.end - Vector2(a, 0)]), c, w])
	clean_ops.append(["line", PackedVector2Array([r.end, r.end - Vector2(0, a)]), c, w])


## Draws a label with extra letter spacing. Godot has no tracking property, so each glyph is
## placed by hand: that wide condensed look is most of the reference UI's character.
func _tracked_text(fnt: Font, pos: Vector2, text: String, size: int, col: Color, spacing := 1.0) -> void:
	var x := pos.x
	var sc := _scaled(size)
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		clean_ops.append(["text", fnt, Vector2(x, pos.y), ch, sc, col])
		x += fnt.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sc).x + spacing


func _tracked_width(fnt: Font, text: String, size: int, spacing := 1.0) -> float:
	var w := 0.0
	var sc := _scaled(size)
	for i in range(text.length()):
		w += fnt.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, sc).x + spacing
	return w


func _section(pos: Vector2,label: String,size:=22) -> void:
	var t:=label.to_upper()
	var spacing:=1.2
	var w:=_tracked_width(bold,t,size,spacing)
	if pos.x<0: pos.x=270.0-w/2.0
	# Title sits inside the panel, bone white with a short red underline. The red plate version
	# spilled past the panel edge and read as a label glued on top.
	_tracked_text(bold,pos,t,size,C_BONE,spacing)
	_box(Rect2(pos.x, pos.y + 7.0, w, 3.0), C_BLOOD)

func _ghost_button(rect: Rect2,label: String,col:=WHITE) -> void:
	_box(rect,Color("111516",0.82))
	_frame(rect,Color(col,0.42),1.0)
	var size:=22
	while bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x>rect.size.x-16 and size>12: size-=1
	_clean_center(bold,Vector2(rect.get_center().x,rect.get_center().y+_scaled(size)*0.36),label.to_upper(),size,Color(col,0.78))

func _plus_button(rect: Rect2) -> void:
	_frame(rect,Color(1,1,1,0.85),2.0)
	var c:=rect.get_center(); var h:=rect.size.x*0.26
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-h,0),c+Vector2(h,0)]),WHITE,3.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(0,-h),c+Vector2(0,h)]),WHITE,3.0])

## Can energy, coin, silver and voucher balances with a + beside each (all open the store).
## Plate behind the wallet row, measured from the row itself: the store header used a
## fixed bar that cut the + buttons and the last balance off at the screen edge.
func _wallet_plate(origin: Vector2,k:=1.0) -> void:
	var ts:=int(round(24*k))
	var inf: bool=game.infinite_resources()
	var cans: String="∞/∞" if inf else "%d/%d"%[game.stamina.value,game.stamina.CAP]
	game.wallet_text_w=Vector4(
		bold.get_string_size(cans,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,
		bold.get_string_size("∞" if inf else _compact(game.bank_coins),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,
		bold.get_string_size("∞" if inf else _compact(game.bank_silver),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,
		bold.get_string_size("∞" if game.infinite_resources() else _compact(game.bank_vouchers),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x)
	var w: Dictionary=game.wallet_layout(origin,k)
	var right: float=(w.v_plus as Rect2).end.x+12.0*k
	var left: float=origin.x-12.0*k
	var plate:=Rect2(Vector2(left,origin.y-9.0*k),Vector2(right-left,52.0*k))
	_box(plate,Color(0.035,0.037,0.041,0.92))
	_frame(plate,Color(1,1,1,0.10),1.0)

func _wallet(origin: Vector2,plus:=true,k:=1.0) -> void:
	var cans: String="∞/∞" if game.infinite_resources() else "%d/%d"%[game.stamina.value,game.stamina.CAP]
	var infw: bool = game.infinite_resources()
	var coins:=("∞" if infw else _compact(game.bank_coins)); var silver:=("∞" if infw else _compact(game.bank_silver)); var vouchers:=("∞" if infw else _compact(game.bank_vouchers))
	var ts:=int(round(24*k))
	game.wallet_text_w=Vector4(bold.get_string_size(cans,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,bold.get_string_size(coins,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,bold.get_string_size(silver,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,bold.get_string_size(vouchers,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x)
	var w: Dictionary=game.wallet_layout(origin,k)
	if w.has("can_icon"):
		clean_ops.append(["texture",can_tex,w.can_icon])
		_clean_text(bold,w.can_text,cans,ts,WHITE)
	clean_ops.append(["texture",silver_tex,w.coin_icon])
	_clean_text(bold,w.coin_text,silver,ts,Color(0.66,0.70,0.74))
	clean_ops.append(["texture",coin_tex,w.silver_icon])
	_clean_text(bold,w.silver_text,coins,ts,GOLD)
	clean_ops.append(["texture",voucher_tex,w.v_icon])
	_clean_text(bold,w.v_text,vouchers,ts,VOUCHER_COL)
	if plus:
		if w.has("can_plus"): _plus_button(w.can_plus)
		if w.has("coin_plus"): _plus_button(w.coin_plus)
		if w.has("silver_plus"): _plus_button(w.silver_plus)
		if w.has("v_plus"): _plus_button(w.v_plus)

## Shop ONLY: silver + gold (fits left of the shop button, nothing clips).
func _wallet_shop_only(origin: Vector2,plus:=true,k:=1.0) -> void:
	var infw2: bool = game.infinite_resources()
	var coins:=("∞" if infw2 else _compact(game.bank_coins)); var silver:=("∞" if infw2 else _compact(game.bank_silver))
	var ts:=int(round(24*k))
	game.wallet_text_w=Vector4(bold.get_string_size(silver,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,bold.get_string_size(coins,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x,0,0)
	var w: Dictionary=game.wallet_layout_shop(origin,k)
	clean_ops.append(["texture",silver_tex,w.coin_icon])
	_clean_text(bold,w.coin_text,silver,ts,Color(0.66,0.70,0.74))
	clean_ops.append(["texture",coin_tex,w.silver_icon])
	_clean_text(bold,w.silver_text,coins,ts,GOLD)
	if plus: _plus_button(w.coin_plus); _plus_button(w.silver_plus)

## How long until the can balance is back at CAP. Centred under the lobby's can counter so the two
## read as one block, and hidden while already full. Bigger than the old corner label so the
## hh:mm:ss digits stay legible at arm's length.
func _energy_refill_timer(origin: Vector2,k:=1.0) -> void:
	var secs: int=game.stamina.seconds_to_full()
	if secs<=0: return
	# Same string and size as _wallet() so the countdown is centred on the digits above it.
	var ts: int=roundi(24*k)
	var cans: String="∞/∞" if game.infinite_resources() else "%d/%d"%[game.stamina.value,game.stamina.CAP]
	var cx: float=origin.x+42*k+bold.get_string_size(cans,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ts)).x*0.5
	var txt: String=_clock_refill(secs)
	# Cap the size: at the "large" text setting the top bar has no room for a second full-size line.
	var fs: int=mini(18,_scaled(18))
	var tw: float=bold.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	clean_ops.append(["text",bold,Vector2(cx-tw*0.5,origin.y+50*k),txt,fs,Color(1,1,1,0.8)])

func _toast(y: float) -> void:
	if game.store_toast<=0.0 or game.store_toast_text.is_empty(): return
	var a: float=minf(1.0,game.store_toast*2.0)
	var msg: String=game.store_toast_text
	var tw: float=bold.get_string_size(msg,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(18)).x+48.0
	var r:=Rect2(270-tw/2,y,tw,46)
	_paint(r,Color(0.04,0.045,0.05,0.96*a)); _slab(Rect2(r.position.x,r.position.y,6,r.size.y),Color(HILITE,a))
	_clean_center(bold,Vector2(270,y+30),msg,18,Color(1,1,1,a))

## Screen header shared by the store and missions pages: back button, big title, red underline.
func _page_header(title: String) -> void:
	_button(Rect2(24,24,100,48),"‹  "+game.localize("back"),false)
	_clean_text(bold,Vector2(150,64),title.to_upper(),34,WHITE)
	_box(Rect2(146,72,76,3),PAINT_RED)

func _di_backdrop() -> void:
	# Restrained near-black backdrop with a warm lower fade; preserve subtle atmosphere,
	# but do not bury the screen in repeated paint textures.
	draw_rect(Rect2(0,0,540,game.ui_h),Color("111313",1.0))
	draw_polygon(PackedVector2Array([Vector2(0,0),Vector2(540,0),Vector2(540,game.ui_h),Vector2(0,game.ui_h)]),
		PackedColorArray([Color("191918"),Color("121414"),Color("090b0b"),Color("0d0e0d")]))
	if grunge_tex: draw_texture_rect(grunge_tex,Rect2(0,0,540,game.ui_h),true,Color(1,1,1,0.025))
	draw_rect(Rect2(0,0,540,112),Color(0,0,0,0.32))
	draw_rect(Rect2(0,game.ui_h-30,540,30),Color(0,0,0,0.28))

func _di_tag(pos: Vector2,label: String,size:=20,angle:=-0.045) -> Rect2:
	var t:=label.to_upper()
	var w:=bold.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	var r:=Rect2(Vector2.ZERO,Vector2(w+26,_scaled(size)+16))
	clean_ops.append(["xf",pos,angle])
	_box(r,Color("17191a",0.96))
	_box(Rect2(0,0,4,r.size.y),PAINT_RED)
	_clean_text(bold,Vector2(13,r.size.y-8),t,size,WHITE,false)
	clean_ops.append(["xf0"])
	return Rect2(pos,r.size)

func _di_label(pos: Vector2,label: String,col:=Color(1,1,1,0.55)) -> void:
	clean_ops.append(["text",bold,pos,label.to_upper(),_scaled(13),col])

## Crisp row: flat translucent dark, optional coloured frame for the active / featured one.
func _di_row(r: Rect2,_frame_col:=Color(0,0,0,0)) -> void:
	# soft dark band that fades out to the right, no outline (like the reference's notices)
	clean_ops.append(["grad",PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]),
		PackedColorArray([Color(0,0,0,0.62),Color(0,0,0,0.18),Color(0,0,0,0.18),Color(0,0,0,0.62)])])

## Price / action box: white-outlined (yellow for deals), greyed when not available.
func _di_price(r: Rect2,label: String,mode:="buy") -> void:
	# Aged brass is a restrained accent, not a bright yellow slab.
	if mode=="off":
		_box(r,Color(1,1,1,0.045))
		_box(Rect2(r.position,Vector2(r.size.x,1)),Color(1,1,1,0.12))
		_clean_center(bold,Vector2(r.get_center().x,r.get_center().y+7),label,18,Color(1,1,1,0.38))
		return
	_box(Rect2(r.position+Vector2(0,3),r.size),Color(0,0,0,0.48))
	_box(r,Color("292316",0.98))
	_frame(r,Color(BRASS_LIGHT,0.82),1.0)
	_box(Rect2(r.position,Vector2(r.size.x,2)),Color(BRASS_LIGHT,0.72))
	var size:=24
	while bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x>r.size.x-16 and size>14: size-=1
	_clean_center(bold,Vector2(r.get_center().x,r.get_center().y+_scaled(size)*0.36),label,size,BRASS_LIGHT)

const KIND_TILE:={"cans":Color("6f6240"),"coins":Color("5b6638"),"silver":Color("4a5a68"),"vouchers":Color("7e3447"),"bundle":Color("3d6766"),"offer":Color("7a5a1c"),"vehicle":Color("2e5a6a"),"character":Color("6a3e3e"),"pet":Color("3e5a3a"),"skin":Color("5a4a6a")}

func _draw_store() -> void:
	var lang: String=game.language_code
	_di_backdrop()
	var view: Rect2=game.store_view_rect()
	list_clip.position=view.position; list_clip.size=view.size
	var cur: String=game.store_currency if not game.store_currency.is_empty() else StoreCatalog.device_currency()
	# rows go into the clipped list layer
	var saved:=clean_ops; clean_ops=list_ops
	for it in game.store_layout():
		var r: Rect2=game.store_screen_rect(it)
		if not r.intersects(view): continue
		if it.has("header"):
			var key: String={"offer":"limited","bundle":"bundles","pass":"passes","vehicle":"vehicles","character":"characters","pet":"pets","skin":"skins","cans":"can_packs","coins":"coin_packs","silver":"silver_packs","vouchers":"voucher_packs"}[it.header]
			_di_label(r.position+Vector2(2,22),StoreCatalog.text(lang,key),HILITE if it.header=="offer" else Color(1,1,1,0.55))
		elif it.has("can_ad"): _store_can_ad(r,lang)
		else: _store_row(r,it.pack,cur,lang)
	var end_y: float=game.STORE_TOP-game.store_scroll+game.store_content_height()-30.0
	if end_y<view.end.y: _clean_center(font,Vector2(270,end_y),StoreCatalog.text(lang,"note"),12,Color(1,1,1,0.45))
	clean_ops=saved
	# hover: the row clips its blurb, so the full ability text pops over it
	var mp: Vector2=hover_point
	if mouse_hover and view.has_point(mp):
		for it2 in game.store_layout():
			if not it2.has("pack"): continue
			var pk: Dictionary=it2.pack
			if not (game.store_screen_rect(it2) as Rect2).has_point(mp): continue
			match String(pk.get("kind","")):
				"vehicle":
					var vk: String=String(pk.get("name","bike"))
					_info_tip(mp,StoreCatalog.text(lang,vk),StoreCatalog.text(lang,"vehicles"),StoreCatalog.text(lang,vk+"_desc"))
				"character":
					var perk: String=String(pk.get("perk",""))
					_info_tip(mp,game.character_name(int(pk.get("char",0))),ShopText.text(lang,"chars"),
						RunText.text(perk,lang) if perk!="" else ExtraText.text(lang,"char_locked"))
				"pet":
					_info_tip(mp,game.pet_name(int(pk.get("pet",0))),ShopText.text(lang,"pets"),ExtraText.text(lang,"pet_locked"))
				"skin":
					var sk3: Dictionary=game.lobby.SKINS[int(pk.get("skin",0))]
					_info_tip(mp,RunText.text(String(sk3.get("name","")),lang),game.character_name(int(sk3.get("char",-1))),
						ExtraText.text(lang,"skin_locked"))
			break
	var max_scroll: float=game.store_max_scroll()
	if max_scroll>0.0:
		var bar_h: float=view.size.y*view.size.y/(view.size.y+max_scroll)
		var bar_y: float=view.position.y+(view.size.y-bar_h)*game.store_scroll/max_scroll
		_box(Rect2(532,view.position.y,2,view.size.y),Color(1,1,1,0.10)); _box(Rect2(531,bar_y,4,bar_h),Color(1,1,1,0.55))
	# header: back, tilted tag, balances at the top right like the reference's resource counters
	_button(Rect2(20,24,96,46),"‹  "+game.localize("back"),false)
	_di_tag(Vector2(136,30),StoreCatalog.text(lang,"store"),22)
	var rs: Rect2=game.STORE_RESTORE
	_box(rs,Color(0.06,0.065,0.068,0.85)); _frame(rs,Color(1,1,1,0.3),1.0)
	var rl: String=ExtraText.text(lang,"restore"); var rsz:=15
	while bold.get_string_size(rl,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(rsz)).x>rs.size.x-12 and rsz>9: rsz-=1
	_clean_center(bold,Vector2(rs.get_center().x,rs.get_center().y+_scaled(rsz)*0.36),rl,rsz,WHITE)
	# k=0.82 keeps all four balances inside 540 px, and the plate is measured
	# from the row so nothing hangs off the header bar.
	_wallet_plate(Vector2(84,84),0.82)
	_wallet(Vector2(84,84),false,0.82)
	_toast(870)

func _store_can_ad(r: Rect2,lang: String) -> void:
	var left: int=game.can_ads_left()
	var enabled: bool=left>0 and game.ad_pending.is_empty()
	_di_row(r)
	var tile:=Rect2(r.position+Vector2(8,8),Vector2(58,58))
	_box(tile,Color("292316",0.98) if enabled else Color(1,1,1,0.04))
	_frame(tile,Color(BRASS_LIGHT,0.75 if enabled else 0.16),1.0)
	var c:=tile.get_center()+Vector2(-8,0)
	clean_ops.append(["poly",PackedVector2Array([c+Vector2(-7,-11),c+Vector2(11,0),c+Vector2(-7,11)]),BRASS_LIGHT if enabled else MUTED])
	clean_ops.append(["texture",can_tex,Rect2(tile.end.x-29,tile.end.y-31,28,28)])
	_clean_text(bold,r.position+Vector2(82,32),StoreCatalog.text(lang,"watch_ad_cans"),22,WHITE if enabled else MUTED,false)
	_clean_text(font,r.position+Vector2(82,56),StoreCatalog.text(lang,"ads_remaining")%left,15,BRASS_LIGHT if enabled else MUTED,false)

## One store row: muted colour tile with the animated pack art, small grey kind label, big
## white amount, extras in small text, price box on the right.
## Truncate a label so it can never run under the price box: the vehicle description
## used to spill across the row and out of the card.
func _clip_text(f: Font, s: String, size: int, max_w: float) -> String:
	if max_w<=8.0: return s
	if f.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x<=max_w: return s
	var out: String=s
	while out.length()>1:
		out=out.substr(0,out.length()-1)
		if f.get_string_size(out+String.chr(8230),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x<=max_w: return out+String.chr(8230)
	return ""

## True only while a real mouse is moving: touch leaves the pointer parked, and a
## tooltip stuck on the last tap looks like a bug on the phone.
var mouse_hover:=false
var hover_point:=Vector2(-1,-1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_hover=true; hover_point=(event as InputEventMouseMotion).position
	elif event is InputEventScreenTouch or event is InputEventScreenDrag: mouse_hover=false

## Greedy wrap for the hover card (the store row itself keeps a single clipped line).
func _wrap_text(f: Font, s: String, size: int, max_w: float) -> Array:
	var lines: Array=[]
	var cur: String=""
	for ch in s:
		var nxt: String=cur+String(ch)
		if cur!="" and f.get_string_size(nxt,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x>max_w:
			lines.append(cur); cur=String(ch)
		else:
			cur=nxt
	if cur!="": lines.append(cur)
	return lines

## Hover card: title, small caption and the full blurb, kept on screen.
func _info_tip(at: Vector2,title: String,subtitle: String,body: String) -> void:
	var size:=15
	var lines: Array=[]
	if body!="": lines=_wrap_text(font,body,size,320.0)
	var w: float=352.0
	var h: float=34.0+float(maxi(1,lines.size()))*(_scaled(size)+7.0)+12.0
	var pos:=Vector2(clampf(at.x-w*0.5,8.0,532.0-w),clampf(at.y-h-18.0,8.0,game.ui_h-h-8.0))
	var panel:=Rect2(pos,Vector2(w,h))
	_box(panel,Color(0.02,0.022,0.026,0.97))
	_frame(panel,Color(1,0.82,0.45,0.85),1.0)
	_clean_text(bold,pos+Vector2(14,24),title,18,WHITE,false)
	if subtitle!="": _clean_text(font,pos+Vector2(14,42),subtitle,11,Color(1,1,1,0.45),false)
	for i in range(lines.size()):
		_clean_text(font,pos+Vector2(14,58.0+float(i)*(_scaled(size)+7.0)),String(lines[i]),size,MUTED,false)


func _store_row(r: Rect2,p: Dictionary,cur: String,lang: String) -> void:
	var kind: String=p.kind
	var owned: bool=game.all_access or (bool(p.get("once",false)) and game.pack_owned(String(p.id)))
	if kind=="pet" and game.pet_owned(int(p.get("pet",-1))): owned=true # a dog won from a case is owned too
	_di_row(r)
	if kind=="offer":
		# one yellow bar across the top, title left, saving right (like GATHER  999)
		var bar:=Rect2(r.position,Vector2(r.size.x,30))
		_box(bar,Color("514326",0.96))
		_box(Rect2(bar.position,Vector2(bar.size.x,2)),BRASS_LIGHT)
		_clean_text(bold,bar.position+Vector2(12,23),StoreCatalog.text(lang,"limited").to_upper(),20,INK_DARK,false)
		var d:="-%d%%"%StoreCatalog.discount(p); var dw:=bold.get_string_size(d,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(22)).x
		_clean_text(bold,Vector2(bar.end.x-dw-12,bar.position.y+24),d,22,INK_DARK,false)
		r=Rect2(r.position+Vector2(0,30),r.size-Vector2(0,30))
	var tile:=Rect2(r.position+Vector2(8,8),Vector2(r.size.y-16,r.size.y-16))
	var tc: Color=KIND_TILE.get(kind,Color("3d6766"))
	# black tile for every pack; the glow, turning rays and sparkles sit on top of it
	_box(tile,Color(0.012,0.012,0.014,1.0))
	_box(Rect2(tile.position,Vector2(tile.size.x,1)),Color(tc.r,tc.g,tc.b,0.55))
	_box(Rect2(tile.position.x,tile.end.y-1,tile.size.x,1),Color(tc.r,tc.g,tc.b,0.55))
	_pack_visual(tile.grow(-2),p,false)
	var x: float=tile.end.x+16
	var y: float=r.position.y+30
	var label: String
	if p.id=="removeads":
		# the one non-consumable: a crossed-out play mark, the title and what it does
		var c:=tile.get_center()
		var ring:=PackedVector2Array()
		for k in range(25): ring.append(c+Vector2(cos(TAU*k/24.0),sin(TAU*k/24.0))*28.0)
		clean_ops.append(["line",ring,WHITE,3.0])
		clean_ops.append(["poly",PackedVector2Array([c+Vector2(-9,-14),c+Vector2(15,0),c+Vector2(-9,14)]),WHITE])
		clean_ops.append(["line",PackedVector2Array([c+Vector2(-22,22),c+Vector2(22,-22)]),Color("e0453d"),5.0])
		_clean_text(bold,Vector2(x,y+34),ExtraText.text(lang,"removeads_title"),26,WHITE,false)
		_clean_text(font,Vector2(x,y+60),ExtraText.text(lang,"removeads_desc"),13,MUTED,false)
		var rr: Rect2=game.store_price_rect(r,false)
		if owned: _di_price(rr,StoreCatalog.text(lang,"owned"),"off")
		elif game.iap and not game.iap.available("removeads"): _di_price(rr,game.pack_price(p,cur),"off")
		else: _di_price(rr,game.pack_price(p,cur),"buy")
		return
	match kind:
		"cans": label=StoreCatalog.text(lang,"can_packs")
		"coins": label=StoreCatalog.text(lang,"coin_packs")
		"silver": label=StoreCatalog.text(lang,"silver_packs")
		"vouchers": label=StoreCatalog.text(lang,"voucher_packs")
		_: label=StoreCatalog.text(lang,p.name)
	# Currency rows need no caption: the icon says it. Characters and skins draw their own name below.
	if not kind in ["cans","coins","silver","vouchers","character","pet","skin","vehicle"]: _di_label(Vector2(x,y),label,HILITE if kind=="offer" else Color(1,1,1,0.55))
	if kind=="cans":
		y-=6.0
		clean_ops.append(["texture",can_tex,Rect2(x,y+10,30,30)])
		_clean_text(bold,Vector2(x+38,y+38),_grouped(int(p.cans)),34,WHITE)
	elif kind in ["coins","silver","vouchers"]:
		y-=6.0
		var coins: bool=kind=="coins"
		var is_silver: bool=kind=="silver"
		var amount: int=int(p.silver) if is_silver else (int(p.coins) if coins else int(p.vouchers))
		var tex: Texture2D=silver_tex if is_silver else (coin_tex if coins else voucher_tex)
		clean_ops.append(["texture",tex,Rect2(x,y+10,30,30) if not is_silver and not coins else Rect2(x-2,y+13,44,27) if not coins and not is_silver else Rect2(x,y+10,30,30)])
		_clean_text(bold,Vector2(x+(48 if not coins and not is_silver else 38),y+38),_grouped(amount),34,WHITE)
		if int(p.bonus)>0: _clean_text(bold,Vector2(x,y+66),"+%d%% %s"%[int(p.bonus),StoreCatalog.text(lang,"bonus").to_upper()],14,HILITE,false)
	elif kind=="offer" and int(p.get("cans",0))>0:
		clean_ops.append(["texture",can_tex,Rect2(x,y+10,34,34)])
		_clean_text(bold,Vector2(x+42,y+40),_grouped(int(p.cans)),32,WHITE)
		_clean_text(bold,Vector2(x,y+76),"%s  %s"%[StoreCatalog.text(lang,"ends"),_clock(game.offer_seconds_left())],14,HILITE,false)
	elif kind=="character":
		# Paid survivor: portrait in the tile, big name, perk line, one-time tag.
		_clean_text(bold,Vector2(x,y+30),game.character_name(int(p.get("char",0))),30,WHITE,false)
		_clean_text(font,Vector2(x,y+58),RunText.text(String(p.get("perk","")),lang),14,MUTED,false)
		_clean_text(font,Vector2(x,y+78),StoreCatalog.text(lang,"once").to_upper(),13,Color("e0453d"),false)
	elif kind=="skin":
		var sk2: Dictionary=game.lobby.SKINS[int(p.get("skin",0))]
		_clean_text(bold,Vector2(x,y+30),RunText.text(String(sk2.get("name","")),lang),30,WHITE,false)
		_clean_text(font,Vector2(x,y+58),game.character_name(int(sk2.get("char",-1))),14,MUTED,false)
		_clean_text(font,Vector2(x,y+78),StoreCatalog.text(lang,"once").to_upper(),13,Color("e0453d"),false)
	elif kind=="pass" or kind=="unlock":
		var pkey: String=String(p.get("name","pass_weekly"))
		_clean_text(bold,Vector2(x,y+30),StoreCatalog.text(lang,pkey),26,WHITE,false)
		var pw: Rect2=game.store_price_rect(r,false)
		var ptw: float=pw.position.x-x-14.0
		_clean_text(font,Vector2(x,y+56),_clip_text(font,StoreCatalog.text(lang,pkey+"_desc"),13,ptw),13,MUTED,false)
	elif kind=="vehicle":
		# Bought vehicle: name, auto-ride line, one-time tag.
		var v_name: String=String(p.get("name","bike"))
		var v_desc: String=String(v_name)+"_desc"
		var price_r: Rect2=game.store_price_rect(r,false)
		var text_w: float=price_r.position.x-x-14.0
		_clean_text(bold,Vector2(x,y+30),_clip_text(bold,StoreCatalog.text(lang,v_name),30,text_w),30,WHITE,false)
		_clean_text(font,Vector2(x,y+58),_clip_text(font,StoreCatalog.text(lang,v_desc),14,text_w),14,MUTED,false)
		_clean_text(font,Vector2(x,y+78),StoreCatalog.text(lang,"once").to_upper(),13,Color("e0453d"),false)
	elif kind=="pet":
		# A dog bought outright: name, plus a hint that cases can still drop it (1% jackpot).
		_clean_text(bold,Vector2(x,y+30),game.pet_name(int(p.get("pet",0))),30,WHITE,false)
		_clean_text(font,Vector2(x,y+58),ExtraText.text(lang,"pet_locked"),14,MUTED,false)
		_clean_text(font,Vector2(x,y+78),StoreCatalog.text(lang,"once").to_upper(),13,Color("e0453d"),false)
	else:
		clean_ops.append(["texture",coin_tex,Rect2(x,y+10,26,26)])
		_clean_text(bold,Vector2(x+32,y+33),_grouped(int(p.coins)),26,WHITE)
		clean_ops.append(["texture",voucher_tex,Rect2(x-2,y+46,40,24)])
		_clean_text(bold,Vector2(x+44,y+66),"×%d"%int(p.vouchers),22,WHITE)
		if kind=="offer":
			_clean_text(bold,Vector2(x,y+86),"%s  %s"%[StoreCatalog.text(lang,"ends"),_clock(game.offer_seconds_left())],14,HILITE,false)
		elif bool(p.get("once",false)):
			_clean_text(bold,Vector2(x,y+92),StoreCatalog.text(lang,"once").to_upper(),13,Color("e0453d"),false)
	var pr: Rect2=game.store_price_rect(r,false)
	if owned: _di_price(pr,StoreCatalog.text(lang,"owned"),"off")
	elif game.iap and not game.iap.available(String(p.id)): _di_price(pr,game.pack_price(p,cur),"off")
	else: _di_price(pr,game.pack_price(p,cur),"deal" if kind=="offer" else "buy")

## Price button: a dark plate with a brass frame and brass lettering — spending money is the
## brass action, not the red one. Greyed out when not available.
func _store_price(rect: Rect2,label: String,enabled: bool) -> void:
	var size:=_scaled(26 if rect.size.y>=50 else 22)
	while bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x-18 and size>13: size-=1
	if enabled:
		_box(rect,Color(0.10,0.09,0.06,0.94),Color(BRASS,0.9),1.5)
		_clean_center(bold,Vector2(rect.get_center().x,rect.get_center().y+size*0.36),label,size,BRASS_LIGHT)
	else:
		_box(rect,Color(0.06,0.062,0.065,0.88),Color(1,1,1,0.10),1)
		_clean_center(bold,Vector2(rect.get_center().x,rect.get_center().y+size*0.36),label,size,MUTED)

func _bonus_tag(pos: Vector2,bonus: int,lang: String) -> void:
	if bonus<=0: return
	_tag(pos,"+%d%% %s"%[bonus,StoreCatalog.text(lang,"bonus").to_upper()],HILITE,INK_DARK,14)

func _amount(pos: Vector2,coins: bool,value: int,size:=26) -> void:
	var icon:=Rect2(pos+Vector2(0,-size+2),Vector2(size+4,size+4)) if coins else Rect2(pos+Vector2(-2,-size+6),Vector2((size+4)*1.5,size))
	clean_ops.append(["texture",coin_tex if coins else voucher_tex,icon])
	_clean_text(bold,Vector2(icon.end.x+8,pos.y+4),_grouped(value),size,GOLD if coins else VOUCHER_COL)

## ---- Limited-time offer ----------------------------------------------------------------------
## Saving as a yellow brush stroke, like "-60%".
func _discount_flag(pos: Vector2,pct: int,size:=1.0) -> void:
	_tag(pos,"-%d%%"%pct,HILITE,INK_DARK,int(28*size))

func _offer_timer(pos: Vector2,size:=20) -> void:
	var cc:=pos+Vector2(9,-7)
	var ring:=PackedVector2Array()
	for i in range(21): ring.append(cc+Vector2(cos(TAU*i/20.0),sin(TAU*i/20.0))*8.0)
	clean_ops.append(["line",ring,HILITE,2.0])
	clean_ops.append(["line",PackedVector2Array([cc+Vector2(0,-5),cc,cc+Vector2(4,2)]),HILITE,2.0])
	_clean_text(bold,pos+Vector2(24,0),_clock(game.offer_seconds_left()),size,HILITE)

## Lobby shortcut: offer picture, saving and countdown; tap reopens the popup.
func _offer_badge(r: Rect2) -> void:
	var o: Dictionary=StoreCatalog.offer(game.offer_id)
	var pulse:=0.5+0.5*sin(Time.get_ticks_msec()/260.0)
	_paint(r)
	_pack_visual(Rect2(r.position+Vector2(6,6),Vector2(r.size.x-12,r.size.x-12)),o)
	_frame(r,Color(HILITE,0.55+0.45*pulse),2.0)
	_tag(Vector2(r.position.x+r.size.x-50,r.position.y-10),"-%d%%"%StoreCatalog.discount(o),HILITE,INK_DARK,15)
	_clean_center(bold,Vector2(r.get_center().x,r.end.y-6),_clock(game.offer_seconds_left()),13,HILITE)

func _draw_offer_popup() -> void:
	var lang: String=game.language_code
	var o: Dictionary=StoreCatalog.offer(game.offer_id)
	if o.is_empty(): return
	var cur: String=game.store_currency if not game.store_currency.is_empty() else StoreCatalog.device_currency()
	_box(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.72))
	var p: Rect2=game.OFFER_PANEL
	_paint(p,Color(0.05,0.052,0.056,0.97))
	_section(Vector2(-1,p.position.y+44),StoreCatalog.text(lang,"limited"),24)
	var c: Vector2=game.OFFER_CLOSE.get_center()
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-11,-11),c+Vector2(11,11)]),WHITE,4.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(11,-11),c+Vector2(-11,11)]),WHITE,4.0])
	var art_r:=Rect2(p.get_center().x-150,p.position.y+86,300,300)
	_pack_visual(art_r,o)
	_frame(art_r,Color(1,1,1,0.18),1.0)
	_discount_flag(Vector2(art_r.end.x-70,art_r.position.y-12),StoreCatalog.discount(o))
	var title_key: String=String(o.get("name","limited"))
	_clean_center(bold,Vector2(p.get_center().x,art_r.end.y+36),StoreCatalog.text(lang,title_key),26,WHITE)
	# selling point: what the bundle actually does in the run
	if o.has("desc_key"):
		var blurb: String=StoreCatalog.text(lang,String(o.desc_key))
		var wrapped: Array=_wrap_text(font,blurb,13,380.0)
		for wi in range(mini(wrapped.size(),2)):
			_clean_center(font,Vector2(p.get_center().x,art_r.end.y+60.0+float(wi)*18.0),String(wrapped[wi]),13,MUTED)
	var y: float=art_r.end.y+76
	if int(o.get("cans",0))>0:
		clean_ops.append(["texture",can_tex,Rect2(p.get_center().x-82,y-30,40,40)])
		_clean_text(bold,Vector2(p.get_center().x-32,y+6),_grouped(int(o.cans)),30,WHITE,false)
	else:
		_amount(Vector2(p.position.x+92,y),true,int(o.coins))
		_amount(Vector2(p.position.x+262,y),false,int(o.vouchers))
	var left: String=StoreCatalog.text(lang,"ends")
	var lw:=font.get_string_size(left,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(17)).x
	_clean_text(font,Vector2(p.get_center().x-lw-60,y+50),left,17,MUTED,false)
	_offer_timer(Vector2(p.get_center().x-48,y+50),18)
	var was_price: String=game.pack_was_price(o,cur)
	var was: String=(StoreCatalog.text(lang,"was")+" "+was_price) if was_price!="" else ""
	var ww:=font.get_string_size(was,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(15)).x
	var b: Rect2=game.OFFER_BUY
	_clean_text(font,Vector2(b.get_center().x-ww/2,b.position.y-14),was,15,MUTED,false)
	clean_ops.append(["line",PackedVector2Array([Vector2(b.get_center().x-ww/2-2,b.position.y-19),Vector2(b.get_center().x+ww/2+2,b.position.y-19)]),Color(1,0.35,0.3,0.9),2.0])
	_store_price(b,game.pack_price(o,cur),game.iap==null or game.iap.available(String(o.id)))
	_toast(812)

func _draw_resource_pack_background() -> void:
	match game.resource_pack_return_state:
		"store": _draw_store()
		"shop": _draw_shop()
		"lootbox": _draw_lootbox()
		"cover": _draw_cover()
		"tasks": _draw_tasks()
		"map": _draw_map()
		"paused":
			_draw_hud()
			_draw_pause()
		_: _draw_character_select()

## A regular pack suggested after a failed spend, without offer countdowns or fake discounts.
func _draw_resource_pack_popup() -> void:
	var lang: String=game.language_code
	var p: Dictionary=game.pack_by_id(game.resource_pack_id)
	if p.is_empty(): return
	var cur: String=game.store_currency if not game.store_currency.is_empty() else StoreCatalog.device_currency()
	_box(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.72))
	var panel: Rect2=game.OFFER_PANEL
	_paint(panel,Color(0.05,0.052,0.056,0.97))
	var title_key: String="coin_packs" if p.kind=="coins" else ("voucher_packs" if p.kind=="vouchers" else "can_packs")
	_section(Vector2(-1,panel.position.y+44),StoreCatalog.text(lang,title_key),26)
	var close_c: Vector2=game.OFFER_CLOSE.get_center()
	clean_ops.append(["line",PackedVector2Array([close_c+Vector2(-11,-11),close_c+Vector2(11,11)]),WHITE,4.0])
	clean_ops.append(["line",PackedVector2Array([close_c+Vector2(11,-11),close_c+Vector2(-11,11)]),WHITE,4.0])
	var art_r:=Rect2(panel.get_center().x-150,panel.position.y+86,300,300)
	_pack_visual(art_r,p)
	_frame(art_r,Color(1,1,1,0.18),1.0)
	var kind: String=String(p.kind)
	var amount: int=int(p.get("cans",0) if kind=="cans" else p.get(kind,0))
	var value: String=_grouped(amount)
	var size:=36
	var tw: float=bold.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	var icon_size:=Vector2(42,42) if kind!="vouchers" else Vector2(62,38)
	var x: float=panel.get_center().x-(icon_size.x+12+tw)/2.0
	var y: float=art_r.end.y+72
	var tex: Texture2D=can_tex if kind=="cans" else (coin_tex if kind=="coins" else voucher_tex)
	clean_ops.append(["texture",tex,Rect2(Vector2(x,y-icon_size.y/2),icon_size)])
	_clean_text(bold,Vector2(x+icon_size.x+12,y+size*0.35),value,size,WHITE,false)
	if int(p.get("bonus",0))>0: _bonus_tag(Vector2(panel.get_center().x-62,y+50),int(p.bonus),lang)
	_store_price(game.OFFER_BUY,game.pack_price(p,cur),game.iap==null or game.iap.available(String(p.id)))
	_toast(812)

## Pack picture with a live backdrop: the glow breathes, light rays turn slowly, now and then a
## bright flash rolls through, and sparkles twinkle on top. Pictures are goods-only PNGs.
func _pack_visual(r: Rect2,p: Dictionary,own_bg:=true) -> void:
	var t: float=Time.get_ticks_msec()/1000.0
	var seed: int=hash(String(p.id))
	var phase: float=float(seed%1000)/159.0
	var col: Color=StoreCatalog.GLOW.get(String(p.get("glow","gold")),Color(1,0.72,0.25))
	var pulse: float=0.72+0.28*sin(t*3.0+phase)
	var flash: float=pow(maxf(0.0,sin(t*1.1+phase)),14.0)
	if own_bg: _box(r,Color(0.03,0.032,0.036,1.0))
	var c: Vector2=r.get_center()+Vector2(0,r.size.y*0.06)
	var rays: int=int(p.get("rays",0))
	if rays>0:
		var spin: float=t*0.35+phase
		# rays reach past the corners and are clipped to the square, so they fill the whole tile
		var radius: float=r.size.length()
		var half: float=PI/rays*0.42
		var rc:=Color(col.r,col.g,col.b,0.26*pulse+0.30*flash)
		var sq:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		for i in range(rays):
			var a: float=spin+TAU*i/rays
			var p1:=c+Vector2(cos(a-half),sin(a-half))*radius
			var p2:=c+Vector2(cos(a+half),sin(a+half))*radius
			for piece in Geometry2D.intersect_polygons(PackedVector2Array([c,p1,p2]),sq):
				if piece.size()>=3: clean_ops.append(["poly",piece,rc])
	var g: float=r.size.x*(1.0+0.08*pulse+0.12*flash)
	clean_ops.append(["tinted",glow_tex,Rect2(c-Vector2(g,g)*0.5,Vector2(g,g)),Color(col.r,col.g,col.b,0.85*pulse+0.4*flash)])
	var art: Texture2D=_store_art(String(p.get("art",p.id)))
	if art:
		var available:=r.grow(-r.size.x*0.015)
		var art_size: Vector2=art.get_size()
		var fit: float=minf(available.size.x/art_size.x,available.size.y/art_size.y)
		var draw_size: Vector2=art_size*fit
		clean_ops.append(["texture",art,Rect2(available.get_center()-draw_size*0.5,draw_size)])
	var count: int=4+rays/2
	for k in range(count):
		var h: int=hash(str(seed)+"s"+str(k))
		var pos:=r.position+Vector2(0.1+0.8*float(h%997)/997.0,0.08+0.6*float((h/997)%991)/991.0)*r.size
		var tw: float=pow(maxf(0.0,sin(t*(1.4+0.33*k)+k*2.1+phase)),4.0)
		if tw<0.03: continue
		var sz: float=(3.0+float(h%5))*(r.size.x/200.0)*(0.6+0.6*tw)
		var sc:=Color(1.0,0.96,0.86,tw)
		clean_ops.append(["line",PackedVector2Array([pos-Vector2(sz,0),pos+Vector2(sz,0)]),sc,2.0])
		clean_ops.append(["line",PackedVector2Array([pos-Vector2(0,sz),pos+Vector2(0,sz)]),sc,2.0])

## ---- Check-in and missions screens ------------------------------------------------------------
func _red_dot(pos: Vector2) -> void:
	var pts:=PackedVector2Array()
	for i in range(16): pts.append(pos+Vector2(cos(TAU*i/16.0),sin(TAU*i/16.0))*7.0)
	clean_ops.append(["poly",pts,Color("e23a35")])

## Lobby side buttons: just a white line icon and a small label, no frame, no shadow.
func _side_button(r: Rect2,icon: String,label: String,dot: bool) -> void:
	# Dark chip behind every rail button: on the pale safehouse wall the white line icons were
	# unreadable, and the reference UI always sits icons on a plate.
	_box(r.grow(-1), Color(0.020, 0.022, 0.025, 0.72))
	_frame(r.grow(-1), Color(C_BONE, 0.12), 1.0)
	_box(Rect2(r.position.x, r.position.y, r.size.x, 2), C_BLOOD)
	var c:=r.position+Vector2(r.size.x/2,30)
	var ic: Color=WHITE
	var ac: Color=HILITE if dot else WHITE
	match icon:
		"signin":
			_frame(Rect2(c-Vector2(16,13),Vector2(32,28)),ic,2.0)
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-16,-5),c+Vector2(16,-5)]),ic,2.0])
			for x in [-8,8]: clean_ops.append(["line",PackedVector2Array([c+Vector2(x,-18),c+Vector2(x,-9)]),ic,3.0])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-7,4),c+Vector2(-2,9),c+Vector2(8,-1)]),ac,3.0])
		"tasks":
			_frame(Rect2(c-Vector2(14,16),Vector2(28,34)),ic,2.0)
			for k in range(3):
				var y:=-7+k*9
				clean_ops.append(["line",PackedVector2Array([c+Vector2(-8,y),c+Vector2(-5,y+3),c+Vector2(-1,y-3)]),ac,2.0])
				clean_ops.append(["line",PackedVector2Array([c+Vector2(2,y),c+Vector2(9,y)]),ic,2.0])
		"shop":
			_frame(Rect2(c-Vector2(17,11),Vector2(34,24)),ic,2.0)
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-17,-11),c+Vector2(-11,-18),c+Vector2(17,-18),c+Vector2(17,-11)]),ic,2.0])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-17,-1),c+Vector2(17,-1)]),ic,2.0])
		"store":
			# a shopping bag with a price tag: the real-money store
			var bag:=PackedVector2Array([c+Vector2(-15,-8),c+Vector2(15,-8),c+Vector2(17,17),c+Vector2(-17,17),c+Vector2(-15,-8)])
			clean_ops.append(["line",bag,ic,2.0])
			var handle:=PackedVector2Array()
			for k in range(9): handle.append(c+Vector2(-7+14.0*k/8.0,-8-9*sin(PI*k/8.0)))
			clean_ops.append(["line",handle,ic,2.0])
			var tag:=PackedVector2Array([c+Vector2(-2,1),c+Vector2(7,1),c+Vector2(11,6),c+Vector2(7,11),c+Vector2(-2,11)])
			clean_ops.append(["poly",tag,HILITE])
			clean_ops.append(["poly",_circle_pts(c+Vector2(1,6),1.6,8),INK_DARK])
		"map":
			# a folded map: three panels with a dashed route and a pin
			var fold:=PackedVector2Array([c+Vector2(-17,-12),c+Vector2(-6,-16),c+Vector2(6,-12),c+Vector2(17,-16),c+Vector2(17,14),c+Vector2(6,18),c+Vector2(-6,14),c+Vector2(-17,18),c+Vector2(-17,-12)])
			clean_ops.append(["line",fold,ic,2.0])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-6,-16),c+Vector2(-6,14)]),ic,1.5])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(6,-12),c+Vector2(6,18)]),ic,1.5])
			clean_ops.append(["poly",_circle_pts(c+Vector2(10,-3),4.0,10),HILITE])
		"bag":
			# a backpack: rounded body, top flap, front pocket and a carry loop
			_frame(Rect2(c-Vector2(14,10),Vector2(28,28)),ic,2.0)
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-14,-2),c+Vector2(-10,-12),c+Vector2(10,-12),c+Vector2(14,-2)]),ic,2.0])
			_frame(Rect2(c+Vector2(-8,6),Vector2(16,9)),ac,2.0)
			var loop:=PackedVector2Array()
			for k in range(7): loop.append(c+Vector2(-5+10.0*k/6.0,-12-5*sin(PI*k/6.0)))
			clean_ops.append(["line",loop,ic,2.0])
		"mail":
			# an envelope: frame and the flap's V
			_frame(Rect2(c-Vector2(17,12),Vector2(34,24)),ic,2.0)
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-17,-12),c+Vector2(0,3),c+Vector2(17,-12)]),ac,2.0])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(-17,12),c+Vector2(-5,-1)]),ic,1.5])
			clean_ops.append(["line",PackedVector2Array([c+Vector2(17,12),c+Vector2(5,-1)]),ic,1.5])
	var ls:=13
	while bold.get_string_size(label.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ls)).x>r.size.x+6 and ls>8: ls-=1
	_clean_center(bold,Vector2(r.get_center().x,r.end.y-6),label.to_upper(),ls,WHITE,false)
	if dot: _red_dot(r.position+Vector2(r.size.x-10,6))

func _circle_pts(c: Vector2,r: float,n:=12) -> PackedVector2Array:
	var pts:=PackedVector2Array()
	for k in range(n): pts.append(c+Vector2(cos(TAU*k/n),sin(TAU*k/n))*r)
	return pts

## Mailbox page: a list of letters (title, first line, reward); tap one to read it in full.
func _draw_mail() -> void:
	var lang: String=game.language_code
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.02,0.022,0.024,0.78))
	if game.mail_open>=0 and game.mail_open<game.mails.size(): _draw_letter(game.mails[game.mail_open],lang); return
	_page_header(ExtraText.text(lang,"mail"))
	if game.mails.is_empty():
		_clean_center(font,Vector2(270,420),ExtraText.text(lang,"mail_empty"),18,MUTED)
	for i in range(mini(game.mails.size(),5)):
		var m: Dictionary=game.mails[i]; var r: Rect2=game.mail_row(i)
		var claimed: bool=game.mail_claimed.has(String(m.id))
		var has_gift: bool=int(m.coins)>0 or int(m.vouchers)>0 or int(m.get("cans",0))>0
		_box(r,Color(0.075,0.08,0.082,0.94)); _frame(r,Color(1,1,1,0.10),1.0)
		if has_gift and not claimed: _box(Rect2(r.position,Vector2(4,r.size.y)),PAINT_RED)
		var ec:=r.position+Vector2(34,34)
		var ecol:=Color(1,1,1,0.4 if claimed else 0.9)
		_frame(Rect2(ec-Vector2(14,10),Vector2(28,20)),ecol,1.5)
		clean_ops.append(["line",PackedVector2Array([ec+Vector2(-14,-10),ec+Vector2(0,2),ec+Vector2(14,-10)]),ecol,1.5])
		_clean_text(bold,r.position+Vector2(62,34),String(m.title),19,Color(1,1,1,0.55) if claimed else WHITE,false)
		var first: String=String(m.body).split("\n")[0]
		if first.length()>30: first=first.substr(0,29)+"…"
		_clean_text(font,r.position+Vector2(62,58),first,13,MUTED,false)
		if has_gift: _reward_line(Vector2(r.position.x+62,r.end.y-14),int(m.coins),int(m.vouchers),18,int(m.get("cans",0)))
		var tag: String=ExtraText.text(lang,"claimed") if claimed or not has_gift else ExtraText.text(lang,"read")
		_clean_text(bold,Vector2(r.end.x-18-bold.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(15)).x,r.end.y-16),tag,15,Color(1,1,1,0.4) if claimed or not has_gift else HILITE,false)
		_clean_text(bold,Vector2(r.end.x-22,r.position.y+40),"›",26,Color(1,1,1,0.5),false)
		if has_gift and not claimed: _red_dot(r.position+Vector2(r.size.x-8,8))
	_toast(860)

## Splits text into lines that fit `width` (words for spaced scripts, characters for CJK/Thai).
func _wrap(text: String,f: Font,size: int,width: float) -> PackedStringArray:
	var out:=PackedStringArray()
	for para in text.split("\n"):
		var line:=""; var word:=""
		var tokens:=PackedStringArray()
		for ch in para:
			var code:=ch.unicode_at(0)
			if ch==" ": tokens.append(word+" "); word=""
			elif code>=0x2E80 or (code>=0x0E00 and code<=0x0E7F): 
				if word!="": tokens.append(word); word=""
				tokens.append(ch)
			else: word+=ch
		if word!="": tokens.append(word)
		for tk in tokens:
			if f.get_string_size(line+tk,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and line!="":
				out.append(line.strip_edges(false,true)); line=tk.strip_edges(true,false)
			else: line+=tk
		out.append(line)
	return out

## One letter, full text, scrolling; the gift and the claim button come after the last line.
func _draw_letter(m: Dictionary,lang: String) -> void:
	_page_header(ExtraText.text(lang,"mail"))
	var view: Rect2=game.LETTER_VIEW
	list_clip.position=view.position; list_clip.size=view.size
	var saved:=clean_ops; clean_ops=list_ops
	var y: float=view.position.y-game.mail_scroll
	var x: float=view.position.x+16; var w: float=view.size.x-32
	_box(Rect2(view.position.x,y,view.size.x,maxf(view.size.y,game.letter_content_h())),Color(0.05,0.055,0.058,0.82))
	y+=46.0
	for line in _wrap(String(m.title),bold,_scaled(24),w):
		_clean_text(bold,Vector2(x,y),line,24,WHITE,false); y+=32.0
	_clean_text(font,Vector2(x,y+2),ExtraText.text(lang,"from"),12,MUTED,false); y+=18.0
	_box(Rect2(x,y,w,1),Color(1,1,1,0.14)); y+=34.0
	var text_top: float=y
	for line in _wrap(String(m.body),font,_scaled(17),w):
		_clean_text(font,Vector2(x,y),line,17,Color(1,1,1,0.88),false); y+=27.0
	game.mail_text_h=(y-(view.position.y-game.mail_scroll))
	var has_gift: bool=int(m.coins)>0 or int(m.vouchers)>0 or int(m.get("cans",0))>0
	if has_gift:
		var claimed: bool=game.mail_claimed.has(String(m.id))
		_box(Rect2(x,y+12,w,1),Color(1,1,1,0.14))
		_reward_line(Vector2(x+130,y+66),int(m.coins),int(m.vouchers),24,int(m.get("cans",0)))
		var b: Rect2=game.letter_claim_rect()
		if claimed: _ghost_button(b,ExtraText.text(lang,"claimed"),Color(1,1,1,0.4))
		else: _store_price(b,ExtraText.text(lang,"claim"),true)
	clean_ops=saved
	var ms: float=game.letter_max_scroll()
	if ms>0.0:
		var bar_h: float=view.size.y*view.size.y/(view.size.y+ms)
		var bar_y: float=view.position.y+(view.size.y-bar_h)*game.mail_scroll/ms
		_box(Rect2(view.end.x+3,bar_y,3,bar_h),Color(1,1,1,0.35))
	_toast(860)

## Backpack: a grid of item slots with icon, name and count.
func _draw_bag() -> void:
	var lang: String=game.language_code
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.02,0.022,0.024,0.78))
	_page_header(ExtraText.text(lang,"bag"))
	var items: Array=game.bag_items()
	# a real grid: owned stacks first, the rest are empty slots, clipped under the header
	list_clip.position=Vector2(0,132)
	list_clip.size=Vector2(540,game.ui_h-172)
	var saved_ops:=clean_ops
	clean_ops=list_ops
	for i in range(game.bag_slot_count()):
		var r: Rect2=game.bag_slot(i)
		if r.end.y<126 or r.position.y>game.ui_h-34: continue
		_box(r,Color(0.06,0.065,0.068,0.80)); _frame(r,Color(1,1,1,0.14),1.0)
		if i<items.size():
			var it: Dictionary=items[i]
			var icon:=Rect2(r.get_center()+Vector2(-26,-46),Vector2(52,52))
			if it.id=="coins": clean_ops.append(["texture",coin_tex,icon])
			elif it.id=="silver": clean_ops.append(["texture",silver_tex,icon])
			else: clean_ops.append(["texture",voucher_tex,Rect2(r.get_center()+Vector2(-36,-40),Vector2(72,42))])
			_clean_center(bold,Vector2(r.get_center().x,r.end.y-34),_grouped(int(it.count)),20,GOLD if it.id=="coins" else (Color(0.85,0.90,1.0) if it.id=="silver" else VOUCHER_COL))
			_clean_center(font,Vector2(r.get_center().x,r.end.y-12),ExtraText.text(lang,"item_"+String(it.id)),12,MUTED)
		else:
			_clean_center(font,r.get_center()+Vector2(0,6),"-",16,Color(1,1,1,0.10))
	clean_ops=saved_ops
	_toast(860)

## Lobby airdrop: the crate bobs gently; free once a day (one ad), dimmed until tomorrow.
func _airdrop_button(lang: String) -> void:
	if not game.airdrop_available(): return   # claimed today: gone until tomorrow
	var r: Rect2=game.AIRDROP_RECT
	var ready: bool=game.airdrop_available()
	var t: float=Time.get_ticks_msec()/1000.0
	if ready and glow_tex: clean_ops.append(["tinted",glow_tex,Rect2(r.get_center()+Vector2(-72,-80),Vector2(144,144)),Color(HILITE.r,HILITE.g,HILITE.b,0.20+0.10*sin(t*3.0))])
	# big crate, small tag: the crate is what the player should notice
	if airdrop_tex: clean_ops.append(["tinted",airdrop_tex,Rect2(r.position+Vector2((r.size.x-112)*0.5,-6),Vector2(112,112)),Color(1,1,1,1.0) if ready else Color(0.55,0.55,0.55,0.8)])
	var label: String="AD"   # a play mark and "AD": everyone reads it as "watch an ad"
	var plate:=Rect2(r.get_center().x-26,r.end.y-20,52,18)
	_box(plate,Color(HILITE,0.92) if ready else Color(0,0,0,0.6))
	var ls:=11; var room: float=plate.size.x-(22.0 if ready else 8.0)
	while bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ls)).x>room and ls>9: ls-=1
	var lw: float=bold.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(ls)).x
	var lx: float=plate.get_center().x-lw*0.5
	if ready:
		# a small play mark tells it's a video: one ad, then the drop opens
		lx+=7.0
		var pc:=Vector2(lx-9,plate.get_center().y)
		clean_ops.append(["poly",PackedVector2Array([pc+Vector2(-4,-4.5),pc+Vector2(4.5,0),pc+Vector2(-4,4.5)]),INK_DARK])
	_clean_text(bold,Vector2(lx,plate.get_center().y+_scaled(ls)*0.36),label,ls,INK_DARK if ready else MUTED,false)

## The opened airdrop: the crate, a burst of light and what was inside.
func _draw_airdrop() -> void:
	var lang: String=game.language_code
	var t: float=Time.get_ticks_msec()/1000.0
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.78))
	if glow_tex: clean_ops.append(["tinted",glow_tex,Rect2(270-210,330-210,420,420),Color(HILITE.r,HILITE.g,HILITE.b,0.35+0.1*sin(t*3.0))])
	for i in range(12):
		var a: float=t*0.4+TAU*i/12.0
		clean_ops.append(["poly",PackedVector2Array([Vector2(270,330),Vector2(270,330)+Vector2(cos(a-0.06),sin(a-0.06))*260,Vector2(270,330)+Vector2(cos(a+0.06),sin(a+0.06))*260]),Color(1,0.85,0.45,0.10)])
	if airdrop_tex: clean_ops.append(["texture",airdrop_tex,Rect2(270-120,330-120,240,240)])
	_clean_center(bold,Vector2(270,150),ExtraText.text(lang,"airdrop_got"),34,WHITE)
	var rw: Dictionary=game.airdrop_reward
	var w:=0.0
	if int(rw.get("coins",0))>0: w+=60+bold.get_string_size(_grouped(int(rw.coins)),HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(34)).x
	if int(rw.get("vouchers",0))>0: w+=110
	_reward_line(Vector2(270-w*0.5,560),int(rw.get("coins",0)),int(rw.get("vouchers",0)),34)
	_clean_center(font,Vector2(270,660),ExtraText.text(lang,"tap_close"),15,MUTED)

## Share button on the results screen: an outlined button with a share glyph.
func _share_button(r: Rect2,lang: String) -> void:
	# same box, size and type as the shop button above it, plus a small share mark
	var label: String=ExtraText.text(lang,"share")
	_button(r,label,false)
	var tw: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(24)).x
	var ic:=Vector2(r.get_center().x-tw*0.5-20,r.get_center().y)
	var col:=Color("e2dfd7")
	for p in [ic+Vector2(-7,0),ic+Vector2(7,-8),ic+Vector2(7,8)]: clean_ops.append(["poly",_circle_pts(p,3.5,10),col])
	clean_ops.append(["line",PackedVector2Array([ic+Vector2(7,-8),ic+Vector2(-7,0),ic+Vector2(7,8)]),col,1.6])

func _reward_line(pos: Vector2,coins: int,vouchers: int,size:=22,cans:=0) -> void:
	var x:=pos.x
	if cans>0:
		clean_ops.append(["texture",can_tex,Rect2(Vector2(x,pos.y-size),Vector2(size+4,size+4))])
		_clean_text(bold,Vector2(x+size+8,pos.y),"×%d"%cans,size,WHITE)
		x+=size+16+bold.get_string_size("×%d"%cans,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	if coins>0:
		clean_ops.append(["texture",coin_tex,Rect2(Vector2(x,pos.y-size),Vector2(size+4,size+4))])
		var t:=_grouped(coins); _clean_text(bold,Vector2(x+size+8,pos.y),t,size,GOLD)
		x+=size+16+bold.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(size)).x
	if vouchers>0:
		clean_ops.append(["texture",voucher_tex,Rect2(Vector2(x,pos.y-size+2),Vector2((size+4)*1.6,size+2))])
		_clean_text(bold,Vector2(x+(size+4)*1.6+6,pos.y),"×%d"%vouchers,size,VOUCHER_COL)

func _draw_signin() -> void:
	var lang: String=game.language_code
	var t: float=Time.get_ticks_msec()/1000.0
	_box(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.60))
	var p: Rect2=game.SIGNIN_PANEL
	_box(p,Color(0.045,0.05,0.052,0.95))
	_frame(p,Color(1,1,1,0.12),1.0)
	_section(Vector2(-1,p.position.y+16),ProgressCatalog.text(lang,"signin"),24)
	# week / month switch, centred under the title
	for ti in range(2):
		var tr: Rect2 = game.signin_tab_rect(ti)
		var on: bool = (game.signin_monthly == (ti == 1))
		if on: _box(tr, Color(0.55,0.10,0.10,0.95))
		else: _frame(tr.grow(-2), Color(1,1,1,0.22), 1.0)
		var tab_label: String = ("月签到" if ti==1 else "周签到") if String(lang).begins_with("zh") else ("MONTHLY" if ti==1 else "WEEKLY")
		_clean_center(bold, tr.get_center()+Vector2(0,7), tab_label, 16, WHITE if on else MUTED)
	var c: Vector2=game.SIGNIN_CLOSE.get_center()
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-11,-11),c+Vector2(11,11)]),WHITE,4.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(11,-11),c+Vector2(-11,11)]),WHITE,4.0])

	var avail: bool = game.signin_available()
	var track: Array = game.signin_rewards()
	var day_idx: int = game.signin_day_index()
	var compact: bool = game.signin_monthly

	for i in range(track.size()):
		var r: Rect2 = game.signin_tile(i)
		var reward: Dictionary = track[i]
		var done: bool = i < day_idx
		var current: bool = avail and i == day_idx
		var jackpot: bool = (i == 6 and not compact)
		_box(r.grow(-3),Color(0.085,0.09,0.092,0.96) if not done else Color(0.05,0.052,0.055,0.92))
		_frame(r.grow(-3),Color(BRASS,0.9) if jackpot else Color(1,1,1,0.14),1.5 if jackpot else 1.0)
		if compact:
			# 30 tiles on one screen: the day, then whatever that day actually pays
			_clean_text(font,r.position+Vector2(5,13),str(i+1),11,MUTED)
			var sv: int = int(reward.get("silver", 0))
			var cv: int = int(reward.get("coins", 0))
			var vv: int = int(reward.get("vouchers", 0))
			var icx: float = r.position.x + 20.0
			# the biggest thing that day pays is the icon; the rest ride as small badges
			if cv >= sv and cv > 0:
				clean_ops.append(["texture",coin_tex,Rect2(Vector2(icx, r.position.y+14),Vector2(28,28))])
				_clean_center(bold,Vector2(r.get_center().x,r.end.y-7),str(cv),12,GOLD)
				if sv > 0:
					_clean_text(font,r.position+Vector2(43,13),"+%ds"%sv,9,Color(0.85,0.90,1.0))
			elif sv > 0:
				clean_ops.append(["texture",silver_tex,Rect2(Vector2(icx, r.position.y+14),Vector2(28,28))])
				_clean_center(bold,Vector2(r.get_center().x,r.end.y-7),str(sv),12,Color(0.85,0.90,1.0))
				if cv > 0:
					_clean_text(font,r.position+Vector2(43,13),"+"+str(cv),9,GOLD)
			elif vv > 0:
				clean_ops.append(["texture",voucher_tex,Rect2(Vector2(icx, r.position.y+16),Vector2(28,24))])
				_clean_center(bold,Vector2(r.get_center().x,r.end.y-7),"×%d"%vv,12,VOUCHER_COL)
			if vv > 0 and (sv > 0 or cv > 0):
				clean_ops.append(["texture",voucher_tex,Rect2(r.position+Vector2(42,2),Vector2(22,18))])
		else:
			_clean_text(bold,r.position+Vector2(10,24),ProgressCatalog.text(lang,"day").replace("%d",str(i+1)).to_upper(),13,WHITE if current else MUTED)
			if jackpot:
				var half: float = r.size.x * 0.5
				var cy2: float = r.get_center().y - 4.0
				var js: int = int(reward.get("silver", 0))
				var jc: int = int(reward.get("coins", 0))
				var jv: int = int(reward.get("vouchers", 0))
				clean_ops.append(["texture",silver_tex,Rect2(Vector2(r.position.x+half*0.5-26,cy2-26),Vector2(52,52))])
				_clean_center(bold,Vector2(r.position.x+half*0.5,r.end.y-14),_grouped(js),17,BRASS_LIGHT)
				if jc > 0:
					clean_ops.append(["texture",coin_tex,Rect2(Vector2(r.position.x+half*1.5-26,cy2-26),Vector2(52,52))])
					_clean_center(bold,Vector2(r.position.x+half*1.5,r.end.y-14),_grouped(jc),17,BRASS_LIGHT)
				elif jv > 0:
					clean_ops.append(["texture",voucher_tex,Rect2(Vector2(r.position.x+half*1.5-26,cy2-22),Vector2(52,44))])
					_clean_center(bold,Vector2(r.position.x+half*1.5,r.end.y-14),"×%d"%jv,17,BRASS_LIGHT)
			else:
				var s2: int = int(reward.get("silver", 0))
				var c2: int = int(reward.get("coins", 0))
				var v2: int = int(reward.get("vouchers", 0))
				if s2 > 0:
					clean_ops.append(["texture",silver_tex,Rect2(r.get_center()+Vector2(-26,-28),Vector2(52,52))])
					_clean_center(bold,Vector2(r.get_center().x,r.end.y-14),_grouped(s2),20,Color(0.85,0.90,1.0))
				elif c2 > 0:
					clean_ops.append(["texture",coin_tex,Rect2(r.get_center()+Vector2(-26,-28),Vector2(52,52))])
					_clean_center(bold,Vector2(r.get_center().x,r.end.y-14),_grouped(c2),20,GOLD)
				elif v2 > 0:
					clean_ops.append(["texture",voucher_tex,Rect2(r.get_center()+Vector2(-26,-20),Vector2(52,44))])
					_clean_center(bold,Vector2(r.get_center().x,r.end.y-14),"×%d"%v2,20,VOUCHER_COL)
		if current:
			var pulse:=0.5+0.5*sin(t*4.0)
			_frame(r,Color(1,1,1,0.7+0.3*pulse),2.0)
			if not compact: _box(Rect2(r.end.x-18,r.position.y+2,14,5),PAINT_RED)
		if done:
			_box(r.grow(-3),Color(0,0,0,0.55))
			var cc:=r.get_center()
			clean_ops.append(["line",PackedVector2Array([cc+Vector2(-18,0),cc+Vector2(-5,13),cc+Vector2(20,-14)]),WHITE,6.0])

	if avail:
		_plain_button(game.SIGNIN_CLAIM,ProgressCatalog.text(lang,"claim"))
		_ad_x2_button(game.SIGNIN_DOUBLE,"busy" if game.ad_pending=="signin_double" else "ready")
	else: _ghost_button(Rect2(game.SIGNIN_CLAIM.position,Vector2(game.SIGNIN_DOUBLE.end.x-game.SIGNIN_CLAIM.position.x,game.SIGNIN_CLAIM.size.y)),ProgressCatalog.text(lang,"claim"))
	_toast(712)

func _draw_tasks() -> void:
	var lang: String=game.language_code
	draw_rect(Rect2(0,0,540,game.ui_h),Color(0.025,0.028,0.03,0.92))
	_page_header(ProgressCatalog.text(lang,"tasks"))
	for t in range(2):
		var r: Rect2=game.tasks_tab_rect(t); var on: bool=game.tasks_tab==t
		if on: _slab(r,PAINT_RED)
		else: _frame(r.grow(-3),Color(1,1,1,0.25),1.0)
		_clean_center(bold,Vector2(r.get_center().x,r.get_center().y+8),ProgressCatalog.text(lang,"daily" if t==0 else "limited").to_upper(),20,WHITE if on else MUTED)
		var ready:=false
		for m in (game.daily_missions() if t==0 else game.event_missions()):
			if game.mission_ready(m,t==0): ready=true
		if ready: _red_dot(r.position+Vector2(r.size.x-8,8))
	var line: String
	if game.tasks_tab==0: line=ProgressCatalog.text(lang,"resets")+"  "+_clock(game.seconds_to_midnight())
	else:
		var secs: int=game.event_seconds_left(); var days: int=secs/86400
		line=ProgressCatalog.text(lang,"event")+"  ·  "+ProgressCatalog.text(lang,"ends")+"  "+(("%dd "%days) if days>0 else "")+_clock(secs%86400)
	_clean_text(bold,Vector2(34,178),line.to_upper(),15,HILITE if game.tasks_tab==1 else MUTED,false)
	for row in game.task_rows():
		var r: Rect2=row.rect; var m: Dictionary=row.m; var daily: bool=row.daily
		var value: int=game.mission_value(m,daily); var goal: int=int(m.goal)
		var claimed: bool=game.mission_claimed(m,daily); var ready: bool=game.mission_ready(m,daily)
		_paint(r)
		if ready: _frame(r.grow(-2),Color(HILITE,0.85),2.0)
		_clean_text(bold,r.position+Vector2(18,38),ProgressCatalog.describe(lang,m).to_upper(),21,Color(1,1,1,0.55) if claimed else WHITE)
		# thin stat bar, like the reference's damage / force bars
		var bar:=Rect2(r.position+Vector2(18,64),Vector2(250,6))
		_box(bar,Color(1,1,1,0.14))
		_box(Rect2(bar.position,Vector2(bar.size.x*float(value)/maxf(1.0,goal),bar.size.y)),HILITE if value>=goal else WHITE)
		_clean_text(bold,Vector2(bar.position.x,bar.end.y+22),"%s / %s"%[_grouped(value),_grouped(goal)],14,MUTED,false)
		_reward_line(Vector2(r.end.x-150,r.position.y+40),int(m.coins),int(m.vouchers),20)
		var b: Rect2=game.task_button(r)
		if game.can_swap_mission(int(row.slot),daily): _swap_ad_button(game.task_swap_button(r),game.ad_pending=="swap:%s:%d"%["daily" if daily else "event",int(row.slot)])
		if claimed: _ghost_button(b,ProgressCatalog.text(lang,"claimed"),Color(1,1,1,0.4))
		elif ready: _store_price(b,ProgressCatalog.text(lang,"claim"),true); _red_dot(b.position+Vector2(b.size.x-2,2))
		else: _ghost_button(b,ProgressCatalog.text(lang,"go"))
	_toast(860)

## ---- New personal best on the death screen -----------------------------------------------------
## A white flash, a gold title that pops in, light rays turning behind it, sparkles, and confetti
## that keeps drifting down over the whole screen.
const CONFETTI_COLORS:=[Color("c4a56a"),Color("a94b43"),Color("d8d4ca"),Color("8b6a4d")]

func _draw_new_record() -> void:
	var t: float=game.gameover_time
	var lang: String=game.language_code
	var c:=Vector2(270,150)
	# rays
	var spin: float=t*0.6
	var ray_a: float=0.08+0.3*maxf(0.0,1.0-t)
	for i in range(14):
		var a: float=spin+TAU*i/14.0; var h: float=PI/14.0*0.45
		clean_ops.append(["poly",PackedVector2Array([c,c+Vector2(cos(a-h),sin(a-h)*0.32)*250.0,c+Vector2(cos(a+h),sin(a+h)*0.32)*250.0]),Color(1.0,0.78,0.3,ray_a)])
	if glow_tex:
		var g: float=300.0+30.0*sin(t*3.0)
		clean_ops.append(["tinted",glow_tex,Rect2(c-Vector2(g,g*0.6)*0.5,Vector2(g,g*0.6)),Color(1.0,0.75,0.25,0.55)])
	# title pops in (overshoot), then breathes
	var pop: float=clampf(t/0.35,0.0,1.0)
	var scale: float=lerpf(2.2,1.0,1.0-pow(1.0-pop,3.0))+0.06*sin(t*5.0)*float(pop>=1.0)
	var title: String=ProgressCatalog.text(lang,"new_record")
	_clean_center(bold,c+Vector2(0,18),title,int(54*scale),Color("ffd36b"))
	var best: String=ProgressCatalog.text(lang,"best").replace("%d",_grouped(game.best_distance))
	_clean_center(bold,Vector2(270,214),best,24,WHITE)
	# twinkles around the title
	for k in range(10):
		var ang: float=TAU*k/10.0+t*0.8
		var pos:=c+Vector2(cos(ang)*190.0,sin(ang)*58.0)
		var tw: float=pow(maxf(0.0,sin(t*3.0+k*1.7)),3.0)
		var sz: float=4.0+6.0*tw
		clean_ops.append(["line",PackedVector2Array([pos-Vector2(sz,0),pos+Vector2(sz,0)]),Color(1,0.95,0.8,tw),2.0])
		clean_ops.append(["line",PackedVector2Array([pos-Vector2(0,sz),pos+Vector2(0,sz)]),Color(1,0.95,0.8,tw),2.0])
	# opening flash
	var flash: float=maxf(0.0,0.6-t*1.6)
	if flash>0.0: _box(Rect2(0,0,540,game.ui_h),Color(1,0.96,0.85,flash),Color(0,0,0,0),0,0)

func _record_confetti() -> void:
	var t: float=game.gameover_time
	for k in range(70):
		var h: int=hash("cf"+str(k))
		var x0: float=float(h%540)
		var speed: float=90.0+float((h/540)%120)
		var delay: float=float((h/7)%100)/100.0*1.2
		var tt: float=t-delay
		if tt<0.0: continue
		var y: float=-20.0+fmod(tt*speed+float(h%300)*0.0,1000.0)
		# a burst upward from the title for the first moment, then a steady fall
		var x: float=x0+sin(tt*2.0+k)*18.0
		if tt<0.6:
			y=150.0-sin(tt/0.6*PI)*120.0+tt*speed*0.5
			x=270.0+(x-270.0)*tt/0.6
		var rot: float=tt*(3.0+float(k%5))
		var col: Color=CONFETTI_COLORS[k%CONFETTI_COLORS.size()]
		var w: float=5.0+float(k%3)*2.0; var hgt: float=9.0
		var d1:=Vector2(cos(rot),sin(rot))*w*0.5; var d2:=Vector2(-sin(rot),cos(rot))*hgt*0.5*(0.25+0.75*absf(cos(tt*4.0+k)))
		var p:=Vector2(x,y)
		clean_ops.append(["poly",PackedVector2Array([p-d1-d2,p+d1-d2,p+d1+d2,p-d1+d2]),col])

## Mid-run banner when the old best is passed: pops in under the distance, rays and a short
## confetti burst, then fades out after a few seconds.
func _draw_record_banner() -> void:
	var t: float=3.0-game.record_banner   # 0 -> 3 s
	var a: float=clampf(game.record_banner/0.6,0.0,1.0)
	var c:=Vector2(270,214)
	var spin: float=t*0.8
	for i in range(12):
		var ang: float=spin+TAU*i/12.0; var h: float=PI/12.0*0.4
		clean_ops.append(["poly",PackedVector2Array([c,c+Vector2(cos(ang-h),sin(ang-h))*Vector2(200,70),c+Vector2(cos(ang+h),sin(ang+h))*Vector2(200,70)]),Color(1,0.78,0.3,0.22*a)])
	var pop: float=clampf(t/0.3,0.0,1.0)
	var sc: float=lerpf(1.8,1.0,1.0-pow(1.0-pop,3.0))
	var lang: String=game.language_code
	_clean_center(bold,Vector2(270,226),ProgressCatalog.text(lang,"new_record")+"  "+_grouped(int(game.distance))+" m",int(30*sc),Color(1,0.84,0.42,a))
	if t<1.4:
		for k in range(36):
			var hsh: int=hash("rb"+str(k))
			var ang2: float=TAU*float(hsh%360)/360.0
			var sp: float=120.0+float((hsh/360)%160)
			var p:=c+Vector2(cos(ang2),sin(ang2)*0.6)*sp*t+Vector2(0,140.0*t*t)
			var col: Color=CONFETTI_COLORS[k%CONFETTI_COLORS.size()]; col.a=clampf(1.4-t,0.0,1.0)
			var rot: float=t*6.0+k
			var d1:=Vector2(cos(rot),sin(rot))*3.5; var d2:=Vector2(-sin(rot),cos(rot))*5.0
			clean_ops.append(["poly",PackedVector2Array([p-d1-d2,p+d1-d2,p+d1+d2,p-d1+d2]),col])

## The red cross's offer: watch a rewarded ad to restore 4 health cells. Same worn-console
## style as the other popups: dim the frozen run, one panel, one primary action.
func _draw_health_ad_prompt() -> void:
	var zh: bool=game.language_code.begins_with("zh")
	_box(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.72))
	var p: Rect2=game.HEALTH_AD_PANEL
	_paint(p,Color(0.05,0.052,0.056,0.98))
	var c:=Vector2(p.get_center().x,p.position.y+58)
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-20,0),c+Vector2(20,0)]),Color("e0453d"),8.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(0,-20),c+Vector2(0,20)]),Color("e0453d"),8.0])
	_section(Vector2(-1,p.position.y+120),"看广告恢复血量" if zh else "WATCH AD TO HEAL",26)
	var sub: String="恢复 %d 格血量" % game.HEALTH_AD_CELLS if zh else "Restore %d health cells" % game.HEALTH_AD_CELLS
	var sw: float=font.get_string_size(sub,HORIZONTAL_ALIGNMENT_LEFT,-1,_scaled(17)).x
	clean_ops.append(["text",font,Vector2(c.x-sw/2,p.position.y+166),sub,_scaled(17),Color(1,1,1,0.75)])
	_button(game.HEALTH_AD_WATCH,("观看广告  +%d格" % game.HEALTH_AD_CELLS) if zh else ("WATCH AD  +%d" % game.HEALTH_AD_CELLS),true)
	_button(game.HEALTH_AD_CANCEL,"取消" if zh else "CANCEL",false)

## "Top-up failed" popup: red title stroke, short explanation, Retry / Close.
func _draw_payfail() -> void:
	var lang: String=game.language_code
	_box(Rect2(0,0,540,game.ui_h),Color(0,0,0,0.72))
	var p: Rect2=game.PAYFAIL_PANEL
	_paint(p,Color(0.05,0.052,0.056,0.98))
	var c:=Vector2(p.get_center().x,p.position.y+70)
	clean_ops.append(["line",PackedVector2Array([c+Vector2(-20,-20),c+Vector2(20,20)]),Color("e0453d"),8.0])
	clean_ops.append(["line",PackedVector2Array([c+Vector2(20,-20),c+Vector2(-20,20)]),Color("e0453d"),8.0])
	_section(Vector2(-1,p.position.y+118),StoreCatalog.text(lang,"pay_failed"),26)
	var msg: String=StoreCatalog.text(lang,"pay_failed_msg")
	var size: int=_scaled(17); var maxw: float=p.size.x-60
	var lines:=[]; var line:=""
	var cjk:=false
	for i in range(msg.length()):
		if msg.unicode_at(i)>0x2E7F: cjk=true; break
	var parts: PackedStringArray=msg.split("") if cjk else msg.split(" ")
	var total: float=font.get_string_size(msg,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var n_lines: int=int(ceil(total/maxw))
	if n_lines>1: maxw=minf(maxw,total/n_lines*1.12)
	for w in parts:
		var trial: String=line+w if cjk or line.is_empty() else line+" "+w
		if font.get_string_size(trial,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>maxw and not line.is_empty():
			lines.append(line); line=w
		else: line=trial
	if not line.is_empty(): lines.append(line)
	for i in range(lines.size()):
		var lw: float=font.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		clean_ops.append(["text",font,Vector2(c.x-lw/2,p.position.y+206+i*(size+8)),lines[i],size,Color(1,1,1,0.75)])
	_store_price(game.PAYFAIL_RETRY,StoreCatalog.text(lang,"retry"),true)
	_ghost_button(game.PAYFAIL_CLOSE,StoreCatalog.text(lang,"close"))


var _terms_lines_cache: PackedStringArray
var _terms_loaded: bool = false

## Wrapped text lines of the legal disclaimer (markdown '#' stripped, word-wrapped to 400px).
func _terms_lines() -> PackedStringArray:
	if _terms_loaded: return _terms_lines_cache
	var txt: String = FileAccess.get_file_as_string("res://assets/legal/terms.txt").replace("#","")
	var size: int = _scaled(15)
	var maxw: float = 400.0
	var out: PackedStringArray = []
	for raw_line in txt.split("\n", false):
		var line: String = raw_line.strip_edges(false, true)
		if line.is_empty():
			out.append("")
			continue
		var cur: String = ""
		for w in line.split(" "):
			var trial: String = w if cur.is_empty() else cur + " " + w
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > maxw and not cur.is_empty():
				out.append(cur); cur = w
			else: cur = trial
		if not cur.is_empty(): out.append(cur)
	_terms_lines_cache = out
	_terms_loaded = true
	return _terms_lines_cache

## Pixels of scrollable overflow in the terms text area; the game clamps terms_scroll to this.
func terms_max_scroll() -> float:
	var lh: int = _scaled(21)
	return maxf(0.0, _terms_lines().size() * lh - game.TERMS_TEXT_AREA.size.y)

## First-launch legal gate: a small solid-black window over the login page (cover).
## The cover poster stays fully visible around the window (no full-screen black),
## everything outside the window is the unmodified poster.
func _draw_terms() -> void:
	var zh: bool = game.language_code.begins_with("zh")
	# Background is still the login poster itself.
	_draw_cover()
	var panel: Rect2 = game.TERMS_PANEL
	_box(panel, Color(0, 0, 0, 1))
	_frame(panel, Color(1, 1, 1, 0.5), 2.0)
	_section(Vector2(-1, 228), "DREADLINE · TERMS OF USE & DISCLAIMER", 22)
	var area: Rect2 = game.TERMS_TEXT_AREA
	var size: int = _scaled(15)
	var lh: int = _scaled(21)
	var y0: float = area.position.y - game.terms_scroll
	var lines: PackedStringArray = _terms_lines()
	for i in range(lines.size()):
		var y: float = y0 + i * lh
		if y + lh < area.position.y or y > area.end.y: continue
		if not lines[i].is_empty():
			clean_ops.append(["text", font, Vector2(area.position.x + 4, y), lines[i], size, Color(1, 1, 1, 0.82)])
	_frame(area, Color(1, 1, 1, 0.14), 1.0)
	_button(game.TERMS_DISAGREE, "不同意 · 退出" if zh else "DISAGREE · EXIT", false)
	_button(game.TERMS_AGREE, "同意并继续" if zh else "I AGREE", true)


## Debug aid for device-only problems: if any model failed to load, say which one, in a
## corner small enough not to disturb play. A screenshot is then enough to identify it.
func _draw_missing_assets() -> void:
	if ModelFix.missing.is_empty():
		return
	var msg: String = "MISSING: " + String(ModelFix.missing[0]).get_file()
	draw_string(ThemeDB.fallback_font, Vector2(12, size.y - 14), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.45, 0.4, 0.9))