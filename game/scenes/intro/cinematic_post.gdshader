shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Bloom LDR localizado na intro: pirâmide de mipmaps, sem HDR nem configuração global.
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float bloom = 0.12;
uniform float threshold = 0.58;
uniform float aberration_px = 0.0;
uniform float vignette = 0.1;
uniform float radius_px = 6.0;
uniform float mip_lod = 3.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 chroma = SCREEN_PIXEL_SIZE * aberration_px * (uv - 0.5);
	vec3 base = textureLod(scene, uv, 0.0).rgb;
	base.r = textureLod(scene, uv + chroma, 0.0).r;
	base.b = textureLod(scene, uv - chroma, 0.0).b;
	vec2 step_uv = SCREEN_PIXEL_SIZE * radius_px;
	vec3 glow = textureLod(scene, uv, mip_lod).rgb * 0.36;
	glow += textureLod(scene, uv + vec2(step_uv.x, 0.0), mip_lod).rgb * 0.16;
	glow += textureLod(scene, uv - vec2(step_uv.x, 0.0), mip_lod).rgb * 0.16;
	glow += textureLod(scene, uv + vec2(0.0, step_uv.y), mip_lod).rgb * 0.16;
	glow += textureLod(scene, uv - vec2(0.0, step_uv.y), mip_lod).rgb * 0.16;
	glow = max(glow - vec3(threshold), vec3(0.0)) / max(1.0 - threshold, 0.01);
	float edge = smoothstep(0.2, 0.72, length(uv - 0.5));
	COLOR = vec4((base + glow * bloom) * (1.0 - edge * vignette), 1.0);
}
