shader_type spatial;
// Sol de blocos incandescentes (mapa do espaço, DESIGN 27): a superfície é uma grade de blocos de `block` m,
// cada um com o seu tom (laranja fundo → amarelo → branco-quente) que respira devagar; as juntas escurecem.
uniform float block = 0.5;
uniform float energy = 1.5;
uniform vec3 deep : source_color = vec3(0.95, 0.3, 0.03);
uniform vec3 mid : source_color = vec3(1.0, 0.6, 0.09);
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.42);
varying vec3 lp;
varying vec3 ln;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	// Grade na face (os dois eixos que não são o da normal dominante).
	vec3 a = abs(ln);
	vec2 uv = a.x > a.y && a.x > a.z ? lp.yz : (a.y > a.z ? lp.xz : lp.xy);
	vec2 g = uv / block;
	vec2 cell = floor(g);
	float side = a.x > a.y && a.x > a.z ? sign(ln.x) : (a.y > a.z ? sign(ln.y) * 2.0 : sign(ln.z) * 3.0);
	float h = hash(vec3(cell, side));
	float breath = 0.5 + 0.5 * sin(TIME * (0.6 + h * 1.4) + h * 6.2831);
	float t = clamp(h * 0.75 + breath * 0.35, 0.0, 1.0);
	vec3 col = t < 0.5 ? mix(deep, mid, t * 2.0) : mix(mid, hot, (t - 0.5) * 2.0);
	vec2 f = fract(g);
	float seam = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.08, seam));
	ALBEDO = col;
	EMISSION = col * energy;
	ROUGHNESS = 1.0;
}
