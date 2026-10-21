// A Tracer: the drawn bullet. The mesh is a unit box scaled along X to the streak's whole
// length, its leading end at the round's position. The first head_length metres are the
// bright head; the rest is the tail, fading to nothing and tapering toward where the round
// was TRACER_TAIL_SECONDS ago. COLOR is the instance colour: planes' rounds and ground guns'
// rounds differ. Unshaded, like everything in the flat-colour world.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float head_length = 2.5;
// The tail's width at its end, as a fraction of the head's.
uniform float tail_width = 0.3;

varying float fade;

void vertex() {
	float total = length(MODEL_MATRIX[0].xyz);
	float behind = (0.5 - VERTEX.x) * total;
	float t = clamp((behind - head_length) / max(total - head_length, 0.001), 0.0, 1.0);
	fade = 1.0 - t;
	VERTEX.yz *= mix(1.0, tail_width, t);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * fade * fade;
}
