shader_type spatial;
render_mode cull_disabled;
uniform sampler2D glyph_atlas : source_color, filter_linear_mipmap;
void fragment() {
	vec3 tex = texture(glyph_atlas, UV).rgb;
	float engraving = smoothstep(0.29, 0.58, max(tex.r, max(tex.g, tex.b)));
	float edge = texture(glyph_atlas, UV + vec2(0.0007, -0.0007)).r;
	ALBEDO = mix(vec3(0.31, 0.335, 0.35), vec3(0.035, 0.045, 0.05), engraving);
	ALBEDO += vec3(0.13) * max(0.0, edge - tex.r);
	METALLIC = 0.42;
	ROUGHNESS = 0.61;
}
