shader_type spatial;
render_mode cull_disabled;

uniform sampler2D forest_floor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 terrain_normal;
varying vec3 terrain_position;

void vertex() {
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(terrain_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 stone = texture(rock, terrain_position.zy * 0.24).rgb * weights.x;
	stone += texture(rock, terrain_position.xz * 0.24).rgb * weights.y;
	stone += texture(rock, terrain_position.xy * 0.24).rgb * weights.z;
	vec3 soil = texture(forest_floor, UV).rgb * vec3(0.50, 0.55, 0.48);
	ALBEDO = mix(stone * vec3(0.62, 0.66, 0.65), soil, smoothstep(0.66, 0.90, abs(n.y)));
	ROUGHNESS = 0.96;
}
