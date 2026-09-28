extends SceneTree

## SONDE — QUELS GESTES DE PAYSAGE COUVRENT LE PLUS DE TUILES ?
##
## ⚠ **LA STRATÉGIE EST DE JORDAN (26 septembre 2026)** : *« tu me cherches des formes qui sont à la
## fois évidentes pour l'artiste et couvrent une bonne partie des tuiles dont le système a besoin ; on
## itère, je te montre à chaque fois, tu les ajoutes au témoin ; et arrivé un moment on sera obligé de
## passer au bloc d'érosion, mais il sera petit car on n'a plus à assouvir toutes les diagonales
## puisqu'on les a interdites. »*
##
## ⚠ **LA CIBLE EST DONC 52, PAS 90.** Interdire les contacts diagonaux retire 38 tuiles du besoin :
## ce sont celles où deux cellules ne se touchent que par une arête, et dont la matière est pincée.
## Le témoin intuitif vise les 52 qui restent, et l'érosion ne portera que le reliquat.
##
## ⚠ **UN GESTE SE JUGE SUR DEUX CHOSES, ET LA SONDE N'EN MESURE QU'UNE.** Elle compte les tuiles qu'un
## motif livre ; elle ne dit pas s'il est évident à modeler. C'est pour ça que chaque motif porte un
## NOM DE PAYSAGE — falaise, corniche, cheminée, auvent — et pas une description de bits : si le nom ne
## se comprend pas d'un coup, le geste n'est pas évident, et aucun compteur ne le rattrapera.
##
## ⚠ **ET CHAQUE MOTIF EST VÉRIFIÉ SANS CONTACT DIAGONAL.** Un geste qui en contiendrait livrerait des
## tuiles que le peintre s'interdit désormais : il gonflerait la couverture avec des formes que
## personne ne posera. C'est mesuré par motif, pas supposé.
##
## ── LE DÉCOR COMMUN ─────────────────────────────────────────────────────────────────────────────────
##
## Un cube de COTE, massif sur les couches 0..SOL−1, ciel au-dessus. Les gestes CREUSÉS entament la
## roche, les gestes DRESSÉS se posent sur elle. ⚠ Le même décor pour tous : sinon l'on comparerait des
## contextes, pas des gestes — un sol de grotte et un sol de massif ne sont pas la même tuile.
##
## ⚠ **RÉCOLTE : convention (A), sommets INTÉRIEURS seulement**, comme le trancheur. Un sommet de bord
## lit des cellules hors du cube, que le modèle tient pour vides : il récolterait la face de sciage.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_gestes_de_paysage.gd

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const COTE := 11
## La roche monte jusqu'à SOL−1 ; au-dessus c'est le ciel. Assez épaisse pour qu'une grotte ait un
## plafond ET un sol sans toucher le bord du cube.
const SOL := 8

## ⚠ **LE JOURNAL DES COUPS — et il existe parce que Jordan n'a pas pu lire le catalogue sans lui.**
## *« je ne peux pas comprendre car pour chacune tu ne m'as pas dit l'épaisseur : une tuile (fine), ou
## large ? »* Un nom de geste dit l'INTENTION, jamais la DIMENSION — et c'est la dimension qui décide
## de la tuile. « Une bosse sur une paroi » de 1×2×3 et la même de 3×3×3 ne livrent pas les mêmes
## classes. Chaque `_poser` et chaque `_creuser` s'inscrit donc ici, avec sa taille et sa place, et le
## catalogue s'imprime en gestes REPRODUCTIBLES au lieu de formules.
var _ops: Array = []


func _initialize() -> void:
	print("=== LES GESTES DE PAYSAGE ===\n")
	print("décor : cube de %d, roche sur les couches 0..%d, ciel au-dessus" % [COTE, SOL - 1])
	print("cible : les %d tuiles SANS contact diagonal (les 38 autres sont interdites)\n"
		% _cible().size())

	var motifs: Array = _catalogue()
	var reference: Dictionary = _recolter(_massif())

	print("── CHAQUE GESTE, AVEC SES DIMENSIONS ──")
	print("   le décor : un massif de %d × %d × %d, ciel au-dessus
" % [COTE, SOL, COTE])
	for m in motifs:
		var cases: Dictionary = m["cases"]
		m["tuiles"] = _recolter(cases)
		m["diag"] = _contacts_diagonaux(cases)
		var propres: Dictionary = _moins(m["tuiles"], reference)
		print("   %s" % m["nom"])
		print("        %s" % _coups(m))
		print("        %d tuile(s), %d de plus que le sol nu%s"
			% [int((m["tuiles"] as Dictionary).size()), propres.size(),
				"" if int(m["diag"]) == 0 else ("   ⚠ %d contact(s) diagonal(aux)" % m["diag"])])
	print("")

	# ── CE QUE TOUT LE CATALOGUE COUVRE ─────────────────────────────────────────────────────────────
	var cible: Dictionary = _cible()
	var union := {}
	var hors_cible := {}
	for m in motifs:
		for nom in (m["tuiles"] as Dictionary):
			if cible.has(nom):
				union[nom] = true
			else:
				hors_cible[nom] = true
	# ── CE QUE LES FORMES SEULES COUVRENT ───────────────────────────────────────────────────────────
	#
	# ⚠ **C'EST LA MESURE QUI RÉPOND À LA QUESTION DE JORDAN**, et elle se pose en une ligne : si les
	# formes seules couvrent tout, le témoin peut être entièrement lisible ; sinon, on sait exactement
	# combien d'atomes il faudra glisser dedans, et lesquels.
	var par_formes := {}
	var par_atomes := {}
	for m in motifs:
		for nom in (m["tuiles"] as Dictionary):
			if not cible.has(nom):
				continue
			if m["quoi"] == "forme":
				par_formes[nom] = true
			else:
				par_atomes[nom] = true
	var formes: Array = motifs.filter(func(m): return m["quoi"] == "forme")
	print("── CE QUE LES FORMES SEULES COUVRENT ──")
	print("   %d formes reconnaissables, %d atomes"
		% [formes.size(), motifs.size() - formes.size()])
	print("   les FORMES seules : %d des %d tuiles visées" % [par_formes.size(), cible.size()])
	var que_les_atomes: Array = []
	for nom in par_atomes:
		if not par_formes.has(nom):
			que_les_atomes.append(nom)
	que_les_atomes.sort()
	print("   %d tuile(s) qu'AUCUNE forme n'atteint — il faudra un atome pour chacune :"
		% que_les_atomes.size())
	for nom in que_les_atomes:
		print("      %s" % nom)
	print("")

	print("── LA COUVERTURE DU CATALOGUE ENTIER ──")
	print("   %d des %d tuiles visées" % [union.size(), cible.size()])
	if not hors_cible.is_empty():
		print("   ⚠ et %d tuile(s) récoltée(s) HORS CIBLE — un motif contient une diagonale :"
			% hors_cible.size())
		var h: Array = hors_cible.keys()
		h.sort()
		print("      %s" % ", ".join(PackedStringArray(h)))
	var manquantes: Array = []
	for nom in cible:
		if not union.has(nom):
			manquantes.append(nom)
	manquantes.sort()
	print("   %d tuile(s) qu'AUCUN geste ne livre — c'est le travail du bloc d'érosion :"
		% manquantes.size())
	# ⚠ **ON DESSINE LA CONFIGURATION, PAS SEULEMENT SON NOM.** « mb_vrille_d_b2h2 » ne dit à personne
	# quoi modeler ; les deux couches de 2×2 le disent en trois lignes. C'est le seul format par lequel
	# une tuile manquante devient un geste faisable.
	for nom in manquantes:
		print("      %s" % nom)
		_dessiner(nom)
	print("")

	# ── L'ORDRE À SUIVRE : le plus gros apport d'abord ───────────────────────────────────────────────
	#
	# ⚠ **GLOUTON, DONC SUFFISANT ET NON MINIMAL** — le dire autrement serait mentir : couvrir un
	# ensemble par le moins de parties possible est un problème où le glouton ne garantit rien.
	print("── DANS QUEL ORDRE LES AJOUTER (le plus gros apport à chaque coup) ──")
	var reste := {}
	for nom in union:
		reste[nom] = true
	var pris: Array = []
	while not reste.is_empty():
		var meilleur: Dictionary = {}
		var gain := 0
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
		var neuves: Array = []
		for nom in (meilleur["tuiles"] as Dictionary):
			if reste.has(nom):
				neuves.append(nom)
				reste.erase(nom)
		neuves.sort()
		print("   %s   +%d → reste %d" % [meilleur["nom"], gain, reste.size()])
		# ⚠ **LA LISTE DE TRAVAIL PORTE LES DIMENSIONS, sinon elle n'est pas une liste de travail.**
		# C'est la remarque de Jordan : un nom de geste ne dit pas s'il est fin ou large, et c'est
		# l'épaisseur qui décide de la classe.
		print("        %s" % _coups(meilleur))
		print("        %s" % ", ".join(PackedStringArray(neuves)))
	print("   → %d gestes sur %d suffisent aux %d tuiles atteintes"
		% [pris.size(), motifs.size(), union.size()])
	print("")

	# ── LE CONTRÔLE : le jeu retenu couvre-t-il VRAIMENT chaque geste écarté ? ──────────────────────
	#
	# ⚠ **« PAR CONSTRUCTION » N'EST PAS UNE MESURE, et ce projet a déjà payé de le croire.** Le
	# glouton s'arrête quand son reste est vide, ce qui PROUVE qu'il couvre l'union — mais seulement
	# si l'union a été bâtie sur la même base que les gestes, et si aucun geste ne livre quelque chose
	# hors cible. Les deux se vérifient en dix lignes ; les supposer, c'est la faute que la charte §6
	# nomme trois fois. Si un geste écarté portait une tuile absente du jeu retenu, l'écarter serait
	# une PERTE, et personne ne le saurait.
	print("── CE QUE LES GESTES ÉCARTÉS AURAIENT APPORTÉ ──")
	var retenu := {}
	for nom in pris:
		for m in motifs:
			if m["nom"] == nom:
				for t in (m["tuiles"] as Dictionary):
					retenu[t] = true
	var perdu := 0
	for m in motifs:
		if pris.has(m["nom"]):
			continue
		var hors: Dictionary = _moins(m["tuiles"], retenu)
		if hors.is_empty():
			continue
		perdu += 1
		var l: Array = hors.keys()
		l.sort()
		print("   ⚠ %s porte %d tuile(s) que le jeu retenu n'a pas : %s"
			% [m["nom"], hors.size(), ", ".join(PackedStringArray(l))])
	if perdu == 0:
		print("   ✓ aucun des %d gestes écartés ne porte une tuile absente du jeu retenu."
			% (motifs.size() - pris.size()))
		print("     Les écarter ne coûte AUCUNE classe — seulement de la variété (charte §2).")

	print("\n⚠ Cette sonde compte les tuiles ; elle ne dit pas si un geste est évident à modeler.")
	quit(0)


## LES TUILES VISÉES : celles qui n'ont aucun contact diagonal, dans leurs deux contextes possibles.
func _cible() -> Dictionary:
	var sortie := {}
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits):
			continue
		if not MB.sans_contact_diagonal(bits):
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


## COMBIEN DE SOMMETS PORTENT UN CONTACT DIAGONAL. ⚠ Un geste qui en a livre des tuiles que le peintre
## s'interdit : il gonflerait la couverture avec des formes que personne ne posera.
func _contacts_diagonaux(pleines: Dictionary) -> int:
	var n := 0
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var bits: int = MB.bits(pleines, Vector3i(x, y, z))
				if MB.porte_une_surface(bits) and not MB.sans_contact_diagonal(bits):
					n += 1
	return n


func _moins(a: Dictionary, b: Dictionary) -> Dictionary:
	var sortie := {}
	for k in a:
		if not b.has(k):
			sortie[k] = true
	return sortie


# ── LE DÉCOR ET LES GESTES ──────────────────────────────────────────────────────────────────────────

## ⚠ Le massif REMET LE JOURNAL À ZÉRO : chaque geste commence par lui, donc chaque geste repart d'une
## page blanche. Oublier ce nettoyage ferait traîner les coups du geste précédent dans le suivant.
func _massif() -> Dictionary:
	_ops = []
	var p := {}
	for x in COTE:
		for y in SOL:
			for z in COTE:
				p[Vector3i(x, y, z)] = true
	return p


func _creuser(p: Dictionary, a: Vector3i, b: Vector3i) -> void:
	_ops.append({"quoi": "creusé", "a": a, "t": b - a + Vector3i.ONE})
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				p.erase(Vector3i(x, y, z))


func _poser(p: Dictionary, a: Vector3i, b: Vector3i) -> void:
	_ops.append({"quoi": "posé  ", "a": a, "t": b - a + Vector3i.ONE})
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				p[Vector3i(x, y, z)] = true


## ⚠ **CHAQUE NOM DOIT SE COMPRENDRE D'UN COUP.** C'est le seul critère d'« évidence » que cette sonde
## porte, et il est humain : si je dois expliquer le geste, il n'est pas évident.
func _catalogue() -> Array:
	var sortie: Array = []

	# ── LES GESTES DE SURFACE ───────────────────────────────────────────────────────────────────────
	var p: Dictionary = _massif()
	_creuser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, COTE - 1))
	_ajouter(sortie, "LA FALAISE (un plat haut, un plat bas)", p)

	p = _massif()
	for k in 3:
		_creuser(p, Vector3i(0, SOL - 1 - k, 0), Vector3i(2 + k * 2, SOL - 1 - k, COTE - 1))
	_ajouter(sortie, "L'ESCALIER (trois gradins)", p)

	p = _massif()
	for k in range(0, 7):
		_creuser(p, Vector3i(0, SOL - 1 - k, 0), Vector3i(k, SOL - 1 - k, COTE - 1))
	_ajouter(sortie, "LA RAMPE (une case de chute par case)", p)

	p = _massif()
	_poser(p, Vector3i(4, SOL, 4), Vector3i(6, SOL + 1, 6))
	_ajouter(sortie, "LA BUTTE (un monticule posé)", p)

	p = _massif()
	_poser(p, Vector3i(2, SOL, 5), Vector3i(8, SOL + 1, 5))
	_ajouter(sortie, "LA CRÊTE (une arête d'une case de large)", p)

	p = _massif()
	_poser(p, Vector3i(2, SOL, 5), Vector3i(8, SOL + 2, 5))
	_creuser(p, Vector3i(4, SOL + 1, 5), Vector3i(6, SOL + 2, 5))
	_ajouter(sortie, "LE COL (une crête échancrée)", p)

	p = _massif()
	_poser(p, Vector3i(5, SOL, 2), Vector3i(6, SOL + 2, 8))
	_poser(p, Vector3i(5, SOL, 5), Vector3i(8, SOL + 2, 6))
	_ajouter(sortie, "L'ÉPERON (un contrefort en T)", p)

	p = _massif()
	_creuser(p, Vector3i(4, SOL - 2, 4), Vector3i(6, SOL - 1, 6))
	_ajouter(sortie, "LA CUVETTE (un creux dans le plat)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, COTE - 1))
	_creuser(p, Vector3i(6, SOL - 1, 4), Vector3i(8, SOL - 1, 6))
	_ajouter(sortie, "L'ENTAILLE (une encoche dans la falaise)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 2, 0), Vector3i(5, SOL - 1, COTE - 1))
	_poser(p, Vector3i(3, SOL - 2, 3), Vector3i(5, SOL - 2, 7))
	_ajouter(sortie, "LA CORNICHE (une banquette au pied de la falaise)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 3, 0), Vector3i(5, SOL - 1, COTE - 1))
	_poser(p, Vector3i(3, SOL - 1, 3), Vector3i(5, SOL - 1, 7))
	_ajouter(sortie, "L'AUVENT (un surplomb au-dessus du vide)", p)

	p = _massif()
	_poser(p, Vector3i(4, SOL, 4), Vector3i(4, SOL + 3, 4))
	_ajouter(sortie, "L'AIGUILLE (un pilier seul dressé)", p)

	# ⚠ **IL PORTAIT DEUX CONTACTS DIAGONAUX, ET LA SONDE L'A DIT** : le caillou était posé un étage
	# au-dessus du plat bas et ne touchait la falaise que par une arête. Il livrait alors deux tuiles
	# HORS CIBLE (`mb_biais_b2h1_a` et `_c`) — des formes que le peintre s'interdit. Posé sur le plat
	# HAUT, au ras du vide, il touche par une face et le geste reste le même à l'œil.
	p = _massif()
	_creuser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, COTE - 1))
	_poser(p, Vector3i(6, SOL, 5), Vector3i(6, SOL, 5))
	_ajouter(sortie, "LE CAILLOU AU BORD (une case au ras de la falaise)", p)

	# ── LES GESTES CREUSÉS ──────────────────────────────────────────────────────────────────────────
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_ajouter(sortie, "LA SALLE (un vide dans la roche)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_creuser(p, Vector3i(8, 2, 4), Vector3i(8, 3, 6))
	_ajouter(sortie, "L'ALCÔVE (une salle écartée d'un côté)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(4, 2, 4), Vector3i(4, 4, 4))
	_ajouter(sortie, "LE PILIER DE SALLE (du sol au plafond)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(2, 4, 2), Vector3i(7, 4, 3))
	_poser(p, Vector3i(2, 4, 6), Vector3i(7, 4, 7))
	_ajouter(sortie, "LA VOÛTE (un plafond de salle qui remonte au centre)", p)

	p = _massif()
	_creuser(p, Vector3i(0, 2, 4), Vector3i(COTE - 1, 3, 6))
	_ajouter(sortie, "LE TUNNEL PERCÉ", p)

	p = _massif()
	_creuser(p, Vector3i(0, 2, 4), Vector3i(7, 3, 6))
	_ajouter(sortie, "LE TUNNEL BOUCHÉ (un cul-de-sac)", p)

	p = _massif()
	_creuser(p, Vector3i(0, 2, 4), Vector3i(5, 3, 6))
	_creuser(p, Vector3i(4, 2, 6), Vector3i(5, 3, COTE - 1))
	_ajouter(sortie, "LE TUNNEL COUDÉ (un virage)", p)

	p = _massif()
	_creuser(p, Vector3i(4, 2, 4), Vector3i(6, SOL - 1, 6))
	_ajouter(sortie, "LE PUITS (un trou vertical ouvert au ciel)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_creuser(p, Vector3i(4, 5, 4), Vector3i(5, SOL - 1, 5))
	_ajouter(sortie, "LA CHEMINÉE (une salle ouverte au ciel par un conduit)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 4, 0), Vector3i(4, SOL - 1, COTE - 1))
	_creuser(p, Vector3i(5, SOL - 4, 4), Vector3i(8, SOL - 3, 6))
	_ajouter(sortie, "LA BOUCHE DE GROTTE (un tunnel qui s'ouvre en falaise)", p)

	# ── LES GESTES DRESSÉS AU-DESSUS DU VIDE ────────────────────────────────────────────────────────
	p = _massif()
	_creuser(p, Vector3i(3, SOL - 3, 0), Vector3i(6, SOL - 1, COTE - 1))
	_poser(p, Vector3i(3, SOL - 1, 4), Vector3i(6, SOL - 1, 6))
	_ajouter(sortie, "LE PONT (un tablier qui franchit un canyon)", p)

	p = _massif()
	_creuser(p, Vector3i(3, SOL - 3, 0), Vector3i(6, SOL - 1, COTE - 1))
	_poser(p, Vector3i(3, SOL - 2, 4), Vector3i(6, SOL - 1, 6))
	_ajouter(sortie, "L'ARCHE ÉPAISSE (un tablier de deux cases)", p)

	p = _massif()
	_creuser(p, Vector3i(3, SOL - 3, 0), Vector3i(6, SOL - 1, COTE - 1))
	_poser(p, Vector3i(4, SOL - 3, 4), Vector3i(5, SOL - 1, 6))
	_ajouter(sortie, "LA PILE DANS LE CANYON (un socle qui monte du fond)", p)

	# ── LES GESTES DE MUR ───────────────────────────────────────────────────────────────────────────
	p = _massif()
	_creuser(p, Vector3i(0, SOL - 4, 0), Vector3i(4, SOL - 1, COTE - 1))
	_creuser(p, Vector3i(5, SOL - 3, 4), Vector3i(5, SOL - 2, 6))
	_ajouter(sortie, "LE RENFONCEMENT (une niche dans une paroi)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 4, 0), Vector3i(4, SOL - 1, COTE - 1))
	_poser(p, Vector3i(4, SOL - 3, 4), Vector3i(4, SOL - 2, 6))
	_ajouter(sortie, "LE BOSSAGE (une bosse sur une paroi)", p)

	# ── LES ANGLES ET LES TORSIONS ──────────────────────────────────────────────────────────────────
	#
	# ⚠ **ILS ONT ÉTÉ AJOUTÉS PARCE QUE LA MESURE A DIT OÙ ÇA MANQUAIT, pas par inspiration.** Le
	# premier catalogue couvrait 33 des 52, et les 19 absentes formaient un bloc d'une netteté rare :
	# **8 vrilles, 3 tétras, et des équerres**. Toutes sont des configurations où la forme TOURNE en
	# trois dimensions — or tous mes gestes étaient EXTRUDÉS : une falaise tirée selon z, un tunnel
	# tiré selon x. Un catalogue de profils ne peut pas livrer un angle, si long soit-il.
	#
	# ⚠ Et la lecture des bits dit exactement quel geste les fabrique : `tetra` est **un L de trois
	# cases avec une quatrième posée sur son COIN** ; `vrille` est le même L avec la quatrième posée
	# sur son BOUT. Autrement dit : une marche d'angle, et un escalier qui tourne.
	p = _massif()
	_creuser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, COTE - 1))
	_creuser(p, Vector3i(6, SOL - 1, 0), Vector3i(COTE - 1, SOL - 1, 5))
	_ajouter(sortie, "LE PROMONTOIRE (la falaise qui tourne un angle saillant)", p)

	p = _massif()
	_creuser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, COTE - 1))
	_poser(p, Vector3i(0, SOL - 1, 0), Vector3i(5, SOL - 1, 5))
	_ajouter(sortie, "LE RECOIN (la falaise qui tourne un angle rentrant)", p)

	# L'escalier qui tourne : chaque marche monte d'une case ET change de direction.
	p = _massif()
	_poser(p, Vector3i(4, SOL, 4), Vector3i(4, SOL, 4))
	_poser(p, Vector3i(5, SOL, 4), Vector3i(5, SOL + 1, 4))
	_poser(p, Vector3i(5, SOL, 5), Vector3i(5, SOL + 2, 5))
	_poser(p, Vector3i(4, SOL, 5), Vector3i(4, SOL + 3, 5))
	_ajouter(sortie, "L'ESCALIER QUI TOURNE (des marches qui montent en virant)", p)

	# La marche d'angle : un gradin en L, la quatrième case posée sur le COIN du L.
	p = _massif()
	_poser(p, Vector3i(4, SOL, 4), Vector3i(6, SOL, 4))
	_poser(p, Vector3i(4, SOL, 5), Vector3i(4, SOL, 6))
	_poser(p, Vector3i(4, SOL + 1, 4), Vector3i(4, SOL + 1, 4))
	_ajouter(sortie, "LA MARCHE D'ANGLE (un gradin en L, surmonté au coin)", p)

	p = _massif()
	for k in 3:
		_poser(p, Vector3i(3 + k, SOL + k, 3 + k), Vector3i(7 - k, SOL + k, 7 - k))
	_ajouter(sortie, "LA PYRAMIDE À GRADINS (chaque étage rentre d'une case)", p)

	# ── LES MÊMES GESTES, MAIS SOUS ROCHE ───────────────────────────────────────────────────────────
	#
	# ⚠ **UN SOL DE GROTTE N'EST PAS UN SOL DE MASSIF — c'est toute la raison du modèle ORIENTÉ.** Les
	# manquantes comptent `mb_coin_b1h0` et `mb_equerre_b3h0` SANS suffixe : ce sont les versions
	# d'INTÉRIEUR, et aucun geste de surface ne les livrera jamais, si nombreux soient-ils.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(4, 2, 4), Vector3i(4, 2, 4))
	_ajouter(sortie, "LE BLOC TOMBÉ (une case seule sur le sol d'une salle)", p)

	# ⚠ **LES BRAS DU L DOIVENT MESURER UNE SEULE CASE, ET MA PREMIÈRE VERSION EN METTAIT TROIS.** Une
	# pièce lit un voisinage de 2×2×2 : un bras de trois cases met son BOUT hors de ce voisinage, et le
	# sommet ne voit plus qu'un L plat de trois cases — une `equerre`, jamais une `vrille`. Le geste
	# paraissait juste et ne pouvait structurellement pas livrer ce qu'on lui demandait.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 2, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_ajouter(sortie, "LE SOCLE EN L (trois cases sur le sol d'une salle)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 2, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_poser(p, Vector3i(3, 3, 3), Vector3i(3, 3, 3))
	_ajouter(sortie, "LE SOCLE EN L, CASE SUR LE COIN (un tétra)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 2, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_poser(p, Vector3i(4, 3, 3), Vector3i(4, 3, 3))
	_ajouter(sortie, "LE SOCLE EN L, CASE SUR UN BOUT (une vrille)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 2, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_poser(p, Vector3i(3, 3, 4), Vector3i(3, 3, 4))
	_ajouter(sortie, "LE SOCLE EN L, CASE SUR L'AUTRE BOUT (la vrille miroir)", p)

	# ⚠ Les mêmes gestes RETOURNÉS : `b1h3` est la forme suspendue au plafond, et aucun geste posé sur
	# un sol ne la livrera jamais — le modèle est ORIENTÉ, le haut et le bas ne sont pas échangeables.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 4, 3), Vector3i(4, 4, 3))
	_poser(p, Vector3i(3, 4, 4), Vector3i(3, 4, 4))
	_poser(p, Vector3i(4, 3, 3), Vector3i(4, 3, 3))
	_ajouter(sortie, "LA CONSOLE EN L AU PLAFOND, CASE SOUS UN BOUT", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 4, 3), Vector3i(4, 4, 3))
	_poser(p, Vector3i(3, 4, 4), Vector3i(3, 4, 4))
	_poser(p, Vector3i(3, 3, 4), Vector3i(3, 3, 4))
	_ajouter(sortie, "LA CONSOLE EN L AU PLAFOND, CASE SOUS L'AUTRE BOUT", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 4, 3), Vector3i(4, 4, 3))
	_poser(p, Vector3i(3, 4, 4), Vector3i(3, 4, 4))
	_poser(p, Vector3i(3, 3, 3), Vector3i(3, 3, 3))
	_ajouter(sortie, "LA CONSOLE EN L AU PLAFOND, CASE SOUS LE COIN", p)

	# ⚠ La vrille COUCHÉE (`b2h2`) : le même escalier, mais qui tourne autour d'un axe HORIZONTAL.
	# Deux cases en bas, deux en haut — c'est une marche adossée à une paroi qui se décale en montant.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(3, 3, 3))
	_poser(p, Vector3i(4, 2, 3), Vector3i(4, 2, 3))
	_poser(p, Vector3i(3, 3, 4), Vector3i(3, 3, 4))
	_ajouter(sortie, "LA MARCHE QUI SE DÉCALE EN MONTANT (une vrille couchée)", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(3, 3, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_poser(p, Vector3i(4, 3, 3), Vector3i(4, 3, 3))
	_ajouter(sortie, "LA MARCHE QUI SE DÉCALE, MIROIR", p)

	# ⚠ **LES MÊMES GESTES, MAIS AU GRAND JOUR.** Deux vrilles manquaient encore, et il ne leur
	# manquait rien d'autre que le CIEL : `_dehors` n'est pas une autre forme, c'est la même posée là
	# où rien ne la coiffe. Un catalogue tout entier sculpté sous roche ne livrera jamais les variantes
	# d'air libre, si complet soit-il — c'est la définition même du modèle à deux contextes.
	p = _massif()
	_poser(p, Vector3i(3, SOL, 3), Vector3i(4, SOL, 3))
	_poser(p, Vector3i(3, SOL, 4), Vector3i(3, SOL, 4))
	_poser(p, Vector3i(4, SOL + 1, 3), Vector3i(4, SOL + 1, 3))
	_ajouter(sortie, "LE SOCLE EN L AU GRAND JOUR, CASE SUR UN BOUT", p)

	p = _massif()
	_poser(p, Vector3i(3, SOL, 3), Vector3i(4, SOL, 3))
	_poser(p, Vector3i(3, SOL, 4), Vector3i(3, SOL, 4))
	_poser(p, Vector3i(3, SOL + 1, 4), Vector3i(3, SOL + 1, 4))
	_ajouter(sortie, "LE SOCLE EN L AU GRAND JOUR, AUTRE BOUT (miroir)", p)

	# ⚠ Un muret de deux cases de long et deux de haut, avec UNE case posée à son pied : c'est la
	# lecture directe du dessin de `mb_equerre_creuse_b3h2` — trois cases en bas dont une écartée,
	# deux au-dessus. Les deux sens existent, et ce sont deux tuiles distinctes.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 3, 3))
	_poser(p, Vector3i(4, 2, 4), Vector3i(4, 2, 4))
	_ajouter(sortie, "LE MURET AVEC UNE MARCHE À SON PIED", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(3, 2, 3), Vector3i(4, 3, 3))
	_poser(p, Vector3i(3, 2, 4), Vector3i(3, 2, 4))
	_ajouter(sortie, "LE MURET AVEC UNE MARCHE, AUTRE CÔTÉ", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_creuser(p, Vector3i(2, 5, 2), Vector3i(4, 5, 4))
	_ajouter(sortie, "L'ANGLE DE PLAFOND RELEVÉ (un coin de salle qui monte)", p)

	# ── LES FORMES CHERCHÉES EXPRÈS POUR LES VRILLES ────────────────────────────────────────────────
	#
	# ⚠ **ON NE CHERCHE PAS UNE FORME AU HASARD : ON LA CHERCHE POUR UNE TUILE NOMMÉE.** Les 35 formes
	# reconnaissables du catalogue couvrent 38 des 52, et les 12 absentes sont presque toutes des
	# VRILLES. Or la vrille est une hélice — un escalier qui monte en tournant. Le nom du paysage
	# existe donc, et il s'appelle un colimaçon. Si ces formes-là les livrent, aucune vrille n'aura
	# besoin d'un atome ; si elles ne les livrent pas, c'est que l'hélice n'a pas de forme de paysage
	# du tout, et il faudra le dire à l'artiste plutôt que de la lui cacher.
	#
	# Quatre marches autour d'un noyau de 2 × 2, chacune montant d'une case : c'est la plus petite
	# hélice qui existe, et elle tient dans le voisinage qu'une pièce lit.
	for lieu in [{"nom": "en grotte", "y": 2}, {"nom": "au grand jour", "y": SOL}]:
		for sens in [1, -1]:
			p = _massif()
			if lieu["y"] == 2:
				_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
			var y0: int = lieu["y"]
			var z0: int = 4
			var z1: int = 4 + sens
			_poser(p, Vector3i(4, y0, z0), Vector3i(4, y0, z0))
			_poser(p, Vector3i(5, y0, z0), Vector3i(5, y0 + 1, z0))
			_poser(p, Vector3i(5, y0, z1), Vector3i(5, y0 + 2, z1))
			_poser(p, Vector3i(4, y0, z1), Vector3i(4, y0 + 3, z1))
			_ajouter(sortie, "L'ESCALIER EN COLIMAÇON %s%s"
				% [lieu["nom"], "" if sens > 0 else " (l'autre sens)"], p)

	# ⚠ La même hélice SUSPENDUE : `b1h3` n'est pas une autre forme, c'est celle-ci à l'envers, et
	# aucun escalier posé sur un sol ne la livrera jamais.
	for sens in [1, -1]:
		p = _massif()
		_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
		var z0: int = 4
		var z1: int = 4 + sens
		_poser(p, Vector3i(4, 4, z0), Vector3i(4, 4, z0))
		_poser(p, Vector3i(5, 3, z0), Vector3i(5, 4, z0))
		_poser(p, Vector3i(5, 2, z1), Vector3i(5, 4, z1))
		_poser(p, Vector3i(4, 2, z1), Vector3i(4, 4, z1))
		_ajouter(sortie, "LA VIS SUSPENDUE AU PLAFOND%s"
			% ("" if sens > 0 else " (l'autre sens)"), p)

	# ⚠ Les jumelles d'INTÉRIEUR de deux formes qui n'existaient qu'au grand jour. Le modèle est
	# orienté : un gradin de grotte et un gradin de massif sont deux tuiles.
	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(4, 2, 4), Vector3i(6, 2, 4))
	_poser(p, Vector3i(4, 2, 5), Vector3i(4, 2, 6))
	_poser(p, Vector3i(4, 3, 4), Vector3i(4, 3, 4))
	_ajouter(sortie, "LA MARCHE D'ANGLE EN GROTTE", p)

	p = _massif()
	_creuser(p, Vector3i(2, 2, 2), Vector3i(7, 4, 7))
	_poser(p, Vector3i(2, 2, 2), Vector3i(7, 2, 2))
	_poser(p, Vector3i(2, 2, 3), Vector3i(2, 2, 7))
	_ajouter(sortie, "LA BANQUETTE EN L AU PIED DES PAROIS", p)

	return sortie


## LE DESSIN D'UNE CONFIGURATION : ses deux couches de 2×2, vues de dessus.
##
## ⚠ Les huit cellules d'un sommet sont `v + COINS[t]` avec `t = x + 2y + 4z` : le bit `y` sépare donc
## la couche BASSE de la HAUTE, et `x`/`z` placent la case dans le carré. On lit le dessin comme une
## carte — x vers la droite, z vers le bas.
func _dessiner(nom: String) -> void:
	var nu: String = MB.nom_nu(nom)
	var bits := -1
	for c in MB.classes():
		if c["nom"] == nu:
			bits = c["bits"]
			break
	if bits < 0:
		return
	print("         couche BASSE      couche HAUTE")
	for z in 2:
		var ligne := "           "
		for y in 2:
			for x in 2:
				var t: int = x + 2 * y + 4 * z
				ligne += ("#" if (bits & (1 << t)) else ".") + " "
			ligne += "     " if y == 0 else ""
		print(ligne)


## Range un geste avec le journal des coups qui l'ont fait.
func _ajouter(sortie: Array, nom: String, cases: Dictionary) -> void:
	sortie.append({"nom": nom, "cases": cases, "ops": _ops.duplicate(true),
		"quoi": "atome" if _est_un_atome(nom) else "forme"})


## ── GESTE, ATOME, FORME — trois mots, et il en manquait un ─────────────────────────────────────────
##
## ⚠ **JORDAN, 26 septembre 2026** : *« il y a une sous-catégorie des gestes que je te demande de
## nommer, qui sont des formes qui couvrent une partie des tuiles qu'un geste atteint toutes ; il faut
## trouver le bon compromis entre gestes et formes montrées. »* Il avait raison de le demander : je
## traitais tout le catalogue comme une seule espèce, et le placeur a rendu un cube blanc.
##
##   • un **ATOME** est le plus petit arrangement qui produit une classe. C'est un fait du MODÈLE. Il
##     est efficace — un seul atome peut livrer onze tuiles — et il ne ressemble à rien ;
##   • une **FORME** est un objet de paysage qu'on reconnaît : une arche, un pont, une cheminée, une
##     bouche de grotte. C'est un fait de l'ŒIL. Elle livre MOINS de tuiles par unité, puisqu'elle
##     n'atteint qu'une partie de ce qu'un atome atteint en entier — d'où le fait qu'il en faille
##     DAVANTAGE, comme Jordan le pressentait.
##
## ⚠ **ET LE BON OBJECTIF N'EST PAS LE MOINS DE COUPS POSSIBLE.** Un témoin sert à MONTRER à l'artiste
## ce que le système attend ; couvrir sans montrer, c'est le défaut que la charte §2 nomme déjà
## (« 90/90 et un socle en dentelle »). On couvre donc avec des FORMES, et l'on ne descend aux atomes
## que pour ce qu'aucune forme n'atteint.
##
## ⚠ Ce classement est ÉCRIT À LA MAIN, et c'est assumé : « reconnaissable » n'est pas mesurable. Le
## critère est celui du nom — si le mot ne fait pas voir la chose d'un coup, c'est un atome.
func _est_un_atome(nom: String) -> bool:
	for marque in ["SOCLE EN L", "CONSOLE EN L", "MURET AVEC UNE MARCHE", "MURET AVEC UNE MARCHE,",
			"MARCHE QUI SE DÉCALE"]:
		if nom.contains(marque):
			return true
	return false


## Les coups d'un geste, en clair. ⚠ **La TAILLE d'abord, la place ensuite** : c'est l'épaisseur qui
## décide de la classe, la position ne fait que placer le geste dans le décor.
func _coups(m: Dictionary) -> String:
	var bouts: Array = []
	for o in (m["ops"] as Array):
		var t: Vector3i = o["t"]
		var a: Vector3i = o["a"]
		bouts.append("%s %d×%d×%d en (%d,%d,%d)"
			% [o["quoi"], t.x, t.y, t.z, a.x, a.y, a.z])
	return "  ·  ".join(PackedStringArray(bouts))
