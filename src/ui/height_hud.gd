extends CanvasLayer
class_name HeightHUD

@onready var player_system: PlayerSystem = get_node("../Player")

var readout: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.09, 0.12, 0.88)
	panel_style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	readout = Label.new()
	readout.add_theme_color_override("font_color", Color(0.91, 0.96, 0.84))
	readout.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	readout.add_theme_constant_override("shadow_offset_x", 1)
	readout.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(readout)
	add_child(panel)


func _process(_delta: float) -> void:
	var cell := player_system.world_system.world_to_cell(player_system.global_position)
	var state := "NO CHAO" if player_system.is_grounded else "NO AR / CAINDO"
	readout.text = "PSEUDO-3D  |  MAPA 64 x 64 x 8\n"
	readout.text += "POS %02d, %02d   ALTURA %.2f   %s\n" % [cell.x, cell.y, player_system.elevation, state]
	readout.text += "WASD/SETAS mover   ESPACO pular   R reiniciar\n"
	readout.text += "ESCADAS   PARKOUR/QUEDA   PONTE/TUNEL   TELHADO"
