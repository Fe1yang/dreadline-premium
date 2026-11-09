extends SceneTree
## DSH: front-view captures for all survivors plus aim variations, to verify the
## two-hand stance (no crossed arms, nothing buried in the chest) and the Riley mesh.

const OUT := "res://diagnostics/pose/dsh_check"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await create_timer(0.6).timeout
	game._clear_world()
	game.enter_lobby()
	await create_timer(0.3).timeout
	game.owned_characters[4] = true

	for ch in [0, 1, 2, 3, 4]:
		game.select_character(ch)
		game.start_run()
		game.state = "playing"
		game.shot_timer = 999
		game.hint_time = 0
		game.touch_controls = false
		if game.hud != null:
			game.hud.visible = false
		await create_timer(1.2).timeout
		await _shot(game, "char%d_front" % ch, 0.0)
		print("DSH: char", ch, " done")

	# aim variations on the male: does the stance still read correctly at 90/180 deg?
	game.select_character(0)
	game.start_run()
	game.state = "playing"
	game.shot_timer = 999
	game.hint_time = 0
	game.touch_controls = false
	await create_timer(1.2).timeout
	for aim in [[1.0, 0.0, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]]:
		game.player.set_aim(Vector3(aim[0], 0.0, aim[2]))
		await create_timer(0.3).timeout
		var tag: String = "aim_%s_%s" % [str(int(aim[0])), str(int(aim[2]))]
		await _shot_keep_yaw(game, tag)
		print("DSH: ", tag, " done")

	print("DSH_CHECK_DONE")
	game.queue_free()
	await process_frame
	quit()

func _shot(game, tag: String, yaw: float) -> void:
	game.set_process(false)
	if game.player != null and game.player.model != null:
		game.player.model.rotation.y = yaw
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, tag])
	game.set_process(true)

func _shot_keep_yaw(game, tag: String) -> void:
	game.set_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, tag])
	game.set_process(true)
