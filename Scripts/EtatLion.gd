class_name EtatLion
extends RefCounted
## L'état d'un lion chez l'hôte, au format réseau (phase 16, logique pure : les tests `--script` le
## nomment). L'hôte l'écrit à chaque tick physique dans `Lion.etat_reseau`, que le `Synchro` du lion
## recopie chez chaque client, d'un seul tenant : l'instant (tick physique de l'hôte), le numéro de la
## dernière commande du client appliquée à ce lion (0 : aucune, ou le lion de l'hôte), la position, la
## vitesse commandée et le recul (`DeplacementLion`), l'orientation. Un client y interpole les lions
## distants (`InterpolationLion`) et y recale la prédiction de son lion (`PredictionLocale`), qui
## repart de la vitesse commandée et du recul de l'hôte, jamais de sa vitesse totale.

## Octets : instant (u32), commande (u32), position, vitesse, recul (deux f32 chacun), orientation (s8).
const TAILLE := 33


static func encoder(instant: int, commande: int, position: Vector2, vitesse: Vector2, recul: Vector2, direction: int) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(TAILLE)
	octets.encode_u32(0, instant)
	octets.encode_u32(4, commande)
	octets.encode_float(8, position.x)
	octets.encode_float(12, position.y)
	octets.encode_float(16, vitesse.x)
	octets.encode_float(20, vitesse.y)
	octets.encode_float(24, recul.x)
	octets.encode_float(28, recul.y)
	octets.encode_s8(32, direction)
	return octets


## L'état `octets` reçu de l'hôte : `{instant, commande, position, vitesse, recul, direction}`, ou un
## dictionnaire vide s'il est mal formé (autre type, taille, valeur non finie, orientation autre que
## 1 ou -1).
static func decoder(octets: Variant) -> Dictionary:
	if not (octets is PackedByteArray) or octets.size() != TAILLE:
		return {}
	var etat := {"instant": octets.decode_u32(0), "commande": octets.decode_u32(4),
		"position": Vector2(octets.decode_float(8), octets.decode_float(12)),
		"vitesse": Vector2(octets.decode_float(16), octets.decode_float(20)),
		"recul": Vector2(octets.decode_float(24), octets.decode_float(28)), "direction": octets.decode_s8(32)}
	if not (etat.position.is_finite() and etat.vitesse.is_finite() and etat.recul.is_finite()) or absi(etat.direction) != 1:
		return {}
	return etat
