shader_type canvas_item;
// Brilho que atravessa as peças do LAVOICE depois do encaixe final (intro, DESIGN 19). shine_x anda pela tela, em
// coordenadas do canvas; a faixa é inclinada e some nas bordas.

uniform float shine_x = -10000.0;
uniform float width = 70.0;
uniform float slant = 0.45;
uniform float strength = 0.0;
// Clarão quando a peça encaixa (0..1): a peça fica branca e volta.
uniform float flash = 0.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float d = abs(world.x - shine_x + world.y * slant);
	float s = smoothstep(width, 0.0, d) * strength;
	c.rgb = mix(c.rgb, vec3(1.0), clamp(s + flash, 0.0, 1.0));
	COLOR = c;
}
