shader_type spatial;
// Asfalt yol şeridi: UV.x = enine 0..1, UV.y = boyuna metre / genişlik.
// Kenar çizgileri ve kesikli orta çizgi prosedürel (ek doku yok); kenarlar tozlu.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tiling = 0.9;
uniform vec3 line_color : source_color = vec3(0.85, 0.82, 0.72);
uniform vec3 dust_color : source_color = vec3(0.62, 0.50, 0.38);
uniform float edge_line_offset = 0.06;
uniform float line_width = 0.025;
uniform float dash_length = 0.6;

void fragment() {
	vec2 uv = vec2(UV.x, UV.y) * tiling;
	vec3 albedo = texture(albedo_tex, uv).rgb;
	vec3 arm = texture(arm_tex, uv).rgb;
	float across = UV.x;
	// Çizgiler: iki kenar çizgisi + kesikli orta çizgi (aşınmış görünsün diye hafif soluk)
	float aa = fwidth(across) * 1.5;
	float edge_l = 1.0 - smoothstep(line_width, line_width + aa, abs(across - edge_line_offset));
	float edge_r = 1.0 - smoothstep(line_width, line_width + aa, abs(across - (1.0 - edge_line_offset)));
	float dash = step(0.5, fract(UV.y / dash_length));
	float center = (1.0 - smoothstep(line_width * 0.8, line_width * 0.8 + aa, abs(across - 0.5))) * dash;
	float lines = max(max(edge_l, edge_r), center) * 0.8;
	albedo = mix(albedo, line_color, lines);
	// Genel çöl tozu tonu + kenarlara doğru yoğunlaşan toz
	albedo *= vec3(1.0, 0.94, 0.86);
	float dust = smoothstep(0.18, 0.0, min(across, 1.0 - across));
	albedo = mix(albedo, dust_color, dust * 0.75);
	ALBEDO = albedo;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = mix(arm.g, 0.6, lines);
	AO = arm.r;
}
