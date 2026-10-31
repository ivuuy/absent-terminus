shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float presence : hint_range(0.0, 1.0) = 0.0;

float ellipse(vec2 p, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.80, 1.10, length((p - center) / radius));
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float head = ellipse(p, vec2(-0.015, 0.79), vec2(0.14, 0.14));
	float shoulders = ellipse(p, vec2(0.0, 0.56), vec2(0.34, 0.16));
	float coat_width = mix(0.34, 0.22, clamp(p.y / 0.65, 0.0, 1.0));
	float coat = (1.0 - smoothstep(coat_width - 0.035, coat_width + 0.035, abs(p.x)))
		* smoothstep(0.02, 0.14, p.y) * (1.0 - smoothstep(0.57, 0.67, p.y));
	float neck = ellipse(p, vec2(0.0, 0.66), vec2(0.07, 0.12));
	float shape = max(max(head, neck), max(shoulders, coat));
	ALBEDO = vec3(0.018, 0.029, 0.035);
	ALPHA = shape * presence * 0.74;
}
