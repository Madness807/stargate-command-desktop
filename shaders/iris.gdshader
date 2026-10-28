shader_type spatial;
render_mode cull_disabled;
uniform float turn = 0.0;
uniform float shade = 0.45;
varying vec2 iris_position;
void vertex() {
	float c = cos(turn);
	float s = sin(turn);
	iris_position = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy + vec2(0.0, 2.60);
}
void fragment() {
	if (length(iris_position) > 2.51) { discard; }
	float brushed = sin(iris_position.y * 180.0) * 0.003;
	ALBEDO = vec3(shade + brushed) * vec3(0.94, 0.97, 1.0);
	METALLIC = 0.65;
	ROUGHNESS = 0.62;
}
