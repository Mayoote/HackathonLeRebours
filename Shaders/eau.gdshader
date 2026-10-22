// Eau peu profonde : transparente, petites vagues et reflets qui bougent
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 couleur : source_color = vec4(0.18, 0.45, 0.62, 0.55);
uniform vec4 ecume : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float vitesse = 0.6;
uniform float echelle = 0.35;

float vague(vec2 p, float t) {
	return sin(p.x * 1.3 + t) * 0.5 + sin(p.y * 1.7 - t * 1.2) * 0.5 + sin((p.x + p.y) * 0.9 + t * 0.7) * 0.4;
}

void fragment() {
	vec3 monde = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = monde.xz * echelle;
	float t = TIME * vitesse;
	float h = vague(p, t);
	float dx = vague(p + vec2(0.05, 0.0), t) - h;
	float dz = vague(p + vec2(0.0, 0.05), t) - h;
	NORMAL_MAP = normalize(vec3(-dx * 6.0, -dz * 6.0, 1.0)) * 0.5 + 0.5;
	float reflet = smoothstep(0.85, 1.25, h);
	ALBEDO = mix(couleur.rgb, ecume.rgb, reflet * 0.35);
	ALPHA = couleur.a + reflet * 0.15;
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	SPECULAR = 0.7;
}
