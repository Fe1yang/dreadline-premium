extends Node3D
## Upgrade gate: glowing barrier panels across the road, like the "pick a side" gates in runner
## games. Two panels early on, three later in the run. Each panel shows one buff in big lettering;
## the survivor runs through one and gets that buff. The chosen panel flares, the others fade.
##
## Roguelike rarity: most buffs are common (plain blue / green / red panels); now and then a rare
## (purple), epic (orange) or legendary (gold, with a light beam and sparkles) one turns up with a
## much bigger effect, and a rarity tag above the panel.

const GameText=preload("res://scripts/game_text.gd")
const ROAD_HALF:=3.15
const PANEL_BOTTOM:=0.22
const PANEL_TOP:=1.95
const POST_HEIGHT:=2.15
# Common panels: left blue, right red, and green for the middle one when there are three.
const SIDE_COLORS:=[Color("2f7bff"),Color("ff3b3b")]
const SIDE_COLORS_3:=[Color("2f7bff"),Color("22b35e"),Color("ff3b3b")]
const RARITY_COLORS:=[Color("ffffff"),Color("a259ff"),Color("ff8a1f"),Color("ffc928")]
const RARITY_NAMES:={
	"en":["","RARE","EPIC","LEGENDARY"],"zh_CN":["","稀有","史诗","传说"],"zh_TW":["","稀有","史詩","傳說"],
	"ja":["","レア","エピック","レジェンド"],"ko":["","레어","에픽","전설"],"es":["","RARO","ÉPICO","LEGENDARIO"],
	"fr":["","RARE","ÉPIQUE","LÉGENDAIRE"],"de":["","SELTEN","EPISCH","LEGENDÄR"],"pt":["","RARO","ÉPICO","LENDÁRIO"],
	"ru":["","РЕДКОЕ","ЭПИЧЕСКОЕ","ЛЕГЕНДАРНОЕ"],"ar":["","نادر","ملحمي","أسطوري"],"hi":["","दुर्लभ","महाकाव्य","पौराणिक"],
	"id":["","LANGKA","EPIK","LEGENDARIS"],"it":["","RARO","EPICO","LEGGENDARIO"],"tr":["","NADİR","DESTANSI","EFSANEVİ"],
	"nl":["","ZELDZAAM","EPISCH","LEGENDARISCH"],"pl":["","RZADKIE","EPICKIE","LEGENDARNE"],"th":["","หายาก","มหากาพย์","ตำนาน"],
	"vi":["","HIẾM","SỬ THI","HUYỀN THOẠI"],"uk":["","РІДКІСНЕ","ЕПІЧНЕ","ЛЕГЕНДАРНЕ"]}

static var gate_font: Font

var language:="en"
var options: Array=[]
var left: Dictionary={}   # first option (kept for older callers / tests)
var right: Dictionary={}  # last option
var resolved:=false
var selected:=-1
var fade:=1.0
var pulse:=0.0
var labels: Array[Label3D]=[]
var panels: Array[MeshInstance3D]=[]
var panel_mats: Array[StandardMaterial3D]=[]
var trim_mats: Array[StandardMaterial3D]=[]
var glow_mats: Array[StandardMaterial3D]=[]
var beam_mats: Array[StandardMaterial3D]=[]
var colors: Array[Color]=[]
var halves: Array[Node3D]=[]
var flare:=0.0

static func _font() -> Font:
	if gate_font==null:
		var base:=(load("res://assets/fonts/hud_condensed_bold.otf") as FontFile).duplicate() as FontFile
		var fallbacks: Array[Font]=[]
		if ResourceLoader.exists("res://assets/fonts/hud_cjk_black.otf"): fallbacks.append(load("res://assets/fonts/hud_cjk_black.otf"))
		var system:=SystemFont.new(); system.font_names=PackedStringArray(["Microsoft YaHei","PingFang SC","Noto Sans CJK SC","Segoe UI","Arial"])
		fallbacks.append(system); base.fallbacks=fallbacks
		var heavy:=FontVariation.new(); heavy.base_font=base; heavy.variation_embolden=0.6
		gate_font=heavy
	return gate_font

## options: 2 or 3 dictionaries {id, rarity 0-3, value, title, detail}.
func setup(opts: Array,language_code:="en") -> void:
	language=language_code
	options=opts; left=opts[0]; right=opts[opts.size()-1]
	var n:=opts.size()
	var width:=2.0*ROAD_HALF/n
	for i in range(n):
		_make_option(opts[i],-ROAD_HALF+width*(i+0.5),i,width,n)
	for i in range(n+1): _post(-ROAD_HALF+width*i)

func _unshaded(color: Color,add:=false) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=color
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	if add: m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	return m

func _box(parent: Node3D,pos:Vector3,size:Vector3,mat: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; n.mesh=mesh
	n.position=pos; n.material_override=mat; parent.add_child(n); return n

func _post(x: float) -> void:
	var post_mat:=StandardMaterial3D.new(); post_mat.albedo_color=Color("2f3436"); post_mat.roughness=0.5; post_mat.metallic=0.5
	var n:=MeshInstance3D.new(); var c:=CylinderMesh.new(); c.top_radius=0.09; c.bottom_radius=0.11; c.height=POST_HEIGHT
	n.mesh=c; n.position=Vector3(x,POST_HEIGHT*0.5,0); n.material_override=post_mat; add_child(n)
	var cap:=MeshInstance3D.new(); var s:=SphereMesh.new(); s.radius=0.13; s.height=0.26; cap.mesh=s
	cap.position=Vector3(x,POST_HEIGHT,0); cap.material_override=post_mat; add_child(cap)
	var foot:=MeshInstance3D.new(); var f:=CylinderMesh.new(); f.top_radius=0.16; f.bottom_radius=0.2; f.height=0.1
	foot.mesh=f; foot.position=Vector3(x,0.05,0); foot.material_override=post_mat; add_child(foot)

func _label(parent: Node3D,text: String,pos: Vector3,size: int,pixel: float,max_w: float,col: Color,outline: Color) -> Label3D:
	var l:=Label3D.new(); l.text=text; l.font=_font()
	l.font_size=_fit(text,size,max_w,pixel); l.pixel_size=pixel; l.outline_size=28
	l.modulate=col; l.outline_modulate=outline
	l.position=pos; l.double_sided=false; l.render_priority=5; l.outline_render_priority=4
	parent.add_child(l); labels.append(l); return l

func _make_option(option: Dictionary,x: float,index: int,slot: float,count: int) -> void:
	var rarity: int=int(option.get("rarity",0))
	var color: Color
	if rarity>0: color=RARITY_COLORS[rarity]
	else: color=(SIDE_COLORS_3 if count==3 else SIDE_COLORS)[index]
	colors.append(color)
	var half:=Node3D.new(); half.position=Vector3(x,0,0); add_child(half); halves.append(half)
	var width:=slot-0.12
	var height:=PANEL_TOP-PANEL_BOTTOM
	var mid_y:=(PANEL_TOP+PANEL_BOTTOM)*0.5
	# Translucent glowing barrier sheet: rarer = denser and brighter.
	var deep:=color.darkened(0.15); deep.s=minf(1.0,deep.s*1.35)
	var sheet_mat:=_unshaded(Color(deep.r,deep.g,deep.b,0.28+0.06*rarity))
	panels.append(_box(half,Vector3(0,mid_y,0),Vector3(width,height,0.03),sheet_mat)); panel_mats.append(sheet_mat)
	var trim:=_unshaded(color.lightened(0.25)); trim_mats.append(trim)
	var trim_h:=0.09+0.03*rarity
	_box(half,Vector3(0,PANEL_TOP,0.0),Vector3(width,trim_h,0.07),trim)
	_box(half,Vector3(0,PANEL_BOTTOM,0.0),Vector3(width,0.07,0.07),trim)
	if rarity>=2: # side bars too, so epic / legendary read as framed
		for sx in [-width*0.5,width*0.5]: _box(half,Vector3(sx,mid_y,0.0),Vector3(0.06,height,0.07),trim)
	var glow:=_unshaded(Color(color.r,color.g,color.b,0.10+0.08*rarity),true); glow_mats.append(glow)
	_box(half,Vector3(0,mid_y,-0.02),Vector3(width+0.3+0.2*rarity,height+0.3+0.2*rarity,0.01),glow)
	if rarity==3:
		# Legendary: a tall beam of light and sparkles drifting up through the panel.
		var beam:=_unshaded(Color(color.r,color.g,color.b,0.22),true); beam_mats.append(beam)
		_box(half,Vector3(0,PANEL_TOP+2.4,-0.05),Vector3(width*0.7,4.8,0.02),beam)
		var sparks:=CPUParticles3D.new(); sparks.amount=28; sparks.lifetime=1.6
		sparks.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX; sparks.emission_box_extents=Vector3(width*0.45,0.1,0.1)
		sparks.direction=Vector3.UP; sparks.spread=12.0; sparks.initial_velocity_min=0.8; sparks.initial_velocity_max=1.6
		sparks.gravity=Vector3.ZERO; sparks.scale_amount_min=0.04; sparks.scale_amount_max=0.08
		var spark_mesh:=SphereMesh.new(); spark_mesh.radius=0.5; spark_mesh.height=1.0; spark_mesh.radial_segments=6; spark_mesh.rings=3
		spark_mesh.material=_unshaded(Color(1.0,0.92,0.6,0.95),true); sparks.mesh=spark_mesh
		sparks.position=Vector3(0,PANEL_BOTTOM+0.1,0.1); half.add_child(sparks)
	# Lettering: the effect huge, the name smaller above it; rarity tag on top of the frame.
	var title: String; var detail: String
	if option.has("label"):
		title=String(option.label[0]); detail=String(option.label[1])
	else:
		var parts:=String(GameText.gate(language,option.id,option.title+"|"+option.detail)).split("|")
		title=parts[0]; detail=_with_value(parts[1] if parts.size()>1 else "",option)
	var text_w:=width-0.35
	var scale_k:=1.0 if count==2 else 0.82
	var outline:=color.darkened(0.65)
	var cut:=detail.rfind(" ")
	if count==3 and cut>0:
		# narrow panel: name, then the stat word, then the number as big as it will go
		_label(half,detail.substr(cut+1),Vector3(0,mid_y-0.42,0.05),112,0.0092,text_w,Color.WHITE,outline)
		_label(half,detail.substr(0,cut),Vector3(0,mid_y+0.17,0.05),58,0.0072,text_w,Color(1,1,1,0.9),outline)
		_label(half,title,Vector3(0,mid_y+0.57,0.05),62,0.0072,text_w,Color.WHITE,outline)
	else:
		_label(half,detail,Vector3(0,mid_y-0.22,0.05),int(150*scale_k),0.0092,text_w,Color.WHITE,outline)
		_label(half,title,Vector3(0,mid_y+0.50,0.05),int(110*scale_k),0.0072,text_w,Color.WHITE,outline)
	if rarity>0:
		var names: Array=RARITY_NAMES.get(language,RARITY_NAMES["en"])
		var tag:=String(names[rarity])
		var plate:=_unshaded(Color(0.04,0.04,0.05,0.85))
		_box(half,Vector3(0,PANEL_TOP+0.28,0.02),Vector3(minf(width*0.8,1.9),0.36,0.03),plate)
		_label(half,tag,Vector3(0,PANEL_TOP+0.28,0.06),int(80*scale_k),0.0062,minf(width*0.75,1.8),color.lightened(0.2),Color(0,0,0,0.9))

## Swaps the number in the localized detail ("伤害 +8%") for this option's rolled value.
static func _with_value(detail: String,option: Dictionary) -> String:
	if not option.has("value"): return detail
	var re:=RegEx.new(); re.compile("\\d+")
	var m:=re.search(detail)
	if m==null: return detail
	return detail.substr(0,m.get_start())+str(int(option.value))+detail.substr(m.get_end())

## Shrinks the font so long words (German, Russian...) still fit inside the panel width.
func _fit(text: String,size: int,max_width_m: float,pixel: float) -> int:
	var f:=_font()
	while size>30 and f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*pixel>max_width_m: size-=6
	return size

func tick(delta: float) -> void:
	pulse+=delta
	position.z+=3.5*delta
	if not resolved:
		# Gentle shimmer; rare and better pulse harder, legendary throbs gold.
		for i in range(panel_mats.size()):
			var r: int=int(options[i].get("rarity",0))
			panel_mats[i].albedo_color.a=0.26+0.06*r+(0.05+0.05*r)*sin(pulse*(3.0+r)+i*1.7)
			glow_mats[i].albedo_color.a=0.10+0.08*r+0.06*r*maxf(0.0,sin(pulse*4.0+i))
		for b in beam_mats: b.albedo_color.a=0.16+0.10*sin(pulse*5.0)
		return
	fade=maxf(0.0,fade-delta*1.6)
	flare=maxf(0.0,flare-delta*2.5)
	for i in range(halves.size()):
		var chosen: bool=i==selected
		var a: float=fade if chosen else fade*fade*0.6
		panel_mats[i].albedo_color.a=(0.28+0.5*flare)*a if chosen else 0.28*a
		trim_mats[i].albedo_color.a=a
		glow_mats[i].albedo_color.a=0.15*a
		if chosen: halves[i].scale=Vector3.ONE*(1.0+0.12*flare)
	for b in beam_mats: b.albedo_color.a=0.2*fade
	for label in labels: label.modulate.a=fade; label.outline_modulate.a=fade

func lane_of(player_x: float) -> int:
	var n:=options.size()
	return clampi(int((player_x+ROAD_HALF)/(2.0*ROAD_HALF)*n),0,n-1)

func chosen_color() -> Color:
	return colors[selected] if selected>=0 else Color.WHITE

func choose(player_x: float) -> Dictionary:
	if resolved: return {}
	resolved=true; selected=lane_of(player_x); flare=1.0
	return options[selected]
