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
onready var BMP_txt: LineEdit = get_node(BMP_txt_path)
export(NodePath) var speed_multiplier_txt_path
onready var speed_multiplier_txt: LineEdit = get_node(speed_multiplier_txt_path)
export(NodePath) var song_index_txt_path
onready var song_index_txt: LineEdit = get_node(song_index_txt_path)

export(NodePath) var time_offset_txt_path
onready var time_offset_txt: LineEdit = get_node(time_offset_txt_path)

export(NodePath) var open_file_label_path
onready var open_file_label: Label = get_node(open_file_label_path)

export(NodePath) var player_song_from_start_button_path
onready var player_song_from_start_button: Button = get_node(player_song_from_start_button_path)

export(NodePath) var player_song_from_here_button_path
onready var player_song_from_here_button: Button = get_node(player_song_from_here_button_path)

# 1 (4), 1/2 (8), 1/4 (16), 1/16 (64)
var note_type_order = [0, 3, 2, 3, 1, 3, 2, 3] 
var currently_open_file = ""
var modified = false

var EDITOR_SETTINGS_PATH

var song_file_path
var songs
var songs_directory

var number_of_lanes = 4

var undo_redo: UndoRedo = UndoRedo.new()

func _ready():
	EDITOR_SETTINGS_PATH = filename.get_base_dir() + "/../../editor_settings.json"
	load_editor_settings(EDITOR_SETTINGS_PATH)
	file_dialog.connect("file_selected", self, "_on_file_selected")
	file_dialog_select_songs.connect("file_selected", self, "_on_songs_file_selected")
	note_editor.connect("tiles_modified", self, "_on_tiles_modified")
	confirmation_dialog.connect("confirmed", self, "_on_confirmation_dialog_confirmed")
	
	get_tree().get_root().connect("size_changed", self, "_on_window_resized")
	_on_window_resized()

	get_tree().set_auto_accept_quit(false)

func _notification(request):
	if (request == MainLoop.NOTIFICATION_WM_QUIT_REQUEST):
		if modified:
			$ExitDialog.popup_centered(Vector2(200, 50))
		else:
			get_tree().quit()
		

func _on_window_resized():
	var size = note_editor.rect_size.y/10
	tile_size = Vector2(size, size)
	note_editor.refresh()

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.control:
			var button_clicked = true
			if event.scancode == KEY_Z && event.shift:
				undo_redo.redo()
			elif event.scancode == KEY_Z:
				undo_redo.undo()
			elif event.scancode == KEY_S:
				_on_SaveBeatmap_pressed()
			else:
				button_clicked = false
			
			if button_clicked:
				get_tree().set_input_as_handled()
		

func _on_tiles_modified():
	modified = true
	refresh_open_file_label()

func get_note_type(y: int, save: bool = false):
	return note_type_order[y % len(note_type_order)]

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
		keyboard_note_shortcuts_inv[dict_keyboard_note_shortcuts[key].tile_name] = int(key)
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
		float(speed_multiplier_txt.text),
		int(song_index_txt.text),
	]
	var beat_map_keys = beat_map.keys()
	beat_map_keys.sort_custom(self, "_beat_map_keys_sorter")
	var max_index = int(beat_map_keys[len(beat_map_keys)-1].split(" ")[1])
	
	for i in number_of_lanes:
		array_beat_map.append([])
	
	for key in beat_map_keys:
		var sp = key.split(" ")
		var x = int(sp[0])
		var y = int(sp[1])
		var arr = array_beat_map[x+3]
		arr.append([get_note_type(y, true), y, int(beat_map[key].name)])
	
	file.store_string(JSON.print(array_beat_map))
	file.close()
	modified = false
	refresh_open_file_label()
	print("Saved beatmap at " + currently_open_file)

func _beat_map_keys_sorter(key_a:String, key_b: String):
	var y1 = int(key_a.split(" ")[1])
	var y2 = int(key_b.split(" ")[1])
	return y1 < y2 

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
	undo_redo.create_action("Clear Beatmap")
	undo_redo.add_do_method(self, "_clear_beatmap")
	undo_redo.add_undo_property(self, "beat_map",  beat_map.duplicate())
	undo_redo.add_do_method(note_editor, "refresh")
	undo_redo.add_undo_method(note_editor, "refresh")
	undo_redo.add_do_property(note_editor, "_current_keyboard_position", Vector2(0, 0))
	undo_redo.add_undo_property(note_editor, "_current_keyboard_position", note_editor._current_keyboard_position)
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
		note_editor._current_keyboard_position = Vector2(0, 0)
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
		player_song_from_start_button.get_node("Label").text = "Play Song\nFrom Start"
		player_song_from_here_button.get_node("Label").text = "Play Song\nFrom Here"
	else:
		player.stream = GDScriptAudioImporter.loadfile(songs_directory + "/" + songs[int(song_index_txt.text)].get_file())
		player.volume_db = -20
		note_editor.play_notes(int(BMP_txt.text), float(speed_multiplier_txt.text), float(time_offset_txt.text))
		player_song_from_start_button.get_node("Label").text = "Stop Playing"
		player_song_from_here_button.get_node("Label").text = "Stop Playing"

func _on_PlaySongFromHere_pressed():
	var player = $AudioStreamPlayer
	if player.playing:
		player.stop()
		note_editor.stop_playing()
		player_song_from_start_button.get_node("Label").text = "Play Song\nFrom Start"
		player_song_from_here_button.get_node("Label").text = "Play Song\nFrom Here"
	else:
		player.stream = GDScriptAudioImporter.loadfile(songs_directory + "/" + songs[int(song_index_txt.text)].get_file())
		player.volume_db = -20
		note_editor.play_notes(int(BMP_txt.text), float(speed_multiplier_txt.text), float(time_offset_txt.text), true)
		player_song_from_start_button.get_node("Label").text = "Stop Playing"
		player_song_from_here_button.get_node("Label").text = "Stop Playing"

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
			for x in beat_map_array.size()-3:
				var beat_map_1d = beat_map_array[x+3]
				for i in range(0, len(beat_map_1d)):
					var arr = beat_map_1d[i]
					var y = arr[1]
					var name = arr[2]
					beat_map[str(x) + " " + str(y)] = {
						name=name
					}
			note_editor.refresh()
			currently_open_file = path
			refresh_open_file_label()
			note_editor._current_keyboard_position =  Vector2(0, 0)
			note_editor._update_keyboard_selection_box()
			note_editor.refresh()


func _on_ExitDialog_confirmed():
	get_tree().quit()
