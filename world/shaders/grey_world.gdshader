// grey_world.gdshader: full-screen post effect for the teaser fitting (CanvasItem, reads the
// screen). Everything outside `radius` (aspect-corrected screen units, around `center`) is
// greyed; the colour wave edge gets a warm sparkle ring. radius < 0 = all grey.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = -1.0;
uniform float softness = 0.18;
uniform float ring = 1.0;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(l) * vec3(0.96, 0.98, 1.04) * 0.92 + 0.04;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float dist = length(d);
	float colour = 1.0 - smoothstep(radius - softness, radius, dist);
	float edge = smoothstep(radius - softness, radius - softness * 0.5, dist) * (1.0 - smoothstep(radius - softness * 0.5, radius, dist));
	vec3 outc = mix(grey, c.rgb, colour) + vec3(1.0, 0.85, 0.45) * edge * 0.35 * ring;
	COLOR = vec4(outc, 1.0);
}
