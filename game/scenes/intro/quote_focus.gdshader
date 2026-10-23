shader_type canvas_item;
render_mode unshaded;
uniform float focus_px = 0.0;
uniform float dissolve = 0.0;
uniform float grain_px = 3.0;
varying vec4 tint;
varying vec2 glyph_at;
void vertex() { tint = COLOR; glyph_at = VERTEX; }
void fragment() {
	vec2 d = TEXTURE_PIXEL_SIZE * focus_px;
	vec4 glyph = texture(TEXTURE, UV) * 0.5;
	glyph += texture(TEXTURE, UV + vec2(d.x, 0.0)) * 0.125;
	glyph += texture(TEXTURE, UV - vec2(d.x, 0.0)) * 0.125;
	glyph += texture(TEXTURE, UV + vec2(0.0, d.y)) * 0.125;
	glyph += texture(TEXTURE, UV - vec2(0.0, d.y)) * 0.125;
	vec2 cell = floor(glyph_at / grain_px);
	float noise = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float keep = 1.0 - smoothstep(noise, noise + 0.18, dissolve);
	COLOR = glyph * tint;
	COLOR.a *= keep;
}
