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
## Veri yolu seviyeleri (0..1): efektler, ortam, arayüz.
var sfx_volume: float = 1.0
var ambient_volume: float = 1.0
var ui_volume: float = 1.0


func _ready() -> void:
	load_settings()
	_apply_audio()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	control_mode = cfg.get_value("controls", "mode", control_mode) as ControlMode
	joystick_sensitivity = cfg.get_value("controls", "joystick_sensitivity", joystick_sensitivity) as float
	gyro_sensitivity = cfg.get_value("controls", "gyro_sensitivity", gyro_sensitivity) as float
	invert_pitch = cfg.get_value("controls", "invert_pitch", invert_pitch) as bool
	master_volume = cfg.get_value("audio", "master_volume", master_volume) as float
	sfx_volume = cfg.get_value("audio", "sfx_volume", sfx_volume) as float
	ambient_volume = cfg.get_value("audio", "ambient_volume", ambient_volume) as float
	ui_volume = cfg.get_value("audio", "ui_volume", ui_volume) as float
	_apply_audio()
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mode", control_mode)
	cfg.set_value("controls", "joystick_sensitivity", joystick_sensitivity)
	cfg.set_value("controls", "gyro_sensitivity", gyro_sensitivity)
	cfg.set_value("controls", "invert_pitch", invert_pitch)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "ambient_volume", ambient_volume)
	cfg.set_value("audio", "ui_volume", ui_volume)
	cfg.save(SAVE_PATH)
	_apply_audio()
	changed.emit()


func apply_audio() -> void:
	_apply_audio()


func _apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Ambient", ambient_volume)
	_set_bus("UI", ui_volume)


func _set_bus(bus_name: String, volume: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.0001)
