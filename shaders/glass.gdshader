shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(0.22, 0.38, 0.46, 0.12);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
    vec2 uv = UV;
    float edge = pow(abs(uv.x - 0.5) * 2.0, 10.0) + pow(abs(uv.y - 0.5) * 2.0, 12.0);
    float frost = clamp(edge, 0.0, 1.0) * (0.62 + noise(uv * 90.0) * 0.24 + noise(uv * 250.0) * 0.14);
    ALBEDO = mix(tint.rgb, vec3(0.65, 0.76, 0.81), frost);
    ALPHA = tint.a + frost * 0.48;
    ROUGHNESS = 0.14 + frost * 0.6;
    METALLIC = 0.15;
    SPECULAR = 0.8;
}
