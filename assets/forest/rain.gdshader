shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float weather_clock = 0.0;
void vertex() {
 float fall = mod(weather_clock * 24.0 + INSTANCE_CUSTOM.r * 42.0, 42.0);
 VERTEX.y -= fall;
 VERTEX.x += fall * 0.045;
}
void fragment() {
 ALBEDO = vec3(0.68, 0.76, 0.8);
 ALPHA = 0.24 * (1.0 - abs(UV.x - 0.5) * 2.0);
}
