// outline.gdshader: inverted hull, used as next_pass of the toon material. From the spike.
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.025;
uniform vec4 color : source_color = vec4(0.18, 0.14, 0.26, 1.0);
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = color.rgb; }
