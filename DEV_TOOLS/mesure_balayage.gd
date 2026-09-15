extends SceneTree
##
## MESURE DU BALAYAGE — le séparateur qui glisse coûte-t-il des images ?
##
## Le greybox de l'écran partagé tourne sans vsync ni plafond, et l'on relève le temps d'une image dans
## cinq situations, entrelacées passe après passe :
##   surface_seule            séparateur à 320, la grotte ne se rend pas
##   bande_fixe               séparateur à 240, les deux vues rendues
##   sous_terre_fixe          séparateur à 80
##   balayage                 le séparateur ne s'arrête jamais (80 ↔ 320), par le vrai chemin du jeu
##   balayage_redimensionne   le même, en redimensionnant les SubViewport à chaque image — ce que la
##                            charte interdit (§3), mesuré pour savoir ce que l'interdit épargne
##
## ⚠ Le bruit est à sens unique (River Stones, §8) : une charge étrangère ne peut qu'AJOUTER du temps.
## On compare donc les MINIMUMS de plusieurs passes, jamais une moyenne ni une passe isolée.
##
## ⚠ AVEC fenêtre : le mode headless ne rend rien, il ne mesurerait rien.
##   godot --path D:/UnderMend --script res://DEV_TOOLS/mesure_balayage.gd

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")

const PASSES := 5
const CHAUFFE := 0.5
const DUREE_PASSE := 2.0
const LOIN := Vector2(40.5, 4.5)  # à plus de dix cases de toute entrée
const PRES := Vector2(10.5, 7.5)  # à une case de l'entrée (10, 6)

const SCENARIOS := ["surface_seule", "bande_fixe", "sous_terre_fixe", "balayage", "balayage_redimensionne"]

var greybox
var _scenario := 0
var _passe := 0
var _t := 0.0
var _debut_usec := 0
var _images := 0
var _en_mouvement := 0
var _grotte_rendue := 0
var _resultats := {}


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	greybox = load("res://DEV_TOOLS/greybox_ecran_partage.tscn").instantiate()
	root.add_child(greybox)
	for nom in SCENARIOS:
		_resultats[nom] = []
	print("MESURE — balayage de l'écran partagé, %d passes de %.1f s, sans vsync" % [PASSES, DUREE_PASSE])
	print("  carte graphique : %s" % RenderingServer.get_video_adapter_name())


func _process(delta: float) -> bool:
	if greybox.ecran == null:
		return false  # ⚠ en --script, le _ready du greybox n'a lieu qu'à la première image
	if _passe == 0 and _scenario == 0 and _t == 0.0:
		_preparer()
	var nom: String = SCENARIOS[_scenario]
	_piloter(nom)
	_t += delta
	if _t < CHAUFFE:
		return false
	if _debut_usec == 0:
		_debut_usec = Time.get_ticks_usec()
		return false
	_images += 1
	if greybox.mep.balayage.en_mouvement():
		_en_mouvement += 1
	if greybox.ecran.grotte.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		_grotte_rendue += 1
	if _t < CHAUFFE + DUREE_PASSE:
		return false

	var ms := float(Time.get_ticks_usec() - _debut_usec) / _images / 1000.0
	_resultats[nom].append(ms)
	print("  passe %d  %-24s %7.3f ms  (%5d i/s)  en mouvement %3d %%  grotte rendue %3d %%" % [
		_passe + 1, nom, ms, roundi(1000.0 / ms), 100 * _en_mouvement / _images, 100 * _grotte_rendue / _images])
	_scenario += 1
	if _scenario == SCENARIOS.size():
		_scenario = 0
		_passe += 1
	if _passe == PASSES:
		_bilan()
		return true
	_preparer()
	return false


func _preparer() -> void:
	_t = 0.0
	_debut_usec = 0
	_images = 0
	_en_mouvement = 0
	_grotte_rendue = 0
	greybox.ecran.surface.size = Vector2i(MiseEnPage.LARGEUR, MiseEnPage.HAUTEUR)
	greybox.ecran.grotte.size = Vector2i(MiseEnPage.LARGEUR, MiseEnPage.HAUTEUR)
	greybox.grotte = 1
	greybox.colonne = 12.5
	match SCENARIOS[_scenario]:
		"bande_fixe":
			greybox.sous_terre = false
			greybox.pos_surface = PRES
		"sous_terre_fixe":
			greybox.sous_terre = true
		_:
			greybox.sous_terre = false
			greybox.pos_surface = LOIN


func _piloter(nom: String) -> void:
	if not nom.begins_with("balayage"):
		return
	if not greybox.mep.balayage.en_mouvement():
		greybox.sous_terre = not greybox.sous_terre  # 320 → 80 → 320… le séparateur ne s'arrête pas
	if nom == "balayage_redimensionne":
		var s: int = greybox.ecran.separateur
		greybox.ecran.surface.size = Vector2i(maxi(s, 1), MiseEnPage.HAUTEUR)
		greybox.ecran.grotte.size = Vector2i(maxi(MiseEnPage.LARGEUR - s, 1), MiseEnPage.HAUTEUR)


func _bilan() -> void:
	print("\nMINIMUM DES %d PASSES (ms par image)" % PASSES)
	var reference: float = (_resultats["bande_fixe"] as Array).min()
	for nom in SCENARIOS:
		var mesures: Array = _resultats[nom]
		var minimum: float = mesures.min()
		print("  %-24s %7.3f ms  (%5d i/s)  %+6.1f %% par rapport à bande_fixe" % [
			nom, minimum, roundi(1000.0 / minimum), 100.0 * (minimum - reference) / reference])
