# This file is for the beat map editor project.
#
# MIT License
# 
# Copyright (c) 2021 waleed177, lilybugged and other contributors
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
tool
extends MarginContainer

onready var _notes_container = $VBoxContainer/ScrollContainer/NotesContainer
onready var _scene = get_owner()

signal note_selection_changed
const NoteButton = preload("res://ui/note_button/note_button.tscn")
var selected_note = 0

var _mode = "normal"
var _selection = null

func _ready():
	call_deferred("refresh")

func refresh():
	var tile_ids = _scene.tileset.get_tiles_ids()
	print(_scene.keyboard_note_shortcuts_inv)
	for note in _notes_container.get_children():
		note.queue_free()
	for tile_id in tile_ids:
		if not _scene.display_note_id_in_note_selector(_scene.tileset, tile_id):
			continue
		var tile_name = _scene.tileset.tile_get_name(tile_id)
		var button = NoteButton.instance()
		button.texture_normal = _scene.get_texture_atlas(_scene.tileset, tile_id)
		button.rect_min_size = Vector2(0, 32)
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.expand = true
		button.connect("gui_input", self, "_on_note_button_gui_input", [tile_name, button])
		if tile_name in _scene.keyboard_note_shortcuts_inv:
			var scancode = _scene.keyboard_note_shortcuts_inv[tile_name]
			button.get_node("Shortcut").text = OS.get_scancode_string(scancode) + str(_scene.keyboard_note_shortcuts[scancode].x)
		else:
			button.get_node("Shortcut").text = ""
		_notes_container.add_child(button)

func _on_note_button_gui_input(event, tile_name, button: TextureButton):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				BUTTON_LEFT:
					selected_note = tile_name
					for child in _notes_container.get_children():
						child.select(false)
					button.select(true)
					emit_signal("note_selection_changed", selected_note)
				BUTTON_RIGHT:
					if _mode == "normal":
						_mode = "select_shortcut"
						_selection = {
							tile_name = tile_name,
							button = button
						}
						button.get_node("Shortcut").text = "_"
					elif _mode == "select_shortcut":
						_mode = "normal"
						button.get_node("Shortcut").text = ""
						_scene.keyboard_note_shortcuts.erase(_scene.keyboard_note_shortcuts_inv[tile_name])
						_scene.keyboard_note_shortcuts_inv.erase(tile_name)

func _input(event):
	if event is InputEventKey:
		if event.pressed and _mode == "select_shortcut":
			if KEY_0 <= event.scancode and event.scancode <= KEY_9:
				_selection.button.get_node("Shortcut").text = OS.get_scancode_string(_scene.keyboard_note_shortcuts_inv[_selection.tile_name]) + str(event.scancode - KEY_0)
				
				var scancode = int(_scene.keyboard_note_shortcuts_inv[_selection.tile_name])
				_scene.keyboard_note_shortcuts[scancode].x = event.scancode - KEY_0
				_mode = "normal"
			else:
				_selection.button.get_node("Shortcut").text = OS.get_scancode_string(event.scancode)
				if _selection.tile_name in _scene.keyboard_note_shortcuts_inv:
					_scene.keyboard_note_shortcuts.erase(_scene.keyboard_note_shortcuts_inv[_selection.tile_name])
				_scene.keyboard_note_shortcuts[event.scancode] = {
					tile_name= _selection.tile_name,
					x = -1
				} 
				_scene.keyboard_note_shortcuts_inv[_selection.tile_name] = event.scancode
				_mode = "normal"
			return true
