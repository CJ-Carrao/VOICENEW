// Giz do rascunho (Lavoisier L2, DESIGN 17.1): o contorno de onde a coisa vai nascer, desenhado como giz (grão e
// riscos na tela, borda mais forte), não holograma (Regra 9: nada de construto brilhante). Sem luz e sem sombra.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 chalk : source_color = vec4(0.953, 0.937, 0.886, 1.0);
uniform float alpha = 0.34;
// Quanto a borda (onde a superfície fica de lado pra câmera) reforça o traço.
uniform float rim = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float grain = hash(floor(FRAGCOORD.xy / 2.0));
	float stroke = smoothstep(0.32, 0.5, abs(fract((FRAGCOORD.x + FRAGCOORD.y) / 9.0) - 0.5));
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = chalk.rgb;
	ALPHA = clamp(alpha * (0.55 + 0.45 * grain) * (0.75 + 0.25 * stroke) + edge * edge * rim * (0.6 + 0.4 * grain), 0.0, 1.0);
}
