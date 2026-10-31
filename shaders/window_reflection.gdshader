shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.025, 0.055, 0.065, 0.46);

float ellipse(vec2 point, vec2 center, vec2 radius) {
	return 1.0 - smoothstep(0.88, 1.04, length((point - center) / radius));
}

float band(float value, float low, float high) {
	return smoothstep(low - 0.012, low + 0.012, value)
		* (1.0 - smoothstep(high - 0.012, high + 0.012, value));
}

void fragment() {
	vec2 point = vec2(UV.x - 0.5, 1.0 - UV.y);
	float coat_width = mix(0.28, 0.20, clamp(point.y / 0.65, 0.0, 1.0));
	float coat = (1.0 - smoothstep(coat_width - 0.012, coat_width + 0.012, abs(point.x)))
		* band(point.y, 0.04, 0.63);
	float shoulders = ellipse(point, vec2(0.0, 0.60), vec2(0.25, 0.085));
	float neck = band(point.x, -0.075, 0.075) * band(point.y, 0.63, 0.76);
	float head = ellipse(point, vec2(0.0, 0.78), vec2(0.15, 0.13));
	float cap = band(point.x, -0.17, 0.17) * band(point.y, 0.87, 0.96);
	float brim = band(point.x, -0.24, 0.24) * band(point.y, 0.86, 0.89);
	float silhouette = max(max(max(coat, shoulders), neck), max(head, max(cap, brim)));
	ALBEDO = tint.rgb;
	ALPHA = silhouette * tint.a;
}
