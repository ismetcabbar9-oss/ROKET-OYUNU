shader_type spatial;
// Roket motoru alevi: koni üzerinde eklemeli (additive), titreşen, uca doğru sönen ışıma.
// Koninin geniş ucu (UV.y = 0) lüle tarafındadır.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 core_color : source_color = vec3(1.0, 0.93, 0.75);
uniform vec3 outer_color : source_color = vec3(1.0, 0.42, 0.08);
uniform float intensity = 4.0;
// 0 = motor kapalı, 1 = tam itki
uniform float throttle : hint_range(0.0, 1.0) = 1.0;
uniform float flicker_speed = 45.0;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	// Kenara bakan yüzeyler sönük, kameraya bakan merkez parlak
	float facing = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float flicker = 0.82 + 0.18 * sin(TIME * flicker_speed + along * 18.0) * sin(TIME * flicker_speed * 0.37 + 2.1);
	float fade = pow(1.0 - along, 1.7);
	float core = smoothstep(0.55, 1.0, facing) * pow(1.0 - along, 3.0);
	vec3 col = mix(outer_color, core_color, core);
	float a = facing * fade * throttle * flicker;
	ALBEDO = col * intensity * a;
	ALPHA = a;
}
