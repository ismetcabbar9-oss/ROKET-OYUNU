shader_type spatial;
// Kurak arazi: eğime ve büyük ölçekli gürültüye göre kum / taşlı toprak / kaya karışımı.
// Mobil için: 3 katman x (renk + normal + pürüz), kaya yan yüzeyler için iki düzlemli izdüşüm.
render_mode cull_back;

group_uniforms Kum;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float sand_tiling = 0.11;

group_uniforms Toprak;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ground_tiling = 0.07;

group_uniforms Kaya;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float rock_tiling = 0.025;

group_uniforms Karisim;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float macro_tiling = 0.0015;
// Eğim (1 - normal.y) kaya eşikleri
uniform float rock_slope_start = 0.16;
uniform float rock_slope_end = 0.30;
uniform float ground_amount = 0.5;
uniform vec3 tint_dark : source_color = vec3(0.86, 0.80, 0.72);
uniform vec3 tint_light : source_color = vec3(1.08, 1.03, 0.97);
uniform float normal_strength = 1.0;

// Döşeme tekrarını kırmak için ikinci, döndürülmüş ve farklı ölçekli örnek
vec3 sample_varied(sampler2D tex, vec2 uv, float blend) {
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.37 + vec2(0.13, 0.57);
	return mix(texture(tex, uv).rgb, texture(tex, uv2).rgb, blend);
}

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 top_uv = world_pos.xz;
	float macro = texture(macro_noise, top_uv * macro_tiling).r;
	float macro_fine = texture(macro_noise, top_uv * macro_tiling * 7.3 + vec2(0.37, 0.71)).r;
	float slope = 1.0 - world_normal.y;

	// Ağırlıklar
	float rock_w = smoothstep(rock_slope_start, rock_slope_end, slope + (macro_fine - 0.5) * 0.1);
	float ground_w = smoothstep(0.5 - ground_amount * 0.5, 0.75 - ground_amount * 0.3, macro + slope * 1.4) * (1.0 - rock_w);
	float sand_w = max(1.0 - rock_w - ground_w, 0.0);

	vec3 albedo = vec3(0.0);
	vec3 nmap = vec3(0.0);
	float rough = 0.0;
	float ao = 0.0;

	if (sand_w > 0.001) {
		vec2 uv = top_uv * sand_tiling;
		albedo += sample_varied(sand_albedo, uv, macro_fine) * sand_w;
		nmap += texture(sand_normal, uv).rgb * sand_w;
		vec3 arm = texture(sand_arm, uv).rgb;
		ao += arm.r * sand_w;
		rough += arm.g * sand_w;
	}
	if (ground_w > 0.001) {
		vec2 uv = top_uv * ground_tiling;
		albedo += sample_varied(ground_albedo, uv, macro_fine) * ground_w;
		nmap += texture(ground_normal, uv).rgb * ground_w;
		vec3 arm = texture(ground_arm, uv).rgb;
		ao += arm.r * ground_w;
		rough += arm.g * ground_w;
	}
	if (rock_w > 0.001) {
		// Yan yüzeyler için X ve Z izdüşümleri yumuşak geçişle karıştırılır (dikiş/mip çizgisi oluşmaz);
		// ikisi birden yalnızca dar geçiş bölgesinde örneklenir.
		vec2 uv_x = vec2(world_pos.z, -world_pos.y) * rock_tiling;
		vec2 uv_z = vec2(world_pos.x, -world_pos.y) * rock_tiling;
		float wx = smoothstep(-0.15, 0.15, abs(world_normal.x) - abs(world_normal.z));
		vec2 rtop_uv = top_uv * rock_tiling;
		float side_w = smoothstep(0.35, 0.75, slope);
		vec3 s_alb;
		vec3 s_nrm;
		vec3 s_arm;
		if (wx > 0.999) {
			s_alb = texture(rock_albedo, uv_x).rgb;
			s_nrm = texture(rock_normal, uv_x).rgb;
			s_arm = texture(rock_arm, uv_x).rgb;
		} else if (wx < 0.001) {
			s_alb = texture(rock_albedo, uv_z).rgb;
			s_nrm = texture(rock_normal, uv_z).rgb;
			s_arm = texture(rock_arm, uv_z).rgb;
		} else {
			s_alb = mix(texture(rock_albedo, uv_z).rgb, texture(rock_albedo, uv_x).rgb, wx);
			s_nrm = mix(texture(rock_normal, uv_z).rgb, texture(rock_normal, uv_x).rgb, wx);
			s_arm = mix(texture(rock_arm, uv_z).rgb, texture(rock_arm, uv_x).rgb, wx);
		}
		vec3 r_alb = mix(texture(rock_albedo, rtop_uv).rgb, s_alb, side_w);
		vec3 r_nrm = mix(texture(rock_normal, rtop_uv).rgb, s_nrm, side_w);
		vec3 r_arm = mix(texture(rock_arm, rtop_uv).rgb, s_arm, side_w);
		albedo += r_alb * rock_w;
		nmap += r_nrm * rock_w;
		ao += r_arm.r * rock_w;
		rough += r_arm.g * rock_w;
	}

	// Büyük ölçekli ton farkı: döşeme tekrarını kırar
	albedo *= mix(tint_dark, tint_light, macro);

	ALBEDO = albedo;
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = clamp(rough, 0.35, 1.0);
	AO = mix(1.0, ao, 0.6);
	AO_LIGHT_AFFECT = 0.15;
	SPECULAR = 0.3;
}
