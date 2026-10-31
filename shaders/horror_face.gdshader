shader_type canvas_item;

uniform float age = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

float oval(vec2 p, vec2 center, vec2 radius) {
	return length((p - center) / radius);
}

void fragment() {
	float zoom = mix(0.58, 1.18, smoothstep(0.0, 0.16, age));
	vec2 p = (UV - vec2(0.5, 0.49)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) / zoom;
	p += vec2(sin(age * 81.0), cos(age * 63.0)) * 0.0025 * exp(-age * 4.0);
	p.x += p.y * 0.045;
	float rough = noise(p * 95.0) * 0.6 + noise(p * 230.0) * 0.4;
	float skin_width = mix(0.285, 0.205, smoothstep(0.02, 0.40, p.y));
	float head = oval(p, vec2(0.0, -0.01), vec2(skin_width, 0.435));
	float mask = 1.0 - smoothstep(0.97, 1.015, head);
	float depth = sqrt(max(0.0, 1.0 - min(head * head, 1.0)));
	float side_light = clamp(0.58 - p.x * 1.5 + depth * 0.36, 0.08, 1.0);
	vec3 skin = vec3(0.48, 0.53, 0.49) * side_light * (0.72 + rough * 0.36);
	// Hollow sockets, crooked lid contours and tiny, unfocused pupils.
	vec2 eye_p = vec2(p.x, p.y + abs(p.x) * 0.20);
	float eye_l = oval(eye_p, vec2(-0.115, -0.095), vec2(0.073, 0.047));
	float eye_r = oval(eye_p, vec2(0.111, -0.09), vec2(0.069, 0.052));
	float eyes = min(eye_l, eye_r);
	skin *= mix(0.28, 1.0, smoothstep(0.85, 1.85, eyes));
	skin = mix(skin, vec3(0.004, 0.006, 0.006), 1.0 - smoothstep(0.80, 1.08, eyes));
	float pupil = exp(-pow(oval(p, vec2(-0.107, -0.123), vec2(0.006, 0.008)), 2.0) * 2.0);
	pupil += exp(-pow(oval(p, vec2(0.105, -0.113), vec2(0.004, 0.006)), 2.0) * 2.0);
	skin += vec3(0.68, 0.73, 0.64) * pupil;
	float brow = exp(-pow((p.y + 0.178 - abs(p.x) * 0.28) / 0.019, 2.0));
	skin += vec3(0.10) * brow * smoothstep(0.035, 0.09, abs(p.x)) * (1.0 - smoothstep(0.18, 0.23, abs(p.x)));
	// Nose bridge and sunken cheeks give the face volume without a white flash.
	skin += vec3(0.12, 0.13, 0.11) * exp(-pow(p.x / 0.022, 2.0)) * (1.0 - smoothstep(0.05, 0.14, abs(p.y)));
	float nose = oval(p, vec2(0.0, 0.065), vec2(0.032, 0.043));
	skin *= mix(0.22, 1.0, smoothstep(0.7, 1.4, nose));
	float cheeks = exp(-pow((abs(p.x) - 0.168) / 0.042, 2.0)) * exp(-pow((p.y - 0.12) / 0.10, 2.0));
	skin *= 1.0 - cheeks * 0.65;
	// An uneven open mouth with worn, irregular teeth.
	vec2 mouth_p = p + vec2(sin(p.y * 32.0) * 0.004, 0.0);
	float mouth = oval(mouth_p, vec2(0.006, 0.225), vec2(0.092, 0.135));
	skin = mix(skin, vec3(0.095, 0.065, 0.062), 1.0 - smoothstep(0.94, 1.18, mouth));
	skin = mix(skin, vec3(0.002, 0.004, 0.004), 1.0 - smoothstep(0.79, 0.94, mouth));
	float tooth_x = fract((p.x + 0.08) * 63.0);
	float teeth = smoothstep(0.10, 0.25, tooth_x) * (1.0 - smoothstep(0.72, 0.93, tooth_x));
	float tooth_length = 0.018 + hash(vec2(floor((p.x + 0.08) * 63.0), 3.0)) * 0.018;
	float upper = smoothstep(0.109, 0.117, p.y) * (1.0 - smoothstep(0.119 + tooth_length, 0.127 + tooth_length, p.y));
	float lower = smoothstep(0.317 - tooth_length, 0.325 - tooth_length, p.y) * (1.0 - smoothstep(0.331, 0.337, p.y));
	skin = mix(skin, vec3(0.43, 0.42, 0.32), teeth * max(upper, lower) * (1.0 - smoothstep(0.73, 0.85, mouth)));
	float streak = (1.0 - smoothstep(0.0, 0.008, abs(abs(p.x) - 0.112 - sin(p.y * 31.0) * 0.01)))
		* smoothstep(-0.06, 0.0, p.y) * (1.0 - smoothstep(0.10, 0.26, p.y));
	skin *= 1.0 - streak * 0.65;
	// The missing conductor's cap is almost lost in the surrounding darkness.
	skin *= mix(1.0, 0.10, 1.0 - smoothstep(-0.31, -0.286, p.y + p.x * 0.06));
	float fade = 1.0 - smoothstep(0.70, 1.03, age);
	float grain = hash(floor(FRAGCOORD.xy) + floor(age * 24.0));
	vec3 background = vec3(0.002, 0.006, 0.008);
	COLOR = vec4(mix(background, skin, mask) + grain * 0.015, (0.78 + mask * 0.22) * fade);
}
