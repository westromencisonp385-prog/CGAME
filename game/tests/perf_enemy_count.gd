extends SceneTree

## 压测：同屏 N 个敌人时的帧时间（真 GPU）
var main: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	main.player.status.apply("invincible", 999.0)
	main.player.auto_combat = false
	var minions := EnemyArchetypes.ids_of_tier("minion")
	var count := 0
	for target in [0, 30, 60, 90, 120]:
		while count < target:
			var a := TAU * float(count) / 30.0
			var r := 5.0 + float(count / 30) * 2.5
			var e: EnemyDummy = main.spawn_archetype(minions[count % minions.size()], main.player.global_position + Vector3(cos(a) * r, 0, sin(a) * r))
			if e != null:
				e.speed *= 0.2
			count += 1
		await create_timer(1.0).timeout
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var worst := 0.0
		var last := t0
		while Time.get_ticks_usec() - t0 < 3000000:
			await process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, float(now - last) / 1000.0)
			last = now
			frames += 1
		var avg := 3000.0 / float(frames)
		print("PERF enemies=%d avg_ms=%.2f fps=%.0f worst_ms=%.1f draw_calls=%d" % [main.get_tree().get_nodes_in_group("enemies").size(), avg, 1000.0 / avg, worst, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit(0)
