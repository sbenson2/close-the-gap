shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 tint : source_color = vec4(0.34, 0.46, 0.23, 1.0);
uniform float wind_strength = 0.065;
uniform float plant_height = 1.0;
uniform float gust_multiplier = 1.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.37, 0.23));
	float bend = clamp(VERTEX.y / plant_height, 0.0, 1.0);
	float gust = sin(TIME * 1.05 + phase) + 0.35 * sin(TIME * 2.4 + phase * 1.7);
	VERTEX.xz += vec2(1.0, 0.45) * gust * wind_strength * gust_multiplier * bend * bend;
}

void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb;
	ROUGHNESS = 0.94;
	BACKLIGHT = ALBEDO * 0.18;
}
