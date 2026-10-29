extends CanvasLayer
class_name HeightHUD

@onready var player_system: PlayerSystem = get_node("../Player")

var readout: Label
var _refresh_elapsed := 0.0


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


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.1:
		return
	_refresh_elapsed = 0.0
	var cell := player_system.world_system.world_to_cell(player_system.global_position)
	var state := "NO CHAO" if player_system.is_grounded else "PULANDO" if player_system.vertical_velocity > 0.0 else "CAINDO"
	var height_readout := "DEGRAU %d / 7" % floori(player_system.elevation + 0.01)
	if not player_system.is_grounded:
		var support_text := "BASE %d" % floori(player_system.shadow_elevation) if player_system._has_ground_shadow else "SEM APOIO"
		height_readout = "ALTURA %.2f  %s" % [player_system.elevation, support_text]
	var text := "MUNDO 64 x 64 x 8\n"
	text += "POS %02d, %02d   %s   %s\n" % [cell.x, cell.y, height_readout, state]
	text += "WASD/SETAS mover   ESPACO pular   R reiniciar\n"
	text += "SUBA PULANDO: 0 BAIXO -> 7 ALTO\n"
	text += "PARKOUR/QUEDA   PONTE/TUNEL   TELHADO"
	if readout.text != text:
		readout.text = text
