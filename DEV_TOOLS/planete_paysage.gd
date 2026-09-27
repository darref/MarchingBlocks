extends SceneTree

## LA PLANÈTE PAYSAGE — un témoin bâti avec des FORMES qu'on reconnaît, pas avec des atomes
##
## ⚠ **JORDAN, 26 septembre 2026, corrigeant le placeur précédent** : *« tu as encore trop optimisé, il
## faut que l'arche soit visible comme une arche ; il ne s'agit pas de produire le nombre de gestes
## minimum. »* Puis, choisissant : *« l'arche, le pont, la bouche de grotte, la cheminée, l'auvent, et
## tout ce qu'on voit d'autre dans la nature sans en faire trop non plus. »*
##
## ⚠ **L'OBJECTIF N'EST PAS LA COUVERTURE MINIMALE, ET C'EST TOUT LE SUJET.** Le placeur glouton avait
## rendu 50 tuiles sur 50 en dix coups — et un cube blanc, dont toute la substance était enfermée dans
## une cavité qu'on ne pouvait même pas voir. Un témoin sert à MONTRER à l'artiste ce que le système
## attend ; couvrir sans montrer, c'est la faute que la charte §2 nomme déjà (« 90/90 et un socle en
## dentelle »). On bâtit donc un PAYSAGE, et la couverture se mesure ensuite.
##
## ── LES DEUX ESPÈCES, ET POURQUOI IL FAUT LES DEUX ──────────────────────────────────────────────────
##
##   • une **FORME** est un objet qu'on nomme d'un coup — une arche, un pont, une cheminée. Elle livre
##     peu de tuiles pour beaucoup de cases, et c'est elle qui parle à l'artiste ;
##   • un **ATOME** est le plus petit arrangement qui produit une classe. Il livre beaucoup pour rien,
##     et il ne ressemble à rien.
##
## ⚠ **MESURÉ (`sonde_gestes_de_paysage.gd`) : 43 formes couvrent 41 des 52 tuiles ; 9 résistent** — les
## huit vrilles et le tétra suspendu. On couvre donc avec des formes, et l'on ne descend aux atomes que
## pour ce qu'aucune forme ne porte. Les cacher serait pire que les montrer : l'artiste doit savoir que
## le modèle lui demande une hélice.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/planete_paysage.gd -- --glb=D:/UnderMend/ART/planete_paysage.glb

const MB := preload("res://addons/undermend/marching_blocks.gd")

const COTE := 12
## La roche de base : les couches 0 à SOCLE−1 sont pleines partout.
const SOCLE := 6

var _p := {}
var _glb := ""
## ⚠ **`--ao` PEINT LA LÉGENDE PAR L'OCCLUSION AU LIEU DE « ROCHE AU-DESSUS » (Jordan, 26 septembre
## 2026).** La charte §2 a DÉJÀ écarté l'occlusion du ciel — mais comme critère de CONTEXTE, celui qui
## décide quelle tuile est récoltée : mesuré, **11 % des sommets changent d'avis** entre un bloc de 7³
## et le même volume enrobé de roche, et l'artiste sculpterait alors des tuiles que le pinceau ne
## poserait jamais là. Pour un critère de POSE, cette dérive est rédhibitoire.
##
## ⚠ **MAIS LA LÉGENDE NE DÉCIDE RIEN — ELLE INFORME**, et une légende n'a pas besoin d'être stable
## d'un bloc à l'autre : elle a besoin d'être JUSTE SOUS L'ŒIL. Le reproche fait à l'occlusion ne
## s'applique donc pas ici, et c'est ce qui rend la question de Jordan légitime. Cette option existe
## pour la trancher à l'image, jamais au raisonnement.
var _ao := false
var _journal: Array = []
## `--couches` imprime l'occupation au format de `BlocsMaitres.BLOCS`. ⚠ C'est ainsi que le bloc unique
## du greffon est produit : il n'est pas réécrit à la main dans `blocs_maitres.gd`, il est COLLÉ depuis
## cette sortie — le même geste que pour la grille du finisseur, et pour la même raison.
var _couches := false


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--glb="):
			_glb = option.substr("--glb=".length())
		if option == "--ao":
			_ao = true
		if option == "--couches":
			_couches = true

	print("=== LA PLANÈTE PAYSAGE ===\n")
	print("cible : %d tuiles sans contact diagonal\n" % _cible().size())

	_batir()

	print("── CE QUE CHAQUE FORME APPORTE ──")
	var vues := {}
	var cases := 0
	for etape in _journal:
		var neuves: Array = []
		for nom in (etape["tuiles"] as Dictionary):
			if not vues.has(nom):
				vues[nom] = true
				neuves.append(nom)
		neuves.sort()
		print("   %-36s %4d cases (+%d)  +%d tuile(s)%s"
			% [etape["nom"], etape["cases"], etape["cases"] - cases, neuves.size(),
				"" if int(etape["diag"]) == 0 else "   ⚠ %d DIAGONALE(S)" % etape["diag"]])
		if not neuves.is_empty():
			print("        %s" % ", ".join(PackedStringArray(neuves)))
		cases = etape["cases"]
	print("")

	_reparer()
	_finir()
	_bilan()
	if _couches:
		_imprimer_les_couches()
	if _glb != "":
		print("")
		_exporter(_p, _glb)
	print("\n⚠ Ce fichier se juge à l'œil : aucun compteur ne dit si ça ressemble à un paysage.")
	quit(0)


## ⚠ **ON MESURE APRÈS CHAQUE FORME, ET PAS SEULEMENT À LA FIN.** Deux formes voisines créent des
## configurations à leur jonction : parfois une classe de plus, parfois un contact diagonal — celui que
## le peintre s'interdit. Un bilan pris seulement à la fin dirait QU'IL y en a, jamais LAQUELLE les a
## faits, et il faudrait tout défaire pour le savoir.
func _etape(nom: String) -> void:
	_journal.append({"nom": nom, "cases": _p.size(), "tuiles": _recolter(_p),
		"diag": _contacts_diagonaux(_p)})


# ── LE PAYSAGE ──────────────────────────────────────────────────────────────────────────────────────
#
# ⚠ **LA MAIN TIENT LA FORME, LA MESURE DIT CE QU'IL MANQUE** — c'est la méthode de la charte §2, et
# elle vaut ici mot pour mot. Aucune de ces formes n'est placée par un solveur : elles sont posées là
# où un paysage les mettrait, et c'est seulement ensuite qu'on regarde ce qui manque encore.

func _batir() -> void:
	# ⚠ **LE PREMIER PAYSAGE TENAIT DANS DEUX COUCHES SUR DOUZE, ET L'IMAGE L'A DIT D'UN COUP.** Six
	# couches de roche morte en dessous, du vide au-dessus, un canyon profond d'une case : de loin, un
	# cube blanc avec une encoche. **L'amplitude du relief doit être du même ordre que la hauteur du
	# bloc**, sinon aucune forme ne se lit — et aucun compteur ne l'aurait signalé, puisque la
	# couverture, elle, était bonne.

	# LE SOCLE : deux couches de roche mère, partout.
	_bloc(Vector3i(0, 0, 0), Vector3i(COTE - 1, 1, COTE - 1), true)
	# LE GRAND MASSIF, à l'ouest, et LE MASSIF DE L'EST, plus bas. Entre eux, LE CANYON.
	_bloc(Vector3i(0, 2, 0), Vector3i(5, 7, COTE - 1), true)
	_bloc(Vector3i(9, 2, 0), Vector3i(COTE - 1, 5, COTE - 1), true)
	_etape("LES DEUX MASSIFS et LE CANYON qui les sépare")

	# L'ARCHE : deux piles montant du fond du canyon, un tablier qui les relie, un vide entre elles.
	_bloc(Vector3i(6, 2, 3), Vector3i(6, 6, 4), true)
	_bloc(Vector3i(8, 2, 3), Vector3i(8, 6, 4), true)
	_bloc(Vector3i(6, 7, 3), Vector3i(8, 7, 4), true)
	_etape("L'ARCHE (deux piles, un tablier, un vide entre elles)")

	# LE PONT : un tablier d'une seule case, qui franchit le canyon d'une paroi à l'autre.
	_bloc(Vector3i(6, 5, 8), Vector3i(8, 5, 9), true)
	_etape("LE PONT (un tablier fin, d'une paroi à l'autre)")

	# LA SALLE, creusée dans le grand massif.
	_bloc(Vector3i(1, 3, 3), Vector3i(4, 5, 8), false)
	_etape("LA SALLE (creusée dans le grand massif)")

	# LA BOUCHE DE GROTTE : elle perce la paroi du canyon et ouvre la salle sur le dehors.
	_bloc(Vector3i(5, 3, 5), Vector3i(5, 5, 7), false)
	_etape("LA BOUCHE DE GROTTE (elle perce la paroi du canyon)")

	# LA CHEMINÉE : un conduit du plafond de la salle jusqu'au ciel.
	# ⚠ Elle perçait le plateau juste à côté de l'échancrure du promontoire : les deux entailles se
	# touchaient en diagonale et mettaient le plateau en damier. Elle s'ouvre donc plus au nord.
	_bloc(Vector3i(2, 6, 7), Vector3i(3, 7, 8), false)
	_etape("LA CHEMINÉE (de la salle jusqu'au ciel)")

	# L'AUVENT : le sommet du massif AVANCE au-dessus du canyon. ⚠ Un surplomb se fait en faisant
	# avancer une lèvre sur un vide qui existe, jamais en évidant sous une lèvre en place — trois
	# versions fausses l'ont appris, chacune remettant la matière en damier.
	_bloc(Vector3i(6, 7, 6), Vector3i(6, 7, 9), true)
	_etape("L'AUVENT (le massif surplombe le canyon)")

	# LA CORNICHE : une banquette accrochée à mi-hauteur de la paroi du canyon.
	# ⚠ Elle courait sous le PONT, un étage plus bas : la banquette et le tablier ne se touchaient
	# alors que par une arête. Elle longe donc une autre portion de paroi.
	_bloc(Vector3i(6, 4, 0), Vector3i(6, 4, 2), true)
	_etape("LA CORNICHE (une banquette à mi-paroi)")

	# LE TUNNEL : il traverse le massif de l'est et débouche dans le canyon.
	_bloc(Vector3i(9, 3, 2), Vector3i(COTE - 1, 4, 3), false)
	_etape("LE TUNNEL (il débouche dans le canyon)")

	# LE PUITS : un trou vertical dans le massif de l'est, ouvert au ciel.
	_bloc(Vector3i(10, 2, 9), Vector3i(11, 5, 10), false)
	_etape("LE PUITS (un trou ouvert au ciel)")

	# LA CRÊTE et son COL : une arête d'une case sur le massif de l'est, échancrée en son milieu.
	_bloc(Vector3i(11, 6, 4), Vector3i(11, 7, COTE - 1), true)
	_bloc(Vector3i(11, 6, 6), Vector3i(11, 7, 7), false)
	_etape("LA CRÊTE et son COL")

	# L'AIGUILLE : un piton isolé sur le massif de l'est.
	_bloc(Vector3i(9, 6, 6), Vector3i(9, 8, 6), true)
	_etape("L'AIGUILLE (un piton isolé)")

	# LE PROMONTOIRE : une échancrure du plateau laisse un cap avancer.
	_bloc(Vector3i(4, 7, 3), Vector3i(5, 7, 4), false)
	_etape("LE PROMONTOIRE (le plateau échancré laisse un cap)")

	# LA BUTTE : un monticule sur le grand massif.
	_bloc(Vector3i(2, 8, 9), Vector3i(3, 8, 10), true)
	_etape("LA BUTTE (un monticule)")

	# LE PILIER DE SALLE, du sol au plafond.
	_bloc(Vector3i(2, 3, 4), Vector3i(2, 5, 4), true)
	_etape("LE PILIER DE SALLE (du sol au plafond)")

	# L'ALCÔVE : la salle écartée d'un côté, sur toute sa hauteur.
	_bloc(Vector3i(1, 3, 9), Vector3i(2, 5, 9), false)
	_etape("L'ALCÔVE (la salle écartée d'un côté)")

	# LE BOSSAGE : une bosse d'une case d'épaisseur sur la paroi de la salle.
	_bloc(Vector3i(4, 3, 6), Vector3i(4, 4, 6), true)
	_etape("LE BOSSAGE (une bosse sur la paroi)")

	# LA BANQUETTE EN L, au pied des parois de la salle — un sol de GROTTE, que nulle forme de
	# surface ne livrera jamais : le modèle est orienté.
	_bloc(Vector3i(1, 3, 6), Vector3i(1, 3, 8), true)
	_bloc(Vector3i(2, 3, 8), Vector3i(3, 3, 8), true)
	_etape("LA BANQUETTE EN L (au pied des parois de la salle)")

	# LA MARCHE D'ANGLE : un gradin en L sur le plateau, surmonté à son coin.
	_bloc(Vector3i(1, 8, 1), Vector3i(3, 8, 1), true)
	_bloc(Vector3i(1, 8, 2), Vector3i(1, 8, 3), true)
	_bloc(Vector3i(1, 9, 1), Vector3i(1, 9, 1), true)
	_etape("LA MARCHE D'ANGLE (un gradin en L, surmonté au coin)")

	# LE CAILLOU AU BORD : une case seule au ras de la falaise.
	_bloc(Vector3i(5, 8, 8), Vector3i(5, 8, 8), true)
	_etape("LE CAILLOU AU BORD")

	# LA STALACTITE : une case seule qui pend du plafond de la salle.
	_bloc(Vector3i(3, 5, 7), Vector3i(3, 5, 7), true)
	_etape("LA STALACTITE")


func _bloc(a: Vector3i, b: Vector3i, plein: bool) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				var c := Vector3i(x, y, z)
				if plein:
					_p[c] = true
				else:
					_p.erase(c)


# ── LE BILAN ────────────────────────────────────────────────────────────────────────────────────────

func _bilan() -> void:
	var cible: Dictionary = _cible()
	var recolte: Dictionary = _recolter(_p)
	var dedans := {}
	for nom in recolte:
		if cible.has(nom):
			dedans[nom] = true
	var manque: Array = []
	for nom in cible:
		if not dedans.has(nom):
			manque.append(nom)
	manque.sort()
	print("── LE BILAN ──")
	var diag: int = _contacts_diagonaux(_p)
	print("   %d cases  ·  %d contact(s) diagonal(aux)" % [_p.size(), diag])
	# ⚠ **UN COMPTE NE SE RÉPARE PAS, UNE POSITION SI.** Savoir qu'il reste quatre contacts diagonaux
	# ne dit pas quelle forme les a faits ; les voir au sommet près le dit en une ligne, et évite de
	# retoucher au jugé une forme qui n'y est pour rien.
	if diag > 0:
		print("   OÙ ILS SONT :")
		for x in COTE - 1:
			for y in COTE - 1:
				for z in COTE - 1:
					var b: int = MB.bits(_p, Vector3i(x, y, z))
					if MB.porte_une_surface(b) and not MB.sans_contact_diagonal(b):
						print("      sommet (%d,%d,%d) — %s"
							% [x, y, z, MB.classer(b)["nom"]])
	print("   %d des %d tuiles visées" % [dedans.size(), cible.size()])
	if manque.is_empty():
		print("   ✓ rien ne manque")
		return
	print("   %d manquent :" % manque.size())
	for nom in manque:
		print("      %-32s %s" % [nom, _dessin(nom)])


## Le dessin d'une configuration, en une ligne : les deux couches de 2×2.
##
## ⚠ **ON DESSINE, ON NE NOMME PAS SEULEMENT.** « mb_vrille_d_b3h1 » ne dit à personne quoi modeler ;
## les deux carrés le disent d'un coup d'œil, et c'est le seul format par lequel une tuile absente
## devient un geste faisable.
func _dessin(nom: String) -> String:
	var nu: String = MB.nom_nu(nom)
	var bits := -1
	for c in MB.classes():
		if c["nom"] == nu:
			bits = c["bits"]
			break
	if bits < 0:
		return ""
	var bas := ""
	var haut := ""
	for z in 2:
		for x in 2:
			bas += "#" if (bits & (1 << (x + 4 * z))) else "."
			haut += "#" if (bits & (1 << (x + 2 + 4 * z))) else "."
		bas += "/"
		haut += "/"
	return "bas %s  haut %s" % [bas, haut]


# ── LES RÈGLES DU MODÈLE, LUES ET JAMAIS RECOPIÉES ──────────────────────────────────────────────────

func _cible() -> Dictionary:
	var sortie := {}
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits) or not MB.sans_contact_diagonal(bits):
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


func _contacts_diagonaux(pleines: Dictionary) -> int:
	var n := 0
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var bits: int = MB.bits(pleines, Vector3i(x, y, z))
				if MB.porte_une_surface(bits) and not MB.sans_contact_diagonal(bits):
					n += 1
	return n


## ⚠ Mêmes appels que `exporter_le_bloc` : amincissement, soudure, normales retirées. Une chaîne
## d'export parallèle divergerait de la vraie au premier réglage.
func _exporter(pleines: Dictionary, chemin: String) -> void:
	var BM := load("res://addons/undermend/blocs_maitres.gd")
	var brut: ArrayMesh = BM._coque_sous_voxels(pleines, 0.25)
	if brut.get_surface_count() == 0:
		print("⚠ rien à écrire")
		return
	if _ao:
		brut = _colorier_par_occlusion(brut, pleines)
	var instance := MeshInstance3D.new()
	instance.name = "MasterBlock"
	# ⚠ Le MÊME traitement que `exporter_le_bloc`, teintes nommées comprises : un fichier de travail
	# qui ne ressemblerait pas à ce qui part ferait juger l'artiste sur autre chose.
	instance.mesh = BM.par_teinte(BM.sans_normales(BM.souder(brut)))
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_scene(instance, etat)
	if err == OK:
		err = document.write_to_filesystem(etat, chemin)
	instance.free()
	if err != OK:
		print("⚠ échec de l'écriture (%d) : %s" % [err, chemin])
		return
	print("écrit → %s  (%d octets, %d cases, cube de %d)"
		% [chemin, FileAccess.get_file_as_bytes(chemin).size(), pleines.size(), COTE])


# ── LE FINISSEUR ────────────────────────────────────────────────────────────────────────────────────
#
# ⚠ **LA MAIN TIENT LA FORME, LA RECHERCHE COMPLÈTE LA COUVERTURE (charte §2).** Le paysage ci-dessus
# est posé à la main, forme par forme, parce que c'est lui que l'artiste doit reconnaître. Mais deux
# formes voisines créent des configurations que personne n'a voulues, et j'ai passé trois essais à
# déboguer des coins de voxels au jugé — en accusant deux fois la mauvaise forme. Ce que la main fait
# mal, une recherche le fait bien : elle essaie, elle mesure, elle refuse tout ce qui pince la matière.
#
# ⚠ **ELLE NE POSE QUE DES ATOMES, ET C'EST ASSUMÉ.** Ils ne ressemblent à rien — mais ils ne servent
# qu'à ce qu'aucune forme ne porte, et les cacher serait pire que les montrer : l'artiste doit savoir
# que le modèle lui demande une hélice.
func _finir() -> void:
	print("── LE FINISSEUR (il ne pose que ce qu'aucune forme n'a livré) ──")
	var cible: Dictionary = _cible()
	for tour in 8:
		var avant: Dictionary = _recolter(_p)
		var acquis: int = _combien(avant, cible)
		var diag_avant: int = _contacts_diagonaux(_p)
		var meilleur := {}
		var gain := 0
		for atome in _atomes():
			for place in _places(atome):
				var essai: Dictionary = _p.duplicate()
				for d in (atome["cases"] as Array):
					essai[place + (d as Vector3i)] = true
				# ⚠ **LA CONTRAINTE EST RELATIVE, ET L'ABSOLUE BLOQUAIT TOUT.** Exiger « zéro contact
				# diagonal » refuse absolument tous les coups dès que le paysage en porte un seul —
				# le finisseur annonçait alors « plus rien à gagner » alors qu'il n'avait rien pu
				# essayer. Ce qu'on veut, c'est qu'il n'en AJOUTE pas.
				if _contacts_diagonaux(essai) > diag_avant:
					continue
				var apres: Dictionary = _recolter(essai)
				var net: int = _combien(apres, cible) - acquis
				if net > gain:
					gain = net
					meilleur = {"nom": atome["nom"], "place": place, "cases": essai,
						"neuves": _moins(apres, avant)}
		if gain == 0:
			print("   (plus rien à gagner)")
			return
		_p = meilleur["cases"]
		var l: Array = (meilleur["neuves"] as Dictionary).keys()
		l.sort()
		print("   %-34s en (%d,%d,%d)  +%d   %s"
			% [meilleur["nom"], meilleur["place"].x, meilleur["place"].y, meilleur["place"].z,
				gain, ", ".join(PackedStringArray(l))])


## Les endroits où un atome peut se poser : toutes ses cases vides, et au moins une COLLÉE à la
## matière par une FACE. ⚠ Un atome posé dans le vide ne tiendrait que par des arêtes — c'est
## exactement ce qu'on cherche à éviter.
func _places(atome: Dictionary) -> Array:
	var sortie: Array = []
	for x in range(1, COTE - 1):
		for y in range(1, COTE - 1):
			for z in range(1, COTE - 1):
				var a := Vector3i(x, y, z)
				var libre := true
				var colle := false
				for d in (atome["cases"] as Array):
					var c: Vector3i = a + (d as Vector3i)
					if c.x < 1 or c.y < 1 or c.z < 1 							or c.x > COTE - 2 or c.y > COTE - 2 or c.z > COTE - 2 or _p.has(c):
						libre = false
						break
					for e in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
							Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
						if _p.has(c + e):
							colle = true
				if libre and colle:
					sortie.append(a)
	return sortie


## ⚠ Les mêmes atomes que `sonde_gestes_de_paysage.gd` a mesurés : un L de trois cases dont les bras
## font UNE case, plus une quatrième posée sur le coin ou sur un bout, et la barre qui se décale en
## montant. L'épaisseur d'une case est ce qui décide de la classe.
func _atomes() -> Array:
	var L: Array = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)]
	return [
		{"nom": "un L de trois cases", "cases": L},
		{"nom": "un L, une case sur le COIN", "cases": L + [Vector3i(0, 1, 0)]},
		{"nom": "un L, une case sur un BOUT", "cases": L + [Vector3i(1, 1, 0)]},
		{"nom": "un L, une case sur l'AUTRE BOUT", "cases": L + [Vector3i(0, 1, 1)]},
		{"nom": "une barre qui se décale en montant", "cases": [Vector3i(0, 0, 0),
			Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 1)]},
		{"nom": "la même, en miroir", "cases": [Vector3i(0, 0, 0), Vector3i(0, 1, 0),
			Vector3i(0, 0, 1), Vector3i(1, 1, 0)]},
		{"nom": "deux cases", "cases": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]},
		{"nom": "une case seule", "cases": [Vector3i(0, 0, 0)]},
	]


func _combien(tuiles: Dictionary, cible: Dictionary) -> int:
	var n := 0
	for k in tuiles:
		if cible.has(k):
			n += 1
	return n


func _moins(a: Dictionary, b: Dictionary) -> Dictionary:
	var sortie := {}
	for k in a:
		if not b.has(k):
			sortie[k] = true
	return sortie


# ── LA RÉPARATION ───────────────────────────────────────────────────────────────────────────────────
#
# ⚠ **ELLE EXISTE PARCE QUE J'AI PASSÉ CINQ ESSAIS À DÉPLACER DES FORMES À LA MAIN, et que chaque
# correction en cassait une autre ailleurs.** Deux formes voisines mettent parfois la matière en
# damier — quatre cellules alternées autour d'une face, où la roche ne tient que par une arête. Je
# croyais chaque fois savoir laquelle était fautive ; deux fois sur trois j'ai accusé la mauvaise, et
# seule la POSITION des contacts, imprimée au sommet près, a tranché.
#
# ⚠ **LE REMÈDE EST LOCAL ET IL EST SÛR** : un damier se défait en comblant UNE de ses deux cases
# vides. On essaie les huit cases du sommet fautif, on garde celle qui fait le plus baisser le compte,
# et l'on recommence. La forme dessinée à la main n'est touchée que d'une case, là où elle pinçait.
#
# ⚠ **ET ELLE N'A PAS LE DROIT D'ÉCHOUER EN SILENCE** : si le compte ne descend pas à zéro, elle le
# DIT. Un témoin illégal qui se croit propre ferait sculpter à l'artiste des formes que le peintre
# refusera de poser.
func _reparer() -> void:
	print("── LA RÉPARATION (elle comble les pincements) ──")
	for tour in 24:
		var reste: int = _contacts_diagonaux(_p)
		if reste == 0:
			print("   ✓ aucun pincement" if tour == 0 else "   ✓ tout est comblé")
			return
		var meilleure := Vector3i.ZERO
		var mieux: int = reste
		for v in _fautifs():
			for t in 8:
				var c: Vector3i = v + MB.COINS[t]
				if _p.has(c):
					continue
				var essai: Dictionary = _p.duplicate()
				essai[c] = true
				var n: int = _contacts_diagonaux(essai)
				if n < mieux:
					mieux = n
					meilleure = c
		if mieux >= reste:
			print("   ⚠ %d pincement(s) que combler une case ne suffit pas à défaire" % reste)
			return
		_p[meilleure] = true
		print("   une case en (%d,%d,%d)  → %d pincement(s) restant(s)"
			% [meilleure.x, meilleure.y, meilleure.z, mieux])


func _fautifs() -> Array:
	var sortie: Array = []
	for x in COTE - 1:
		for y in COTE - 1:
			for z in COTE - 1:
				var b: int = MB.bits(_p, Vector3i(x, y, z))
				if MB.porte_une_surface(b) and not MB.sans_contact_diagonal(b):
					sortie.append(Vector3i(x, y, z))
	return sortie


# ── LA LÉGENDE PAR OCCLUSION ────────────────────────────────────────────────────────────────────────
#
# ⚠ **ELLE NE REMPLACE RIEN DANS LE GREFFON : elle repeint une copie, pour qu'on puisse comparer.**
# Jordan a tranché le 27 septembre 2026 — ni l'occlusion ni `case_sous_roche()` : le témoin livré se colore
# par `MB.face_sous_le_ciel()`, « le VIDE que borde la face voit-il le ciel ? ». Cette option reste une
# comparaison.
#
# ⚠ **ET L'ORIENTATION NE CHANGE PAS** — sol, paroi, plafond se lisent toujours à la normale. Seul le
# CONTEXTE change de source : « y a-t-il de la roche au-dessus de ma case » devient « cette face
# voit-elle le ciel ». Changer les deux à la fois rendrait la comparaison illisible.
func _colorier_par_occlusion(mesh: ArrayMesh, pleines: Dictionary) -> ArrayMesh:
	var RP := load("res://addons/undermend/repli_procedural.gd")
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var couleurs := PackedColorArray()
	couleurs.resize(v.size())
	# ⚠ **L'OCCLUSION SE CALCULE PAR FACE DE CASE, PAS PAR TRIANGLE.** La coque découpe chaque face en
	# quatre sous-voxels : compter par triangle referait seize fois le même lancer de rayons pour la
	# même réponse. Le cache est la différence entre deux secondes et deux minutes.
	var cache := {}
	for t in range(0, v.size() - 2, 3):
		var n: Vector3 = (v[t + 1] - v[t]).cross(v[t + 2] - v[t])
		if n.length_squared() < 0.000000001:
			continue
		n = -n.normalized()   # ⚠ Godot enroule en HORAIRE : la sortante est à l'opposé.
		var centre: Vector3 = (v[t] + v[t + 1] + v[t + 2]) / 3.0
		var case := Vector3i(floori(centre.x - n.x * 0.3), floori(centre.y - n.y * 0.3),
			floori(centre.z - n.z * 0.3))
		var cle: String = "%d,%d,%d,%d,%d,%d" % [case.x, case.y, case.z,
			roundi(n.x), roundi(n.y), roundi(n.z)]
		if not cache.has(cle):
			# ⚠ **LE RAYON PART DE LA CASE VOISINE, PAS DE LA SURFACE — ET L'INVERSE A TOUT FAUSSÉ.**
			# La coque est AMINCIE : sa surface est rentrée d'un quart DANS sa propre case. Un point
			# posé juste au-dessus d'un sol se trouve donc encore à l'intérieur de la case pleine, et
			# tout rayon un peu rasant la heurte au premier pas. Le dessus du plateau ressortait
			# « souterrain » alors qu'il n'a que du ciel au-dessus. On part du CENTRE de la case d'en
			# face, qui est vide par construction.
			var voisine: Vector3 = Vector3(case) + Vector3.ONE * 0.5 + n
			cache[cle] = _voit_le_ciel(pleines, voisine, n)
		var ouvert: bool = cache[cle]
		var couleur: Color
		if n.y > 0.5:
			couleur = RP.COULEUR_DESSUS if ouvert else RP.COULEUR_DESSUS_DEDANS
		elif n.y < -0.5:
			couleur = RP.COULEUR_PLAFOND if ouvert else RP.COULEUR_PLAFOND_DEDANS
		else:
			couleur = RP.COULEUR_PAROI if ouvert else RP.COULEUR_PAROI_DEDANS
		for k in 3:
			couleurs[t + k] = couleur
	arrays[Mesh.ARRAY_COLOR] = couleurs
	var sortie := ArrayMesh.new()
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return sortie


## CETTE FACE VOIT-ELLE LE CIEL ? Des rayons dans l'hémisphère de sa normale ; ouverte si assez
## d'entre eux s'échappent.
##
## ⚠ **LE SEUIL EST LA SEULE CHOSE ARBITRAIRE ICI, ET IL FAUT LE DIRE.** « Roche au-dessus » répondait
## oui ou non sans réglage — c'est ce qui lui donnait 0 % de dérive. L'occlusion demande COMBIEN, donc
## un seuil, donc un choix. La charte §4 exige qu'un tel nombre soit mesuré et non pris au goût : à ce
## stade il est posé à la moitié, et c'est l'image qui dira s'il tient.
const PORTEE := 7.0
const SEUIL_OUVERT := 0.5

func _voit_le_ciel(pleines: Dictionary, depart: Vector3, normale: Vector3) -> bool:
	var libres := 0
	var total := 0
	for d in _directions(normale):
		total += 1
		var bloque := false
		var l := 0.35
		while l < PORTEE:
			var p: Vector3 = depart + d * l
			if pleines.has(Vector3i(floori(p.x), floori(p.y), floori(p.z))):
				bloque = true
				break
			l += 0.35
		if not bloque:
			libres += 1
	return float(libres) / float(maxi(1, total)) >= SEUIL_OUVERT


## Des directions réparties dans l'hémisphère de `normale`. ⚠ On garde le CIEL en tête : une face
## tournée vers le bas ne verra jamais le ciel directement, et c'est bien ce qu'on veut dire — un
## plafond de grotte et le dessous d'un auvent ne se distinguent que par ce qu'il y a AUTOUR.
func _directions(normale: Vector3) -> Array:
	var sortie: Array = []
	for i in 24:
		var phi: float = float(i) * 2.399963
		var y: float = 1.0 - (float(i) + 0.5) / 24.0
		var r: float = sqrt(maxf(0.0, 1.0 - y * y))
		var d := Vector3(cos(phi) * r, y, sin(phi) * r)
		if d.dot(normale) > 0.1:
			sortie.append(d.normalized())
	if sortie.is_empty():
		sortie.append(normale)
	return sortie


## L'occupation en couches ASCII, `couches[y][z]` indexée par x — le format de `BlocsMaitres.BLOCS`.
## ⚠ Une case hors de `[0, COTE)` n'a pas de place dans ce format : on le dit plutôt que de la perdre.
func _imprimer_les_couches() -> void:
	for cle in _p:
		var c: Vector3i = cle
		if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= COTE or c.y >= COTE or c.z >= COTE:
			print("⚠ case hors du bloc : %s" % c)
	print("── LES COUCHES ──")
	for y in COTE:
		print("\t\t\t[   # y = %d" % y)
		for z in COTE:
			var rangee := ""
			for x in COTE:
				rangee += "#" if _p.has(Vector3i(x, y, z)) else "."
			print("\t\t\t\t\"%s\"," % rangee)
		print("\t\t\t],")
