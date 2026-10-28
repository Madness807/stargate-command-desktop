shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Rouge : terrain exploré ; vert : terrain actuellement visible.
uniform sampler2D intel_tex : filter_linear, repeat_disable;
uniform bool show_grid = false;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + 1.0), f.x), f.y);
}
float trail(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - (a + ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0)));
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	vec3 grass = texture(grass_tex, p * 0.055).rgb * vec3(0.72, 0.85, 0.68);
	vec3 dirt = texture(dirt_tex, p * 0.07).rgb * vec3(0.9, 0.86, 0.75);
	float route = min(trail(p, vec2(8, 38), vec2(32, 24)), trail(p, vec2(32, 24), vec2(54, 10)));
	route = min(route, trail(p, vec2(32, 24), vec2(46, 36)));
	float track = 1.0 - smoothstep(0.8, 2.7, route + noise(p * 0.6) * 0.8);
	float outside = max(abs(p.x - 31.0) - 32.0, abs(p.y - 23.0) - 24.0);
	track *= 1.0 - smoothstep(0.0, 8.0, outside);
	float patches = smoothstep(0.55, 0.8, noise(p * 0.12));
	vec3 color = mix(grass, dirt, max(track * 0.85, patches * 0.5));
	color *= 0.8 + noise(p * 0.045) * 0.35;
	vec2 intel = texture(intel_tex, (p + vec2(1.0)) / vec2(64.0, 48.0)).rg;
	float explored = smoothstep(0.1, 0.9, intel.r);
	float visible = smoothstep(0.1, 0.9, intel.g);
	float grey = dot(color, vec3(0.3, 0.59, 0.11));
	color = mix(vec3(grey) * vec3(0.28, 0.34, 0.4), color, visible);
	if (show_grid && outside <= 0.0) {
		vec2 f = fract((p + vec2(1.0)) / 2.0);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		color = mix(color, vec3(0.5, 0.75, 0.8), (1.0 - smoothstep(0.0, 0.025, edge)) * visible * 0.55);
	}
	vec3 tactical = mix(vec3(0.002, 0.004, 0.008), color, explored);
	// Continuer le décor au-delà de la grille, sans révéler les cellules inconnues.
	vec3 landscape = mix(grass, dirt, patches * 0.5) * vec3(0.55, 0.62, 0.66);
	ALBEDO = mix(tactical, landscape, smoothstep(0.0, 18.0, outside));
	ROUGHNESS = 0.95;
}
