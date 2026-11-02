shader_type spatial;
// As criações em blocos (ModelVoxels, DESIGN 28 e 8.1): a cor da peça com acabamento (rugosidade, metal, brilho),
// a sombra dos cantos (cor do vértice) e, desenhados aqui, a linha entre os blocos e um tom levemente diferente por
// bloco. A malha junta faces planas em retângulos; a UV diz onde cada ponto cai na grade da face (em blocos) e a UV2
// diz a camada da face (x) e que a malha é de blocos (y = 1). Malha sem UV2 (a montagem que desmorona) fica lisa.
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.75;
uniform float metallic = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Linha entre blocos: largura (fração do bloco), quanto escurece, e o tom que varia de bloco pra bloco.
uniform float seam_width = 0.07;
uniform float seam_darken = 0.22;
uniform float variation = 0.06;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 color = albedo.rgb * COLOR.rgb;
	if (UV2.y > 0.5) {
		vec2 cell = floor(UV);
		float tone = 1.0 + (hash(vec3(cell, UV2.x)) - 0.5) * 2.0 * variation;
		vec2 inside = fract(UV);
		float edge = min(min(inside.x, 1.0 - inside.x), min(inside.y, 1.0 - inside.y));
		// Bloco pequeno na tela: a linha some aos poucos (senão o modelo de longe vira chiado escuro).
		float pixel = max(fwidth(UV.x), fwidth(UV.y));
		float near = clamp((0.35 - pixel) / 0.25, 0.0, 1.0);
		float seam = (1.0 - smoothstep(seam_width - pixel, seam_width + pixel, edge)) * near;
		color *= mix(1.0, tone, near) * (1.0 - seam * seam_darken);
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color.rgb * emission_energy;
}
