shader_type canvas_item;

uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float breath = 0.0;

void fragment() {
	vec2 point = UV - vec2(0.5);
	float edge = smoothstep(0.24, 0.70, length(point));
	float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))
		+ floor(TIME * 12.0)) * 43758.5453);
	float shade = edge * tension * (0.26 + breath * 0.035);
	COLOR = vec4(vec3(0.015, 0.027, 0.032) + grain * 0.035,
		shade + grain * tension * 0.014);
}
