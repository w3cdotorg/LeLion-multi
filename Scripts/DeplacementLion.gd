class_name DeplacementLion
extends RefCounted
## Le déplacement d'un lion, en logique pure (aucun nœud, aucun autoload : les tests `--script` le
## nomment) : la vitesse commandée, qui suit la direction voulue avec une accélération bornée, et le
## recul (coup, étourdissement, choc), qui s'amortit de lui-même. `Lion.avancer` en fait un pas par
## tick physique sur l'hôte ; la prédiction du lion local (phase 16) rejouera les mêmes pas.

var speed := 350.0
var acceleration := 2400.0
var force_recul := 700.0
## Vitesse née des commandes (px/s).
var vitesse := Vector2.ZERO
## Vitesse née des coups et des chocs (px/s), amortie une fois et demie plus vite que la vitesse
## commandée ne se reprend.
var recul := Vector2.ZERO


## Un pas de `delta` secondes vers la direction voulue `direction` (longueur 1 au plus) : la vitesse
## commandée s'en rapproche, le recul s'amortit ; renvoie leur somme, la vitesse du lion avant les
## contacts avec les autres lions (`PareChocs.bloquer`).
func vitesse_du_pas(direction: Vector2, delta: float) -> Vector2:
	vitesse = vitesse.move_toward(direction * speed, acceleration * delta)
	recul = recul.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)
	return vitesse + recul


## Le lion s'arrête net (début d'un étourdissement) ; son recul continue.
func arreter() -> void:
	vitesse = Vector2.ZERO


## Recul d'un coup parti de `origine` sur un lion de centre `centre`, tourné vers `direction_du_lion`
## (1 = droite, -1 = gauche) : à l'opposé du coup, ou vers l'arrière du lion si l'origine est inconnue
## (`Vector2.INF`) ou confondue avec son centre.
func repousser(centre: Vector2, origine: Vector2, direction_du_lion: int) -> void:
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (centre - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	recul = direction_recul * force_recul
