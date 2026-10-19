extends Node
## Oyuncu tercihleri (kontrol modu, hassasiyet, ses). user://settings.cfg'ye kaydedilir.
## Oyun hissi değerleri burada DEĞİL, config/ altındaki Resource dosyalarındadır.

signal changed

enum ControlMode { JOYSTICK, GYRO }

const SAVE_PATH: String = "user://settings.cfg"

var control_mode: ControlMode = ControlMode.JOYSTICK
var joystick_sensitivity: float = 1.0
var gyro_sensitivity: float = 1.0
var invert_pitch: bool = false
var master_volume: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("controls", "mode", control_mode) as ControlMode
	joystick_sensitivity = cfg.get_value("controls", "joystick_sensitivity", joystick_sensitivity) as float
	gyro_sensitivity = cfg.get_value("controls", "gyro_sensitivity", gyro_sensitivity) as float
	invert_pitch = cfg.get_value("controls", "invert_pitch", invert_pitch) as bool
	master_volume = cfg.get_value("audio", "master_volume", master_volume) as float
	_apply_audio()
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mode", control_mode)
	cfg.set_value("controls", "joystick_sensitivity", joystick_sensitivity)
	cfg.set_value("controls", "gyro_sensitivity", gyro_sensitivity)
	cfg.set_value("controls", "invert_pitch", invert_pitch)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SAVE_PATH)
	_apply_audio()
	changed.emit()


func _apply_audio() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
