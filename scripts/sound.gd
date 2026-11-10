extends Node

var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var stop_times: Array[float] = []
var cursor := 0
var muted := false
# Independent volume sliders (Settings): 0..1 linear, applied to the Music and SFX buses.
var music_volume := 0.8
var sfx_volume := 1.0
var last_id := ""
var music: AudioStreamPlayer
var music_state_name := ""
# Chase music for the intro and the run itself; the two tracks alternate.
const CHASE_TRACKS := ["res://assets/audio/chase_survival_pulse.mp3","res://assets/audio/chase_track_2.mp3"]
var chase: AudioStreamPlayer
## Start screen ("tap anywhere to start") has its own looping track.
var title_music: AudioStreamPlayer
## Main screen (character and pet picking) rotates randomly through these, like the chase tracks.
const LOBBY_TRACKS := ["res://assets/audio/lobby_music.ogg","res://assets/audio/lobby_serenade.mp3","res://assets/audio/lobby_beyond_routine.mp3","res://assets/audio/lobby_smooth_podcast.mp3"]
var lobby_music: AudioStreamPlayer
var lobby_streams: Array = []
## Supply shop (è¡¥ç»™å•†åº—) rotates randomly through these too; the theme copy is duplicated so
## its loop can stay off here while the shared `music` player keeps looping it elsewhere.
const SHOP_TRACKS := ["res://assets/audio/dead_run_theme.wav","res://assets/audio/shop_disco.mp3"]
var shop_music: AudioStreamPlayer
var shop_streams: Array = []
## States that are the main screen, including the popups shown over it.
## Note: "terms" is NOT here â€” it sits over the cover (login page), so it keeps the
## login/title music, not the lobby music.
const LOBBY_STATES:=["character_select","signin","offer"]
var chase_streams: Array = []
var chase_index := -1
## A third chase track that only joins the rotation during a storm (main_3d sets `storm`).
const STORM_TRACK := "res://assets/audio/chase_storm.mp3"
var storm_stream: AudioStream
var storm := false
## Rain ambience: looped along with the chase music whenever the weather is rain/storm.
## Storm/rain ambience: two supplied beds, chosen at random per weather change and played as
## a layer UNDER the music (own player, Music bus). `RAIN_GAIN` evens them out by ear.
const RAIN_TRACKS := ["res://assets/audio/storm_rain.mp3", "res://assets/audio/storm_rain_2.mp3"]
const RAIN_GAIN := [-10.0, -10.0]     # per-track dB, tweak if one bed is louder
const RAIN_TRACK := "res://assets/audio/storm_rain.mp3"
const RAIN_TRACK_OLD := "res://assets/audio/rain_thunder.mp3"
var rain_stream: AudioStream
var rain: AudioStreamPlayer
var raining := false
## Played the moment night falls in a run (main_3d calls night_fell), then the rotation carries on.
const NIGHT_TRACK := "res://assets/audio/night_fall.mp3"
var night_stream: AudioStream
## New-record fanfare: ducks the chase track, then hands it back where it stopped.
const RECORD_FANFARE := "res://assets/audio/record_fanfare.mp3"
var fanfare: AudioStreamPlayer

func _ready() -> void:
	streams["rifle"] = load("res://assets/audio/rifle.mp3")
	streams["smg"] = load("res://assets/audio/smg.mp3")
	streams["sniper"] = load("res://assets/audio/sniper.mp3")
	streams["shotgun"] = load("res://assets/audio/shotgun.mp3")
	streams["flame"] = load("res://assets/audio/flame.mp3")
	streams["equip"] = load("res://assets/audio/equip_lobby.mp3")
	streams["pistol_near"] = load("res://assets/audio/pistol_near.mp3")
	streams["pistol_far"] = load("res://assets/audio/pistol_far.mp3")
	streams["reload"] = load("res://assets/audio/reload.mp3")
	streams["explosion"] = load("res://assets/audio/explosion.mp3")
	streams["zombie"] = load("res://assets/audio/zombie_growl.mp3")
	streams["pursuer_roar"] = load("res://assets/audio/pursuer_roar.mp3")
	streams["game_over"] = load("res://assets/audio/game_over.mp3")
	# case rewards: tada for an upgrade, level-up for a dog (the best pull)
	streams["tada"] = load("res://assets/audio/tada.mp3")
	streams["level_up"] = load("res://assets/audio/level_up.mp3")
	streams["coin_get"] = load("res://assets/audio/get_coin.mp3")
	streams["thunder"] = _tone(2.2, 70.0, 28.0, 0.55, true)
	streams["shot"] = streams["rifle"]
	streams["hit"] = _tone(0.055, 95.0, 58.0, 0.24, true)
	streams["kill"] = _tone(0.11, 180.0, 65.0, 0.30, true)
	streams["hurt"] = _tone(0.22, 85.0, 42.0, 0.45, true)
	streams["gate"] = _tone(0.28, 330.0, 880.0, 0.28, false)
	streams["pickup"] = _tone(0.20, 520.0, 940.0, 0.24, false)
	_ensure_buses()
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		voice.bus="SFX"
		add_child(voice)
		voices.append(voice)
		stop_times.append(0.0)
	var theme:=load("res://assets/audio/dead_run_theme.wav") as AudioStreamWAV
	if theme:
		theme.loop_mode=AudioStreamWAV.LOOP_FORWARD
		theme.loop_begin=0
		theme.loop_end=int(theme.get_length()*theme.mix_rate)
		music=AudioStreamPlayer.new()
		music.stream=theme
		music.volume_db=-13.0
		add_child(music)
	for path in CHASE_TRACKS:
		var st = load(path)
		if st: chase_streams.append(st)
	var title_stream=load("res://assets/audio/login_music.ogg")
	if title_stream:
		if title_stream is AudioStreamOggVorbis: (title_stream as AudioStreamOggVorbis).loop=true
		title_music=AudioStreamPlayer.new(); title_music.stream=title_stream; title_music.volume_db=-6.0; add_child(title_music)
		# the track is levelled to about -16 LUFS; -6 dB sits it near the gunshots, above the run music
	for path in LOBBY_TRACKS:
		var st = load(path)
		if st:
			# rotation: each track plays through once, then a random different one starts
			if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop=false
			elif st is AudioStreamMP3: (st as AudioStreamMP3).loop=false
			lobby_streams.append(st)
	lobby_music=AudioStreamPlayer.new(); lobby_music.volume_db=-6.0
	add_child(lobby_music); lobby_music.finished.connect(_next_lobby_track)
	for i in range(SHOP_TRACKS.size()):
		var st = load(SHOP_TRACKS[i])
		if not st: continue
		if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop=false
		elif st is AudioStreamMP3: (st as AudioStreamMP3).loop=false
		elif st is AudioStreamWAV:
			# a duplicate: the shared theme resource must stay looping for the `music` player
			st=(st as AudioStreamWAV).duplicate(); (st as AudioStreamWAV).loop_mode=AudioStreamWAV.LOOP_DISABLED
		shop_streams.append(st)
	shop_music=AudioStreamPlayer.new(); shop_music.volume_db=-13.0; add_child(shop_music)
	shop_music.finished.connect(_next_shop_track)
	chase=AudioStreamPlayer.new(); chase.volume_db=-12.0; add_child(chase)
	chase.finished.connect(_next_chase_track)
	var rain_path:=RAIN_TRACK
	if RAIN_TRACKS.size() > 0:
		rain_path=String(RAIN_TRACKS[randi() % RAIN_TRACKS.size()])
	if ResourceLoader.exists(rain_path):
		rain_stream=load(rain_path)
		if rain_stream is AudioStreamMP3: (rain_stream as AudioStreamMP3).loop=true
		var idx:=RAIN_TRACKS.find(rain_path)
		rain=AudioStreamPlayer.new(); rain.stream=rain_stream
		rain.volume_db=float(RAIN_GAIN[idx]) if idx>=0 and idx<RAIN_GAIN.size() else -10.0
		rain.bus="Music"; add_child(rain)
	var fanfare_stream=load(RECORD_FANFARE)
	if fanfare_stream:
		fanfare=AudioStreamPlayer.new(); fanfare.stream=fanfare_stream; fanfare.volume_db=-2.0
		add_child(fanfare); fanfare.finished.connect(_fanfare_finished)
	for p in [music,title_music,lobby_music,shop_music,chase,fanfare]:
		if is_instance_valid(p): p.bus="Music"
	apply_volumes()
	music_state("cover")

func _process(delta: float) -> void:
	for i in range(voices.size()):
		if stop_times[i]>0:
			stop_times[i]-=delta
			if stop_times[i]<=0: voices[i].stop()

func music_state(state: String) -> void:
	var previous:=music_state_name
	music_state_name=state
	if is_instance_valid(music):
		var should_play:=not muted and state in ["language","settings","character_select"] and not (state in LOBBY_STATES and is_instance_valid(lobby_music))
		if should_play and not music.playing: music.play()
		elif not should_play and music.playing: music.stop()
	if is_instance_valid(title_music):
		# The start screen (login page) plays the login track; the terms window sits on
		# top of it, so "terms" keeps the same login music.
		var title_on:=not muted and state in ["cover","terms"]
		if title_on and not title_music.playing: title_music.play()
		elif not title_on and title_music.playing: title_music.stop()
	if is_instance_valid(lobby_music):
		var lobby_on:=not muted and (state in LOBBY_STATES or state in ["map","bag","mail","signin","tasks","lootbox","airdrop"])
		if lobby_on and not lobby_music.playing: _next_lobby_track()
		elif not lobby_on and lobby_music.playing: lobby_music.stop()
	if is_instance_valid(shop_music):
		var shop_on:=not muted and state in ["shop","store"]
		if shop_on and not shop_music.playing: _next_shop_track()
		elif not shop_on and shop_music.playing: shop_music.stop()
	if is_instance_valid(chase) and not chase_streams.is_empty():
		if muted or not state in ["intro","playing","paused","health_ad"]:
			chase.stop(); chase.stream_paused=false
		elif state in ["paused","health_ad"]:
			chase.stream_paused=true # silent while paused / in a prompt, resumes from the same spot
		elif chase.stream_paused:
			chase.stream_paused=false
		elif not chase.playing:
			_next_chase_track()
	if is_instance_valid(rain):
		var rain_on:=raining and not muted and music_state_name in ["intro","playing"]
		if rain_on and not rain.playing: rain.play()
		elif not rain_on and rain.playing: rain.stop()

## Random next lobby track, never the same one twice in a row (same rule as the chase rotation).
func _next_lobby_track() -> void:
	if lobby_streams.is_empty() or not (music_state_name in LOBBY_STATES or music_state_name in ["map","bag"]): return
	var last: AudioStream=lobby_music.stream
	var options: Array=lobby_streams.filter(func(st): return st!=last)
	if options.is_empty(): options=lobby_streams
	lobby_music.stream=options[randi()%options.size()]; lobby_music.play()

## Random next shop track, never the same one twice in a row (same rule as the other rotations).
func _next_shop_track() -> void:
	if shop_streams.is_empty() or not music_state_name in ["shop","store"]: return
	var last: AudioStream=shop_music.stream
	var options: Array=shop_streams.filter(func(st): return st!=last)
	if options.is_empty(): options=shop_streams
	shop_music.stream=options[randi()%options.size()]; shop_music.play()

func _next_chase_track() -> void:
	if chase_streams.is_empty() or not music_state_name in ["intro","playing","paused","health_ad"]: return
	if storm_stream==null and ResourceLoader.exists(STORM_TRACK): storm_stream=load(STORM_TRACK)
	var pool: Array=chase_streams.duplicate()
	if storm and storm_stream: pool.append(storm_stream)
	# random each time, never the same track twice in a row
	var last: AudioStream=chase.stream
	var options: Array=pool.filter(func(st): return st!=last)
	if options.is_empty(): options=pool
	var pick: AudioStream=options[randi()%options.size()]
	chase_index=chase_streams.find(pick)
	chase.stream=pick; chase.stream_paused=false; chase.play()

func set_rain(on: bool) -> void:
	raining=on
	if is_instance_valid(rain):
		if on and not muted and not rain.playing: rain.play()
		elif (not on or muted) and rain.playing: rain.stop()

func night_fell() -> void:
	if not is_instance_valid(chase) or not music_state_name in ["intro","playing","paused","health_ad"]: return
	if night_stream==null and ResourceLoader.exists(NIGHT_TRACK): night_stream=load(NIGHT_TRACK)
	if night_stream==null: return
	if night_stream is AudioStreamMP3: (night_stream as AudioStreamMP3).loop=false
	chase.stream=night_stream; chase_index=-1; chase.stream_paused=state_paused(); chase.play()

## Freeze / unfreeze every one-shot voice so a paused run is a still frame, sound included.
func freeze_voices(on: bool) -> void:
	for v in voices:
		if is_instance_valid(v):
			v.stream_paused = on
	if is_instance_valid(music):
		music.stream_paused = on


func state_paused() -> bool:
	return music_state_name=="paused"

## Moment the run passes the old best: play the fanfare, pause the chase track mid-note,
## and hand it back where it stopped the instant the fanfare ends.
func record_fanfare() -> void:
	if muted or not is_instance_valid(fanfare): return
	if is_instance_valid(chase) and chase.playing: chase.stream_paused=true
	fanfare.play()

func _fanfare_finished() -> void:
	if not is_instance_valid(chase): return
	# A state change may have stopped the track already; only wake it if it is still ours.
	if music_state_name in ["intro","playing","paused","health_ad"]:
		chase.stream_paused=(music_state_name in ["paused","health_ad"])

## Touch every stream once at loader time: the first real playback then has nothing left to
## decode, which on iOS used to cost a frame right in the middle of a fight.
func prime_all() -> void:
	for id in streams.keys():
		var st: AudioStream = streams[id]
		if st == null:
			continue
		st.get_length()


func play(id: String) -> void:
	last_id=id
	if muted or not streams.has(id) or voices.is_empty() or streams[id]==null: return
	var voice := voices[cursor % voices.size()]
	cursor += 1
	voice.stream = streams[id]
	voice.pitch_scale = randf_range(0.92,1.08) if id=="zombie" else 1.0
	voice.volume_db = -1.0
	# Gunshots levelled to about the pistol's loudness (measured: rifle -11, smg -14.5,
	# shotgun -7, sniper -18, pistol -7 LUFS raw), so no gun is much louder than another.
	if id=="rifle": voice.volume_db=-12.0
	elif id=="smg": voice.volume_db=-10.0
	elif id=="pistol_near": voice.volume_db=-16.0
	elif id=="pistol_far": voice.volume_db=-12.0
	elif id=="shotgun": voice.volume_db=-15.0
	elif id=="flame": voice.volume_db=-19.0
	elif id=="equip": voice.volume_db=-8.0
	elif id=="sniper": voice.volume_db=-4.0
	elif id=="zombie": voice.volume_db=-6.0
	elif id in ["coin_get","tada","level_up"]: voice.volume_db=-14.0 # claim/jingle quieter
	if id=="explosion": voice.volume_db-=0.92 # Ten percent lower linear amplitude.
	voice.play()
	stop_times[voice.get_index()] = 0.0
	if id=="smg": stop_times[voice.get_index()]=minf(0.65,streams[id].get_length())
	elif id in ["rifle","pistol_near","pistol_far"]: stop_times[voice.get_index()]=0.38
	elif id=="shotgun": stop_times[voice.get_index()]=0.70
	elif id=="sniper": stop_times[voice.get_index()]=0.85
	elif id in ["explosion","zombie"]: stop_times[voice.get_index()]=2.4

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()
	if is_instance_valid(music):
		music.stop()
		music.stream=null
	if is_instance_valid(chase):
		chase.stop()
		chase.stream=null

func _tone(duration: float, start_hz: float, end_hz: float, volume: float, noisy: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = count + int(start_hz * 10)
	for i in range(count):
		var t := float(i) / float(count)
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU * hz / rate
		var envelope := pow(1.0-t, 2.0)
		var sample := sin(phase) * 0.65 + (rng.randf_range(-1,1) * 0.55 if noisy else sin(phase*2.0)*0.18)
		bytes.encode_s16(i*2, int(clampf(sample*envelope*volume,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes
	return stream


func _ensure_buses() -> void:
	for bus_name in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus(); var i:=AudioServer.bus_count-1
			AudioServer.set_bus_name(i,bus_name); AudioServer.set_bus_send(i,"Master")

## Push the two slider values onto their buses (0 = silent).
func apply_volumes() -> void:
	_ensure_buses()
	for pair in [["Music",music_volume],["SFX",sfx_volume]]:
		var i:=AudioServer.get_bus_index(String(pair[0])); var v: float=clampf(float(pair[1]),0.0,1.0)
		AudioServer.set_bus_mute(i,v<=0.001)
		AudioServer.set_bus_volume_db(i,linear_to_db(maxf(v,0.001)))
