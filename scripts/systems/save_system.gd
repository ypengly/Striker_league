extends Node
## JSON save file in user:// (works on desktop, Android and Web/IndexedDB).
## Registered as autoload "SaveSystem".

const SAVE_PATH := "user://striker_league_save.json"

var data: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	data = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		data = parsed

func save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
