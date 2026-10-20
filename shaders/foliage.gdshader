shader_type spatial;
// Kuru çalı / bitki kartları: alfa kesmeli (discard), çift yüzlü, ışık için sabit yukarı normal.
// Rüzgârda hafif salınım (tepe noktaları); maliyeti tek bir sin.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff = 0.3;
uniform float sway_strength = 0.04;
uniform float sway_speed = 1.3;

void vertex() {
	// UV.y = 0 tepe, 1 taban: yalnızca üst kısım salınır
	float top = 1.0 - UV.y;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * sway_speed + world.x * 0.3 + world.z * 0.2) * sway_strength * top;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = tex.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
	// Arka yüzde de normal yukarı kalsın (çift yüzlü kartlarda kararmayı önler)
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}
