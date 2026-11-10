extends Node3D

const PlayerScript=preload("res://scripts/player_3d.gd")
const ZombieScript=preload("res://scripts/zombie_3d.gd")
const BulletScript=preload("res://scripts/bullet_3d.gd")
const OrdnanceScript=preload("res://scripts/ordnance_projectile_3d.gd")
const GateScript=preload("res://scripts/gate_3d.gd")
const BuffCatalog=preload("res://scripts/buff_catalog.gd")
const ExtraText=preload("res://scripts/extra_text.gd")
const RunText=preload("res://scripts/run_text.gd")
const IapScript=preload("res://scripts/iap_service.gd")
const BarrelScript=preload("res://scripts/barrel_3d.gd")
const WeaponCrateScript=preload("res://scripts/weapon_crate_3d.gd")
const BarrelRollScript=preload("res://scripts/barrel_roll_3d.gd")
const CRATE_WEAPONS:=["SMG","SHOTGUN","SNIPER","PISTOL","LAUNCHER","RIFLE","MAKAROV","SUOMI"]
const CRATE_TIER:={"HELMET":0.9,"ARMOR":1.0,"PISTOL":0.7,"RIFLE":0.9,"SMG":1.0,"SHOTGUN":1.1,"SNIPER":1.25,"LAUNCHER":1.5,"BIKE":1.2}
const RoadObstacleScript=preload("res://scripts/road_obstacle_3d.gd")
const PickupScript=preload("res://scripts/pickup_3d.gd")
const EffectScript=preload("res://scripts/effect_3d.gd")
const ExplosionScript=preload("res://scripts/explosion_3d.gd")
const SoundScript=preload("res://scripts/sound.gd")
const HudScript=preload("res://scripts/hud.gd")
const RevivalAdsScript=preload("res://scripts/revival_ads.gd")
const Localization=preload("res://scripts/localization.gd")
const ShopCatalog=preload("res://scripts/shop_catalog.gd")
const StoreCatalog=preload("res://scripts/store_catalog.gd")
const StaminaScript=preload("res://scripts/stamina_system.gd")
const ProgressCatalog=preload("res://scripts/progress_catalog.gd")
const ShopText=preload("res://scripts/shop_text.gd")
const ShopSceneScript=preload("res://scripts/shop_scene_3d.gd")
const LootboxSceneScript=preload("res://scripts/lootbox_scene_3d.gd")
const MapTableScript=preload("res://scripts/map_table_3d.gd")
const LobbySceneScript=preload("res://scripts/lobby_scene_3d.gd")
const DisasterDressing=preload("res://scripts/disaster_dressing_3d.gd") # Kimi: blood, drag marks, rubble, idle watchers on every block
const BloodPoolScript=preload("res://scripts/blood_pool_3d.gd")
const MAX_BLOOD_POOLS:=60
## Concurrent zombies are capped: every one is a skinned model, and 26 at once is what a
## phone cannot do. The wave quota still arrives, just in two or three ranks.
const MAX_ALIVE_ZOMBIES:=14
## The city loop is 384 m and the run looks straight down it, so the whole loop used to be
## submitted every frame. Blocks fade out at the preset distance instead.
const VIEW_CULL_END_HIGH:=150.0
const VIEW_CULL_END_FAST:=135.0
const VIEW_CULL_FADE:=26.0
var view_cull_end:=VIEW_CULL_END_HIGH
const BossChaserScript=preload("res://scripts/boss_chaser_3d.gd")
# Sky domes (Poly Haven, CC0, 2K HDR): a broken-cloud sky for clear runs, a heavy overcast for rain and fog.
# Procedural cloud sky from the user's sky pack (shaders/sky_clouds.gdshader); one material,
# recoloured per weather.
const SKY_SHADER=preload("res://shaders/sky_clouds.gdshader")
# Binbun-style stylised skies: saturated gradient, bright puffy cloud layers with parallax.
# "mix" is the pack's day/sunset blend (1 = full day, ~0.1 = golden hour).
const SKY_PRESETS:={
	"clear":{"sky":Color("3988c4"),"horizon":Color("b9d9e8"),"sunset_sky":Color("303b68"),"sunset_horizon":Color("d9956c"),"cloud":Color("f4f2e9"),"density":0.96,"depth":2.4,"wind":Vector2(0.35,0.18),"mix":1.0,"energy":0.96,"tiling":0.75},
	"sunset":{"sky":Color("2a3f8f"),"horizon":Color("ff8a3d"),"sunset_sky":Color("2c2f7a"),"sunset_horizon":Color("ff6a2a"),"cloud":Color("ffb57a"),"density":1.0,"depth":3.0,"wind":Vector2(0.3,0.15),"mix":0.12,"energy":1.0,"tiling":0.75},
	"rain":{"sky":Color("3d4a58"),"horizon":Color("7f8d99"),"cloud":Color("6e7984"),"density":1.6,"depth":3.5,"wind":Vector2(0.7,0.35),"mix":1.0,"energy":1.05,"tiling":0.9},
	"storm":{"sky":Color("141b26"),"horizon":Color("394556"),"cloud":Color("2c3440"),"density":2.3,"depth":4.0,"wind":Vector2(1.3,0.6),"mix":1.0,"energy":0.95,"tiling":1.0},
	"fog":{"sky":Color("8f9ea8"),"horizon":Color("d3dade"),"cloud":Color("e1e6e9"),"density":1.3,"depth":2.0,"wind":Vector2(0.2,0.1),"mix":1.0,"energy":1.1,"tiling":0.8}}
const EnvironmentMaterials=preload("res://scripts/environment_materials.gd")
const ROAD_SEGMENT:=16.0
const ROAD_COUNT:=24
const ROAD_LOOP:=ROAD_SEGMENT*ROAD_COUNT
const ROAD_BEHIND:=56.0 # city blocks kept behind the player for intro/chase shots
const DAY_NIGHT_CYCLE_METRES:=20000.0 # day at 0 m, night at 10 km, day again at 20 km
var day_start_offset:=0.0  # metres into the 20 km cycle where this run begins
var night_amount:=0.0
var night_announced:=false   # the night song has played for the current dark stretch

var state:="cover"
# Loading screen (state "loading"): random loading art + "加载中..." progress, then
# the target ("lobby" or "run") is entered. See _begin_loading / _finish_loading.
var loading_time:=0.0
var loading_duration:=2.8
var loading_progress:=0.0
var loading_target:="lobby"
var loading_order: Array[int] = []
var loading_idx:=0
var loading_switch:=0.0
var intro_time:=0.0
var intro_horde_offsets: Array[Vector3]=[]
var chaser: Node3D # the giant Chaser that leads the opening pursuit
const CHASER_OFFSET:=Vector3(0,0,8.2)
## Mid-run chase segments: every few hundred metres the Abomination bursts out of the horde
## and runs the survivor down for a stretch. It gains steadily; every hit the survivor takes
## is a stumble that lets it closer, and if it gets within reach it mauls. Outlast the timer
## to shake it — a clean escape pays coins.
var chase_active:=false
var chase_cam_weight:=0.0  # 0 = normal runner camera, 1 = framed for the pursuer behind
var chase_time:=0.0          # seconds left in the current segment
var chase_gap:=0.0           # metres between the beast and the survivor
var chase_growl:=0.0
var next_chase_at:=8000.0    # run distance of the next ambush (none early in a run)
const CHASE_DURATION:=13.0
const CHASE_START_GAP:=16.0
const CHASE_CATCH:=2.6       # within reach: it starts mauling
const CHASE_CLOSE_RATE:=1.05 # metres per second it gains on an even runner
const CHASE_STUMBLE:=2.6     # metres lost per hit taken during the chase
const CHASE_MAUL_DPS:=11.0
const CHASE_REWARD:=25
var character_choice:=0
var skin_choice:={} # char index -> index into lobby.SKINS (outfit override, stats unchanged)
var pet_choice:=0
var language_code:="zh_CN"
var player: Node3D
var debug_show_fps := false   # F3: on-screen frame time counter
var debug_hide_pickups := false
var companion_pet: Node3D  # first dog; kept as an alias of companion_pets[0] for HUD/tests
var companion_pets: Array=[]  # up to MAX_COMPANION_PETS dogs, duplicates allowed
var sound: Node
var hud: Control
var revival_ads: Node
var camera: Camera3D
## Debug only: when true the run camera stops following so a probe can park it anywhere
## (used to verify weapon/helmet placement at close range).
var debug_camera_hold := false

## Park the camera somewhere and keep it there. Debug helper for placement checks.
func debug_camera_at(pos: Vector3, target: Vector3, fov := 40.0) -> void:
	debug_camera_hold = true
	camera.global_position = pos
	camera.look_at(target, Vector3.UP)
	camera.fov = fov

func debug_camera_release() -> void:
	debug_camera_hold = false
var capture_close_cam:=false # freeze follow cam for close-up seat-fit screenshots
var shop_truck: Node3D
var lootbox_scene: Node3D
var map_scene: Node3D
var lobby: Node3D
var settings_return_state:="cover"
var text_size:=1 # 0 small, 1 medium (default), 2 large: for players who need bigger text
## HIGH is the authored look (the build 16 picture); FAST is for older phones.
var quality_high:=true
var lobby_toast:=0.0
## Second currency (券), bought in the store; nothing spends it yet.
var bank_vouchers:=0
## Cans are run energy: 10 per run, one restored naturally every three minutes.
var stamina: Node
## A dog only comes along (intro chase and runs) once the player has picked one in the pet tab;
## tapping the equipped dog again sends it home.
var pet_equipped:=false
## Dogs are locked until won from a case (then owned for good). In a run a locked dog can still
## turn up on a platform: shoot it free and it runs with you for that run only.
var owned_pets:={}            # pet index -> true
## Mason and Riley are free; Darius, Maya and the outfit skins are one-time store purchases.
var owned_characters:={}      # char index -> true
var owned_skins:={}           # lobby.SKINS index -> true
var owned_vehicle:=""
## Lobby loadout switch. false = no vehicle and no pet in the run (testing).
var equip_menu_index:=-1  # card whose EQUIP dropdown is open
var equip_menu_tab:=0     # ...and which tab it belongs to
var loadout_on:=true
var vehicle_equipped:=true
## Whether the owned special weapon (the flamethrower) is carried into a run.
var weapon_equipped:=true         # "" = none, "BIKE" = bought motorcycle (auto-rides every run's first 1000m)
const VEHICLE_AUTO_RANGE:=1000.0 # bought bike auto-rides every run until this distance (or durability runs out)
var vehicle_auto_active:=false
## Road scroll speed for this frame; barrels and crates ride the same number.
var world_speed:=3.5
## Distance at which the bought bike gives out; a fuel can pushes it out again.
var vehicle_range_end:=VEHICLE_AUTO_RANGE
var lobby_toast_key:="coming" # ShopText key the lobby toast shows
var lobby_preview_character:=-1      # locked survivor/skin being previewed on the platform
var lobby_preview_asset:=""          # skin asset for the preview ("" = default body)
const MAX_COMPANION_PETS:=4  # most dogs that can follow and bite in one run
const PET_CRATE_CHANCE:=0.08
const GEAR_CRATE_CHANCE:=0.22
const FUEL_CRATE_CHANCE:=0.30   # only while riding or holding the flamethrower # helmet / armour on a platform instead of a gun
const BIKE_CRATE_CHANCE:=0.14  # a motorcycle: ride it, ram zombies, until it breaks apart
## Durability lost per zombie run down on the bike, by kind.
const BIKE_RAM_COST:={"walker":8.0,"walker_b":8.0,"walker_c":8.0,"runner":6.0,"runner_b":6.0,"brute":22.0,"jockey":10.0,"banshee":18.0,"spitter":14.0,"bomber_male":30.0,"bomber_female":30.0}
const BIKE_DECAY:=1.8           # durability per second — a careful ride lasts about a minute
## District 14's missile crater is a real hole in the road: it blocks the survivor and
## the horde instead of being a floor decal. Must match build_city_districts.py.
const CRATER_RADIUS:=1.70
const CRATER_X:=-0.65
## Real-money store page (state "store"), opened from the + next to a balance.
var store_return_state:="character_select"
var store_scroll:=0.0
var store_press:=Vector2(-1,-1)
var store_dragged:=false
var store_toast:=0.0
var store_toast_text:=""
## Store rewarded ads: +5 cans per completed view, at most ten per local calendar day.
const CAN_AD_REWARD:=5
const CAN_AD_DAILY_LIMIT:=10
var can_ad_day:=""
var can_ad_count:=0
var store_owned:={}  # once-only packs already bought
## In-app purchases (StoreKit 2 on iOS, a simulator in the editor): see iap_service.gd.
var iap: Node
var iap_ledger:={}        # StoreKit transaction IDs already granted (saved)
var remove_ads:=false     # non-consumable: rewarded ads are skipped, the reward is given directly

## Offered once per session, right after a rewarded ad pays out.
var ads_offer_open:=false
var ads_offer_seen:=false
var ads_offer_shows:=0
const ADS_OFFER_MAX_SHOWS:=2
const ADS_OFFER_CARD:=Rect2(46,300,448,420)
const ADS_OFFER_BUY:=Rect2(70,582,400,66)
const ADS_OFFER_LATER:=Rect2(70,664,400,52)

func ads_offer_price() -> String:
	if iap!=null and iap.prices.has("removeads"): return String(iap.prices["removeads"])
	return "$9.99"

func maybe_offer_no_ads() -> void:
	if PREMIUM_BUILD: return
	if remove_ads or ads_offer_shows>=ADS_OFFER_MAX_SHOWS: return
	ads_offer_shows+=1
	_save()
	ads_offer_open=true
	_release_touches()

func ads_offer_tap(pos: Vector2) -> void:
	if ADS_OFFER_BUY.has_point(pos):
		ads_offer_open=false
		buy_pack("removeads")
		return
	ads_offer_open=false

## One zombie in twenty thousand carries a lottery ticket. No model: just the line of text.
const VOUCHER_DROP_CHANCE := 0.00005

const REMOVE_ADS_PACK:={"id":"removeads","kind":"bundle","name":"removeads","coins":0,"vouchers":0,"tier":3,"bonus":0,"once":true,"glow":"red","rays":10}
var store_currency:=""
## "Top-up failed" popup (state "payfail"): shown whenever a purchase doesn't go through, with
## Retry (same pack again) and Close. Opens over the store or the limited-offer popup.
var payfail_pack:=""
var payfail_return_state:="store"
const PAYFAIL_PANEL:=Rect2(50,300,440,360)
const PAYFAIL_RETRY:=Rect2(74,572,186,60)
const PAYFAIL_CLOSE:=Rect2(280,572,186,60)
## Measured widths of the can, coin, silver and voucher numbers (hud.gd updates them while drawing)
## so the + buttons sit right after the numbers however long they get.
var wallet_text_w:=Vector4(72,92,92,64)
## Limited-time offer (限时礼包). Shown at most every 2-3 days, and not to someone who has
## already played a long time today. While one is running it also sits in the lobby and the
## store with its countdown.
const OFFER_GAP_HOURS:=Vector2(20,26)
const OFFER_SKIP_AFTER_MINUTES:=180.0
var offer_id:=""
var last_offer_id:=""  # so two days never show the same bundle
var offer_expires:=0
var next_offer_at:=0
var play_day:=""
var play_seconds_today:=0.0
var offer_return_state:="character_select"
## Resource-shortage packs are separate from limited offers: they open only after a failed spend.
var resource_pack_id:=""
var resource_pack_return_state:="character_select"
## Check-in and missions (see "Check-in and missions" below).
var signin_last:=""          # date of the last check-in claim
var signin_index:=0          # next day of the 7-day cycle (0-6)
var signin_monthly:=false     # true: the 30-day track is on screen
var signin_month_index:=0    # next day of the 30-day track
var signin_month_key:=""    # YYYY-MM it belongs to
var signin_shown_day:=""     # the check-in pops up by itself once a day
var signin_return_state:="character_select"
var daily_day:=""
var daily_stats:={}
var daily_claimed:={}
## Missions swapped out by watching an ad: slot index -> replacement mission id (reset with the day / event).
var daily_swaps:={}
var event_swaps:={}
var event_window:=-1
var event_stats:={}
var event_claimed:={}
var tasks_tab:=0
var tasks_return_state:="character_select"
var run_counted_distance:=0.0
var run_counted:=false
# Weather: each run randomly rolls clear, rain or fog (no snow on this city map).
const RainShader=preload("res://shaders/rain_and_snow.gdshader")
var weather:="clear"
var run_weather:="clear"
var runs_this_launch:=0 # the first run after launching is always clear weather # remembered while the shop overrides the lighting
var world_env: Environment
var sky_material: ShaderMaterial
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D # soft sky fill by day, readable moonlight after dark
var street_lamps: Array[Dictionary]=[]
var rain_overlay: ColorRect
var rain_material: ShaderMaterial
var lightning_flash: ColorRect
var lightning_timer:=6.0
var lightning_t:=-1.0      # time since the current strike started (<0: none)
var thunder_delay:=-1.0
var weather_base:={}
## Rain on the ground: a wet sheen plane over the road plus splash ripples.
var wet_sheen: MeshInstance3D
var wet_mat: StandardMaterial3D
var wet_fade := 0.0
var wet_target := 0.0
var splash_accum := 0.0
var force_sunset:=false # preview/testing only       # exposure / sun / ambient of the current weather, restored after a flash
var shop_return_state:="cover"
var shop_items: Array=[]
var bank_coins:=0
var bank_silver:=0
var run_coins:=0
var run_silver:=0
## Rewarded-ad doubles: extra coins already paid for this run's result, and which ad is playing.
var run_double_bonus:=0
var run_double_silver:=0
var ad_pending:=""
## A single rewarded ad can start one run without cans; cancelled ads do not consume it.
var ad_run_used:=false
var last_reward:=0
var last_silver_reward:=0
var survival_bonus:=0
var revive_used:=false   # true once every revive of this run is spent (the HUD reads this)
## Ad revives per run: the first gives back more health and longer invincibility.
const REVIVES:=[{"hp":0.5,"invuln":10.0},{"hp":0.3,"invuln":8.0}]
# In the buy-once build a revive is always available: the ad is the only gate.
const PREMIUM_REVIVE_HP := 0.35
const PREMIUM_REVIVE_INVULN := 7.0
var revive_count:=0
var revive_pending:=false
var revive_invulnerable:=0.0
var jockey_introduced:=false
var banshee_introduced:=false
var banshee_warning:=0.0
var meta_upgrades:=ShopCatalog.default_levels()
var shop_index:=0
var zombies: Array=[]
var bullets: Array=[]
var ordnance: Array=[]
var gates: Array=[]
var barrels: Array=[]
var crates: Array=[]
var blood_pools: Array=[]
var foot_timer:=0.0
var watchers: Array=[]   # roadside zombies (scenery that can be shot), owned by the road blocks
var kill_counts:={}      # kind -> kills this run
var kill_coins:={}       # kind -> coins earned from those kills
var crate_timer:=3.0
var roller_timer:=11.0   # rolling reward barrels: a new wave every few seconds
var obstacles: Array=[]
## Zombies playing their death fall: they still have to ride the scrolling road, or the
## corpse looks like it slides backwards over the tarmac for a second.
var dying_zombies: Array=[]
## Venom globs in flight (spitter). Each one is a small mesh lobbed at where the survivor
## stood when it was spat, so sidestepping dodges it.
var venoms: Array=[]
## Active vomit streams (spitter). Each one sprays for about a second and then splashes.
var venom_streams: Array=[]
var pickups: Array=[]
var effects: Array=[]
# Pooled effects (see _fx_spark_at etc.): a kill re-arms these instead of building
# 30-40 nodes, meshes and materials in a single frame.
const FX_SPARK_SIZES:=[0.045,0.062,0.08]
const FX_DROP_SIZES:=[0.05,0.075,0.10]
const FX_LABELS:=16
var fx_sparks: Array=[[],[],[]]
var fx_drops: Array=[[],[],[]]
var fx_labels: Array=[]
var blood_free: Array=[]
var roads: Array=[]
var scenery: Array=[]
var rng:=RandomNumberGenerator.new()
var run_time:=0.0
var distance:=0.0
var kills:=0
var wave:=0
## 尸潮: zombies arrive in waves instead of a trickle. Each wave is a fixed quota that
## bursts in as one pack; the wave is over the moment the road is clear again, and a calm
## window follows before the next one. Clearing fast is what buys the breather.
var surge:=false
var phase_timer:=0.0        # calm countdown until the next wave
var wave_quota:=0           # zombies still to spawn in this wave
var wave_timeout:=0.0       # a stuck straggler can never hold the run hostage
var wave_clear_banner:=0.0  # "WAVE CLEAR" banner timer
var best_distance:=0
## The opening chase plays once; after that (saved locally) runs start straight away.
var intro_seen:=false
## New personal best on the death screen: the best before this run, whether it was beaten, and a
## clock for the celebration animation.
var run_start_best:=0
var new_record:=false
var gameover_time:=0.0
## In-run record moment: banner timer once the old best is passed.
var record_banner:=0.0
const RECORD_HINT_METRES:=150.0  # start showing "x m to your best" this close
var spawn_timer:=0.0
var gate_timer:=7.0
var barrel_timer:=5.0
var obstacle_timer:=5.5
var pickup_timer:=3.0
var shot_timer:=0.0
var growl_timer:=4.0
var damage_flash:=0.0
var shake:=0.0
var wave_banner:=0.0
var hint_time:=7.0
var new_gate_index:=0
var elapsed:=0.0
var auto_reload:=true
var touch_controls:=false
## A tap that moves the player from one screen to the next (pause -> lobby) must not
## also press whatever button happens to sit under the same finger on the new screen.
var lobby_swallow_tap:=0.0
var mouse_position:=Vector2(270,390)
var aim_direction:=Vector3.FORWARD
var aim_target: Node3D
var aim_point:=Vector3.ZERO
var left_touch_id:=-1
var right_touch_id:=-1
var left_stick:=Vector2.ZERO
var right_stick:=Vector2.ZERO
# Touch layout (mobile only; hidden on desktop): sticks bottom corners, action buttons stacked on the right.
const STICK_LEFT:=Vector2(110,842)
const STICK_RIGHT:=Vector2(430,842)
const BTN_RELOAD:=Vector2(492,596)
const BTN_FRAG:=Vector2(492,676)
const BTN_FLASH:=Vector2(420,676)
const BTN_FIRE_MODE:=Vector2(420,596)
const BTN_SWAP:=Vector2(492,516)
const BTN_RADIUS:=36.0
const PAUSE_BUTTON:=Rect2(476,8,58,58)
## Settings -> Control layout. The two rows sit above the play field, away from
## every control the player is dragging underneath.
const CTRL_RESET:=Rect2(66,152,196,58)
const SETTINGS_QUALITY:=Rect2(66,700,408,70)
const CTRL_SAVE:=Rect2(278,152,196,58)
const CTRL_KEYS:=["stick_left","stick_right","btn_reload","btn_swap","btn_frag","btn_flash","btn_fire","pause"]
## Saved position of every movable control, in real viewport coordinates.
var touch_layout:={}
## Key of the control under the finger in the layout editor ("" = not dragging).
var ctrl_drag:=""
## The classic start screen (state "cover"): the title poster greets every launch, and any
## tap starts the run right away. Characters, shop and the rest live in the lobby side bar.
var ui_h:=960.0
var ui_w:=540.0
var left_origin:=STICK_LEFT
var right_origin:=STICK_RIGHT
var left_knob:=Vector2(92,820)
var right_knob:=Vector2(448,820)

## This is the one-time-purchase build: no store, no ads, no stamina, everything unlocked.
const PREMIUM_BUILD := true


func premium_build() -> bool:
	return PREMIUM_BUILD


## Hand the player the whole game the moment the save is loaded.
func _apply_premium_unlocks() -> void:
	# Coins and silver are earned from zero like any other player; no god-mode wallet here.
	# Only the cans are gone, so runs never cost energy.
	all_access = false
	if stamina != null:
		stamina.infinite = true


func _ready() -> void:
	BootTrace.mark("main: _ready start")
	# 60 fps is what the game is drawn for; uncapped, a 120 Hz phone renders twice
	# the frames for the same picture, which is pure heat and battery.
	Engine.max_fps=60
	rng.randomize()
	stamina=StaminaScript.new(); add_child(stamina); _load_save(); stamina.changed.connect(_save)
	_setup_world()  # the street is built by the run's loading screen, one district per frame
	view_cull_end=VIEW_CULL_END_HIGH if quality_high else VIEW_CULL_END_FAST
	_apply_quality()
	# Every screen is drawn for a 9:16 portrait rectangle. A tall phone (the iPhone 15
	# Plus is 19.5:9) used to EXPAND the canvas, so the lobby grew a dead black band
	# under it and the camera staged a frame the design never had. Keep the original
	# rectangle and letterbox it on every device instead.
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	ui_h=get_viewport().get_visible_rect().size.y
	ui_w=get_viewport().get_visible_rect().size.x
	_pin_sticks()
	touch_controls=OS.has_feature("mobile")
	sound=SoundScript.new(); sound.muted=_read_muted(); _read_volumes(); add_child(sound)
	# Every test/capture run is fully muted — the owner's machine stays silent.
	var _targs:=OS.get_cmdline_user_args()
	for _f in ["--smoke-test","--soak-test","--lootbox-test","--stamina-test","--capture","--capture-medic","--capture-bike"]:
		if _f in _targs: sound.muted=true; break
	if PREMIUM_BUILD:
		_apply_premium_unlocks()
	iap=IapScript.new(); iap.ledger=iap_ledger; iap.grant=_iap_grant; add_child(iap)
	iap.purchase_finished.connect(_on_purchase_finished)
	revival_ads=RevivalAdsScript.new(); add_child(revival_ads)
	revival_ads.revive_rewarded.connect(_revive_after_reward)
	revival_ads.revive_cancelled.connect(_revive_ad_cancelled)
	revival_ads.ad_rewarded.connect(_on_ad_rewarded)
	revival_ads.ad_cancelled.connect(_on_ad_cancelled)
	player=PlayerScript.new(); player.character=character_choice; add_child(player); player.reset()
	shop_truck=ShopSceneScript.new()
	add_child(shop_truck); shop_truck.visible=false; shop_items=ShopCatalog.items()
	lootbox_scene=LootboxSceneScript.new(); add_child(lootbox_scene); lootbox_scene.visible=false
	map_scene=MapTableScript.new(); add_child(map_scene); map_scene.visible=false
	lobby=LobbySceneScript.new(); add_child(lobby); lobby.visible=false
	_setup_weather_overlay()
	var layer:=CanvasLayer.new(); add_child(layer)
	hud=HudScript.new(); hud.game=self; hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_zombies(); _set_menu_scene(); _update_mouse_aim()
	# Legal gate: on a real player's first launch the Terms of Use must be accepted before
	# anything else is reachable. Test/capture runs skip it so the scripts keep working.
	if not terms_accepted:
		var skip_terms:=false
		for f in ["--smoke-test","--soak-test","--lootbox-test","--stamina-test","--capture","--capture-medic","--capture-bike"]:
			if f in OS.get_cmdline_user_args(): skip_terms=true; break
		if not skip_terms: state="terms"
	if "--capture" in OS.get_cmdline_user_args(): call_deferred("_capture")
	elif "--capture-medic" in OS.get_cmdline_user_args(): call_deferred("_capture_medic")
	elif "--capture-bike" in OS.get_cmdline_user_args(): call_deferred("_capture_bike")
	elif "--capture-car" in OS.get_cmdline_user_args(): call_deferred("_capture_car")
	elif "--lootbox-test" in OS.get_cmdline_user_args(): call_deferred("_lootbox_test")
	elif "--smoke-test" in OS.get_cmdline_user_args(): call_deferred("_smoke_test")
	elif "--soak-test" in OS.get_cmdline_user_args(): call_deferred("_soak_test")

## Default position of every movable control, in real viewport coordinates. The action
## buttons used to be shifted by hud._btn() for a taller phone; the layout stores the
## final point instead, so the HUD, the hit tests and the grab test share one value.
## Sticks sit a little higher than they used to: the old corners were a stretch.
func default_touch_layout() -> Dictionary:
	var dy:=ui_h-960.0
	return {
		"stick_left": Vector2(110,ui_h-146),
		"stick_right": Vector2(430,ui_h-146),
		"btn_reload": BTN_RELOAD+Vector2(0,dy),
		"btn_swap": BTN_SWAP+Vector2(0,dy),
		"btn_frag": BTN_FRAG+Vector2(0,dy),
		"btn_flash": BTN_FLASH+Vector2(0,dy),
		"btn_fire": BTN_FIRE_MODE+Vector2(0,dy),
		"pause": PAUSE_BUTTON.get_center(),
	}

## Merge the saved layout with the defaults for this screen, keeping every control
## reachable. Sticks are pinned to their stored place instead of a hardcoded corner.
func _pin_sticks() -> void:
	var defaults:=default_touch_layout()
	for key in defaults.keys():
		var p: Vector2=defaults[key]
		var saved: Variant=touch_layout.get(key)
		if saved is Vector2: p=saved
		touch_layout[key]=_clamped_control(key,p)
	left_origin=touch_layout["stick_left"]; right_origin=touch_layout["stick_right"]
	left_knob=left_origin; right_knob=right_origin

## Keep a control fully on screen: a stick carries a 46 px knob swing, a button a 34 px
## face, so clamping at the edge would cut the control in half.
func _clamped_control(key: String,p: Vector2) -> Vector2:
	var half:=50.0 if key.begins_with("stick_") else (30.0 if key=="pause" else 38.0)
	return Vector2(clampf(p.x,half,ui_w-half),clampf(p.y,half,ui_h-half))

func control_pos(key: String) -> Vector2:
	if touch_layout.has(key): return touch_layout[key]
	return default_touch_layout().get(key,Vector2(ui_w*0.5,ui_h*0.5))

## Nearest control whose grab area contains the finger ("" when none does).
func control_at(pos: Vector2) -> String:
	var best:=""; var best_d:=1e9
	for key in CTRL_KEYS:
		var d:=pos.distance_to(control_pos(key))
		var grab:=74.0 if key.begins_with("stick_") else 46.0
		if d<=grab and d<best_d: best=key; best_d=d
	return best

func move_control(key: String,pos: Vector2) -> void:
	if key=="": return
	touch_layout[key]=_clamped_control(key,pos)
	if key=="stick_left": left_origin=touch_layout[key]; left_knob=left_origin
	elif key=="stick_right": right_origin=touch_layout[key]; right_knob=right_origin

func localize(key: String) -> String:
	return Localization.text(language_code,key)

func _setup_world() -> void:
	var we:=WorldEnvironment.new(); var env:=Environment.new()
	var sky:=Sky.new(); var sky_mat:=ShaderMaterial.new(); sky_mat.shader=SKY_SHADER
	sky_mat.set_shader_parameter("cloud_tex_01",load("res://assets/sky/clouds/clouds_01.png"))
	sky_mat.set_shader_parameter("cloud_tex_02",load("res://assets/sky/clouds/clouds_04.png"))
	sky_mat.set_shader_parameter("night_noise_01",load("res://assets/sky/clouds/clouds_07.png"))
	sky_mat.set_shader_parameter("night_noise_02",load("res://assets/sky/clouds/clouds_03.png"))
	sky_mat.set_shader_parameter("cloud_tiling",Vector2(1.4,1.4))
	sky_mat.set_shader_parameter("sun_scale",0.018)
	sky_mat.set_shader_parameter("sun_strength",4.0); sky_mat.set_shader_parameter("sun_color",Color("fff8ec"))
	# The visible solar disc and the shadow-casting sun use the same direction.
	sky_mat.set_shader_parameter("use_directional_light",true)
	sky_mat.set_shader_parameter("cloud_shape_exponent",1.35)
	sky_mat.set_shader_parameter("horizon_exponent",4.0)
	sky_material=sky_mat; sky.sky_material=sky_mat; env.background_mode=Environment.BG_SKY; env.sky=sky; env.sky_rotation=Vector3(0,deg_to_rad(25),0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("bdc7ca"); env.ambient_light_energy=0.46
	env.reflected_light_source=1
	env.tonemap_mode=Environment.TONE_MAPPER_ACES; env.tonemap_exposure=0.82
	env.fog_enabled=true; env.fog_light_color=Color("c9c8b8"); env.fog_density=0.0012; env.fog_sky_affect=0.015
	we.environment=env; add_child(we); world_env=env
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-34,-155,0)
	sun.light_color=Color("ffe4b5"); sun.light_energy=0.95; sun.shadow_enabled=true; sun.directional_shadow_max_distance=180
	# Authored look; _apply_quality swaps to two splits over 90 m when the player picks FAST.
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.directional_shadow_blend_splits=true
	sun.shadow_opacity=0.76; sun.shadow_blur=1.45; sun.shadow_bias=0.035; sun.shadow_normal_bias=0.65
	add_child(sun); sun_light=sun
	var rim:=DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-38,145,0); rim.light_color=Color("d0dbe2"); rim.light_energy=0.14
	rim.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY # the sky shader's sun follows the main sun only
	add_child(rim); fill_light=rim
	camera=Camera3D.new(); camera.position=Vector3(0,6.4,13.5); camera.fov=52; camera.near=0.1; camera.far=390; add_child(camera)
	camera.current=true; camera.look_at(Vector3(0,1.0,-8))
	var ground:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(700,700); ground.mesh=plane
	var m:=StandardMaterial3D.new(); m.albedo_color=Color("555c5a"); m.roughness=0.98; ground.material_override=m
	ground.position.y=-0.27; add_child(ground)

func _mesh_node(mesh: Mesh,color: Color,pos: Vector3) -> MeshInstance3D:
	var n:=MeshInstance3D.new(); n.mesh=mesh; n.position=pos
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=0.9; n.material_override=m
	add_child(n); return n

func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	var normal: Vector3=(b-a).cross(c-a).normalized()
	for point in [a,b,c]: st.set_normal(normal); st.add_vertex(point)

func _grass_clump() -> Node3D:
	var root:=Node3D.new(); var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(7):
		var base:=Vector3(rng.randf_range(-0.22,0.22),0,rng.randf_range(-0.22,0.22)); var h:=rng.randf_range(0.18,0.38); var w:=rng.randf_range(0.018,0.035)
		var angle:=rng.randf_range(0,TAU); var right:=Vector3(cos(angle),0,sin(angle))*w; var tip:=base+Vector3(rng.randf_range(-0.10,0.10),h,rng.randf_range(-0.10,0.10))
		_triangle(st,base-right,base+right,tip); _triangle(st,base+Vector3(-right.z,0,right.x),base-Vector3(-right.z,0,right.x),tip)
	var blades:=MeshInstance3D.new(); blades.mesh=st.commit()
	var m:=StandardMaterial3D.new(); m.albedo_color=Color("687348"); m.roughness=1.0; m.cull_mode=BaseMaterial3D.CULL_DISABLED; blades.material_override=m; root.add_child(blades)
	return root

func _rock() -> Node3D:
	var root:=Node3D.new(); var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top:=Vector3(0.03,rng.randf_range(0.13,0.19),-0.02); var bottom:=Vector3(0,-0.025,0)
	var ring: Array[Vector3]=[Vector3(0.20,0.035,0),Vector3(0.02,0.02,0.14),Vector3(-0.16,0.04,0.01),Vector3(-0.01,0.025,-0.12)]
	for i in range(4):
		_triangle(st,top,ring[i],ring[(i+1)%4]); _triangle(st,bottom,ring[(i+1)%4],ring[i])
	var rock:=MeshInstance3D.new(); rock.mesh=st.commit(); rock.rotation.y=rng.randf_range(0,TAU); rock.position.y=0.04
	var m:=StandardMaterial3D.new(); m.albedo_color=Color("777b72"); m.roughness=1.0; rock.material_override=m; root.add_child(rock)
	return root

## Zebra crossings stay rare and random: a recycled block shows its crossing only about
## one pass in six, so crossings appear roughly every 350–700 m instead of at every corner.
func _randomize_zebra(road: Node3D) -> void:
	var z:=road.find_child("CITY_zebra_paint",true,false) as Node3D
	if z: z.visible=rng.randf()<0.16

## Quality preset, saved with the rest of the settings. HIGH is the authored look: 2x MSAA,
## four shadow splits over 180 m and the city drawn to 250 m. FAST trades those for frame
## rate. Textures, models, materials and effects are identical in both.
func _apply_quality() -> void:
	view_cull_end=VIEW_CULL_END_HIGH if quality_high else VIEW_CULL_END_FAST
	var vp:=get_viewport()
	if vp: vp.msaa_3d=Viewport.MSAA_2X if quality_high else Viewport.MSAA_DISABLED
	if is_instance_valid(sun_light):
		sun_light.directional_shadow_max_distance=180.0 if quality_high else 90.0
		sun_light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality_high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun_light.shadow_blur=1.45 if quality_high else 1.1
	for road in roads:
		if is_instance_valid(road): _apply_cull_range(road)

## Fade every mesh of a block out at view_cull_end so only the near city is drawn.
func _apply_cull_range(root: Node) -> void:
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi:=node as MeshInstance3D
		if mi==null: continue
		mi.visibility_range_end=view_cull_end
		mi.visibility_range_end_margin=VIEW_CULL_FADE
		mi.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## District scenes are loaded once at startup: loading them inside _build_road was the single
## biggest frame spike of a run (24 models, about 4 MB each, decoded on the first frame).
var district_cache := {}
var _district_requests:={}   # path -> ResourceLoader threaded status


## One district per frame. Loading all 24 in _ready froze the first launch before the first
## frame could be drawn; the loading screen now stays up until this finishes.
const DISTRICTS_NEEDED := 7   # ~110 m of street; the rest stream in from the lobby
var district_prewarm_i := 0
var districts_ready := false


func _prewarm_step() -> void:
	if districts_ready:
		return
	if district_prewarm_i >= 24:
		districts_ready = true
		return
	if district_prewarm_i >= DISTRICTS_NEEDED:
		# only declare the world ready once every requested district is actually in memory
		if _district_requests.is_empty():
			districts_ready = true
		return
	var path: String = "res://assets/models/environment/city_hd_%02d.glb" % district_prewarm_i
	district_prewarm_i += 1
	if not ResourceLoader.exists(path):
		return
	if district_cache.has(path):
		return
	# On a worker thread: parsing a 10 MB district on the main thread is exactly the hitch that
	# showed up as soon as the bar finished.
	if not _district_requests.has(path):
		if ResourceLoader.load_threaded_request(path) == OK:
			_district_requests[path] = 0
		else:
			district_cache[path] = load(path)
		return
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: Resource = ResourceLoader.load_threaded_get(path)
		if packed != null:
			district_cache[path] = packed
		_district_requests.erase(path)


## Load the next districts on a worker thread while the player is running, so a new block never
## has to be parsed on the frame it appears (that is the hitching the phone shows).
func _district_threads() -> void:
	if player == null:
		return
	var want: int = clampi(roads.size() + 1, 0, 23)
	for k in range(3):
		var idx: int = (want + k) % 24
		var path: String = "res://assets/models/environment/city_hd_%02d.glb" % idx
		if district_cache.has(path) or _district_requests.has(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_district_requests[path] = 0
	# poll whatever is in flight
	for path in _district_requests.keys():
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed: Resource = ResourceLoader.load_threaded_get(path)
			if packed != null:
				district_cache[path] = packed
			_district_requests.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_district_requests.erase(path)


func _district_scene(path: String) -> Resource:
	if district_cache.has(path):
		return district_cache[path]
	var packed: Resource = load(path) if ResourceLoader.exists(path) else null
	if packed != null:
		district_cache[path] = packed
	return packed


## Whole-district culling. Per-mesh visibility ranges only save the renderer work; switching a
## district node off skips its ~45 meshes outright.
const DISTRICT_CULL := 152.0  # just past the fog cutoff so no gap appears


func _cull_districts() -> void:
	for r in roads:
		if not is_instance_valid(r):
			continue
		r.visible = absf(r.position.z) < DISTRICT_CULL


## One district. Pulled out of _build_road so the run's loading screen can build them one per
## frame instead of stalling a single frame with all 24 (~255 ms, several seconds on a phone).
func _build_district(i: int) -> void:
	var asset: String="city_hd_%02d"%(i%24)
	var path: String="res://assets/models/environment/"+asset+".glb"
	if not ResourceLoader.exists(path): path="res://assets/models/environment/city_hd_00.glb"
	var packed: Resource=_district_scene(path)
	if packed==null:
		push_warning("district failed to load: "+path+" -- falling back to city_hd_00")
		packed=load("res://assets/models/environment/city_hd_00.glb")
	if packed==null:
		push_error("no district model available at all, skipping this segment")
		return
	var road:=packed.instantiate() as Node3D
	if road==null:
		push_error("district instantiate failed: "+path)
		return
	road.position=Vector3(0,0,ROAD_BEHIND-i*ROAD_SEGMENT); add_child(road)
	EnvironmentMaterials.apply(road,i); DisasterDressing.apply(road,i,ZombieScript); roads.append(road)
	_place_phone_booth(road)
	_place_street_props(road, i)
	_apply_cull_range(road)
	_randomize_zebra(road)
	_setup_streetlamp(road,i)
	if road.has_meta("watcher"): watchers.append(road.get_meta("watcher"))


## Builds whatever is still missing. Called once at startup; a run normally arrives here with the
## street already standing.
## Street furniture, placed the way a real pavement works: things that belong against a wall sit
## at the curb line, the rest is scattered sparsely. Each district gets its own mix so the blocks
## do not look identical, and the lamp style varies block by block.
const PROP_DIR := "res://assets/models/props/"
## Kerb height: the pavement surface above the asphalt.
const PAVEMENT_Y := 0.14


func _prop_node(name: String, parent: Node3D, world_pos: Vector3, yaw: float = 0.0) -> Node3D:
	var path := PROP_DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var node := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(node)
	# world coordinates, because the district node carries a scale and props must not inherit it.
	# Anything standing on the roadway sits on the asphalt (y=0), not on the 0.14 m pavement, or it
	# hovers and its shadow lands a step away from it.
	var pos := world_pos
	if absf(pos.x) < 4.45:
		pos.y = 0.01
	node.global_position = pos
	node.global_rotation = Vector3(0.0, yaw, 0.0)
	return node


## Some districts ship their own lamp post standing in the roadway (x around -1.4). Hide those.
func _hide_road_lamps(road: Node3D) -> void:
	for m in road.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if String(mi.name).to_lower().find("lamp") == -1:
			continue
		if absf(mi.global_position.x) < 4.6:
			mi.visible = false


## One phone booth per block, standing beside the block's own street shelter and aligned with it.
## If a district has no shelter there is no booth: nothing is dropped at random.
const SHELTER_HINTS := ["station", "shelter", "busstop", "bus_stop", "kiosk"]


func _shelter_of(road: Node3D) -> AABB:
	var found := AABB()
	var has := false
	for m in road.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name).to_lower()
		var hit := false
		for hint in SHELTER_HINTS:
			if nm.find(hint) != -1:
				hit = true
				break
		if not hit:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		# a real shelter sits wholly on one pavement; anything crossing the centre line is not one
		var on_left: bool = a.end.x < -4.6
		var on_right: bool = a.position.x > 4.6
		if not (on_left or on_right):
			continue
		if a.size.x > 4.0 or a.size.y > 4.5:
			continue
		found = a if not has else found.merge(a)
		has = true
	return found


func _place_phone_booth(road: Node3D) -> void:
	var shel := _shelter_of(road)
	if shel.size == Vector3.ZERO:
		# No shelter mesh in this block: stand it on the pavement line instead of skipping, so
		# every other block gets one. One per 16 m block can never overlap the next.
		return
	var side := -1.0 if shel.get_center().x < 0.0 else 1.0
	# Fixed outer line requested by the user: 10 m from the centre line, well past the kerb.
	# 8.85 m is the pavement line; 11 m sits inside the building shell, so props placed there
	# were invisible.
	var x: float = side * 8.85
	var z: float = shel.end.z + 1.5 if side < 0.0 else shel.position.z - 1.5
	# side-on, glass towards the road
	_prop_node("phone_booth", road, Vector3(x, PAVEMENT_Y, z), -side * PI * 0.5)


## The rest of the street furniture, all on the x = 11 line the user settled on. Sparse: most
## blocks get two or three pieces, and litter comes as a small cluster near existing ground junk.
func _place_street_props(road: Node3D, index: int) -> void:
	var rng_d := RandomNumberGenerator.new()
	rng_d.seed = 0xC0FFEE + index * 733
	var side: float = -1.0 if rng_d.randf() < 0.5 else 1.0
	var base_z: float = road.global_position.z
	# 8.85 m is the pavement line; 11 m sits inside the building shell, so props placed there
	# were invisible.
	var x: float = side * 8.85

	if rng_d.randf() < 0.20:
		_prop_node("bench", road, Vector3(x, PAVEMENT_Y, base_z + rng_d.randf_range(-6.0, 6.0)), -side * PI * 0.5)
	if rng_d.randf() < 0.18:
		_prop_node("trash_bin", road, Vector3(x, PAVEMENT_Y, base_z + rng_d.randf_range(-6.0, 6.0)), -side * PI * 0.5)
	# trash cans live out past the kerb line, at 12 m from the centre
	if rng_d.randf() < 0.16:
		_prop_node("trash_can", road, Vector3(side * 12.0, PAVEMENT_Y, base_z + rng_d.randf_range(-6.0, 6.0)), 0.0)
	if rng_d.randf() < 0.40:
		# 10.9 .. 11.3 on whichever pavement this block uses
		var mx: float = x + side * rng_d.randf_range(-0.1, 0.3)
		# ring the crater mouth instead of dropping covers on the tarmac
	if rng_d.randf() < 0.14:
		_prop_node("hydrant", road, Vector3(x, PAVEMENT_Y, base_z + rng_d.randf_range(-6.5, 6.5)), 0.0)

	# litter: 1-4 cans in one spot, preferably where the block already has ground junk
	if rng_d.randf() < 0.45:
		# only the z comes from the junk pile: the cans themselves must stay on 9..12
		var near := _junk_spot(road, side)
		var lz: float = near.z if near != Vector3.ZERO else base_z + rng_d.randf_range(-7.0, 7.0)
		var lx: float = side * rng_d.randf_range(9.0, 12.0)
		var count: int = rng_d.randi_range(1, 4)
		for i in range(count):
			var can_name: String = ["can_a", "can_b", "can_c", "can_d"][rng_d.randi_range(0, 3)]
			var off := Vector3(rng_d.randf_range(-0.6, 0.6), 0.0, rng_d.randf_range(-0.6, 0.6))
			_prop_node(can_name, road, Vector3(lx, PAVEMENT_Y, lz) + off, rng_d.randf_range(0.0, TAU))


## World position of existing ground junk on one side of the block, or ZERO if there is none.
func _junk_spot(road: Node3D, side: float) -> Vector3:
	for m in road.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var nm := String(mi.name).to_lower()
		if nm.find("garbage") == -1 and nm.find("trash") == -1 and nm.find("weed") == -1 and nm.find("rubble") == -1:
			continue
		var a: AABB = mi.global_transform * mi.get_aabb()
		if side > 0.0 and a.get_center().x < 4.2:
			continue
		if side < 0.0 and a.get_center().x > -4.2:
			continue
		return a.get_center()
	return Vector3.ZERO


func _decorate_district(road: Node3D, index: int) -> void:
	var decor_rng := RandomNumberGenerator.new()
	decor_rng.seed = 0x5EED + index * 977
	var base_z: float = road.global_position.z
	# --- lamps: three block styles, so the lighting differs from street to street -------------
	# Placed near the kerb, in world space, on the pavement (kerb 4.36, buildings ~7.8).
	var lamp_style: int = index % 3
	if lamp_style != 2:
		var lamp_name: String = "lamp_modern" if lamp_style == 0 else "lamp_round"
		for side in [-1.0, 1.0]:
			_prop_node(lamp_name, road, Vector3(side * 8.80, PAVEMENT_Y, base_z + 2.4), 0.0)
			_prop_node(lamp_name, road, Vector3(side * 8.80, PAVEMENT_Y, base_z - 5.4), 0.0)
	# --- things that stand against the buildings --------------------------------------------
	for side in [-1.0, 1.0]:
		var x_wall: float = side * 9.40
		if decor_rng.randf() < 0.34:
			_prop_node("trash_bin", road, Vector3(x_wall, PAVEMENT_Y, base_z + decor_rng.randf_range(-6.0, 6.0)), side * PI * 0.5)
		if decor_rng.randf() < 0.26:
			_prop_node("trash_can", road, Vector3(side * 12.0, PAVEMENT_Y, base_z + decor_rng.randf_range(-6.0, 6.0)), side * PI * 0.5)
		if decor_rng.randf() < 0.18:
			_prop_node("phone_booth", road, Vector3(x_wall, PAVEMENT_Y, base_z + decor_rng.randf_range(-5.0, 5.0)), side * PI * 0.5)
		if decor_rng.randf() < 0.30:
			_prop_node("bench", road, Vector3(side * 8.80, PAVEMENT_Y, base_z + decor_rng.randf_range(-5.5, 5.5)), side * PI * 0.5)
		if decor_rng.randf() < 0.22:
			_prop_node("hydrant", road, Vector3(side * 8.70, PAVEMENT_Y, base_z + decor_rng.randf_range(-6.5, 6.5)), 0.0)
		# --- litter: a couple of cans, not a carpet ---------------------------------------------
	var cans := decor_rng.randi_range(0, 3)
	for i in range(cans):
		var can_name: String = ["can_a", "can_b", "can_c", "can_d"][decor_rng.randi_range(0, 3)]
		var cx: float = decor_rng.randf_range(8.6, 9.7) * (1.0 if decor_rng.randf() < 0.5 else -1.0)
		_prop_node(can_name, road, Vector3(cx, PAVEMENT_Y, base_z + decor_rng.randf_range(-7.0, 7.0)), decor_rng.randf_range(0.0, TAU))


func _build_road() -> void:
	for i in range(roads.size(), ROAD_COUNT):
		_build_district(i)


func _setup_streetlamp(road: Node3D,variant: int) -> void:
	# These are the exact positions of the modelled lamps in build_city_districts.py.
	# Only districts that actually contain a lamp receive a light; no floating light rows.
	if variant%6==5 or variant%2!=0: return
	var side: float=-1.0 if variant%4==0 else 1.0
	var lamp:=SpotLight3D.new(); lamp.position=Vector3(side*4.20,5.24,4.8)
	lamp.rotation_degrees=Vector3(-90,0,0); lamp.light_color=Color("ffdca3"); lamp.spot_range=11.5
	lamp.spot_angle=53.0; lamp.spot_angle_attenuation=1.4; lamp.spot_attenuation=1.25
	lamp.light_energy=0.0; lamp.visible=false; road.add_child(lamp)
	var mat:=StandardMaterial3D.new()
	var diffuser:=road.find_child("CITY_lamp",true,false) as MeshInstance3D
	if diffuser and diffuser.mesh:
		var source: Material=diffuser.get_surface_override_material(0)
		if source==null: source=diffuser.mesh.surface_get_material(0)
		if source is StandardMaterial3D: mat=(source as StandardMaterial3D).duplicate() as StandardMaterial3D
		for surface in range(diffuser.mesh.get_surface_count()): diffuser.set_surface_override_material(surface,mat)
	mat.emission_enabled=true; mat.emission=Color("ffd78e"); mat.emission_energy_multiplier=0.0
	street_lamps.append({"light":lamp,"material":mat})

## While paused the frame should be a photograph: freeze every animation player and the
## zombies' fire particles, so nothing on screen keeps moving. Re-checked every frame, so
## it catches all the ways the run can enter or leave the paused state.
var _visuals_frozen:=false
func _freeze_visuals(frozen: bool) -> void:
	if frozen==_visuals_frozen: return
	_visuals_frozen=frozen
	var actors: Array=[player]+companion_pets+zombies
	for a in actors:
		if not is_instance_valid(a): continue
		var ap: AnimationPlayer=a.get("animation_player")
		if ap==null: ap=a.find_child("AnimationPlayer",true,false) as AnimationPlayer
		# Godot 4 AnimationPlayer has no `paused` property — freeze via speed_scale.
		if ap: ap.speed_scale=0.0 if frozen else 1.0
		var flames_node: CPUParticles3D=a.get("flames")
		if is_instance_valid(flames_node): flames_node.speed_scale=0.0 if frozen else 1.0
		var embers_node: CPUParticles3D=a.get("embers")
		if is_instance_valid(embers_node): embers_node.speed_scale=0.0 if frozen else 1.0

func _process(delta: float) -> void:
	elapsed+=delta
	lobby_swallow_tap=maxf(0.0,lobby_swallow_tap-delta)
	# Before the run starts, compile one of everything in the hidden warm-up viewport:
	# a menu stutter costs nothing, the same compile mid-run costs the player a freeze.
	if state!="playing":
		_warm_up_tick()
		_prewarm_step()
	var from_pause: bool=(state=="settings" or state=="controls") and settings_return_state=="paused"
	if (state=="paused" or from_pause)!=_visuals_frozen: _freeze_visuals(state=="paused" or from_pause)
	if state=="gameover": gameover_time+=delta
	sound.music_state(payfail_return_state if state=="payfail" else (map_return_state if state=="map" else ("shop" if state=="armory" else state)))  # popups keep the music underneath
	damage_flash=maxf(0,damage_flash-delta); shake=maxf(0,shake-delta*3.0)
	banshee_warning=maxf(0,banshee_warning-delta)
	world_speed=(3.5*(player.effective_move_mult() if state=="playing" else 1.0)) if state in ["playing","intro"] else (0.25 if state=="cover" else 0.0)
	for road in roads:
		road.position.z+=world_speed*delta
		if road.position.z>ROAD_BEHIND+ROAD_SEGMENT:
			road.position.z-=ROAD_LOOP
			_refresh_watcher(road)
			_randomize_zebra(road)
	_tick_lightning(delta)
	_apply_day_night()
	if state=="loading":
		_tick_loading(delta)
		return
	if state=="intro":
		_tick_intro(delta)
		return
	var scene_state:=state
	if scene_state=="payfail": scene_state=payfail_return_state
	if scene_state=="resource_pack": scene_state=resource_pack_return_state
	if scene_state=="offer": scene_state=offer_return_state
	# the armory is an overlay on the supply truck, so it uses the truck camera
	if scene_state=="armory": scene_state="shop"
	if scene_state in ["cover","language","terms"] or (scene_state=="settings" and settings_return_state!="paused"):
		camera.fov=52; _set_menu_scene(); return
	if scene_state=="shop":
		camera.fov=shop_truck.camera_fov(); camera.position=shop_truck.camera_position(); camera.look_at(shop_truck.camera_target()); return
	if scene_state=="lootbox":
		camera.fov=lootbox_scene.camera_fov(); camera.h_offset=0; camera.v_offset=0
		camera.position=lootbox_scene.camera_position(); camera.look_at(lootbox_scene.camera_target()); return
	if scene_state=="map":
		camera.fov=map_scene.camera_fov(); camera.h_offset=0; camera.v_offset=0
		camera.position=map_scene.camera_position(); camera.look_at(map_scene.camera_target(),Vector3(0,0,-1))
		map_toast=maxf(0.0,map_toast-delta); return
	lobby.visible=lobby_behind()
	RunText.lang=language_code
	lobby_toast=maxf(0.0,lobby_toast-delta); share_toast=maxf(0.0,share_toast-delta); store_toast=maxf(0.0,store_toast-delta)
	if state in ["playing","intro","paused"]: _track_play_time(delta)
	if state=="offer" and not offer_active(): close_offer()
	if lobby_behind():
		if lobby_preview_character>=0:
			lobby.show_character(lobby_preview_character,lobby_preview_asset)
		else:
			lobby.show_character(character_choice,character_asset(character_choice))
		camera.fov=lobby.CAMERA_FOV; camera.h_offset=0; camera.v_offset=0
		camera.position=lobby.camera_position(); camera.look_at(lobby.camera_target()); return
	if state in ["cover","loading","language","terms","controls"] or (state=="settings" and settings_return_state!="paused"):
		camera.fov=52; _set_menu_scene(); return
	if capture_close_cam: return
	if debug_camera_hold:
		return
	camera.position.x=lerpf(camera.position.x,player.position.x*0.12,delta*3.0)
	# While the beast is on the road the camera eases up and back so the pursuer rises
	# into the lower frame as it closes in — and settles again once it loses the trail.
	chase_cam_weight=move_toward(chase_cam_weight,1.0 if (chase_active and is_instance_valid(chaser)) else 0.0,delta*1.8)
	# Speed feel: the view stretches with the vehicle — a proper sprint on the bike, more in a car.
	camera.fov=52.0+5.0*chase_cam_weight+(2.0*player.vehicle_speed() if (is_instance_valid(player) and player.vehicle!="") else 0.0)
	camera.position.y=6.4+0.9*chase_cam_weight
	camera.position.z=13.5+1.8*chase_cam_weight
	camera.h_offset=rng.randf_range(-0.12,0.12)*shake; camera.v_offset=rng.randf_range(-0.1,0.1)*shake
	camera.look_at(Vector3(player.position.x*0.08,1.0+0.25*chase_cam_weight,lerpf(-8.0,player.position.z+1.5,chase_cam_weight)))
	if state!="playing": return
	run_time+=delta; distance+=delta*10.5*player.effective_move_mult(); _check_record(delta); hint_time=maxf(0,hint_time-delta); wave_banner=maxf(0,wave_banner-delta)
	revive_invulnerable=maxf(0.0,revive_invulnerable-delta)
	# Road events ramp up over the run: an almost empty street at the start, busier later,
	# and never two things on the same stretch of road (see _road_clear).
	var ramp: float=_pace()
	# Wave director: fight a wave, clear it, breathe, repeat. A wave ends when the road is
	# clear rather than on a timer, so a clean sweep is rewarded with a longer breather.
	wave_clear_banner=maxf(0.0,wave_clear_banner-delta)
	if surge:
		wave_timeout-=delta
		if wave_quota<=0 and _living_zombies()==0: _end_wave(ramp)
		elif wave_timeout<=0.0: _end_wave(ramp)
	else:
		phase_timer-=delta
		if phase_timer<=0.0: _begin_wave(ramp)
	growl_timer-=delta
	if growl_timer<=0:
		if not zombies.is_empty(): sound.play("zombie")
		growl_timer=rng.randf_range(5.5,10.0)
	var axis:=0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis-=1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis+=1
	if touch_controls: axis=clampf(axis+left_stick.x,-1,1)
	if axis!=0: player.target_x=clampf(player.target_x+axis*5.0*player.effective_move_mult()*delta,-3.15,3.15)
	if right_stick.length()>0.16:
		aim_direction=Vector3(right_stick.x,0,right_stick.y).normalized()
	elif not touch_controls:
		_update_mouse_aim()
	if touch_controls: _update_touch_aim()
	_cull_districts()
	player.set_aim(aim_direction); player.tick(delta); shot_timer-=delta
	# Firing is automatic on every platform; aiming and reloading remain player choices.
	# Out of ammo for the current gun: fall back to the pistol, which never runs dry.
	if not player.infinite_ammo() and player.ammo<=0 and player.reserve_ammo<=0 and not player.reloading:
		swap_weapon(true)
	if shot_timer<=0:
		if player.can_fire():
			_fire(); shot_timer=player.fire_interval
		elif player.ammo<=0 and auto_reload:
			request_reload()
	if surge and wave_quota>0:
		spawn_timer-=delta
		if spawn_timer<=0:
			if _living_zombies()>=MAX_ALIVE_ZOMBIES:
				spawn_timer=0.2   # hold the pack back until the road thins out
			else:
				_spawn_zombie(); wave_quota-=1
				# One pack: ~0.4 s apart early, ~0.2 s deep in the run.
				spawn_timer=lerpf(0.42,0.22,ramp)*rng.randf_range(0.85,1.15)
	gate_timer-=delta
	if gate_timer<=0:
		if _road_clear(-40.0): _spawn_gate(); gate_timer=lerpf(11.0,7.5,ramp)*rng.randf_range(0.9,1.15)
		else: gate_timer=1.2
	_district_threads()
	barrel_timer-=delta
	if barrel_timer<=0:
		if _road_clear(-45.0): _spawn_barrel(); barrel_timer=lerpf(26.0,14.0,ramp)*rng.randf_range(0.85,1.2)
		else: barrel_timer=1.5
	crate_timer-=delta
	if crate_timer<=0:
		if _road_clear(-46.0): _spawn_crates(); crate_timer=lerpf(30.0,17.0,ramp)*rng.randf_range(0.85,1.2)
		else: crate_timer=1.5
	roller_timer-=delta
	if roller_timer<=0:
		if _road_clear(-48.0): _spawn_rollers(); roller_timer=lerpf(26.0,16.0,ramp)*rng.randf_range(0.85,1.2)
		else: roller_timer=1.5
	obstacle_timer-=delta
	if obstacle_timer<=0:
		if _road_clear(-48.0): _spawn_obstacle_pattern(); obstacle_timer=lerpf(20.0,11.0,ramp)*rng.randf_range(0.85,1.2)
		else: obstacle_timer=1.5
	pickup_timer-=delta
	if pickup_timer<=0:
		var roll:=rng.randf()
		var pickup_kind := "ammo"
		# helmet and armour now stand on platforms (see _spawn_crates), not on the ground
		if roll<0.09: pickup_kind="grenade"
		elif roll<0.16: pickup_kind="flashbang"
		elif roll<0.30: pickup_kind="fire_round"
		elif roll<0.58: pickup_kind="medkit"
		_spawn_pickup(pickup_kind); pickup_timer=lerpf(15.0,9.0,_pace())*rng.randf_range(0.85,1.2)
	_cleanup_companions()
	for dog in companion_pets:
		if is_instance_valid(dog): dog.tick(delta)
	_scroll_extra(delta)
	var _t0 := Time.get_ticks_usec(); _tick_bullets(delta); _profile_tick("_tick_bullets(delta)", _t0)
	var _t1 := Time.get_ticks_usec(); _tick_ordnance(delta); _profile_tick("_tick_ordnance(delta)", _t1)
	var _t2 := Time.get_ticks_usec(); _tick_barrels(delta); _profile_tick("_tick_barrels(delta)", _t2)
	var _t3 := Time.get_ticks_usec(); _tick_crates(delta); _profile_tick("_tick_crates(delta)", _t3)
	var _t4 := Time.get_ticks_usec(); _tick_dying_zombies(delta); _profile_tick("_tick_dying_zombies(delta)", _t4)
	var _t5 := Time.get_ticks_usec(); _vehicle_smash(); _profile_tick("_vehicle_smash()", _t5)
	var _t6 := Time.get_ticks_usec(); _tick_venom(delta); _profile_tick("_tick_venom(delta)", _t6)
	var _t7 := Time.get_ticks_usec(); _tick_blood(delta); _profile_tick("_tick_blood(delta)", _t7)
	var _t8 := Time.get_ticks_usec(); _tick_rain(delta); _profile_tick("_tick_rain(delta)", _t8)
	var _t9 := Time.get_ticks_usec(); _tick_watchers(delta); _profile_tick("_tick_watchers(delta)", _t9)
	var _t10 := Time.get_ticks_usec(); _tick_zombies(delta); _profile_tick("_tick_zombies(delta)", _t10)
	var _t11 := Time.get_ticks_usec(); _resolve_barrel_collision(); _profile_tick("_resolve_barrel_collision()", _t11)
	var _t12 := Time.get_ticks_usec(); _resolve_crater_collision(); _profile_tick("_resolve_crater_collision()", _t12)
	var _t13 := Time.get_ticks_usec(); _tick_obstacles(delta); _profile_tick("_tick_obstacles(delta)", _t13)
	var _t14 := Time.get_ticks_usec(); _tick_gates(delta); _profile_tick("_tick_gates(delta)", _t14)
	var _t15 := Time.get_ticks_usec(); _tick_pickups(delta); _profile_tick("_tick_pickups(delta)", _t15)
	var _t16 := Time.get_ticks_usec(); _tick_effects(delta); _profile_tick("_tick_effects(delta)", _t16)
	var _t17 := Time.get_ticks_usec(); _tick_vehicle(delta); _profile_tick("_tick_vehicle(delta)", _t17)
	_tick_buffs(delta)
	_tick_chase(delta)
	if player.health<=0: _end_run()

## Temporary hitch hunter (debug builds only): prints any tick slice that blows past 120 ms.
func _profile_tick(name: String, t0: int) -> void:
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if ms > 120.0:
		print("HITCH ", name, " ", snappedf(ms, 0.1), " ms")


func _menu_zombies() -> void:
	for i in range(3):
		var z:=ZombieScript.new(); add_child(z); z.configure("walker" if i!=1 else "brute",1.0)
		z.position=Vector3(-2.2+i*2.2,0,-16-i*6); zombies.append(z)

func _set_menu_scene() -> void:
	player.position=Vector3(1.05,0,3.0); player.target_x=1.05; player.model.rotation.y=0
	camera.position=Vector3(3.0,2.65,8.4); camera.h_offset=0; camera.v_offset=0; camera.look_at(Vector3(-0.35,1.05,3.0))

func _is_automated_test() -> bool:
	var args:=OS.get_cmdline_args()
	for a in args:
		if "test_" in a or "--smoke-test" in a or "--soak-test" in a or "--capture" in a: return true
	return false

func _begin_loading(target: String) -> void:
	loading_target=target
	loading_time=0.0; loading_progress=0.0; loading_switch=0.0
	# ONE image per load: pick a single random art, keep it until progress reaches 100%
	loading_order=[0,1,2,3]; loading_order.shuffle(); loading_idx=0
	if _is_automated_test(): loading_duration=0.01
	else: loading_duration=2.8
	state="loading"
	_release_touches()
	# Hide the menu-scene runner so it can't flash on the road when loading ends
	if is_instance_valid(player): player.visible=false

## ---- First-draw warm-up ---------------------------------------------------------
## GLES3 compiles a shader the first time it is drawn, and the blood decals build
## their textures in GDScript. Both used to land on the player as 0.2-2 s freezes when
## a new thing appeared. One of everything is drawn in a hidden 48x48 viewport while the
## player is still on the cover / lobby: same pipelines, no visible frame, no freeze.
var warmup_done:=false
var warmup_view: SubViewport
var warmup_root: Node3D
var warmup_queue: Array=[]
var warmup_nodes: Array=[]

func _warm_up_begin() -> void:
	warmup_view=SubViewport.new(); warmup_view.size=Vector2i(48,48)
	warmup_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(warmup_view)
	warmup_root=Node3D.new(); warmup_view.add_child(warmup_root)
	var cam:=Camera3D.new(); cam.position=Vector3(0,0.6,3.0); cam.current=true; warmup_root.add_child(cam)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-40,-30,0); sun.shadow_enabled=true
	warmup_root.add_child(sun)
	# procedural decal textures: pure CPU work and the slowest single item
	for k in range(BloodPoolScript.VARIANTS): BloodPoolScript._texture(k)
	for k in range(BloodPoolScript.SPLASH_VARIANTS): BloodPoolScript._splash(k)
	for k in ["walker","runner","brute","jockey","banshee","bomber","bomber_female"]:
		warmup_queue.append("zombie:"+k)
	for k in ["medkit","armor","helmet","ammo","grenade","flashbang","launcher","fire_round","coin","silver_coin"]:
		warmup_queue.append("pickup:"+k)
	# survivor rigs and the held weapons: their skin pipelines used to compile on the first
	# frame of the run, which is the stutter right after the loading bar disappears
	for c in (load("res://scripts/lobby_scene_3d.gd") as GDScript).CHARACTERS:
		warmup_queue.append("actor:"+String(c.asset))
	for w in ["pistol","makarov","suomi","smg","shotgun","sniper","rifle","launcher","flame"]:
		warmup_queue.append("weapon:"+w)
	warmup_queue.append("crate")
	warmup_queue.append("barrel")
	warmup_queue.append("effects")

## Builds one queue item; the viewport keeps drawing it for a frame, which is what
## compiles the pipeline. Freed as soon as the queue is empty.
func _warm_up_tick() -> void:
	if warmup_done: return   # once is enough: the pipelines stay compiled
	if warmup_view==null: _warm_up_begin()
	if warmup_queue.is_empty():
		warmup_done=true
		if is_instance_valid(warmup_view): warmup_view.queue_free()
		warmup_view=null; warmup_root=null; warmup_nodes.clear()
		return
	var item: String=String(warmup_queue.pop_front())
	if item=="effects":
		# one node per effect shape: unshaded spark/drop, alpha blast/shockwave, label text
		for k in range(5):
			var fx=EffectScript.new(); warmup_root.add_child(fx); fx.life=0.0; fx.total_life=1.0
			match k:
				0: fx.make_spark(Color.WHITE,0.05)
				1: fx.make_drop(Color.WHITE,0.05)
				2: fx.make_blast(Color("8e1d12"),0.6)
				3: fx.make_shockwave(Color("ffd27a"),0.4)
				_: fx.make_text("0",Color.WHITE)
			fx.position=Vector3(-1.2+0.6*float(k),0.6,0.0)
		return
	var n: Node3D=null
	if item.begins_with("zombie:"):
		n=ZombieScript.new(); warmup_root.add_child(n); n.configure(item.trim_prefix("zombie:"),1.0)
	elif item.begins_with("pickup:"):
		n=PickupScript.new(); n.kind=item.trim_prefix("pickup:"); warmup_root.add_child(n)
	elif item.begins_with("actor:"):
		var path: String = item.trim_prefix("actor:")
		if ResourceLoader.exists(path):
			n = (load(path) as PackedScene).instantiate() as Node3D
			if n != null: warmup_root.add_child(n)
	elif item.begins_with("weapon:"):
		var wid: String = item.trim_prefix("weapon:").to_upper()
		var wpath := "res://assets/models/weapons/%s.glb" % wid.to_lower()
		if wid == "RIFLE": wpath = "res://assets/models/rifle.glb"
		if ResourceLoader.exists(wpath):
			n = (load(wpath) as PackedScene).instantiate() as Node3D
			if n != null: warmup_root.add_child(n)
	elif item == "crate":
		n = WeaponCrateScript.new(); warmup_root.add_child(n); n.setup("SMG", 3)
	elif item == "barrel":
		n = BarrelScript.new(); warmup_root.add_child(n)
	if n!=null:
		n.position=Vector3(0.0,0.0,0.0)
		warmup_nodes.append(n)

func _teardown_warmup() -> void:
	## The warm-up viewport holds throwaway zombies, pickups and crates. If the queue had not
	## drained by the time loading finished, they stayed alive at the origin and showed up as a
	## pile of zombies marching in place.
	warmup_queue.clear()
	for n in warmup_nodes:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
	warmup_nodes.clear()
	if is_instance_valid(warmup_view):
		warmup_view.queue_free()
	warmup_view = null
	warmup_root = null
	warmup_done = true


func _finish_loading() -> void:
	if state!="loading": return
	_teardown_warmup()
	var target:=loading_target
	if target=="run" and roads.size()<ROAD_COUNT:
		_build_road()
	loading_progress=1.0
	if target=="run":
		if is_instance_valid(player): player.visible=true
		start_run()
	else:
		enter_lobby()
		if is_instance_valid(player): player.visible=true
		# Cut straight to the lobby camera in the same frame — no menu-road flash
		if is_instance_valid(lobby):
			lobby.visible=true
			camera.fov=lobby.CAMERA_FOV; camera.h_offset=0; camera.v_offset=0
			camera.position=lobby.camera_position(); camera.look_at(lobby.camera_target())

func _tick_loading(delta: float) -> void:
	loading_time+=delta
	if loading_target=="run":
		_prewarm_step()
		if roads.size()<ROAD_COUNT:
			_build_district(roads.size())
		districts_ready = district_prewarm_i>=DISTRICTS_NEEDED and roads.size()>=ROAD_COUNT
	else:
		# the lobby needs no street: never make the player wait for one
		districts_ready = true
	if loading_target=="run":
		_warm_up_tick()
	var prewarm_part: float = float(mini(district_prewarm_i, DISTRICTS_NEEDED)) / float(DISTRICTS_NEEDED)
	var road_part: float = float(roads.size()) / float(ROAD_COUNT) if loading_target=="run" else 0.0
	loading_progress = minf(0.98, maxf(maxf(loading_time/maxf(loading_duration,0.01), prewarm_part if loading_target=="run" else 0.0), road_part))
	# same random image from start to finish, no switching
	if loading_time>=loading_duration and districts_ready and (loading_target!="run" or warmup_done or warmup_queue.is_empty()):
		_finish_loading()

func start_run(free_with_ad:=false,no_cost:=false) -> void:
	var automated:="--smoke-test" in OS.get_cmdline_user_args() or "--soak-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--capture-bike" in OS.get_cmdline_user_args()
	if not automated and not free_with_ad and not no_cost and not stamina.consume():
		store_toast_text=StoreCatalog.text(language_code,"no_cans"); store_toast=2.4
		# Never force the pack popup: the toast explains it, and the wallet's little "+"
		# icons stay on screen for anyone who actually WANTS to buy or watch an ad.
		if state=="cover": enter_lobby()
		return
	equip_menu_index=-1
	# A run can open at dawn, noon, dusk or the dead of night: pick a random
	# point in the day-night cycle, then the 20 km cycle carries on from there.
	day_start_offset=rng.randf()*DAY_NIGHT_CYCLE_METRES
	night_announced=false
	_clear_world(); state="playing"; run_time=0; distance=0; kills=0; wave=0; run_coins=0; run_silver=0; run_double_bonus=0; run_double_silver=0; ad_pending=""; last_reward=0; last_silver_reward=0; survival_bonus=0
	kill_counts.clear(); kill_coins.clear(); run_counted_distance=0.0; run_counted=false
	for road in roads: _refresh_watcher(road)
	revive_used=false; revive_count=0; revive_pending=false; revive_invulnerable=0.0; jockey_introduced=false; banshee_introduced=false; banshee_warning=0.0
	_chase_reset()
	spawn_timer=1.6; gate_timer=9.0; barrel_timer=32.0; crate_timer=20.0; obstacle_timer=24.0; pickup_timer=12.0; shot_timer=0; growl_timer=3.5; hint_time=7; damage_flash=0; new_gate_index=0; gates_since_epic=0
	surge=false; phase_timer=4.5; wave_quota=0; wave_timeout=0.0; wave_clear_banner=0.0  # a calm opening before the first 尸潮
	aim_direction=Vector3.FORWARD; aim_target=null; left_stick=Vector2.ZERO; right_stick=Vector2.ZERO; _release_touches()
	shop_truck.visible=false; player.visible=true; camera.fov=52; camera.position=Vector3(0,6.4,13.5)
	runs_this_launch+=1; runs_total+=1; run_start_best=best_distance; new_record=false; record_banner=0.0
	# Opening hour: daytime almost always, dusk or dawn only now and then.
	#   85% day · 10% dusk · 5% dawn (first run of a session is always day)
	var opening:="clear"
	# A brand new player (no best distance yet) always gets a daylight tutorial run.
	var rookie: bool = best_distance <= 0.0 and runs_this_launch <= 2
	if runs_this_launch>1 and not rookie:
		var hour_roll:=rng.randf()
		if hour_roll<0.10: opening="dusk"
		elif hour_roll<0.15: opening="dawn"
	if opening=="clear":
		set_weather("clear" if (runs_this_launch==1 or rookie) else _roll_weather())
	else:
		set_weather(opening)
	player.reset(); player.apply_meta(meta_upgrades); player.set_aim(aim_direction)
	if flame_owned() and weapon_equipped:
		player.set_weapon("FLAME")
	# Bought motorcycle: every run starts already mounted for the first VEHICLE_AUTO_RANGE metres
	# (it also breaks on durability as usual, whichever comes first).
	# The gold sports car opens with a 2000 m dash; every other vehicle keeps 1000 m.
	vehicle_range_end=2000.0 if owned_vehicle=="GOLD_CAR" else VEHICLE_AUTO_RANGE
	vehicle_auto_active=loadout_on and vehicle_equipped and owned_vehicle!=""
	if vehicle_auto_active:
		player.mount_vehicle(owned_vehicle)
	if automated:
		_spawn_zombie(-18); _spawn_zombie(-32); _spawn_companion()
		# These two open the run, and a walker's own speed is roughly the road speed, so it used to
		# hover in place instead of closing in. Give the opening pair a real approach speed.
		for opening_z in zombies:
			if is_instance_valid(opening_z) and opening_z.kind != "banshee":
				opening_z.speed = 3.5 + 2.2
	else:
		# Every run opens with the chase shot (the horde and the hunter behind the survivor),
		# like Temple Run; it has a dog only if the player has equipped one (pet tab).
		_begin_intro()

func _spawn_companion() -> void:
	_cleanup_companions()
	if not companion_pets.is_empty() or not loadout_on or not pet_equipped or not pet_owned(pet_choice): return
	_recruit_pet(pet_choice,player.position+(load("res://scripts/pet_companion_3d.gd") as GDScript).follow_offset(0))

## Drops freed dogs from the pack and keeps companion_pet pointing at the first dog.
func _cleanup_companions() -> void:
	for i in range(companion_pets.size()-1,-1,-1):
		if not is_instance_valid(companion_pets[i]): companion_pets.remove_at(i)
	companion_pet=companion_pets[0] as Node3D if not companion_pets.is_empty() else null

## Adds a dog to the pack (equipped one at the start, or one freed from a platform).
## Up to MAX_COMPANION_PETS can follow; breeds may repeat. Returns false when the pack is full.
func _recruit_pet(index: int,at: Vector3) -> bool:
	_cleanup_companions()
	if companion_pets.size()>=MAX_COMPANION_PETS: return false
	var slot:=companion_pets.size()
	var dog: Node3D=(load("res://scripts/pet_companion_3d.gd") as GDScript).new() as Node3D
	dog.game=self; add_child(dog); dog.setup(index,slot)
	dog.position=at
	companion_pets.append(dog)
	companion_pet=dog if companion_pet==null else companion_pet
	return true

func _begin_intro() -> void:
	_clear_world(); intro_horde_offsets.clear(); intro_time=0.0; state="intro"
	player.position=Vector3(0,0,4.5); player.target_x=0.0; player.visible=true
	player.set_aim(Vector3.FORWARD); player._play_run()
	# The Chaser leads; a pack of smaller zombies runs around and ahead of it.
	if is_instance_valid(chaser): chaser.queue_free()
	chaser=null
	# The chaser model is supplied separately; if it isn't in the project the intro still plays
	# with the horde instead of crashing.
	if ResourceLoader.exists(BossChaserScript.MODEL_PATH):
		chaser=BossChaserScript.new(); add_child(chaser); chaser.position=player.position+CHASER_OFFSET
	var horde:= [
		["walker",Vector3(1.6,0,6.4)],
		["runner",Vector3(-2.2,0,5.6)],
		["runner",Vector3(2.4,0,6.3)],
		["walker",Vector3(-2.7,0,8.4)],
		["walker",Vector3(2.8,0,9.2)],
		["runner",Vector3(-1.9,0,10.9)],
		["walker",Vector3(1.9,0,11.6)],
		["walker",Vector3(-0.6,0,12.8)],
		["walker",Vector3(0.9,0,13.4)]
	]
	for entry in horde:
		var z:=ZombieScript.new(); add_child(z); z.configure(str(entry[0]),1.0)
		z.model.rotation.y+=PI
		var offset: Vector3=entry[1]
		z.position=player.position+offset
		intro_horde_offsets.append(offset); zombies.append(z)
	_spawn_companion()
	for dog in companion_pets:
		if is_instance_valid(dog): dog.position=player.position+INTRO_PET_OFFSET+Vector3(float(dog.slot_index)*0.35,0,0)
	camera.fov=50; camera.h_offset=0; camera.v_offset=0
	camera.position=Vector3(2.2,1.05,6.6); camera.look_at(player.position+CHASER_OFFSET+Vector3(0,2.3,0))
	sound.play("zombie")

## In the opening shot the dog runs level with the survivor on the far side from the camera.
const INTRO_PET_OFFSET:=Vector3(-1.15,0,0.15)

func _tick_intro(delta: float) -> void:
	intro_time+=delta
	player.set_aim(Vector3.FORWARD); player.tick(delta)
	for dog in companion_pets:
		if is_instance_valid(dog): dog.run_beside(player.position+INTRO_PET_OFFSET+Vector3(float(dog.slot_index)*0.35,0,0),delta)
	for i in range(zombies.size()):
		var z=zombies[i]
		if not is_instance_valid(z): continue
		var offset: Vector3=intro_horde_offsets[i]
		# no backward drift: the horde keeps pace with the survivor instead of sliding behind him
		z.position=Vector3(offset.x+sin(intro_time*3.0+i)*0.07,0,player.position.z+offset.z)
	var chaser_pos:=player.position+CHASER_OFFSET-Vector3(0,0,intro_time*0.22)
	if is_instance_valid(chaser):
		chaser.position=chaser_pos
		# each heavy footfall shakes the low camera
		shake=maxf(shake,0.18*maxf(0.0,sin(intro_time*TAU*1.15)))
	# Low angle beside the survivor looking back up at the Chaser, then swing to the run camera.
	var monster_camera:=Vector3(2.2+sin(intro_time*1.8)*0.08,1.05+intro_time*0.06,6.6-intro_time*0.12)
	var chase_camera:=Vector3(0,6.4,13.5)
	var turn:=smoothstep(1.55,4.0,intro_time)
	camera.position=monster_camera.lerp(chase_camera,turn)
	camera.v_offset=randf_range(-0.04,0.04)*shake*(1.0-turn)
	camera.fov=lerpf(50.0,52.0,turn)
	var look_target:=(chaser_pos+Vector3(0,2.3,0)).lerp(Vector3(0,1.0,-8),turn)
	camera.look_at(look_target)
	if intro_time>=4.9: _finish_intro()

func _finish_intro() -> void:
	if state!="intro": return
	if not intro_seen: intro_seen=true; _save()
	# Keep the dogs where they are so they carry on from the intro instead of popping in.
	var pet_positions: Array=[]
	for dog in companion_pets:
		pet_positions.append(dog.position if is_instance_valid(dog) else Vector3.INF)
	_clear_world(); intro_horde_offsets.clear(); state="playing"; camera.v_offset=0
	player.position=Vector3(0,0,4.5); player.target_x=0.0; player.set_aim(Vector3.FORWARD)
	camera.position=Vector3(0,6.4,13.5); camera.fov=52; camera.look_at(Vector3(0,1.0,-8))
	spawn_timer=1.6; shot_timer=0.2; hint_time=7.0
	_spawn_companion()
	for i in range(mini(companion_pets.size(),pet_positions.size())):
		if is_instance_valid(companion_pets[i]) and pet_positions[i]!=Vector3.INF:
			companion_pets[i].position=pet_positions[i]
	# In a car or a tank the animals ride along out of sight (they are "in" the vehicle).
	var inside: bool=is_instance_valid(player) and player.vehicle in ["SEDAN","TANK","GOLD_CAR"]
	for pet in companion_pets:
		if is_instance_valid(pet): pet.visible = not inside
	_spawn_zombie(-18); _spawn_zombie(-32)

## ---- Mid-run chase segments ---------------------------------------------------------------
## Every few hundred metres the Abomination ambushes from behind. It gains ground steadily;
## taking a hit is a stumble that lets it closer (see _hurt_player), and inside arm's reach
## it mauls. Survive the timer and it loses the trail — that pays a coin bonus.

func _chase_begin() -> void:
	if chase_active or state!="playing": return
	if not ResourceLoader.exists(BossChaserScript.MODEL_PATH): return
	chase_active=true; chase_time=CHASE_DURATION; chase_gap=CHASE_START_GAP; chase_growl=0.0
	if is_instance_valid(chaser): chaser.queue_free()
	chaser=BossChaserScript.new(); add_child(chaser)
	chaser.position=player.position+Vector3(0,0,chase_gap)
	sound.play("zombie"); shake=maxf(shake,0.5)

func _tick_chase(delta: float) -> void:
	if not chase_active:
		if distance>=next_chase_at: _chase_begin()
		return
	if not is_instance_valid(chaser): chase_active=false; return
	chase_time-=delta
	# It gains on an even runner; a survivor with speed buffs (or Maya's adrenaline) holds
	# the gap open a little longer.
	var gain: float=CHASE_CLOSE_RATE-(player.effective_move_mult()-1.0)*1.6
	chase_gap=maxf(0.0,chase_gap-gain*delta)
	chaser.position.z=player.position.z+chase_gap
	chaser.position.x=lerpf(chaser.position.x,player.position.x,minf(1.0,delta*2.2))
	shake=maxf(shake,0.10+0.20*(1.0-minf(1.0,chase_gap/CHASE_START_GAP)))
	chase_growl-=delta
	if chase_growl<=0.0: sound.play("zombie"); chase_growl=3.2
	if chase_gap<=CHASE_CATCH:
		# Inside reach: it swipes the survivor's back — raw damage over time until it
		# loses interest, so the last seconds of a chase always hurt.
		if revive_invulnerable<=0.0 and player.vehicle=="":
			player.health=maxf(0.0,player.health-CHASE_MAUL_DPS*delta)
			damage_flash=maxf(damage_flash,0.25); shake=maxf(shake,0.6)
	if chase_time<=0.0: _chase_escape()

func _chase_escape() -> void:
	chase_active=false
	next_chase_at=distance+rng.randf_range(7600.0,8400.0) # roughly every 8000 m
	run_coins+=CHASE_REWARD
	sound.play("gate")
	_popup(player.position+Vector3(0,3.1,0),RunText.text("escaped")+"  +%d"%CHASE_REWARD,Color("c9f54a"))
	if is_instance_valid(chaser):
		var beast:=chaser; chaser=null
		# It slides back into the horde instead of popping out of existence.
		var tween:=create_tween()
		tween.tween_property(beast,"position:z",beast.position.z+22.0,1.6)
		tween.tween_callback(beast.queue_free)

func _chase_reset() -> void:
	chase_active=false; chase_time=0.0; chase_gap=0.0; next_chase_at=8000.0

## A hit during the chase is a stumble: the beast eats the lost ground at once.
func _chase_stumble() -> void:
	if chase_active: chase_gap=maxf(0.0,chase_gap-CHASE_STUMBLE)

func _setup_weather_overlay() -> void:
	var weather_layer:=CanvasLayer.new(); add_child(weather_layer)
	rain_overlay=ColorRect.new(); rain_overlay.color=Color(0,0,0,0)
	rain_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rain_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m:=ShaderMaterial.new(); m.shader=RainShader
	m.set_shader_parameter("rain_trails",true)
	m.set_shader_parameter("rain_amount",140.0)
	m.set_shader_parameter("near_rain_length",0.11); m.set_shader_parameter("far_rain_length",0.05)
	m.set_shader_parameter("near_rain_width",0.55); m.set_shader_parameter("far_rain_width",0.30)
	m.set_shader_parameter("near_rain_transparency",0.55); m.set_shader_parameter("far_rain_transparency",0.22)
	m.set_shader_parameter("rain_color",Color(0.78,0.84,0.90,1.0))
	m.set_shader_parameter("base_rain_speed",0.9); m.set_shader_parameter("additional_rain_speed",0.6)
	m.set_shader_parameter("slant",0.12)
	rain_overlay.material=m; rain_overlay.visible=false; weather_layer.add_child(rain_overlay)
	rain_material=m
	# Lightning: a brief cold-white wash over the whole screen on top of the exposure spike.
	lightning_flash=ColorRect.new(); lightning_flash.color=Color(0.86,0.92,1.0,0.0)
	lightning_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lightning_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); weather_layer.add_child(lightning_flash)

## Weather is a blind box: clear most of the time, and the atmospheric variants are rare
## enough to feel like a small event when they land (and cheap enough not to punish).
func _roll_weather() -> String:
	var roll:=rng.randf()
	if roll<0.72: return "clear"   # 72%
	if roll<0.86: return "rain"    # 14%
	if roll<0.96: return "fog"     # 10%
	return "storm"                 # 4%

## Wet road for rain/storm: a dark, glossy sheet over the tarmac plus splash droplets.
## True planar reflections are too expensive on phones, so the wet look comes from a very low
## roughness sheet catching the sky and the street lights, which reads as a wet road.
func _set_rain_surface(kind: String) -> void:
	wet_target = 1.0 if kind in ["rain","storm"] else 0.0
	if wet_sheen == null:
		wet_sheen = MeshInstance3D.new()
		var quad := PlaneMesh.new()
		quad.size = Vector2(72.0, 120.0)
		wet_sheen.mesh = quad
		wet_mat = StandardMaterial3D.new()
		wet_mat.albedo_color = Color(0.16, 0.19, 0.22, 0.0)
		wet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wet_mat.roughness = 0.10
		wet_mat.metallic = 0.45
		wet_mat.metallic_specular = 0.9
		wet_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wet_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		wet_sheen.material_override = wet_mat
		wet_sheen.position = Vector3(0, 0.035, -34.0)
		add_child(wet_sheen)

## One splash: a ring on the tarmac plus a few droplets.
## Fade the wet sheet in/out and keep the tarmac speckled with splashes while it rains.
func _tick_rain(delta: float) -> void:
	if wet_sheen == null: return
	wet_fade = move_toward(wet_fade, wet_target, delta * 1.2)
	if wet_mat != null:
		wet_mat.albedo_color.a = 0.34 * wet_fade
		wet_mat.roughness = lerpf(0.85, 0.10, wet_fade)
		wet_mat.metallic = lerpf(0.0, 0.45, wet_fade)
	wet_sheen.visible = wet_fade > 0.02
	if wet_fade > 0.35 and state == "playing":
		splash_accum += delta
		var step: float = 0.020 if weather == "storm" else 0.032
		while splash_accum >= step:
			splash_accum -= step
			_spawn_rain_splash()

func _spawn_rain_splash() -> void:
	var x := rng.randf_range(-5.5, 5.5)
	var z := rng.randf_range(-24.0, 3.0)
	var p := Vector3(x, 0.04, z)
	if rng.randf() < 0.55:
		var ring := EffectScript.new()
		ring.mode = "part"
		ring.position = p
		ring.velocity = Vector3.ZERO
		ring.gravity = 0.0
		ring.life = 0.32; ring.total_life = 0.32
		ring.spin = Vector3.ZERO
		var disc := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07; tm.outer_radius = 0.115
		disc.mesh = tm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.86, 0.92, 0.96, 0.72)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc.material_override = dm
		disc.rotation.x = -PI * 0.5
		ring.add_child(disc)
		add_child(ring)
		effects.append(ring)
	for i in range(4):
		_fx_spark_at(p + Vector3(rng.randf_range(-0.1,0.1), 0.0, rng.randf_range(-0.1,0.1)),
			Color(0.82,0.88,0.92,0.7), 0.028,
			Vector3(rng.randf_range(-0.6,0.6), rng.randf_range(1.0,1.8), rng.randf_range(-0.6,0.6)),
			-9.0, rng.randf_range(0.28,0.42))

func set_weather(kind: String) -> void:
	weather=kind
	if is_instance_valid(sound):
		sound.storm=kind=="storm"
		sound.set_rain(kind in ["rain","storm"])
	_set_rain_surface(kind)
	if world_env==null: return
	# Neutral daytime key light; the distance cycle, not a random sunset, changes the hour.
	var exposure:=0.82; var ambient:=Color("bdc7ca"); var ambient_energy:=0.46
	var fog_color:=Color("c9c8b8"); var fog_density:=0.0012; var fog_sky:=0.015
	var sun_energy:=0.95; var sky_energy:=0.96; var sun_color:=Color("ffe4b5")
	var depth_fog:=false; var fog_begin:=0.0; var fog_end:=280.0
	match kind:
		"rain":
			exposure=0.76; ambient=Color("95a2ac"); ambient_energy=0.54
			fog_color=Color("74808a"); fog_density=0.012; fog_sky=0.22
			sun_energy=0.34; sky_energy=0.62; sun_color=Color("d3dce3")
		"storm":
			exposure=0.62; ambient=Color("7c8a99"); ambient_energy=0.50
			fog_color=Color("4a5663"); fog_density=0.018; fog_sky=0.30
			sun_energy=0.18; sky_energy=0.42; sun_color=Color("b8c6d6")
		"fog":
			exposure=0.86; ambient=Color("b9c2c7"); ambient_energy=0.62
			fog_color=Color("b4bdc2"); fog_density=0.96; fog_sky=0.7
			sun_energy=0.30; sky_energy=0.70; sun_color=Color("e6ebee")
			depth_fog=true; fog_begin=12.5; fog_end=46.0
	var preset_name: String=kind
	if kind=="dusk" or kind=="dawn": preset_name="sunset"   # both use the golden-hour sky
	if kind=="clear" and force_sunset: preset_name="sunset" # explicit preview only
	if kind=="dawn":
		# cooler, paler sunrise instead of the warm sunset
		sun_color=Color("ffd6b0"); sun_energy=0.62
		ambient=Color("c8cfd8"); ambient_energy=0.52
		fog_color=Color("cfd3d8"); exposure=0.86
	var preset: Dictionary=SKY_PRESETS.get(preset_name,SKY_PRESETS["clear"])
	sky_energy=float(preset.energy)
	if preset_name=="sunset":
		sun_color=Color("ffb06a"); sun_energy=0.75; ambient=Color("d8b8a8"); fog_color=Color("e0b49a")
	# Mode first: switching fog mode resets the density in this Godot version.
	world_env.fog_mode=Environment.FOG_MODE_DEPTH if depth_fog else Environment.FOG_MODE_EXPONENTIAL
	world_env.fog_depth_begin=fog_begin; world_env.fog_depth_end=fog_end; world_env.fog_depth_curve=1.35
	world_env.fog_density=fog_density; world_env.fog_sky_affect=fog_sky
	weather_base={"exposure":exposure,"sun":sun_energy,"sun_color":sun_color,"ambient":ambient_energy,"ambient_color":ambient,"fog_color":fog_color,"sky_energy":sky_energy,"cloud_color":preset.cloud,"flash":0.0}
	lightning_t=-1.0; thunder_delay=-1.0; lightning_timer=rng.randf_range(3.0,6.0)
	if lightning_flash: lightning_flash.color.a=0.0
	if rain_material:
		var storm: bool=kind=="storm"
		rain_material.set_shader_parameter("rain_amount",260.0 if storm else 140.0)
		rain_material.set_shader_parameter("slant",0.32 if storm else 0.12)
		rain_material.set_shader_parameter("base_rain_speed",1.0 if storm else 0.9)
		rain_material.set_shader_parameter("additional_rain_speed",0.9 if storm else 0.6)
		rain_material.set_shader_parameter("near_rain_transparency",0.75 if storm else 0.55)
		rain_material.set_shader_parameter("near_rain_length",0.16 if storm else 0.11)
	if sky_material:
		sky_material.set_shader_parameter("sky_day",preset.sky); sky_material.set_shader_parameter("horizon_day",preset.horizon)
		sky_material.set_shader_parameter("sky_sunset",preset.get("sunset_sky",preset.sky)); sky_material.set_shader_parameter("horizon_sunset",preset.get("sunset_horizon",preset.horizon))
		sky_material.set_shader_parameter("day_night_mix",preset.mix)
		sky_material.set_shader_parameter("cloud_density",preset.density)
		sky_material.set_shader_parameter("cloud_depth",preset.depth); sky_material.set_shader_parameter("wind_speed",preset.wind)
		sky_material.set_shader_parameter("cloud_tiling",Vector2(preset.tiling,preset.tiling)); sky_material.set_shader_parameter("flash",0.0)
	if rain_overlay: rain_overlay.visible=kind in ["rain","storm"] and state!="shop"
	_apply_day_night()

## A complete day-night-day cycle takes 20 km. The sun crosses the horizon at 5 km and
## 15 km, reaches night at 10 km, and returns to the original daylight at 20 km.
func _apply_day_night() -> void:
	if world_env==null or weather_base.is_empty(): return
	var cycle_distance: float=(distance+day_start_offset) if state in ["playing","intro","paused","gameover"] else 0.0
	var phase: float=fposmod(cycle_distance,DAY_NIGHT_CYCLE_METRES)/DAY_NIGHT_CYCLE_METRES
	night_amount=0.5-0.5*cos(phase*TAU)
	# The first song of every night: starts the moment the sky turns dark.
	if night_amount>0.5 and not night_announced and state=="playing":
		night_announced=true
		if is_instance_valid(sound): sound.night_fell()
	elif night_amount<0.4: night_announced=false
	var flash: float=float(weather_base.get("flash",0.0))
	world_env.tonemap_exposure=float(weather_base.exposure)*lerpf(1.0,0.96,night_amount)+flash*2.4
	world_env.ambient_light_color=(weather_base.ambient_color as Color).lerp(Color("657c9c"),night_amount*0.68)
	world_env.ambient_light_energy=float(weather_base.ambient)*lerpf(1.0,0.62,night_amount)+flash*1.2
	world_env.fog_light_color=(weather_base.fog_color as Color).lerp(Color("172335"),night_amount*0.88)
	world_env.background_energy_multiplier=float(weather_base.sky_energy)*lerpf(1.0,0.58,night_amount)
	if sun_light:
		sun_light.rotation_degrees=Vector3(lerpf(-34.0,34.0,night_amount),-155,0)
		sun_light.light_energy=float(weather_base.sun)*(1.0-night_amount)+flash*2.4
		sun_light.light_color=(weather_base.sun_color as Color).lerp(Color("a9c4e4"),night_amount).lerp(Color("e8f0ff"),flash)
	if fill_light:
		fill_light.light_energy=lerpf(0.14,0.32,night_amount)+flash*1.4
		fill_light.light_color=Color("d0dbe2").lerp(Color("8caed6"),night_amount)
	if sky_material:
		sky_material.set_shader_parameter("daylight_blend",1.0-2.0*night_amount)
		sky_material.set_shader_parameter("cloud_color",(weather_base.cloud_color as Color).lerp(Color("26364b"),night_amount*0.88))
		sky_material.set_shader_parameter("sun_strength",4.0*(1.0-night_amount))
		sky_material.set_shader_parameter("moon_strength",2.2*night_amount)
	if is_instance_valid(player): player.set_night(night_amount)
	for entry in street_lamps:
		var lamp: SpotLight3D=entry.light
		lamp.visible=night_amount>0.04; lamp.light_energy=3.1*night_amount
		(entry.material as StandardMaterial3D).emission_energy_multiplier=2.4*night_amount

## Lightning only supplies a flash; _apply_day_night combines it with the current hour.
func _tick_lightning(delta: float) -> void:
	if weather!="storm" or state!="playing" or weather_base.is_empty(): return
	if lightning_t<0.0:
		lightning_timer-=delta
		if lightning_timer<=0.0:
			lightning_t=0.0; thunder_delay=rng.randf_range(0.35,1.3); lightning_timer=rng.randf_range(5.0,11.0)
	var flash:=0.0
	if lightning_t>=0.0:
		lightning_t+=delta
		var t:=lightning_t
		flash=maxf(exp(-pow((t-0.04)/0.035,2.0)),0.75*exp(-pow((t-0.20)/0.05,2.0)))
		if t>0.6: lightning_t=-1.0; flash=0.0
	if thunder_delay>=0.0:
		thunder_delay-=delta
		if thunder_delay<0.0: sound.play("thunder"); shake=maxf(shake,0.25)
	weather_base.flash=flash
	if lightning_flash: lightning_flash.color.a=flash*0.42
	if sky_material: sky_material.set_shader_parameter("flash",flash)

func open_shop() -> void:
	shop_return_state=state
	if state!="paused": _clear_world()
	state="shop"; _release_touches(); player.visible=false; shop_truck.visible=true
	run_weather=weather; set_weather("clear")
	shop_truck.position=Vector3(0,0,0); camera.h_offset=0; camera.v_offset=0
	shop_index=clampi(shop_index,0,maxi(0,shop_items.size()-1))
	shop_truck.reset_view(String(shop_items[shop_index].id) if not shop_items.is_empty() else "")
	camera.fov=shop_truck.camera_fov(); camera.position=shop_truck.camera_position(); camera.look_at(shop_truck.camera_target())

## A paused run is a still frame: stop emitting, freeze the particles mid-flight and hold the
## sound. Called from every path that enters or leaves "paused".
func _freeze_world(on: bool) -> void:
	if is_instance_valid(sound):
		sound.freeze_voices(on)
	if is_instance_valid(player) and is_instance_valid(player.flame_jet):
		player.flame_jet.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player) and is_instance_valid(player.flame_glow):
		player.flame_glow.visible = not on


## Armory: a browsable 3D catalogue of every weapon, opened from the supply truck.
const ARMORY_BTN := Rect2(404, 80, 112, 40)
const ARMORY_WEAPONS := ["PISTOL", "MAKAROV", "SUOMI", "SMG", "SHOTGUN", "SNIPER", "LAUNCHER", "FLAME"]
const ARMORY_VIEW := Rect2(40, 158, 460, 380)
## Per-weapon size multiplier for the armory stage (compact guns would fill the frame).
const ARMORY_SIZE := {"MAKAROV": 0.66, "PISTOL": 0.86, "SUOMI": 1.0, "SMG": 1.0,
	"SHOTGUN": 1.0, "SNIPER": 1.0, "LAUNCHER": 1.0, "FLAME": 1.0}
const ARMORY_BACK := Rect2(24, 24, 100, 48)
const ARMORY_PREV := Rect2(60, 722, 60, 44)
const ARMORY_UPGRADE := Rect2(150, 716, 240, 52)
const ARMORY_NEXT := Rect2(420, 722, 60, 44)   # the 3D weapon; drag it to spin
var armory_index := 0
var armory_return := "shop"
var armory_viewport: SubViewport
var armory_stage: Node3D
var armory_pivot: Node3D
var armory_model: Node3D
var armory_spin := 0.0
var armory_drag := false

## Damage / rate / magazine for every weapon, taken from the same table set_weapon uses.
const ARMORY_STATS := {
	"PISTOL":   {"damage": 24.0, "rate": 0.42, "mag": 12},
	"MAKAROV":  {"damage": 20.0, "rate": 0.36, "mag": 8},
	"SUOMI":    {"damage": 11.0, "rate": 0.085, "mag": 70},
	"SMG":      {"damage": 12.0, "rate": 0.095, "mag": 36},
	"SHOTGUN":  {"damage": 30.0, "rate": 0.72, "mag": 8},
	"SNIPER":   {"damage": 95.0, "rate": 0.85, "mag": 5},
	"LAUNCHER": {"damage": 180.0, "rate": 1.0, "mag": 4},
	"FLAME":    {"damage": 22.0, "rate": 0.12, "mag": 100},
}

## A tiny 3D stage that renders the selected weapon for the armory panel.
func _build_armory_view() -> void:
	armory_viewport = SubViewport.new()
	armory_viewport.size = Vector2i(460, 380)
	armory_viewport.own_world_3d = true
	armory_viewport.transparent_bg = true
	armory_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	armory_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(armory_viewport)

	armory_stage = Node3D.new()
	armory_viewport.add_child(armory_stage)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.16, 1.05)
	cam.fov = 34.0
	armory_stage.add_child(cam)
	cam.look_at(Vector3(0, 0.02, 0))

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, -38, 0)
	key.light_energy = 1.7
	armory_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 132, 0)
	fill.light_energy = 0.7
	armory_stage.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.34, 0.38)
	e.ambient_light_energy = 0.9
	env.environment = e
	armory_stage.add_child(env)


func _armory_show_weapon() -> void:
	if not is_instance_valid(armory_viewport):
		_build_armory_view()
	if is_instance_valid(armory_model):
		armory_model.queue_free()
		armory_model = null
	var id: String = armory_weapon_id()
	var path := "res://assets/models/weapons/%s.glb" % id.to_lower()
	if id == "RIFLE":
		path = "res://assets/models/rifle.glb"
	if not ResourceLoader.exists(path):
		return
	var model := (load(path) as PackedScene).instantiate() as Node3D
	if not is_instance_valid(armory_pivot):
		armory_pivot = Node3D.new()
		armory_stage.add_child(armory_pivot)
	armory_pivot.add_child(model)
	armory_pivot.rotation = Vector3.ZERO
	armory_model = model
	# normalise: centre it and scale the longest side to a fixed length on screen
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var a: AABB = m.transform * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var span := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := 0.62 * float(ARMORY_SIZE.get(id, 1.0)) / maxf(0.001, span)
	model.scale = Vector3.ONE * k
	var centre := box.get_center()
	model.position = -centre * k + Vector3(0, 0.02, 0)
	model.rotation.y = deg_to_rad(28.0)


## The supply-shop item that upgrades this weapon ("" when the gun is not sold there).
func armory_shop_id() -> String:
	var id: String = armory_weapon_id().to_lower()
	var candidate := "w_" + id
	for item in shop_items:
		if String(item.id) == candidate:
			return candidate
	return ""


func armory_level() -> int:
	var sid := armory_shop_id()
	if sid == "":
		return 0
	return int(meta_upgrades.get(sid, 0))


func armory_max_level() -> int:
	var sid := armory_shop_id()
	if sid == "":
		return 0
	for item in shop_items:
		if String(item.id) == sid:
			return int(item.max_level)
	return 0


## Silver cost of the next level of this weapon (0 when maxed or not sold here).
func armory_price() -> int:
	var sid := armory_shop_id()
	if sid == "":
		return 0
	for item in shop_items:
		if String(item.id) == sid:
			return item_cost(item)
	return 0


func armory_upgrade() -> void:
	var sid := armory_shop_id()
	if sid == "":
		return
	if buy_item(sid):
		_armory_show_weapon()


func armory_weapon_id() -> String:
	return String(ARMORY_WEAPONS[clampi(armory_index, 0, ARMORY_WEAPONS.size() - 1)])

func armory_step(side: int) -> void:
	armory_index = posmod(armory_index + side, ARMORY_WEAPONS.size())
	_armory_show_weapon()

func open_armory() -> void:
	armory_return = state
	armory_index = 0
	state = "armory"
	shop_truck.visible = true
	player.visible = false
	_armory_show_weapon()

func close_armory() -> void:
	state = armory_return if armory_return != "" else "shop"
	shop_truck.visible = state in ["shop", "armory"]

func close_shop() -> void:
	shop_truck.visible=false; player.visible=true; camera.fov=52
	if shop_return_state=="paused":
		state="paused"; set_weather(run_weather); camera.position=Vector3(player.position.x*0.12,6.4,13.5); camera.look_at(Vector3(player.position.x*0.08,1.0,-8)); return
	_clear_world(); set_weather("clear")
	# Back to the character lobby (from the lobby or after a run); the title poster is only the first screen.
	enter_lobby()

func open_language() -> void:
	state="language"

## DF-07 case opening: 100 gold or 1 voucher for one permanent upgrade. Purchases commit
## immediately, so leaving during the animation can never duplicate or lose a reward.
## Two payment buttons: gold (LOOTBOX_COST) or a single voucher (1 per draw).
const LOOTBOX_COST:=500        # silver per case (buy-once build)
const LOOTBOX_VOUCHER_COST:=1   # or a single voucher
const LOOTBOX_GOLD_RECT:=Rect2(30,790,230,66) # gold payment
const LOOTBOX_VOUCHER_RECT:=Rect2(280,790,230,66) # 1-voucher payment
var lootbox_return_state:="cover"
var lootbox_message:=""
var lootbox_reward_title:=""

## ---- War-room map table -------------------------------------------------------------------
## The lobby's map button opens the 3D map table. Only the city is a real destination; every
## other pinned photo answers "coming soon". Tapping the city photo starts a run right away.
var map_return_state:="character_select"
var map_toast:=0.0
var map_toast_text:=""
var map_press:=Vector2(-1,-1)
var map_dragged:=false
func open_map() -> void:
	if state=="map": return
	map_return_state=state; map_toast=0.0
	state="map"; _release_touches()
	map_scene.visible=true; lobby.visible=false; shop_truck.visible=false; player.visible=false

func close_map() -> void:
	map_scene.visible=false; state=map_return_state
	map_press=Vector2(-1,-1); map_dragged=false
	shop_truck.visible=state in ["shop", "armory"]; player.visible=state in ["playing","paused","gameover","intro","cover","health_ad"]

## A tap on the map table (press and release without a drag) either leaves, starts a run at
## the city photo, or answers "coming soon" for the locked districts.
func _map_release(pos: Vector2) -> void:
	if state=="map" and not map_dragged:
		if Rect2(24,24,100,48).has_point(pos): close_map()
		else:
			var pick: String=map_scene.pick_photo(camera,pos)
			if pick=="city":
				# The city is where the run already happens — no teleporting to yourself.
				map_toast=1.8; map_toast_text=ExtraText.text(language_code,"already_here")
			elif not pick.is_empty():
				map_toast=1.6; map_toast_text=pick.to_upper()+" · "+ExtraText.text(language_code,"stay_tuned")
	map_press=Vector2(-1,-1); map_dragged=false

func open_lootbox() -> void:
	if state=="lootbox": return
	lootbox_return_state=state; lootbox_message=""; lootbox_reward_title=""
	state="lootbox"; _release_touches(); lootbox_scene.reset_case()
	lootbox_scene.visible=true; lobby.visible=false; shop_truck.visible=false; player.visible=false

func buy_lootbox(use_voucher:=false) -> bool:
	if state!="lootbox" or lootbox_scene.opening: return false
	var candidates: Array=[]
	for item in shop_items:
		if int(meta_upgrades.get(item.id,0))<int(item.max_level): candidates.append(item)
	var pet_candidates: Array=[]
	for i in range(lobby.PETS.size()):
		if not pet_owned(i): pet_candidates.append({"id":"pet_%d"%i,"pet":i})
	var char_candidates: Array=[]
	for i in range(lobby.CHARACTERS.size()):
		if i>=2 and not character_owned(i): char_candidates.append({"id":"char_%d"%i,"char":i})
	if candidates.is_empty() and pet_candidates.is_empty() and char_candidates.is_empty(): lootbox_message=ShopText.text(language_code,"case_maxed"); return false
	if use_voucher:
		if bank_vouchers<LOOTBOX_VOUCHER_COST:
			lootbox_message=ShopText.text(language_code,"case_no_voucher")
			open_resource_pack("vouchers"); return false
		bank_vouchers-=LOOTBOX_VOUCHER_COST
	else:
		if bank_silver<LOOTBOX_COST:
			lootbox_message=ShopText.text(language_code,"case_no_coins")
			open_resource_pack("silver"); return false
		bank_silver-=LOOTBOX_COST
	# Dogs and paid characters are the jackpot: a case almost always pays an upgrade — a dog or
	# a paid character is separate. When every upgrade is maxed the case pays one of those.
	# Paid content can also drop out of a case, on two tiers of luck:
	#   1%  -> the expensive shelf (cruiser, white tiger, ...)
	#   3%  -> the cheap shelf   (survivors, dogs, starter vehicles)
	# The golden bike and the tank are deliberately excluded: they are store-only.
	var cheap_pool: Array=[]
	var rare_pool: Array=[]
	for cp in StoreCatalog.PACKS:
		if not bool(cp.get("once",false)): continue
		var kind:=String(cp.get("kind",""))
		if not kind in ["character","pet","vehicle"]: continue
		var cid:=String(cp.id)
		if cid in ["vehicle_gold","vehicle_tank"]: continue
		if store_owned.has(cid): continue
		var price:=float(cp.get("usd",0.0)) if cp.has("usd") else float(StoreCatalog.TIERS[clampi(int(cp.get("tier",0)),0,StoreCatalog.TIERS.size()-1)])
		if price>10.0: rare_pool.append(cp)
		else: cheap_pool.append(cp)
	var item: Dictionary
	var r:=rng.randf()
	if not rare_pool.is_empty() and r<0.01:
		item=rare_pool[rng.randi_range(0,rare_pool.size()-1)]
	elif not cheap_pool.is_empty() and r<0.04:
		item=cheap_pool[rng.randi_range(0,cheap_pool.size()-1)]
	elif (not cheap_pool.is_empty() or not rare_pool.is_empty()) and r<0.14:
		# 10% band: a puzzle piece for one of the paid items still missing
		var puzzle_pool: Array=cheap_pool + rare_pool
		var pp: Dictionary=puzzle_pool[rng.randi_range(0,puzzle_pool.size()-1)]
		var pid:=String(pp.id)
		puzzle_pieces[pid]=int(puzzle_pieces.get(pid,0))+1
		var got:=int(puzzle_pieces[pid])
		var label:=StoreCatalog.text(language_code,String(pp.get("name",pid)))
		if got>=50:
			# pity pays out: the pieces become the item
			puzzle_pieces.erase(pid)
			if pp.has("char"): owned_characters[int(pp.char)]=true
			elif pp.has("pet"): owned_pets[int(pp.pet)]=true
			elif pp.has("vehicle"): owned_vehicle=String(pp.vehicle)
			store_owned[pid]=true
			lootbox_reward_title="%s  ✓"%label
			sound.play("level_up")
		else:
			lootbox_reward_title="%s  %d/50"%[label,got]
		lootbox_message=""
		lootbox_scene.open_case("ammo")
		sound.play("gate"); _save()
		return true
	elif not char_candidates.is_empty() and candidates.is_empty():
		item=char_candidates[rng.randi_range(0,char_candidates.size()-1)]
	elif not pet_candidates.is_empty() and candidates.is_empty():
		item=pet_candidates[rng.randi_range(0,pet_candidates.size()-1)]
	else:
		item=candidates[rng.randi_range(0,candidates.size()-1)]
	var paid_id:=String(item.get("id",""))
	if item.has("char"):
		owned_characters[int(item.char)]=true
		store_owned[paid_id]=true
		lootbox_reward_title=character_name(int(item.char))+"  ✓"
	elif item.has("pet"):
		owned_pets[int(item.pet)]=true
		store_owned[paid_id]=true
		lootbox_reward_title=pet_name(int(item.pet))+"  ✓"
	elif item.has("vehicle"):
		owned_vehicle=String(item.vehicle)
		store_owned[paid_id]=true
		lootbox_reward_title=StoreCatalog.text(language_code,String(item.name))+"  ✓"
	else:
		meta_upgrades[item.id]=int(meta_upgrades.get(item.id,0))+1
		lootbox_reward_title=ShopText.text(language_code,String(item.name_key))+"  +1"
	lootbox_message=""; lootbox_scene.open_case(String(item.id)); sound.play("gate"); _save()
	# the fanfare lands when the reward rises out of the case: level-up for a dog/character, tada otherwise
	var fanfare:="level_up" if item.has("pet") or item.has("char") else "tada"
	get_tree().create_timer(1.15).timeout.connect(func(): if state=="lootbox": sound.play(fanfare))
	return true

func close_lootbox() -> void:
	lootbox_scene.visible=false; state=lootbox_return_state
	shop_truck.visible=state in ["shop", "armory"]; player.visible=state in ["playing","paused","gameover","intro","cover","health_ad"]

## ---- Wallet row and the real-money store -------------------------------------------------
## Full wallet (lobby/store): can energy, silver, gold and voucher, each with a + (opens the store).
## Shop wallet is silver+gold only (see wallet_layout_shop). hud.gd draws them from the same
## layouts so the buttons line up with what is on screen.
const WALLET_LOBBY:=Vector2(12,16)
const LOBBY_WALLET_SCALE:=0.78  # the lobby's balances are drawn smaller than in the shop / store
const LOBBY_GEAR:=Rect2(488,8,46,46)
const LOBBY_GEAR_PET:=Rect2(430,8,46,46)
const LOBBY_GEAR_VEHICLE:=Rect2(430,62,46,46)
## First-launch gate: the Terms of Use & Disclaimer must be accepted before the game unlocks.
## Small window on the login page (cover): a solid black card floats over the poster,
## the poster stays visible around it. Music stays on the login track.
const TERMS_PANEL:=Rect2(40,200,460,560)
const TERMS_TEXT_AREA:=Rect2(60,290,420,320)   # scrollable document area inside the window
const TERMS_AGREE:=Rect2(272,640,202,58)
const TERMS_DISAGREE:=Rect2(66,640,190,58)
var terms_accepted:=false
var terms_scroll:=0.0
var terms_press:=Vector2(-1,-1)
var terms_dragged:=false
## The red cross beside the health strip is a real button: it offers a rewarded ad for 4 cells back.
const HEALTH_AD_PANEL:=Rect2(70,360,400,270)
const HEALTH_AD_WATCH:=Rect2(94,524,352,54)
const HEALTH_AD_CANCEL:=Rect2(94,586,352,44)
const HEALTH_AD_CELLS:=4
## Filled every frame by hud._draw_hearts so _pointer_down can hit-test the cross.
var health_plus_rect:=Rect2()
const WALLET_SHOP:=Vector2(96,598)
const WALLET_STORE:=Vector2(150,78)
## Buy-once build: no cans, no store. Coins, silver and vouchers only.
func wallet_layout_premium(origin: Vector2,k:=1.0) -> Dictionary:
	var cw: float=wallet_text_w.z
	var gw: float=wallet_text_w.y
	var vw: float=wallet_text_w.w
	var coin_icon:=Rect2(origin,Vector2(34,34)*k)
	var silver_icon:=Rect2(Vector2(coin_icon.end.x+11*k+cw+18*k,origin.y),Vector2(34,34)*k)
	var v_icon:=Rect2(Vector2(silver_icon.end.x+11*k+gw+18*k,origin.y+2*k),Vector2(50,31)*k)
	return {"coin_icon":coin_icon,"coin_text":Vector2(coin_icon.end.x+11*k,origin.y+24.5*k),
		"silver_icon":silver_icon,"silver_text":Vector2(silver_icon.end.x+11*k,origin.y+24.5*k),
		"v_icon":v_icon,"v_text":Vector2(v_icon.end.x+6*k,origin.y+24.5*k)}


func wallet_layout(origin: Vector2,k:=1.0) -> Dictionary:
	if PREMIUM_BUILD:
		return wallet_layout_premium(origin, k)
	# Full 4-item wallet for lobby + store: cans, silver, gold, voucher.
	var sw: float=wallet_text_w.x; var cw: float=wallet_text_w.z; var gw: float=wallet_text_w.y; var vw: float=wallet_text_w.w
	var can_plus:=Rect2(origin+Vector2(42*k+sw+11*k,3*k),Vector2(28,28)*k)
	var coin_icon:=Rect2(Vector2(can_plus.end.x+15*k,origin.y),Vector2(34,34)*k)
	var coin_plus:=Rect2(Vector2(coin_icon.end.x+11*k+cw+11*k,origin.y+3*k),Vector2(28,28)*k)
	var silver_icon:=Rect2(Vector2(coin_plus.end.x+15*k,origin.y),Vector2(34,34)*k)
	var silver_plus:=Rect2(Vector2(silver_icon.end.x+11*k+gw+11*k,origin.y+3*k),Vector2(28,28)*k)
	var v_icon:=Rect2(Vector2(silver_plus.end.x+14*k,origin.y+2*k),Vector2(50,31)*k)
	var v_plus:=Rect2(Vector2(v_icon.end.x+6*k+vw+8*k,origin.y+3*k),Vector2(28,28)*k)
	return {"can_icon":Rect2(origin,Vector2(34,34)*k),"can_text":origin+Vector2(42,24.5)*k,"can_plus":can_plus,
		"coin_icon":coin_icon,"coin_text":Vector2(coin_icon.end.x+11*k,origin.y+24.5*k),"coin_plus":coin_plus,
		"silver_icon":silver_icon,"silver_text":Vector2(silver_icon.end.x+11*k,origin.y+24.5*k),"silver_plus":silver_plus,
		"v_icon":v_icon,"v_text":Vector2(v_icon.end.x+6*k,origin.y+24.5*k),"v_plus":v_plus}

func wallet_layout_shop(origin: Vector2,k:=1.0) -> Dictionary:
	# Shop ONLY: silver + gold. wallet_text_w.x = silver width, .y = gold width (set by hud._wallet_shop_only).
	# Two items fit left of SHOP_STORE_BTN (x=430) so nothing clips.
	var sw: float=wallet_text_w.x; var gw: float=wallet_text_w.y
	var coin_icon:=Rect2(origin,Vector2(34,34)*k)
	var coin_plus:=Rect2(Vector2(coin_icon.end.x+11*k+sw+11*k,origin.y+3*k),Vector2(28,28)*k)
	var silver_icon:=Rect2(Vector2(coin_plus.end.x+15*k,origin.y),Vector2(34,34)*k)
	var silver_plus:=Rect2(Vector2(silver_icon.end.x+11*k+gw+11*k,origin.y+3*k),Vector2(28,28)*k)
	return {"coin_icon":coin_icon,"coin_text":Vector2(coin_icon.end.x+11*k,origin.y+24.5*k),"coin_plus":coin_plus,
		"silver_icon":silver_icon,"silver_text":Vector2(silver_icon.end.x+11*k,origin.y+24.5*k),"silver_plus":silver_plus}

func _wallet_plus_hit(origin: Vector2,pos: Vector2,k:=1.0) -> bool:
	var w: Dictionary=wallet_layout_shop(origin,k) if origin==WALLET_SHOP else wallet_layout(origin,k)
	for key in ["can_plus","coin_plus","silver_plus","v_plus"]:
		if w.has(key) and (w[key] as Rect2).grow(10).has_point(pos): open_store(); return true
	return false

func open_store() -> void:
	if PREMIUM_BUILD:
		# nothing is for sale in this build
		lobby_toast = 1.6
		lobby_toast_key = "coming"
		return
	if state=="store": return
	sound.music_state("store")
	store_return_state=state; state="store"; store_scroll=0.0; store_press=Vector2(-1,-1)
	if store_currency.is_empty(): store_currency=StoreCatalog.device_currency()
	_release_touches()

func close_store() -> void:
	state=store_return_state; store_press=Vector2(-1,-1)

## Layout of the store list in content coordinates (before scrolling): section headers, then
## full-width bundle cards, then two-column coin and voucher cards.
const STORE_TOP:=124.0
const STORE_BOTTOM:=930.0
static func store_bottom(h: float) -> float:
	return h-30.0
func store_view_rect() -> Rect2:
	return Rect2(0,STORE_TOP,540,store_bottom(ui_h)-STORE_TOP)

func store_layout() -> Array:
	# One full-width row per pack (list layout); grey caps label above each group.
	var items:=[]; var y:=6.0
	if offer_active():
		items.append({"pack":StoreCatalog.offer(offer_id),"rect":Rect2(22,y,496,160)}); y+=172.0
	for section in ["pass","bundle","vehicle","character","pet","skin","cans","coins","silver","vouchers"]:
		items.append({"header":section,"rect":Rect2(22,y,496,30)}); y+=32.0
		if section=="cans":
			items.append({"can_ad":true,"rect":Rect2(22,y,496,74)}); y+=84.0
		for p in StoreCatalog.PACKS:
			if p.kind!=section: continue
			var h:=138.0 if section=="bundle" else 112.0
			items.append({"pack":p,"rect":Rect2(22,y,496,h)}); y+=h+10.0
		if section=="bundle": items.append({"pack":REMOVE_ADS_PACK,"rect":Rect2(22,y,496,112)}); y+=122.0
		y+=10.0
	return items

func store_content_height() -> float:
	var h:=0.0
	for it in store_layout(): h=maxf(h,(it.rect as Rect2).end.y)
	return h+60.0  # room for the price note at the end

func store_max_scroll() -> float:
	return maxf(0.0,store_content_height()-(store_bottom(ui_h)-STORE_TOP))

## Where an item sits on screen right now.
func store_screen_rect(item: Dictionary) -> Rect2:
	var r: Rect2=item.rect
	return Rect2(r.position+Vector2(0,STORE_TOP-store_scroll),r.size)

## The price button inside a pack card.
static func store_price_rect(card: Rect2,_bundle: bool) -> Rect2:
	return Rect2(card.end.x-132,card.get_center().y-24,116,48)

func _store_drag(pos: Vector2,rel: Vector2) -> void:
	if not store_dragged and pos.distance_to(store_press)>10.0: store_dragged=true
	if store_dragged: store_scroll=clampf(store_scroll-rel.y,0.0,store_max_scroll())

func _terms_drag(pos: Vector2,rel: Vector2) -> void:
	if not terms_dragged and pos.distance_to(terms_press)>10.0: terms_dragged=true
	if terms_dragged: terms_scroll=clampf(terms_scroll-rel.y,0.0,hud.terms_max_scroll())

## A tap (no slide) on a card buys it.
func _store_release(pos: Vector2) -> void:
	if store_press.x<0: return
	var tapped: bool=not store_dragged
	store_press=Vector2(-1,-1)
	if not tapped or not store_view_rect().has_point(pos): return
	for it in store_layout():
		if not store_screen_rect(it).has_point(pos): continue
		if it.has("can_ad"): request_reward_ad("can_refill"); return
		if it.has("pack"): buy_pack(it.pack.id); return

## Buying a pack. Real charging needs the App Store (StoreKit in-app purchases) hooked in here;
## until that is connected, running from the Godot editor grants the pack so the flow can be
## tested, and an exported game only says payments are not connected yet.
func pack_by_id(id: String) -> Dictionary:
	if id=="removeads": return REMOVE_ADS_PACK
	var p: Dictionary=StoreCatalog.pack(id)
	return p if not p.is_empty() else StoreCatalog.offer(id)

func pack_owned(id: String) -> bool:
	return remove_ads if id=="removeads" else bool(store_owned.get(id,false))

## Price shown on a pack: the App Store's localized price on device; the old price table only in
## the editor simulator (development only). "…" while prices are still loading.
func pack_price(p: Dictionary,cur: String) -> String:
	if iap and iap.mode=="storekit":
		var t: String=iap.price(String(p.id))
		return t if t!="" else "…"
	if iap and iap.mode=="sim":
		if p.has("usd"): return StoreCatalog.bundle_price(cur,float(p.usd))
		return StoreCatalog.price_text(cur,int(p.tier))
	return "—"

## The struck-through "was" price of an offer is only known from our own table, so it is shown
## in the simulator only; on device the discount percentage carries the message.
func pack_was_price(p: Dictionary,cur: String) -> String:
	if iap and iap.mode=="sim": return StoreCatalog.price_text(cur,int(p.get("was",p.tier)))
	return ""

## Buying a pack opens Apple's native purchase sheet (StoreKit 2). Nothing is granted here:
## rewards come only from _iap_grant, after the App Store reports a verified transaction.
func buy_pack(id: String) -> bool:
	var p: Dictionary=pack_by_id(id)
	if p.is_empty(): return false
	var lang:=language_code
	if bool(p.get("once",false)) and pack_owned(id):
		store_toast_text=StoreCatalog.text(lang,"owned"); store_toast=1.6; return false
	if PREMIUM_BUILD:
		# this build only deals in coins and silver
		var cost_coins := int(p.get("coins", 0))
		var cost_silver := int(p.get("silver", 0))
		if cost_coins > 0 and bank_coins < cost_coins:
			store_toast_text = ExtraText.text(lang, "not_enough_coins"); store_toast = 1.8; return false
		if cost_silver > 0 and bank_silver < cost_silver:
			store_toast_text = ExtraText.text(lang, "not_enough_silver"); store_toast = 1.8; return false
		bank_coins -= cost_coins
		bank_silver -= cost_silver
		_iap_grant(id, "premium")
		sound.play("equip")
		_save()
		return true
	if iap==null or iap.mode=="none": purchase_failed(id); return false
	# In the editor, hold Shift while tapping a pack to see the failure popup.
	if iap.mode=="sim" and OS.has_feature("editor") and Input.is_key_pressed(KEY_SHIFT): iap.sim_next="failed"
	if iap.busy.has(id): return false
	store_toast_text=ExtraText.text(lang,"iap_busy"); store_toast=1.2
	return iap.buy(id)

## Grants a verified transaction (called by iap_service exactly once per transaction ID, before
## the transaction is finished). Returns true once the reward is saved.
func _iap_grant(id: String,_tx: String) -> bool:
	var p: Dictionary=pack_by_id(id)
	if p.is_empty(): return false
	if id=="removeads": remove_ads=true
	else:
		bank_coins+=int(p.get("coins",0)); bank_silver+=int(p.get("silver",0)); bank_vouchers+=int(p.get("vouchers",0)); stamina.add(int(p.get("cans",0)))
		if p.has("char"): owned_characters[int(p.char)]=true
		if p.has("skin"): owned_skins[int(p.skin)]=true
		if p.has("pet"): owned_pets[int(p.pet)]=true
		if p.has("vehicle"): owned_vehicle=String(p.vehicle)
		if id=="unlock_all":
			all_access=true; remove_ads=true
			stamina.infinite=true
			for q in StoreCatalog.PACKS:
				if bool(q.get("once",false)): store_owned[String(q.id)]=true
				if q.has("char"): owned_characters[int(q.char)]=true
				if q.has("skin"): owned_skins[int(q.skin)]=true
				if q.has("pet"): owned_pets[int(q.pet)]=true
		if PASS_REWARDS.has(id):
			passes[id]=true; pass_days.erase(id)  # fresh pass pays out today
		if bool(p.get("once",false)): store_owned[id]=true
		if id==offer_id: offer_id=""; offer_expires=0
	_save(); return true

func _on_purchase_finished(id: String,status: String) -> void:
	var lang:=language_code
	match status:
		"purchased":
			store_toast_text=ExtraText.text(lang,"iap_ok"); store_toast=1.8; sound.play("coin_get")
			if state=="offer": close_offer()
			elif state=="resource_pack": close_resource_pack()
		"restored":
			if id=="removeads": remove_ads=true; _save()
			store_toast_text=ExtraText.text(lang,"restored" if id!="" else "nothing_restore"); store_toast=1.8
		"revoked":
			if id=="removeads": remove_ads=false; _save()
		"pending": store_toast_text=ExtraText.text(lang,"iap_pending"); store_toast=2.4
		"cancelled": store_toast_text=ExtraText.text(lang,"iap_cancelled"); store_toast=1.4
		_: purchase_failed(id)

const STORE_RESTORE:=Rect2(392,28,132,40)
func restore_purchases() -> void:
	if iap: iap.restore()

## Called whenever a purchase doesn't complete (not connected, cancelled, network error, or a
## StoreKit failure once real payments are hooked up): nothing is granted, the popup explains.
func purchase_failed(id: String) -> void:
	payfail_pack=id
	if state!="payfail": payfail_return_state=state
	state="payfail"; store_toast=0.0; _release_touches()

func close_payfail() -> void:
	state=payfail_return_state; payfail_pack=""

func retry_payfail() -> void:
	var id:=payfail_pack
	close_payfail()
	if buy_pack(id):
		if state=="offer": close_offer()
		elif state=="resource_pack": close_resource_pack()

static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())

func offer_active() -> bool:
	if PREMIUM_BUILD: return false
	return not offer_id.is_empty() and now_unix()<offer_expires

func offer_seconds_left() -> int:
	return maxi(0,offer_expires-now_unix())

## Counts today's play time (resets at midnight) for the "already played a lot today" rule.
func _track_play_time(delta: float) -> void:
	var today:=Time.get_date_string_from_system()
	if today!=play_day: play_day=today; play_seconds_today=0.0
	play_seconds_today+=delta

## Called whenever the player lands in the lobby. Pops an offer only if the gap since the last
## one has passed and today's play time is still short; otherwise does nothing.
## True when the player already owns what this bundle sells, so it must never pop.
func _offer_owned(o: Dictionary) -> bool:
	if all_access: return true  # Cheat Code: nothing left to sell
	if o.has("vehicle") and owned_vehicle==String(o.vehicle): return true
	if o.has("char") and owned_characters.has(int(o.char)): return true
	if o.has("pet") and owned_pets.has(int(o.pet)): return true
	return false

func maybe_show_offer(force:=false) -> bool:
	if PREMIUM_BUILD: return false
	if "--smoke-test" in OS.get_cmdline_user_args() and not force: return false
	if offer_active(): return false
	var now:=now_unix()
	if next_offer_at==0 and not force:
		next_offer_at=now+24*3600; _save(); return false  # brand-new players get a day first
	if not force:
		if now<next_offer_at: return false
		var today:=Time.get_date_string_from_system()
		if today==play_day and play_seconds_today>OFFER_SKIP_AFTER_MINUTES*60.0: return false
	# one different bundle a day: never pick the one shown last time
	var pool: Array=[]
	for it in StoreCatalog.OFFERS:
		if String(it.id)!=last_offer_id and not _offer_owned(it): pool.append(it)
	if pool.is_empty(): return false
	var o: Dictionary=pool[rng.randi()%pool.size()]
	last_offer_id=String(o.id)
	offer_id=o.id; offer_expires=now+StoreCatalog.OFFER_HOURS*3600
	next_offer_at=now+int(rng.randf_range(OFFER_GAP_HOURS.x,OFFER_GAP_HOURS.y)*3600.0)
	_save(); open_offer(); return true

func open_offer() -> void:
	if not offer_active() or state=="offer": return
	offer_return_state=state; state="offer"; _release_touches()

func close_offer() -> void:
	state=offer_return_state

const RESOURCE_PACKS:={"coins":"coins_1","silver":"silver_1","vouchers":"vouchers_1","cans":"cans_1"}
func open_resource_pack(kind: String) -> void:
	if not RESOURCE_PACKS.has(kind): return
	resource_pack_id=String(RESOURCE_PACKS[kind])
	resource_pack_return_state=state
	state="resource_pack"; _release_touches()

func close_resource_pack() -> void:
	state=resource_pack_return_state

## Voucher spending uses the same shortage popup. Spending exactly the balance is a success,
## not a shortage; only a failed purchase opens the pack.
func spend_vouchers(cost: int) -> bool:
	if cost<=0: return true
	if bank_vouchers<cost:
		open_resource_pack("vouchers"); return false
	bank_vouchers-=cost; _save(); return true

## Popup layout, shared with hud.gd.
const OFFER_PANEL:=Rect2(36,150,468,646)
const OFFER_CLOSE:=Rect2(452,156,44,44)
const OFFER_BUY:=Rect2(96,714,348,62)
## The small offer badge on the right of the lobby.
const OFFER_BADGE:=Rect2(2,246,92,104)    # left column, under the airdrop

## ---- Check-in and missions ----------------------------------------------------------------
## Lobby side buttons.
const SIDE_MAP:=Rect2(470,118,70,76)    # map select (more maps coming) — right-hand column

## ---- Daily airdrop -------------------------------------------------------------------------
## Once a day the lobby's airdrop can be opened for free by watching one rewarded ad.
const AIRDROP_RECT:=Rect2(16,118,90,118)   # slightly left, while keeping a visible screen-edge margin
var airdrop_day:=""
## Supply crates: three a day, and only every fifth run.
var airdrop_count_today:=0
var runs_total:=0
var airdrop_at_run:=-5
var airdrop_reward:={}   # what the last drop held, shown on the reveal screen
var airdrop_return_state:="character_select"

func airdrop_available() -> bool:
	if PREMIUM_BUILD: return false
	if airdrop_day!=today():
		airdrop_day=today()
		airdrop_count_today=0
	if airdrop_count_today>=3:
		return false
	return runs_total-airdrop_at_run>=5

func _roll_airdrop() -> Dictionary:
	var r:=rng.randf()
	if r<0.60: return {"coins":rng.randi_range(8,20)*10,"vouchers":0}
	if r<0.90: return {"coins":rng.randi_range(5,12)*10,"vouchers":1}
	return {"coins":0,"vouchers":2}

func _open_airdrop() -> void:
	airdrop_day=today(); airdrop_reward=_roll_airdrop()
	airdrop_count_today+=1; airdrop_at_run=runs_total
	_grant(int(airdrop_reward.coins),int(airdrop_reward.vouchers)); _save()
	airdrop_return_state=state if state!="airdrop" else airdrop_return_state; state="airdrop"; _release_touches()

## ---- Share the result ------------------------------------------------------------------------
## On the phone this opens the system share sheet (Facebook, WhatsApp, Messages, X ...) with a
## screenshot of the results and a line of text, through an iOS share plugin singleton if one is
## installed. Without one (editor / desktop) the text is copied to the clipboard instead.
const SHARE_RECT:=Rect2(66,832,408,54)   # same width/height as the shop button, same 20 px gap
const SHARE_SINGLETONS:=["GodotShare","Share","NativeShare"]
var share_toast:=0.0
func share_text() -> String:
	return ExtraText.text(language_code,"share_text").replace("%m",str(int(distance))).replace("%k",str(kills))

func share_result() -> String:
	var text:=share_text()
	var img_path:=OS.get_user_data_dir().path_join("dead_frontier_result.png")
	var vp:=get_viewport()
	if vp and vp.get_texture(): vp.get_texture().get_image().save_png(img_path)
	for name in SHARE_SINGLETONS:
		if Engine.has_singleton(name):
			var sh=Engine.get_singleton(name)
			if sh.has_method("share_image"): sh.share_image(img_path,"Dead Frontier",text,""); return "native"
			if sh.has_method("sharePic"): sh.sharePic(img_path,"Dead Frontier","Dead Frontier",text); return "native"
			if sh.has_method("share"): sh.share(text,"Dead Frontier",img_path); return "native"
			if sh.has_method("shareText"): sh.shareText("Dead Frontier","Dead Frontier",text); return "native"
	DisplayServer.clipboard_set(text); share_toast=2.2
	return "clipboard"
const SIDE_BAG:=Rect2(470,198,70,76)    # backpack
const SIDE_SIGNIN:=Rect2(470,278,70,76)   # same x as the rest of the rail
const SIDE_TASKS:=Rect2(470,358,70,76)
const SIDE_SHOP:=Rect2(470,438,70,76)   # supply truck (upgrades)
const SIDE_STORE:=Rect2(470,518,70,76)  # real-money store
const SIDE_MAIL:=Rect2(470,598,70,76)   # mailbox

## ---- Backpack --------------------------------------------------------------------------------
## Everything the player holds. For now coins and vouchers (vouchers only when there are any);
## gifts with other item types can be added to bag_items() later.
var bag_return_state:="character_select"
func bag_items() -> Array:
	var items:=[{"id":"coins","count":bank_coins}]
	if bank_silver>0: items.append({"id":"silver","count":bank_silver})
	if bank_vouchers>0: items.append({"id":"vouchers","count":bank_vouchers})
	return items

const BAG_COLS:=4
const BAG_ROWS:=8
const BAG_TOP:=150.0
var bag_scroll:=0.0
func bag_slot_count() -> int:
	return BAG_COLS*BAG_ROWS
func bag_slot(i: int) -> Rect2:
	return Rect2(36+(i%BAG_COLS)*120,BAG_TOP+(i/BAG_COLS)*140-bag_scroll,108,128)
func bag_max_scroll() -> float:
	return maxf(0.0,BAG_TOP+BAG_ROWS*140.0-(ui_h-40.0))

func open_bag() -> void:
	bag_return_state=state; state="bag"; _release_touches()

func close_bag() -> void:
	state=bag_return_state

## ---- Mailbox ---------------------------------------------------------------------------------
## Gifts for players. A welcome mail is built in; more come from MAIL_URL, a JSON file you host
## anywhere (fetched each time the lobby opens):
##   {"mails":[{"id":"launch_gift","title":{"en":"Launch gift","zh_CN":"上线福利"},
##              "body":{"en":"...","zh_CN":"..."},"coins":300,"vouchers":2,"until":"2026-12-31"}]}
## Titles / bodies may also be plain strings. Each id can be claimed once per player.
const MAIL_URL:=""
const MAIL_TOP:=150.0
const MAIL_ROW:=128.0
var mails: Array=[]
var mail_claimed:={}
var mail_return_state:="character_select"
var mail_http: HTTPRequest

func _builtin_mail() -> Array:
	return [{"id":"welcome_v1","title":ExtraText.text(language_code,"welcome_title"),"body":ExtraText.text(language_code,"welcome_body"),"coins":200,"vouchers":3,"cans":50}]

func _mail_text(v,fallback:="") -> String:
	if v is Dictionary: return String(v.get(language_code,v.get("en",fallback)))
	return String(v) if v!=null else fallback

func refresh_mail() -> void:
	var list:=_builtin_mail()
	for m in remote_mail:
		if m is Dictionary and m.has("id"):
			if m.has("until") and String(m.until)<Time.get_date_string_from_system(): continue
			list.append({"id":String(m.id),"title":_mail_text(m.get("title")),"body":_mail_text(m.get("body")),
				"coins":int(m.get("coins",0)),"vouchers":int(m.get("vouchers",0)),"cans":int(m.get("cans",0))})
	mails=list

var remote_mail: Array=[]
func fetch_mail() -> void:
	if MAIL_URL=="" or "--smoke-test" in OS.get_cmdline_user_args(): return
	if not is_instance_valid(mail_http):
		mail_http=HTTPRequest.new(); add_child(mail_http)
		mail_http.request_completed.connect(func(_r,code,_h,body):
			if code!=200: return
			var data=JSON.parse_string(body.get_string_from_utf8())
			if data is Dictionary and data.get("mails") is Array: remote_mail=data.mails; refresh_mail())
	mail_http.request(MAIL_URL)

func mail_unclaimed() -> int:
	var n:=0
	for m in mails:
		if not mail_claimed.has(String(m.id)) and (int(m.coins)>0 or int(m.vouchers)>0 or int(m.get("cans",0))>0): n+=1
	return n

func open_mail() -> void:
	refresh_mail(); mail_return_state=state; state="mail"; mail_open=-1; _release_touches()

func close_mail() -> void:
	state=mail_return_state

func mail_row(i: int) -> Rect2:
	return Rect2(30,MAIL_TOP+i*MAIL_ROW,480,MAIL_ROW-12)

static func mail_claim_rect(row: Rect2) -> Rect2:
	return Rect2(row.end.x-138,row.end.y-54,124,42)

## Reading a letter: the full text scrolls; rewards and the claim button sit at its end.
const LETTER_VIEW:=Rect2(24,96,492,840)
var mail_open:=-1
var mail_scroll:=0.0
var mail_press:=Vector2(-1,-1)
var mail_dragged:=false
var mail_text_h:=0.0  # height of the wrapped letter text, measured by the HUD while drawing

func letter_content_h() -> float:
	return mail_text_h+(190.0 if mail_open>=0 and mail_open<mails.size() and (int(mails[mail_open].coins)>0 or int(mails[mail_open].vouchers)>0 or int(mails[mail_open].get("cans",0))>0) else 40.0)

func letter_max_scroll() -> float:
	return maxf(0.0,letter_content_h()-LETTER_VIEW.size.y)

## Claim button at the end of the letter, in screen coordinates (moves as the letter scrolls).
func letter_claim_rect() -> Rect2:
	return Rect2(150,LETTER_VIEW.position.y+mail_text_h+110.0-mail_scroll,240,58)

func open_letter(i: int) -> void:
	mail_open=i; mail_scroll=0.0; mail_press=Vector2(-1,-1); mail_text_h=0.0

func _letter_release(pos: Vector2) -> void:
	if mail_press.x<0: return
	var tapped:=not mail_dragged; mail_press=Vector2(-1,-1)
	if not tapped: return
	if mail_open<0:
		for i in range(mini(mails.size(),5)):
			if mail_row(i).has_point(pos): open_letter(i); return
	elif letter_claim_rect().has_point(pos) and LETTER_VIEW.has_point(pos):
		claim_mail(String(mails[mail_open].id))

func claim_mail(id: String) -> bool:
	if mail_claimed.has(id): return false
	for m in mails:
		if String(m.id)==id:
			mail_claimed[id]=true; _grant(int(m.coins),int(m.vouchers)); stamina.add(int(m.get("cans",0))); _save(); return true
	return false
## In the supply truck: a plain way into the store next to the coin balance.
const SHOP_STORE_BTN:=Rect2(430,590,92,48)
## Check-in popup.
const SIGNIN_PANEL:=Rect2(30,170,480,520)
const SIGNIN_CLOSE:=Rect2(458,180,44,44)
const SIGNIN_CLAIM:=Rect2(56,600,200,64)
const SIGNIN_DOUBLE:=Rect2(268,600,216,64)
## Missions page.
const TASK_TOP:=196.0
func lobby_behind() -> bool:
	if state=="character_select": return true
	if state=="offer": return offer_return_state=="character_select"
	if state=="resource_pack": return resource_pack_return_state=="character_select"
	if state=="store": return false
	if state=="mail": return mail_return_state=="character_select"
	if state=="bag": return bag_return_state=="character_select"
	if state=="airdrop": return airdrop_return_state=="character_select"
	if state=="tasks": return tasks_return_state=="character_select"
	if state=="signin": return signin_return_state=="character_select"
	if state=="payfail":
		if payfail_return_state=="offer": return offer_return_state=="character_select"
		if payfail_return_state=="resource_pack": return resource_pack_return_state=="character_select"
		return payfail_return_state=="character_select"
	return false

func today() -> String:
	return Time.get_date_string_from_system()

## Starts a fresh day / event window when the date has moved on.
func _roll_progress() -> void:
	if daily_day!=today(): daily_day=today(); daily_stats.clear(); daily_claimed.clear(); daily_swaps.clear()
	var w:=int(now_unix()/(ProgressCatalog.EVENT_DAYS*86400))
	if w!=event_window: event_window=w; event_stats.clear(); event_claimed.clear(); event_swaps.clear()

func _progress(stat: String,amount: int) -> void:
	if amount<=0: return
	_roll_progress()
	daily_stats[stat]=int(daily_stats.get(stat,0))+amount
	event_stats[stat]=int(event_stats.get(stat,0))+amount

func daily_missions() -> Array:
	_roll_progress()
	return _apply_swaps(ProgressCatalog.pick(ProgressCatalog.DAILY_POOL,ProgressCatalog.DAILY_COUNT,"daily"+daily_day),ProgressCatalog.DAILY_POOL,daily_swaps)

func event_missions() -> Array:
	_roll_progress()
	return _apply_swaps(ProgressCatalog.pick(ProgressCatalog.EVENT_POOL,ProgressCatalog.EVENT_COUNT,"event"+str(event_window)),ProgressCatalog.EVENT_POOL,event_swaps)

func _apply_swaps(list: Array,pool: Array,swaps: Dictionary) -> Array:
	for slot in swaps:
		var i: int=int(slot)
		if i<0 or i>=list.size(): continue
		for m in pool:
			if String(m.id)==String(swaps[slot]): list[i]=m
	return list

## A mission can be swapped by ad while it is still open (not done, not claimed) and the pool
## has another mission that is not already shown, done or claimed.
func can_swap_mission(slot: int,daily: bool) -> bool:
	var list: Array=daily_missions() if daily else event_missions()
	if slot<0 or slot>=list.size(): return false
	var m: Dictionary=list[slot]
	if mission_claimed(m,daily) or mission_ready(m,daily): return false
	return not _swap_candidates(list,daily).is_empty()

func _swap_candidates(list: Array,daily: bool) -> Array:
	var shown:={}
	for m in list: shown[String(m.id)]=true
	var out:=[]
	for m in (ProgressCatalog.DAILY_POOL if daily else ProgressCatalog.EVENT_POOL):
		if shown.has(String(m.id)) or mission_claimed(m,daily) or mission_value(m,daily)>=int(m.goal): continue
		out.append(m)
	return out

func swap_mission(slot: int,daily: bool) -> bool:
	if not can_swap_mission(slot,daily): return false
	var list: Array=daily_missions() if daily else event_missions()
	var options: Array=_swap_candidates(list,daily)
	var pick: Dictionary=options[rng.randi_range(0,options.size()-1)]
	(daily_swaps if daily else event_swaps)[slot]=String(pick.id); _save(); return true

func mission_value(m: Dictionary,daily: bool) -> int:
	return mini(int(m.goal),int((daily_stats if daily else event_stats).get(String(m.stat),0)))

func mission_claimed(m: Dictionary,daily: bool) -> bool:
	return (daily_claimed if daily else event_claimed).has(String(m.id))

func mission_ready(m: Dictionary,daily: bool) -> bool:
	return mission_value(m,daily)>=int(m.goal) and not mission_claimed(m,daily)

func claim_mission(m: Dictionary,daily: bool) -> bool:
	if not mission_ready(m,daily): return false
	(daily_claimed if daily else event_claimed)[String(m.id)]=true
	_grant(int(m.coins),int(m.vouchers)); return true

func missions_ready_count() -> int:
	var n:=0
	for m in daily_missions(): if mission_ready(m,true): n+=1
	for m in event_missions(): if mission_ready(m,false): n+=1
	return n

## Bought "unlock all": coins, silver, vouchers and cans are endless, shown as the infinity mark.
func infinite_resources() -> bool:
	return all_access


func _grant(coins: int,vouchers: int) -> void:
	bank_coins+=coins; bank_vouchers+=vouchers
	var parts:=[]
	if coins>0: parts.append("+%d %s"%[coins,StoreCatalog.text(language_code,"coin_packs")])
	if vouchers>0: parts.append("+%d %s"%[vouchers,StoreCatalog.text(language_code,"voucher_packs")])
	store_toast_text=" ".join(parts) if not parts.is_empty() else ""; store_toast=1.6
	sound.play("coin_get"); _save()

## Seconds until the daily missions reset (local midnight) and until the event window ends.
func seconds_to_midnight() -> int:
	var t:=Time.get_datetime_dict_from_system()
	return 86400-(int(t.hour)*3600+int(t.minute)*60+int(t.second))

func event_seconds_left() -> int:
	_roll_progress()
	return maxi(0,(event_window+1)*ProgressCatalog.EVENT_DAYS*86400-now_unix())

## Which reward list the panel is showing right now.
func signin_rewards() -> Array:
	return ProgressCatalog.SIGNIN_MONTH if signin_monthly else ProgressCatalog.SIGNIN


## Day index inside the active track.
func signin_day_index() -> int:
	return signin_month_index if signin_monthly else signin_index


func signin_available() -> bool:
	return signin_last!=today()


## A new month wipes the 30-day track back to day one.
func _signin_roll_month() -> void:
	var key := Time.get_date_string_from_system().substr(0, 7)
	if signin_month_key != key:
		signin_month_key = key
		signin_month_index = 0

func claim_signin(times:=1) -> bool:
	if not signin_available(): return false
	var list: Array = signin_rewards()
	var idx: int = signin_day_index()
	if idx < 0 or idx >= list.size(): return false
	var r: Dictionary = list[idx]
	signin_last = today()
	if signin_monthly:
		signin_month_index = (signin_month_index + 1) % list.size()
	else:
		signin_index = (signin_index + 1) % list.size()
	bank_silver += int(r.get("silver", 0)) * times
	_grant(int(r.get("coins", 0))*times,int(r.get("vouchers", 0))*times)
	return true

func can_ads_left() -> int:
	return maxi(0,CAN_AD_DAILY_LIMIT-clampi(can_ad_count,0,CAN_AD_DAILY_LIMIT)) if can_ad_day==today() else CAN_AD_DAILY_LIMIT

## Rewarded ads besides revive: double today's check-in, double run coins, or refill cans.
func request_reward_ad(purpose: String) -> bool:
	if not ad_pending.is_empty() or not is_instance_valid(revival_ads): return false
	if purpose=="signin_double" and not signin_available(): return false
	if purpose in ["free_run","can_refill"] and not _reward_ad_allowed(purpose): return false
	if remove_ads and _reward_ad_allowed(purpose): _on_ad_rewarded(purpose); return true
	if purpose=="run_double" and not can_double_run(): return false
	if purpose=="airdrop" and not airdrop_available(): return false
	if purpose.begins_with("swap:"):
		var a: PackedStringArray=purpose.split(":")
		if not can_swap_mission(int(a[2]),a[1]=="daily"): return false
	if revival_ads.show_reward_ad(purpose): ad_pending=purpose
	return not ad_pending.is_empty()

func _on_ad_rewarded(purpose: String) -> void:
	ad_pending=""
	match purpose:
		"signin_double": claim_signin(2)
		"airdrop": if airdrop_available(): _open_airdrop()
		_ when purpose.begins_with("swap:"):
			var a: PackedStringArray=purpose.split(":"); swap_mission(int(a[2]),a[1]=="daily")
		"run_double":
			if state=="gameover" and run_double_bonus==0 and (last_reward>0 or last_silver_reward>0):
				run_double_bonus=last_reward; run_double_silver=last_silver_reward; bank_coins+=run_double_bonus; bank_silver+=run_double_silver; _save(); sound.play("coin_get")
		"free_run":
			if _reward_ad_allowed(purpose):
				ad_run_used=true; _save(); start_run(true)
		"can_refill":
			if _reward_ad_allowed(purpose):
				can_ad_day=today(); can_ad_count+=1; stamina.add(CAN_AD_REWARD)
				store_toast_text="+%d %s"%[CAN_AD_REWARD,StoreCatalog.text(language_code,"can_packs")]; store_toast=1.6
				_save(); sound.play("coin_get")
		"health_refill":
			if _reward_ad_allowed(purpose):
				var heal_cells: float=HEALTH_AD_CELLS*(100.0/3.0)   # one heart cell = 100/3 HP
				player.health=minf(player.max_health,player.health+heal_cells)
				var zh_ad: bool=language_code.begins_with("zh")
				_popup(player.position+Vector3(0,2.5,0),"+%d %s"%[int(heal_cells),"血量" if zh_ad else "HP"],Color("c9f54a"))
				sound.play("coin_get")
			if state=="health_ad": state="playing"
	_release_touches()

func _reward_ad_allowed(purpose: String) -> bool:
	if purpose=="run_double": return can_double_run()
	if purpose=="airdrop": return airdrop_available()
	if purpose=="free_run": return not ad_run_used and stamina.value<stamina.RUN_COST and state=="character_select"
	if purpose=="can_refill": return state=="store" and can_ads_left()>0
	if purpose=="health_refill": return state=="health_ad" and player.health<player.max_health-0.01
	if purpose.begins_with("swap:"):
		var a: PackedStringArray=purpose.split(":"); return can_swap_mission(int(a[2]),a[1]=="daily")
	return true

	maybe_offer_no_ads()

func _on_ad_cancelled(_purpose: String) -> void:
	ad_pending=""
	if state=="health_ad": state="playing"

func can_double_run() -> bool:
	return state=="gameover" and run_double_bonus==0 and (last_reward>0 or last_silver_reward>0)

## Results screen: the ×2 button sits beside the total, under the kill breakdown.
func gameover_double_rect() -> Rect2:
	var y:=340.0
	for kind in ["banshee","brute","jockey","runner","walker"]:
		if int(kill_counts.get(kind,0))>0: y+=22.0
	return Rect2(262,y+30,196,58)

func open_signin() -> void:
	if state=="signin": return
	signin_return_state=state; state="signin"; _release_touches()

func close_signin() -> void:
	state=signin_return_state

func open_tasks() -> void:
	tasks_return_state=state; state="tasks"; _release_touches()

func close_tasks() -> void:
	state=tasks_return_state

## Tile rectangles of the 7 check-in days (4 on top, then 3 with a wide day 7).
## Week / month switch at the top of the check-in panel.
func signin_tab_rect(t: int) -> Rect2:
	return Rect2(56 + t * 220, 214, 208, 46)


func signin_tile(i: int) -> Rect2:
	if signin_monthly:
		# 6 columns x 5 rows inside the same panel: 30 days on one screen
		var col: int = i % 6
		var row: int = i / 6
		return Rect2(40 + col * 77, 258 + row * 62, 71, 56)
	if i<4: return Rect2(46+i*114,262,106,150)
	if i<6: return Rect2(46+(i-4)*114,424,106,150)
	return Rect2(274,424,220,150)

## Mission rows on the missions page for the open tab.
func task_rows() -> Array:
	var rows:=[]; var daily: bool=tasks_tab==0
	var list: Array=daily_missions() if daily else event_missions()
	for i in range(list.size()):
		rows.append({"m":list[i],"daily":daily,"slot":i,"rect":Rect2(30,TASK_TOP+i*124,480,112)})
	return rows

static func task_button(row: Rect2) -> Rect2:
	return Rect2(row.end.x-138,row.position.y+60,124,40)

## Small "swap by ad" button left of the mission's main button.
static func task_swap_button(row: Rect2) -> Rect2:
	return Rect2(row.end.x-194,row.position.y+60,46,40)

static func tasks_tab_rect(t: int) -> Rect2:
	return Rect2(30+t*246,92,234,46)

## Survivor / pet picker: a horizontal strip above the start button (swipe sideways to scroll).
const LOBBY_SLOTS:=8   # cards per tab; slots past the real survivors / dogs read "coming soon"
## Start button: the gap above it (to the picker) equals the gap below it (to the screen edge).
const LOBBY_START:=Rect2(66,860,408,76)
const LOBBY_AD_RUN:=Rect2(482,860,48,76)
## Loadout switch in the lobby: with every pack unlocked for testing, this is the only
## way to start a vanilla run - no vehicle, no pet.
const LOBBY_LOADOUT:=Rect2(12,860,48,76)
const LOBBY_STRIP_Y:=732.0   # strip ends exactly where the start button begins (836)
const LOBBY_STEP:=96.0
const LOBBY_CARD:=Vector2(88,104)
const LOBBY_LEFT_X:=12.0
const LOBBY_BAND_TOP:=684.0   # the dark band behind tabs, strip and start button
## Main screen list: one column on the left with 角色 / 宠物 tabs; it scrolls vertically.
var lobby_tab:=0          # 0 = survivors, 1 = pets, 2 = skins, 3 = vehicle
var vehicle_choice:=0 # which vehicle card is shown in the lobby stage (0 scrambler, 1 sport, 2 cruiser)
## The lobby only showcases the four bikes; the tank and the black saloon are played but never
## displayed here (user's call).
## All six keep a card in the lobby; the tank and the saloon just never stand on the rug.
const LOBBY_VEHICLE_CARDS:=7
var lobby_scroll:=0.0
var lobby_press:=Vector2(-1,-1)
var lobby_dragged:=false

## Page arrows at the two ends of the picker strip (shown only when there is more that way).
func lobby_page_rect(side: int) -> Rect2:
	return Rect2(0.0 if side<0 else 540.0-30.0,LOBBY_STRIP_Y,30,LOBBY_CARD.y)

func lobby_page_visible(side: int) -> bool:
	return lobby_scroll>1.0 if side<0 else lobby_scroll<lobby_max_scroll()-1.0

func lobby_page(side: int) -> void:
	lobby_scroll=clampf(lobby_scroll+side*LOBBY_STEP*4.0,0.0,lobby_max_scroll())

func lobby_tab_rect(t: int) -> Rect2:
	# tab 2 (skins) is gone, so the vehicle tab takes the third slot instead of leaving a gap
	var slot := 3 if t == 4 else (2 if t == 3 else t)
	return Rect2(LOBBY_LEFT_X+slot*72.0,LOBBY_BAND_TOP+4,68,40)

func lobby_view_rect() -> Rect2:
	return Rect2(LOBBY_LEFT_X-6,LOBBY_STRIP_Y,540-2*(LOBBY_LEFT_X-6),LOBBY_CARD.y)

func lobby_item_count() -> int:
	if lobby_tab==2: return maxi(LOBBY_SLOTS,lobby.SKINS.size())
	if lobby_tab==3: return LOBBY_VEHICLE_CARDS # BIKE / SPORT / CRUISER / GOLD / TANK / SEDAN
	if lobby_tab==4: return 1  # the flamethrower
	return maxi(LOBBY_SLOTS,lobby.CHARACTERS.size()) if lobby_tab==0 else maxi(LOBBY_SLOTS,lobby.PETS.size())

func lobby_max_scroll() -> float:
	return maxf(0.0,lobby_item_count()*LOBBY_STEP-(LOBBY_STEP-LOBBY_CARD.x)+12.0-lobby_view_rect().size.x)

## The EQUIP dropdown sits just above the survivor card it belongs to.
func equip_menu_rect() -> Rect2:
	var c:=lobby_card_rect(clampi(equip_menu_index,0,maxi(0,lobby_item_count()-1)))
	# Two rows (equip on top, unequip below), lifted clear of the card.
	return Rect2(c.position.x-6.0,c.position.y-96.0,c.size.x+12.0,40.0)

func lobby_card_rect(i: int) -> Rect2:
	return Rect2(LOBBY_LEFT_X+i*LOBBY_STEP-lobby_scroll,LOBBY_STRIP_Y,LOBBY_CARD.x,LOBBY_CARD.y)

func set_lobby_tab(t: int) -> void:
	if t == 2: return   # the skins tab was removed
	if t==lobby_tab: return
	lobby_tab=t; lobby_scroll=0.0; equip_menu_index=-1
	lobby.focus_pets=t==1
	lobby.focus_vehicle=t==3

## A finger lifted without sliding picks the card under it; a slide only scrolls the list.
## Wears whatever the open dropdown points at, on whichever tab opened it.
## Lobby card -> shop pack id, so a locked card can be bought right there with coins or silver.
## "1200 金币" / "4000 银币" for a lobby card, empty when there is nothing to buy.
func card_price_text(tab: int, index: int) -> String:
	var pid := _pack_id_for_card(tab, index)
	if pid == "":
		return ""
	var p: Dictionary = pack_by_id(pid)
	if p.is_empty():
		return ""
	var zh := String(language_code).begins_with("zh")
	var coins := int(p.get("coins", 0))
	var silver := int(p.get("silver", 0))
	if coins > 0:
		return "%d %s" % [coins, "金币" if zh else "coins"]
	if silver > 0:
		return "%d %s" % [silver, "银币" if zh else "silver"]
	return ""


func _pack_id_for_card(tab: int, index: int) -> String:
	match tab:
		0:
			return ["", "char_riley", "char_darius", "char_maya"][clampi(index, 0, 3)]
		1:
			return "pet_%d" % clampi(index, 0, 5)
		3:
			return ["vehicle_bike", "vehicle_sport", "vehicle_car", "vehicle_gold",
				"vehicle_tank", "vehicle_sedan", "vehicle_gold_car"][clampi(index, 0, 6)]
		4:
			return "weapon_flame"
	return ""


## The "take it off" row directly under the equip row.
func equip_menu_unequip_rect() -> Rect2:
	var r := equip_menu_rect()
	return Rect2(r.position.x, r.end.y + 4.0, r.size.x, 36.0)


## Strips whatever the dropdown points at, so a run can start with nothing equipped.
func _unequip_from_menu() -> void:
	match equip_menu_tab:
		1:
			pet_equipped = false
		2:
			skin_choice.erase(character_choice)
		3:
			owned_vehicle = ""
			vehicle_choice = 0
		4:
			weapon_equipped = false
	_save()


func _equip_from_menu() -> void:
	var stay_tab := equip_menu_tab   # equipping must never move the player to another tab
	match equip_menu_tab:
		1:
			if equip_menu_index < lobby.PETS.size():
				select_pet(equip_menu_index)
		2:
			if equip_menu_index < lobby.SKINS.size():
				select_skin(equip_menu_index)
		3:
			var vkey: String = String(["BIKE","SPORT","CRUISER","GOLD","TANK","SEDAN","GOLD_CAR"][clampi(equip_menu_index,0,6)])
			if vehicle_is_owned(String(["vehicle_bike","vehicle_sport","vehicle_car","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"][clampi(equip_menu_index,0,6)])):
				owned_vehicle = vkey
				_save()
		4:
			weapon_equipped = true
			_save()
		_:
			select_character(equip_menu_index)
	if lobby_tab != stay_tab:
		lobby_tab = stay_tab
		lobby.focus_pets = stay_tab == 1
		lobby.focus_vehicle = stay_tab == 3


func _lobby_release(pos: Vector2) -> void:
	if lobby_press.x<0: return
	var was_drag:=lobby_dragged; lobby_press=Vector2(-1,-1); lobby_dragged=false
	if was_drag: return
	# The dropdown sits above the card strip, outside lobby_view_rect(), so it used to be rejected
	# by the guard below and every tap fell through to the card underneath.
	if equip_menu_index>=0:
		if equip_menu_rect().has_point(pos):
			_equip_from_menu()
			equip_menu_index=-1; sound.play("equip"); return
		equip_menu_index=-1  # tapping elsewhere just closes the dropdown
		return              # and the tap goes no further
	if not lobby_view_rect().has_point(pos): return
	for i in range(lobby_item_count()):
		if lobby_card_rect(i).has_point(pos):
			if lobby_tab==4:
				# one card: the flamethrower. Owned ones offer EQUIP, unowned ones just say so.
				if not flame_owned():
					if PREMIUM_BUILD:
						buy_pack(_pack_id_for_card(4, i))
					else:
						lobby_toast=1.8; lobby_toast_key="char_locked"
				elif weapon_equipped:
					lobby_toast=1.6; lobby_toast_key="char_equipped"
				else:
					equip_menu_index=i; equip_menu_tab=4
				return
			if lobby_tab==3:
				vehicle_choice=i
				# The tank (3) and the saloon (4) keep their card, art and name, but are never
				# mounted on the 3D stage: mounting those two huge models here stalls the lobby.
				if i <= 3:
					lobby.set_vehicle_visual(i)
				else:
					lobby.set_vehicle_visual(vehicle_choice if vehicle_choice <= 3 else 0)
					lobby.focus_vehicle = false
					# the big vehicles are never staged in the lobby: say where to see them
					store_toast_text=ExtraText.text(language_code,"view_in_match")
					store_toast=2.0
				# tapping an owned vehicle EQUIPS it: vehicle_choice is only the preview,
				# so the run used to keep mounting whatever was stored before.
				var vkey: String=String(["BIKE","SPORT","CRUISER","GOLD","TANK","SEDAN","GOLD_CAR"][clampi(i,0,6)])
				if vehicle_is_owned(String(["vehicle_bike","vehicle_sport","vehicle_car","vehicle_gold","vehicle_tank","vehicle_sedan","vehicle_gold_car"][clampi(i,0,6)])):
					if owned_vehicle == vkey:
						lobby_toast=1.6; lobby_toast_key="char_equipped"
					else:
						equip_menu_index=i; equip_menu_tab=3
				elif PREMIUM_BUILD:
					buy_pack(_pack_id_for_card(3, i))
			elif lobby_tab==2:
				if i<lobby.SKINS.size():
					if int(skin_choice.get(character_choice, -1)) == i:
						lobby_toast=1.6; lobby_toast_key="char_equipped"
					else:
						equip_menu_index=i; equip_menu_tab=2
				else: lobby_toast=1.6; lobby_toast_key="coming"
			elif lobby_tab==1:
				if i<lobby.PETS.size():
					if pet_choice == i and pet_equipped:
						lobby_toast=1.6; lobby_toast_key="char_equipped"
					elif PREMIUM_BUILD and not pet_owned(i):
						buy_pack(_pack_id_for_card(1, i))
					else:
						equip_menu_index=i; equip_menu_tab=1
				else: lobby_toast=1.6; lobby_toast_key="coming"
			elif i<lobby.CHARACTERS.size():
				# preview the survivor and offer the dropdown; wearing them is a second tap
				if character_owned(i):
					lobby.show_character(i,character_asset(i))
					if i==character_choice:
						# already worn: no dropdown, just say so
						lobby_toast=1.6; lobby_toast_key="char_equipped"
					else:
						equip_menu_index=i; equip_menu_tab=0
				else:
					if PREMIUM_BUILD:
						buy_pack(_pack_id_for_card(0, i))
					else:
						select_character(i)
			else: lobby_toast=1.6; lobby_toast_key="coming"
			return

func _lobby_drag(pos: Vector2,rel: Vector2) -> void:
	if not lobby_dragged and pos.distance_to(lobby_press)>10.0: lobby_dragged=true
	if lobby_dragged: lobby_scroll=clampf(lobby_scroll-rel.x,0.0,lobby_max_scroll())

func _lobby_tap(pos: Vector2) -> void:
	_pointer_down(pos); _lobby_release(pos)

func select_character(index: int) -> void:
	index=posmod(index,lobby.CHARACTERS.size())
	if not character_owned(index):
		# Locked survivor: a tap still shows their model on the platform (preview only);
		# character_choice is untouched, so they can never be taken into a run.
		lobby_preview_character=index; lobby_preview_asset=""
		lobby.show_character(index,"")
		lobby_toast=1.8; lobby_toast_key="char_locked"; return
	lobby_preview_character=-1; lobby_preview_asset=""
	character_choice=index; player.set_character(character_choice,character_asset(character_choice)); lobby.show_character(character_choice,character_asset(character_choice)); _save()

## ---- Outfit skins --------------------------------------------------------------------------
func default_skin_index(char_index: int) -> int:
	for i in range(lobby.SKINS.size()):
		if int(lobby.SKINS[i].get("char",-1))==char_index: return i
	return -1

func selected_skin_index(char_index: int=-1) -> int:
	if char_index<0: char_index=character_choice
	return int(skin_choice.get(char_index,default_skin_index(char_index)))

func character_asset(char_index: int) -> String:
	# Only an explicit skin pick overrides the body; every other character uses the
	# default model from player.CHARACTER_ASSETS / lobby.CHARACTERS ("" = no override).
	if skin_choice.has(char_index):
		var si:=int(skin_choice[char_index])
		if si>=0 and si<lobby.SKINS.size(): return String(lobby.SKINS[si].asset)
	return ""

func select_skin(i: int) -> void:
	if i<0 or i>=lobby.SKINS.size(): return
	var char_index:=int(lobby.SKINS[i].get("char",-1))
	if char_index<0: return
	if not character_owned(char_index):
		# Locked owner: still preview this outfit on the platform (owner wearing it), never select.
		var skin_asset:=String(lobby.SKINS[i].asset)
		lobby_preview_character=char_index; lobby_preview_asset=skin_asset
		lobby.show_character(char_index,skin_asset)
		lobby_toast=1.8; lobby_toast_key="char_locked"; return
	if not skin_owned(i):
		# Locked outfit: preview the owner wearing it on the platform, never select.
		lobby_preview_character=char_index; lobby_preview_asset=String(lobby.SKINS[i].asset)
		lobby.show_character(char_index,String(lobby.SKINS[i].asset))
		lobby_toast=1.8; lobby_toast_key="skin_locked"; return
	lobby_preview_character=-1; lobby_preview_asset=""
	skin_choice[char_index]=i; character_choice=char_index
	player.set_character(char_index,character_asset(char_index))
	lobby.show_character(char_index,character_asset(char_index))
	_save()

func character_name(i: int) -> String:
	return RunText.text(String(lobby.CHARACTERS[i].name).to_lower(),language_code)

func pet_name(i: int) -> String:
	return RunText.text("dog_%d"%i,language_code)

func pet_owned(index: int) -> bool:
	if all_access: return true
	return owned_pets.has(index) or owned_pets.has(str(index))

## Mason (0) and Riley (1) are free forever; everyone else is bought once in the store.
func character_owned(index: int) -> bool:
	if all_access: return true
	if is_instance_valid(lobby) and (index<0 or index>=lobby.CHARACTERS.size()): return false
	return index<=0 or owned_characters.has(index) or owned_characters.has(str(index))

## A character's default look comes with the character; only the extra outfits cost money.
func skin_owned(index: int) -> bool:
	if all_access: return true
	if index<0 or index>=lobby.SKINS.size(): return false
	if index==default_skin_index(int(lobby.SKINS[index].get("char",-1))): return true
	return owned_skins.has(index) or owned_skins.has(str(index))

func vehicle_owned(id: String) -> bool:
	return owned_vehicle==id


## Is this store vehicle ("vehicle_bike" / "vehicle_sport" / "vehicle_cruiser") owned?
## vehicle_owned() above only answers "is it the one currently equipped", and it compares
## against the vehicle names BIKE/SPORT/CRUISER - never the store id. A one-off vehicle
## purchase records itself in store_owned, so check that first, then fall back to the
## equipped name for saves written before store_owned existed.
## The flamethrower is a one-off store purchase; the purchase record is the ownership flag.
func flame_owned() -> bool:
	return bool(store_owned.get("weapon_flame", false))

func vehicle_is_owned(id: String) -> bool:
	if all_access: return true
	if store_owned.has(id): return true
	var name_of: Dictionary={"vehicle_bike":"BIKE","vehicle_sport":"SPORT","vehicle_cruiser":"CRUISER","vehicle_gold":"GOLD","vehicle_tank":"TANK","vehicle_sedan":"SEDAN"}
	var vname: String=String(name_of.get(id,""))
	return vname!="" and owned_vehicle==vname

func select_pet(index: int) -> void:
	index=posmod(index,lobby.PETS.size())
	if not pet_owned(index):
		# Locked: show it off on the platform, but it can't be taken into a run.
		lobby.show_pet(lobby.PETS[index].asset); lobby_toast=1.8; lobby_toast_key="pet_locked"
		if pet_equipped and pet_choice!=index: pass
		return
	if pet_equipped and index==pet_choice:
		pet_equipped=false; lobby.show_pet(""); _save(); return
	pet_choice=index; sound.play("equip"); pet_equipped=true; lobby.show_pet(lobby.PETS[pet_choice].asset); _save()

## Every finished run lands back in the character lobby.
## Lobby switch: take the whole loadout off, or put it back.
func toggle_pet_equip() -> void:
	if not pet_owned(pet_choice): return
	pet_equipped=not pet_equipped
	if is_instance_valid(lobby):
		lobby.show_pet(lobby.PETS[pet_choice].asset if pet_equipped and loadout_on else "")
	_save()

func toggle_vehicle_equip() -> void:
	vehicle_equipped=not vehicle_equipped
	vehicle_auto_active=loadout_on and vehicle_equipped and owned_vehicle!=""
	_save()

func toggle_loadout() -> void:
	loadout_on=not loadout_on
	_save()
	if is_instance_valid(lobby):
		lobby.show_pet(lobby.PETS[pet_choice].asset if pet_equipped and loadout_on else "")

func go_to_lobby() -> void:
	_clear_world(); set_weather("clear"); player.visible=true
	enter_lobby()

## Both passes pay out once per calendar day. Rewards stack if a player owns both.
const PASS_REWARDS:={"pass_weekly":{"coins":200,"cans":30},"pass_monthly":{"coins":500,"cans":100}}
var puzzle_pieces:={}  # store id -> pieces collected (50 unlocks that item)
var all_access:=false  # "unlock everything" pack: no ads, endless coins and rations
var passes:={}        # pass id -> true while the subscription is live
var pass_days:={}     # pass id -> "YYYY-MM-DD" of the last payout
func _tick_pass() -> void:
	if passes.is_empty(): return
	var today:=Time.get_date_string_from_system()
	var coins_in:=0
	var cans_in:=0
	for id in passes.keys():
		if String(pass_days.get(String(id),""))==today: continue
		pass_days[String(id)]=today
		var r: Dictionary=PASS_REWARDS.get(String(id),{})
		coins_in+=int(r.get("coins",0))
		cans_in+=int(r.get("cans",0))
	if coins_in<=0 and cans_in<=0: return
	bank_coins+=coins_in
	stamina.add(cans_in)
	store_toast_text="Pass: +%d coins, +%d rations"%[coins_in,cans_in]
	store_toast=2.2
	_save()

func enter_lobby() -> void:
	# Swallow the tap that brought us here: iOS sends an emulated mouse event for the
	# same finger, and that second press landed on the lobby Start button underneath.
	lobby_swallow_tap=0.45
	_dev_unlock_all()
	if pet_equipped and not pet_owned(pet_choice): pet_equipped=false
	# Locked content can never stay selected (old saves predate the store).
	if not character_owned(character_choice): character_choice=0
	if skin_choice.has(character_choice) and not skin_owned(int(skin_choice[character_choice])): skin_choice.erase(character_choice)
	lobby_preview_character=-1; lobby_preview_asset=""
	# Gate buffs (incl. the +max-HP ones) are permanent only within the run:
	# leaving it clears them, so the lobby never shows last run's bonuses.
	if is_instance_valid(player):
		player.reset(); player.apply_meta(meta_upgrades)
	refresh_mail(); fetch_mail()
	state="character_select"; lobby.visible=true; lobby.show_character(character_choice,character_asset(character_choice)); lobby.show_pet(lobby.PETS[pet_choice].asset if pet_equipped else "")
	var today:=Time.get_date_string_from_system()
	if signin_available() and signin_shown_day!=today and not "--smoke-test" in OS.get_cmdline_user_args():
		signin_shown_day=today; open_signin(); return
	maybe_show_offer()

## Swap button / E / Tab: switch between the crate gun and the pistol (unlimited ammo).
func swap_weapon(out_of_ammo:=false) -> bool:
	if state!="playing" or not player.swap_weapon(): return false
	sound.play("reload")
	var zh:=language_code.begins_with("zh")
	var names:={"PISTOL":"手枪","SMG":"冲锋枪","SHOTGUN":"霰弹枪","SNIPER":"狙击枪","RIFLE":"突击步枪","LAUNCHER":"榴弹发射器"}
	var label: String=("弹药耗尽 → 手枪" if zh else "OUT OF AMMO → PISTOL") if out_of_ammo else (String(names.get(player.weapon,player.weapon)) if zh else player.weapon)
	_popup(player.position+Vector3(0,2.5,0),label,Color("ffd275"))
	return true

func select_shop_item(index: int) -> void:
	if shop_items.is_empty(): return
	shop_index=posmod(index,shop_items.size()); shop_truck.focus(shop_items[shop_index].id)

func item_cost(item: Dictionary) -> int:
	return int(item.cost)+int(meta_upgrades.get(item.id,0))*20

## Spends silver only: supply-truck gear upgrades are a pure silver transaction.
func _spend_silver(cost: int) -> bool:
	if bank_silver<cost: return false
	bank_silver-=cost
	return true

func buy_item(id: String) -> bool:
	for item in shop_items:
		if item.id!=id: continue
		var level: int=meta_upgrades.get(id,0); var cost: int=item_cost(item)
		if level>=int(item.max_level): return false
		if not _spend_silver(cost):
			open_resource_pack("silver"); return false
		meta_upgrades[id]=level+1; sound.play("pickup"); _save(); return true
	return false

func _clear_world() -> void:
	for body in dying_zombies:
		if is_instance_valid(body): body.queue_free()
	dying_zombies.clear()
	venoms.clear()
	venom_streams.clear()
	if is_instance_valid(chaser): chaser.queue_free(); chaser=null
	for dog in companion_pets:
		if is_instance_valid(dog): dog.queue_free()
	companion_pets.clear(); companion_pet=null
	for collection in [zombies,bullets,ordnance,gates,barrels,crates,blood_pools,obstacles,pickups,effects]:
		for node in collection:
			if is_instance_valid(node): node.queue_free()
		collection.clear()

func _end_run() -> void:
	if state!="playing": return
	survival_bonus=int(distance/75.0)
	var total_reward:=run_coins+survival_bonus
	bank_coins+=maxi(0,total_reward-last_reward)
	last_reward=total_reward
	bank_silver+=maxi(0,run_silver-last_silver_reward)
	last_silver_reward=run_silver
	# missions: count the run once, and only the new metres after a revival
	if not run_counted: run_counted=true; _progress("runs",1)
	_progress("distance",int(distance-run_counted_distance)); run_counted_distance=distance
	state="gameover"; revive_pending=false; _release_touches(); gameover_time=0.0
	chase_active=false # a run that ends mid-chase keeps the beast standing as a corpse shot
	# A new personal best (not on the very first run, which has nothing to beat).
	if run_start_best>0 and int(distance)>run_start_best: new_record=true
	best_distance=maxi(best_distance,int(distance)); _save()
	sound.play("game_over")
	if new_record: sound.play("gate")

## The moment the survivor passes their old best mid-run: banner, confetti burst, sound.
func _check_record(delta: float) -> void:
	record_banner=maxf(0.0,record_banner-delta)
	if new_record or run_start_best<=0 or int(distance)<=run_start_best: return
	new_record=true; record_banner=3.0; sound.record_fanfare()

func record_metres_left() -> int:
	return maxi(0,run_start_best-int(distance))

## Tapping the red cross beside the health strip offers a rewarded ad for 4 health cells back.
func _tap_health_plus() -> void:
	if player.health>=player.max_health-0.01:
		var full: bool=language_code.begins_with("zh")
		_popup(player.position+Vector3(0,2.5,0),"血量已满" if full else "HP FULL",Color("ffd275")); return
	state="health_ad"; _release_touches()

func request_revival() -> bool:
	if state!="gameover" or revive_pending: return false
	if revive_used and not PREMIUM_BUILD: return false
	if remove_ads: _revive_after_reward(); return true
	if not is_instance_valid(revival_ads): return false
	revive_pending=revival_ads.show_revival_ad()
	return revive_pending

func _revive_ad_cancelled() -> void:
	revive_pending=false

func _revive_after_reward() -> void:
	if state!="gameover" or revive_used or player.health>0.0: return
	var r: Dictionary=REVIVES[revive_count]
	revive_count+=1
	if PREMIUM_BUILD:
		# buy-once build: every ad brings you back, with a fixed slice of health
		revive_used = false
		player.health = maxf(player.health, player.max_health * PREMIUM_REVIVE_HP)
		revive_invulnerable = PREMIUM_REVIVE_INVULN
	else:
		revive_used = revive_count>=REVIVES.size()
	revive_pending=false
	revive_invulnerable=float(r.invuln)
	player.health=maxf(1.0,player.max_health*float(r.hp))
	for z in zombies.duplicate():
		if is_instance_valid(z) and _flat_distance(z.position,player.position)<13.0:
			_burst(z.position+Vector3(0,1.0,0),Color("ff9b55"),8)
			zombies.erase(z); z.queue_free()
	state="playing"; damage_flash=0.0; spawn_timer=1.8; shot_timer=0.25; surge=false; wave_quota=0; wave_clear_banner=0.0; phase_timer=3.2
	# Back on your feet: the beast loses your trail for a moment before the next ambush.
	if is_instance_valid(chaser) and not chase_active: chaser.queue_free(); chaser=null
	next_chase_at=maxf(next_chase_at,distance+150.0)
	_release_touches(); _popup(player.position+Vector3(0,2.5,0),RunText.text("revived"),Color("c9f54a"))

func _count_zombie_kind(type: String) -> int:
	var count:=0
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.kind==type: count+=1
	return count

## ---- wave director ------------------------------------------------------------------
## Waves beat a flat trickle: a burst you can clean out, then a real breather. The quota
## grows by two per wave and stops at 26, so late waves are dense but still clearable.
func _wave_size() -> int:
	return clampi(4+wave*2,6,26)

## Difficulty steps up with the wave number and stops at 2.1 (it used to grow with run
## time without a ceiling, which turned every gun into a peashooter by ten minutes).
func _wave_difficulty() -> float:
	return minf(1.0+0.08*float(maxi(0,wave-1)),2.1)

func _living_zombies() -> int:
	var count:=0
	for z in zombies:
		if is_instance_valid(z) and not z.dead: count+=1
	return count

func _begin_wave(ramp: float) -> void:
	wave+=1; surge=true; wave_banner=2.0; sound.play("gate")
	wave_quota=_wave_size()
	wave_timeout=lerpf(30.0,45.0,ramp)  # generous: normally the road clearing ends the wave
	spawn_timer=minf(spawn_timer,0.45)

func _end_wave(ramp: float) -> void:
	surge=false; wave_quota=0
	wave_clear_banner=2.2
	phase_timer=lerpf(6.5,3.8,ramp)*rng.randf_range(0.9,1.1)
	# Clean sweep: a small patch-up, so a good wave pushes the run forward instead of only
	# draining it. Deep in a run the breather - and the heal - are smaller.
	if is_instance_valid(player):
		player.health=minf(player.max_health,player.health+player.max_health*lerpf(0.07,0.04,ramp))

## Lobby zombies are off: the safehouse lobby shows no wanderers.
var lobby_zombie_count := 0
func _spawn_lobby_zombies() -> void:
	# Clear whatever was left over first: a stray brute from a previous run would loom in
	# the lobby and read as a "test" zombie.
	for z in zombies.duplicate():
		if is_instance_valid(z): z.queue_free()
	zombies.clear()
	for i in lobby_zombie_count:
		_spawn_zombie(-11.0 - float(i) * 3.0, "walker")
	var lane := 0
	for z in zombies:
		if is_instance_valid(z):
			z.passive = true
			z.position.x = clampf(-2.4 + float(lane), -2.4, 2.4)
			lane += 1

func _spawn_zombie(at_z:=-85.0,forced_kind:="") -> void:
	# Health steps up per wave and stops at 2.1 (see _wave_difficulty): the late game gets
	# harder through numbers and specials, not through bullet sponges.
	var difficulty:=_wave_difficulty()
	var z:=ZombieScript.new(); var roll:=rng.randf(); var kind:=forced_kind
	if kind.is_empty():
		# Unlock order: walker -> runner(female) -> jockey -> brute(juggernaut) -> banshee -> bomber.
		# Each tier only appears after the previous one has been introduced.
		if run_time>40.0 and not jockey_introduced: kind="jockey"
		elif run_time>110.0 and not banshee_introduced and roll<0.02: kind="banshee"
		else:
			kind="walker"
			if run_time>20 and roll<minf(0.34,0.12+run_time*0.0015): kind="runner"
			# brute after jockey has been seen
			if jockey_introduced and run_time>30 and roll>maxf(0.80,0.94-run_time*0.0008): kind="brute"
			# bomber only after banshee tier, deep into the run (time-based, not unreachable distance)
			if run_time>150.0 and roll>0.11 and roll<0.17 and _count_zombie_kind("bomber")+_count_zombie_kind("bomber_female")<2:
				kind="bomber" if rng.randf()<0.5 else "bomber_female"
			# Spitter: same late tier as the bomber, spits from a distance instead of closing in.
			if run_time>95.0:
				var spitter_p: float=clampf(0.05+(run_time-95.0)*0.0007,0.05,0.16)
				if roll>0.52 and roll<0.52+spitter_p and _count_zombie_kind("spitter")<2: kind="spitter"
			# Late game: plain walkers thin out, specials take over - but the walker never
			# reaches zero, so the road still reads as a horde rather than a boss rush.
			if run_time>150.0 and kind=="walker":
				var special_bias: float=clampf((run_time-150.0)/240.0,0.0,0.45)
				if rng.randf()<special_bias: kind="runner" if rng.randf()<0.55 else "jockey"
			if jockey_introduced and run_time>50 and roll>0.36 and roll<0.43 and _count_zombie_kind("jockey")<2: kind="jockey"
			# Banshee: rare at start, scales up with time. 1.5% at 110s -> up to ~8% late.
			if run_time>110.0:
				var banshee_p: float=clampf(0.015+(run_time-110.0)*0.00035,0.015,0.08)
				if roll>1.0-banshee_p and _count_zombie_kind("banshee")<1: kind="banshee"
	# Two male zombie bodies: roughly half of the plain walkers use the second model.
	# Three male zombie bodies: plain, the second (black) and the third (Asian) model.
	if kind=="walker":
		var body_roll := rng.randf()
		if body_roll < 0.30: kind="walker_b"
		elif body_roll < 0.60: kind="walker_c"
	# And two female runners, 40% of them use the second body.
	if kind=="runner" and rng.randf()<0.40: kind="runner_b"
	if kind=="jockey": jockey_introduced=true
	elif kind=="banshee":
		banshee_introduced=true
		banshee_warning=3.8
		if at_z< -30.0: at_z=-24.0
	var lanes:=[-2.4,0.0,2.4]; var lane: float=lanes[rng.randi_range(0,2)]
	if kind=="banshee": lane=_clear_lane_for_banshee(at_z,lane)
	for other in zombies:
		if is_instance_valid(other) and absf(other.position.x-lane)<1.1 and absf(other.position.z-at_z)<2.3: at_z-=2.8
	add_child(z); z.configure(kind,difficulty); z.position=Vector3(lane,0,at_z); zombies.append(z)

# ---- Banshee keep-out: she is slow and wide, so roadblocks, cars and barrels coming from the
# distance must never be spawned into her lane (they would drive straight through her).
const BANSHEE_KEEP_OUT:=1.75

func _banshee_xs() -> Array:
	var xs:=[]
	for z in zombies:
		if is_instance_valid(z) and not z.dead and z.kind=="banshee": xs.append(z.position.x)
	return xs

func _x_blocked_by_banshee(x: float,half_width: float) -> bool:
	for bx in _banshee_xs():
		if absf(x-bx)<BANSHEE_KEEP_OUT+half_width: return true
	return false

func _clear_lane_for_banshee(at_z: float,preferred: float) -> float:
	# Pick the lane with the most room around her spawn point.
	var best:=preferred; var best_score:=-1.0
	for lane in [preferred,-2.4,0.0,2.4]:
		var score:=100.0
		for obstacle in obstacles:
			if is_instance_valid(obstacle) and absf(obstacle.position.x-lane)<obstacle.half_extents.x+1.2:
				score=minf(score,absf(obstacle.position.z-at_z))
		for barrel in barrels:
			if is_instance_valid(barrel) and not barrel.dead and absf(barrel.position.x-lane)<1.4:
				score=minf(score,absf(barrel.position.z-at_z))
		if score>best_score+0.01: best=lane; best_score=score
	return best

func _wants_to_fire() -> bool:
	return true

## Flamethrower: instead of bullets, everything inside a forward cone catches fire. Zombies
## burn for their own duration and take damage over time (see ZombieScript.ignite).
const FLAME_RANGE := 10.5
const FLAME_HALF_ANGLE := 11.0
const FLAME_BURN_SECONDS := 3.0
const FLAME_BURN_FRACTION := 0.09
const FLAME_TICK_DAMAGE := 22.0   # per 0.12 s tick: it is a paid gold weapon
## Crates and barrels count hits, not health; the flame takes several per tick.
const FLAME_STRUCTURE_HITS := 60   # flame melts a case: one burst is enough
func _fire_flame() -> bool:
	var fwd: Vector3 = aim_direction.normalized()
	var origin: Vector3 = player.muzzle_position()
	var hit := 0
	var flat_fwd: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	for z in zombies:
		if not is_instance_valid(z) or z.dead: continue
		var d: Vector3 = z.position - origin
		d.y = 0.0
		var dist: float = d.length()
		if dist > FLAME_RANGE: continue
		if dist > 0.4 and flat_fwd.dot(d.normalized()) < cos(deg_to_rad(FLAME_HALF_ANGLE)): continue
		_hit_zombie(z, FLAME_TICK_DAMAGE, "torso", z.position + Vector3(0, 1.0, 0), Color("ffb14d"))
		z.ignite(FLAME_BURN_SECONDS, z.max_health * FLAME_BURN_FRACTION)
		hit += 1
	player.fire()
	player.pulse_flame()
	# the cone also cooks whatever drop is in it, so auto-fire breaks crates and barrels
	for crate in crates:
		if not is_instance_valid(crate) or crate.is_queued_for_deletion():
			continue
		var cd: Vector3 = crate.global_position - origin
		cd.y = 0.0
		if cd.length() > FLAME_RANGE:
			continue
		if cd.length() > 0.4 and flat_fwd.dot(cd.normalized()) < cos(deg_to_rad(FLAME_HALF_ANGLE)):
			continue
		if crate.take_hit(FLAME_STRUCTURE_HITS):
			_break_crate(crate)
		hit += 1
	for barrel in barrels:
		if not is_instance_valid(barrel) or barrel.is_queued_for_deletion():
			continue
		var bd: Vector3 = barrel.global_position - origin
		bd.y = 0.0
		if bd.length() > FLAME_RANGE:
			continue
		if bd.length() > 0.4 and flat_fwd.dot(bd.normalized()) < cos(deg_to_rad(FLAME_HALF_ANGLE)):
			continue
		if barrel.take_hit(400.0):
			_explode(barrel)
		hit += 1
	sound.play("flame")
	if hit > 0:
		_burst(origin + flat_fwd_of(fwd) * 1.2, Color("ff9b35"), 3)
	return true

func flat_fwd_of(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()

func _fire() -> bool:
	if is_instance_valid(player) and player.vehicle in ["TANK","SEDAN","GOLD_CAR"]: return false  # cannon only / no guns in the car
	if not player.can_fire(): return false
	if player.weapon=="LAUNCHER": return _fire_launcher()
	if player.weapon=="FLAME": return _fire_flame()
	var sound_id: String=player.weapon.to_lower()
	if player.weapon=="PISTOL":
		var near_target:=is_instance_valid(aim_target) and _flat_distance(player.position,aim_target.position)<14.0
		sound_id="pistol_near" if near_target or not is_instance_valid(aim_target) else "pistol_far"
	player.fire(); sound.play(sound_id)
	var origin: Vector3=player.muzzle_position(); var base: Vector3=aim_direction.normalized()
	if is_instance_valid(aim_target) and not aim_target.dead and (zombies.has(aim_target) or watchers.has(aim_target) or barrels.has(aim_target) or crates.has(aim_target)):
		base=(aim_point-origin).normalized()
	var count: int=player.projectile_count
	for i in range(count):
		var b:=BulletScript.new(); b.position=origin; b.velocity=base.rotated(Vector3.UP,(i-(count-1)/2.0)*0.075)*player.bullet_speed
		b.damage=player.damage; b.pierce=player.pierce
		if player.crit_chance>0.0 and rng.randf()<player.crit_chance: b.damage*=player.crit_mult; b.set_meta("crit",true)
		# Shots aimed at the Banshee punch through two zombies in the way, so she can be reached.
		if is_instance_valid(aim_target) and zombies.has(aim_target) and aim_target.kind=="banshee": b.pierce+=2
		add_child(b); bullets.append(b)
	return true

func _fire_launcher() -> bool:
	if not player.can_fire(): return false
	if player.fire_mode and player.fire_ammo<=0: player.fire_mode=false
	var origin: Vector3=player.muzzle_position()
	var base: Vector3=aim_direction.normalized()
	if is_instance_valid(aim_target) and not aim_target.dead and (zombies.has(aim_target) or watchers.has(aim_target) or barrels.has(aim_target) or crates.has(aim_target)):
		base=(aim_point-origin).normalized()
	base.y=0.0
	if base.length()<0.1: base=aim_direction
	base=base.normalized()
	player.fire(); sound.play("shotgun")
	_spawn_ordnance("fire" if player.fire_mode else "launcher",origin,base*14.0+Vector3(0,3.0,0))
	if player.fire_mode:
		player.fire_ammo-=1
		if player.fire_ammo<=0: player.fire_mode=false
	shake=maxf(shake,0.24)
	return true

func toggle_fire_mode() -> bool:
	if player.weapon!="LAUNCHER" or player.fire_ammo<=0: return false
	player.fire_mode=not player.fire_mode
	sound.play("gate")
	_popup(player.position+Vector3(0,2.5,0),RunText.text("incendiary") if player.fire_mode else RunText.text("frag_mode"),Color("ff7547") if player.fire_mode else Color("ffd275"))
	return true

func _throw_ordnance(kind: String) -> bool:
	if state!="playing": return false
	if kind=="frag":
		if player.grenade_count<=0: return false
		player.grenade_count-=1
	elif kind=="flash":
		if player.flashbang_count<=0: return false
		player.flashbang_count-=1
	elif kind=="molotov":
		if player.molotov_count<=0: return false
		player.molotov_count-=1
	else: return false
	var origin: Vector3=player.position+Vector3(0,1.35,0)+aim_direction*0.65
	_spawn_ordnance(kind,origin,aim_direction*9.0+Vector3(0,4.2,0))
	sound.play("reload")
	return true

func _spawn_ordnance(kind: String,origin: Vector3,initial_velocity: Vector3) -> Node3D:
	var projectile:=OrdnanceScript.new()
	projectile.kind=kind; projectile.position=origin; projectile.velocity=initial_velocity
	add_child(projectile); ordnance.append(projectile)
	return projectile

func request_reload() -> bool:
	if player.request_reload():
		sound.play("reload"); return true
	return false

func _tick_bullets(delta: float) -> void:
	for i in range(bullets.size()-1,-1,-1):
		var b=bullets[i]; var prev: Vector3=b.position; b.tick(delta); var consumed:=false
		for z in zombies+watchers:
			if not is_instance_valid(z): continue
			var zp: Vector3=z.global_position
			# Hitscan on the aim line: once the bullet's flat (X-Z) distance is inside the
			# target, it hits — same rule as barrels (y<2.4). The old height check let
			# low targets (jockey, 1.05m) be shot over because the muzzle flies at ~1.35m.
			if not z.dead and not b.hit_targets.has(z) and b.position.y<2.30 and _swept_2d(prev,b.position,zp,z.radius+0.24):
				b.hit_targets.append(z); var hit_at: Vector3=b.position
				if b.has_meta("crit"): _popup(hit_at+Vector3(0,0.9,0),RunText.text("crit"),Color("ffd84a"))
				_hit_zombie(z,b.damage,_body_part(z,b.position),b.position)
				_on_bullet_hit(z,b,hit_at)
				if b.pierce>0: b.pierce-=1
				else: consumed=true
				break
		if not consumed:
			for crate in crates:
				if _swept_crate_hit(crate,prev,b.position):
					consumed=true
					if crate.take_hit(maxi(1,roundi(b.damage))): _break_crate(crate)
					break
		if not consumed:
			for barrel in barrels:
				if not barrel.dead and not b.hit_targets.has(barrel) and b.position.y<2.4 and _swept_2d(prev,b.position,barrel.position,barrel.radius+0.34):
					b.hit_targets.append(barrel)
					if barrel.take_hit(b.damage): _explode(barrel)
					consumed=true; break
		if consumed or b.life<=0 or b.position.z< -100 or b.position.z>16 or absf(b.position.x)>8:
			bullets.remove_at(i); b.queue_free()

func _flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

## A bullet covers up to a metre in one frame on a phone, so testing only the point it
## landed on could skip a barrel entirely between two frames - which read as "I aimed
## right at it and nothing happened". Test the whole step against the target circle.
func _swept_2d(from: Vector3,to: Vector3,center: Vector3,radius: float) -> bool:
	var ax:=from.x-center.x; var az:=from.z-center.z
	var dx:=to.x-from.x; var dz:=to.z-from.z
	var len2:=dx*dx+dz*dz
	var t:=0.0 if len2<0.000001 else clampf(-(ax*dx+az*dz)/len2,0.0,1.0)
	var cx:=ax+dx*t; var cz:=az+dz*t
	return cx*cx+cz*cz<=radius*radius

## The same sweep for the box-shaped platforms (weapon crates and rolling barrels).
func _swept_crate_hit(crate: Node3D,from: Vector3,to: Vector3) -> bool:
	if crate.bullet_hits(from): return true
	for i in range(1,7):
		if crate.bullet_hits(from.lerp(to,i/6.0)): return true
	return false

func _tick_ordnance(delta: float) -> void:
	for i in range(ordnance.size()-1,-1,-1):
		var projectile=ordnance[i]
		projectile.tick(delta)
		if projectile.kind in ["launcher","fire"] and not projectile.detonate_requested:
			for z in zombies:
				if not is_instance_valid(z) or z.dead: continue
				if projectile.position.y>0.0 and projectile.position.y<2.30 and _flat_distance(projectile.position,z.position)<z.radius+0.34:
					projectile.detonate_requested=true
					break
		if projectile.detonate_requested:
			_detonate_ordnance(projectile)
			ordnance.remove_at(i); projectile.queue_free()
		elif projectile.position.z< -70 or projectile.position.z>16 or absf(projectile.position.x)>10:
			ordnance.remove_at(i); projectile.queue_free()

## Molotov burn: identical numbers to the flamethrower so the two feel like one weapon family.
func _z_ignite_molotov(z: Node3D) -> void:
	_hit_zombie(z, FLAME_TICK_DAMAGE, "torso", z.position + Vector3(0, 1.0, 0), Color("ffb14d"))
	z.ignite(FLAME_BURN_SECONDS, z.max_health * FLAME_BURN_FRACTION)


func _detonate_ordnance(projectile: Node3D) -> void:
	var center: Vector3=projectile.position
	var kind: String=projectile.kind
	if kind=="molotov":
		# a burning pool: everything inside catches fire exactly like a flamethrower hit
		sound.play("explosion"); shake=maxf(shake,0.35)
		_burst(center,Color("ff9b35"),30); _fire_spray(center)
		var pool:=EffectScript.new(); pool.position=Vector3(center.x,0.06,center.z)
		pool.life=3.0; pool.total_life=3.0
		add_child(pool); pool.make_shockwave(Color(1.0,0.55,0.15,0.85),4.0); effects.append(pool)
		for z in zombies:
			if is_instance_valid(z) and not z.dead and _flat_distance(z.position,center)<4.5:
				_z_ignite_molotov(z)
		return
	if kind=="flash":
		sound.play("explosion"); shake=maxf(shake,0.5)
		_burst(center,Color("ffffff"),50); _blast_sphere(center,Color(0.85,0.96,1.0,0.95),2.2,false)
		_blast_sphere(center,Color(1,1,1,0.9),1.4,false)
		var ring:=EffectScript.new(); ring.position=Vector3(center.x,0.10,center.z); ring.life=0.55; ring.total_life=0.55
		add_child(ring); ring.make_shockwave(Color(0.85,0.96,1.0,0.95),1.4); effects.append(ring)
		var ring2:=EffectScript.new(); ring2.position=Vector3(center.x,0.10,center.z); ring2.life=0.7; ring2.total_life=0.7
		add_child(ring2); ring2.make_shockwave(Color(1,1,1,0.8),2.2); effects.append(ring2)
		for z in zombies:
			if is_instance_valid(z) and not z.dead and _flat_distance(z.position,center)<8.0:
				z.stun_timer=maxf(z.stun_timer,4.0)
		return
	sound.play("explosion"); shake=maxf(shake,0.85)
	_custom_explosion(center)
	_burst(center,Color("ffb14f"),26); _fire_spray(center)
	var radius := 4.5 if kind=="launcher" else 5.0
	if kind=="fire":
		radius=4.0
		_fire_spray(center)
		_blast_sphere(center,Color(1.0,0.20,0.035,0.58),0.95,false)
	for z in zombies.duplicate():
		if not is_instance_valid(z) or z.dead: continue
		if _flat_distance(z.position,center)<radius:
			if kind=="fire":
				z.burn_timer=maxf(z.burn_timer,5.0); z.burn_dps=24.0
				_hit_zombie(z,45.0,"torso",z.position+Vector3(0,1.0,0),Color("ff8a4f"))
			else:
				_hit_zombie(z,220.0 if kind=="frag" else player.damage,"torso",z.position+Vector3(0,1.0,0),Color("ffb15c"))
	for barrel in barrels.duplicate():
		if is_instance_valid(barrel) and not barrel.dead and _flat_distance(barrel.position,center)<radius and kind!="flash": _explode(barrel)
	if kind!="flash":
		for crate in crates:
			if not crate.broken and _flat_distance(crate.position,center)<radius and crate.take_hit(99999): _break_crate(crate)

## Spitter venom: a thick stream of vomit hosed at the survivor, not a single lobbed glob.
## It keeps coming for ~1.2 s, so standing still in it hurts and stepping aside dodges it.
func _start_venom_stream(z: Node3D) -> void:
	venom_streams.append({"z":z, "t":0.0, "dur":1.25, "aim":player.position+Vector3(0,0.9,0), "tick":0.0, "shown":false})

func _tick_venom(delta: float) -> void:
	if venom_streams.is_empty(): return
	for i in range(venom_streams.size()-1,-1,-1):
		var s: Dictionary=venom_streams[i]
		var z: Node3D=s["z"] as Node3D
		s["t"]=float(s["t"])+delta
		if not is_instance_valid(z) or float(s["t"])>float(s["dur"]):
			# the last of it lands: acid splash where it was aimed
			_venom_splash(s["aim"] as Vector3)
			venom_streams.remove_at(i)
			continue
		var mouth: Vector3=z.position+Vector3(0,1.52,-0.22)
		var aim: Vector3=s["aim"] as Vector3
		var dir: Vector3=(aim-mouth).normalized()
		# Thick, uneven, yellow-green: drops for the spray and small chunks for the body of it.
		for k in range(6):
			var wobble:=Vector3(randf_range(-0.5,0.5), randf_range(-0.25,0.55), randf_range(-0.2,0.2))
			var vel: Vector3=dir*randf_range(8.5,13.5)+wobble
			var hue: Color=Color("b9d94a").lerp(Color("6f9a1e"),randf())
			_fx_drop_at(mouth+Vector3(randf_range(-0.14,0.14),randf_range(-0.06,0.06),0),hue,
				randf_range(0.05,0.095),vel,-11.0,randf_range(0.32,0.52))
			if k<2:
				_fx_spark_at(mouth,hue.darkened(0.15),0.08,vel*0.85,-9.0,randf_range(0.3,0.45))
		s["tick"]=float(s["tick"])+delta
		if float(s["tick"])>=0.32:
			s["tick"]=0.0
			if _flat_distance(player.position,aim)<1.6 and revive_invulnerable<=0.0:
				_hurt_player(4.0)
				if not bool(s["shown"]):
					s["shown"]=true
					_popup(player.position+Vector3(0,2.3,0),RunText.text("venom"),Color("b9d94a"))

## Acid hitting the tarmac: green spray, a heavy pool and a little damage if you stand in it.
func _venom_splash(at: Vector3) -> void:
	_burst(at+Vector3(0,0.15,0),Color("a8ea4a"),20)
	_burst(at+Vector3(0,0.10,0),Color("4e8a1d"),14)
	_burst(at+Vector3(0,0.05,0),Color("2f5c12"),8)
	for k in range(10):
		_fx_drop_at(at+Vector3(randf_range(-0.5,0.5),0.1,randf_range(-0.4,0.4)),
			Color("8fbf35").lerp(Color("557c17"),randf()),randf_range(0.06,0.1),
			Vector3(randf_range(-2.2,2.2),randf_range(1.6,3.4),randf_range(-1.2,1.2)),-10.0,randf_range(0.4,0.7))
	shake=maxf(shake,0.18)
	if _flat_distance(player.position,at)<1.15 and revive_invulnerable<=0.0:
		_hurt_player(7.0)

func _tick_zombies(delta: float) -> void:
	for i in range(zombies.size()-1,-1,-1):
		var z=zombies[i]; z.tick(delta)
		if String(z.kind)=="spitter" and z.get("spit_ready")==true:
			z.set("spit_ready",false)
			if z.position.z<-2.0 and z.position.z>-34.0: _start_venom_stream(z as Node3D)
		var burn_damage: float=z.consume_burn_damage_number()
		if burn_damage>0.0: _damage_number(z,burn_damage,Color("ff8a4f"))
		if z.dead:
			_hit_zombie(z,0.0,"torso",z.position+Vector3(0,1.0,0))
			continue
		if z.consume_banshee_pulse():
			var ignited:=0
			for other in zombies:
				if other==z or not is_instance_valid(other) or other.dead or other.kind=="banshee": continue
				if _flat_distance(z.position,other.position)<=12.0:
					other.ignite(5.5,8.0,5.0)
					_burst(other.position+Vector3(0,1.0,0),Color("ff7138"),8)
					ignited+=1
			if ignited>0:
				_popup(z.position+Vector3(0,2.8,0),RunText.text("banshee_frenzy"),Color("ff8a4f"))
		_avoid_barrels(z,delta)
		_avoid_obstacles(z,delta)
		_avoid_crater(z,delta)
		if String(z.kind).begins_with("bomber") and _flat_distance(z.position,player.position)<1.7:
			# The bomber never melee-swings: close to the survivor it simply bursts. It used
			# to burst at 2.4 m, which is further than a pistol can drop it in the time it
			# needs to close, so it felt unkillable; 1.7 m gives the player the last shot.
			_hit_zombie(z,1e9,"torso",z.position+Vector3(0,1.0,0))
			continue
		if z.position.z>player.position.z-0.6 and z.position.z<player.position.z+0.8 and absf(z.position.x-player.position.x)<z.radius+0.38:
			if player.vehicle!="":
				# Riding: the survivor runs the zombie down instead of getting bitten.
				# _ram_zombie kills via _hit_zombie, which already erases and frees it.
				_ram_zombie(z)
			elif z.passive:
				# lobby walker: it just shuffles past, no bite
				continue
			else:
				_hurt_player(z.damage); _burst(z.position+Vector3(0,1,0),Color("91a85c"),8); zombies.remove_at(i); z.queue_free()
		elif z.position.z>13: zombies.remove_at(i); z.queue_free()
	_separate_zombies()

## Zombies only advance along +Z, so a fast one (jockey 7.4 m/s) used to walk
## straight through a slow one (banshee 1.65, brute 5.6) and the models overlapped.
## Resolve every pair as two circles: spread sideways first (that is what makes a
## horde), and when the kerb blocks the sideways move, stop the trailing one from
## overtaking - it queues up behind instead of clipping through.
func _separate_zombies() -> void:
	var count:=zombies.size()
	for i in range(count):
		var a=zombies[i]
		if not is_instance_valid(a) or a.dead: continue
		for j in range(i+1,count):
			var b=zombies[j]
			if not is_instance_valid(b) or b.dead: continue
			var dx: float=a.position.x-b.position.x
			var dz: float=a.position.z-b.position.z
			var min_dist: float=(a.radius+b.radius)+0.05
			var d2: float=dx*dx+dz*dz
			if d2>=min_dist*min_dist: continue
			var d: float=sqrt(maxf(d2,0.0001))
			var overlap: float=min_dist-d
			var nx: float=dx/d
			var nz: float=dz/d
			var half: float=overlap*0.5
			a.position.x=clampf(a.position.x+nx*half,-3.05,3.05)
			b.position.x=clampf(b.position.x-nx*half,-3.05,3.05)
			# The kerb may have eaten the sideways correction; take what is left along Z,
			# and only from the one further from the survivor (never shove him into a bite).
			var rx: float=a.position.x-b.position.x
			var rz: float=a.position.z-b.position.z
			var rd: float=sqrt(rx*rx+rz*rz)
			if rd>=min_dist: continue
			var need: float=min_dist-rd
			if a.kind=="banshee": b.position.z-=need
			elif b.kind=="banshee": a.position.z-=need
			elif a.position.z<=b.position.z: a.position.z-=need
			else: b.position.z-=need

func _avoid_barrels(z: Node3D,delta: float) -> void:
	for barrel in barrels:
		if not is_instance_valid(barrel) or barrel.dead: continue
		var dx: float=z.position.x-barrel.position.x
		var dz: float=z.position.z-barrel.position.z
		var clearance: float=z.radius+barrel.radius+0.08
		# Start steering early so the zombie walks around the barrel naturally.
		if absf(dz)<2.4 and absf(dx)<clearance+0.35:
			var side: float=_barrel_avoid_side(z,barrel)
			var urgency: float=1.0-clampf(absf(dz)/2.4,0.0,1.0)
			var steer_speed: float=maxf(2.0,z.speed*0.65)
			z.position.x=clampf(z.position.x+side*steer_speed*(0.45+urgency*0.55)*delta,-3.05,3.05)
			dx=z.position.x-barrel.position.x
		# Resolve any remaining contact instead of allowing visual overlap.
		var minimum: float=z.radius+barrel.radius
		if absf(dz)>=minimum: continue
		var needed_x: float=sqrt(maxf(0.0,minimum*minimum-dz*dz))+0.015
		if absf(dx)>=needed_x: continue
		var side: float=_barrel_avoid_side(z,barrel)
		var new_x: float=barrel.position.x+side*needed_x
		if new_x < -3.05 or new_x > 3.05:
			new_x=barrel.position.x-side*needed_x
		z.position.x=clampf(new_x,-3.05,3.05)

func _barrel_avoid_side(z: Node3D,barrel: Node3D) -> float:
	var dx: float=z.position.x-barrel.position.x
	var side: float=1.0 if dx>0.0 else -1.0
	if absf(dx)<=0.06:
		var left_room: float=barrel.position.x+3.05
		var right_room: float=3.05-barrel.position.x
		if absf(left_room-right_room)>0.1:
			side=-1.0 if left_room>right_room else 1.0
		else:
			side=-1.0 if int(z.get_instance_id())%2==0 else 1.0
	var clearance: float=z.radius+barrel.radius+0.12
	if side>0.0 and barrel.position.x+clearance>3.05: return -1.0
	if side<0.0 and barrel.position.x-clearance< -3.05: return 1.0
	return side

func _body_part(z: Node3D,hit_position: Vector3) -> String:
	var local:=hit_position-z.global_position
	var ratio: float=local.y/z.collision_height()
	var w: float=1.28*ZombieScript.BRUTE_SCALE if z.kind=="brute" else (0.88 if z.kind=="runner" else 1.0)
	var head_ratio:=0.64 if z.kind=="jockey" else 0.73
	if ratio>head_ratio: return "head"
	if ratio<0.37: return "leg_l" if local.x<0 else "leg_r"
	if absf(local.x)>0.30*w and ratio>0.43: return "arm_l" if local.x<0 else "arm_r"
	return "torso"

const DAMAGE_RED:=Color("ff3030")

func _hit_zombie(z: Node3D,amount: float,part:="torso",hit_position:=Vector3.ZERO,_damage_color:=Color("f4f0df")) -> void:
	if hit_position==Vector3.ZERO: hit_position=z.global_position+Vector3(0,1.2,0)
	var multiplier: float=1.55 if part=="head" else (0.88 if part.begins_with("leg") else 1.0)
	var actual_damage: float=minf(maxf(0.0,z.health),amount*multiplier)
	if actual_damage>0.0:
		_damage_number(z,actual_damage,DAMAGE_RED)
	if z.take_hit(amount*multiplier):
		# The kill creates a physical coin pile; coins are earned only on contact pickup.
		var reward: int=int(round(float(z.reward)*player.coin_mult))
		kills+=1; sound.play("kill")
		_roll_voucher_drop(z.global_position)
		_drop_coins(z.global_position,reward,String(z.kind))
		if player.kill_heal>0.0: player.health=minf(player.max_health,player.health+player.kill_heal*player.heal_scale())
		if player.drop_chance>0.0 and rng.randf()<player.drop_chance: _drop_pickup(z.global_position)
		_progress("kills",1)
		if z.kind in ["brute","banshee"]: _progress(String(z.kind)+"_kills",1)
		kill_counts[z.kind]=int(kill_counts.get(z.kind,0))+1
		var zp: Vector3=z.global_position
		if String(z.kind).begins_with("bomber"):
			_bomber_blast(zp)
		else:
			_blood_spray(hit_position,28 if part=="head" else 20); _burst(hit_position,Color("78935c"),5)
			_dismember(z,part)
			_blood_splatter(Vector3(zp.x,zp.y,zp.z),rng.randf_range(2.2,3.2)*(1.4 if z.kind=="brute" else 1.0),true)
		var roadside: bool=watchers.has(z)
		zombies.erase(z); watchers.erase(z)
		if roadside:
			# The watchers never move, so a fall reads perfectly and cannot slide.
			z.die()
			dying_zombies.append(z)
			get_tree().create_timer(1.15).timeout.connect(func():
				if is_instance_valid(z): z.queue_free())
		else:
			# Road zombies burst away: a body lying on the scrolling road either slides or
			# sinks into the tarmac, and the user asked for the blast look instead.
			z.queue_free()
	else:
		sound.play("hit"); _blood_spray(hit_position,7)
		if rng.randf()<0.5: _blood_splatter(Vector3(z.global_position.x,0.0,z.global_position.z),rng.randf_range(0.7,1.2),false)

## The bomber bursts in a shower of blood: huge spray, layered ground splatter, a shock
## blast, heavy damage to the survivor if it got close, and a chain reaction into the horde.
func _bomber_blast(zp: Vector3) -> void:
	shake=maxf(shake,0.8); sound.play("explosion")
	if OS.get_name()=="iOS": Input.vibrate_handheld(120,0.7)
	var center:=zp+Vector3(0,1.1,0)
	_blast_sphere(center,Color("8e1d12"),0.75,false)
	_blast_sphere(center,Color("3f0c06"),1.15,true)
	_blood_spray(center,48)
	_burst(center,Color("7a1a10"),26)
	_blood_splatter(Vector3(zp.x,0.0,zp.z),rng.randf_range(3.6,4.6),true)
	_blood_splatter(Vector3(zp.x,0.0,zp.z),rng.randf_range(2.2,3.2),true)
	if _flat_distance(player.position,zp)<2.9:
		# 50-70 damage: a hard hit that still leaves a full-health survivor standing.
		# The last point is always kept, so one bomber can never execute the player.
		var blast:=minf(rng.randf_range(50.0,70.0),maxf(0.0,player.health-1.0))
		if blast>=1.0: _hurt_player(blast)
	for z in zombies.duplicate():
		if is_instance_valid(z) and not z.dead and _flat_distance(z.position,zp)<3.2:
			_hit_zombie(z,120.0,"torso",z.position+Vector3(0,1.1,0),Color("ff8a5c"))

func _damage_number(z: Node3D,amount: float,_color: Color) -> void:
	_fx_label_at(z.global_position+Vector3(rng.randf_range(-0.24,0.24),2.78,rng.randf_range(-0.12,0.12)),
		"-%d"%maxi(1,roundi(amount)),DAMAGE_RED,Vector3(rng.randf_range(-0.16,0.16),1.05,0),0.78,true)

## Blood thrown away from the shooter: one directional splash (random shape out of eight,
## random size, angle jittered around the shot) plus flung droplets landing further along.
func _blood_splatter(pos: Vector3,size_m: float,kill: bool) -> void:
	var dir:=Vector3(aim_direction.x,0,aim_direction.z)
	if dir.length()<0.01: dir=Vector3.FORWARD
	dir=dir.normalized().rotated(Vector3.UP,rng.randf_range(-0.45,0.45))
	_spawn_blood_pool(pos+dir*size_m*0.25,size_m*rng.randf_range(0.85,1.15),11.0 if kill else 6.0,true,dir)
	if kill:
		for i in range(rng.randi_range(3,6)):
			var d:=dir.rotated(Vector3.UP,rng.randf_range(-0.6,0.6))
			_spawn_blood_pool(pos+d*rng.randf_range(0.9,2.8),rng.randf_range(0.18,0.5),9.0)

func _spawn_blood_pool(pos: Vector3,size_m: float,life: float,splash:=false,dir:=Vector3.ZERO) -> void:
	if blood_pools.size()>=MAX_BLOOD_POOLS:
		var oldest=blood_pools.pop_front()
		if is_instance_valid(oldest): oldest.disarm(); blood_free.append(oldest)
	var pool
	if blood_free.is_empty(): pool=BloodPoolScript.new(); add_child(pool)
	else: pool=blood_free.pop_back()
	# Tiny height steps stop overlapping pools from z-fighting on the road.
	# Sidewalk kills sit at y~0.16 — pool must sit on the pavement, not under it.
	var base_y: float=0.015 if pos.y<0.05 else pos.y+0.005
	pool.position=Vector3(pos.x,base_y+0.0008*(blood_pools.size()%12),pos.z)
	# Splash textures spray toward +U; turn that onto the spray direction. Droplets spin freely.
	pool.rotation.y=atan2(-dir.z,dir.x) if splash and dir!=Vector3.ZERO else rng.randf()*TAU
	pool.setup(size_m,rng.randi(),life,splash); blood_pools.append(pool)

func _tick_blood(delta: float) -> void:
	for i in range(blood_pools.size()-1,-1,-1):
		var pool=blood_pools[i]
		if pool.tick(delta):
			blood_pools.remove_at(i); pool.disarm(); blood_free.append(pool)

func _blood_spray(pos: Vector3,count: int) -> void:
	for i in range(count):
		_fx_drop_at(pos,Color("a5282c") if i%3 else Color("651b22"),rng.randf_range(0.045,0.105),
			aim_direction*rng.randf_range(1.0,3.8)+Vector3(rng.randf_range(-1.9,1.9),rng.randf_range(0.1,2.8),rng.randf_range(-0.8,0.8)),-6.5,rng.randf_range(0.45,0.85))

func _dismember(z: Node3D,part: String) -> void:
	var head: Array=["Head","Jaw","Brow","Brow.001","Cheek","Cheek.001","CrownLock","Ear","EyeSocket","EyeWhite","Fringe","HairMass","LowerLip","MouthCavity","NoseBridge","NoseTip","Pupil","Sideburn","Tooth"]
	var torso: Array=["Torso","ChestWound","ClothFold","CollarL","CollarR","Pocket","Rib","Tear"]
	var arm_l: Array=["ArmL","ElbowL","ForearmL","HandL","FingerL"]
	var arm_r: Array=["ArmR","ElbowR","ForearmR","HandR","FingerR"]
	var origin:=z.global_position+Vector3(0,1.05,0)
	_spawn_part(z.model,torso,origin,Vector3(rng.randf_range(-0.5,0.5),2.2,0.5))
	match part:
		"head":
			_spawn_part(z.model,head,origin,Vector3(0.7,4.2,-0.4)); _spawn_part(z.model,arm_l,origin,Vector3(-2.0,2.4,0.2)); _spawn_part(z.model,arm_r,origin,Vector3(2.0,2.6,-0.2))
		"arm_l": _spawn_part(z.model,arm_l,origin,Vector3(-3.0,3.1,0.3))
		"arm_r": _spawn_part(z.model,arm_r,origin,Vector3(3.0,3.1,0.3))
		"leg_l": _spawn_part(z.model,["LegL"],origin,Vector3(-2.2,2.5,0.4))
		"leg_r": _spawn_part(z.model,["LegR"],origin,Vector3(2.2,2.5,0.4))
		_:
			_spawn_part(z.model,head,origin,Vector3(0.3,3.7,-0.6)); _spawn_part(z.model,arm_l,origin,Vector3(-2.5,2.7,0.3)); _spawn_part(z.model,arm_r,origin,Vector3(2.5,2.7,-0.3))

func _spawn_part(source: Node3D,names: Array,pos: Vector3,force: Vector3) -> void:
	var e:=EffectScript.new(); e.position=pos; e.velocity=force; e.gravity=-7.5; e.life=1.25; e.total_life=e.life
	e.spin=Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-4,4)); add_child(e); e.make_part(source,names); effects.append(e)

func _hurt_player(amount: float) -> void:
	if revive_invulnerable>0.0: return
	_chase_stumble() # a hit is a stumble — the beast eats the lost ground
	if player.vehicle!="":
		# The bike soaks the hit: durability drops instead of health until it breaks apart.
		player.vehicle_durability-=amount
		_burst(player.position+Vector3(0,0.6,0.2),Color("ffb14d"),6)
		shake=maxf(shake,0.45); sound.play("hurt")
		if player.vehicle_durability<=0.0: _vehicle_breakdown()
		return
	var before: float=player.instinct_boost
	player.take_damage(amount); damage_flash=0.42; shake=0.75; sound.play("hurt")
	# Maya's adrenaline: her instinct flashes on screen when a fresh burst kicks in.
	if player.is_maya() and before<=0.5 and player.instinct_boost>before:
		_popup(player.position+Vector3(0,2.8,0),RunText.text("instinct"),Color("7fd2ff"))

## Running a zombie down on the bike: it dies (coins, kills, blood and all) but the
## impact wears the bike out — brutes and bombers cost far more than walkers.
func _ram_zombie(z: Node3D) -> void:
	# Ram power scales the wear: a harder-hitting vehicle (e.g. a future car) spends less
	# durability per zombie run down — it plows through more of them before breaking.
	var cost: float=float(BIKE_RAM_COST.get(String(z.kind),8.0))/player.vehicle_ram()
	var zp: Vector3=z.global_position
	# Knock-fly: blood burst + forward shockwave before the body is gone, so the hit
	# reads as the zombie flying off the vehicle, then dying into a blood pool.
	_blood_spray(zp+Vector3(0,1.0,0),18); _burst(zp+Vector3(0,0.8,0),Color("a5282c"),10)
	var ring:=EffectScript.new(); ring.position=Vector3(zp.x,0.10,zp.z); ring.life=0.35; ring.total_life=0.35
	add_child(ring); ring.make_shockwave(Color(1.0,0.6,0.3,0.8),0.7); effects.append(ring)
	_hit_zombie(z,1e9,"torso",zp+Vector3(0,1.0,0))
	# The golden bike shakes coins out of whatever it runs down: a second, gold pile
	# on top of the kill reward, so ramming always pays.
	if player.vehicle=="GOLD":
		_drop_coins(zp+Vector3(0,0,0.35),maxi(2,int(round(float(z.get("reward"))))),"brute")
	if player.vehicle=="GOLD_CAR":
		# gold sports car: everything it runs down pays five times
		_drop_coins(zp+Vector3(0,0,0.35),maxi(2,int(round(float(z.get("reward"))*5.0))),"brute")
	shake=maxf(shake,0.45 if player.vehicle in ["CRUISER","GOLD"] else 0.3)
	player.vehicle_durability-=cost
	if player.vehicle_durability<=0.0: _vehicle_breakdown()

func _vehicle_breakdown() -> void:
	# The bike dies under the survivor: sparks, black smoke, and they're running again.
	var center:=player.position+Vector3(0,0.55,0.15)
	_burst(center,Color("ffb14d"),14); _burst(center+Vector3(0,0.3,0),Color("3a3a38"),10)
	sound.play("explosion"); shake=maxf(shake,0.55)
	vehicle_auto_active=false
	player.dismount_vehicle()
	_popup(player.position+Vector3(0,2.5,0),RunText.text("bike_down"),Color("ffad72"))

## Wear and the warning smoke. Under 30 durability the engine coughs gray puffs and sparks.
var vehicle_smoke:=0.0
var cannon_cd:=0.0
var vehicle_dust:=0.0
func _tick_vehicle(delta: float) -> void:
	if player.vehicle=="": return
	# Bought bike: auto-ride only covers the opening stretch; step off at VEHICLE_AUTO_RANGE.
	if vehicle_auto_active and distance>=vehicle_range_end:
		vehicle_auto_active=false; player.dismount_vehicle(); sound.play("gate"); _popup(player.position+Vector3(0,2.5,0),RunText.text("bike_down"),Color("ffad72")); return
	# TANK: the cannon fires itself; each shell clears the lane ahead and
	# costs a chunk of durability, so roughly 6-8 shots wreck it.
	if player.vehicle=="TANK":
		cannon_cd-=delta
		if cannon_cd<=0.0:
			cannon_cd=CANNON_PERIOD
			_fire_cannon()
	player.vehicle_durability-=BIKE_DECAY*delta
	vehicle_dust-=delta
	if vehicle_dust<=0.0:
		vehicle_dust=0.05
		var d:=EffectScript.new(); d.position=player.position+Vector3(rng.randf_range(-0.22,0.22),0.08,0.75)
		d.velocity=Vector3(rng.randf_range(-0.5,0.5),rng.randf_range(0.6,1.5),rng.randf_range(2.4,3.8)); d.gravity=-1.2
		d.life=0.55; d.total_life=0.55; add_child(d)
		d.make_blast(Color("8a7f68"),rng.randf_range(0.05,0.12),true); effects.append(d)
	if player.vehicle_durability<30.0:
		vehicle_smoke-=delta
		if vehicle_smoke<=0.0:
			vehicle_smoke=0.14
			var e:=EffectScript.new(); e.position=player.position+Vector3(rng.randf_range(-0.12,0.12),0.5,0.55)
			e.velocity=Vector3(rng.randf_range(-0.4,0.4),1.7,rng.randf_range(0.3,0.9)); e.gravity=0.9
			e.life=0.7; e.total_life=0.7; add_child(e)
			e.make_spark(Color("ffb14d") if rng.randf()<0.3 else Color("5a5a58"),rng.randf_range(0.03,0.07)); effects.append(e)
	if player.vehicle_durability<=0.0: _vehicle_breakdown()

## Sidewalk watcher density grows with distance: 1 per even block at the start,
## up to 3 per block deep into the run. Refills any slot that was shot empty.
func _refresh_watcher(road: Node3D) -> void:
	var index: int=roads.find(road)
	if index<0 or index%2!=0: return
	var desired: int=1+mini(2,int(distance/1500.0))
	for k in range(desired):
		var key: String="watcher" if k==0 else "watcher_%d"%k
		var old=road.get_meta(key,null)
		if old!=null and is_instance_valid(old) and not old.dead: continue
		var w_rng:=RandomNumberGenerator.new(); w_rng.seed=rng.randi()
		watchers.append(DisasterDressing.spawn_watcher(road,index,ZombieScript,w_rng,key))

## Roadside zombies aren't statues: they turn to watch the survivor go by, and every few
## seconds do something: standing ones shuffle a few steps along the pavement, scratch, or
## sway and mutter; sitting ones lift their heads and gesture. Plays through the AnimationPlayer
## clips prepared in DisasterDressing.spawn_watcher.
func _tick_watchers(delta: float) -> void:
	for w in watchers:
		if not is_instance_valid(w) or w.dead: continue
		var anim: AnimationPlayer=w.animation_player
		# Skeleton animation is CPU work even when the model is culled, so freeze the
		# roadside watchers once they are far enough away that nobody can read them.
		if (w.global_position-player.global_position).length()>90.0:
			if anim and anim.speed_scale>0.0: anim.speed_scale=0.0
			continue
		if anim and anim.speed_scale<=0.0: anim.speed_scale=1.0
		var sitting: bool=w.get_meta("sitting",false)
		var base_yaw: float=w.get_meta("base_yaw",0.0)
		var gp: Vector3=w.global_position
		# Head-and-shoulders tracking: turn toward the survivor when they're close.
		var to_player:=player.global_position-gp
		var target_yaw: float=base_yaw
		if absf(to_player.z)<22.0:
			var look: float=atan2(to_player.x,to_player.z)
			target_yaw=base_yaw+clampf(wrapf(look-base_yaw,-PI,PI),-0.55 if sitting else -1.3,0.55 if sitting else 1.3)
		# Shuffling: walk a few steps along the pavement (road-local z), facing the way they go.
		var walk_left: float=w.get_meta("walk_left",0.0)
		if walk_left>0.0:
			var dir: float=w.get_meta("walk_dir",1.0)
			var step:=0.55*delta
			w.position.z+=dir*step; walk_left-=step; w.set_meta("walk_left",walk_left)
			target_yaw=0.0 if dir>0.0 else PI
			if walk_left<=0.0 and anim and anim.has_animation("ual_Idle"): anim.play("ual_Idle",0.4)
		w.model.rotation.y=lerp_angle(w.model.rotation.y,target_yaw,1.0-exp(-delta*(3.0 if walk_left>0.0 else 1.6)))
		var next_act: float=w.get_meta("next_act",3.0)-delta
		if next_act<=0.0 and walk_left<=0.0 and anim:
			next_act=rng.randf_range(3.5,7.5)
			var roll:=rng.randf()
			if sitting:
				var talk:="ual_Sitting_Talking" if anim.current_animation!="ual_Sitting_Talking" else "ual_Sitting_Idle"
				if anim.has_animation(talk): anim.play(talk,0.5)
			elif roll<0.45 and anim.has_animation("ual_Walk"):
				w.set_meta("walk_left",rng.randf_range(0.8,2.0)); w.set_meta("walk_dir",-1.0 if rng.randf()<0.5 else 1.0)
				anim.play("ual_Walk",0.35); anim.speed_scale=0.55
			elif roll<0.7 and anim.has_animation("Zombie_Scratch"):
				anim.play("Zombie_Scratch",0.3); anim.speed_scale=0.9
				next_act=rng.randf_range(2.0,3.0)
			elif anim.has_animation("ual_Idle_Talking"):
				anim.play("ual_Idle_Talking",0.4); anim.speed_scale=0.8
			elif anim.has_animation("ual_Idle"):
				anim.play("ual_Idle",0.4)
		w.set_meta("next_act",next_act)

func _pace() -> float:
	return clampf(run_time/180.0,0.0,1.0)

## True when nothing else (gate, crate, car/barrier, barrel) sits within `gap` metres of z,
## so road events arrive one at a time instead of piling up together.
func _road_clear(z: float,gap:=9.0) -> bool:
	for list in [gates,crates,obstacles,barrels]:
		for item in list:
			if is_instance_valid(item) and absf(item.position.z-z)<gap: return false
	return true

func _spawn_gate() -> void:
	# Never drop a gate on top of cars, barriers or weapon crates: try again a moment later.
	for o in obstacles:
		if is_instance_valid(o) and absf(o.position.z-(-40.0))<o.half_extents.y+3.0: gate_timer=1.0; return
	for c in crates:
		if is_instance_valid(c) and absf(c.position.z-(-40.0))<3.0: gate_timer=1.0; return
	var opts: Array=_roll_gate_options()
	new_gate_index+=1
	var gate:=GateScript.new(); gate.position=Vector3(0,0,-40); gate.setup(opts,language_code); add_child(gate); gates.append(gate)
	var best:=0
	for o in opts: best=maxi(best,int(o.rarity))
	if best>=2: sound.play("gate") # an epic or legendary gate announces itself

## Roguelike gate roll. Most buffs are common and small; rare, epic and legendary ones are
## increasingly unlikely and much stronger. Two choices early on, three past THREE_GATE_DISTANCE.
## Pity: after PITY_GATES gates without an epic or better, one is guaranteed.
const THREE_GATE_DISTANCE:=500.0
const PITY_GATES:=8
const RARITY_WEIGHTS:=[64.0,25.0,9.0,2.0]
var gates_since_epic:=0

func _roll_rarity() -> int:
	var w: Array=RARITY_WEIGHTS.duplicate()
	var late: float=clampf(distance/1500.0,0.0,1.0) # a little luckier deeper into a run
	w[2]+=3.0*late; w[3]+=2.0*late
	var total:=0.0
	for x in w: total+=x
	var r:=rng.randf()*total
	for i in range(w.size()):
		r-=w[i]
		if r<=0.0: return i
	return 0

func _gate_option(id: String,rarity: int) -> Dictionary:
	var v: float=BuffCatalog.value_of(id,rarity)
	return {"id":id,"rarity":rarity,"value":v,"label":BuffCatalog.label(language_code,id,v),
		"title":BuffCatalog.label("en",id,v)[0],"detail":BuffCatalog.label("en",id,v)[1]}

## Never offer a buff that would do nothing right now (or is already at its cap).
func _buff_useful(id: String,rarity: int) -> bool:
	if rarity<int(BuffCatalog.BUFFS[id].min): return false
	match id:
		"heal": return player.health<player.max_health*0.9
		"crit_damage": return player.crit_chance>0.0
		"crit_chance": return player.crit_chance<0.6
		"reserve": return player.can_use_reserve()
		"dmg_reduce": return player.dmg_reduce<0.6
		"move": return player.move_mult<1.4
		"reload": return player.reload_scale>0.3
		"shield": return player.shield<200.0
		"explode": return player.explode_chance<0.6
		"shock": return player.shock_chance<0.6
		"ammo_return": return player.ammo_return<0.6
		"drop": return player.drop_chance<0.4
		"multishot": return player.projectile_count<(9 if player.weapon=="SHOTGUN" else 5)
	return true

func _roll_gate_options() -> Array:
	# The very first gate is always the plain damage / fire-rate pair, to teach the idea.
	if new_gate_index==0: return [_gate_option("damage",0),_gate_option("rate",0)]
	var count:=3 if distance>=THREE_GATE_DISTANCE else 2
	var opts:=[]; var used:={}
	for k in range(count):
		var rarity:=_roll_rarity()
		var ids: Array=BuffCatalog.BUFFS.keys().filter(func(i): return not used.has(i) and _buff_useful(i,rarity))
		if ids.is_empty(): ids=["damage","rate"].filter(func(i): return not used.has(i))
		if ids.is_empty(): ids=["damage"]
		var id: String=ids[rng.randi_range(0,ids.size()-1)]
		used[id]=true; opts.append(_gate_option(id,rarity))
	var best:=0
	for o in opts: best=maxi(best,int(o.rarity))
	if best>=2: gates_since_epic=0
	else:
		gates_since_epic+=1
		if gates_since_epic>=PITY_GATES:
			var k:=rng.randi_range(0,opts.size()-1)
			var forced:=3 if rng.randf()<0.25 else 2
			var id2: String=opts[k].id if _buff_useful(String(opts[k].id),forced) else "damage"
			opts[k]=_gate_option(id2,forced); gates_since_epic=0
	return opts

## ---- Gate buff effects ---------------------------------------------------------------------
## Called after a bullet hits a zombie (the zombie may already be dead and freed).
func _on_bullet_hit(z: Node3D,b: Node3D,at: Vector3) -> void:
	var p=player
	if p.ammo_return>0.0 and rng.randf()<p.ammo_return and p.ammo<p.magazine_size: p.ammo+=1
	if b.has_meta("fragment"): return # fragments don't chain further
	var alive: bool=is_instance_valid(z) and not z.dead
	if alive and p.burn_dps>0.0: z.set_meta("burn",[p.burn_dps,2.5])
	if alive and p.poison_dps>0.0: z.set_meta("poison",[p.poison_dps,5.0])
	if p.explode_chance>0.0 and rng.randf()<p.explode_chance:
		_burst(at,Color("ffb347"),10); shake=maxf(shake,0.18)
		for o in zombies.duplicate():
			if is_instance_valid(o) and not o.dead and o!=z and _flat_distance(o.position,at)<1.8: _hit_zombie(o,b.damage*0.6)
	if p.shock_chance>0.0 and rng.randf()<p.shock_chance:
		var arcs:=0
		for o in zombies.duplicate():
			if arcs>=2: break
			if is_instance_valid(o) and not o.dead and o!=z and _flat_distance(o.position,at)<3.2:
				_burst(o.global_position+Vector3(0,1.2,0),Color("8fd8ff"),6); _hit_zombie(o,b.damage*0.5); arcs+=1
	if p.bullet_split>0:
		var dir: Vector3=b.velocity.normalized()
		for i in range(p.bullet_split):
			var f:=BulletScript.new(); f.position=at+dir*0.3
			var ang: float=(i-(p.bullet_split-1)/2.0)*0.55+(0.35 if p.bullet_split==1 else 0.0)
			f.velocity=dir.rotated(Vector3.UP,ang)*p.bullet_speed*0.8; f.damage=b.damage*0.4; f.pierce=0
			f.set_meta("fragment",true); if is_instance_valid(z): f.hit_targets.append(z)
			add_child(f); bullets.append(f)

## Movement-speed buff: everything on the road also slides toward the survivor faster, by the
## amount the run speed exceeds the normal 3.5 m/s (zombies included, so they keep pace).
func _scroll_extra(delta: float) -> void:
	var extra: float=(player.effective_move_mult()-1.0)*3.5*delta
	if extra<=0.0: return
	for list in [zombies,barrels,crates,gates,pickups,obstacles,blood_pools]:
		for n in list:
			if is_instance_valid(n): n.position.z+=extra

## Per-frame buffs: health regen and burning / poisoned zombies (damage applied twice a second).
var buff_tick:=0.0
func _tick_buffs(delta: float) -> void:
	if player.regen>0.0: player.health=minf(player.max_health,player.health+player.regen*player.heal_scale()*delta)
	# Maya's field instinct: slow self-repair while she is below 60% health.
	var instinct: float=player.instinct_regen_rate()
	if instinct>0.0: player.health=minf(player.max_health*player.INSTINCT_REGEN_CAP,player.health+instinct*delta)
	buff_tick+=delta
	if buff_tick<0.5: return
	var step:=buff_tick; buff_tick=0.0
	for z in zombies.duplicate():
		if not is_instance_valid(z) or z.dead: continue
		var dmg:=0.0
		for key in ["burn","poison"]:
			if not z.has_meta(key): continue
			var st: Array=z.get_meta(key)
			dmg+=float(st[0])*minf(step,float(st[1])); st[1]=float(st[1])-step
			if float(st[1])<=0.0: z.remove_meta(key)
			else: z.set_meta(key,st)
		if dmg>0.0:
			_burst(z.global_position+Vector3(0,1.1,0),Color("ff7a2e") if z.has_meta("burn") else Color("8fe35a"),3)
			_hit_zombie(z,dmg)

## Coin quality by zombie: heavies (brute / bomber / banshee) drop a gold pile,
## everything ordinary drops a silver pile. Both add to the same run_coins wallet.
const GOLD_COIN_KINDS:=["brute","banshee","bomber","bomber_female"]

func _drop_coins(at: Vector3,amount: int,zombie_kind: String) -> void:
	var pickup:=PickupScript.new()
	# riding the golden bike converts every drop to gold - never silver, never both
	var as_gold: bool=(zombie_kind in GOLD_COIN_KINDS) or (is_instance_valid(player) and player.vehicle in ["GOLD","GOLD_CAR"])
	pickup.kind="coin" if as_gold else "silver_coin"
	pickup.value=maxi(1,amount); pickup.source_kind=zombie_kind
	pickup.position=Vector3(clampf(at.x,-2.75,2.75),0,at.z); add_child(pickup); pickups.append(pickup)

## A kill can drop a pickup where the zombie fell (drop-chance buff).
func _drop_pickup(at: Vector3) -> void:
	var kinds:=["medkit","ammo","grenade"]
	if player.weapon=="PISTOL" and player.stowed.is_empty(): kinds=["medkit","grenade"]
	var pickup:=PickupScript.new(); pickup.kind=kinds[rng.randi_range(0,kinds.size()-1)]
	pickup.position=Vector3(clampf(at.x,-2.6,2.6),0,at.z); add_child(pickup); pickups.append(pickup)

func _tick_gates(delta: float) -> void:
	for i in range(gates.size()-1,-1,-1):
		var g=gates[i]; g.tick(delta)
		# Resolve as soon as the gate reaches the survivor. Requiring it to have been behind
		# at the start of the frame lost buffs on vehicles: _scroll_extra pushes gates forward
		# after this check, so a gate could step past the player between two frames and then
		# never resolve again.
		if not g.resolved and g.position.z>=player.position.z:
			var choice: Dictionary=g.choose(player.position.x)
			if not choice.is_empty():
				player.apply_upgrade(choice.id,float(choice.get("value",-1)))
				sound.play("gate")
				var taken: String=String(choice.label[1]) if choice.has("label") else String(choice.detail)
				# One confirmation only: the floating line above the head, like a coin pickup.
				_popup(player.position+Vector3(0,2.6,0),taken,g.chosen_color().lightened(0.3))
		if g.fade<=0 or g.position.z>14: gates.remove_at(i); g.queue_free()

func _spawn_barrel() -> void:
	var x:=rng.randf_range(-2.7,2.7)
	for attempt in range(8):
		if not _x_blocked_by_banshee(x,0.45): break
		x=rng.randf_range(-2.7,2.7)
	if _x_blocked_by_banshee(x,0.45): return # no room this time; skip rather than overlap her
	var barrel:=BarrelScript.new(); barrel.position=Vector3(x,0,-45); add_child(barrel); barrels.append(barrel)

## Crate health, shown on the crate. Each bullet takes off its real damage, so the number reads
## like a health bar: 105 with 33-damage bullets breaks in 4 shots. Sized from the current gun so
## a crate always takes about 3-8 shots (a little more late in a run / for better guns).
func _crate_shots(id: String) -> float:
	# A dog is worth more than a gun: its platform takes 5-10 shots instead of 3-8.
	if id.begins_with("PET_"): return clampf((5.0+run_time*0.03)*1.0,5.0,10.0)
	return clampf((3.0+run_time*0.025)*float(CRATE_TIER.get(id,1.0)),3.0,8.0)

func _crate_per_shot() -> float:
	return player.damage*maxf(1.0,player.projectile_count*0.6)

func _crate_hits(id: String) -> int:
	return maxi(10,int(round(_crate_per_shot()*_crate_shots(id)/5.0))*5)

## Crate health follows the gun in hand: if the survivor loses a strong gun (or picks one up),
## the remaining health is rescaled so it still takes the same number of shots to break.
func _rescale_crate(c: Node3D) -> void:
	if not c.has_meta("shots"): c.set_meta("shots",_crate_shots(String(c.weapon_id)))
	var full: int=maxi(10,int(round(_crate_per_shot()*float(c.get_meta("shots"))/5.0))*5)
	if full==int(c.max_hits): return
	var left: int=maxi(1,int(ceil(float(c.hits_left)/maxf(1.0,float(c.max_hits))*full)))
	c.max_hits=full; c.hits_left=left; c._refresh_counter()

func _crate_spot_clear(x: float,z: float) -> bool:
	if _x_blocked_by_banshee(x,0.75): return false
	for o in obstacles:
		if is_instance_valid(o) and absf(o.position.z-z)<o.half_extents.y+2.2 and absf(o.position.x-x)<o.half_extents.x+1.0: return false
	for b in barrels:
		if is_instance_valid(b) and absf(b.position.z-z)<2.2 and absf(b.position.x-x)<1.3: return false
	for g in gates:
		if is_instance_valid(g) and absf(g.position.z-z)<3.5: return false
	return true

func _spawn_crates() -> void:
	var choices: Array=CRATE_WEAPONS.duplicate(); choices.erase(player.weapon)
	choices.shuffle()
	var z:=-46.0
	# always one platform on the left and one on the right, never a cluster
	var spots: Array=[-1.7,1.7]
	var used:=0
	var dog_spot:=-1
	_cleanup_companions()
	if companion_pets.size()<MAX_COMPANION_PETS and rng.randf()<PET_CRATE_CHANCE: dog_spot=rng.randi_range(0,spots.size()-1)
	for si in range(spots.size()):
		var x: float=spots[si]
		if not _crate_spot_clear(x,z): continue
		var crate:=WeaponCrateScript.new(); var id: String=choices[used%choices.size()]; used+=1
		if si==dog_spot: id="PET_%d"%rng.randi_range(0,lobby.PETS.size()-1)
		elif (player.vehicle!="" or player.weapon=="FLAME") and rng.randf()<FUEL_CRATE_CHANCE:
			id="FUEL"
		elif rng.randf()<GEAR_CRATE_CHANCE:
			var gear:=[]
			if not player.has_helmet: gear.append("HELMET")
			if not player.has_armor: gear.append("ARMOR")
			if not gear.is_empty(): id=gear[rng.randi_range(0,gear.size()-1)]
		elif player.vehicle=="" and rng.randf()<BIKE_CRATE_CHANCE: id="BIKE"
		elif player.vehicle=="" and rng.randf()<0.06: id="SPORT"
		elif player.vehicle=="" and rng.randf()<0.06: id="CRUISER"
		elif player.vehicle=="" and rng.randf()<0.06: id="SEDAN"
		crate.setup(id,_crate_hits(id)); crate.position=Vector3(x,0,z); add_child(crate); crates.append(crate)

## ---- Rolling reward barrels --------------------------------------------------------------
## A wave of up to three barrels rolls down the road, each carrying a pet / weapon / vehicle
## that turns slowly above it and a hit counter on its front face. They are 0.9 m wide and
## the lanes are 2.4 m apart, so even three at once leave a 1.5 m gap between each pair: the
## road is never walled off, there is always somewhere to slip through.
const ROLLER_LANES:=[-2.4,0.0,2.4]

func _spawn_rollers() -> void:
	var alive:=0
	for c in crates:
		if is_instance_valid(c) and c.has_method("is_roller") and not c.broken: alive+=1
	if alive>=2: return                     # never more than two rolling at once
	var want:=mini(2-alive,rng.randi_range(1,2))
	var xs: Array=[]
	var lanes: Array=ROLLER_LANES.duplicate()
	lanes.shuffle()
	var tries:=0
	while xs.size()<want and tries<16:
		tries+=1
		var x: float=float(lanes[rng.randi_range(0,lanes.size()-1)])+rng.randf_range(-0.28,0.28)
		var ok: bool=absf(x)<2.9
		for other in xs:
			if absf(x-float(other))<2.0: ok=false   # keep a passable gap between them
		if ok: xs.append(x)
	for x in xs:
		if not _crate_spot_clear(x,-48.0): continue
		var clash:=false
		for c in crates:
			if is_instance_valid(c) and absf(c.position.x-x)<1.3 and absf(c.position.z-(-48.0))<4.0: clash=true; break
		if clash: continue
		var id:=_roller_id()
		var barrel:=BarrelRollScript.new()
		barrel.setup(id,_crate_hits(id))
		barrel.position=Vector3(x,0,-48.0)
		add_child(barrel); crates.append(barrel)
## Pets, weapons and the paid bikes can ride a barrel. The tank never does.
func _roller_id() -> String:
	var roll:=rng.randf()
	if roll<0.20:
		return "PET_%d"%rng.randi_range(0,lobby.PETS.size()-1)
	if roll<0.50 and player.vehicle=="":
		var v: Array=["BIKE","SPORT","CRUISER","SEDAN"]
		return String(v[rng.randi_range(0,v.size()-1)])
	var choices: Array=CRATE_WEAPONS.duplicate(); choices.erase(player.weapon)
	return String(choices[rng.randi_range(0,choices.size()-1)])

func _break_crate(crate: Node3D) -> void:
	sound.play("pickup"); shake=maxf(shake,0.35)
	var center: Vector3=crate.position+Vector3(0,0.55,0)
	_burst(center,Color("8a6a3c"),16); _burst(center+Vector3(0,0.6,0),Color("6cc8ff"),10)
	if String(crate.weapon_id).begins_with("PET_"):
		# A dog on the platform: freed, it runs with the survivor for the rest of this run.
		# Up to MAX_COMPANION_PETS can follow; past that the crate pays a small coin bonus.
		var recruited:=_recruit_pet(int(String(crate.weapon_id).trim_prefix("PET_")),crate.position)
		crate.arrived=true; sound.play("gate")
		if recruited:
			_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("ffd27a"))
		else:
			run_coins+=15
			_popup(player.position+Vector3(0,2.5,0),"4 DOGS MAX  +15",Color("ffd27a"))
		return
	if crate.weapon_id=="ARMOR":
		player.set_armor(true); player.shield=minf(200.0,player.shield+50.0); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("72d9e5")); return
	if crate.weapon_id=="HELMET":
		player.set_helmet(true); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("b6d38a")); return
	if crate.weapon_id=="BIKE":
		# The motorcycle rolls off the platform and the survivor swings into the saddle.
		player.mount_vehicle("BIKE"); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("ffd27a")); return
	if crate.weapon_id=="SPORT":
		player.mount_vehicle("SPORT"); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("ffd27a")); return
	if crate.weapon_id=="CRUISER":
		player.mount_vehicle("CRUISER"); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("ffd27a")); return
	if crate.weapon_id=="FUEL":
		_refuel(); sound.play("gate")
		return
	if crate.weapon_id=="SEDAN":
		player.mount_vehicle("SEDAN"); sound.play("gate")
		_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("ffd27a")); return
	# Swap immediately on break; the flying gun is only the visual of it landing in your hands.
	player.stowed={}; player.set_weapon(crate.weapon_id); sound.play("gate")
	_popup(player.position+Vector3(0,2.5,0),crate.display_name(),Color("7fd2ff"))

## Fuel can: refills whatever is carrying the player. On a vehicle it resets the tank (so the
## remaining range becomes a full VEHICLE_AUTO_RANGE again, never stacked on top of it); on foot
## with the flamethrower it refills the fuel instead.
func _refuel() -> void:
	if player.vehicle != "":
		player.vehicle_durability = 100.0
		vehicle_range_end = distance + VEHICLE_AUTO_RANGE
		_popup(player.position+Vector3(0,2.5,0),"油箱加满" if String(language_code).begins_with("zh") else "FUEL: FULL",Color("ffb14d"))
	elif player.weapon == "FLAME":
		player.ammo = player.magazine_size
		player.reserve_ammo = mini(player.reserve_ammo + 100, player.magazine_size * 3)
		_popup(player.position+Vector3(0,2.5,0),"燃料 +100" if String(language_code).begins_with("zh") else "FLAME FUEL +100",Color("ff9b35"))
	else:
		run_coins += 15
		_popup(player.position+Vector3(0,2.5,0),"+15",Color("ffd27a"))

## Fallen bodies ride the scrolling road exactly like obstacles do, otherwise the corpse
## appears to skate backwards while the tarmac moves under it.
func _tick_dying_zombies(delta: float) -> void:
	if dying_zombies.is_empty(): return
	var step: float=3.5*(player.effective_move_mult() if is_instance_valid(player) else 1.0)*delta
	for i in range(dying_zombies.size()-1,-1,-1):
		var body=dying_zombies[i]
		if not is_instance_valid(body): dying_zombies.remove_at(i); continue
		body.position.z+=step
		if body.position.z>14.0: dying_zombies.remove_at(i); body.queue_free()

func _tick_crates(delta: float) -> void:
	var hand: Vector3=player.position+Vector3(0,1.25,0.1)
	for i in range(crates.size()-1,-1,-1):
		var c=crates[i]; c.tick(delta,hand)
		# A rolling barrel is solid: it hurts like a wreck or a crater, then rolls on.
		if c.has_method("is_roller") and not c.broken:
			c.contact_tick(delta)
			if c.hit_cooldown<=0.0 and c.touches(player.position):
				c.hit_cooldown=1.2
				_hurt_player(c.contact_damage)
				shake=maxf(shake,0.4)
				_burst(player.position+Vector3(0,0.55,0),Color("c8a06a"),8)
		if not c.broken: _rescale_crate(c)
		# Crates are not solid: the runner can run straight through them.
		if c.arrived or (c.broken and c.flight>1.5):
			crates.remove_at(i); c.queue_free(); continue
		if not c.broken and c.position.z>13: crates.remove_at(i); c.queue_free()

## Wood splinters, dust and a short camera kick when a vehicle ploughs a crate or a barrel.
## Generic "it came apart": duplicate the prop's own body and throw it, so any model breaks
## (the rolling barrel keeps its shell under "body"; its mesh names are generated garbage).
func _fly_apart(target: Node3D) -> void:
	var src: Node3D=target.get("body") as Node3D
	if not is_instance_valid(src): src=target.get("model") as Node3D
	if not is_instance_valid(src): src=target
	var shell: Node3D=src.duplicate() as Node3D
	if shell==null: return
	shell.transform=Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var center: Vector3=target.global_position+Vector3(0,0.5,0)
	var e:=EffectScript.new()
	e.mode="part"
	e.position=center
	e.velocity=Vector3(rng.randf_range(-1.6,1.6), rng.randf_range(2.6,4.0), rng.randf_range(-0.8,1.4))
	e.gravity=-9.0; e.life=1.2; e.total_life=1.2
	e.spin=Vector3(rng.randf_range(-5,5), rng.randf_range(-4,4), rng.randf_range(-5,5))
	e.add_child(shell)
	add_child(e)
	effects.append(e)

func _smash_wood(at: Vector3) -> void:
	var p: Vector3=at+Vector3(0,0.62,0)
	_burst(p,Color("8a6a3f"),24)   # splintered planks
	_burst(p,Color("d8b070"),12)   # pale inner wood
	_burst(p,Color("2a2118"),8)    # dirt and shadow
	shake=maxf(shake,0.34)
	if is_instance_valid(sound): sound.play("pickup")

## Whatever a vehicle drives through is harvested on contact: a platform hands over its
## weapon / pet / vehicle and a barrel spills its item, both with the wood smash.
func _vehicle_smash() -> void:
	if not is_instance_valid(player) or player.vehicle=="": return
	# Only what is actually under the body counts: the saloon is 4 m long, the tank ~2.4 m.
	# The old box reached 1.3 m behind the player and two lanes wide, which hoovered items
	# up before the car touched them.
	var half_width: float=0.90 if player.vehicle=="SEDAN" else 0.62
	var front: float=-3.72 if player.vehicle=="SEDAN" else -1.32
	var rear: float=0.24
	for c in crates.duplicate():
		if not is_instance_valid(c) or c.broken: continue
		# Real box overlap with the platform's own footprint, not a magic radius.
		var cw: float=float(c.half_extents.x); var cd: float=float(c.half_extents.y)
		if absf(c.position.x-player.position.x)>half_width+cw: continue
		if c.position.z+cd<front or c.position.z-cd>rear: continue
		if c.has_method("is_roller"):
			# Rolling barrel: the shell is thrown apart and the item is collected at once,
			# so nothing is left on the road to look like it rolls backwards.
			_smash_wood(c.position); _fly_apart(c); _break_crate(c)
		else:
			_smash_wood(c.position)
			if c.take_hit(99999): _break_crate(c)
	for b in barrels.duplicate():
		if not is_instance_valid(b) or b.dead: continue
		if absf(b.position.x-player.position.x)>half_width+0.30: continue
		if b.position.z+0.30<front or b.position.z-0.30>rear: continue
		# An explosive barrel is explosive: ramming it sets it off for real. The blast hits
		# the vehicle's durability first, so the car survives a hit the survivor would not.
		barrels.erase(b)
		_explode(b)
		return

func _tick_barrels(delta: float) -> void:
	for i in range(barrels.size()-1,-1,-1):
		var b=barrels[i]
		if b.dead: barrels.remove_at(i); b.queue_free(); continue
		b.position.z += world_speed * delta
		b.tick(delta)
		if b.position.z>13: barrels.remove_at(i); b.queue_free()

func _resolve_barrel_collision() -> void:
	for barrel in barrels:
		if not is_instance_valid(barrel) or barrel.dead: continue
		var dz: float=player.position.z-barrel.position.z
		var minimum: float=barrel.radius+0.40
		if absf(dz)>=minimum or absf(player.position.x-barrel.position.x)>=minimum: continue
		var clearance: float=sqrt(maxf(0.0,minimum*minimum-dz*dz))+0.025
		var left: float=clampf(barrel.position.x-clearance,-3.15,3.15)
		var right: float=clampf(barrel.position.x+clearance,-3.15,3.15)
		var new_x: float=left if absf(player.position.x-left)<absf(player.position.x-right) else right
		if absf(new_x-barrel.position.x)<clearance-0.02:
			new_x=right if new_x==left else left
		player.position.x=new_x; player.target_x=new_x

## Live z of district 14's missile crater (the tile scrolls with the city). INF when the
## crater tile is not built. The 0.25 is the crater's offset inside its district mesh.
func _crater_z() -> float:
	for i in range(roads.size()):
		if i%24==14: return roads[i].position.z-0.25
	return INF

## The crater is a hole, not a decal: the survivor is shoved around its nearest rim.
func _resolve_crater_collision() -> void:
	var cz: float=_crater_z()
	if cz==INF: return
	if player.vehicle=="SEDAN": return   # drives over the crater lip
	var dz: float=player.position.z-cz
	var minimum: float=CRATER_RADIUS+0.32
	if absf(dz)>=minimum or absf(player.position.x-CRATER_X)>=minimum: return
	var clearance: float=sqrt(maxf(0.0,minimum*minimum-dz*dz))+0.025
	var left: float=clampf(CRATER_X-clearance,-3.15,3.15)
	var right: float=clampf(CRATER_X+clearance,-3.15,3.15)
	var new_x: float=left if absf(player.position.x-left)<absf(player.position.x-right) else right
	if absf(new_x-CRATER_X)<clearance-0.02:
		new_x=right if new_x==left else left
	player.position.x=new_x; player.target_x=new_x

## Zombies know better than to wade into the blast hole: they pick the nearer rim early,
## and a hard rim constraint keeps the stragglers out of the pit itself.
func _avoid_crater(z: Node3D,delta: float) -> void:
	var cz: float=_crater_z()
	if cz==INF: return
	var dz: float=z.position.z-cz
	var clearance: float=CRATER_RADIUS+z.radius+0.10
	if absf(dz)>=clearance+1.8: return
	var dx: float=z.position.x-CRATER_X
	if absf(dx)<clearance+0.45:
		var side: float=(1.0 if dx>=0.0 else -1.0) if absf(dx)>0.05 else 1.0
		var urgency: float=1.0-clampf(absf(dz)/(clearance+1.8),0.0,1.0)
		var steer: float=maxf(2.0,z.speed*0.7)
		z.position.x=clampf(z.position.x+side*steer*(0.45+urgency*0.55)*delta,-3.05,3.05)
	if absf(dz)<clearance:
		var push: float=sqrt(maxf(0.0,clearance*clearance-dz*dz))+0.02
		var dx2: float=z.position.x-CRATER_X
		if absf(dx2)<push:
			var l: float=clampf(CRATER_X-push,-3.05,3.05)
			var r: float=clampf(CRATER_X+push,-3.05,3.05)
			z.position.x=l if absf(dx2+push)<absf(dx2-push) else r

func _spawn_obstacle(kind: String,lane_x: float,at_z: float=-48.0,crosswise: bool=false,damage_tier_override: int=-1) -> Node3D:
	var obstacle:=RoadObstacleScript.new()
	obstacle.kind=kind
	obstacle.police_crosswise=crosswise and kind=="police"
	if kind=="car":
		if damage_tier_override>=0:
			obstacle.damage_tier=damage_tier_override
		else:
			# Damage belongs to a district: intact areas keep more usable cars,
			# while rundown districts contain more stripped and burnt-out shells.
			var district: int=int(distance/16.0)%24
			var severity: float=[0.10,0.20,0.42,0.78,0.34,0.58][district/4]
			var roll: float=rng.randf()
			if roll<severity*0.32: obstacle.damage_tier=3
			elif roll<severity: obstacle.damage_tier=2
			elif roll<minf(0.95,severity+0.25): obstacle.damage_tier=1
			else: obstacle.damage_tier=0
	obstacle.position=Vector3(lane_x,0,at_z)
	add_child(obstacle)
	obstacles.append(obstacle)
	return obstacle

func _route_remains_open(kind: String,lane_x: float,at_z: float,crosswise: bool=false) -> bool:
	# Merge the full blocked intervals of every longitudinally overlapping obstacle.
	# At least one player-width corridor must remain across the entire playable road.
	var half:=Vector2(1.15,0.34)
	if kind=="police": half=Vector2(2.42,1.08) if crosswise else Vector2(1.08,2.42)
	elif kind=="car": half=Vector2(1.02,2.08)
	elif kind=="corpse_pile": half=Vector2(0.92,1.16)
	const PLAYER_CLEARANCE: float=0.43
	const REQUIRED_GAP: float=0.86
	var intervals: Array=[]
	for existing in obstacles:
		if not is_instance_valid(existing): continue
		if absf(existing.position.z-at_z)>=existing.half_extents.y+half.y+0.45: continue
		intervals.append([existing.position.x-existing.half_extents.x-PLAYER_CLEARANCE,existing.position.x+existing.half_extents.x+PLAYER_CLEARANCE])
	intervals.append([lane_x-half.x-PLAYER_CLEARANCE,lane_x+half.x+PLAYER_CLEARANCE])
	intervals.sort_custom(func(a,b): return a[0]<b[0])
	var cursor: float=-3.05
	for interval in intervals:
		if interval[0]-cursor>=REQUIRED_GAP: return true
		cursor=maxf(cursor,float(interval[1]))
	return 3.05-cursor>=REQUIRED_GAP

## A pothole marked by three cones in a tight triangle. Only ever spawned when the road has no
## cones on it at all, so a run can never accumulate more than three.
## How many cone obstacles are on the road right now.
func _cone_obstacle_count() -> int:
	var n := 0
	for o in obstacles:
		if is_instance_valid(o) and String(o.kind) == "cone":
			n += 1
	return n


func _spawn_cone_triangle() -> void:
	var lane_x: float = [-2.0, 0.0, 2.0][rng.randi_range(0, 2)]
	var z := -46.0
	for off in [Vector3(-0.7, 0, 0.5), Vector3(0.7, 0, 0.5), Vector3(0, 0, -0.6)]:
		_spawn_obstacle("cone", lane_x + off.x, z + off.z)


func _spawn_obstacle_pattern() -> void:
	if rng.randf()<0.12 and _cone_obstacle_count() == 0:
		_spawn_cone_triangle()
		return
	# A crosswise police car is accepted only when its wide side really remains passable.
	if rng.randf()<0.09 and not _x_blocked_by_banshee(0.0,2.6):
		var open_side: float=-1.0 if rng.randf()<0.5 else 1.0
		var police_x: float=-open_side*0.85
		if _route_remains_open("police",police_x,-48.0,true):
			_spawn_obstacle("police",police_x,-48.0,true)
			return
	var lanes: Array=[-2.4,0.0,2.4]
	var safe_lane:=rng.randi_range(0,2)
	var blocked: Array=[0,1,2]
	blocked.erase(safe_lane)
	# Dense two-obstacle patterns are a late-run escalation, never an opening-run trap.
	# 0–500 m: one obstacle only; afterwards the chance rises gradually to 58%.
	var double_obstacle_chance: float=clampf((distance-500.0)/1800.0,0.0,1.0)*0.58
	if rng.randf()>double_obstacle_chance:
		blocked=[blocked[rng.randi_range(0,blocked.size()-1)]]
	# Never block the lane a Banshee is walking in.
	for lane_index in blocked.duplicate():
		if _x_blocked_by_banshee(lanes[lane_index],0.55): blocked.erase(lane_index)
	if blocked.is_empty(): return
	var car_lane: int=blocked[rng.randi_range(0,blocked.size()-1)]
	for lane_index in blocked:
		var kind: String="fence"
		if lane_index==car_lane:
			var roll: float=rng.randf()
			kind="police" if roll<0.14 else ("corpse_pile" if roll<0.27 else "car")
		elif rng.randf()<0.12:
			kind="corpse_pile"
		var lane_x: float=lanes[lane_index]
		# Both police and ordinary wrecks can mount the kerb into the pavement.
		var shoulder_chance: float=0.28 if kind=="police" else (0.20 if kind=="car" else 0.0)
		if rng.randf()<shoulder_chance:
			var shoulder: float=signf(lane_x) if not is_zero_approx(lane_x) else (-1.0 if rng.randf()<0.5 else 1.0)
			lane_x=shoulder*3.18
		var at_z: float=-48.0-float(blocked.find(lane_index))*0.8
		# A second obstacle must not seal the gap left by the first one. Skip it instead.
		if _route_remains_open(kind,lane_x,at_z):
			_spawn_obstacle(kind,lane_x,at_z)

func _tick_obstacles(delta: float) -> void:
	for i in range(obstacles.size()-1,-1,-1):
		var obstacle=obstacles[i]
		obstacle.tick(delta)
		if obstacle.overlaps(player.position) and player.vehicle!="SEDAN":  # the car ploughs through wrecks
			var clearance: float=obstacle.half_extents.x+0.43
			var left: float=clampf(obstacle.position.x-clearance,-3.15,3.15)
			var right: float=clampf(obstacle.position.x+clearance,-3.15,3.15)
			var new_x: float=left if absf(player.position.x-left)<absf(player.position.x-right) else right
			if absf(new_x-obstacle.position.x)<clearance-0.04:
				new_x=right if is_equal_approx(new_x,left) else left
			player.position.x=new_x
			player.target_x=new_x
			if obstacle.hit_cooldown<=0.0:
				obstacle.hit_cooldown=1.0
				_hurt_player(obstacle.damage)
				# At speed the vehicle smashes, it doesn't gently scrape: extra wear.
				if player.vehicle!="": player.vehicle_durability-=maxf(6.0,obstacle.damage*0.6)
				shake=maxf(shake,0.55)
				_burst(player.position+Vector3(0,0.55,0),Color("f2a04d"),8)
				var label: String=_obstacle_label(String(obstacle.kind))
				_popup(player.position+Vector3(0,2.45,0),"%s -%d"%[label,int(obstacle.damage)],Color("ffad72"))
		if obstacle.position.z>13.0:
			obstacles.remove_at(i)
			obstacle.queue_free()

## Localised label for the obstacle hit pop-up ("CORPSES" used to leak into Chinese runs).
func _obstacle_label(kind: String) -> String:
	var zh := String(language_code).begins_with("zh")
	match kind:
		"police":
			return "警车" if zh else "POLICE"
		"car":
			return "废车" if zh else "WRECK"
		"corpse_pile":
			return "尸堆" if zh else "CORPSES"
		_:
			return "路障" if zh else "BARRIER"


func _avoid_obstacles(z: Node3D,delta: float) -> void:
	for obstacle in obstacles:
		if not is_instance_valid(obstacle): continue
		var dx: float=z.position.x-obstacle.position.x
		var dz: float=z.position.z-obstacle.position.z
		var clearance: float=obstacle.half_extents.x+z.radius+0.08
		if absf(dz)<obstacle.half_extents.y+2.0 and absf(dx)<clearance+0.22:
			var side: float=_obstacle_avoid_side(z,obstacle)
			z.position.x=clampf(z.position.x+side*maxf(2.2,z.speed*0.75)*delta,-3.05,3.05)
			dx=z.position.x-obstacle.position.x
		if absf(dz)<obstacle.half_extents.y+z.radius and absf(dx)<clearance:
			var side: float=_obstacle_avoid_side(z,obstacle)
			var new_x: float=obstacle.position.x+side*(clearance+0.025)
			if new_x< -3.05 or new_x>3.05: new_x=obstacle.position.x-side*(clearance+0.025)
			z.position.x=clampf(new_x,-3.05,3.05)

func _obstacle_avoid_side(z: Node3D,obstacle: Node3D) -> float:
	var dx: float=z.position.x-obstacle.position.x
	var side:=1.0 if dx>0.0 else -1.0
	var clearance: float=obstacle.half_extents.x+z.radius+0.12
	if absf(dx)<=0.08 or (side>0 and obstacle.position.x+clearance>3.05) or (side<0 and obstacle.position.x-clearance< -3.05):
		var left_room: float=obstacle.position.x+3.05
		var right_room: float=3.05-obstacle.position.x
		side=-1.0 if left_room>right_room else 1.0
	return side

## The barrel's own model thrown apart: cap, rings and staves. This is the "it just came
## apart" look; the vehicle smash uses it too, minus the blast damage.
func _barrel_debris(barrel: Node3D) -> void:
	var center:=barrel.position+Vector3(0,0.55,0)
	var model: Node3D=barrel.get("model") as Node3D
	if is_instance_valid(model):
		_spawn_part(model,["Cap"],center,Vector3(0.8,4.0,0.2))
		_spawn_part(model,["Ring"],center,Vector3(-1.5,2.8,0.4))
		_spawn_part(model,["Barrel"],center,Vector3(1.8,2.2,-0.3))
	_burst(center,Color("8a6a3f"),22)
	_burst(center,Color("c9a163"),12)
	shake=maxf(shake,0.42)

func _explode(barrel: Node3D) -> void:
	barrel.dead=true
	# hide the body at once: the node is only freed on the next barrel tick, and its charred shell
	# was left standing on the road for that frame (and longer if the tick missed it)
	barrel.visible = false
	sound.play("explosion"); shake=1.0
	if OS.get_name()=="iOS": Input.vibrate_handheld(200,0.85)
	var center:=barrel.position+Vector3(0,0.55,0)
	_barrel_debris(barrel)
	_custom_explosion(center)
	_burst(center,Color("ffd275"),18); _fire_spray(center)
	if _flat_distance(player.position,barrel.position)<3.25:
		if player.has_armor:
			_hurt_player(player.max_health*0.90); _popup(player.position+Vector3(0,2.6,0),RunText.text("armor_hit"),Color("72d9e5"))
		else:
			_hurt_player(player.max_health*2.0); _popup(player.position+Vector3(0,2.6,0),RunText.text("no_armor"),Color("ff6547"))
	for z in zombies.duplicate():
		if is_instance_valid(z) and _flat_distance(z.position,barrel.position)<3.4: _hit_zombie(z,150,"torso",z.position+Vector3(0,1.1,0),Color("ffb15c"))

func _custom_explosion(pos: Vector3) -> void:
	var fx:=ExplosionScript.new()
	fx.position=pos
	add_child(fx)
	effects.append(fx)

func _blast_sphere(pos: Vector3,color: Color,size: float,smoke: bool) -> void:
	var e:=EffectScript.new(); e.position=pos; e.life=0.38 if not smoke else 0.9; e.total_life=e.life
	add_child(e); e.make_blast(color,size,smoke); effects.append(e)

func _fire_spray(pos: Vector3) -> void:
	for i in range(36):
		var angle:=rng.randf_range(0,TAU); var e:=EffectScript.new(); e.position=pos
		e.velocity=Vector3(cos(angle)*rng.randf_range(1.2,5.0),rng.randf_range(0.8,4.5),sin(angle)*rng.randf_range(1.2,5.0))
		e.gravity=-5.5; e.life=rng.randf_range(0.35,0.75); e.total_life=e.life; add_child(e)
		e.make_drop(Color("ffd56a") if i%3==0 else Color("f05a28"),rng.randf_range(0.045,0.12)); effects.append(e)

func _spawn_pickup(kind: String,at_z:=-38.0) -> void:
	var pickup:=PickupScript.new(); pickup.kind=kind
	var lanes:=[-2.4,0.0,2.4]; pickup.position=Vector3(lanes[rng.randi_range(0,2)],0,at_z)
	add_child(pickup); pickups.append(pickup)

const COIN_MAGNET:=3.6   # metres; the pickup-range buff adds to it

func _tick_pickups(delta: float) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var p=pickups[i]; p.tick(delta)
		# Coin magnet: dropped coins within reach fly to the survivor, no need to run over them.
		if p.kind in ["coin","silver_coin"]:
			var reach: float=COIN_MAGNET+player.pickup_bonus
			var to_player: Vector3=Vector3(player.position.x,0,player.position.z)-Vector3(p.position.x,0,p.position.z)
			if p.has_meta("pulled") or to_player.length()<reach:
				var pull: float=float(p.get_meta("pulled",0.0))+delta; p.set_meta("pulled",pull)
				var step: float=(6.0+pull*26.0)*delta
				p.position+=to_player.normalized()*minf(step,to_player.length())
		if _flat_distance(p.position,player.position)<0.82+player.pickup_bonus:
			if p.kind in ["coin","silver_coin"]:
				var _is_gold: bool = p.kind=="coin"
				# Jian the scavenger stretches gold further: +25% coins from pickups.
				var coin_gain: int = int(round(p.value*player.scavenger_coin_scale())) if _is_gold else p.value
				if _is_gold: run_coins+=coin_gain
				else: run_silver+=p.value
				if not p.source_kind.is_empty(): kill_coins[p.source_kind]=int(kill_coins.get(p.source_kind,0))+coin_gain
				_popup(player.position+Vector3(0,2.4,0),RunText.text("l_coin" if _is_gold else "l_silver_coin")+" +%d"%coin_gain,Color("ffd25e") if _is_gold else Color("e8f0ff"))
			elif p.kind=="ammo":
				# Jian's scavenger eye: he strips every cache bare (+50% ammo).
				var ammo_gain: int = int(round(player.magazine_size*2*player.scavenger_ammo_scale()))
				player.reserve_ammo+=ammo_gain; _popup(player.position+Vector3(0,2.4,0),RunText.fmt("ammo",ammo_gain),Color("ffd275"))
			elif p.kind=="armor":
				player.set_armor(true); player.shield=minf(200.0,player.shield+50.0); _popup(player.position+Vector3(0,2.4,0),RunText.fmt("shield",50),Color("72d9e5"))
			elif p.kind=="helmet":
				player.set_helmet(true); _popup(player.position+Vector3(0,2.4,0),RunText.text("helmet"),Color("b6d38a"))
			elif p.kind=="grenade":
				player.grenade_count=mini(8,player.grenade_count+2); _popup(player.position+Vector3(0,2.4,0),RunText.fmt("frag",2),Color("b6d38a"))
			elif p.kind=="flashbang":
				player.flashbang_count=mini(5,player.flashbang_count+1); _popup(player.position+Vector3(0,2.4,0),RunText.fmt("flash",1),Color("bdefff"))
			elif p.kind=="launcher":
				player.set_weapon("LAUNCHER"); _popup(player.position+Vector3(0,2.4,0),ShopText.text(language_code,"n_launcher"),Color("ff9b55"))
			elif p.kind=="fire_round":
				player.fire_ammo=mini(24,player.fire_ammo+4); _popup(player.position+Vector3(0,2.4,0),RunText.fmt("incendiary_n",4),Color("ff6547"))
			else:
				# Darius (paramedic) doubles the medkit: 70 HP instead of 35.
				var healed:=int(35.0*player.heal_scale())
				player.health=minf(player.max_health,player.health+healed); _popup(player.position+Vector3(0,2.4,0),RunText.fmt("health",healed),Color("c9f54a"))
			sound.play("pickup"); pickups.remove_at(i); p.queue_free()
		elif p.position.z>13: pickups.remove_at(i); p.queue_free()

## ---- Pooled effects -----------------------------------------------------------------
func _fx_release(e) -> void:
	e.disarm()
	match String(e.get_meta("fx_kind","")):
		"spark": fx_sparks[int(e.get_meta("fx_bucket",0))].append(e)
		"drop": fx_drops[int(e.get_meta("fx_bucket",0))].append(e)
		_: fx_labels.append(e)

func _fx_spark_at(pos: Vector3,color: Color,size: float,vel: Vector3,grav: float,seconds: float) -> void:
	var b: int=0 if size<0.052 else (1 if size<0.072 else 2)
	var pool: Array=fx_sparks[b]
	var e
	if pool.is_empty(): e=EffectScript.new(); add_child(e)
	else: e=pool.pop_back()
	e.make_spark(color,FX_SPARK_SIZES[b])
	e.set_meta("fx_kind","spark"); e.set_meta("fx_bucket",b)
	e.position=pos; e.velocity=vel; e.gravity=grav; e.arm(seconds)
	effects.append(e)

func _fx_drop_at(pos: Vector3,color: Color,size: float,vel: Vector3,grav: float,seconds: float) -> void:
	var b: int=0 if size<0.062 else (1 if size<0.088 else 2)
	var pool: Array=fx_drops[b]
	var e
	if pool.is_empty(): e=EffectScript.new(); add_child(e)
	else: e=pool.pop_back()
	e.make_drop(color,FX_DROP_SIZES[b])
	e.set_meta("fx_kind","drop"); e.set_meta("fx_bucket",b)
	e.position=pos; e.velocity=vel; e.gravity=grav; e.arm(seconds)
	effects.append(e)

func _fx_label_at(pos: Vector3,text: String,color: Color,vel: Vector3,seconds: float,big: bool) -> void:
	var e
	if fx_labels.is_empty(): e=EffectScript.new(); add_child(e)
	else: e=fx_labels.pop_back()
	e.make_text(text,color)
	e.set_meta("fx_kind","label")
	if big: e.label.font_size=64; e.label.pixel_size=0.0085; e.label.outline_size=12
	e.position=pos; e.velocity=vel; e.gravity=0.0; e.arm(seconds)
	effects.append(e)

func _burst(pos: Vector3,color: Color,count: int) -> void:
	for i in range(count):
		_fx_spark_at(pos,color,rng.randf_range(0.035,0.075),Vector3(rng.randf_range(-2,2),rng.randf_range(0.5,3),rng.randf_range(-2,2)),-5.0,rng.randf_range(0.35,0.65))

## Rolled on every kill. A voucher is announced with the same popup the coins use.
func _roll_voucher_drop(z_pos: Vector3) -> void:
	if rng.randf() >= VOUCHER_DROP_CHANCE:
		return
	bank_vouchers += 1
	_popup(z_pos + Vector3(0.0, 2.4, 0.0), "你获得了一张礼券！" if String(language_code).begins_with("zh") else "You found a voucher!", Color(1, 1, 1, 1))
	sound.play("coin_get")
	_save()


func _popup(pos: Vector3,text: String,color: Color) -> void:
	_fx_label_at(pos,text,color,Vector3(0,0.8,0),0.85,false)

func _tick_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i]
		# Effects belong to the world, so they ride the scrolling road like bullets and crates.
		# Without this, a barrel explosion stayed at a fixed z and travelled with the player.
		e.position.z += 3.5 * delta
		e.tick(delta)
		if e.life<=0:
			effects.remove_at(i)
			if e.has_meta("fx_kind"): _fx_release(e)
			else: e.queue_free()                     # blasts, shocks and body parts are rare

func _update_mouse_aim() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player): return
	aim_target=null
	for z in zombies+watchers:
		if not is_instance_valid(z) or z.dead or camera.is_position_behind(z.global_position): continue
		var top:=camera.unproject_position(z.global_position+Vector3(0,z.collision_height()*0.96,0))
		var bottom:=camera.unproject_position(z.global_position+Vector3(0,0.12,0))
		var hit_rect:=Rect2(Vector2((top.x+bottom.x)*0.5-27,top.y),Vector2(54,maxf(20,bottom.y-top.y))).grow(5)
		if hit_rect.has_point(mouse_position):
			var ratio:=clampf((mouse_position.y-top.y)/maxf(1,bottom.y-top.y),0,1)
			var height:=lerpf(z.collision_height()*0.90,0.24,ratio)
			aim_target=z; aim_point=z.global_position+Vector3(0,height,0)
			var target_flat:=aim_point-player.global_position; target_flat.y=0
			if target_flat.length()>0.15: aim_direction=target_flat.normalized()
			return
	for barrel in barrels:
		if not is_instance_valid(barrel) or barrel.dead or camera.is_position_behind(barrel.global_position): continue
		var top:=camera.unproject_position(barrel.global_position+Vector3(0,barrel.height,0))
		var bottom:=camera.unproject_position(barrel.global_position+Vector3(0,0.03,0))
		var center_x: float=(top.x+bottom.x)*0.5
		var edge:=camera.unproject_position(barrel.global_position+Vector3(barrel.radius,barrel.height*0.5,0))
		var half_width: float=maxf(12.0,absf(edge.x-center_x)+6.0)
		var hit_rect:=Rect2(Vector2(center_x-half_width,top.y),Vector2(half_width*2.0,maxf(24.0,bottom.y-top.y))).grow(4)
		if hit_rect.has_point(mouse_position):
			aim_target=barrel; aim_point=barrel.global_position+Vector3(0,barrel.height*0.5,0)
			var target_flat:=aim_point-player.global_position; target_flat.y=0
			if target_flat.length()>0.15: aim_direction=target_flat.normalized()
			return
	for crate in crates:
		if not is_instance_valid(crate) or crate.broken or camera.is_position_behind(crate.global_position): continue
		var c_top:=camera.unproject_position(crate.global_position+Vector3(0,2.0,0))
		var c_bottom:=camera.unproject_position(crate.global_position+Vector3(0,0.03,0))
		var c_edge:=camera.unproject_position(crate.global_position+Vector3(crate.half_extents.x,0.4,0))
		var c_half: float=maxf(16.0,absf(c_edge.x-c_bottom.x)+8.0)
		var c_rect:=Rect2(Vector2(c_bottom.x-c_half,c_top.y),Vector2(c_half*2.0,maxf(30.0,c_bottom.y-c_top.y))).grow(4)
		if c_rect.has_point(mouse_position):
			aim_target=crate; aim_point=crate.global_position+Vector3(0,0.45,0)
			var c_flat:=aim_point-player.global_position; c_flat.y=0
			if c_flat.length()>0.15: aim_direction=c_flat.normalized()
			return
	var origin:=camera.project_ray_origin(mouse_position); var direction:=camera.project_ray_normal(mouse_position)
	if absf(direction.y)<0.001: return
	var point:=origin+direction*((1.15-origin.y)/direction.y)
	var flat:=point-player.global_position; flat.y=0
	if flat.length()>0.15: aim_direction=flat.normalized()

func _update_touch_aim() -> void:
	aim_target=null; var best_score:=0.94
	for z in zombies+watchers:
		if not is_instance_valid(z) or z.dead: continue
		if watchers.has(z) and z.global_position.z>player.global_position.z-1.5: continue # behind: ignore
		var flat: Vector3=z.global_position-player.global_position; flat.y=0
		if flat.length()<0.2 or flat.length()>42: continue
		var score: float=aim_direction.dot(flat.normalized())-flat.length()*0.0008
		if z.kind=="banshee": score+=0.04 # the Banshee is the priority target when she's roughly in line
		if score>best_score:
			best_score=score; aim_target=z; aim_point=z.global_position+Vector3(0,z.collision_height()*0.62,0)
	for barrel in barrels:
		if not is_instance_valid(barrel) or barrel.dead: continue
		var flat: Vector3=barrel.global_position-player.global_position; flat.y=0
		if flat.length()<0.2 or flat.length()>42: continue
		var score: float=aim_direction.dot(flat.normalized())-flat.length()*0.0008
		if score>best_score:
			best_score=score; aim_target=barrel; aim_point=barrel.global_position+Vector3(0,barrel.height*0.5,0)
	for crate in crates:
		if not is_instance_valid(crate) or crate.broken: continue
		var flat: Vector3=crate.global_position-player.global_position; flat.y=0
		if flat.length()<0.2 or flat.length()>42: continue
		var score: float=aim_direction.dot(flat.normalized())-flat.length()*0.0008
		if score>best_score:
			best_score=score; aim_target=crate; aim_point=crate.global_position+Vector3(0,0.45,0)

func _unhandled_input(event: InputEvent) -> void:
	if armory_drag and is_instance_valid(armory_model):
		if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
			# spin around a pivot so horizontal drag is a yaw and vertical drag a pitch,
			# which lets every angle be reached
			armory_pivot.rotation.y -= event.relative.x * 0.012
			armory_pivot.rotation.x = clampf(armory_pivot.rotation.x - event.relative.y * 0.010, deg_to_rad(-85.0), deg_to_rad(85.0))
			return
		if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed):
			armory_drag = false
	# F9 hides every ground pickup: one keypress tells us whether the stray white dot is a
	# pickup or something else.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		debug_show_fps = not debug_show_fps
		print("fps overlay: ", debug_show_fps)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		debug_hide_pickups = not debug_hide_pickups
		for q in pickups:
			if is_instance_valid(q):
				q.visible = not debug_hide_pickups
		print("pickups visible: ", not debug_hide_pickups)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE] and state=="intro":
			_finish_intro()
			return
		if state=="shop" and event.keycode in [KEY_LEFT,KEY_A]: select_shop_item(shop_index-1); return
		if state=="shop" and event.keycode in [KEY_RIGHT,KEY_D]: select_shop_item(shop_index+1); return
		if state=="shop" and event.keycode in [KEY_ENTER,KEY_SPACE]:
			if buy_item(shop_items[shop_index].id): shop_truck.celebrate_purchase(shop_items[shop_index].id)
			return
		if event.keycode in [KEY_ENTER,KEY_SPACE] and state=="cover":
			if intro_seen: enter_lobby()
			else: start_run()
		elif event.keycode in [KEY_ENTER,KEY_SPACE] and state=="gameover": start_run()
		elif event.keycode in [KEY_ESCAPE,KEY_P]:
			if state=="playing":
				state="paused"; _release_touches(); _freeze_world(true)
			elif state=="paused":
				state="playing"; _freeze_world(false)
		elif event.keycode==KEY_R and state=="playing": request_reload()
		elif event.keycode==KEY_O and state=="character_select" and OS.has_feature("editor"): maybe_show_offer(true)  # test the offer popup from the editor
		elif event.keycode in [KEY_E,KEY_TAB] and state=="playing": swap_weapon()
		elif event.keycode==KEY_G and state=="playing": _throw_ordnance("molotov" if player.molotov_count>0 else "frag")
		elif event.keycode==KEY_F and state=="playing": _throw_ordnance("flash")
		elif event.keycode==KEY_Q and state=="playing": toggle_fire_mode()
	if state=="character_select":
		if event is InputEventScreenDrag:
			if lobby_press.x>=0: _lobby_drag(event.position,event.relative)
			elif event.position.x>100 and event.position.x<440 and event.position.y<LOBBY_BAND_TOP: lobby.drag(event.relative.x)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			# Touch screens also send emulated mouse motion; only the touch events scroll there.
			if lobby_press.x>=0:
				if not touch_controls: _lobby_drag(event.position,event.relative)
			elif event.position.x>100 and event.position.x<440 and event.position.y<LOBBY_BAND_TOP: lobby.drag(event.relative.x)
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
			_lobby_release(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and lobby_view_rect().has_point(event.position):
			lobby_scroll=clampf(lobby_scroll+(-48.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 48.0),0.0,lobby_max_scroll())
	if state=="mail":
		if (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and not touch_controls)) and mail_press.x>=0:
			if not mail_dragged and event.position.distance_to(mail_press)>10.0: mail_dragged=true
			if mail_dragged and mail_open>=0: mail_scroll=clampf(mail_scroll-event.relative.y,0.0,letter_max_scroll())
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed): _letter_release(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and mail_open>=0:
			mail_scroll=clampf(mail_scroll+(-60.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 60.0),0.0,letter_max_scroll())
		if state=="terms":
			if (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and not touch_controls)) and terms_press.x>=0:
				_terms_drag(event.position,event.relative)
			elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				terms_scroll=clampf(terms_scroll+(-60.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 60.0),0.0,hud.terms_max_scroll())
	if state=="map":
		if (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and not touch_controls)) and map_press.x>=0:
			if not map_dragged and event.position.distance_to(map_press)>10.0: map_dragged=true
			if map_dragged: map_scene.pan(event.relative.x)
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed): _map_release(event.position)
	if state=="controls":
		if ctrl_drag!="" and (event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT))):
			move_control(ctrl_drag,event.position)
		elif ctrl_drag!="" and ((event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)):
			ctrl_drag=""; sound.play("hit"); _save()
	if state=="settings" and volume_drag!="":
		if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)): _set_volume_from(event.position.x)
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
			volume_drag=""; sound.play("hit"); _save()
	if state=="bag":
		if event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
			bag_scroll=clampf(bag_scroll-event.relative.y,0.0,bag_max_scroll())
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			bag_scroll=clampf(bag_scroll+(-60.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 60.0),0.0,bag_max_scroll())
	if state=="store":
		if event is InputEventScreenDrag and store_press.x>=0: _store_drag(event.position,event.relative)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) and store_press.x>=0 and not touch_controls: _store_drag(event.position,event.relative)
		elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed): _store_release(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			store_scroll=clampf(store_scroll+(-60.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 60.0),0.0,store_max_scroll())
	if event is InputEventMouseMotion:
		mouse_position=event.position
		if state=="playing" and not touch_controls: _update_mouse_aim()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not touch_controls:
		# iOS emulates a mouse press for every finger. Without this guard a single tap
		# ran _pointer_down twice, once for the touch and once for the emulated mouse.
		if event.pressed: _pointer_down(event.position)
	elif event is InputEventScreenTouch:
		touch_controls=true
		if event.pressed:
			if _pointer_down(event.position): return
			if state=="playing":
				# Grab whichever stick the finger is closer to. With a movable layout the old
				# left-half / right-half split left a stick placed on the wrong side unusable.
				var dl: float=event.position.distance_to(left_origin)
				var dr: float=event.position.distance_to(right_origin)
				if left_touch_id==-1 and (right_touch_id!=-1 or dl<=dr):
					left_touch_id=event.index; left_knob=left_origin; left_stick=Vector2.ZERO
				elif right_touch_id==-1:
					right_touch_id=event.index; right_knob=right_origin; right_stick=Vector2.ZERO
		else:
			if event.index==left_touch_id: left_touch_id=-1; left_stick=Vector2.ZERO; left_knob=left_origin
			if event.index==right_touch_id: right_touch_id=-1; right_stick=Vector2.ZERO; right_knob=right_origin
	elif event is InputEventScreenDrag:
		if event.index==left_touch_id:
			# Left stick only steers sideways, so its knob slides on a horizontal track.
			left_stick=Vector2(clampf((event.position.x-left_origin.x)/58.0,-1.0,1.0),0.0); left_knob=left_origin+left_stick*46.0
		elif event.index==right_touch_id:
			right_stick=((event.position-right_origin)/58.0).limit_length(1.0); right_knob=right_origin+right_stick*46.0

func _release_touches() -> void:
	left_touch_id=-1; right_touch_id=-1; left_stick=Vector2.ZERO; right_stick=Vector2.ZERO
	left_origin=control_pos("stick_left"); right_origin=control_pos("stick_right"); left_knob=left_origin; right_knob=right_origin

## Armory taps are handled here and nowhere else: the shop/pause branches below share one
## long if-chain, and editing it has broken the build twice.
## Equip switches in the lobby: one per tab, routed through a small standalone handler so the
## long pointer chain below stays untouched.
func toggle_weapon_equip() -> void:
	weapon_equipped = not weapon_equipped
	_save()
	# the ON/OFF ring on the button is the feedback, no toast key needed


func _lobby_gear_pointer(pos: Vector2) -> bool:
	if state != "character_select":
		return false
	if LOBBY_GEAR.has_point(pos):
		# top-right corner is the settings gear, as on every other screen
		settings_return_state = "character_select"; state = "settings"; return true
	if lobby_tab == 1 and LOBBY_GEAR_PET.has_point(pos):
		toggle_pet_equip(); return true
	if lobby_tab == 3 and LOBBY_GEAR_VEHICLE.has_point(pos):
		toggle_vehicle_equip(); return true

	return false


func _armory_pointer(pos: Vector2) -> bool:
	if state == "shop" and ARMORY_BTN.has_point(pos):
		open_armory()
		return true
	if state == "armory" and ARMORY_BACK.has_point(pos):
		close_armory()
		return true
	if state != "armory":
		return false
	if ARMORY_UPGRADE.has_point(pos):
		armory_upgrade()
		return true
	if ARMORY_PREV.has_point(pos):
		armory_step(-1)
		return true
	if ARMORY_NEXT.has_point(pos):
		armory_step(1)
		return true
	if ARMORY_VIEW.has_point(pos):
		armory_drag = true
		return true
	return false



func _pointer_down(pos: Vector2) -> bool:
	if _lobby_gear_pointer(pos): return true
	if _armory_pointer(pos): return true
	if ads_offer_open:
		ads_offer_tap(pos); return true
	if state=="terms":
		# 不同意 = 退出游戏，下次打开还会弹出；同意 = 存档并进入游戏。
		if TERMS_AGREE.has_point(pos): terms_accepted=true; _save(); state="cover"; return true
		if TERMS_DISAGREE.has_point(pos): get_tree().quit(); return true
		terms_press=pos; terms_dragged=false; return true
	if state=="loading":
		_finish_loading()
		return true
	if state=="intro":
		_finish_intro()
		return true
	# The cover (original title poster): the painted gear opens settings, any other tap
	# goes through the loading screen (random art) — the classic login page flow.
	if state=="cover":
		if Rect2(466,10,70,70).has_point(pos): settings_return_state="cover"; state="settings"
		elif intro_seen: _begin_loading("lobby") # returning players go straight to the main screen
		else: _begin_loading("run") # first launch: the opening chase
		_release_touches(); return true
	if state=="lootbox":
		if Rect2(24,24,100,48).has_point(pos): close_lootbox(); return true
		if LOOTBOX_GOLD_RECT.has_point(pos): buy_lootbox(false); return true
		if LOOTBOX_VOUCHER_RECT.has_point(pos): buy_lootbox(true); return true
		return true
	elif state=="map":
		# Don't act on press: a swipe pans the table, only a clean tap picks a photo.
		map_press=pos; map_dragged=false
		return true
	elif state=="offer":
		if OFFER_CLOSE.grow(8).has_point(pos) or not OFFER_PANEL.has_point(pos): close_offer(); return true
		if OFFER_BUY.has_point(pos):
			if buy_pack(offer_id): close_offer()
			return true
		return true
	elif state=="resource_pack":
		if OFFER_CLOSE.grow(8).has_point(pos) or not OFFER_PANEL.has_point(pos): close_resource_pack(); return true
		if OFFER_BUY.has_point(pos):
			if buy_pack(resource_pack_id) and state=="resource_pack": close_resource_pack()
			return true
		return true
	elif state=="signin":
		if SIGNIN_CLOSE.grow(8).has_point(pos) or not SIGNIN_PANEL.has_point(pos): close_signin(); return true
		if SIGNIN_CLAIM.has_point(pos): claim_signin()
		elif SIGNIN_DOUBLE.has_point(pos): request_reward_ad("signin_double")
		return true
	elif state=="airdrop":
		state=airdrop_return_state; return true
	elif state=="bag":
		if Rect2(24,24,100,48).has_point(pos): close_bag()
		return true
	elif state=="mail":
		if Rect2(24,24,100,48).has_point(pos):
			if mail_open>=0: mail_open=-1
			else: close_mail()
			return true
		mail_press=pos; mail_dragged=false
		return true
	elif state=="tasks":
		if Rect2(24,24,100,48).has_point(pos): close_tasks(); return true
		for t in range(2):
			if tasks_tab_rect(t).has_point(pos): tasks_tab=t; return true
		for row in task_rows():
			if task_swap_button(row.rect).grow(4).has_point(pos):
				request_reward_ad("swap:%s:%d"%["daily" if row.daily else "event",int(row.slot)]); return true
			if task_button(row.rect).grow(6).has_point(pos):
				if mission_claimed(row.m,row.daily): return true
				if mission_ready(row.m,row.daily): claim_mission(row.m,row.daily)
				else: start_run()  # "Go": jump straight into a run
				return true
		return true
	elif state=="character_select":
		if lobby_swallow_tap>0.0: return true
		if _wallet_plus_hit(WALLET_LOBBY,pos,LOBBY_WALLET_SCALE): return true
		if SIDE_SIGNIN.has_point(pos): open_signin(); return true
		if SIDE_TASKS.has_point(pos): open_tasks(); return true
		if SIDE_SHOP.has_point(pos): open_shop(); return true
		if SIDE_STORE.has_point(pos): open_store(); return true
		if SIDE_MAIL.has_point(pos): open_mail(); return true
		if SIDE_BAG.has_point(pos): open_bag(); return true
		if SIDE_MAP.has_point(pos): open_map(); return true
		if AIRDROP_RECT.has_point(pos) and airdrop_available(): request_reward_ad("airdrop"); return true
		if offer_active() and OFFER_BADGE.has_point(pos): open_offer(); return true
		# Main screen (see hud._draw_character_select): one scrolling column on the left with
		# 角色 / 宠物 tabs; the survivor and the pet stand together on the platform.
		# EQUIP dropdown wins over the tab row: it is drawn on top of the tabs, so a press
		# there must equip (or just close) and never reach the tab underneath.
		if equip_menu_index >= 0:
			if equip_menu_rect().has_point(pos):
				_equip_from_menu()
				sound.play("equip")
			elif equip_menu_unequip_rect().has_point(pos):
				_unequip_from_menu()
				sound.play("equip")
			equip_menu_index = -1
			return true
		for tab_i in [0, 1, 3, 4]:
			if lobby_tab_rect(tab_i).has_point(pos): set_lobby_tab(tab_i); return true
		for side in [-1,1]:
			if lobby_page_visible(side) and lobby_page_rect(side).has_point(pos): lobby_page(side); return true
		# The equip dropdown lives above the card strip, outside lobby_view_rect(): without this
		# the press was never registered and the popup could not be tapped at all.
		if lobby_view_rect().has_point(pos) or (equip_menu_index>=0 and equip_menu_rect().has_point(pos)):
			lobby_press=pos; lobby_dragged=false; return true
		if LOBBY_AD_RUN.grow(8).has_point(pos) and not ad_run_used and stamina.value<stamina.RUN_COST:
			request_reward_ad("free_run"); return true
		if false and LOBBY_LOADOUT.has_point(pos):  # GEAR toggle retired: equip lives on the cards
			toggle_loadout(); return true
		if LOBBY_START.has_point(pos):
			if stamina.value>=stamina.RUN_COST: _begin_loading("run")
			else: store_toast_text=StoreCatalog.text(language_code,"no_cans"); store_toast=2.4
			return true
		return true
	elif state=="settings":
		if SLIDER_MUSIC.grow(8).has_point(pos): volume_drag="music"; _set_volume_from(pos.x); return true
		if SLIDER_SFX.grow(8).has_point(pos): volume_drag="sfx"; _set_volume_from(pos.x); return true
		if Rect2(66,348,408,70).has_point(pos): auto_reload=not auto_reload; _save(); return true
		if Rect2(66,436,408,70).has_point(pos): open_language(); return true
		if Rect2(66,524,408,70).has_point(pos): text_size=(text_size+1)%3; _save(); return true
		if Rect2(66,612,408,70).has_point(pos): ctrl_drag=""; state="controls"; return true
		if SETTINGS_QUALITY.has_point(pos): quality_high=not quality_high; _apply_quality(); _save(); return true
		if Rect2(66,810,408,64).has_point(pos): state=settings_return_state; return true
	elif state=="controls":
		if CTRL_RESET.has_point(pos):
			touch_layout={}; _pin_sticks(); _save(); return true
		if CTRL_SAVE.has_point(pos):
			ctrl_drag=""; _save(); state="settings"; return true
		ctrl_drag=control_at(pos)
		return true
	if state=="gameover" and gameover_double_rect().has_point(pos): request_reward_ad("run_double"); return true
	if state=="gameover" and Rect2(66,586,408,70).has_point(pos) and (not revive_used or PREMIUM_BUILD): request_revival(); return true
	if state=="gameover" and Rect2(66,672,408,66).has_point(pos): go_to_lobby(); return true
	if state=="gameover" and Rect2(66,758,408,54).has_point(pos): open_shop(); return true
	if state=="gameover" and SHARE_RECT.has_point(pos): share_result(); return true
	if state=="shop":
		if ARMORY_BTN.has_point(pos): open_armory(); return true
		if _wallet_plus_hit(WALLET_SHOP,pos): return true
		if SHOP_STORE_BTN.has_point(pos): open_store(); return true
		if Rect2(24,24,100,44).has_point(pos): close_shop(); return true
		if Rect2(404,24,112,48).has_point(pos): open_lootbox(); return true
		if Rect2(30,786,80,60).has_point(pos): select_shop_item(shop_index-1); return true
		if Rect2(430,786,80,60).has_point(pos): select_shop_item(shop_index+1); return true
		if Rect2(124,786,292,60).has_point(pos):
			var id: String=shop_items[shop_index].id
			shop_truck.focus(id)
			if buy_item(id): shop_truck.celebrate_purchase(id)
			return true
		for i in range(shop_items.size()):
			if Rect2(30+i*60,862,56,44).has_point(pos): select_shop_item(i); return true
	elif state=="payfail":
		if PAYFAIL_RETRY.has_point(pos): retry_payfail()
		elif PAYFAIL_CLOSE.has_point(pos) or not PAYFAIL_PANEL.has_point(pos): close_payfail()
		return true
	elif state=="store":
		if Rect2(24,24,100,48).has_point(pos): close_store(); return true
		if STORE_RESTORE.has_point(pos): restore_purchases(); return true
		if store_view_rect().has_point(pos): store_press=pos; store_dragged=false
		return true
	elif state=="language":
		for i in range(Localization.LANGUAGES.size()):
			var rect:=Rect2(30+(i%2)*245,150+floori(i/2.0)*62,235,50)
			if rect.has_point(pos): language_code=Localization.LANGUAGES[i].code; _save(); return true
		if Rect2(66,840,408,60).has_point(pos): state="settings"; return true
	elif state=="playing":
		if PAUSE_BUTTON.has_point(pos):
			state="paused"; _release_touches(); _freeze_world(true); return true
		if health_plus_rect.grow(8).has_point(pos): _tap_health_plus(); return true
		if touch_controls and pos.distance_to(control_pos("btn_swap"))<BTN_RADIUS+4: swap_weapon(); return true
		if touch_controls and pos.distance_to(control_pos("btn_reload"))<BTN_RADIUS+6: request_reload(); return true
		if touch_controls and pos.distance_to(control_pos("btn_frag"))<BTN_RADIUS: _throw_ordnance("molotov" if player.molotov_count>0 else "frag"); return true
		if touch_controls and pos.distance_to(control_pos("btn_flash"))<BTN_RADIUS: _throw_ordnance("flash"); return true
		if touch_controls and player.weapon=="LAUNCHER" and pos.distance_to(control_pos("btn_fire"))<BTN_RADIUS: toggle_fire_mode(); return true
	elif state=="health_ad":
		if HEALTH_AD_CANCEL.has_point(pos): state="playing"; return true
		if HEALTH_AD_WATCH.has_point(pos): request_reward_ad("health_refill"); return true
		return true
	elif state=="paused":
		if Rect2(66,468,408,68).has_point(pos): state="playing"; return true
		if Rect2(66,552,408,58).has_point(pos): settings_return_state="paused"; state="settings"; return true
		if Rect2(66,626,408,58).has_point(pos): auto_reload=not auto_reload; _save(); return true
		if Rect2(66,700,408,58).has_point(pos): open_shop(); return true
		# Restarting inside a run is free: retrying a failed run should never drain cans.
		if Rect2(66,774,408,58).has_point(pos): start_run(false,true); return true
		if Rect2(66,848,408,58).has_point(pos):
			_release_touches(); go_to_lobby(); return true
	return false

## Save file: the current name plus the legacy Dead Run name, so an old file keeps working
## and is written under the new name on the next save.
const SAVE_PATH:="user://deadfrontier.cfg"
const SAVE_PATH_LEGACY:="user://dead_run.cfg"

func _load_save() -> void:
	var c:=ConfigFile.new()
	# Test and capture runs must not inherit the player's real save: a purchased remove-ads
	# or an already-claimed mailbox would break the scripted assertions.
	var isolated:=false
	for f in ["--smoke-test","--soak-test","--lootbox-test","--stamina-test","--capture","--capture-medic","--capture-bike"]:
		if f in OS.get_cmdline_user_args(): isolated=true; break
	if not isolated and (c.load(SAVE_PATH)==OK or c.load(SAVE_PATH_LEGACY)==OK):
		best_distance=int(c.get_value("run","best",0)); character_choice=int(c.get_value("run","character",0)); skin_choice=c.get_value("run","skins",{}); pet_choice=clampi(int(c.get_value("run","pet",0)),0,3); pet_equipped=bool(c.get_value("run","pet_equipped",false)); owned_pets=c.get_value("pets","owned",{}) if int(c.get_value("pets","rules",0))>=2 else {}; mail_claimed=c.get_value("mail","claimed",{}); airdrop_day=str(c.get_value("airdrop","day","")); intro_seen=bool(c.get_value("run","intro_seen",false)) or best_distance>0; ad_run_used=bool(c.get_value("run","ad_run_used",false)); auto_reload=bool(c.get_value("gameplay","auto_reload_v3",true)); text_size=clampi(int(c.get_value("display","text_size",1)),0,2); quality_high=bool(c.get_value("display","quality_high",true)); owned_vehicle=str(c.get_value("vehicles","owned","")); loadout_on=bool(c.get_value("run","loadout_on",true)); passes=c.get_value("pass","owned",{}); pass_days=c.get_value("pass","days",{}); puzzle_pieces=c.get_value("puzzle","pieces",{}); all_access=bool(c.get_value("pass","all_access",false))
		if owned_vehicle=="CAR": owned_vehicle="CRUISER" # old save name for the third bike
		owned_characters=c.get_value("chars","owned",{}); owned_skins=c.get_value("chars","skins",{})
		terms_accepted=bool(c.get_value("legal","terms_v1",false))
		airdrop_day=String(c.get_value("crates","day",""))
		airdrop_count_today=int(c.get_value("crates","count",0))
		runs_total=int(c.get_value("crates","runs",0))
		airdrop_at_run=int(c.get_value("crates","at_run",-5))
		# A locked survivor can never stay selected (e.g. an old save from before the store).
		if not character_owned(character_choice): character_choice=0
		if is_instance_valid(player): player.set_character(character_choice,character_asset(character_choice))
		language_code=str(c.get_value("ui","language",language_code)); bank_coins=int(c.get_value("wallet","coins",0)); bank_silver=int(c.get_value("wallet","silver",0)); bank_vouchers=int(c.get_value("wallet","vouchers",0))
		can_ad_day=str(c.get_value("can_ads","day","")); can_ad_count=clampi(int(c.get_value("can_ads","count",0)),0,CAN_AD_DAILY_LIMIT)
		for id in c.get_value("store","owned",[]): store_owned[String(id)]=true
		remove_ads=bool(c.get_value("store","remove_ads",false))
		ads_offer_shows=int(c.get_value("store","ads_offer_shows",0))
		for tx in c.get_value("store","iap_ledger",[]): iap_ledger[String(tx)]=true
		offer_id=str(c.get_value("offer","id","")); offer_expires=int(c.get_value("offer","expires",0)); next_offer_at=int(c.get_value("offer","next",0))
		play_day=str(c.get_value("offer","play_day","")); play_seconds_today=float(c.get_value("offer","play_seconds",0.0))
		signin_last=str(c.get_value("signin","last","")); signin_index=int(c.get_value("signin","index",0)); signin_shown_day=str(c.get_value("signin","shown",""))
		daily_day=str(c.get_value("missions","day","")); daily_stats=c.get_value("missions","stats",{}); daily_claimed=c.get_value("missions","claimed",{}); daily_swaps=c.get_value("missions","swaps",{})
		event_window=int(c.get_value("event","window",-1)); event_stats=c.get_value("event","stats",{}); event_claimed=c.get_value("event","claimed",{}); event_swaps=c.get_value("event","swaps",{})
		for id in meta_upgrades.keys(): meta_upgrades[id]=int(c.get_value("upgrades",id,0))
	var saved_layout: Variant=c.get_value("controls","layout",{})
	touch_layout=saved_layout if saved_layout is Dictionary else {}
	stamina.load_config(c)
## Settings volume sliders: track rects (also used by hud.gd to draw them).
const SLIDER_MUSIC:=Rect2(200,214,214,36)
const SLIDER_SFX:=Rect2(200,282,214,36)
var volume_drag:=""

func _set_volume_from(x: float) -> void:
	var r: Rect2=SLIDER_MUSIC if volume_drag=="music" else SLIDER_SFX
	var v:=clampf((x-r.position.x)/r.size.x,0.0,1.0)
	v=snappedf(v,0.05)
	if volume_drag=="music": sound.music_volume=v
	else: sound.sfx_volume=v
	sound.apply_volumes()

func _read_volumes() -> void:
	var c:=ConfigFile.new()
	if c.load(SAVE_PATH)==OK or c.load(SAVE_PATH_LEGACY)==OK:
		sound.music_volume=clampf(float(c.get_value("audio","music_volume",0.8)),0.0,1.0)
		sound.sfx_volume=clampf(float(c.get_value("audio","sfx_volume",1.0)),0.0,1.0)

func _read_muted() -> bool:
	var c:=ConfigFile.new()
	return bool(c.get_value("audio","muted",false)) if (c.load(SAVE_PATH)==OK or c.load(SAVE_PATH_LEGACY)==OK) else false
func _save() -> void:
	if "--smoke-test" in OS.get_cmdline_user_args() or "--soak-test" in OS.get_cmdline_user_args() or "--lootbox-test" in OS.get_cmdline_user_args() or "--stamina-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--capture-medic" in OS.get_cmdline_user_args() or "--capture-bike" in OS.get_cmdline_user_args(): return # test and capture runs must never touch the player's real save
	var c:=ConfigFile.new(); c.set_value("run","best",best_distance); c.set_value("run","character",character_choice); c.set_value("run","skins",skin_choice); c.set_value("run","pet",pet_choice); c.set_value("run","pet_equipped",pet_equipped); c.set_value("pets","owned",owned_pets); c.set_value("pets","rules",2); c.set_value("chars","owned",owned_characters); c.set_value("chars","skins",owned_skins); c.set_value("vehicles","owned",owned_vehicle); c.set_value("run","loadout_on",loadout_on); c.set_value("puzzle","pieces",puzzle_pieces); c.set_value("pass","owned",passes); c.set_value("pass","days",pass_days); c.set_value("pass","all_access",all_access); c.set_value("mail","claimed",mail_claimed); c.set_value("airdrop","day",airdrop_day); c.set_value("run","intro_seen",intro_seen); c.set_value("run","ad_run_used",ad_run_used); c.set_value("gameplay","auto_reload_v3",auto_reload); c.set_value("display","text_size",text_size); c.set_value("display","quality_high",quality_high); c.set_value("audio","music_volume",sound.music_volume if is_instance_valid(sound) else 0.8); c.set_value("audio","sfx_volume",sound.sfx_volume if is_instance_valid(sound) else 1.0)
	c.set_value("ui","language",language_code); c.set_value("wallet","coins",bank_coins); c.set_value("wallet","silver",bank_silver); c.set_value("wallet","vouchers",bank_vouchers); c.set_value("store","owned",store_owned.keys()); c.set_value("store","remove_ads",remove_ads); c.set_value("store","ads_offer_shows",ads_offer_shows); c.set_value("store","iap_ledger",iap_ledger.keys()); c.set_value("legal","terms_v1",terms_accepted)
	c.set_value("can_ads","day",can_ad_day); c.set_value("can_ads","count",can_ad_count)
	c.set_value("crates","day",airdrop_day); c.set_value("crates","count",airdrop_count_today);
	c.set_value("crates","runs",runs_total); c.set_value("crates","at_run",airdrop_at_run)
	c.set_value("offer","id",offer_id); c.set_value("offer","expires",offer_expires); c.set_value("offer","next",next_offer_at); c.set_value("offer","play_day",play_day); c.set_value("offer","play_seconds",play_seconds_today)
	c.set_value("signin","last",signin_last); c.set_value("signin","index",signin_index); c.set_value("signin","shown",signin_shown_day)
	c.set_value("missions","day",daily_day); c.set_value("missions","stats",daily_stats); c.set_value("missions","claimed",daily_claimed); c.set_value("missions","swaps",daily_swaps)
	c.set_value("event","window",event_window); c.set_value("event","stats",event_stats); c.set_value("event","claimed",event_claimed); c.set_value("event","swaps",event_swaps)
	for id in meta_upgrades.keys(): c.set_value("upgrades",id,meta_upgrades[id])
	c.set_value("controls","layout",touch_layout)
	stamina.save_config(c)
	c.set_value("audio","muted",sound.muted if is_instance_valid(sound) else false); c.save(SAVE_PATH)

func _capture() -> void:
	# In-memory unlocks so the review shots can show every survivor, pet and skin; _save()
	# ignores capture runs, so the player's real save is never touched by this.
	for i in range(lobby.PETS.size()): owned_pets[i]=true
	owned_characters[2]=true; owned_characters[3]=true; owned_skins[1]=true
	await get_tree().create_timer(0.4).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://menu-3d.png")
	open_shop(); await get_tree().create_timer(0.35).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://shop-3d.png")
	close_shop(); open_language(); await get_tree().create_timer(0.15).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://languages-3d.png")
	enter_lobby(); select_character(0)
	for i in range(lobby.PETS.size()):
		select_pet(i); await get_tree().create_timer(0.4).timeout; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://diagnostics/pets/lobby-"+str(i)+".png")
	get_viewport().get_texture().get_image().save_png("res://lobby-mason.png")
	select_character(1); await get_tree().create_timer(0.4).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://lobby-riley.png")
	state="cover"; character_choice=1; player.set_character(1); start_run()
	for i in range(4): _spawn_zombie(-7-i*6)
	_spawn_gate(); gates[0].position.z=-12
	_spawn_pickup("ammo",-5); pickups[0].position.x=-2.0
	_spawn_pickup("medkit",-14); pickups[1].position.x=2.2
	_spawn_obstacle("car",2.05,-8.0)
	_spawn_obstacle("fence",-2.05,-4.8)
	aim_direction=Vector3(-0.15,0,-1).normalized(); mouse_position=Vector2(220,390)
	await get_tree().create_timer(0.7).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://gameplay-3d.png")
	get_viewport().get_texture().get_image().save_png("res://diagnostics/obstacles/roadblocks.png")
	player.set_character(0); character_choice=0
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://gameplay-male-hd.png")
	for weapon_id in ["PISTOL","SMG","SHOTGUN","SNIPER","RIFLE"]:
		player.set_weapon(weapon_id)
		await get_tree().create_timer(0.16).timeout; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://diagnostics/weapons_hd/gameplay_"+weapon_id.to_lower()+".png")
	player.set_weapon("PISTOL")
	player.set_character(1); character_choice=1
	for weapon_id in ["PISTOL","SMG","SHOTGUN","SNIPER","RIFLE"]:
		player.set_weapon(weapon_id)
		await get_tree().create_timer(0.16).timeout; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://diagnostics/weapons_hd/gameplay_female_"+weapon_id.to_lower()+".png")
	player.set_weapon("PISTOL")
	touch_controls=true; right_stick=Vector2(-0.15,-1).normalized(); right_knob=right_origin+right_stick*46
	await get_tree().create_timer(0.15).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://gameplay-touch.png")
	touch_controls=false; player.ammo=0; auto_reload=false; player.set_armor(true); player.set_helmet(true)
	_spawn_pickup("armor",-3); pickups[-1].position.x=-2.3
	_spawn_pickup("helmet",-6); pickups[-1].position.x=2.3
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://armor-3d.png")
	hud.visible=false
	state="cover"
	for p in pickups: p.visible=false
	for g in gates: g.visible=false
	for z in zombies: z.visible=false
	camera.position=Vector3(2.8,2.35,8.0); camera.look_at(player.position+Vector3(0,1.05,0))
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://equipment-closeup-3d.png")
	hud.visible=true
	state="playing"
	camera.position=Vector3(0,6.4,13.5); camera.look_at(player.position+Vector3(0,0,-7.0))
	for p in pickups: p.visible=true
	for g in gates: g.visible=true
	for z in zombies: z.visible=true
	_spawn_zombie(-4); zombies[-1].position.x=0; aim_direction=Vector3.FORWARD
	_hit_zombie(zombies[-1],1000,"head",zombies[-1].position+Vector3(0,1.75,0))
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://blood-3d.png")
	_spawn_barrel(); barrels[-1].position=Vector3(1.4,0,-4); _explode(barrels[-1])
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://explosion-3d.png")
	# Ordnance captures use the live game scene, not offline model renders.
	start_run(); _clear_world(); state="playing"; shot_timer=999; auto_reload=false; hint_time=0; touch_controls=true
	player.set_character(0); character_choice=0; aim_direction=Vector3.FORWARD; player.set_aim(aim_direction)
	var pickup_kinds: Array=["grenade","flashbang","launcher","fire_round"]
	var pickup_positions: Array=[Vector3(-2.1,0,-2.0),Vector3(2.1,0,-2.8),Vector3(-1.9,0,-7.0),Vector3(1.9,0,-7.8)]
	for i in range(pickup_kinds.size()):
		_spawn_pickup(pickup_kinds[i],pickup_positions[i].z); pickups[-1].position=pickup_positions[i]
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/pickups.png")
	for pickup in pickups:
		if is_instance_valid(pickup): pickup.queue_free()
	pickups.clear()
	player.set_weapon("LAUNCHER"); player.fire_ammo=4; player.fire_mode=true
	await get_tree().create_timer(0.12).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/launcher-held.png")
	hud.visible=false; state="cover"; camera.position=Vector3(2.8,2.35,8.0); camera.look_at(player.position+Vector3(0,1.05,0))
	await get_tree().create_timer(0.08).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/launcher-closeup.png")
	hud.visible=true; state="playing"; camera.position=Vector3(0,6.4,13.5); camera.look_at(Vector3(0,1.0,-8))
	assert(_fire_launcher())
	await get_tree().create_timer(0.10).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/launcher-projectile.png")
	start_run(); _clear_world(); state="playing"; shot_timer=999; hint_time=0; touch_controls=false
	_spawn_zombie(-6); zombies[-1].position.x=0
	_spawn_ordnance("frag",zombies[-1].position+Vector3(0,0.5,0),Vector3.ZERO).fuse=0.025
	await get_tree().create_timer(0.07).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/frag-explosion.png")
	start_run(); _clear_world(); state="playing"; shot_timer=999; hint_time=0; touch_controls=false
	_spawn_zombie(-6); zombies[-1].position.x=0
	_spawn_ordnance("flash",zombies[-1].position+Vector3(0,0.6,0),Vector3.ZERO).fuse=0.025
	await get_tree().create_timer(0.07).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/flash-detonation.png")
	start_run(); _clear_world(); state="playing"; shot_timer=999; hint_time=0; touch_controls=false
	_spawn_zombie(-6); zombies[-1].position.x=0; zombies[-1].health=200
	_spawn_ordnance("fire",zombies[-1].position+Vector3(0,0.5,0),Vector3.ZERO).fuse=0.025
	await get_tree().create_timer(0.07).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ordnance/fire-detonation.png")
	start_run(); _clear_world(); state="playing"; shot_timer=999; spawn_timer=999; hint_time=0; touch_controls=false
	await get_tree().create_timer(3.4).timeout
	player.position.x=-2.8; player.target_x=-2.8
	_spawn_zombie(-7,"jockey"); zombies[-1].position.x=-1.9
	_spawn_zombie(-10,"banshee"); zombies[-1].position.x=1.8
	_spawn_zombie(-8,"walker"); zombies[-1].position.x=0.2
	var capture_banshee=zombies[1]; var capture_walker=zombies[2]
	capture_walker.position.x=capture_banshee.position.x-0.8; capture_banshee.banshee_pulse_timer=0.0
	_tick_zombies(0.05)
	await get_tree().create_timer(0.18).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/monsters/gameplay-specials.png")
	# Bomber showcase: the pair waddling in, then the blood blast when one bursts.
	start_run(); _clear_world(); state="playing"; shot_timer=999; spawn_timer=999; hint_time=0; touch_controls=false
	player.position.x=0; player.target_x=0
	_spawn_zombie(-7,"bomber"); zombies[-1].position.x=-1.3
	_spawn_zombie(-11,"bomber_female"); zombies[-1].position.x=1.5
	_tick_zombies(0.05)
	await get_tree().create_timer(0.18).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/monsters/bomber-pair.png")
	_bomber_blast(zombies[-2].position)
	await get_tree().create_timer(0.10).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/monsters/bomber-blast.png")
	# Chase segment showcase: the beast closing in behind the survivor, warning HUD on.
	start_run(); _clear_world(); state="playing"; shot_timer=999; spawn_timer=999; hint_time=0; touch_controls=false
	player.position.x=0; player.target_x=0; aim_direction=Vector3.FORWARD; player.set_aim(aim_direction)
	distance=401.0; _tick_chase(0.1)
	if is_instance_valid(chaser):
		chase_gap=6.5; chaser.position.z=player.position.z+chase_gap
		await get_tree().create_timer(1.2).timeout; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://diagnostics/chase-segment.png")
	chase_active=false
	if is_instance_valid(chaser): chaser.queue_free(); chaser=null
	player.health=0; _end_run()
	await get_tree().create_timer(0.10).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/monsters/gameover-revival.png")
	# UI restyle captures: daily check-in, lobby, tasks, store.
	go_to_lobby(); await get_tree().create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	if state!="signin": open_signin()
	await get_tree().create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-restyle-signin.png")
	close_signin(); await get_tree().create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-restyle-lobby.png")
	open_tasks(); await get_tree().create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-restyle-tasks.png")
	close_tasks(); open_store(); await get_tree().create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-restyle-store.png")
	close_store()
	# War-room map table, opened from the lobby's map button: default view, then swiped right.
	go_to_lobby(); await get_tree().create_timer(0.3).timeout
	open_map(); await get_tree().create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-map-table.png")
	map_scene.pan_x=1.6; await get_tree().create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-map-table-right.png")
	close_map()
	go_to_lobby(); await get_tree().create_timer(0.3).timeout
	# New survivors: Riley (regenerated) and Maya (new) standing in the lobby; Maya leads the intro chase below.
	select_character(1); await get_tree().create_timer(0.4).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-riley-lobby.png")
	_iap_grant("char_maya","capture") # capture rig owns everyone; the store flow is what enforces payment
	select_character(3); await get_tree().create_timer(0.4).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/ui-maya-lobby.png")
	start_run(); _begin_intro(); shot_timer=999; hint_time=0; touch_controls=false
	await get_tree().create_timer(0.65).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/intro/intro-horde.png")
	await get_tree().create_timer(1.55).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/intro/intro-turn.png")
	await get_tree().create_timer(1.65).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/intro/intro-chase.png")
	_finish_intro()
	print("CAPTURE_3D_SAVED menu shop languages gameplay armor blood explosion ordnance specials revival intro")
	get_tree().quit()

## Darius (third survivor) review shots only: lobby card, opening chase, and a live run.
## Additive — never overwrites the existing marketing captures.
func _capture_medic() -> void:
	owned_characters[2]=true; enter_lobby(); select_character(2)
	await get_tree().create_timer(0.6).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/lobby-darius.png")
	character_choice=2; player.set_character(2); start_run(); _begin_intro(); shot_timer=999; hint_time=0; touch_controls=false
	await get_tree().create_timer(1.2).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/chase-darius.png")
	_finish_intro()
	for i in range(3): _spawn_zombie(-7-i*6)
	_spawn_pickup("medkit",-6); pickups[-1].position.x=1.8
	await get_tree().create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/run-darius.png")
	print("CAPTURE_MEDIC_SAVED lobby chase run")
	get_tree().quit()

func _capture_bike() -> void:
	# Riding shot for the motorcycle: default survivor on the bike, horde ahead, so the
	# seated pose, the wheels and the durability bar are all visible in one frame.
	character_choice=0; player.set_character(0); start_run(); _begin_intro(); shot_timer=999; hint_time=0; touch_controls=false
	_finish_intro()
	for i in range(3): _spawn_zombie(-7-i*6)
	player.mount_vehicle("BIKE")
	await get_tree().create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/run-bike.png")==OK)
	# Close top-down view to verify seat/tank clipping.
	capture_close_cam=true
	camera.position=player.position+Vector3(0,3.2,2.8); camera.look_at(player.position+Vector3(0,0.9,0))
	await get_tree().create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/run-bike-close.png")==OK)
	print("CAPTURE_BIKE_SAVED")
	get_tree().quit()

func _capture_car() -> void:
	# Same shot for the cruiser: seat fit is per-vehicle, verify separately.
	character_choice=0; player.set_character(0); start_run(); _begin_intro(); shot_timer=999; hint_time=0; touch_controls=false
	_finish_intro()
	for i in range(3): _spawn_zombie(-7-i*6)
	player.mount_vehicle("CRUISER")
	await get_tree().create_timer(0.5).timeout; await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/run-car.png")==OK)
	capture_close_cam=true
	camera.position=player.position+Vector3(0,3.6,3.2); camera.look_at(player.position+Vector3(0,1.2,0))
	await get_tree().create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/medic/run-car-close.png")==OK)
	print("CAPTURE_CAR_SAVED")
	get_tree().quit()

func _lootbox_test() -> void:
	# Exercise the actual shop button and case-button hit rectangles. _save() is disabled
	# for this flag, so the player's real wallet and upgrades are never written.
	var saved_coins: int=bank_coins
	var saved_vouchers: int=bank_vouchers
	var saved_upgrades: Dictionary=meta_upgrades.duplicate(true)
	var saved_pets: Dictionary=owned_pets.duplicate()
	meta_upgrades=ShopCatalog.default_levels()
	for i in range(lobby.PETS.size()): owned_pets[i]=true # the 1% dog jackpot stays out of this deterministic upgrade check
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://diagnostics/lootbox"))
	open_shop(); bank_coins=200; bank_vouchers=0
	_pointer_down(Rect2(404,24,112,48).get_center())
	assert(state=="lootbox" and lootbox_scene.visible and not shop_truck.visible)
	await get_tree().create_timer(0.25).timeout; await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/lootbox/case-closed.png")==OK)
	var levels_before:=0
	for item in shop_items: levels_before+=int(meta_upgrades.get(item.id,0))
	_pointer_down(LOOTBOX_GOLD_RECT.get_center())
	assert(bank_coins==100 and lootbox_scene.opening and not lootbox_reward_title.is_empty())
	var levels_after:=0
	for item in shop_items: levels_after+=int(meta_upgrades.get(item.id,0))
	assert(levels_after==levels_before+1)
	_pointer_down(LOOTBOX_GOLD_RECT.get_center())
	assert(bank_coins==100) # a double tap cannot charge twice during the animation
	await get_tree().create_timer(2.45).timeout; await RenderingServer.frame_post_draw
	assert(lootbox_scene.revealed and not lootbox_scene.opening)
	assert(get_viewport().get_texture().get_image().save_png("res://diagnostics/lootbox/case-open.png")==OK)
	bank_coins=0
	_pointer_down(LOOTBOX_GOLD_RECT.get_center())
	assert(bank_coins==0 and lootbox_message==ShopText.text(language_code,"case_no_coins"))
	assert(state=="resource_pack" and resource_pack_id=="coins_1" and resource_pack_return_state=="lootbox")
	_pointer_down(OFFER_CLOSE.get_center()); assert(state=="lootbox")
	# voucher path: 1 voucher per draw
	bank_vouchers=2
	levels_before=levels_after
	_pointer_down(LOOTBOX_VOUCHER_RECT.get_center())
	assert(bank_vouchers==1 and lootbox_scene.opening)
	levels_after=levels_before+1
	# (levels_after computed before animation finishes; reward already committed)
	_pointer_down(LOOTBOX_VOUCHER_RECT.get_center())
	assert(bank_vouchers==1) # double tap safe
	await get_tree().create_timer(2.45).timeout; await RenderingServer.frame_post_draw
	assert(lootbox_scene.revealed and not lootbox_scene.opening)
	bank_vouchers=0
	_pointer_down(LOOTBOX_VOUCHER_RECT.get_center())
	assert(bank_vouchers==0 and lootbox_message==ShopText.text(language_code,"case_no_voucher"))
	assert(state=="resource_pack" and resource_pack_id=="vouchers_1" and resource_pack_return_state=="lootbox")
	_pointer_down(OFFER_CLOSE.get_center()); assert(state=="lootbox")
	_pointer_down(Rect2(24,24,100,48).get_center())
	assert(state=="shop" and shop_truck.visible and not lootbox_scene.visible)
	bank_coins=saved_coins; bank_vouchers=saved_vouchers; meta_upgrades=saved_upgrades; owned_pets=saved_pets
	print("LOOTBOX_TEST_PASS shop_button debit=100 gold +1 voucher upgrade=+1 double_tap=safe animation=revealed insufficient_funds=blocked close=shop save=untouched")
	get_tree().quit()

func _smoke_test() -> void:
	meta_upgrades=ShopCatalog.default_levels(); bank_coins=0
	assert(Localization.LANGUAGES.size()==20)
	assert(sound.streams.get("explosion")!=null and sound.streams.get("zombie")!=null)
	assert(sound.streams.get("smg")!=null and sound.streams["smg"].get_length()>0.2)
	intro_seen=false  # a brand-new player: tapping the cover begins the opening run
	assert(state=="cover")  # the classic title poster greets every launch
	_pointer_down(Vector2(270,480)); assert(state in ["intro","playing"])  # tap anywhere to start
	_clear_world(); enter_lobby(); assert(state=="character_select")
	_lobby_tap(lobby_card_rect(1).get_center()); assert(character_choice==1 and player.character==1)
	# Darius is a paid survivor: a locked tap only explains, then the purchase unlocks him
	_lobby_tap(lobby_card_rect(2).get_center()); assert(character_choice==1 and lobby_toast>0.0 and lobby_toast_key=="char_locked")
	assert(_iap_grant("char_darius","smoke") and character_owned(2))
	_lobby_tap(lobby_card_rect(2).get_center()); assert(character_choice==2 and player.character==2)
	assert(player.heal_scale()==2.0) # Darius the paramedic: every healing effect is doubled
	# Jian is the newest paid survivor: locked until purchased, then his scavenger perks apply
	assert(not character_owned(4))
	assert(_iap_grant("char_maya","smoke") and character_owned(3))
	assert(player.scavenger_ammo_scale()==1.0) # perks key off the PLAYED character, not ownership
	_lobby_tap(lobby_card_rect(4).get_center()); assert(character_choice==4 and player.character==4)
	assert(player.scavenger_ammo_scale()==1.5 and player.scavenger_coin_scale()==1.25)
	_lobby_tap(lobby_card_rect(0).get_center()); assert(character_choice==0 and player.character==0)
	assert(player.heal_scale()==1.0)
	lobby_scroll=0.0; assert(not lobby_page_visible(-1) and lobby_page_visible(1))
	_pointer_down(lobby_page_rect(1).get_center()); assert(lobby_scroll>0.0 and lobby_page_visible(-1))
	_pointer_down(lobby_page_rect(-1).get_center()); assert(lobby_scroll==0.0)
	_lobby_tap(lobby_card_rect(1).get_center()); assert(character_choice==1)
	_lobby_tap(lobby_card_rect(0).get_center()); assert(character_choice==0)
	await get_tree().process_frame; assert(lobby.visible and is_instance_valid(lobby.actor))
	_pointer_down(lobby_tab_rect(1).get_center()); assert(lobby_tab==1)
	pet_equipped=false; owned_pets={}
	# locked dog: previewed, never equipped
	_lobby_tap(lobby_card_rect(0).get_center()); assert(not pet_equipped and lobby_toast>0.0 and lobby_toast_key=="pet_locked")
	_spawn_companion(); assert(not is_instance_valid(companion_pet))
	# ...but it can also be bought outright in the store
	assert(_iap_grant("pet_0","smoke") and pet_owned(0) and pack_owned("pet_0"))
	_lobby_tap(lobby_card_rect(0).get_center()); assert(pet_equipped and pet_choice==0)
	pet_equipped=false; owned_pets={}
	for i in range(lobby.PETS.size()): owned_pets[i]=true
	for i in range(lobby.PETS.size()):
		_lobby_tap(lobby_card_rect(i).get_center()); assert(pet_equipped and pet_choice==i and lobby.pet_path==lobby.PETS[i].asset)
		await get_tree().process_frame; assert(is_instance_valid(lobby.pet))
	# tapping the equipped dog again sends it home: no dog in the intro or the run
	var last_pet:=lobby_card_rect(lobby.PETS.size()-1).get_center()
	_lobby_tap(last_pet); assert(not pet_equipped); await get_tree().process_frame; assert(not is_instance_valid(lobby.pet))
	_spawn_companion(); assert(not is_instance_valid(companion_pet))
	_lobby_tap(last_pet); assert(pet_equipped)
	_pointer_down(lobby_tab_rect(0).get_center()); assert(lobby_tab==0)
	# outfit skins: Maya is a paid survivor; her default look comes with her, the tactical
	# outfit is a separate one-time purchase. Locked taps explain, never select.
	set_lobby_tab(2); assert(lobby_tab==2 and lobby_item_count()>=lobby.SKINS.size())
	_lobby_tap(lobby_card_rect(0).get_center()); assert(character_choice!=3 and lobby_toast_key=="char_locked")
	assert(_iap_grant("char_maya","smoke") and character_owned(3))
	_lobby_tap(lobby_card_rect(1).get_center()); assert(character_choice!=3 and lobby_toast_key=="skin_locked")
	assert(_iap_grant("skin_maya_tactical","smoke") and skin_owned(1))
	_lobby_tap(lobby_card_rect(1).get_center())
	assert(character_choice==3 and selected_skin_index()==1 and "tactical" in player.character_asset_override)
	await get_tree().process_frame; assert(is_instance_valid(lobby.actor) and lobby.actor_asset==String(lobby.SKINS[1].asset))
	player.health=player.max_health*0.5; var maya_regen: float=player.instinct_regen_rate(); assert(maya_regen>0.0) # perk survives the skin swap (regen only ticks while hurt)
	player.health=player.max_health; assert(player.instinct_regen_rate()==0.0)
	_lobby_tap(lobby_card_rect(0).get_center())
	assert(selected_skin_index()==0 and player.character_asset_override==String(lobby.SKINS[0].asset))
	select_character(0); assert(selected_skin_index()==-1 and player.character_asset_override=="")
	set_lobby_tab(0); assert(lobby_tab==0)
	# the supply shop is reachable from the main screen
	_pointer_down(SIDE_SHOP.get_center()); assert(state=="shop")
	_pointer_down(SHOP_STORE_BTN.get_center()); assert(state=="store" and store_return_state=="shop"); close_store(); assert(state=="shop")
	close_shop(); assert(state=="character_select")
	_pointer_down(SIDE_STORE.get_center()); assert(state=="store"); close_store(); assert(state=="character_select")
	# mailbox: welcome gift claims once
	mail_claimed={}; var mc: int=bank_coins; var mv: int=bank_vouchers; var ms2: int=stamina.value
	_pointer_down(SIDE_MAIL.get_center()); assert(state=="mail" and mails.size()>=1 and mail_unclaimed()==1)
	_pointer_down(mail_row(0).get_center()); _letter_release(mail_row(0).get_center()); assert(mail_open==0 and bank_coins==mc)
	mail_text_h=900.0; assert(letter_max_scroll()>0.0); mail_scroll=letter_max_scroll()
	var cr: Rect2=letter_claim_rect(); assert(LETTER_VIEW.has_point(cr.get_center()))
	_pointer_down(cr.get_center()); _letter_release(cr.get_center()); assert(bank_coins==mc+200 and bank_vouchers==mv+3 and stamina.value==ms2+50 and mail_unclaimed()==0)
	_pointer_down(cr.get_center()); _letter_release(cr.get_center()); assert(bank_coins==mc+200)
	_pointer_down(Vector2(60,48)); assert(state=="mail" and mail_open==-1)
	remote_mail=[{"id":"gift2","title":{"en":"Gift","zh_CN":"福利"},"body":"x","coins":50,"vouchers":0},{"id":"old","coins":9,"until":"2000-01-01"}]
	refresh_mail(); assert(mails.size()==2 and mail_unclaimed()==1); remote_mail=[]
	_pointer_down(Vector2(60,48)); assert(state=="character_select")
	# airdrop: one ad a day; the reveal closes on any tap; then "come back tomorrow"
	airdrop_day=""; var ac: int=bank_coins+bank_vouchers*1000
	assert(airdrop_available()); _pointer_down(AIRDROP_RECT.get_center()); assert(ad_pending=="airdrop")
	await get_tree().create_timer(0.55).timeout
	assert(state=="airdrop" and not airdrop_available() and bank_coins+bank_vouchers*1000>ac)
	_pointer_down(Vector2(270,480)); assert(state=="character_select")
	_pointer_down(AIRDROP_RECT.get_center()); assert(ad_pending=="" and state=="character_select")
	# backpack: coins always, vouchers only when held
	var keep_v: int=bank_vouchers; bank_vouchers=0
	_pointer_down(SIDE_BAG.get_center()); assert(state=="bag" and bag_items().size()==1)
	bank_vouchers=3; assert(bag_items().size()==2 and int(bag_items()[1].count)==3)
	_pointer_down(Vector2(60,48)); assert(state=="character_select"); bank_vouchers=keep_v
	state="cover"
	_pointer_down(Vector2(490,45)); assert(state=="settings")
	_pointer_down(Vector2(SLIDER_MUSIC.position.x+SLIDER_MUSIC.size.x*0.5,SLIDER_MUSIC.get_center().y)); volume_drag=""
	assert(absf(sound.music_volume-0.5)<0.06 and AudioServer.get_bus_index("Music")>=0)
	sound.music_volume=0.8; sound.apply_volumes()
	_pointer_down(Vector2(270,840)); assert(state=="cover")
	# The lobby is the hub now: survivors, shop and cases all live on its side bar.
	go_to_lobby(); assert(state=="character_select")
	var skeleton:=player.model.find_child("Skeleton3D",true,false) as Skeleton3D
	assert(is_instance_valid(skeleton) and skeleton.get_bone_count()>=15)
	open_shop(); assert(state=="shop" and shop_truck.visible); bank_coins=100; assert(buy_item("medical")); assert(bank_coins==60)
	select_shop_item(4); assert(shop_items[shop_index].id=="w_shotgun" and shop_truck.focus_id=="w_shotgun")
	bank_coins=200; assert(buy_item("w_shotgun")); player.apply_meta(meta_upgrades); player.set_weapon("SHOTGUN"); assert(is_equal_approx(player.damage,30.0*player.damage_scale*1.12))
	meta_upgrades["w_shotgun"]=0
	open_lootbox(); assert(state=="lootbox"); close_lootbox(); assert(state=="shop")
	# Store: + opens it, a tap on a pack grants it in test runs, once-only packs stay once-only.
	var shop_plus: Rect2=wallet_layout_shop(WALLET_SHOP).coin_plus
	_pointer_down(shop_plus.get_center()); assert(state=="store" and store_return_state=="shop")
	assert(StoreCatalog.currency_for_locale("zh_CN")=="CNY" and StoreCatalog.currency_for_locale("ja_JP")=="JPY" and StoreCatalog.currency_for_locale("de_DE")=="EUR" and StoreCatalog.currency_for_locale("en")=="USD")
	assert(StoreCatalog.price_text("CNY",0)=="¥6" and StoreCatalog.price_text("USD",3)=="$9.99" and StoreCatalog.price_text("EUR",2)=="4,99 €" and StoreCatalog.price_text("KRW",3)=="₩14,000")
	offer_id=""; offer_expires=0; store_owned.clear(); owned_characters={}  # ignore whatever a local save (or the lobby section above) left behind
	var coins_before: int=bank_coins; var v_before: int=bank_vouchers
	var starter: Dictionary=store_layout()[1]; assert(starter.pack.id=="bundle_starter")
	var tap: Vector2=store_screen_rect(starter).get_center()
	_pointer_down(tap); _store_release(tap); assert(bank_coins==coins_before+1000 and bank_vouchers==v_before+1)
	_pointer_down(tap); _store_release(tap); assert(bank_coins==coins_before+1000)
	store_scroll=store_max_scroll(); assert(store_max_scroll()>0.0)
	_pointer_down(Vector2(70,48)); assert(state=="shop")
	bank_coins=coins_before; bank_vouchers=v_before; store_owned.clear()
	# IAP: only a verified transaction grants; cancel / pending / failure grant nothing; one grant per transaction
	assert(iap.mode=="sim" and IapScript.sim_allowed())
	# Catalog <-> App Store product IDs stay in sync: every purchasable pack resolves to a
	# product ID and back, and every registered product ID belongs to a real pack.
	for p in StoreCatalog.PACKS+StoreCatalog.OFFERS:
		assert(iap.product_id(p.id)!="" and iap.pack_for(iap.product_id(p.id))==p.id)
	for k in iap.PRODUCTS:
		assert(not pack_by_id(k).is_empty())
	var ic: int=bank_coins
	iap.sim_next="cancelled"; buy_pack("coins_2"); assert(bank_coins==ic)
	iap.sim_next="pending"; buy_pack("coins_2"); assert(bank_coins==ic)
	iap.sim_next="failed"; buy_pack("coins_2"); assert(bank_coins==ic and state=="payfail"); close_payfail()
	buy_pack("coins_2"); assert(bank_coins==ic+1650)
	var granted_tx: String=String(iap.ledger.keys()[-1])
	iap._deliver("coins_2",granted_tx,false); assert(bank_coins==ic+1650)   # same transaction again: ignored
	assert(iap_ledger.has(granted_tx))
	# remove ads: non-consumable, rewarded ads are skipped
	remove_ads=false; buy_pack("removeads"); assert(remove_ads and pack_owned("removeads"))
	assert(not buy_pack("removeads"))
	iap.restore(); assert(remove_ads)
	remove_ads=false
	# unlockable survivor: non-consumable bought once through the same store flow
	assert(not character_owned(2)); buy_pack("char_darius"); assert(character_owned(2) and pack_owned("char_darius"))
	bank_coins=coins_before; bank_vouchers=v_before
	# Limited offer: not before the gap, not after a long day, pops and can be bought once.
	var keep_state: String=state
	next_offer_at=now_unix()+3600; assert(not maybe_show_offer())
	offer_id=""; assert(maybe_show_offer(true) and state=="offer" and offer_active())
	assert(next_offer_at>=now_unix()+48*3600-5 and next_offer_at<=now_unix()+72*3600+5)
	var o_coins: int=bank_coins; var o_pack: Dictionary=StoreCatalog.offer(offer_id)
	_pointer_down(OFFER_BUY.get_center()); assert(bank_coins==o_coins+int(o_pack.coins) and not offer_active() and state==keep_state)
	assert(StoreCatalog.discount(StoreCatalog.offer("offer_supply"))==75)
	bank_coins=coins_before; bank_vouchers=v_before
	# Failed top-up: popup over the store, nothing granted; Retry buys again, Close goes back.
	open_store(); var c_fail: int=bank_coins
	purchase_failed("coins_2"); assert(state=="payfail" and payfail_return_state=="store" and bank_coins==c_fail)
	_pointer_down(PAYFAIL_CLOSE.get_center()); assert(state=="store")
	purchase_failed("coins_2"); _pointer_down(PAYFAIL_RETRY.get_center()); assert(state=="store" and bank_coins==c_fail+1650)
	close_store(); bank_coins=coins_before
	# Check-in: one claim a day, the cycle moves on; missions count kills/runs and pay out once.
	signin_last=""; signin_index=0; var c0: int=bank_coins
	open_signin(); assert(state=="signin"); _pointer_down(SIGNIN_CLAIM.get_center())
	assert(bank_coins==c0+50 and signin_index==1 and not signin_available())
	_pointer_down(SIGNIN_CLAIM.get_center()); assert(bank_coins==c0+50)
	# watching the ad pays the day twice over (desktop builds reward straight away)
	signin_last=""; var c2: int=bank_coins; var day: Dictionary=ProgressCatalog.SIGNIN[signin_index]
	_on_ad_rewarded("signin_double"); assert(bank_coins==c2+int(day.coins)*2 and not signin_available())
	close_signin()
	daily_day=""; _roll_progress(); var dm: Dictionary=daily_missions()[0]
	assert(not mission_ready(dm,true)); _progress(String(dm.stat),int(dm.goal)); assert(mission_ready(dm,true))
	open_tasks(); tasks_tab=0; var c1: int=bank_coins
	_pointer_down(task_button(task_rows()[0].rect).get_center()); assert(bank_coins==c1+int(dm.coins) and mission_claimed(dm,true))
	_pointer_down(task_button(task_rows()[0].rect).get_center()); assert(bank_coins==c1+int(dm.coins))
	# swap by ad: a claimed mission can't be swapped; an open one changes, and only after the reward
	assert(not can_swap_mission(0,true))
	var swap_before: String=String(daily_missions()[1].id)
	if can_swap_mission(1,true):
		_on_ad_cancelled("swap:daily:1"); assert(String(daily_missions()[1].id)==swap_before)
		_on_ad_rewarded("swap:daily:1"); assert(String(daily_missions()[1].id)!=swap_before)
	daily_swaps.clear()
	assert(event_missions().size()==ProgressCatalog.EVENT_COUNT and event_seconds_left()>0)
	close_tasks(); bank_coins=coins_before; bank_vouchers=v_before
	for code in ["en","zh_CN","ja","ar","th"]: assert(ShopText.text(code,"n_shotgun")!="n_shotgun")
	close_shop(); start_run(); assert(state=="playing" and player.health==115 and is_instance_valid(companion_pet))
	# Bites scale with the breed: the doberman only wounds a walker, the mastiff kills it,
	# and no bite finishes a Juggernaut.
	var breed_before: int=companion_pet.breed
	_spawn_zombie(-2,"walker"); var bite_target=zombies[-1]; var hp_before: float=bite_target.health
	companion_pet.breed=0; companion_pet.position=bite_target.position+Vector3(0,0,1.0); companion_pet.cooldown=0.0; companion_pet.target=bite_target
	companion_pet.tick(0.02); assert(zombies.has(bite_target) and is_equal_approx(bite_target.health,hp_before-16.0))
	companion_pet.breed=3; companion_pet.cooldown=0.0; companion_pet.target=bite_target; companion_pet.position=bite_target.position+Vector3(0,0,1.0)
	companion_pet.tick(0.02); assert(not zombies.has(bite_target))
	_spawn_zombie(-2,"brute"); var brute=zombies[-1]; brute.health=30.0
	companion_pet.cooldown=0.0; companion_pet.target=brute; companion_pet.position=brute.position+Vector3(0,0,1.0)
	companion_pet.tick(0.02); assert(zombies.has(brute) and is_equal_approx(brute.health,1.0))
	zombies.erase(brute); brute.queue_free(); companion_pet.breed=breed_before
	touch_controls=true; right_stick=Vector2.ZERO; assert(_wants_to_fire()); touch_controls=false
	var old: float=player.damage; player.apply_upgrade("damage"); assert(player.damage>old)
	player.target_x=100; await get_tree().create_timer(0.2).timeout; assert(player.position.x<=3.15)
	player.apply_upgrade("smg"); assert(player.weapon=="SMG" and player.ammo==36)
	var before: int=player.ammo; assert(_fire()); assert(player.ammo==before-1 and bullets.size()>0 and sound.last_id=="smg")
	player.apply_upgrade("shotgun"); assert(player.weapon=="SHOTGUN" and player.projectile_count==7)
	var old_bullets: int=bullets.size(); assert(_fire()); assert(bullets.size()==old_bullets+7 and sound.last_id=="shotgun")
	player.apply_upgrade("pistol"); _spawn_zombie(-20); aim_target=zombies[-1]; aim_point=aim_target.position+Vector3(0,1,0)
	assert(_fire() and sound.last_id=="pistol_far")
	aim_target.position=player.position+Vector3(0,0,-6); assert(_fire() and sound.last_id=="pistol_near")
	player.apply_upgrade("sniper"); assert(player.weapon=="SNIPER" and player.magazine_size==5 and player.pierce==2)
	auto_reload=false; player.ammo=0; assert(request_reload()); assert(player.reloading)
	assert(player.animation_player.current_animation==player._anim_name("Reload_Gun") and player.animation_player.is_playing())
	await get_tree().create_timer(player.reload_duration+0.15).timeout; assert(not player.reloading and player.ammo>0)
	assert(player.animation_player.current_animation==player.run_clip and player.animation_player.is_playing())
	for weapon_id in ["PISTOL","SMG","SHOTGUN","SNIPER","RIFLE","LAUNCHER"]:
		player.set_weapon(weapon_id); player.ammo-=1
		assert(player.request_reload() and player.animation_player.current_animation==player._anim_name("Reload_Gun"))
		player.finish_reload(); assert(player.animation_player.current_animation==player.run_clip)
	_spawn_gate(); assert(gates.size()==1 and gates[0].left.id=="damage" and gates[0].right.id=="rate")
	# Roguelike gates: rarity mix, three choices past 500 m, pity, scaled effects.
	var keep_dist: float=distance; var counts:=[0,0,0,0]
	for i in range(2000): counts[_roll_rarity()]+=1
	assert(counts[0]>counts[1] and counts[1]>counts[2] and counts[2]>counts[3] and counts[3]>0)
	distance=600.0; new_gate_index=5; var three: Array=_roll_gate_options(); assert(three.size()==3)
	var ids:={}
	for o in three: ids[o.id]=true
	assert(ids.size()==3)
	distance=100.0; assert(_roll_gate_options().size()==2)
	gates_since_epic=PITY_GATES-1; var forced: Array=_roll_gate_options(); var top:=0
	for o in forced: top=maxi(top,int(o.rarity))
	assert(top>=2 and gates_since_epic==0)
	var g3=GateScript.new(); g3.setup([_gate_option("damage",3),_gate_option("rate",1),_gate_option("heal",0)],"zh_CN"); add_child(g3)
	assert(g3.lane_of(-2.5)==0 and g3.lane_of(0.0)==1 and g3.lane_of(2.5)==2); g3.queue_free()
	var dmg0: float=player.damage; player.apply_upgrade("damage",50.0); assert(absf(player.damage-dmg0*1.5)<0.01); player.damage=dmg0
	# Every gate buff must have a real, measurable effect (no display-only buffs).
	player.reset(); player.set_weapon("RIFLE")
	assert(not _buff_useful("crit_damage",2) and _buff_useful("crit_chance",2))
	var pp=player
	var probe:={
		"max_hp":func(): return pp.max_health, "regen":func(): return pp.regen, "kill_heal":func(): return pp.kill_heal,
		"dmg_reduce":func(): return pp.dmg_reduce, "shield":func(): return pp.shield, "move":func(): return pp.move_mult,
		"damage":func(): return pp.damage, "rate":func(): return -pp.fire_interval, "bullet_speed":func(): return pp.bullet_speed,
		"crit_chance":func(): return pp.crit_chance, "magazine":func(): return pp.magazine_size, "reserve":func(): return pp.reserve_ammo,
		"reload":func(): return -pp.reload_duration, "pierce":func(): return pp.pierce, "multishot":func(): return pp.projectile_count,
		"split":func(): return pp.bullet_split, "explode":func(): return pp.explode_chance, "burn":func(): return pp.burn_dps,
		"poison":func(): return pp.poison_dps, "shock":func(): return pp.shock_chance, "coins":func(): return pp.coin_mult,
		"drop":func(): return pp.drop_chance, "ammo_return":func(): return pp.ammo_return, "pickup_range":func(): return pp.pickup_bonus}
	for id in probe:
		var probe_before=probe[id].call(); player.apply_upgrade(id,BuffCatalog.value_of(id,2)); assert(probe[id].call()>probe_before,id)
	player.apply_upgrade("crit_damage",40.0); assert(player.crit_mult>1.5)
	player.health=50.0; player.apply_upgrade("heal",30.0); assert(player.health==80.0)
	# Darius (paramedic): heal gates restore double.
	player.set_character(2)
	player.health=20.0; player.apply_upgrade("heal",30.0); assert(player.health==80.0)
	player.set_character(0); player.health=player.max_health
	# stats survive a gun change
	var mag_scaled: int=player.magazine_size; player.set_weapon("SMG"); assert(player.magazine_size>36 and player.pierce>0 and player.bullet_split>0)
	# shield + damage reduction soak a hit
	player.health=100.0; player.shield=10.0; player.dmg_reduce=0.5; player.take_damage(40.0); assert(player.shield==0.0 and player.health==90.0)
	# movement speed scrolls the whole road faster
	assert(player.move_mult>1.0)
	# burn ticks damage on a zombie; split spawns fragments
	_spawn_zombie(player.position.z-6.0,"walker"); var zb=zombies[zombies.size()-1]; zb.health=500.0
	zb.set_meta("burn",[20.0,2.5]); buff_tick=0.5; _tick_buffs(0.0); assert(zb.health<500.0)
	var nb: int=bullets.size(); var fake=BulletScript.new(); fake.velocity=Vector3(0,0,-30); fake.damage=10.0; add_child(fake)
	_on_bullet_hit(zb,fake,zb.position+Vector3(0,1,0)); assert(bullets.size()>nb)
	fake.queue_free()
	for nbul in bullets.slice(nb): if is_instance_valid(nbul): nbul.queue_free()
	bullets.resize(nb); zombies.erase(zb); zb.queue_free()
	player.reset()
	distance=keep_dist
	state="playing"; player.set_weapon("SMG"); player.ammo=5; player.reserve_ammo=10
	assert(swap_weapon() and player.weapon=="PISTOL" and player.swap_target()=="SMG")
	assert(swap_weapon() and player.weapon=="SMG" and player.ammo==5 and player.reserve_ammo==10)
	print("SMOKE_SWAP_OK")
	# Weapon crates: weapons now only come from shooting crates down to 0.
	player.set_weapon("RIFLE")
	var crate:=WeaponCrateScript.new(); crate.setup("SHOTGUN",3); crate.position=Vector3(1.5,0,player.position.z-6); add_child(crate); crates.append(crate)
	await get_tree().process_frame
	assert(crate.counter.text=="3" and crate.bullet_hits(crate.position+Vector3(0,0.5,0.4)))
	assert(not crate.take_hit(1) and crate.counter.text=="2")
	crate.take_hit(1); assert(crate.take_hit(1) and crate.broken); _break_crate(crate)
	# Crate health is damage, sized for 3-8 shots of the current gun.
	var keep_rt: float=run_time; run_time=0.0
	var hp0: int=_crate_hits("SHOTGUN"); var shots0: float=hp0/(player.damage*maxf(1.0,player.projectile_count*0.6))
	assert(shots0>=2.5 and shots0<=8.5 and hp0%5==0)
	run_time=600.0; var hp1: int=_crate_hits("SNIPER"); assert(hp1>=hp0 and hp1/(player.damage*maxf(1.0,player.projectile_count*0.6))<=8.5)
	run_time=0.0; assert(_crate_hits("PET_1")>_crate_hits("SMG"))
	run_time=keep_rt
	for step in range(40): _tick_crates(0.02)
	assert(player.weapon=="SHOTGUN" and not crates.has(crate))
	print("SMOKE_CRATE_OK")
	# Vehicle crate: break it and the survivor rides — the bike soaks damage, rams zombies
	# (full kill credit), smokes when nearly done and breaks apart at zero durability.
	var bike_crate:=WeaponCrateScript.new(); bike_crate.setup("BIKE",5); bike_crate.position=Vector3(-1.5,0,player.position.z-6); add_child(bike_crate); crates.append(bike_crate)
	await get_tree().process_frame
	assert(bike_crate.display_name()!="" and bike_crate.bullet_hits(bike_crate.position+Vector3(0,0.5,0.4)))
	while not bike_crate.take_hit(1): pass
	_break_crate(bike_crate)
	assert(player.vehicle=="BIKE" and player.vehicle_durability==player.BIKE_DURABILITY)
	crates.erase(bike_crate); bike_crate.queue_free()
	var health_before_ride: float=player.health
	_hurt_player(30.0); assert(player.health==health_before_ride and player.vehicle_durability==70.0)
	_spawn_zombie(player.position.z-0.2,"walker"); var rammed=zombies[-1]; rammed.position.x=player.position.x
	_tick_zombies(0.01); assert(not zombies.has(rammed) and player.vehicle_durability<70.0)
	player.vehicle_durability=1.0; _tick_vehicle(1.0); assert(player.vehicle=="" and player.health==health_before_ride)
	print("SMOKE_BIKE_OK")
	# The district-14 crater is a hole: it shoves the survivor out and the horde never
	# crosses it (soft steering plus the hard rim).
	var crater_cz: float=_crater_z(); assert(crater_cz!=INF)
	var crater_save:=Vector2(player.position.x,player.position.z)
	player.position=Vector3(CRATER_X,player.position.y,crater_cz); player.target_x=CRATER_X
	_resolve_crater_collision()
	assert(absf(player.position.x-CRATER_X)>=CRATER_RADIUS+0.31)
	player.position.x=crater_save.x; player.position.z=crater_save.y; player.target_x=crater_save.x
	_spawn_zombie(-6.0); var crater_zombie=zombies[-1]; crater_zombie.position=Vector3(CRATER_X,0,crater_cz-1.2)
	for step in range(150):
		crater_zombie.tick(1.0/60.0); _avoid_crater(crater_zombie,1.0/60.0)
		var cd: float=Vector2(crater_zombie.position.x-CRATER_X,crater_zombie.position.z-crater_cz).length()
		assert(cd>=CRATER_RADIUS+crater_zombie.radius-0.02)
	zombies.erase(crater_zombie); crater_zombie.queue_free()
	_spawn_barrel(); var collision_barrel=barrels[-1]; collision_barrel.position=player.position+Vector3(0,0,-0.2)
	_resolve_barrel_collision(); assert(_flat_distance(player.position,collision_barrel.position)>=collision_barrel.radius+0.39)
	collision_barrel.position=Vector3(0,0,-4); await get_tree().process_frame
	mouse_position=camera.unproject_position(collision_barrel.global_position+Vector3(0,collision_barrel.height*0.5,0)); _update_mouse_aim()
	assert(aim_target==collision_barrel and barrels.has(aim_target))
	_spawn_zombie(-6); var avoidance_zombie=zombies[-1]
	avoidance_zombie.position=collision_barrel.position+Vector3(0,0,-1.0)
	for step in range(120):
		avoidance_zombie.tick(1.0/60.0); _avoid_barrels(avoidance_zombie,1.0/60.0)
		assert(_flat_distance(avoidance_zombie.position,collision_barrel.position)>=avoidance_zombie.radius+collision_barrel.radius-0.001)
	zombies.erase(avoidance_zombie); avoidance_zombie.queue_free()
	var health_before_obstacle: float=player.health
	var collision_car=_spawn_obstacle("car",player.position.x,player.position.z)
	_tick_obstacles(0.0)
	assert(player.health<health_before_obstacle and not collision_car.overlaps(player.position))
	obstacles.erase(collision_car); collision_car.queue_free()
	var collision_fence=_spawn_obstacle("fence",player.position.x,player.position.z)
	_tick_obstacles(0.0)
	assert(not collision_fence.overlaps(player.position))
	obstacles.erase(collision_fence); collision_fence.queue_free()
	collision_car=_spawn_obstacle("car",0.0,-6.0)
	_spawn_zombie(-8.0); var road_zombie=zombies[-1]; road_zombie.position.x=0.0
	for step in range(120):
		road_zombie.tick(1.0/60.0); _avoid_obstacles(road_zombie,1.0/60.0)
		assert(not collision_car.overlaps(road_zombie.position,road_zombie.radius))
	zombies.erase(road_zombie); road_zombie.queue_free()
	obstacles.erase(collision_car); collision_car.queue_free()
	player.reserve_ammo=0; _spawn_pickup("ammo",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.reserve_ammo>0)
	player.health=50; _spawn_pickup("medkit",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.health==85)
	# Darius (paramedic): the medkit pickup restores double (35 → 70).
	player.set_character(2)
	player.health=30; _spawn_pickup("medkit",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.health==100)
	player.set_character(0); player.health=player.max_health
	_spawn_pickup("armor",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01)
	assert(player.has_armor and not player.has_helmet and is_instance_valid(player.armor_model))
	_spawn_pickup("helmet",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01)
	assert(player.has_armor and player.has_helmet and is_instance_valid(player.helmet_model))
	# Every ordnance pickup must change real inventory or equip the new weapon.
	player.grenade_count=0; _spawn_pickup("grenade",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.grenade_count==2)
	player.flashbang_count=0; _spawn_pickup("flashbang",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.flashbang_count==1)
	_spawn_pickup("launcher",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.weapon=="LAUNCHER" and player.magazine_size==4)
	player.fire_ammo=0; _spawn_pickup("fire_round",player.position.z); pickups[-1].position.x=player.position.x; _tick_pickups(0.01); assert(player.fire_ammo==4)
	touch_controls=true; assert(_pointer_down(BTN_FIRE_MODE) and player.fire_mode)
	var old_ordnance: int=ordnance.size(); var old_fire_ammo: int=player.fire_ammo
	assert(_fire() and ordnance.size()==old_ordnance+1 and ordnance[-1].kind=="fire" and player.fire_ammo==old_fire_ammo-1)
	player.fire_ammo=1; player.fire_mode=true; assert(_fire()); assert(player.fire_ammo==0 and not player.fire_mode)
	old_ordnance=ordnance.size(); assert(_fire() and ordnance.size()==old_ordnance+1 and ordnance[-1].kind=="launcher")
	assert(_pointer_down(BTN_FRAG) and player.grenade_count==1)
	_spawn_zombie(-10); var frag_target=zombies[-1]; frag_target.position.x=0
	var frag_expected: int=maxi(1,roundi(frag_target.health))
	var frag_projectile=ordnance[-1]; frag_projectile.position=frag_target.position+Vector3(0,0.4,0); frag_projectile.velocity=Vector3.ZERO; frag_projectile.fuse=0
	_tick_ordnance(0.0); assert(not zombies.has(frag_target))
	var frag_number_found:=false
	for effect in effects:
		if is_instance_valid(effect.label) and effect.label.text=="-%d"%frag_expected: frag_number_found=true
	assert(frag_number_found)
	assert(_pointer_down(BTN_FLASH) and player.flashbang_count==0)
	_spawn_zombie(-9); var flash_target=zombies[-1]; flash_target.position.x=2.4
	var flash_projectile=ordnance[-1]; flash_projectile.position=flash_target.position+Vector3(0,0.5,0); flash_projectile.velocity=Vector3.ZERO; flash_projectile.fuse=0
	_tick_ordnance(0.0); assert(flash_target.stun_timer>=3.9 and not flash_target.dead)
	player.fire_ammo=1; player.fire_mode=true; assert(_fire())
	_spawn_zombie(-11); var burn_target=zombies[-1]; burn_target.position.x=-2.4; burn_target.health=200.0
	var fire_projectile=ordnance[-1]; fire_projectile.position=burn_target.position+Vector3(0,0.5,0); fire_projectile.velocity=Vector3.ZERO; fire_projectile.fuse=0
	_tick_ordnance(0.0); assert(burn_target.burn_timer>=4.9 and is_equal_approx(burn_target.burn_dps,24.0))
	var burned_health: float=burn_target.health; burn_target.health=5.0; _tick_zombies(0.25); assert(burned_health>5.0 and not zombies.has(burn_target))
	var burn_number_found:=false
	for effect in effects:
		if is_instance_valid(effect.label) and effect.label.text=="-5": burn_number_found=true
	assert(burn_number_found)
	touch_controls=false; player.set_weapon("PISTOL")
	for projectile in ordnance:
		if is_instance_valid(projectile): projectile.queue_free()
	ordnance.clear()
	player.shield=0.0; player.health=100; player.take_damage(25); assert(is_equal_approx(player.health,80.0))
	_spawn_zombie(-8); var test_z=zombies[-1]; test_z.position.x=0
	assert(_body_part(test_z,test_z.position+Vector3(0,1.8,0))=="head")
	assert(_body_part(test_z,test_z.position+Vector3(-0.17,0.5,0))=="leg_l")
	_hit_zombie(test_z,20,"torso",test_z.position+Vector3(0,1.0,0))
	var bullet_number_found:=false
	for effect in effects:
		if is_instance_valid(effect.label) and effect.label.text=="-20": bullet_number_found=true
	assert(bullet_number_found)
	var effect_count:=effects.size(); _hit_zombie(test_z,1000,"head",test_z.position+Vector3(0,1.8,0)); assert(effects.size()>effect_count+15)
	player.health=player.max_health; _spawn_barrel(); barrels[-1].position=player.position+Vector3(0,0,-1); _explode(barrels[-1])
	assert(is_equal_approx(player.health,player.max_health*0.28))
	player.set_armor(false); player.set_helmet(false); player.health=player.max_health; _spawn_barrel(); barrels[-1].position=player.position+Vector3(0,0,-1); _explode(barrels[-1]); assert(player.health==0)
	var custom_explosion_found:=false
	for effect in effects:
		if effect.get_script()==ExplosionScript: custom_explosion_found=true
	assert(custom_explosion_found)
	run_coins=3; distance=160; var old_bank: int=bank_coins; _end_run(); assert(last_reward==5 and bank_coins==old_bank+5)
	assert(request_revival() and state=="gameover" and revive_pending)
	await get_tree().create_timer(0.55).timeout
	assert(state=="playing" and not revive_used and revive_count==1 and player.health==player.max_health*0.5 and revive_invulnerable>9.0)
	var protected_health: float=player.health; _hurt_player(20); assert(player.health==protected_health)
	_revive_after_reward(); assert(state=="playing" and player.health==protected_health)
	run_coins=5; distance=240; player.health=0; _end_run()
	assert(last_reward==8 and bank_coins==old_bank+8)
	# second revive: 30% health, 8 s invincible; then no more this run
	assert(not revive_used and request_revival()); await get_tree().create_timer(0.55).timeout
	assert(state=="playing" and revive_used and absf(player.health-player.max_health*0.3)<0.01 and revive_invulnerable>7.0)
	revive_invulnerable=0.0; player.health=0; _end_run(); assert(not request_revival())
	_revive_after_reward(); assert(state=="gameover")
	# share: without a native plugin the text goes to the clipboard
	assert(share_result()=="clipboard" and share_text().contains(str(int(distance))))
	# ×2 ad on the results screen: pays the run total once more, only once
	assert(can_double_run() and request_reward_ad("run_double") and ad_pending=="run_double")
	await get_tree().create_timer(0.55).timeout
	assert(ad_pending=="" and run_double_bonus==8 and bank_coins==old_bank+16 and not can_double_run())
	assert(not request_reward_ad("run_double"))
	_pointer_down(gameover_double_rect().get_center()); assert(bank_coins==old_bank+16)
	# New record: only when the best before this run is beaten (first run has nothing to beat).
	var keep_best: int=best_distance
	best_distance=100; start_run(); distance=150; _end_run(); assert(new_record and best_distance==150)
	start_run(); distance=120; _end_run(); assert(not new_record and best_distance==150)
	best_distance=0; start_run(); distance=80; _end_run(); assert(not new_record and best_distance==80)
	best_distance=keep_best
	start_run(); _clear_world(); state="playing"; shot_timer=999; player.health=player.max_health
	run_time=115.0; jockey_introduced=true; banshee_introduced=false
	# The natural banshee roll is a 2% chance, so force the kind: the assertion is about
	# the spawn side-effects (warning + lane clamp), not the RNG table.
	_spawn_zombie(-85,"banshee"); var automatic_banshee=zombies[-1]
	assert(automatic_banshee.kind=="banshee" and automatic_banshee.position.z>=-30.0 and banshee_warning>0.0)
	zombies.erase(automatic_banshee); automatic_banshee.queue_free()
	_spawn_zombie(-16,"jockey"); var jockey=zombies[-1]
	assert(jockey.animation_player.current_animation=="Jockey_Quad_Run" and jockey.speed>7.0)
	_spawn_zombie(-18,"banshee"); var banshee=zombies[-1]
	assert(banshee.animation_player.current_animation=="Banshee_Walk" and banshee.flames.emitting)
	_spawn_zombie(-14,"walker"); var frenzy=zombies[-1]; frenzy.position.x=banshee.position.x
	banshee.banshee_pulse_timer=0.0
	_tick_zombies(0.1)
	var old_frenzy_z: float=frenzy.position.z
	_tick_zombies(0.1)
	assert(frenzy.burn_timer>5.0 and frenzy.frenzy_timer>4.5 and frenzy.flames.emitting)
	assert(frenzy.position.z-old_frenzy_z>frenzy.speed*0.15)
	assert(banshee.burn_timer==0.0 and banshee.flames.emitting)
	# Maya is selectable, and her field instinct is real: slow self-repair below 60% health
	# and an adrenaline speed burst after every hit she takes.
	player.set_character(3); assert(player.character==3 and player.is_maya())
	player.health=player.max_health*0.4; var regen_before: float=player.health; _tick_buffs(1.0)
	assert(player.health>regen_before and player.health<=player.max_health*0.6+0.01)
	player.health=player.max_health; assert(player.instinct_regen_rate()==0.0)
	var plain_mult: float=player.move_mult
	_hurt_player(10.0); assert(player.instinct_boost>0.0 and player.effective_move_mult()>plain_mult)
	player.instinct_boost=0.0; player.health=player.max_health
	player.set_character(0); assert(player.character==0 and not player.is_maya())
	# Mid-run chase: the beast ambushes at the distance mark, gains ground, eats every
	# stumble, and pays out when the survivor lasts the timer.
	distance=399.0; _chase_reset(); next_chase_at=400.0
	_tick_chase(0.1); assert(not chase_active)
	distance=401.0; _tick_chase(0.1); assert(chase_active and is_instance_valid(chaser))
	var gap_before: float=chase_gap; _tick_chase(0.5); assert(chase_gap<gap_before)
	_hurt_player(5.0); assert(chase_gap<=gap_before-CHASE_STUMBLE+0.01)
	var coins_before_chase: int=run_coins
	chase_time=0.05; _tick_chase(0.1); assert(not chase_active and run_coins==coins_before_chase+CHASE_REWARD)
	await get_tree().create_timer(1.8).timeout; assert(not is_instance_valid(chaser))
	player.health=player.max_health
	# Every supply-truck upgrade is a real, measurable improvement — coins never buy nothing.
	for item in shop_items:
		var levels: Dictionary=ShopCatalog.default_levels(); levels[item.id]=1
		player.reset()
		if item.id=="medical":
			player.apply_meta(levels); assert(player.max_health==115.0)
		elif item.id=="ammo":
			player.apply_meta(levels); player.set_weapon("SMG"); assert(player.reserve_ammo==138)
		else:
			player.apply_meta(levels); player.set_weapon(String(item.weapon))
			var expected: float=player.base_damage(String(item.weapon))*1.12
			assert(absf(player.damage-expected)<0.01)
	# 500 coins into the sniper (all five levels): genuinely stronger than stock.
	player.reset(); player.apply_meta(ShopCatalog.default_levels()); player.set_weapon("SNIPER")
	var stock_damage: float=player.damage
	var maxed_levels: Dictionary=ShopCatalog.default_levels(); maxed_levels["w_sniper"]=5
	player.reset(); player.apply_meta(maxed_levels); player.set_weapon("SNIPER")
	assert(player.damage>stock_damage*1.5)
	player.reset(); distance=keep_dist
	_begin_intro(); assert(state=="intro" and zombies.size()==9 and intro_horde_offsets.size()==9 and (is_instance_valid(chaser) or not ResourceLoader.exists(BossChaserScript.MODEL_PATH)))
	assert(player.animation_player.current_animation==player.run_clip and player.animation_player.is_playing())
	_tick_intro(0.5); assert(is_equal_approx(intro_time,0.5) and camera.fov==50.0)
	_finish_intro(); assert(state=="playing" and zombies.size()==2 and intro_horde_offsets.is_empty())
	_begin_intro(); assert(_pointer_down(Vector2(270,480)) and state=="playing" and zombies.size()==2)
	_begin_intro()
	var skip_key:=InputEventKey.new(); skip_key.keycode=KEY_SPACE; skip_key.pressed=true
	_unhandled_input(skip_key); assert(state=="playing" and zombies.size()==2)
	print("SMOKE_3D_OK languages=20 settings=true character_select=true shop=true rewards=true weapons=true reload=true armor=true helmet=true helmet_protection=true barrel_collision=true barrel_aim=true ordnance=true damage_numbers=true audio=true jockey=true banshee=true fire_frenzy=true revival=true revival_rewards=true intro=true crater=true")
	_clear_world(); await get_tree().process_frame; await get_tree().process_frame; get_tree().quit()

func _soak_test() -> void:
	start_run(); player.apply_upgrade("smg"); player.damage=180; player.fire_interval=0.07; player.projectile_count=3; player.reserve_ammo=99999; auto_reload=true
	for frame in range(2100):
		player.health=100; player.target_x=sin(frame/95.0)*2.7; aim_direction=Vector3(sin(frame/130.0)*0.2,0,-1).normalized(); await get_tree().process_frame
	assert(run_time>30 and wave>=2 and kills>10 and new_gate_index>=2)
	print("SOAK_3D_OK time=",snappedf(run_time,0.1)," kills=",kills," gates=",new_gate_index," coins=",run_coins," actors=",zombies.size()+bullets.size()+effects.size())
	_clear_world(); await get_tree().process_frame; await get_tree().process_frame; get_tree().quit()

## Tank shell: a bright tracer down the lane, everything in it dies, the tank wears out.
const CANNON_PERIOD:=1.25
const CANNON_COST:=13.0
const CANNON_RANGE:=42.0
const CANNON_HALF_WIDTH:=2.1
func _fire_cannon() -> void:
	var muzzle:=player.position+Vector3(0,1.55,1.05)
	# tracer + muzzle blast
	_burst(muzzle,Color("ffe3a6"),16)
	_burst(muzzle,Color("8a7f68"),8)
	var beam:=EffectScript.new(); beam.position=muzzle
	add_child(beam); effects.append(beam)
	sound.play("explosion"); shake=maxf(shake,0.5)
	# dynamic damage: every zombie standing in the lane takes its own full health
	for i in range(zombies.size()-1,-1,-1):
		var z=zombies[i]
		if not is_instance_valid(z): continue
		var dz: float=(player.position.z-z.global_position.z)
		if dz<=0.0 or dz>CANNON_RANGE: continue
		if absf(z.global_position.x-player.position.x)>CANNON_HALF_WIDTH: continue
		_blood_spray(z.global_position+Vector3(0,1.0,0),22)
		_hit_zombie(z,1e9,"torso",z.global_position+Vector3(0,1.0,0))
	player.cannon_kick=1.0
	player.vehicle_durability-=CANNON_COST
	if player.vehicle_durability<=0.0: _vehicle_breakdown()

## DEV ONLY: unlock every purchasable thing on this account, so the vehicles can be
## tested without going through the store / ad flow. Flip to false before shipping.
const DEV_UNLOCK_ALL:=false   # premium build: no god mode, everything is earned
func _dev_unlock_all() -> void:
	# Also requires the dev_unlock custom feature in export_presets.cfg, so a
	# normal build never grants the paid content.
	if not DEV_UNLOCK_ALL or not (OS.has_feature("dev_unlock") or OS.has_feature("editor")): return
	for p in StoreCatalog.PACKS:
		if bool(p.get("once",false)): store_owned[String(p.id)]=true
		if p.has("char"): owned_characters[int(p.char)]=true
		if p.has("skin"): owned_skins[int(p.skin)]=true
		if p.has("pet"): owned_pets[int(p.pet)]=true
	# Never hand the player a vehicle: this used to equip the TANK as a side effect of
	# the dev unlock, so every run after one visit to the lobby started mounted on it.
	_save()
