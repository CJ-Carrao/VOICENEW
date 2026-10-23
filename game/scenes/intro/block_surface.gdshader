shader_type canvas_item;
render_mode unshaded;
// Bisel curto: uma luz no topo/esquerda e sombra nas faces opostas, sem textura externa.
uniform float bevel = 0.14;
uniform float highlight = 0.3;
uniform float shade = 0.36;
void fragment() {
	float top = 1.0 - smoothstep(0.0, bevel, UV.y);
	float left = 1.0 - smoothstep(0.0, bevel, UV.x);
	float bottom = smoothstep(1.0 - bevel, 1.0, UV.y);
	float right = smoothstep(1.0 - bevel, 1.0, UV.x);
	COLOR.rgb = COLOR.rgb * (1.0 - shade * max(bottom, right));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), highlight * max(top, left));
}
