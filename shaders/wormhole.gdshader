shader_type spatial;
render_mode unshaded, cull_disabled;

// Parois du trou de ver : bandes qui défilent, stries tourbillonnantes, éclairs violets
uniform float speed = 2.4;

void fragment() {
	float a = UV.x * TAU;
	float z = UV.y;
	float swirl = a + z * 18.0 + TIME * 1.6;
	float streak = pow(abs(sin(swirl * 6.0 + sin(z * 60.0 + TIME * 3.0) * 1.2)), 22.0);
	float band = fract(z * 14.0 + TIME * speed);
	band = smoothstep(0.0, 0.45, band) * smoothstep(1.0, 0.55, band);
	float flash = pow(max(0.0, sin(z * 9.0 - TIME * 5.0 + a * 2.0)), 40.0);
	vec3 base = mix(vec3(0.02, 0.06, 0.3), vec3(0.15, 0.35, 0.95), band * 0.7);
	vec3 col = base + vec3(0.65, 0.85, 1.0) * streak * 0.9 + vec3(0.7, 0.4, 1.0) * flash * 0.8;
	ALBEDO = col * 1.5;
}
