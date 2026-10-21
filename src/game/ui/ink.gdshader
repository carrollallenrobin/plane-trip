// Rubber-stamp ink: eats into whatever is drawn under it with coarse noise, so a Stamp's
// rule and letters look pressed by hand rather than printed (ADR 0008). Used as the material
// of a Stamp, which draws itself in one colour. Headless Godot compiles no shaders.
shader_type canvas_item;

uniform float wear : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 px = floor(FRAGCOORD.xy / 2.0);
	float n = hash(px) * 0.6 + hash(floor(px / 3.0)) * 0.4;
	float keep = smoothstep(wear - 0.25, wear + 0.15, n);
	c.a *= keep;
	COLOR = c;
}
