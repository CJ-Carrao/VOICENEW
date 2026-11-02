shader_type spatial;
// A película do portal (DESIGN 31): sem borda, nas próprias faces dos blocos debaixo da abertura.
// Sem par (pendente), ela é feita de blocos cinza na grade do portal (`cell_m`, centrada no tiro), com juntas que
// brilham de leve na cor do portal; a onda do tiro passa como um lampejo de dentro pra fora (os cubos que pulam
// são PortalBlocks). Com par, do meio pra fora (`reveal_m`), cada bloco vira a vista do outro lado: a câmera de lá
// usa a projeção de janela (Portal.update_view) e a textura cobre um retângulo do plano do portal (`crop`). Cada
// pixel segue o raio do olho até esse plano e pega a cor de lá: a imagem sai exata mesmo com a película dobrada.
// A película fica nas faces e ganha delas só na profundidade (`depth_bias`).
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

// A vista já vem em luz linear (HDR, sem tom: Portal._sync_environment); a neblina também já está nela.
uniform sampler2D view : filter_linear, repeat_disable, hint_default_black;
uniform bool linked = false;
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.1, 1.0);
// Retângulo do plano que a vista cobre, em UV da abertura (início xy, tamanho zw; U pra direita, V pra baixo).
uniform vec4 crop = vec4(0.0, 0.0, 1.0, 1.0);
// Fração da profundidade que a superfície ganha da parede atrás (profundidade invertida: maior = mais perto).
uniform float depth_bias = 0.0002;
// Tamanho da abertura (m), pra levar o ponto do plano pra UV.
uniform vec2 size = vec2(1.1, 2.2);
// Os blocos: aresta (m), segundos desde que abriu, velocidade da onda (m/s) e até onde o outro lado já apareceu
// (m a partir do meio; negativo = nada).
uniform float cell_m = 0.25;
uniform float time_open = 100.0;
uniform float wave_ms = 4.0;
uniform float reveal_m = -1.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z *= 1.0 + depth_bias;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Referencial do portal: o plano é z = 0, o olho fica na frente (z > 0).
	mat4 to_local = inverse(MODEL_MATRIX) * INV_VIEW_MATRIX;
	vec3 frag = (to_local * vec4(VERTEX, 1.0)).xyz;
	vec2 cell = floor(frag.xy / cell_m);
	float dist = length((cell + 0.5) * cell_m);
	if (linked && dist < reveal_m) {
		vec3 eye = (to_local * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 hit = frag.z < -0.0005 ? mix(eye, frag, eye.z / (eye.z - frag.z)) : frag;
		vec2 at = vec2(hit.x / size.x + 0.5, 0.5 - hit.y / size.y);
		ALBEDO = texture(view, (at - crop.xy) / crop.zw).rgb;
	} else {
		// Bloco cinza: variação por bloco, luz falsa pela face (o mundo de blocos é iluminado; a película não).
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float light = 0.78 + 0.22 * dot(world_normal, normalize(vec3(0.35, 1.0, 0.25)));
		// Sem luz da cena, o cinza aparece como é: escuro o bastante pra parecer o bloco do mundo (que leva sombra).
		vec3 grey = vec3(0.17 + hash(cell) * 0.05) * light;
		vec2 inside = fract(frag.xy / cell_m);
		float edge = min(min(inside.x, 1.0 - inside.x), min(inside.y, 1.0 - inside.y));
		float seam = 1.0 - smoothstep(0.035, 0.09, edge);
		// As juntas respiram na cor do portal, em ondas do meio pra fora (dá pra saber qual é qual).
		float pulse = 0.5 + 0.5 * sin(TIME * 2.4 - dist * 5.0);
		vec3 seam_color = mix(grey * 0.4, tint.rgb * 0.85, 0.25 + 0.4 * pulse);
		vec3 color = mix(grey, seam_color, seam);
		// A onda do tiro passando: um lampejo na cor do portal em cada bloco.
		float phase = time_open - dist / wave_ms;
		color += tint.rgb * (phase > 0.0 ? exp(-phase * 7.0) : 0.0) * 0.7;
		// A frente da revelação: os blocos prestes a virar acendem.
		if (linked && reveal_m >= 0.0) {
			color = mix(color, tint.rgb * 1.6, (1.0 - smoothstep(0.0, cell_m * 1.6, dist - reveal_m)) * 0.7);
		}
		ALBEDO = color;
	}
}
