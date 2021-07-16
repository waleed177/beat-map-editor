extends Viewport

onready var texture_rect = $"./TextureRect"

func _ready():
	texture_rect.texture =  texture_rect.get_viewport().get_texture()
	
