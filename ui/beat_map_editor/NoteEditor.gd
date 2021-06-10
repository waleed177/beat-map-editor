tool
extends Control

onready var _note_selector = get_node("../NoteSelector")
onready var _scene = get_owner()
onready var _selection_box = $Scrolling/SelectionBox
onready var _keyboard_selection_box = $Scrolling/KeyboardSelectionBox
onready var _scrolling = $Scrolling

signal tiles_modified

var _beat_map_nodes = {}
var _scroll_speed = 25
var _current_keyboard_position := Vector2(0, 0)
var _max_y = 0

var _key_numbers = range(KEY_0, KEY_9+1)
var _collapse_spaces = false
var mode = "none"
var _selection_currently_selecting = false
var _selection_first_position := Vector2(0, 0)
var _selection_second_position := Vector2(0, 0)
var _selection_stabilize_selection = false

var _clipboard = {
	data = {},
	from = Vector2(0,0),
	to = Vector2(0,0)
}

func _ready():
	focus_mode = Control.FOCUS_CLICK
	_note_selector.connect("note_selection_changed", self, "_on_note_selection_changed")
	refresh()
	

func _on_note_selection_changed(note):
	mode = "place"
	_selection_stabilize_selection = false
	_selection_currently_selecting = false
	_selection_box.rect_size = _scene.tile_size

func _on_NoTool_pressed():
	mode = "none"
	_selection_stabilize_selection = false
	_selection_currently_selecting = false
	_selection_box.rect_size = _scene.tile_size

func _on_SelectTool_pressed():
	mode = "select"

func _on_CopyButton_pressed():
	_clipboard["data"] = {}
	_clipboard["from"] = _selection_first_position
	_clipboard["to"] = _selection_second_position
	for i in _better_range(_selection_first_position.x, _selection_second_position.x, _scene.number_of_lanes):
		for j in _better_range(_selection_first_position.y, _selection_second_position.y, 200):
			_clipboard["data"][str(i) + " " + str(j)] = _get_tile(i, j)

func _on_PasteButton_pressed():
	mode = "paste"
	_selection_stabilize_selection = false


func _unhandled_key_input(event):
	if event.pressed and event.scancode in _scene.keyboard_note_shortcuts:
		var key_data =  _scene.keyboard_note_shortcuts[event.scancode]
		
		_undoable_set_tile(_current_keyboard_position.x if key_data.x == -1 else key_data.x, _current_keyboard_position.y, {
			name= _scene.keyboard_note_shortcuts[event.scancode].tile_name
		})
		if not song_playing:
			_current_keyboard_position.y += 1
		_update_keyboard_selection_box()
	if event.pressed and event.scancode in _key_numbers:
		_current_keyboard_position.y += event.scancode-KEY_0
		_update_keyboard_selection_box()
		

func _gui_input(event):
	if not _scene.visible:
		return false
	if event is InputEventMouseMotion:
		var pos = event.position - _scrolling.rect_position
		var tile_x = floor(pos.x/_scene.tile_size.x)
		var tile_y = floor(pos.y/_scene.tile_size.y)
		
		_selection_box.show()
		if mode == "paste":
			_selection_first_position = Vector2(tile_x, tile_y)
			_selection_second_position = _selection_first_position + vector_abs(_clipboard["to"]-_clipboard["from"])
		if _selection_currently_selecting:
			if not _selection_stabilize_selection:
				if mode != "paste":
					_selection_second_position = Vector2(tile_x,tile_y)
				var delta = _selection_second_position-_selection_first_position
				
				_selection_box.rect_position = vector_pmul(vector_min_coord(_selection_first_position, _selection_second_position),  _scene.tile_size)
				_selection_box.rect_size = vector_pmul(vector_abs(vector_comp_abs_add(delta, 1)), _scene.tile_size)
		else:
			if 0 <= tile_x and tile_x < _scene.number_of_lanes:
				_selection_box.rect_position = Vector2(tile_x*_scene.tile_size.x, tile_y*_scene.tile_size.y)
			else:
				_selection_box.hide()
	if event is InputEventMouseButton:
		var pos = event.position - _scrolling.rect_position
		var tile_x = floor(pos.x/_scene.tile_size.x)
		var tile_y = floor(pos.y/_scene.tile_size.y)
		if event.pressed:
			match event.button_index:
				BUTTON_LEFT:
					match mode:
						"place":
							if 0 <= tile_x and tile_x < _scene.number_of_lanes:
								_undoable_set_tile(tile_x, tile_y, { 
									name = _note_selector.selected_note
								})
						"select":
							_selection_currently_selecting = true
							_selection_stabilize_selection = false
							_selection_first_position = Vector2(tile_x, tile_y)
						"paste":
							var undo_redo: UndoRedo = _scene.plugin.undo_redo
							undo_redo.create_action("Paste")
							var min_x = min(_clipboard["from"].x, _clipboard["to"].x)
							var min_y = min(_clipboard["from"].y, _clipboard["to"].y)
							for i in _better_range(_clipboard["from"].x, _clipboard["to"].x, _scene.number_of_lanes):
								for j in _better_range(_clipboard["from"].y, _clipboard["to"].y, 200):
									var str_pos = str(i) + " " + str(j)
									_undoable_set_tile(tile_x+i-min_x, tile_y+j-min_y, _clipboard["data"][str_pos] if str_pos in _clipboard["data"] else {}, false)
							undo_redo.commit_action()
				BUTTON_RIGHT:
					if 0 <= tile_x and tile_x < _scene.number_of_lanes:
						match mode:
							"place", "none":
								_undoable_set_tile(tile_x, tile_y, {})
							"paste":
								var undo_redo: UndoRedo = _scene.plugin.undo_redo
								undo_redo.create_action("Clear")
								var min_x = min(_clipboard["from"].x, _clipboard["to"].x)
								var min_y = min(_clipboard["from"].y, _clipboard["to"].y)
								for i in _better_range(_clipboard["from"].x, _clipboard["to"].x, _scene.number_of_lanes):
									for j in _better_range(_clipboard["from"].y, _clipboard["to"].y, 200):
										_undoable_set_tile(tile_x+i-min_x, tile_y+j-min_y, {}, false)
								undo_redo.commit_action()
							"select":
								var undo_redo: UndoRedo = _scene.plugin.undo_redo
								undo_redo.create_action("Clear")

								for i in _better_range(_selection_first_position.x, _selection_second_position.x, _scene.number_of_lanes):
									for j in _better_range(_selection_first_position.y, _selection_second_position.y, 200):
										_undoable_set_tile(i, j, {}, false)
								undo_redo.commit_action()
				BUTTON_WHEEL_UP:
					_scrolling.rect_position += Vector2.DOWN * _scroll_speed
					update()
					_refresh_scroll_bar()
				BUTTON_WHEEL_DOWN:
					_scrolling.rect_position += Vector2.UP * _scroll_speed
					update()
					_refresh_scroll_bar()
				BUTTON_MIDDLE:
					if 0 <= tile_x and tile_x < _scene.number_of_lanes:
						_current_keyboard_position.x = tile_x
						_current_keyboard_position.y = tile_y
						_update_keyboard_selection_box()
		else:
			match event.button_index:
				BUTTON_LEFT:
					match mode:
						"select":
							_selection_currently_selecting = true
							_selection_stabilize_selection = true

func _refresh_scroll_bar():
	_scrolling.rect_position.y = min(0, _scrolling.rect_position.y)
	$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y


func _set_tile(x: int, y: int, data, modify: bool = true, actual_y: int = -1):
	var pos_str = str(x) + " " + str(y)
	if 0 > x or x >= _scene.number_of_lanes: return false
	assert(y != NAN)
	if y < 0:
		return
	if modify:
		emit_signal("tiles_modified")
	if data == null or data.empty():
		if pos_str in _beat_map_nodes:
			if modify:
				_scene.beat_map.erase(pos_str)
			_beat_map_nodes[pos_str].queue_free()
			_beat_map_nodes.erase(pos_str)
			if y == _max_y:
				var max_y = 0
				for key in _beat_map_nodes.keys():
					var num = int(key.split(" ")[1]) 
					if num > max_y:
						max_y = num
						print(num)
				_set_max_y(max_y)
	elif not pos_str in _beat_map_nodes or _beat_map_nodes[pos_str] == null:
		if modify:
			_scene.beat_map[pos_str] = data
		
		var texture_button = TextureButton.new()
		texture_button.texture_normal = _scene.get_colored_note(_scene.tileset, data.name, y if actual_y == -1 else actual_y)
		texture_button.anchor_left = _selection_box.anchor_left
		texture_button.anchor_right = _selection_box.anchor_right
		texture_button.mouse_filter = Control.MOUSE_FILTER_PASS
		texture_button.expand = true
		texture_button.rect_size = _scene.tile_size
		_scrolling.add_child(texture_button)
		texture_button.rect_position = Vector2(x*_scene.tile_size.x, y*_scene.tile_size.y)
		
		_beat_map_nodes[pos_str] = texture_button
		
		if y >= _max_y:
			_set_max_y(y)
	else:
		_beat_map_nodes[pos_str].texture_normal = _scene.get_colored_note(_scene.tileset, data.name, y if actual_y == -1 else actual_y)
		if modify:
			_scene.beat_map[pos_str] = data

func _get_tile(x: int, y: int):
	return _scene.beat_map[str(x) + " " + str(y)] if (str(x) + " " + str(y)) in _scene.beat_map else {}

func _undoable_set_tile(x: int, y: int, data, commit_action = true):
	var undo_redo: UndoRedo = _scene.plugin.undo_redo
	if commit_action:
		undo_redo.create_action("Set Tile")
	undo_redo.add_do_method(self, "_set_tile", x, y, data)
	undo_redo.add_undo_method(self, "_set_tile", x, y, _get_tile(x, y))
	if commit_action:
		undo_redo.commit_action()

func _set_scroll_y(y):
	_scrolling.rect_position = Vector2(
		_scrolling.rect_position.x,
		min(0, rect_size.y/2  - _keyboard_selection_box.rect_size.y/2 - y)
	)
	update()
	_refresh_scroll_bar()

func _update_keyboard_selection_box():
	if song_playing:
		_keyboard_selection_box.rect_position = Vector2(0, _current_keyboard_position.y*_scene.tile_size.y)
		_keyboard_selection_box.rect_size = Vector2(_scene.tile_size.x*_scene.number_of_lanes, _scene.tile_size.y)
	else:
		_keyboard_selection_box.rect_position = Vector2(_current_keyboard_position.x*_scene.tile_size.x, _current_keyboard_position.y*_scene.tile_size.y)
		_keyboard_selection_box.rect_size = Vector2(_scene.tile_size.x, _scene.tile_size.y)
	_set_scroll_y(_current_keyboard_position.y*_scene.tile_size.y)
	$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y
	_refresh_scroll_bar()

func refresh():
	_scrolling.rect_position.x = rect_size.x/2 + _scrolling.rect_size.x/2 - _scene.tile_size.x*(_scene.number_of_lanes)/2
	_set_max_y(1)
	update()
	_refresh_scroll_bar()
	_update_keyboard_selection_box()
	
	for key in _beat_map_nodes:
		_beat_map_nodes[key].queue_free()
	_beat_map_nodes.clear()
	if not _scene.beat_map.empty():
		var sorted_keys = _scene.beat_map.keys()
		sorted_keys.sort_custom(self, "_beat_map_nodes_sorter") #TODO: dont sort
		_set_max_y(int(sorted_keys[len(sorted_keys) - 1].split(" ")[1]))
		for key in sorted_keys:
			var xy = key.split(" ")
			var x = int(xy[0])
			var y = int(xy[1])
			_set_tile(x, y, _scene.beat_map[key], false, y)
	update()

func _beat_map_nodes_sorter(stra, strb):
	return int(stra.split(" ")[1]) < int(strb.split(" ")[1]) 

func _set_max_y(val):
	_max_y = val
	var height = $VScrollBar.rect_size.y/(_scene.tile_size.y*_max_y) if _max_y != 0 else 1
	height = clamp(height, 0, 0.9)
	height *= $VScrollBar.rect_size.y
	$VScrollBar.get_stylebox("grabber").border_width_top = height/2.0
	$VScrollBar.get_stylebox("grabber").border_width_bottom = height/2.0
	$VScrollBar.max_value = _max_y

func _on_CollapseSpaces_pressed():
	_collapse_spaces = not _collapse_spaces
	refresh()


func _on_VScrollBar_scrolling():
	_scrolling.rect_position.y = - _scene.tile_size.y * $VScrollBar.value
	update()

########################################
var song_time_delay = AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
var song_bpm
var song_speed
var song_playing = false
var song_time = 0
var song_scroll_y = 0

func play_notes(bpm, speed, from_current_keyboard_position = false):
	song_bpm = float(bpm)
	song_speed = speed
	song_time = _get_time_from_y() if from_current_keyboard_position else 0
	song_playing = true

func _get_time_from_y():
	return _current_keyboard_position.y/(song_bpm*(8.0/120.0))

func stop_playing():
	song_playing = false

func _process(delta):
	if song_playing:
		notes_step(delta)

onready var _keyboard_selection_box_color = _keyboard_selection_box.color

func _should_tick_at_y(y):
	for x in _scene.number_of_lanes:
		var tile: Dictionary = _get_tile(x, y)
		if not tile.empty():
			return true
	return false

func notes_step(delta):
	song_time += delta
	song_scroll_y = song_bpm*song_time*((float(_scene.tile_size.y)/120.0)*8.0)
	_set_scroll_y(song_scroll_y)
	_keyboard_selection_box.rect_position = Vector2(0, song_scroll_y)
	var new_y = floor(song_scroll_y/_scene.tile_size.y)
	$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y
	if _current_keyboard_position.y != new_y:
		_current_keyboard_position.y = new_y
		_update_keyboard_selection_box()
		if _should_tick_at_y(new_y):
			$Tick.play()
#		_keyboard_selection_box.color = Color.lightgreen
#		yield(get_tree().create_timer(0.05), "timeout")
#		_keyboard_selection_box.color = _keyboard_selection_box_color


func _better_range(from: int, to: int, max_range: int):
	if from == to:
		return [from]
	var dir = sign(to - from)
	if abs(from-to) > max_range:
		to = from + max_range*dir
	return range(from, to+dir, dir)

func _draw():
	var scroll_y = -int(_scrolling.rect_position.y / _scene.tile_size.y)
	var sorted_keys
	var max_y
	if _collapse_spaces:
		sorted_keys = _scene.beat_map.keys()
		sorted_keys.sort()
		max_y = sorted_keys[len(sorted_keys)-1] if not sorted_keys.empty() else 0
	for i in range(0, ceil(rect_size.y / _scene.tile_size.y) + 1):
		var y = i * _scene.tile_size.y + fmod(_scrolling.rect_position.y, _scene.tile_size.y)
		var current_y_int 
		
		if _collapse_spaces:
			if i+scroll_y < len(sorted_keys):
				current_y_int = sorted_keys[i+scroll_y]
			else:
				current_y_int = max_y + (scroll_y + i) - len(sorted_keys) + 1
		else:
			current_y_int = scroll_y + i
		
		draw_string(
			get_font(""), 
			Vector2(0, y + _scene.tile_size.y/4), 
			str(current_y_int)
		)
		draw_line(
			Vector2(0, y), 
			Vector2(rect_size.x, y),
			Color.black,
			2 if current_y_int % 4 == 0 else 1
		)
		draw_line(
			Vector2(_scrolling.rect_position.x, 0),
			Vector2(_scrolling.rect_position.x, rect_size.y),
			Color(0.1, 0.1, 0.1)
		)
		var line_x = _scrolling.rect_position.x + _scene.tile_size.x*(_scene.number_of_lanes)
		draw_line(
			Vector2(line_x, 0),
			Vector2(line_x, rect_size.y),
			Color(0.1, 0.1, 0.1)
		)


static func vector_comp_abs_add(v: Vector2, i: int):
	return Vector2(v.x + sign_zero(v.x)*i, v.y + sign_zero(v.y)*i)

static func vector_abs(v: Vector2):
	return Vector2(abs(v.x), abs(v.y))

static func vector_min_coord(v1: Vector2, v2: Vector2):
	return Vector2(min(v1.x, v2.x), min(v1.y, v2.y))

static func sign_zero(x, num = 1):
	return num if x == 0 else sign(x)

static func vector_pmul(a: Vector2, b: Vector2):
	return Vector2(a.x*b.x, a.y*b.y)
