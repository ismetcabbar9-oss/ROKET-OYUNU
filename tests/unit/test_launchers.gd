extends GutTest
## Fırlatma rampaları: tanımlar tutarlı, dizi doğru sırayla ilerler, füze doğru açıyla ayrılır.
## Fizik adımları elle çağrılır (gerçek zaman beklemeden, kare hızından bağımsız).

const DT: float = 1.0 / 60.0
const LAUNCHERS: Array[String] = [
	"res://scenes/launchers/tel_launcher.tscn",
	"res://scenes/launchers/rail_launcher.tscn",
	"res://scenes/launchers/silo_launcher.tscn",
]
const MISSILES: Array[String] = [
	"res://config/missiles/sahin.tres",
	"res://config/missiles/kartal.tres",
	"res://config/missiles/yildirim.tres",
]
const MISSILE_SCENE: String = "res://scenes/missile/missile.tscn"

var _stages: Array[int] = []
var _released: Missile


func before_each() -> void:
	_stages.clear()
	_released = null


func test_every_missile_has_a_launcher_and_every_launcher_a_missile() -> void:
	var missiles: Array[MissileDefinition] = _missiles()
	for path: String in LAUNCHERS:
		var definition: LauncherDefinition = _definition(path)
		var count: int = 0
		for m: MissileDefinition in missiles:
			count += 1 if definition.supports(m) else 0
		assert_gt(count, 0, "%s en az bir füze atabilmeli" % definition.id)
	for m: MissileDefinition in missiles:
		var count: int = 0
		for path: String in LAUNCHERS:
			count += 1 if _definition(path).supports(m) else 0
		assert_gt(count, 1, "%s en az iki rampadan atılabilmeli" % m.id)


func test_definitions_have_shots_and_captions() -> void:
	for path: String in LAUNCHERS:
		var definition: LauncherDefinition = _definition(path)
		for stage: int in [Launcher.Stage.READY, Launcher.Stage.PREPARE, Launcher.Stage.RAISE,
				Launcher.Stage.LOCK, Launcher.Stage.IGNITE, Launcher.Stage.RELEASE]:
			assert_not_null(definition.get_shot(stage), "%s: %d aşaması için kamera çekimi" % [definition.id, stage])
		assert_eq(definition.stage_captions.size(), 4, "%s: dört aşama açıklaması" % definition.id)
		assert_gt(definition.get_sequence_seconds(), 2.0, "%s: dizi hissedilecek kadar uzun" % definition.id)
		assert_lt(definition.get_sequence_seconds(), 9.0, "%s: dizi sıkmayacak kadar kısa" % definition.id)


func test_sequence_runs_all_stages_in_order() -> void:
	for path: String in LAUNCHERS:
		before_each()
		var launcher: Launcher = _launcher_with_missile(path)
		assert_true(launcher.begin_sequence(_steer()), "%s dizi başlamalı" % path)
		var seconds: float = _run_until_released(launcher, 20.0)
		assert_eq(_stages, [Launcher.Stage.PREPARE, Launcher.Stage.RAISE, Launcher.Stage.LOCK,
			Launcher.Stage.IGNITE, Launcher.Stage.RELEASE], path)
		assert_not_null(_released, "%s füzeyi bırakmalı" % path)
		assert_almost_eq(seconds, launcher.definition.get_sequence_seconds(), 0.1, "%s dizi süresi" % path)
		assert_eq(_released.phase, Missile.Phase.FLYING)


func test_rail_launchers_release_at_launch_angle() -> void:
	for path: String in [LAUNCHERS[0], LAUNCHERS[1]]:
		before_each()
		var launcher: Launcher = _launcher_with_missile(path)
		launcher.begin_sequence(_steer())
		_run_until_released(launcher, 20.0)
		var pitch: float = rad_to_deg(asin(_released.get_forward().y))
		assert_almost_eq(pitch, launcher.definition.launch_angle_deg, 0.5, "%s fırlatma açısı" % path)


func test_silo_cold_launch_ignites_above_the_silo() -> void:
	var launcher: Launcher = _launcher_with_missile(LAUNCHERS[2])
	var start_y: float = launcher.missile.global_position.y
	launcher.begin_sequence(_steer())
	_run_until_released(launcher, 20.0)
	var climb: float = _released.global_position.y - start_y
	assert_gt(climb, 12.0, "füze gazla tüpten yeterince yükseğe atılmalı")
	var pitch: float = rad_to_deg(asin(_released.get_forward().y))
	assert_almost_eq(pitch, launcher.definition.ignition_pitch_deg, 1.0, "ateşleme açısı")


func test_skip_shortens_the_sequence() -> void:
	var normal: Launcher = _launcher_with_missile(LAUNCHERS[0])
	normal.begin_sequence(_steer())
	var normal_seconds: float = _run_until_released(normal, 20.0)
	before_each()
	var skipped: Launcher = _launcher_with_missile(LAUNCHERS[0])
	skipped.begin_sequence(_steer())
	skipped.skip()
	var skipped_seconds: float = _run_until_released(skipped, 20.0)
	assert_lt(skipped_seconds, normal_seconds * 0.5, "ATLA diziyi belirgin kısaltmalı")
	assert_not_null(_released)


func test_launcher_resets_to_ready() -> void:
	var launcher: Launcher = _launcher_with_missile(LAUNCHERS[0])
	launcher.begin_sequence(_steer())
	_run_until_released(launcher, 20.0)
	for i: int in roundi((launcher.release_hold_seconds + launcher.reset_seconds + 0.2) / DT):
		launcher._physics_process(DT)
	assert_eq(launcher.stage, Launcher.Stage.READY)
	assert_almost_eq(launcher.raise_pivot.rotation.x, deg_to_rad(launcher.definition.stow_angle_deg), 0.01, "erektör taşıma açısına döndü")
	assert_false(launcher.begin_sequence(_steer()), "füzesiz rampa ateşlenemez")


# --- yardımcılar ---

func _missiles() -> Array[MissileDefinition]:
	var list: Array[MissileDefinition] = []
	for path: String in MISSILES:
		list.append(load(path) as MissileDefinition)
	return list


func _definition(scene_path: String) -> LauncherDefinition:
	var launcher: Launcher = (load(scene_path) as PackedScene).instantiate() as Launcher
	var definition: LauncherDefinition = launcher.definition
	launcher.free()
	return definition


func _launcher_with_missile(scene_path: String) -> Launcher:
	var launcher: Launcher = (load(scene_path) as PackedScene).instantiate() as Launcher
	# Efektler rampanın ebeveynine eklenir; test bittiğinde birlikte silinsin
	var holder := Node3D.new()
	add_child_autofree(holder)
	holder.add_child(launcher)
	launcher.stage_changed.connect(func(stage: Launcher.Stage) -> void: _stages.append(stage))
	launcher.missile_released.connect(func(m: Missile) -> void: _released = m)
	var missile: Missile = (load(MISSILE_SCENE) as PackedScene).instantiate() as Missile
	holder.add_child(missile)
	for m: MissileDefinition in _missiles():
		if launcher.definition.supports(m):
			missile.setup(m)
			break
	launcher.attach(missile)
	return launcher


func _run_until_released(launcher: Launcher, timeout: float) -> float:
	var t: float = 0.0
	while _released == null and t < timeout:
		launcher._physics_process(DT)
		t += DT
	return t


func _steer() -> SteerInput:
	return autofree(SteerInput.new()) as SteerInput
