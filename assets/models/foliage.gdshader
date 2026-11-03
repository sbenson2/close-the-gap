shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float wind_strength = 0.018;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.23 + world.z * 0.19;
	float anchored = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 1.25 + phase) * anchored * wind_strength;
	VERTEX.z += cos(TIME * 0.92 + phase) * anchored * wind_strength * 0.6;
}

void fragment() {
	vec4 texel = texture(albedo_texture, UV) * tint * COLOR;
	ALBEDO = texel.rgb;
	ROUGHNESS = 0.95;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
