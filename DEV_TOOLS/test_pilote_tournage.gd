extends "res://DEV_TOOLS/filmer_ui.gd"
## TEST — le pilote des tournages (`filmer_ui.gd`) garde ses touches tenues quand la fenêtre perd la main.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_pilote_tournage.gd
##
## LE DÉFAUT (trailer final, 7 octobre 2026) : « le vol s'arrête net, x et z figés au centième, W tenu ; le faire monter
## ne le débloque pas ». Ce n'était pas le personnage : sous Windows, quand une AUTRE application prend la main, Godot
## relâche toutes les touches enfoncées — MESURÉ (sonde, W injectée par `parse_input_event`, le Bloc-notes ouvert
## par-dessus : `is_physical_key_pressed(KEY_W)` passe à faux à la perte du focus). Le vol de `filmer_trailer_final.gd`
## enfonçait W UNE fois pour 50 s ; Espace et A, renvoyées à chaque image, le faisaient encore monter et descendre.
## Reproduit en headless sur le vrai tournage (W relâchée au milieu du vol : x et z figés au millionième, y qui oscille
## de 24,6 à 29,4 — la prise 5 à l'identique).
##
## ⚠ Le headless n'a pas de fenêtre à qui ôter la main, et `Input.release_pressed_events` n'est pas exposé aux scripts :
## on rejoue son EFFET, un relâché de W qui ne passe pas par le pilote. Attendus écrits à la main.
## ⚠ On n'ouvre pas l'appli (`_initialize` remplacé) : seul le pilote est éprouvé, et un stickman en vol, mené par W
## comme la vue le mène (`Vue._mener_le_jeu` : W lue par sa PLACE, `is_physical_key_pressed`).

const Personnage_ := preload("res://app/personnage.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le pilote des tournages ===\n")
	_verifier.call_deferred()


func _vrai(c: bool, quoi: String) -> void:
	if c:
		_ok += 1
		print("  ok  " + quoi)
	else:
		_echecs += 1
		print("  ÉCHEC  " + quoi)


## Ce que Windows fait à la perte du focus, pour une touche : relâchée, sans que le pilote le sache.
func _perdre_la_main(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _verifier() -> void:
	# 1. LA TOUCHE TENUE SURVIT À LA PERTE DU FOCUS.
	_cle(KEY_W, true)
	await process_frame
	_vrai(Input.is_physical_key_pressed(KEY_W), "W enfoncée par le pilote : tenue")
	_perdre_la_main(KEY_W)
	_vrai(not Input.is_physical_key_pressed(KEY_W), "la fenêtre perd la main : W relâchée (l'effet rejoué)")
	await process_frame
	await process_frame
	_vrai(Input.is_physical_key_pressed(KEY_W), "… une image plus tard, le pilote l'a RENFONCÉE (elle est encore tenue)")

	# 2. UNE TOUCHE LÂCHÉE PAR LE PILOTE NE REVIENT PAS.
	_cle(KEY_W, false)
	await process_frame
	await process_frame
	_vrai(not Input.is_physical_key_pressed(KEY_W), "W lâchée par le pilote : elle reste lâchée")
	_cle(KEY_F, true)
	_cle(KEY_F, false)
	_perdre_la_main(KEY_F)
	await process_frame
	_vrai(not Input.is_physical_key_pressed(KEY_F), "une touche frappée (F) n'est pas renfoncée : le vol ne rebascule pas")

	# 3. LE STICKMAN EN VOL CONTINUE D'AVANCER (la prise 5 : il restait figé, x et z au millionième).
	var monde := Node3D.new()
	root.add_child(monde)
	var p: CharacterBody3D = Personnage_.new()
	monde.add_child(p)
	p.global_position = Vector3(0, 20, 0)
	p.basculer_vol()
	_cle(KEY_W, true)
	for i in 30:
		p.entree = Vector2(0, 1) if Input.is_physical_key_pressed(KEY_W) else Vector2.ZERO
		await physics_frame
	_perdre_la_main(KEY_W)
	var avant := p.global_position
	for i in 45:
		p.entree = Vector2(0, 1) if Input.is_physical_key_pressed(KEY_W) else Vector2.ZERO
		await physics_frame
	var pas := Vector2(p.global_position.x - avant.x, p.global_position.z - avant.z).length()
	# 45 images de physique à 60 Hz = 0,75 s à 5 cases/s : ~3,7 cases ; figé, il n'en ferait que l'élan (~0,7).
	_vrai(pas > 2.5, "en vol, W tenue par le pilote : la fenêtre perd la main et il avance encore (%.2f cases en 0,75 s)" % pas)
	_cle(KEY_W, false)
	monde.queue_free()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)
