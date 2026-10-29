shader_type canvas_item;

uniform vec2 player_screen_position = vec2(-1000.0, -1000.0);
uniform vec2 viewport_size = vec2(960.0, 540.0);
uniform float player_top = 0.72;
uniform float reveal_radius = 28.0;

void fragment() {
	float roof_height = COLOR.a * 8.0;
	vec2 fragment_position = SCREEN_UV * viewport_size;
	float player_distance = distance(fragment_position, player_screen_position);
	if (roof_height <= player_top || player_distance < reveal_radius) {
		discard;
	}
	COLOR = vec4(COLOR.rgb, 1.0);
}
