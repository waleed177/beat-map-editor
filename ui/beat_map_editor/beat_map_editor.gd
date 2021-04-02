tool
extends MarginContainer

#TODO make ui for setting this stuff
var tileset = preload("res://tilesets/noteskins.tres")
var tile_size = Vector2(64, 64)
var keyboard_note_shortcuts = {}
var keyboard_note_shortcuts_inv = {}
var beat_map = {}
onready var file_dialog = $HBoxContainer/Actions/VBoxContainer/FileDialog

# 1 (4), 1/2 (8), 1/4 (16), 1/16 (64)
var note_type_order = [0, 3, 2, 3, 1, 3, 2, 3, 0] #for display
var note_type_order_save = [4, 64, 16, 64, 8, 64, 16, 64, 4] #for save

func _init():
	load_shortcuts("res://addons/beat_map_editor/shortcuts.json")

func _ready():
	file_dialog.connect("file_selected", self, "_on_file_selected")

func get_note_type(y: int, save: bool = false):
	return (note_type_order_save if save else note_type_order)[y % len(note_type_order)]

func get_texture_atlas(tileset: TileSet, id: int):
	var texture = tileset.tile_get_texture(id)
	var texture_rect = tileset.tile_get_region(id)
	var result = AtlasTexture.new()
	result.atlas = texture
	result.region = texture_rect
	return result

func get_colored_note(tileset: TileSet, name, y: int):
	var id = tileset.find_tile_by_name("0" + str(int(name) + get_note_type(y)*16))
	assert(id >= 0)
	return get_texture_atlas(tileset, id)

func display_note_id_in_note_selector(tileset: TileSet, id: int):
	var name = tileset.tile_get_name(id)
	return name[0] == "0" and int(name.substr(1)) < 16

func load_shortcuts(file_path):
	var file = File.new()
	if not file.file_exists(file_path):
		save_tileset_shortcuts(file_path)
	file.open(file_path,File.READ)
	var dict = JSON.parse(file.get_as_text()).result
	keyboard_note_shortcuts = {}
	keyboard_note_shortcuts_inv = {}
	for key in dict:
		keyboard_note_shortcuts_inv[dict[key]] = int(key)
		keyboard_note_shortcuts[int(key)] = dict[key]

func save_tileset_shortcuts(file_path: String):
	var file = File.new()
	file.open(file_path,File.WRITE)
	file.store_string(JSON.print(keyboard_note_shortcuts))
	file.close()

func _on_SaveShortcuts_pressed():
	save_tileset_shortcuts("res://addons/beat_map_editor/shortcuts.json")

func save_beat_map(file_path):
	var file = File.new()
	file.open(file_path,File.WRITE)
	var array_beat_map = [
		int($HBoxContainer/Actions/VBoxContainer/BMP.text),
		int($HBoxContainer/Actions/VBoxContainer/SpeedMultiplier.text),
		int($HBoxContainer/Actions/VBoxContainer/SongIndex.text),
	]
	var beat_map_keys = beat_map.keys()
	beat_map_keys.sort()
	var max_index = beat_map_keys[len(beat_map_keys)-1]
	
	for key in beat_map_keys:
		array_beat_map.append([get_note_type(key, true), key, int(beat_map[key].name)])
	file.store_string(JSON.print(array_beat_map))
	file.close()


func _on_SaveBeatmap_pressed():
	file_dialog.mode=FileDialog.MODE_SAVE_FILE
	file_dialog.popup_centered(Vector2(400, 400))

func _on_OpenBeatmap_pressed():
	file_dialog.mode=FileDialog.MODE_OPEN_FILE
	file_dialog.popup_centered(Vector2(400, 400))

func _on_file_selected(path):
	match file_dialog.mode:
		FileDialog.MODE_SAVE_FILE:
			save_beat_map(file_dialog.current_file)
		FileDialog.MODE_OPEN_FILE:
			var file = File.new()
			file.open(file_dialog.current_file,File.READ)
			var beat_map_array = JSON.parse(file.get_as_text()).result
			$HBoxContainer/Actions/VBoxContainer/BMP.text = str(beat_map_array[0])
			$HBoxContainer/Actions/VBoxContainer/SpeedMultiplier.text = str(beat_map_array[1])
			$HBoxContainer/Actions/VBoxContainer/SongIndex.text = str(beat_map_array[2])
			beat_map.clear()
			for i in range(3, len(beat_map_array)):
				var arr = beat_map_array[i]
				var y = arr[1]
				var name = arr[2]
				beat_map[y] = {
					name=name
				}
			$HBoxContainer/NoteEditor.refresh()

