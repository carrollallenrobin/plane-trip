// Paper grain over a Sheet: fine noise, faint horizontal fibres and a soft darkening toward
// the edges, drawn as a translucent shade over the cream (ADR 0008). Darkens only, so the ink
// under it stays legible. Headless Godot compiles no shaders; check it in the real game.
shader_type canvas_item;

uniform float grain : hint_range(0.0, 1.0) = 0.10;
uniform float vignette : hint_range(0.0, 1.0) = 0.14;
uniform vec4 tint : source_color = vec4(0.30, 0.24, 0.14, 1.0);

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy / 1.5);
	float speck = hash(px);
	float fibre = hash(vec2(floor(FRAGCOORD.y / 3.0), 7.0));
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.30, 0.78, length(d)) * vignette;
	float a = max(speck - 0.55, 0.0) * grain * 2.0 + fibre * grain * 0.35 + edge;
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 1.0));
}
