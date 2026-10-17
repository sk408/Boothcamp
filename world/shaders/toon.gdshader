// toon.gdshader: 2-band cel shading + rim light (Compatibility renderer OK). Based on the spike.
// The colour lives in ALBEDO (Godot multiplies DIFFUSE_LIGHT by ALBEDO), so the light() pass
// only computes the band factor. Optional cheap procedural patterns:
//   pattern 0 none, 1 dots (perforated booth panels), 2 stripes along x (planks/cardigan
//   ribs), 3 checker on the floor plane (xz), 4 horizontal stripes (y).
shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 0.5, 0.35, 1.0);
uniform vec4 shade : source_color = vec4(0.75, 0.32, 0.3, 1.0);
uniform float rim_amount = 0.22;
uniform float light_scale = 1.0;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 8.0;
uniform vec4 pattern_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float pattern_mix = 0.0;

varying vec3 obj_pos;
varying vec3 world_pos;

void vertex() {
	obj_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (pattern == 1) {
		vec2 p = fract(vec2(world_pos.x + world_pos.z, world_pos.y) * pattern_scale) - 0.5;
		float d = 1.0 - smoothstep(0.16, 0.22, length(p));
		col = mix(col, pattern_color.rgb, d * pattern_mix);
	} else if (pattern == 2) {
		float s = step(0.5, fract(obj_pos.x * pattern_scale));
		col = mix(col, pattern_color.rgb, s * pattern_mix);
	} else if (pattern == 3) {
		vec2 c = floor(world_pos.xz * pattern_scale);
		float s = mod(c.x + c.y, 2.0);
		col = mix(col, pattern_color.rgb, s * pattern_mix);
	} else if (pattern == 4) {
		float s = step(0.5, fract(obj_pos.y * pattern_scale));
		col = mix(col, pattern_color.rgb, s * pattern_mix);
	}
	ALBEDO = col;
	EMISSION = emission.rgb;
}

void light() {
	float band = smoothstep(0.0, 0.06, dot(NORMAL, LIGHT)) * ATTENUATION;
	vec3 shade_mult = shade.rgb / max(albedo.rgb, vec3(0.04));
	vec3 k = mix(shade_mult, vec3(1.0), band);
	float rim = smoothstep(0.62, 0.68, 1.0 - dot(NORMAL, VIEW)) * rim_amount * band;
	DIFFUSE_LIGHT += (k + rim) * LIGHT_COLOR * light_scale / PI;
}
