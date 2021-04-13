tool
extends MarginContainer

#TODO make ui for setting this stuff
var tileset = preload("res://tilesets/noteskins.tres")
var tile_size = Vector2(64, 64)
var keyboard_note_shortcuts = {}
var keyboard_note_shortcuts_inv = {}
var beat_map = {}
var plugin

onready var file_dialog = $FileDialog
onready var file_dialog_select_songs = $SelectSongsFile
onready var confirmation_dialog = $ConfirmationDialog
var _confirmation_dialog_confirmed = false

export(NodePath) var note_editor_path
onready var note_editor = get_node(note_editor_path)
export(NodePath) var BMP_txt_path
onready var BMP_txt: TextEdit = get_node(BMP_txt_path)
export(NodePath) var speed_multiplier_txt_path
onready var speed_multiplier_txt: TextEdit = get_node(speed_multiplier_txt_path)
export(NodePath) var song_index_txt_path
onready var song_index_txt: TextEdit = get_node(song_index_txt_path)

export(NodePath) var open_file_label_path
onready var open_file_label: Label = get_node(open_file_label_path)

# 1 (4), 1/2 (8), 1/4 (16), 1/16 (64)
var note_type_order = [0, 3, 2, 3, 1, 3, 2, 3] #for display
var note_type_order_save = [4, 64, 16, 64, 8, 64, 16, 64] #for save
var currently_open_file = ""
var modified = false

var EDITOR_SETTINGS_PATH

var song_file_path
var songs
var songs_directory

func _ready():
	EDITOR_SETTINGS_PATH = filename.get_base_dir() + "/../../editor_settings.json"
	load_editor_settings(EDITOR_SETTINGS_PATH)
	file_dialog.connect("file_selected", self, "_on_file_selected")
	file_dialog_select_songs.connect("file_selected", self, "_on_songs_file_selected")
	note_editor.connect("tiles_modified", self, "_on_tiles_modified")
	plugin.connect("resource_saved", self, "_on_resource_saved")
	confirmation_dialog.connect("confirmed", self, "_on_confirmation_dialog_confirmed")


func _on_resource_saved(resource):
	if visible:
		_on_SaveBeatmap_pressed()

func _on_tiles_modified():
	modified = true
	refresh_open_file_label()

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

func load_editor_settings(file_path):
	var file = File.new()
	if not file.file_exists(file_path):
		save_editor_settings(file_path)
	file.open(file_path,File.READ)
	var dict = JSON.parse(file.get_as_text()).result
	file.close()
	var dict_keyboard_note_shortcuts = dict["keyboard_note_shortcuts"]
	keyboard_note_shortcuts = {}
	keyboard_note_shortcuts_inv = {}
	for key in dict_keyboard_note_shortcuts:
		keyboard_note_shortcuts_inv[dict_keyboard_note_shortcuts[key]] = int(key)
		keyboard_note_shortcuts[int(key)] = dict_keyboard_note_shortcuts[key]
	song_file_path = dict["song_file_path"]
	songs_directory = dict["songs_directory"]
	if song_file_path and file.file_exists(song_file_path):
		file.open(song_file_path,File.READ)
		songs = JSON.parse(file.get_as_text()).result
		file.close()

func save_editor_settings(file_path: String):
	var file = File.new()
	file.open(file_path,File.WRITE)
	file.store_string(JSON.print({
		keyboard_note_shortcuts = keyboard_note_shortcuts,
		song_file_path = song_file_path,
		songs_directory = songs_directory
	}))
	file.close()

func _on_SaveSettings_pressed():
	save_editor_settings(EDITOR_SETTINGS_PATH)

func save_beat_map():
	var file = File.new()
	file.open(currently_open_file,File.WRITE)
	var array_beat_map = [
		int(BMP_txt.text),
		int(speed_multiplier_txt.text),
		int(song_index_txt.text),
	]
	var beat_map_keys = beat_map.keys()
	beat_map_keys.sort()
	var max_index = beat_map_keys[len(beat_map_keys)-1]
	
	for key in beat_map_keys:
		array_beat_map.append([get_note_type(key, true), key, int(beat_map[key].name)])
	file.store_string(JSON.print(array_beat_map))
	file.close()
	modified = false
	refresh_open_file_label()
	print("Saved beatmap at " + currently_open_file)


func _on_SaveBeatmap_pressed():
	if currently_open_file.empty():
		show_save_beatmap_dialog()
	else:
		save_beat_map()

func _on_OpenBeatmap_pressed():
	var open = true
	if modified:
		confirmation_dialog.dialog_text = "Are you sure you want to open another beatmap?"
		yield(open_confirmation_dialog(), "completed")
		open = _confirmation_dialog_confirmed
	if open:
		file_dialog.mode=FileDialog.MODE_OPEN_FILE
		file_dialog.window_title = "Open beatmap"
		file_dialog.set_filters(PoolStringArray(["*.json"]))
		file_dialog.popup_centered(Vector2(400, 400))

func refresh_open_file_label():
	open_file_label.text = currently_open_file + ("*" if modified else "")


func _on_SaveBeatmapAs_pressed():
	show_save_beatmap_dialog()

func show_save_beatmap_dialog():
	file_dialog.mode=FileDialog.MODE_SAVE_FILE
	file_dialog.window_title = "Save beatmap"	
	file_dialog.set_filters(PoolStringArray(["*.json"]))
	file_dialog.popup_centered(Vector2(400, 400))


func _on_ClearBeatmap_pressed():
	var undo_redo: UndoRedo = plugin.undo_redo
	var beat_map_clone = beat_map.duplicate()
	undo_redo.create_action("Clear Beatmap")
	undo_redo.add_do_method(self, "_clear_beatmap")
	undo_redo.add_undo_property(self, "beat_map", beat_map_clone)
	undo_redo.add_do_method(note_editor, "refresh")
	undo_redo.add_undo_method(note_editor, "refresh")
	undo_redo.add_do_property(note_editor, "_current_y", 0)
	undo_redo.add_undo_property(note_editor, "_current_y", note_editor._current_y)
	undo_redo.add_do_method(note_editor, "_update_keyboard_selection_box")
	undo_redo.add_undo_method(note_editor, "_update_keyboard_selection_box")
	undo_redo.commit_action()

func _clear_beatmap():
	beat_map.clear()

func _on_NewBeatmap_pressed():
	var clear = true
	if modified:
		confirmation_dialog.dialog_text = "Are you sure you want to make a new beatmap without saving?"
		yield(open_confirmation_dialog(),"completed")
		clear = _confirmation_dialog_confirmed
	if clear:
		beat_map.clear()
		note_editor._current_y = 0
		note_editor._update_keyboard_selection_box()
		note_editor.refresh()
		currently_open_file = ""
		modified = false

func open_confirmation_dialog():
	_confirmation_dialog_confirmed = false
	confirmation_dialog.popup_centered(Vector2(200, 50))
	yield(confirmation_dialog, "popup_hide")

func _on_confirmation_dialog_confirmed():
	_confirmation_dialog_confirmed = true
	confirmation_dialog.hide()

func _on_PlaySongFromStart_pressed():
	var player = $AudioStreamPlayer
	if player.playing:
		player.stop()
		note_editor.stop_playing()
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromStart".text = "Play Song From Start"
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromHere".text = "Play Song From Here"
	else:
		player.stream = load(songs_directory + "/" + songs[int(song_index_txt.text)].get_file())
		player.volume_db = -20
		player.play()
		note_editor.play_notes(int(BMP_txt.text), int(BMP_txt.text)/60.0 * int(speed_multiplier_txt.text))
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromStart".text = "Stop Playing"
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromHere".text = "Stop Playing"

func _on_PlaySongFromHere_pressed():
	var player = $AudioStreamPlayer
	if player.playing:
		player.stop()
		note_editor.stop_playing()
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromStart".text = "Play Song From Start"
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromHere".text = "Play Song From Here"
	else:
		player.stream = load(songs_directory + "/" + songs[int(song_index_txt.text)].get_file())
		player.volume_db = -20
		player.play()
		player.seek(note_editor.get_current_time())
		note_editor.play_notes(int(BMP_txt.text), int(BMP_txt.text)/60.0 * int(speed_multiplier_txt.text), note_editor.get_current_time())
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromStart".text = "Stop Playing"
		$"VBoxContainer/HBoxContainer/Actions/VBoxContainer/PlaySongFromHere".text = "Stop Playing"

func _on_SelectSongsFolder_pressed():
	file_dialog_select_songs.mode=FileDialog.MODE_OPEN_FILE
	file_dialog_select_songs.popup_centered(Vector2(400, 400))

func _on_songs_file_selected(path):
	song_file_path = path
	songs_directory = path.get_base_dir()
	var file = File.new()
	if song_file_path and file.file_exists(song_file_path):
		file.open(song_file_path,File.READ)
		songs = JSON.parse(file.get_as_text()).result
		file.close()
	

#Too lazy to make more than one dialogue c:
func _on_file_selected(path):
	match file_dialog.mode:
		FileDialog.MODE_SAVE_FILE:
			currently_open_file = path
			save_beat_map()
		FileDialog.MODE_OPEN_FILE:
			var file = File.new()
			file.open(path,File.READ)
			modified = false
			var beat_map_array = JSON.parse(file.get_as_text()).result
			BMP_txt.text = str(beat_map_array[0])
			speed_multiplier_txt.text = str(beat_map_array[1])
			song_index_txt.text = str(beat_map_array[2])
			beat_map.clear()
			for i in range(3, len(beat_map_array)):
				var arr = beat_map_array[i]
				var y = arr[1]
				var name = arr[2]
				beat_map[y] = {
					name=name
				}
			note_editor.refresh()
			currently_open_file = path
			refresh_open_file_label()
			note_editor._current_y = 0
			note_editor._update_keyboard_selection_box()
			note_editor.refresh()

