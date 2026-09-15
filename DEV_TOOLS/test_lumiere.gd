extends SceneTree
##
## LES TESTS DU MOTEUR D'ÉNIGMES — lumière, miroirs, vitres, lasers, activables.
##
## ⚠ Règle héritée de River Stones (charte §6) : un test vert ne prouve rien tant qu'on ne l'a pas vu
## échouer. Les propriétés structurelles se gardent par des scénarios CONSTRUITS, jamais espérés — et
## ceux qui portent la mention « vu échouer » l'ont été, par une mutation délibérée du code.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_lumiere.gd
## Code de sortie 0 si tout passe, 1 sinon.

const Monde := preload("res://CORE/monde.gd")
const Catalogue := preload("res://CORE/catalogue.gd")
const Direction := preload("res://CORE/direction.gd")
const Couleur := preload("res://CORE/couleur.gd")

var echecs: int = 0
var verifs: int = 0


func _initialize() -> void:
	print("TESTS — Undermend, moteur d'énigmes\n")

	test_catalogue_valide()
	test_catalogue_refuse_l_inecrivable()
	test_reflexion_contre_la_geometrie()
	test_familles_de_miroirs()
	test_miroir_simple()
	test_demi_tour_et_rasant()
	test_coin_diagonal()
	test_vitres_filtrent()
	test_reactions_de_couleur()
	test_la_glace_fond_et_libere_le_faisceau()
	test_laser_detruit()
	test_cristal_relaie()
	test_porte_antique()
	test_une_boucle_ne_s_allume_pas_seule()
	test_destruction_independante_de_l_ordre()
	test_entree_et_boucle()
	test_proprietes_inconnues_refusees()
	test_dependance_toujours_directe()
	test_copie_non_intrusive()

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


func _monde(largeur: int = 9, hauteur: int = 9):
	var m = Monde.new()
	m.ajouter_grille(0, largeur, hauteur)
	return m


func _type_en(m, x: int, y: int, grille: int = 0) -> String:
	var id: int = m.objet_en(grille, Vector2i(x, y))
	return "" if id == -1 else m.objets[id]["type"]


func _faisceau_de(m, source: int) -> Dictionary:
	for f in m.faisceaux:
		if f["source"] == source:
			return f
	return {}


func _rai(m, x: int, y: int, direction: int, couleur: int = Couleur.BLANC, grille: int = 0) -> int:
	return m.poser("RAI_DE_CIEL", grille, Vector2i(x, y), {"direction": direction, "couleur": couleur})


## Un résumé qui ne dépend PAS des identifiants — pour comparer deux mondes bâtis dans un ordre différent.
func _resume(m) -> String:
	var lignes: Array = []
	for id in m.objets:
		var o: Dictionary = m.objets[id]
		var pos: Vector2i = o["case"]
		lignes.append("%d:%d:%d %s%s" % [o["grille"], pos.x, pos.y, o["type"], " ACTIF" if m.actifs.has(id) else ""])
	lignes.sort()
	return "\n".join(PackedStringArray(lignes))


# --- le catalogue ------------------------------------------------------------------------------------

func test_catalogue_valide() -> void:
	_titre("le catalogue livré se vérifie")
	var erreurs: Array = Catalogue.verifier()
	for e in erreurs:
		print("    " + e)
	_verifier(erreurs.is_empty(), "le catalogue livré a des erreurs")


## Le catalogue garantit la terminaison par ce qu'il REFUSE d'écrire. Chaque refus est présenté ici.
func test_catalogue_refuse_l_inecrivable() -> void:
	_titre("le catalogue refuse ce qui casserait la terminaison")
	_attendre_erreur({"X": {"optique": "bloque_si_actif"}}, "optique inconnue",
		"une optique qui RETIRE de la lumière une fois active doit être refusée")
	_attendre_erreur({"X": {"optique": "bloque", "emission": "si_inactif", "props": {"direction": 0, "couleur": 7, "laser": false}}},
		"emission inconnue", "une émission « si inactif » doit être refusée")
	_attendre_erreur({"X": {"optiqe": "bloque"}}, "clé inconnue",
		"une clé mal orthographiée doit être refusée")
	_attendre_erreur({"X": {"optique": "traverse_si_actif"}}, "jamais être actif",
		"un effet « si actif » sur un objet qui ne s'active jamais doit être refusé")
	_attendre_erreur({
		"A": {"optique": "bloque", "reactions": {Couleur.ROUGE: {"devient": "B"}}},
		"B": {"optique": "bloque", "reactions": {Couleur.ROUGE: {"devient": "A"}}},
	}, "cycle", "un cycle de transformations doit être refusé")
	_attendre_erreur({
		"A": {"optique": "bloque", "reactions": {Couleur.ROUGE: {"devient": "B"}, Couleur.BLEU: {"devient": "B"}}},
		"B": {"optique": "traverse"},
	}, "deux destins", "deux « devient » sur un même type doivent être refusés")
	_attendre_erreur({"X": {"optique": "traverse_si_actif", "depend": true, "active_sur_sa_couleur": true,
		"props": {"depend_de": [], "mode": "tous", "couleur": Couleur.ROUGE}}},
		"dépendant ne réagit pas", "un dépendant qui réagit aussi à la lumière doit être refusé")


func _attendre_erreur(types: Dictionary, mot: String, quoi: String) -> void:
	var erreurs: Array = Catalogue.verifier(types)
	var trouve := false
	for e in erreurs:
		if mot in e:
			trouve = true
	_verifier(trouve, quoi + " — erreurs rendues : %s" % str(erreurs))


# --- la réflexion ------------------------------------------------------------------------------------

## La formule entière (`orientation − direction`) contre une réflexion VECTORIELLE calculée à part.
## Deux dérivations indépendantes qui tombent d'accord sur les 64 cas.
func test_reflexion_contre_la_geometrie() -> void:
	_titre("la réflexion entière = la réflexion vectorielle, sur les 64 cas")
	for d in 8:
		var angle := deg_to_rad(d * 45.0)
		var attendu_vecteur := Vector2i(roundi(cos(angle)), -roundi(sin(angle)))
		_verifier(Direction.VECTEURS[d] == attendu_vecteur, "le vecteur de la direction %d" % d)
		for m in 8:
			var ligne := Vector2(cos(deg_to_rad(m * 22.5)), sin(deg_to_rad(m * 22.5)))
			var rayon := Vector2(cos(angle), sin(angle))
			var parallele := absf(rayon.cross(ligne)) < 1e-6
			_verifier(parallele == Direction.rasant(d, m), "rasant(%d, %d)" % [d, m])
			if parallele:
				continue
			var normale := Vector2(-ligne.y, ligne.x)
			var reflechi := rayon - 2.0 * rayon.dot(normale) * normale
			var sortie := posmod(roundi(rad_to_deg(atan2(reflechi.y, reflechi.x)) / 45.0), 8)
			_verifier(sortie == Direction.reflechir(d, m), "reflechir(%d, %d) = %d, la géométrie dit %d" % [d, m, Direction.reflechir(d, m), sortie])


func test_familles_de_miroirs() -> void:
	_titre("par 45° les familles restent séparées, par 22,5° elles se rejoignent")
	for d in 8:
		for m in 8:
			if Direction.rasant(d, m):
				continue
			var meme_famille := Direction.reflechir(d, m) % 2 == d % 2
			_verifier(meme_famille == (m % 2 == 0), "famille de reflechir(%d, %d)" % [d, m])
	var atteintes := {}
	for m in 8:
		if not Direction.rasant(Direction.E, m):
			atteintes[Direction.reflechir(Direction.E, m)] = true
	_verifier(atteintes.size() == 7 and not atteintes.has(Direction.E),
		"depuis l'est, huit orientations doivent atteindre les sept autres directions")


func test_miroir_simple() -> void:
	_titre("un rai vers l'est, un miroir « / », le faisceau monte")
	var m = _monde()
	var rai := _rai(m, 0, 4, Direction.E)
	m.poser("MIROIR", 0, Vector2i(4, 4), {"orientation": 2})
	m.resoudre()
	var f := _faisceau_de(m, rai)
	var dernier: Dictionary = f["pas"][-1]
	_verifier(f["fin"] == "SORTIE", "le faisceau doit sortir par le haut, fin = %s" % f["fin"])
	_verifier(dernier["case"] == Vector2i(4, 0) and dernier["direction"] == Direction.N,
		"dernière case (4, 0) vers le nord, obtenu %s" % str(dernier))
	_verifier(f["pas"].size() == 8, "quatre cases à l'est puis quatre au nord, obtenu %d" % f["pas"].size())


func test_demi_tour_et_rasant() -> void:
	_titre("un miroir de face renvoie sur la source, un miroir de profil arrête")
	var m = _monde()
	var rai := _rai(m, 0, 4, Direction.E)
	var miroir: int = m.poser("MIROIR", 0, Vector2i(4, 4), {"orientation": 4})
	m.resoudre()
	var f := _faisceau_de(m, rai)
	_verifier(f["fin"] == "OBSTACLE" and f["impacts"][-1]["id"] == rai,
		"le rayon renvoyé doit revenir frapper sa propre source")
	m.tourner(miroir, 4)
	m.resoudre()
	f = _faisceau_de(m, rai)
	_verifier(f["fin"] == "RASANT" and f["pas"][-1]["case"] == Vector2i(4, 4),
		"un miroir parallèle au rayon doit l'arrêter par la tranche, fin = %s" % f["fin"])


func test_coin_diagonal() -> void:
	_titre("une diagonale ne se glisse pas entre un mur et une case libre")
	var m = _monde()
	var rai := _rai(m, 2, 6, Direction.NE)
	m.resoudre()
	_verifier(_faisceau_de(m, rai)["fin"] == "SORTIE", "sans mur, la diagonale doit traverser la grille")
	m.poser_mur(0, Vector2i(4, 5))
	m.resoudre()
	var f := _faisceau_de(m, rai)
	_verifier(f["fin"] == "COIN" and f["pas"][-1]["case"] == Vector2i(3, 5),
		"un seul coin plein doit arrêter la diagonale en (3, 5), fin = %s" % f["fin"])


# --- la couleur --------------------------------------------------------------------------------------

func test_vitres_filtrent() -> void:
	_titre("les vitres filtrent, et se composent")
	var m = _monde()
	var rai := _rai(m, 0, 4, Direction.E)
	m.poser("VITRE", 0, Vector2i(2, 4), {"filtre": Couleur.ROUGE})
	var oeil: int = m.poser("OEIL_SACRE", 0, Vector2i(6, 4), {"couleur": Couleur.ROUGE})
	m.resoudre()
	var f := _faisceau_de(m, rai)
	_verifier(f["pas"][1]["couleur"] == Couleur.BLANC and f["pas"][2]["couleur"] == Couleur.ROUGE,
		"blanc avant la vitre rouge, rouge après")
	_verifier(m.actifs.has(oeil), "le rouge sorti de la vitre doit allumer l'œil rouge")

	var m2 = _monde()
	var bleu := _rai(m2, 0, 4, Direction.E, Couleur.BLEU)
	m2.poser("VITRE", 0, Vector2i(2, 4), {"filtre": Couleur.ROUGE})
	m2.resoudre()
	_verifier(_faisceau_de(m2, bleu)["fin"] == "ABSORBE", "un bleu ne traverse pas une vitre rouge")

	var m3 = _monde()
	_rai(m3, 0, 4, Direction.E)
	m3.poser("VITRE", 0, Vector2i(2, 4), {"filtre": Couleur.JAUNE})
	m3.poser("VITRE", 0, Vector2i(3, 4), {"filtre": Couleur.CYAN})
	var vert: int = m3.poser("OEIL_SACRE", 0, Vector2i(6, 4), {"couleur": Couleur.VERT})
	m3.resoudre()
	_verifier(m3.actifs.has(vert), "blanc, puis jaune, puis cyan : il ne reste que le vert")


func test_reactions_de_couleur() -> void:
	_titre("chaque cible réagit à SA couleur, et à rien d'autre")
	_cas_reaction(Couleur.ROUGE, "PILIER_GLACE", {}, "FLAQUE", false, "un rouge fait fondre la glace")
	_cas_reaction(Couleur.BLANC, "PILIER_GLACE", {}, "PILIER_GLACE", false,
		"⚠ règle exacte : un blanc ne fait pas fondre la glace")
	_cas_reaction(Couleur.BLEU, "COLONNE_FEU", {}, "COLONNE_ETEINTE", false, "un bleu éteint le feu")
	_cas_reaction(Couleur.ROUGE, "COLONNE_FEU", {}, "COLONNE_FEU", false, "un rouge n'éteint pas le feu")
	_cas_reaction(Couleur.VIOLET, "OEIL_SACRE", {"couleur": Couleur.JAUNE}, "OEIL_SACRE", false,
		"un violet sur un œil jaune ne fait rien")
	_cas_reaction(Couleur.JAUNE, "OEIL_SACRE", {"couleur": Couleur.JAUNE}, "OEIL_SACRE", true,
		"un jaune allume l'œil jaune")


func _cas_reaction(couleur: int, type: String, props: Dictionary, type_attendu: String, actif_attendu: bool, quoi: String) -> void:
	var m = _monde()
	_rai(m, 0, 4, Direction.E, couleur)
	var id: int = m.poser(type, 0, Vector2i(4, 4), props)
	var evenements: Array = m.resoudre()
	_verifier(_type_en(m, 4, 4) == type_attendu and m.actifs.has(id) == actif_attendu,
		quoi + " — obtenu %s, actif = %s" % [_type_en(m, 4, 4), m.actifs.has(id)])
	if type_attendu == type and not actif_attendu:
		_verifier(evenements.is_empty(), quoi + " — et sans le moindre événement")


# --- les enchaînements -------------------------------------------------------------------------------

func test_la_glace_fond_et_libere_le_faisceau() -> void:
	_titre("la glace fond, et le faisceau libéré va plus loin DANS LA MÊME résolution")
	var m = _monde()
	_rai(m, 0, 4, Direction.E, Couleur.ROUGE)
	m.poser("PILIER_GLACE", 0, Vector2i(3, 4))
	var oeil: int = m.poser("OEIL_SACRE", 0, Vector2i(7, 4), {"couleur": Couleur.ROUGE})
	var evenements: Array = m.resoudre()
	_verifier(_type_en(m, 3, 4) == "FLAQUE", "le pilier doit être devenu une flaque")
	_verifier(m.actifs.has(oeil), "l'œil derrière le pilier doit être allumé")
	_verifier(evenements.size() == 2 and evenements[0]["type"] == "transforme" and evenements[1]["type"] == "active",
		"on anime la fonte, PUIS l'allumage — obtenu %s" % str(evenements))


func test_laser_detruit() -> void:
	_titre("un laser détruit ce qui est destructible, et continue")
	var m = _monde()
	var rai := _rai(m, 0, 4, Direction.E)
	m.poser("VITRE", 0, Vector2i(2, 4), {"concentre": true})
	m.poser("MIROIR", 0, Vector2i(5, 4), {"orientation": 2, "destructible": true})
	var evenements: Array = m.resoudre()
	var f := _faisceau_de(m, rai)
	_verifier(_type_en(m, 5, 4) == "" and evenements[0]["type"] == "detruit", "le miroir destructible doit disparaître")
	_verifier(f["fin"] == "SORTIE" and f["pas"][-1]["case"] == Vector2i(8, 4) and f["pas"][-1]["laser"],
		"le laser doit poursuivre vers l'est à travers la place du miroir")

	var m2 = _monde()
	var rai2 := _rai(m2, 0, 4, Direction.E)
	m2.poser("VITRE", 0, Vector2i(2, 4), {"concentre": true})
	m2.poser("MIROIR", 0, Vector2i(5, 4), {"orientation": 2})
	m2.resoudre()
	_verifier(_type_en(m2, 5, 4) == "MIROIR" and _faisceau_de(m2, rai2)["pas"][-1]["case"] == Vector2i(5, 0),
		"un miroir ordinaire réfléchit le laser et survit")

	var m3 = _monde()
	_rai(m3, 0, 4, Direction.E, Couleur.ROUGE)
	m3.poser("VITRE", 0, Vector2i(2, 4), {"concentre": true})
	m3.poser("CRISTAL", 0, Vector2i(5, 4), {"couleur": Couleur.ROUGE})
	var ev3: Array = m3.resoudre()
	var allume := false
	for e in ev3:
		if e["type"] == "active":
			allume = true
	_verifier(_type_en(m3, 5, 4) == "" and not allume,
		"un cristal frappé par un laser de SA couleur est détruit, et ne s'allume jamais")


func test_cristal_relaie() -> void:
	_titre("un cristal allumé relaie sa couleur")
	var m = _monde()
	_rai(m, 0, 4, Direction.E, Couleur.ROUGE)
	var cristal: int = m.poser("CRISTAL", 0, Vector2i(4, 4), {"couleur": Couleur.ROUGE, "direction": Direction.N})
	var oeil: int = m.poser("OEIL_SACRE", 0, Vector2i(4, 1), {"couleur": Couleur.ROUGE})
	m.resoudre()
	_verifier(m.actifs.has(cristal) and m.actifs.has(oeil), "le cristal et l'œil qu'il éclaire doivent être allumés")
	_verifier(m.faisceaux.size() == 2, "deux faisceaux : le rai, puis le cristal")


func _monde_porte(avec_b: bool, mode: String) -> Array:
	var m = _monde()
	_rai(m, 0, 2, Direction.E, Couleur.JAUNE)
	var a: int = m.poser("OEIL_SACRE", 0, Vector2i(4, 2))
	if avec_b:
		_rai(m, 0, 6, Direction.E, Couleur.JAUNE)
	var b: int = m.poser("OEIL_SACRE", 0, Vector2i(4, 6))
	var porte: int = m.poser("PORTE_ANTIQUE", 0, Vector2i(6, 4), {"depend_de": [a, b], "mode": mode})
	var rouge := _rai(m, 0, 4, Direction.E, Couleur.ROUGE)
	var c: int = m.poser("OEIL_SACRE", 0, Vector2i(8, 4), {"couleur": Couleur.ROUGE})
	return [m, porte, rouge, c]


func test_porte_antique() -> void:
	_titre("une porte antique s'ouvre sur ses yeux, et laisse passer ce qu'elle arrêtait")
	var r: Array = _monde_porte(true, "tous")
	var m = r[0]
	m.resoudre()
	_verifier(m.actifs.has(r[1]) and m.actifs.has(r[3]), "deux yeux allumés : porte ouverte, œil rouge atteint")

	r = _monde_porte(false, "tous")
	m = r[0]
	m.resoudre()
	_verifier(not m.actifs.has(r[1]) and not m.actifs.has(r[3]) and _faisceau_de(m, r[2])["fin"] == "OBSTACLE",
		"un seul œil en mode « tous » : la porte reste fermée et arrête le rouge")

	r = _monde_porte(false, "un")
	m = r[0]
	m.resoudre()
	_verifier(m.actifs.has(r[1]) and m.actifs.has(r[3]), "un seul œil en mode « un » suffit")


## ⚠ VU ÉCHOUER : en partant des actifs de la résolution précédente au lieu de « rien », le cristal
## reste allumé après le retrait du rai — une boucle qui s'entretient toute seule, et un montage qui
## se SOUVIENT, c'est-à-dire un état dérivé qui s'est mis à mentir.
func test_une_boucle_ne_s_allume_pas_seule() -> void:
	_titre("un cristal qui ne s'éclaire que lui-même reste éteint, et un montage n'a pas de mémoire")
	var m = _monde()
	var cristal: int = m.poser("CRISTAL", 0, Vector2i(2, 2), {"couleur": Couleur.ROUGE, "direction": Direction.E})
	m.poser("MIROIR", 0, Vector2i(6, 2), {"orientation": 6})
	m.poser("MIROIR", 0, Vector2i(6, 6), {"orientation": 2})
	m.poser("MIROIR", 0, Vector2i(2, 6), {"orientation": 6})
	m.resoudre()
	_verifier(not m.actifs.has(cristal) and m.faisceaux.is_empty(), "sans lumière extérieure, rien ne s'allume")

	var rai := _rai(m, 0, 2, Direction.E, Couleur.ROUGE)
	m.resoudre()
	_verifier(m.actifs.has(cristal) and m.faisceaux.size() == 2, "un rai rouge allume le cristal, qui boucle sur lui-même")

	m.retirer(rai)
	var evenements: Array = m.resoudre()
	_verifier(not m.actifs.has(cristal), "le rai retiré, le cristal doit s'éteindre malgré sa propre boucle")
	_verifier(evenements.size() == 1 and evenements[0]["type"] == "desactive", "et le dire : %s" % str(evenements))


## ⚠ VU ÉCHOUER : sans l'écrasement de `_destins`, la destruction ne l'emporte que si le laser est tracé
## le premier — le pilier sort en flaque dans un ordre et disparaît dans l'autre.
func test_destruction_independante_de_l_ordre() -> void:
	_titre("un laser et un rouge sur le même pilier : détruit, dans les deux ordres")
	for laser_d_abord in [true, false]:
		var m = _monde()
		m.poser("PILIER_GLACE", 0, Vector2i(4, 4), {"destructible": true})
		if laser_d_abord:
			_rai(m, 4, 0, Direction.S)
			m.poser("VITRE", 0, Vector2i(4, 2), {"concentre": true})
			_rai(m, 0, 4, Direction.E, Couleur.ROUGE)
		else:
			_rai(m, 0, 4, Direction.E, Couleur.ROUGE)
			_rai(m, 4, 0, Direction.S)
			m.poser("VITRE", 0, Vector2i(4, 2), {"concentre": true})
		m.resoudre()
		_verifier(_type_en(m, 4, 4) == "", "laser tracé %s : obtenu « %s »" % ["d'abord" if laser_d_abord else "ensuite", _type_en(m, 4, 4)])

	_titre("la porte antique donne le même monde, quel que soit l'ordre de pose")
	var a = _monde_porte(true, "tous")[0]
	var b = _monde()
	var c: int = b.poser("OEIL_SACRE", 0, Vector2i(8, 4), {"couleur": Couleur.ROUGE})
	_rai(b, 0, 4, Direction.E, Couleur.ROUGE)
	var oeil_b: int = b.poser("OEIL_SACRE", 0, Vector2i(4, 6))
	var oeil_a: int = b.poser("OEIL_SACRE", 0, Vector2i(4, 2))
	b.poser("PORTE_ANTIQUE", 0, Vector2i(6, 4), {"depend_de": [oeil_a, oeil_b]})
	_rai(b, 0, 6, Direction.E, Couleur.JAUNE)
	_rai(b, 0, 2, Direction.E, Couleur.JAUNE)
	a.resoudre()
	b.resoudre()
	_verifier(_resume(a) == _resume(b) and b.actifs.has(c), "deux ordres de pose, deux mondes différents :\n%s\n---\n%s" % [_resume(a), _resume(b)])


func test_entree_et_boucle() -> void:
	_titre("une entrée fait passer la lumière d'une vue à l'autre")
	var m = _monde()
	m.ajouter_grille(1, 9, 9)
	var rai := _rai(m, 0, 4, Direction.E)
	m.poser("ENTREE", 0, Vector2i(4, 4), {"vers_grille": 1, "vers_case": Vector2i(4, 0), "vers_direction": Direction.S})
	var oeil: int = m.poser("OEIL_SACRE", 1, Vector2i(4, 5), {"couleur": Couleur.BLANC})
	_verifier(m.valider().is_empty(), "le montage doit être valide : %s" % str(m.valider()))
	m.resoudre()
	_verifier(m.actifs.has(oeil), "l'œil de la grotte doit être allumé par le rai de surface")
	_verifier(_faisceau_de(m, rai)["pas"][-1]["grille"] == 1, "le faisceau doit finir dans la grille 1")

	_titre("une boucle se referme, se termine, et dit où elle commence")
	var b = _monde()
	b.ajouter_grille(1, 9, 9)
	var rai_b := _rai(b, 0, 0, Direction.E, Couleur.BLANC, 1)
	b.poser("ENTREE", 1, Vector2i(1, 0), {"vers_grille": 0, "vers_case": Vector2i(4, 2), "vers_direction": Direction.E})
	b.poser("MIROIR", 0, Vector2i(6, 2), {"orientation": 6})
	b.poser("MIROIR", 0, Vector2i(6, 6), {"orientation": 2})
	b.poser("MIROIR", 0, Vector2i(2, 6), {"orientation": 6})
	b.poser("MIROIR", 0, Vector2i(2, 2), {"orientation": 2})
	b.resoudre()
	var f := _faisceau_de(b, rai_b)
	_verifier(f["fin"] == "BOUCLE", "le faisceau doit tourner en rond, fin = %s" % f["fin"])
	_verifier(f["boucle_depuis"] >= 0 and f["pas"][f["boucle_depuis"]]["case"] == Vector2i(4, 2),
		"la boucle doit commencer à la bouche d'arrivée (4, 2)")


# --- les montages invalides --------------------------------------------------------------------------

func test_proprietes_inconnues_refusees() -> void:
	_titre("une propriété ou un type mal orthographié est refusé (deux erreurs attendues ci-dessous)")
	var m = _monde()
	_verifier(m.poser("MIROIR", 0, Vector2i(1, 1), {"orientaton": 2}) == -1, "« orientaton » doit être refusée")
	_verifier(m.poser("MIRROR", 0, Vector2i(1, 1)) == -1, "« MIRROR » doit être refusé")
	_verifier(m.objets.is_empty(), "rien ne doit avoir été posé")


func test_dependance_toujours_directe() -> void:
	_titre("une porte dépend d'activables allumés par la lumière, jamais d'une autre porte")
	var m = _monde()
	var oeil: int = m.poser("OEIL_SACRE", 0, Vector2i(1, 1))
	var p1: int = m.poser("PORTE_ANTIQUE", 0, Vector2i(3, 3), {"depend_de": [oeil]})
	_verifier(m.valider().is_empty(), "une porte sur un œil est valide : %s" % str(m.valider()))
	m.poser("PORTE_ANTIQUE", 0, Vector2i(5, 5), {"depend_de": [p1]})
	var trouve := false
	for e in m.valider():
		if "toujours directe" in e:
			trouve = true
	_verifier(trouve, "une porte sur une porte doit être refusée : %s" % str(m.valider()))

	var vide = _monde()
	vide.poser("PORTE_ANTIQUE", 0, Vector2i(3, 3))
	_verifier(not vide.valider().is_empty(), "une porte sans dépendance doit être refusée")


func test_copie_non_intrusive() -> void:
	_titre("résoudre une copie ne touche pas l'original, et une seconde résolution ne dit rien")
	var m = _monde_porte(true, "tous")[0]
	var avant: int = m.empreinte()
	var c = m.copie()
	c.resoudre()
	_verifier(m.empreinte() == avant and m.actifs.is_empty(), "l'original a bougé en résolvant sa copie")
	m.resoudre()
	_verifier(_resume(m) == _resume(c), "l'original et sa copie doivent se résoudre à l'identique")
	_verifier(m.resoudre().is_empty(), "résoudre un monde déjà résolu ne doit produire aucun événement")
