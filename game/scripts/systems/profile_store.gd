class_name ProfileStore
extends RefCounted

## C17 长期档案（SaveV7 envelope + SaveCrypto 加密，写 user://reclaimer_profile.sav）。
## 跨局保存：银币、已解锁模块、任务进度、解锁群系、生涯统计。原子写：先写 .tmp 再改名，失败保留旧档。
## 读取失败（被篡改 / 版本不符 / 换机器）→ 新档，并保留 .bad 副本便于排查。

const PATH := "user://reclaimer_profile.sav"
const CHANNEL := "dev"
const GENERATION := 0

var path := PATH
var data: SaveV7 = SaveV7.new()
var last_error := ""

func load_profile() -> bool:
	data = SaveV7.new()
	data.stamp_build_identity(CHANNEL, GENERATION)
	if not FileAccess.file_exists(path):
		return false
	var blob := FileAccess.get_file_as_bytes(path)
	var d := SaveCrypto.decrypt_dict(blob)
	if d.is_empty():
		last_error = "decrypt_failed"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bad"))
		return false
	var s := SaveV7.migrate(d)
	if not s.matches_build_identity(CHANNEL, GENERATION):
		last_error = "identity_mismatch"
		return false
	data = s
	return true

func save_profile() -> bool:
	data.last_saved_utc_ticks = int(Time.get_unix_time_from_system())
	data.normalize()
	var blob := SaveCrypto.encrypt_dict(data.to_dict())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "open_failed"
		return false
	f.store_buffer(blob)
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_dst)
	return DirAccess.rename_absolute(abs_tmp, abs_dst) == OK

## 从当前单局系统同步进档案（局内 → 生涯）
func absorb_run(run: RunSystems, unlocked_modules: Array, biomes: Array, run_stats: Dictionary) -> void:
	data.silver_before_last_run = data.silver
	data.silver += maxi(run.silver - int(run_stats.get("silver_at_start", 0)), 0)
	for q in run.achieved_quests:
		data.achieved_quests.append(q)
	for k in run.quest_progress:
		data.quest_progress[str(k)] = maxi(int(data.quest_progress.get(str(k), 0)), int(run.quest_progress[k]))
	for m in unlocked_modules:
		data.unlocked_ids.append(m)
	for b in biomes:
		data.unlocked_biome_ids.append(b)
	data.run_statistics = run_stats.duplicate()
	for k in run_stats:
		if typeof(run_stats[k]) == TYPE_INT or typeof(run_stats[k]) == TYPE_FLOAT:
			data.lifetime_statistics[k] = float(data.lifetime_statistics.get(k, 0.0)) + float(run_stats[k])
	data.normalize()
