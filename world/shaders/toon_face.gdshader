// toon_face.gdshader: the toon head material with a swappable 2D face painted on the front.
// The face texture (a SubViewport drawn by world/characters/face_rig.gd) is projected
// planar along object +Z onto the front half of the head mesh.
shader_type spatial;
render_mode ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 0.8, 0.62, 1.0);
uniform vec4 shade : source_color = vec4(0.88, 0.6, 0.42, 1.0);
uniform float rim_amount = 0.22;
uniform sampler2D face_tex : source_color, filter_linear;
uniform float face_size = 0.72;           // object-space width/height covered by the texture
uniform vec2 face_offset = vec2(0.0, 0.0); // object-space centre of the texture
uniform float face_front = 0.05;           // only paint where object z is above this

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec2 uv = vec2((obj_pos.x - face_offset.x) / face_size + 0.5, 0.5 - (obj_pos.y - face_offset.y) / face_size);
	vec4 f = texture(face_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float front = smoothstep(face_front, face_front + 0.06, obj_pos.z);
	ALBEDO = mix(albedo.rgb, f.rgb, f.a * inside * front);
}

void light() {
	float band = smoothstep(0.0, 0.06, dot(NORMAL, LIGHT)) * ATTENUATION;
	vec3 shade_mult = shade.rgb / max(albedo.rgb, vec3(0.04));
	vec3 k = mix(shade_mult, vec3(1.0), band);
	float rim = smoothstep(0.62, 0.68, 1.0 - dot(NORMAL, VIEW)) * rim_amount * band;
	DIFFUSE_LIGHT += (k + rim) * LIGHT_COLOR / PI;
}
