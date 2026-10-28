shader_type spatial;
render_mode cull_disabled;
// Le modèle source utilise un deuxième jeu d'UV pour la normale du couvercle.
uniform sampler2D color_map : source_color, filter_linear_mipmap;
uniform sampler2D data_map : filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
void fragment() {
	ALBEDO = texture(color_map, UV).rgb;
	vec3 data = texture(data_map, UV).rgb;
	ROUGHNESS = data.g;
	METALLIC = data.b;
	NORMAL_MAP = texture(normal_map, UV2).rgb;
	NORMAL_MAP_DEPTH = 0.5;
}
