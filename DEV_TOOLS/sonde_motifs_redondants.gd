extends SceneTree

## SONDE — QUEL MOTIF EN CONTIENT UN AUTRE ?
##
## ⚠ **LA QUESTION EST DE JORDAN (26 septembre 2026)** : *« un tunnel percé des deux côtés montre-t-il
## en lui-même aussi ce que fait un tunnel bouché ? une salle non écartée, une salle écartée ? une
## arche fine, une arche épaisse ? une arche fine, une colonne ? la tuile solo, la tuile solo qui
## dépasse d'un plat ? »*
##
## ⚠ **C'EST LA BONNE FAÇON DE BÂTIR UN TÉMOIN, ET ELLE SE CALCULE.** Un motif n'est pas « utile » ou
## « redondant » à l'œil : il produit un ENSEMBLE de tuiles, et un ensemble en contient un autre ou
## non. Modeler deux motifs dont l'un contient l'autre coûte du travail pour zéro classe.
##
## ⚠ **MAIS L'INCLUSION NE DIT PAS TOUT, et il faut le dire avant de lire le tableau.** Deux motifs
## peuvent livrer les MÊMES classes et ne pas se valoir pour l'artiste : la charte §2 tient qu'« un
## paysage lisible est localement répétitif » et que la variété vient de l'IRRÉGULARITÉ. Cette sonde
## répond à « ai-je besoin de ce motif pour la COUVERTURE », jamais à « ce motif mérite-t-il d'exister ».
##
## ── COMMENT LES MOTIFS SONT POSÉS ───────────────────────────────────────────────────────────────────
##
## Chaque motif vit dans le MÊME décor : un massif plein sur les couches basses, du ciel au-dessus. Un
## tunnel se creuse dans la roche, une colonne se dresse dans l'air — les poser autrement leur donnerait
## des contextes différents, et l'on comparerait alors le décor et non les motifs.
##
## ⚠ **ON RÉCOLTE COMME LE TRANCHEUR RÉCOLTE — convention (A), sommets INTÉRIEURS seulement.** Un
## sommet de bord lit des cellules hors du bloc, que le trancheur tient pour vides : il récolterait la
## face de sciage. C'est justement ce qui fait la différence entre un tunnel PERCÉ (ses bouts tombent
## sur le bord, donc ne sont pas récoltés) et un tunnel BOUCHÉ (son fond est intérieur, donc récolté).
## Se tromper de convention ici répondrait à côté de la question posée.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_motifs_redondants.gd

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

## Le décor commun : un cube de COTE, massif jusqu'à SOL (exclu), ciel au-dessus.
const COTE := 9
const SOL := 4


func _initialize() -> void:
	print("=== QUEL MOTIF EN CONTIENT UN AUTRE ? ===\n")
	print("décor commun : cube de %d, massif sur les couches 0..%d, ciel au-dessus" % [COTE, SOL - 1])
	print("récolte : convention (A), sommets intérieurs seulement — comme le trancheur\n")

	var motifs: Array = [
		{"nom": "le massif nu (référence)", "cases": _massif()},
		{"nom": "TUNNEL PERCÉ des deux côtés", "cases": _tunnel(true)},
		{"nom": "TUNNEL BOUCHÉ (cul-de-sac)", "cases": _tunnel(false)},
		{"nom": "SALLE simple", "cases": _salle(false)},
		{"nom": "SALLE ÉCARTÉE (une alcôve)", "cases": _salle(true)},
		{"nom": "ARCHE FINE (tablier d'une case)", "cases": _arche(1)},
		{"nom": "ARCHE ÉPAISSE (tablier de deux)", "cases": _arche(2)},
		{"nom": "COLONNE (un pilier seul)", "cases": _colonne()},
		{"nom": "TUILE SOLO (un cube sur le plat)", "cases": _solo(false)},
		{"nom": "SOLO QUI DÉPASSE d'un plat", "cases": _solo(true)},
		{"nom": "MARCHE (un gradin d'une case)", "cases": _marche()},
	]

	# ── CE QUE CHAQUE MOTIF LIVRE, EN PROPRE ────────────────────────────────────────────────────────
	var reference: Dictionary = _recolter(motifs[0]["cases"])
	print("── CE QUE CHAQUE MOTIF AJOUTE AU MASSIF NU ──")
	for m in motifs:
		var tout: Dictionary = _recolter(m["cases"])
		m["tuiles"] = tout
		m["propres"] = _moins(tout, reference)
		print("   %-34s %2d tuile(s) au total, %2d de plus que le massif nu"
			% [m["nom"], tout.size(), int((m["propres"] as Dictionary).size())])
	print("")

	# ── LES PAIRES QUE JORDAN A NOMMÉES ─────────────────────────────────────────────────────────────
	print("── LES PAIRES : « A montre-t-il déjà ce que fait B ? » ──")
	_comparer(motifs, "TUNNEL PERCÉ des deux côtés", "TUNNEL BOUCHÉ (cul-de-sac)")
	_comparer(motifs, "SALLE ÉCARTÉE (une alcôve)", "SALLE simple")
	_comparer(motifs, "SALLE simple", "SALLE ÉCARTÉE (une alcôve)")
	_comparer(motifs, "ARCHE ÉPAISSE (tablier de deux)", "ARCHE FINE (tablier d'une case)")
	_comparer(motifs, "ARCHE FINE (tablier d'une case)", "ARCHE ÉPAISSE (tablier de deux)")
	_comparer(motifs, "ARCHE FINE (tablier d'une case)", "COLONNE (un pilier seul)")
	_comparer(motifs, "COLONNE (un pilier seul)", "ARCHE FINE (tablier d'une case)")
	_comparer(motifs, "SOLO QUI DÉPASSE d'un plat", "TUILE SOLO (un cube sur le plat)")
	_comparer(motifs, "TUILE SOLO (un cube sur le plat)", "SOLO QUI DÉPASSE d'un plat")
	print("")

	# ── LE JEU MINIMAL : on ajoute dans l'ordre et l'on regarde qui apporte encore quelque chose ────
	print("── EN LES EMPILANT : qui apporte encore une tuile neuve ? ──")
	var cumul := {}
	for m in motifs:
		var neuves: Array = []
		for nom in (m["tuiles"] as Dictionary):
			if not cumul.has(nom):
				cumul[nom] = true
				neuves.append(nom)
		neuves.sort()
		print("   %-34s +%2d  → cumul %2d %s"
			% [m["nom"], neuves.size(), cumul.size(),
				"" if neuves.is_empty() else ("  " + ", ".join(PackedStringArray(neuves)))])
	print("")

	# ── QUI EST REDONDANT POUR DE BON ───────────────────────────────────────────────────────────────
	#
	# ⚠ **LE « +N » DE L'EMPILEMENT DÉPEND DE L'ORDRE, ET LE LIRE COMME UNE UTILITÉ EST UNE FAUTE.**
	# Un motif peut afficher « +1 » simplement parce qu'il passe avant celui qui le contient. La vraie
	# question est : si je retire CE motif et que je garde TOUS les autres, est-ce que je perds une
	# tuile ? C'est la seule formulation qui ne dépende pas de l'ordre.
	print("── EN RETIRANT CHAQUE MOTIF, TOUS LES AUTRES ÉTANT GARDÉS ──")
	for m in motifs:
		var sans := {}
		for autre in motifs:
			if autre["nom"] == m["nom"]:
				continue
			for nom in (autre["tuiles"] as Dictionary):
				sans[nom] = true
		var perdues: Dictionary = _moins(m["tuiles"], sans)
		if perdues.is_empty():
			print("   ○ %-34s REDONDANT — les autres le couvrent entièrement" % m["nom"])
		else:
			var liste: Array = perdues.keys()
			liste.sort()
			print("   ● %-34s INDISPENSABLE — seul à livrer %s"
				% [m["nom"], ", ".join(PackedStringArray(liste))])
	print("")

	# ── UN JEU SUFFISANT, choisi par le plus grand apport à chaque coup ─────────────────────────────
	#
	# ⚠ **UN CHOIX GLOUTON N'EST PAS PROUVÉ MINIMAL**, et le dire autrement serait mentir : couvrir un
	# ensemble par le moins de parties possible est un problème où le glouton ne garantit rien. Il
	# donne un jeu SUFFISANT et court, pas le plus court.
	print("── UN JEU SUFFISANT, pris au plus gros apport à chaque coup ──")
	var reste := {}
	for nom in cumul:
		reste[nom] = true
	var pris: Array = []
	while not reste.is_empty():
		var meilleur: Dictionary = {}
		var gain := -1
		for m in motifs:
			if pris.has(m["nom"]):
				continue
			var n := 0
			for nom in (m["tuiles"] as Dictionary):
				if reste.has(nom):
					n += 1
			if n > gain:
				gain = n
				meilleur = m
		if gain <= 0:
			break
		pris.append(meilleur["nom"])
		for nom in (meilleur["tuiles"] as Dictionary):
			reste.erase(nom)
		print("   %-34s +%2d  → il reste %d tuile(s) à couvrir"
			% [meilleur["nom"], gain, reste.size()])
	print("   → %d motifs sur %d suffisent à ces %d tuiles"
		% [pris.size(), motifs.size(), cumul.size()])

	print("\n⚠ Cette sonde dit ce qui est nécessaire à la COUVERTURE, jamais ce qui est beau.")
	quit(0)


func _comparer(motifs: Array, a: String, b: String) -> void:
	var ta: Dictionary = _trouver(motifs, a)["tuiles"]
	var tb: Dictionary = _trouver(motifs, b)["tuiles"]
	var manque: Dictionary = _moins(tb, ta)
	if manque.is_empty():
		print("   ✓ « %s » contient TOUT « %s »" % [a, b])
	else:
		var liste: Array = manque.keys()
		liste.sort()
		print("   ✗ « %s » ne donne pas %d tuile(s) de « %s » :" % [a, manque.size(), b])
		for nom in liste:
			print("        %s" % nom)


func _trouver(motifs: Array, nom: String) -> Dictionary:
	for m in motifs:
		if m["nom"] == nom:
			return m
	return {}


func _moins(a: Dictionary, b: Dictionary) -> Dictionary:
	var sortie := {}
	for k in a:
		if not b.has(k):
			sortie[k] = true
	return sortie


## LES TUILES QU'UNE OCCUPATION LIVRE — par les règles du modèle, jamais par une seconde description.
func _recolter(pleines: Dictionary) -> Dictionary:
	var plafond: int = MB.plafond_de(pleines)
	var sortie := {}
	# ⚠ Convention (A) : les huit cellules du sommet doivent être DANS le cube déclaré.
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


# ── LES MOTIFS ──────────────────────────────────────────────────────────────────────────────────────

func _massif() -> Dictionary:
	var p := {}
	for x in COTE:
		for y in SOL:
			for z in COTE:
				p[Vector3i(x, y, z)] = true
	return p


## Un boyau d'une case, percé de part en part ou arrêté avant le bord.
##
## ⚠ **LE TUNNEL BOUCHÉ S'ARRÊTE EN x = 6, PAS EN x = 7.** Un fond posé sur la dernière colonne serait
## lu par des sommets de BORD, que la convention (A) ne récolte pas : le motif n'aurait alors aucun
## fond, et la sonde conclurait « le percé contient le bouché » parce qu'on n'aurait pas modelé de fond.
func _tunnel(perce: bool) -> Dictionary:
	var p: Dictionary = _massif()
	var fin: int = COTE if perce else 6
	for x in range(0, fin):
		p.erase(Vector3i(x, 1, 4))
		p.erase(Vector3i(x, 2, 4))
	return p


## Une salle creusée. `ecartee` lui ajoute une alcôve d'une case sur un côté.
func _salle(ecartee: bool) -> Dictionary:
	var p: Dictionary = _massif()
	for x in range(2, 5):
		for y in range(1, 3):
			for z in range(2, 5):
				p.erase(Vector3i(x, y, z))
	if ecartee:
		p.erase(Vector3i(5, 1, 3))
		p.erase(Vector3i(5, 2, 3))
	return p


## Une arche posée SUR le massif : deux piles et un tablier d'épaisseur `tablier`.
func _arche(tablier: int) -> Dictionary:
	var p: Dictionary = _massif()
	for y in range(SOL, SOL + 2):
		p[Vector3i(2, y, 4)] = true
		p[Vector3i(5, y, 4)] = true
	for e in tablier:
		for x in range(2, 6):
			p[Vector3i(x, SOL + 2 + e, 4)] = true
	return p


## Un pilier seul, sans tablier — l'arche à qui l'on retire le pont.
func _colonne() -> Dictionary:
	var p: Dictionary = _massif()
	for y in range(SOL, SOL + 4):
		p[Vector3i(4, y, 4)] = true
	return p


## Une case seule posée sur le plat. `depassant` la met au bord d'un gradin, en surplomb du plat bas.
func _solo(depassant: bool) -> Dictionary:
	var p: Dictionary = _massif()
	if not depassant:
		p[Vector3i(4, SOL, 4)] = true
		return p
	# Un gradin : la moitié du massif monte d'une case, et le cube solo se pose sur son bord.
	for x in range(0, 5):
		for z in COTE:
			p[Vector3i(x, SOL, z)] = true
	p[Vector3i(4, SOL + 1, 4)] = true
	return p


## Un gradin d'une case — le décrochement le plus commun d'un paysage.
func _marche() -> Dictionary:
	var p: Dictionary = _massif()
	for x in range(0, 5):
		for z in COTE:
			p[Vector3i(x, SOL, z)] = true
	return p
