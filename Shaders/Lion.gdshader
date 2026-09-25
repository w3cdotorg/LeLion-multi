shader_type canvas_item;
// Teinte de la crinière du lion à la couleur de son joueur (spec §5).
// Le masque se déduit du sprite lui-même, pixel par pixel : la crinière est dans les teintes
// du violet au rouge, le visage dans l'orange et le jaune ; le contour (trop sombre) et la
// langue ou les reflets (trop clairs) gardent leurs couleurs. Seuils réglés sur captures.

uniform vec4 couleur_joueur : source_color = vec4(1.0);
// Barbouillage de l'étourdissement (phase 8) : toute la tête vire à la couleur de l'agresseur.
uniform vec4 barbouillage_couleur : source_color = vec4(1.0);
uniform float barbouillage_force : hint_range(0.0, 1.0) = 0.0;

// Teinte en degrés, de -180 à 180 (0 = rouge, négatif = vers le violet).
const vec2 TEINTE_BORD_VIOLET = vec2(-110.0, -80.0);  // fondu d'entrée
const vec2 TEINTE_BORD_VISAGE = vec2(8.0, 18.0);      // fondu de sortie
const vec2 VALEUR_BORD_SOMBRE = vec2(0.10, 0.22);     // en dessous : contour
const vec2 VALEUR_BORD_CLAIR = vec2(0.78, 0.92);      // au-dessus : langue, reflets
const vec2 SATURATION_MIN = vec2(0.20, 0.35);         // en dessous : gris, blancs
// La crinière est sombre (valeur médiane ≈ 0,38) : sans gain, luminance × couleur la noircit.
const float GAIN_LUMINANCE = 2.2;

vec3 rgb_vers_tsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// 1 sur la crinière, 0 ailleurs, avec des fondus pour éviter les pixels isolés.
float masque_criniere(vec3 c) {
	vec3 tsv = rgb_vers_tsv(c);
	float teinte = tsv.x * 360.0;
	if (teinte > 180.0) {
		teinte -= 360.0;
	}
	float m = smoothstep(TEINTE_BORD_VIOLET.x, TEINTE_BORD_VIOLET.y, teinte)
		* (1.0 - smoothstep(TEINTE_BORD_VISAGE.x, TEINTE_BORD_VISAGE.y, teinte));
	m *= smoothstep(VALEUR_BORD_SOMBRE.x, VALEUR_BORD_SOMBRE.y, tsv.z)
		* (1.0 - smoothstep(VALEUR_BORD_CLAIR.x, VALEUR_BORD_CLAIR.y, tsv.z));
	m *= smoothstep(SATURATION_MIN.x, SATURATION_MIN.y, tsv.y);
	return m;
}

void fragment() {
	vec4 base = COLOR;  // texture × modulate (le clignotement joue sur l'alpha)
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float eclat = clamp(lum * GAIN_LUMINANCE, 0.0, 1.0);
	vec3 rgb = mix(base.rgb, couleur_joueur.rgb * eclat, masque_criniere(base.rgb));
	rgb = mix(rgb, barbouillage_couleur.rgb * eclat, barbouillage_force);
	COLOR = vec4(rgb, base.a);
}
