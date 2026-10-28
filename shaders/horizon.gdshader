shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Horizon des événements. kaw : progression du kawoosh (0 à 1), open : flaque stable (0 à 1),
// ripple : remous quand quelque chose la traverse.
uniform float kaw = 0.0;
uniform float open = 0.0;
uniform float ripple = 0.0;
uniform float burst = 1.0;      // 0 : iris fermé, la gerbe ne jaillit pas

uniform sampler2D water_noise : repeat_enable, filter_linear_mipmap;
varying float v_r;

void vertex() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	v_r = r;
	float k = sin(clamp(kaw, 0.0, 1.0) * PI);
	// La gerbe jaillit en bulbe, s'étire vers l'avant puis se rétracte
	float prof = pow(max(0.0, 1.0 - r * r), 0.55);
	float ang = atan(p.y, p.x);
	float turb = sin(ang * 7.0 + TIME * 9.0) * 0.09 + sin(r * 18.0 - TIME * 14.0) * 0.06;
	VERTEX.z += burst * k * (4.2 * prof + turb * prof * 3.0);
	VERTEX.xy *= 1.0 + burst * k * 0.12 * prof;
	// La flaque : vagues concentriques et houle
	float edge = 1.0 - smoothstep(0.85, 1.0, r);
	VERTEX.z += open * edge * (sin(r * 14.0 - TIME * 2.6) * 0.035 + sin(p.x * 9.0 + TIME * 1.7) * 0.02);
	VERTEX.z += ripple * edge * sin(r * 20.0 - TIME * 10.0) * 0.12;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	// Des rides advectées : reflets étirés sur une surface liquide, sans îlots blancs.
	vec2 drift = vec2(TIME * 0.022, -TIME * 0.016);
	float wx = texture(water_noise, UV * 1.2 - drift * 0.55).r;
	float wy = texture(water_noise, UV * 1.2 - drift * 0.55 + vec2(0.37, 0.61)).r;
	vec2 flow = vec2(wx, wy) - 0.5;
	vec2 water_uv = UV * 1.8 + drift + flow * 0.35;
	float broad = texture(water_noise, water_uv).r;
	float fine = texture(water_noise, UV * vec2(3.2, 2.3) - drift * 1.2 + flow * 0.45).r;
	float body = clamp(broad * 0.65 + fine * 0.35, 0.0, 1.0);
	float fold = pow(max(0.0, 1.0 - abs(fine - 0.48) * 3.0), 8.0);
	vec3 col = mix(vec3(0.018, 0.075, 0.17), vec3(0.22, 0.43, 0.65), body);
	col += vec3(0.13, 0.22, 0.29) * fold * (0.35 + broad * 0.65);
	float rim = smoothstep(0.87, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	col += vec3(0.06, 0.18, 0.32) * rim;

	float k = sin(clamp(kaw, 0.0, 1.0) * PI);
	col = mix(col, vec3(0.85, 0.95, 1.0), k * 0.55);
	ALBEDO = col * 0.08;
	EMISSION = col * (0.95 + k * 2.2);
	ROUGHNESS = 0.4;
	METALLIC = 0.0;
	SPECULAR = 0.08;
	ALPHA = clamp(max(open, k * 1.5), 0.0, 1.0) * (1.0 - smoothstep(0.97, 1.0, r));
}
