extends SceneTree
##
## LES TESTS DE LA MISE EN PAGE — séparateur, balayage, hystérésis, événements montrés, fenêtre 2:1.
##
## ⚠ Règle héritée de River Stones (charte §6) : un test vert ne prouve rien tant qu'on ne l'a pas vu
## échouer. Chaque propriété est gardée par un scénario CONSTRUIT pour la casser.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_mise_en_page.gd
## Code de sortie 0 si tout passe, 1 sinon.

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")

const IMAGE := 1.0 / 60.0

var echecs: int = 0
var verifs: int = 0


func _initialize() -> void:
	print("TESTS — Undermend, mise en page de l'écran partagé\n")

	test_cible()
	test_hysteresis()
	test_entree_la_plus_proche()
	test_balayage_arrive()
	test_balayage_sans_saut()
	test_balayage_sans_a_coup()
	test_balayage_ne_depasse_pas()
	test_balayage_independant_des_images()
	test_evenement_attend_la_bande()
	test_evenements_en_file()
	test_sous_terre_ignore_les_evenements()
	test_reouverture_pendant_la_fermeture()
	test_vues_rendues()
	test_centres()
	test_taille_fenetre()

	print("")
	if echecs == 0:
		print("TOUT PASSE — %d vérifications." % verifs)
	else:
		print("%d ÉCHEC(S) sur %d vérifications." % [echecs, verifs])
	quit(1 if echecs > 0 else 0)


# --- outillage ---------------------------------------------------------------------------------------

func _verifier(condition: bool, quoi: String) -> void:
	verifs += 1
	if not condition:
		echecs += 1
		print("  ÉCHEC — " + quoi)


func _titre(texte: String) -> void:
	print("• " + texte)


## Avance `mep` pendant `secondes`, image par image, et rend la plus petite et la plus grande position vues.
func _laisser(mep, secondes: float, sous_terre: bool, distance: float) -> Vector2:
	var bornes := Vector2(INF, -INF)
	var t := 0.0
	while t < secondes - 1e-9:
		mep.avancer(IMAGE, sous_terre, distance)
		bornes = Vector2(minf(bornes.x, mep.balayage.position), maxf(bornes.y, mep.balayage.position))
		t += IMAGE
	return bornes


# --- les règles --------------------------------------------------------------------------------------

func test_cible() -> void:
	_titre("sous terre, les deux vues ; en surface, la grotte ne vient que si elle a quelque chose à dire")
	_verifier(MiseEnPage.cible(true, false, false) == 80, "sous terre loin de tout : 80")
	_verifier(MiseEnPage.cible(true, true, true) == 80, "sous terre, ni entrée ni événement ne changent rien")
	_verifier(MiseEnPage.cible(false, false, false) == 320, "en surface sans raison : surface seule")
	_verifier(MiseEnPage.cible(false, true, false) == 240, "près d'une entrée : la bande")
	_verifier(MiseEnPage.cible(false, false, true) == 240, "pendant un événement : la bande")


func test_hysteresis() -> void:
	_titre("longer le seuil d'une entrée ne fait pas balayer l'écran en boucle")
	var proche := false
	var bascules := 0
	var r := MiseEnPage.RAYON_ENTREE
	var m := MiseEnPage.MARGE_ENTREE
	# on arrive, on longe le seuil en oscillant de part et d'autre du rayon, on s'éloigne, on relonge
	var parcours: Array = [r + 5.0, r + 0.5, r - 0.1]
	for i in 40:
		parcours.append(r - 0.4 if i % 2 == 0 else r + m * 0.9)
	parcours.append(r + m + 0.1)
	for i in 40:
		parcours.append(r + 0.1 if i % 2 == 0 else r + m * 1.5)
	for d in parcours:
		var suivant := MiseEnPage.proche_entree(proche, d)
		if suivant != proche:
			bascules += 1
		proche = suivant
	_verifier(bascules == 2, "on doit basculer deux fois (arriver, repartir), pas %d" % bascules)
	_verifier(not MiseEnPage.proche_entree(false, r + 0.01), "juste hors du rayon, la bande ne s'ouvre pas")
	_verifier(MiseEnPage.proche_entree(true, r + m), "à rayon + marge, elle reste ouverte")


func test_entree_la_plus_proche() -> void:
	_titre("près de plusieurs entrées, la plus proche gagne ; à égalité, la première")
	var entrees: Array = [Vector2i(10, 4), Vector2i(4, 4), Vector2i(4, 10)]
	var p := MiseEnPage.entree_la_plus_proche(Vector2(4.5, 5.5), entrees)
	_verifier(p["index"] == 1 and is_equal_approx(p["distance"], 1.0), "attendu l'entrée 1 à une case, obtenu %s" % str(p))
	var egal := MiseEnPage.entree_la_plus_proche(Vector2(4.5, 7.5), entrees)
	_verifier(egal["index"] == 1, "à égalité entre 1 et 2, la première de la liste : %s" % str(egal))
	_verifier(MiseEnPage.entree_la_plus_proche(Vector2.ZERO, [])["index"] == -1, "sans entrée : -1")


# --- le balayage -------------------------------------------------------------------------------------

func test_balayage_arrive() -> void:
	_titre("le balayage arrive en sa durée, exactement, et s'arrête")
	var b := MiseEnPage.Balayage.new(320, 80, 320)
	b.viser(80)
	var t := 0.0
	while b.en_mouvement() and t < 10.0:
		b.avancer(IMAGE)
		t += IMAGE
	_verifier(absf(t - MiseEnPage.DUREE_BALAYAGE) < IMAGE + 1e-6, "arrivé en %.3f s au lieu de %.3f" % [t, MiseEnPage.DUREE_BALAYAGE])
	_verifier(b.position == 80.0 and b.pixel() == 80 and b.vitesse() == 0.0, "arrivé et immobile sur 80")


## Vu échouer : trajet repris depuis l'ancienne cible au lieu de la position courante.
func test_balayage_sans_saut() -> void:
	_titre("changer de cible en plein mouvement repart de la position COURANTE")
	var b := MiseEnPage.Balayage.new(320, 80, 320)
	b.viser(80)
	for i in 8:
		b.avancer(IMAGE)
	var avant := b.position
	b.viser(320)
	_verifier(b.position == avant, "viser ne doit pas déplacer")
	b.avancer(0.001)
	_verifier(absf(b.position - avant) < 2.0, "saut de %.1f px en une milliseconde" % absf(b.position - avant))


## Vu échouer : élan remis à zéro à chaque changement de cible.
func test_balayage_sans_a_coup() -> void:
	_titre("changer de cible garde la vitesse : ni saut, ni à-coup")
	var b := MiseEnPage.Balayage.new(80, 80, 320)
	b.viser(240)
	for i in 9:  # au milieu du trajet, pleine vitesse
		b.avancer(IMAGE)
	var v := b.vitesse()
	b.viser(320)  # on s'éloigne de l'entrée pendant qu'on remonte : même sens, plus loin
	_verifier(v > 100.0 and absf(b.vitesse() - v) < 1e-3, "vitesse %.1f avant, %.1f après" % [v, b.vitesse()])


## Vu échouer : plafond de l'élan retiré.
func test_balayage_ne_depasse_pas() -> void:
	_titre("un élan fort vers une cible toute proche ne la dépasse pas")
	var b := MiseEnPage.Balayage.new(320, 80, 320)
	b.viser(80)
	while b.position > 250.0:
		b.avancer(IMAGE / 4.0)
	b.viser(240)  # dix pixels devant, lancé vers la gauche
	var plus_bas := b.position
	while b.en_mouvement():
		b.avancer(IMAGE / 4.0)
		plus_bas = minf(plus_bas, b.position)
	_verifier(plus_bas >= 240.0, "le séparateur est descendu à %.1f, sous sa cible 240" % plus_bas)
	_verifier(b.position == 240.0, "arrivé sur 240")


## Vu échouer : position intégrée à la vitesse (Euler) au lieu d'être une fonction du temps.
func test_balayage_independant_des_images() -> void:
	_titre("à 30 ou à 240 images par seconde, le séparateur est au même endroit au même instant")
	var lent := MiseEnPage.Balayage.new(320, 80, 320)
	var vif := MiseEnPage.Balayage.new(320, 80, 320)
	for b in [lent, vif]:
		b.viser(80)
	for i in 3:
		lent.avancer(1.0 / 30.0)
	for i in 24:
		vif.avancer(1.0 / 240.0)
	for b in [lent, vif]:
		b.viser(240)  # interrompu au même instant, t = 0,1 s
	for i in 3:
		lent.avancer(1.0 / 30.0)
	for i in 24:
		vif.avancer(1.0 / 240.0)
	_verifier(absf(lent.position - vif.position) < 1e-3, "%.4f à 30 i/s, %.4f à 240 i/s" % [lent.position, vif.position])


# --- les événements ----------------------------------------------------------------------------------

## Vu échouer : horloge de l'événement lancée dès sa réception.
func test_evenement_attend_la_bande() -> void:
	_titre("un événement reste montré sa durée ENTIÈRE bande ouverte, plus le maintien")
	var mep = MiseEnPage.new()
	var duree := 0.6
	mep.avancer(IMAGE, false, INF)
	mep.signaler(1, Vector2i(6, 6), duree)
	_laisser(mep, MiseEnPage.DUREE_BALAYAGE, false, INF)
	_verifier(mep.pixel() == 240, "la bande doit être ouverte après un balayage, séparateur %d" % mep.pixel())
	_verifier(mep.evenements.courant().get("progression", -1.0) < 2.0 * IMAGE, "l'horloge ne doit pas avoir tourné pendant l'ouverture : %s" % str(mep.evenements.courant()))
	var bornes := _laisser(mep, duree + MiseEnPage.MAINTIEN - 2.0 * IMAGE, false, INF)
	_verifier(bornes.y == 240.0, "la bande s'est refermée trop tôt (jusqu'à %.1f)" % bornes.y)
	_laisser(mep, 3.0 * IMAGE + MiseEnPage.DUREE_BALAYAGE, false, INF)
	_verifier(mep.pixel() == 320, "puis la bande se referme : séparateur %d" % mep.pixel())


func test_evenements_en_file() -> void:
	_titre("deux événements se montrent l'un après l'autre, dans l'ordre de resoudre()")
	var mep = MiseEnPage.new()
	mep.signaler(1, Vector2i(6, 6), 0.5)
	mep.signaler(2, Vector2i(3, 2), 0.4)
	_laisser(mep, MiseEnPage.DUREE_BALAYAGE + 0.1, false, INF)
	_verifier(mep.evenements.courant().get("grille", -1) == 1, "d'abord la grille 1")
	_laisser(mep, 0.5, false, INF)
	_verifier(mep.evenements.courant().get("grille", -1) == 2, "puis la grille 2 : %s" % str(mep.evenements.courant()))
	var bornes := _laisser(mep, 0.3 + MiseEnPage.MAINTIEN - 2.0 * IMAGE, false, INF)
	_verifier(bornes.y == 240.0, "la bande reste ouverte pour les deux, plus le maintien")


func test_sous_terre_ignore_les_evenements() -> void:
	_titre("sous terre, un événement ne change pas la mise en page (OUVERT, défaut : rien ne bouge)")
	var mep = MiseEnPage.new()
	_laisser(mep, 1.0, true, INF)
	mep.signaler(1, Vector2i(6, 6), 0.6)
	var bornes := _laisser(mep, 1.0, true, INF)
	_verifier(bornes == Vector2(80, 80), "le séparateur doit rester sur 80 : %s" % str(bornes))
	_laisser(mep, 1.0, false, INF)
	_verifier(mep.pixel() == 320, "remonté loin de tout, l'événement oublié ne rouvre rien")


func test_reouverture_pendant_la_fermeture() -> void:
	_titre("un événement pendant la fermeture rouvre la bande depuis où elle en est")
	var mep = MiseEnPage.new()
	_laisser(mep, 1.0, false, 1.0)  # près d'une entrée
	_laisser(mep, 0.1, false, 50.0)  # on s'éloigne : la bande commence à se refermer
	var p: float = mep.balayage.position
	_verifier(p > 240.0 and p < 320.0, "la bande doit être en train de se refermer : %.1f" % p)
	mep.signaler(1, Vector2i(2, 2), 0.5)
	mep.avancer(0.001, false, 50.0)
	_verifier(absf(mep.balayage.position - p) < 2.0 and mep.balayage.cible == 240.0, "rouverte sans saut, vers 240")


# --- l'affichage -------------------------------------------------------------------------------------

## Vu échouer : grotte rendue seulement quand son premier pixel est visible.
func test_vues_rendues() -> void:
	_titre("une vue cachée ne se rend pas, et se rend dès qu'on la vise")
	_verifier(not MiseEnPage.grotte_rendue(320, 320), "surface seule : la grotte ne se rend pas")
	_verifier(MiseEnPage.grotte_rendue(320, 240), "la bande va s'ouvrir : la grotte se rend déjà")
	_verifier(MiseEnPage.grotte_rendue(319, 320), "dernier pixel de la fermeture : encore rendue")
	_verifier(MiseEnPage.surface_rendue(80, 80), "la surface est toujours là")


func test_centres() -> void:
	_titre("chaque caméra centre le joueur dans la partie visible de sa vue")
	_verifier(MiseEnPage.centres(320) == Vector2i(160, 320), "surface seule : %s" % str(MiseEnPage.centres(320)))
	_verifier(MiseEnPage.centres(240) == Vector2i(120, 280), "bande : %s" % str(MiseEnPage.centres(240)))
	_verifier(MiseEnPage.centres(80) == Vector2i(40, 200), "sous terre : %s" % str(MiseEnPage.centres(80)))


# --- la fenêtre --------------------------------------------------------------------------------------

## Vu échouer : largeur toujours maîtresse ; plancher retiré.
func test_taille_fenetre() -> void:
	_titre("la fenêtre reste en 2:1, suit le bord qu'on tire, et a un plancher")
	var base := Vector2i(1280, 640)
	var cas := [
		[Vector2i(1400, 640), base, Vector2i(1400, 700), "tirer le bord droit élargit"],
		[Vector2i(1280, 700), base, Vector2i(1400, 700), "tirer le bas rehausse"],
		[Vector2i(1500, 700), base, Vector2i(1500, 750), "le coin : la plus forte traction commande"],
		[Vector2i(1001, 640), base, Vector2i(1000, 500), "une largeur impaire se range"],
		[Vector2i(300, 640), base, Vector2i(640, 320), "sous le plancher, le plancher"],
		[Vector2i(1280, 100), base, Vector2i(640, 320), "écrasée, le plancher"],
	]
	for c in cas:
		var obtenu := MiseEnPage.taille_fenetre(c[0], c[1])
		_verifier(obtenu == c[2], "%s : attendu %s, obtenu %s" % [c[3], c[2], obtenu])
	var ecran := MiseEnPage.taille_fenetre(Vector2i(3000, 1500), base, MiseEnPage.FENETRE_MIN, Vector2i(1920, 1000))
	_verifier(ecran == Vector2i(1920, 960), "bornée par l'écran : %s" % ecran)
	for demandee in [Vector2i(1400, 640), Vector2i(1280, 700), Vector2i(777, 333), Vector2i(100, 5000)]:
		var une := MiseEnPage.taille_fenetre(demandee, base)
		_verifier(MiseEnPage.taille_fenetre(une, une) == une and une.x == 2 * une.y,
			"%s → %s doit être 2:1 et se rendre elle-même" % [demandee, une])
