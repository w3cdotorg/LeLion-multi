extends Ennemi
## Ennemi : traverse l'écran de droite à gauche en zigzag de plus en plus ample.

var speed: float
var frequency: float
var amplitude_depart: float
var amplitude_arrivee: float
var phase_offset: float
var time := 0.0
var start_y := 0.0


func _ready() -> void:
	start_y = position.y
	speed = randf_range(80.0, 180.0)
	frequency = randf_range(0.5, 3.0)
	amplitude_depart = randf_range(20.0, 40.0)
	amplitude_arrivee = randf_range(60.0, 120.0)
	phase_offset = randf_range(0.0, PI * 2.0)


func _physics_process(delta: float) -> void:
	time += delta
	position.x -= speed * delta

	var largeur := get_viewport().get_visible_rect().size.x
	var progression: float = clamp((largeur - position.x) / (largeur + 200.0), 0.0, 1.0)
	var amplitude: float = lerp(amplitude_depart, amplitude_arrivee, progression)

	var sin_base := sin(time * frequency * PI * 2.0)
	var bruit_doux := sin(time * 7.0 + phase_offset * 0.7) * 0.1
	var offset_y := sin_base * amplitude + bruit_doux * amplitude
	position.y = start_y + offset_y
	rotation = deg_to_rad(offset_y * 0.1)

	if position.x < -200:
		queue_free()
