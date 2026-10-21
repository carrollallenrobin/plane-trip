// Sways a Backdrop tree in the wind: the top bends to and fro, the foot stays put. One
// material per tree colour over every tree in a MultiMesh, so the cost is nothing. Each
// tree's phase comes from where it stands, so a line of them does not move as one. The time
// is a parameter BackdropNode advances, not TIME, so the trees stop when the game pauses.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float sway_time = 0.0;
// Metres the top moves either way, and radians per second.
uniform float amplitude = 0.25;
uniform float speed = 1.3;
// The height the bend is measured against: the tallest tree as built.
uniform float tree_height = 12.0;

void vertex() {
	float up = clamp(VERTEX.y / tree_height, 0.0, 1.0);
	float phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.11;
	VERTEX.x += amplitude * up * up * sin(sway_time * speed + phase);
}

void fragment() {
	ALBEDO = albedo.rgb;
}
