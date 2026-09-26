extends SceneTree

## LE TÉMOIN PLANÈTE — un cube lisse sur lequel on POSE les gestes, placés par le calcul
##
## ⚠ **L'IDÉE EST DE JORDAN (26 septembre 2026)** : *« maintenant que tu connais tous les gestes, tu
## peux calculer comment les placer de manière optimale sur un témoin planète ? un cube lisse sur
## lequel on place les gestes intelligemment ? et après on aura tout ? »*
##
## ⚠ **ET LA RÉPONSE TIENT À UNE NUANCE QUI CHANGE TOUT : PLACER N'EST PAS ADDITIONNER.** Un geste
## mesuré seul livre N tuiles ; deux gestes voisins n'en livrent pas N + M. À leur jonction naissent
## des configurations que ni l'un ni l'autre ne contenait — parfois des classes en plus, parfois un
## **contact diagonal**, c'est-à-dire précisément ce que le peintre s'interdit. Un placeur qui
## additionnerait les catalogues rendrait donc un compte faux et un bloc illégal.
##
## D'où la règle de ce placeur : **on essaie, on MESURE, on garde si ça n'abîme rien.**
##
## ── LA PLANÈTE ──────────────────────────────────────────────────────────────────────────────────────
##
## Un cube de roche, évidé au centre, avec du ciel au-dessus. ⚠ **Les deux contextes naissent de la
## FORME, pas d'un réglage** : le dessus est sous le ciel, la cavité est sous roche. C'est la seule
## façon d'obtenir les variantes `_dehors` et leurs jumelles d'intérieur sur un même bloc.
##
## ⚠ **LE BLOC DOIT RESTER PETIT, ET C'EST UNE CONTRAINTE D'ARTISTE, PAS DE MACHINE.** L'artiste
## sculpte CHAQUE case du témoin : doubler le côté multiplie son travail par huit. Un cube de 10 tient
## ~700 cases ; un cube de 16 en tiendrait 3 500, et personne ne les sculptera.
##
## ── CE QUE LE PLACEUR NE SAIT PAS FAIRE ─────────────────────────────────────────────────────────────
##
## ⚠ Il optimise la COUVERTURE et rien d'autre. Il ne sait pas si le résultat ressemble à un paysage,
## et la charte §2 tient qu'un témoin qui couvre sans rien montrer est un mauvais témoin — c'est déjà
## arrivé ici, « 90/90 et un socle en dentelle ». L'œil de Jordan reste le juge.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/temoin_planete.gd

const MB := preload("res://addons/undermend/marching_blocks.gd")

const COTE := 10
## La roche monte jusqu'à SOL−1 ; au-dessus, le ciel.
const SOL := 7
## La cavité, en cases : de CAVE_MIN à CAVE_MAX inclus.
const CAVE_MIN := Vector3i(2, 2, 2)
const CAVE_MAX := Vector3i(7, 4, 7)

## ⚠ **`--sans-pointe` INTERDIT AUSSI LES CONTACTS PAR UN POINT, et cette option est née d'une mesure
## qui m'a démenti.** J'avais annoncé que deux tuiles — `mb_pointe_b1h1` et `mb_pointe_creuse_b3h3` —
## resteraient pour un bloc d'érosion, parce qu'aucun geste du catalogue ne les livre. Le placeur les
## a trouvées : elles naissent aux **jonctions** entre deux gestes voisins, que le catalogue, qui
## mesure chaque geste SEUL, ne pouvait structurellement pas voir.
##
## ⚠ **Ce n'est pas forcément une bonne nouvelle.** `sans_contact_diagonal` ne teste que les diagonales
## de FACE ; la famille `pointe` est une diagonale de CORPS — deux cases qui ne se touchent que par un
## coin. Elle passe donc le filtre du modèle tout en étant aussi impossible à modeler proprement que
## celles qu'on interdit. Cette option laisse Jordan trancher : couvrir 52 en acceptant de la matière
## pincée en un point, ou couvrir 50 sans une seule.
var _sans_pointe := false
## ⚠ **`--glb=<chemin>` ÉCRIT LA PLANÈTE FINIE, TRAITÉE COMME LE VRAI EXPORT.** Même amincissement,
## même soudure, mêmes normales retirées — sinon l'artiste regarderait une géométrie qui n'est pas
## celle qu'il recevra. La charte §4 tient que l'export, le catalogue et le repli lisent le MÊME appel,
## et ce fichier-ci n'a pas le droit d'être une quatrième description.
var _glb := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option == "--sans-pointe":
			_sans_pointe = true
		if option.begins_with("--glb="):
			_glb = option.substr("--glb=".length())
	print("=== LE TÉMOIN PLANÈTE ===\n")
	if _sans_pointe:
		print("⚠ --sans-pointe : les contacts par un POINT sont interdits, en plus des diagonales.\n")
	var cible: Dictionary = _cible()
	print("cible : %d tuiles sans contact diagonal\n" % cible.size())

	var planete: Dictionary = _planete()
	print("── LA PLANÈTE NUE ──")
	_dire(planete, cible)

	# ── LE PLACEMENT ────────────────────────────────────────────────────────────────────────────────
	#
	# ⚠ **GLOUTON, ET SUR LA MESURE — jamais sur le catalogue.** À chaque tour on essaie chaque geste
	# à chaque ancrage possible, on POSE, on RÉCOLTE, et l'on garde le coup qui apporte le plus de
	# tuiles neuves SANS créer un seul contact diagonal. Un coup qui en créerait est refusé même s'il
	# apportait dix classes : il rendrait le bloc illégal pour le peintre.
	print("── LE PLACEMENT ──")
	var pose: Array = []

	while true:
		var meilleur := {}
		var gain := 0
		var avant_tuiles: Dictionary = _recolter(planete)
		var avant: int = _dans_la_cible(avant_tuiles).size()
		for geste in _gestes():
			for ancre in _ancrages(planete, geste["sur"]):
				var essai: Dictionary = planete.duplicate()
				if not _appliquer(essai, geste, ancre):
					continue
				if _contacts_diagonaux(essai) > 0:
					continue
				# ⚠ **LE GAIN EST NET, ET LA PREMIÈRE VERSION NE COMPTAIT QUE LES AJOUTS.** Poser un
				# geste ne fait pas qu'ajouter : il change les configurations des sommets qu'il
				# touche, et peut donc **détruire** une tuile déjà acquise. Mesuré — le journal du
				# premier essai montrait `mb_arete_b1h1` gagnée au coup 1 et regagnée au coup 4 :
				# elle avait été perdue entre les deux, sans que rien ne le dise. Un glouton qui ne
				# compte que ce qu'il ajoute peut ainsi tourner en rond en croyant avancer.
				var apres: Dictionary = _recolter(essai)
				var net: int = _dans_la_cible(apres).size() - avant
				var neuves: Dictionary = _moins(apres, avant_tuiles)
				if net > gain:
					gain = net
					meilleur = {"geste": geste, "ancre": ancre, "cases": essai,
						"neuves": neuves}
		if gain == 0:
			break
		planete = meilleur["cases"]
		pose.append(meilleur)
		var l: Array = (meilleur["neuves"] as Dictionary).keys()
		l.sort()
		print("   %-38s en (%d,%d,%d)  +%d"
			% [meilleur["geste"]["nom"], meilleur["ancre"].x, meilleur["ancre"].y,
				meilleur["ancre"].z, gain])
		print("        %s" % ", ".join(PackedStringArray(l)))
	print("   → %d geste(s) posé(s)\n" % pose.size())

	print("── LA PLANÈTE FINIE ──")
	_dire(planete, cible)
	if _glb != "":
		print("")
		_exporter(planete, _glb)
	print("\n⚠ Ce placeur optimise la COUVERTURE. Il ne dit pas si ça ressemble à un paysage.")
	quit(0)


func _dire(pleines: Dictionary, cible: Dictionary) -> void:
	var recolte: Dictionary = _recolter(pleines)
	var dedans := {}
	var dehors := {}
	for nom in recolte:
		if cible.has(nom):
			dedans[nom] = true
		else:
			dehors[nom] = true
	var manque: Array = []
	for nom in cible:
		if not dedans.has(nom):
			manque.append(nom)
	manque.sort()
	print("   %d cases  ·  %d contact(s) diagonal(aux)" % [pleines.size(), _contacts_diagonaux(pleines)])
	print("   %d des %d tuiles visées" % [dedans.size(), cible.size()])
	if not dehors.is_empty():
		print("   ⚠ %d tuile(s) HORS CIBLE récoltée(s)" % dehors.size())
	if not manque.is_empty():
		print("   manquent : %s" % ", ".join(PackedStringArray(manque)))


# ── LA PLANÈTE ET SES ANCRAGES ──────────────────────────────────────────────────────────────────────

## ⚠ **UN GRADIN EN SURFACE DÈS LE DÉPART, ET CE N'EST PAS UN ORNEMENT.** Un dessus parfaitement plat
## ne livre qu'une seule tuile : il n'y a ni arête, ni coin, ni paroi à l'air libre. Le gradin donne au
## placeur de quoi accrocher des gestes de surface, et il est LUI-MÊME un geste — la falaise.
func _planete() -> Dictionary:
	var p := {}
	for x in COTE:
		for y in SOL:
			for z in COTE:
				p[Vector3i(x, y, z)] = true
	# la cavité
	for x in range(CAVE_MIN.x, CAVE_MAX.x + 1):
		for y in range(CAVE_MIN.y, CAVE_MAX.y + 1):
			for z in range(CAVE_MIN.z, CAVE_MAX.z + 1):
				p.erase(Vector3i(x, y, z))
	# le gradin de surface
	for x in range(0, 5):
		for z in COTE:
			p.erase(Vector3i(x, SOL - 1, z))
	return p


## Les places où un geste peut s'accrocher, selon ce sur quoi il se pose.
##
## ⚠ **ON EXCLUT UNE BANDE DE BORD, parce que la convention (A) ne récolte pas les sommets de bord.**
## Un geste posé au ras du cube serait sculpté par l'artiste et jamais récolté : du travail pour rien,
## et un compteur qui ne le dirait pas.
func _ancrages(pleines: Dictionary, sur: String) -> Array:
	var sortie: Array = []
	match sur:
		"sol_grotte":
			for x in range(CAVE_MIN.x, CAVE_MAX.x):
				for z in range(CAVE_MIN.z, CAVE_MAX.z):
					if pleines.has(Vector3i(x, CAVE_MIN.y - 1, z)) \
							and not pleines.has(Vector3i(x, CAVE_MIN.y, z)):
						sortie.append(Vector3i(x, CAVE_MIN.y, z))
		"plafond_grotte":
			for x in range(CAVE_MIN.x, CAVE_MAX.x):
				for z in range(CAVE_MIN.z, CAVE_MAX.z):
					if pleines.has(Vector3i(x, CAVE_MAX.y + 1, z)) \
							and not pleines.has(Vector3i(x, CAVE_MAX.y, z)):
						sortie.append(Vector3i(x, CAVE_MAX.y, z))
		"paroi_grotte":
			for y in range(CAVE_MIN.y, CAVE_MAX.y):
				for z in range(CAVE_MIN.z, CAVE_MAX.z):
					if pleines.has(Vector3i(CAVE_MIN.x - 1, y, z)) \
							and not pleines.has(Vector3i(CAVE_MIN.x, y, z)):
						sortie.append(Vector3i(CAVE_MIN.x, y, z))
		"surface":
			for x in range(1, COTE - 2):
				for z in range(1, COTE - 2):
					var h: int = _hauteur(pleines, x, z)
					if h >= 0:
						sortie.append(Vector3i(x, h + 1, z))
	return sortie


func _hauteur(pleines: Dictionary, x: int, z: int) -> int:
	for y in range(COTE - 1, -1, -1):
		if pleines.has(Vector3i(x, y, z)):
			return y
	return -1


## Pose un geste. Rend faux si une case sort du cube, ou si la place est déjà prise — auquel cas le
## geste ne serait pas celui qu'on croit.
func _appliquer(pleines: Dictionary, geste: Dictionary, ancre: Vector3i) -> bool:
	for d in (geste["cases"] as Array):
		var c: Vector3i = ancre + (d as Vector3i)
		if c.x < 1 or c.y < 1 or c.z < 1 \
				or c.x > COTE - 2 or c.y > COTE - 2 or c.z > COTE - 2:
			return false
		if pleines.has(c):
			return false
		pleines[c] = true
	return true


# ── LES GESTES, RÉDUITS À LEUR DÉTAIL ───────────────────────────────────────────────────────────────
#
# ⚠ **ON NE GARDE QUE LE DÉTAIL, JAMAIS LE DÉCOR.** Le catalogue mesurait « une salle 6×3×6 PLUS un
# socle en L » ; ici la salle est la planète, et le socle est le seul geste. Reposer le décor à chaque
# coup creuserait une salle dans une salle.
#
# ⚠ Et chaque détail fait **UNE case d'épaisseur**, comme la mesure l'a montré : c'est l'épaisseur qui
# décide de la classe, et un bras de deux cases ne livre pas la même chose qu'un bras d'une.
func _gestes() -> Array:
	var L: Array = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]
	var sortie: Array = []

	for sur in ["sol_grotte", "surface"]:
		var ou: String = "en grotte" if sur == "sol_grotte" else "au grand jour"
		sortie.append({"nom": "socle en L, %s" % ou, "sur": sur, "cases": L})
		sortie.append({"nom": "socle en L + case sur le COIN, %s" % ou, "sur": sur,
			"cases": L + [Vector3i(0, 1, 0)]})
		sortie.append({"nom": "socle en L + case sur un BOUT, %s" % ou, "sur": sur,
			"cases": L + [Vector3i(1, 1, 0)]})
		sortie.append({"nom": "socle en L + case sur l'AUTRE BOUT, %s" % ou, "sur": sur,
			"cases": L + [Vector3i(0, 1, 1)]})
		sortie.append({"nom": "marche qui se décale, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0),
				Vector3i(0, 1, 1)]})
		sortie.append({"nom": "marche qui se décale MIROIR, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1),
				Vector3i(1, 1, 0)]})
		sortie.append({"nom": "muret avec une marche au pied, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0),
				Vector3i(1, 1, 0), Vector3i(1, 0, 1)]})
		sortie.append({"nom": "muret, marche de l'AUTRE CÔTÉ, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0),
				Vector3i(1, 1, 0), Vector3i(0, 0, 1)]})
		sortie.append({"nom": "une case seule, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0)]})
		sortie.append({"nom": "deux cases, %s" % ou, "sur": sur,
			"cases": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]})

	# ⚠ Les mêmes, SUSPENDUS : `b1h3` est la forme accrochée au plafond, et aucun geste posé sur un sol
	# ne la livrera jamais. Le modèle est ORIENTÉ — le haut et le bas ne sont pas échangeables.
	sortie.append({"nom": "console en L au plafond", "sur": "plafond_grotte", "cases": L})
	sortie.append({"nom": "console en L + case sous le COIN", "sur": "plafond_grotte",
		"cases": L + [Vector3i(0, -1, 0)]})
	sortie.append({"nom": "console en L + case sous un BOUT", "sur": "plafond_grotte",
		"cases": L + [Vector3i(1, -1, 0)]})
	sortie.append({"nom": "console en L + case sous l'AUTRE BOUT", "sur": "plafond_grotte",
		"cases": L + [Vector3i(0, -1, 1)]})
	sortie.append({"nom": "stalactite (une case au plafond)", "sur": "plafond_grotte",
		"cases": [Vector3i(0, 0, 0)]})

	sortie.append({"nom": "bossage sur la paroi (1 × 2 × 3)", "sur": "paroi_grotte",
		"cases": [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1),
			Vector3i(0, 1, 1), Vector3i(0, 0, 2), Vector3i(0, 1, 2)]})
	sortie.append({"nom": "bosse sur la paroi (1 × 1 × 1)", "sur": "paroi_grotte",
		"cases": [Vector3i(0, 0, 0)]})
	return sortie


# ── LES RÈGLES DU MODÈLE, LUES ET JAMAIS RECOPIÉES ──────────────────────────────────────────────────

func _cible() -> Dictionary:
	var sortie := {}
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not _legal(bits):
			continue
		sortie[c["nom"]] = true
		if MB.exterieur_possible(bits):
			sortie[MB.nom_en_contexte(c["nom"], true)] = true
	return sortie


func _recolter(pleines: Dictionary) -> Dictionary:
	var plafond: int = MB.plafond_de(pleines)
	var sortie := {}
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var v := Vector3i(x, y, z)
				var bits: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(bits):
					continue
				var r: Dictionary = MB.classer(bits)
				var dehors: bool = MB.exterieur_possible(bits) \
					and MB.sous_le_ciel(pleines, v, plafond)
				sortie[MB.nom_en_contexte(r["nom"], dehors)] = true
	return sortie


## ⚠ **UNE SEULE DÉFINITION DE « LÉGAL », lue par le compteur ET par la cible.** Deux écritures
## auraient laissé le placeur poser des formes que la cible ne compte pas, ou l'inverse — et le bilan
## final aurait été juste sans que le bloc le soit.
func _legal(bits: int) -> bool:
	if not MB.sans_contact_diagonal(bits):
		return false
	if _sans_pointe and MB.nom_de(MB.classer(bits)["classe"]).begins_with("mb_pointe"):
		return false
	return true


func _contacts_diagonaux(pleines: Dictionary) -> int:
	var n := 0
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var bits: int = MB.bits(pleines, Vector3i(x, y, z))
				if MB.porte_une_surface(bits) and not _legal(bits):
					n += 1
	return n


func _moins(a: Dictionary, b: Dictionary) -> Dictionary:
	var sortie := {}
	for k in a:
		if not b.has(k):
			sortie[k] = true
	return sortie


func _dans_la_cible(tuiles: Dictionary) -> Dictionary:
	var cible: Dictionary = _cible()
	var sortie := {}
	for k in tuiles:
		if cible.has(k):
			sortie[k] = true
	return sortie


## ÉCRIT LA PLANÈTE EN `.glb`, exactement comme `exporter_le_bloc` écrit le témoin.
##
## ⚠ **ON RÉUTILISE LES APPELS DU GREFFON PLUTÔT QUE DE LES RECOPIER** — l'amincissement, la soudure,
## le retrait des normales. Une chaîne d'export parallèle divergerait de la vraie au premier réglage,
## et l'artiste sculpterait sur une géométrie que le pipeline ne lui rendrait pas.
##
## ⚠ **CE FICHIER EST FAIT POUR ÊTRE REGARDÉ, PAS ENCORE POUR REVENIR.** La planète mesure dix cases de
## côté tandis que `BlocsMaitres.COTE` en déclare huit : `librairie_depuis_glb()` le relirait dans une
## boîte trop petite et en perdrait la moitié. Le dire ici vaut mieux que de le découvrir au retour.
func _exporter(pleines: Dictionary, chemin: String) -> void:
	var BM := load("res://addons/undermend/blocs_maitres.gd")
	# ⚠ L'AMINCI, comme ce qui part réellement : `maillage_moitie` n'est rien d'autre que cet appel.
	var brut: ArrayMesh = BM._coque_sous_voxels(pleines, 0.25)
	if brut.get_surface_count() == 0:
		print("⚠ la planète est vide — rien à écrire")
		return
	var mesh: ArrayMesh = BM.sans_normales(BM.souder(brut))
	var instance := MeshInstance3D.new()
	instance.name = "MasterBlock"
	instance.mesh = mesh
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_scene(instance, etat)
	if err == OK:
		err = document.write_to_filesystem(etat, chemin)
	instance.free()
	if err != OK:
		print("⚠ échec de l'écriture (%d) : %s" % [err, chemin])
		return
	var octets: int = FileAccess.get_file_as_bytes(chemin).size()
	print("écrit → %s  (%d octets, %d cases, cube de %d)"
		% [chemin, octets, pleines.size(), COTE])
	print("   ⚠ ce .glb fait %d cases de côté ; le greffon en déclare %d." % [COTE, BM.COTE])
	print("   Il est fait pour être REGARDÉ et sculpté, pas encore pour repasser par l'import.")
