tool
extends Control

onready var _note_selector = get_node("../NoteSelector")
onready var _scene = get_owner()
onready var _selection_box = $Scrolling/SelectionBox
onready var _keyboard_selection_box = $Scrolling/KeyboardSelectionBox
onready var _scrolling = $Scrolling

signal tiles_modified

onready var _tile_size = _scene.tile_size
var _beat_map_nodes = {}
var _scroll_speed = 25
var _current_y = 0
var _max_y = 0

var _key_numbers = range(KEY_0, KEY_9+1)
var _collapse_spaces = false

func _ready():
	focus_mode = Control.FOCUS_CLICK
	_set_max_y(1)

func _unhandled_key_input(event):
	if event.pressed and event.scancode in _scene.keyboard_note_shortcuts:
		_undoable_set_tile(_current_y, {
			name= _scene.keyboard_note_shortcuts[event.scancode]
		})
		_current_y += 1
		_update_keyboard_selection_box()
	if event.pressed and event.scancode in _key_numbers:
		_current_y += event.scancode-KEY_0
		_update_keyboard_selection_box()
		

func _gui_input(event):
	if not _scene.visible:
		return false
	if event is InputEventMouseMotion:
		var pos = event.position - _scrolling.rect_position
		_selection_box.rect_position = Vector2(_selection_box.rect_position.x, floor(pos.y/_tile_size.y)*_tile_size.y)
	if event is InputEventMouseButton:
		if event.pressed:
			var pos = event.position - _scrolling.rect_position
			var tile_x = floor((pos.x+_tile_size.x/2)/_tile_size.x)
			var tile_y = floor(pos.y/_tile_size.y)
			match event.button_index:
				BUTTON_LEFT:
					if tile_x == 0:
						_undoable_set_tile(tile_y, { 
							name = _note_selector.selected_note
						})
				BUTTON_RIGHT:
					if tile_x == 0:
						_undoable_set_tile(tile_y, {})
				BUTTON_WHEEL_UP:
					_scrolling.rect_position += Vector2.DOWN * _scroll_speed
					_scrolling.rect_position.y = min(0, _scrolling.rect_position.y)
					$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y
				BUTTON_WHEEL_DOWN:
					_scrolling.rect_position += Vector2.UP * _scroll_speed
					$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y
				BUTTON_MIDDLE:
					if tile_x == 0:
						_current_y = tile_y
						_update_keyboard_selection_box()

func _set_tile(y: int, data, modify: bool = true, actual_y: int = -1):
	assert(y != NAN)
	if y < 0:
		return
	if modify:
		emit_signal("tiles_modified")
	if data == null or data.empty():
		if modify:
			_scene.beat_map.erase(y)
		_beat_map_nodes[y].queue_free()
		_beat_map_nodes.erase(y)
		if y == _max_y:
			_set_max_y(_beat_map_nodes.keys().max())
	elif not y in _beat_map_nodes or _beat_map_nodes[y] == null:
		if modify:
			_scene.beat_map[y] = data
		
		var texture_button = TextureButton.new()
		texture_button.texture_normal = _scene.get_colored_note(_scene.tileset, data.name, y if actual_y == -1 else actual_y)
		texture_button.anchor_left = _selection_box.anchor_left
		texture_button.anchor_right = _selection_box.anchor_right
		texture_button.mouse_filter = Control.MOUSE_FILTER_PASS
		texture_button.expand = true
		texture_button.rect_size = _scene.tile_size
		_scrolling.add_child(texture_button)
		texture_button.rect_position = Vector2(_selection_box.rect_position.x, y*_tile_size.y)
		
		_beat_map_nodes[y] = texture_button
		
		if y >= _max_y:
			_set_max_y(y)
	else:
		_beat_map_nodes[y].texture_normal = _scene.get_colored_note(_scene.tileset, data.name, y if actual_y == -1 else actual_y)
		if modify:
			_scene.beat_map[y] = data

func _get_tile(y: int):
	return _scene.beat_map[y] if y in _scene.beat_map else {}

func _undoable_set_tile(y: int, data):
	var undo_redo: UndoRedo = _scene.plugin.undo_redo
	undo_redo.create_action("Set Tile")
	undo_redo.add_do_method(self, "_set_tile", y, data)
	undo_redo.add_undo_method(self, "_set_tile", y, _get_tile(y))
	undo_redo.commit_action()

func _update_keyboard_selection_box():
	_keyboard_selection_box.rect_position = Vector2(_keyboard_selection_box.rect_position.x, _current_y*_tile_size.y)
	_scrolling.rect_position = Vector2(
		_scrolling.rect_position.x,
		min(0, rect_size.y/2  - _keyboard_selection_box.rect_size.y/2-_keyboard_selection_box.rect_position.y)
	)
	$VScrollBar.value = abs(_scrolling.rect_position.y) / _scene.tile_size.y

func refresh():
	for key in _beat_map_nodes:
		_beat_map_nodes[key].queue_free()
	_beat_map_nodes.clear()
	var y = -1
	var sorted_keys = _scene.beat_map.keys()
	sorted_keys.sort()
	_set_max_y(sorted_keys[len(sorted_keys) - 1])
	for key in sorted_keys:
		if _collapse_spaces:
			y += 1
		else:
			y = key
		_set_tile(y, _scene.beat_map[key], false, key)

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

