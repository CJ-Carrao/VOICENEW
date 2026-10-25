shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform bool shrine_interior = false;
uniform float clash_amount = 0.0;
uniform float clash_pressure = 0.0;
uniform vec3 clash_point = vec3(0.0);
uniform vec3 clash_axis = vec3(1.0, 0.0, 0.0);
varying vec3 world_point;

void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 grid = UV * vec2(160.0, 90.0);
	float star = step(0.978, hash(floor(grid))) * pow(max(0.0, 1.0 - length(fract(grid) - 0.5) * 2.0), 9.0);
	float horizon = exp(-abs(UV.y - 0.5) * 24.0);
	float streams = pow(max(0.0, sin(UV.x * 170.0 + UV.y * 16.0 + TIME * 0.6)), 24.0);
	vec3 sky = vec3(0.003, 0.005, 0.018) + vec3(0.08, 0.16, 0.36) * horizon;
	sky += vec3(0.58, 0.75, 1.0) * star * 2.5 + vec3(0.16, 0.29, 0.62) * streams * horizon;
	vec2 hole = (UV - vec2(0.5, 0.5)) * vec2(2.0, 1.0);
	float radius = length(hole);
	sky *= smoothstep(0.068, 0.079, radius);
	sky += vec3(0.5, 0.7, 1.0) * exp(-abs(radius - 0.080) * 420.0) * 1.8;
	float disk = exp(-abs(hole.y) * 290.0) * smoothstep(0.068, 0.09, abs(hole.x)) * (1.0 - smoothstep(0.12, 0.26, abs(hole.x)));
	sky += disk * vec3(0.35, 0.55, 0.85);
	vec3 void_sky = sky;
		float mist = sin(UV.x * 24.0 + TIME * 0.25) * sin(UV.y * 19.0 - TIME * 0.18);
		float cuts = pow(max(0.0, sin(UV.x * 90.0 + UV.y * 64.0 + TIME * 1.5)), 48.0);
	vec3 shrine_sky = vec3(0.025, 0.002, 0.003) + vec3(0.10, 0.006, 0.004) * (mist * 0.5 + 0.5);
	shrine_sky += vec3(0.35, 0.025, 0.015) * horizon + vec3(0.18, 0.012, 0.008) * cuts * horizon;
	sky = shrine_interior ? shrine_sky : void_sky;
	if (clash_amount > 0.01) {
		float side = dot(world_point - clash_point, normalize(clash_axis)) - clash_pressure * 2.0;
		float seam = exp(-abs(side + sin(UV.y * 45.0 + TIME * 9.0) * 0.13) * 12.0);
		float own = 1.0 - smoothstep(-0.25, 0.25, side);
		sky = mix(shrine_interior ? void_sky : shrine_sky, sky, own);
		sky += vec3(0.62, 0.45, 0.85) * seam * (0.6 + sin(TIME * 18.0) * 0.2);
	}
	ALBEDO = FRONT_FACING ? vec3(0.0005) : sky;
	EMISSION = FRONT_FACING ? vec3(0.0) : sky * 0.8;
	ROUGHNESS = 1.0;
}
