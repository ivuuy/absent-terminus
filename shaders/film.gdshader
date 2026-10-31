shader_type canvas_item;
uniform float menu_shade = 1.0;
void fragment() {
    float vignette = smoothstep(0.20, 0.8, distance(UV, vec2(0.5)));
    float left = 1.0 - smoothstep(0.0, 0.76, UV.x);
    float alpha = vignette * 0.28 + left * menu_shade * 0.84;
    COLOR = vec4(0.015, 0.023, 0.027, alpha);
}
