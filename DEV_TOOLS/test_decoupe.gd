extends SceneTree
##
## TEST — la découpe d'un mesh par une boîte (`addons/marchingblocks_core/decoupe.gd`).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_decoupe.gd
##
## ⚠ **CE MODULE N'AVAIT AUCUN TEST, ET C'EST LE PLUS PARTAGÉ DE LA CHAÎNE** — le trancheur, la
## génération et les blocs maîtres l'appellent tous. Son propre commentaire invoquait un invariant
## d'aire « qui sert au TEST » : ce test n'existait pas.
##
## ── CE QUI L'A FAIT ÉCRIRE, ET C'EST UNE FAUTE QUI A VÉCU LONGTEMPS ─────────────────────────────────
##
## `trancher()` lisait VERTEX, NORMAL, TEX_UV et INDEX — **jamais COLOR** — tandis que `poser()`, dans
## le même fichier, préservait les couleurs. Deux fonctions du même module ne traitaient pas les mêmes
## données, et rien ne le signalait.
##
## Le symptôme était trompeur : le MATÉRIAU était bien conservé. Les pièces portaient donc un matériau
## en `vertex_color_use_as_albedo` sur un maillage sans couleurs — Godot rend alors du BLANC. La planche
## du monde d'essai est sortie entièrement blanche, et le codage vert/bleu/brun (ce qui regarde le ciel,
## un plafond, une paroi) avait disparu.
##
## ⚠ **CE QUE ÇA COÛTAIT N'EST PAS ESTHÉTIQUE** : ce codage est le seul contrôle VISUEL capable de
## montrer un plafond posé là où il faut un sol. Sans lui, la planche ne pouvait plus rougir sur une
## faute d'orientation — *un contrôle incapable d'échouer ne garde rien* (charte §6).
##
## ⚠ Et après correction, la suite complète rendait **exactement le même compte qu'avant** : 6 670
## vérifications, 0 échec. Rien ne gardait la correction. C'est ce fichier qui la garde.
##
## ── LES ATTENTES, CONSTRUITES ICI ET NON RELUES DU MODULE ───────────────────────────────────────────
##
##   • un mesh COLORÉ tranché garde ses couleurs, et les couleurs interpolées à la coupe restent dans
##     l'enveloppe des couleurs d'origine — une interpolation ne peut pas inventer une teinte ;
##   • un mesh SANS couleurs n'en gagne pas : fabriquer un tableau de blancs forcerait un matériau en
##     `vertex_color_use_as_albedo` à blanchir un mesh qui n'en a jamais eu ;
##   • `poser()` et `fusionner()` les conservent aussi — les trois fonctions doivent s'accorder ;
##   • L'AIRE SE CONSERVE : découper par deux boîtes qui se partagent l'espace rend l'aire de départ.
##     C'est l'invariant qui attrape à la fois un triangle perdu et un triangle compté deux fois.

const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")

const EPS := 0.0005

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — la découpe ===\n")
	_les_couleurs_survivent_au_tranchage()
	_une_couleur_interpolee_reste_dans_l_enveloppe()
	_un_mesh_sans_couleur_n_en_gagne_pas()
	_poser_conserve_les_couleurs()
	_fusionner_conserve_les_couleurs()
	_l_aire_se_conserve()
	_aucun_triangle_plat()
	_la_memoire_des_relectures()

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


# ── LE SUJET D'ESSAI ────────────────────────────────────────────────────────────────────────────────

## Un carré de 2 × 2 dans le plan XY, en deux triangles, chaque coin d'une couleur FRANCHE.
## ⚠ BÂTI ICI, à la main, sans passer par `repli_procedural` : trancher la géométrie d'un module pour
## la comparer à elle-même serait une tautologie.
## LA MÉMOIRE DES RELECTURES (1er octobre 2026) : pendant un tranchage, un maillage n'est relu qu'une fois.
## ⚠ `poser` REMPLACE des tableaux dans le conteneur qu'il relit : si la mémoire le lui prêtait au lieu d'une copie,
## poser deux fois le même maillage rendrait la seconde fois des sommets DÉJÀ déplacés. Le tranchage d'aujourd'hui ne
## relit pas un maillage déjà posé — la garde de `test_blocs_maitres` restait muette — d'où ce cas construit.
## Attendu à la main : le carré (0..2, 0..2) décalé de +5 en x va de 5 à 7, les deux fois.
func _la_memoire_des_relectures() -> void:
	var carre := _carre_colore(true)
	Decoupe.memoriser(true)
	var une := Decoupe.poser(carre, Transform3D(Basis(), Vector3(5, 0, 0)))
	var deux := Decoupe.poser(carre, Transform3D(Basis(), Vector3(5, 0, 0)))
	var evitees := Decoupe.relectures_evitees
	Decoupe.memoriser(false)
	var xs := []
	for m in [une, deux]:
		var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var lo := INF
		var hi := -INF
		for p in v:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
		xs.append([lo, hi])
	_dire(xs == [[5.0, 7.0], [5.0, 7.0]], "poser deux fois le même maillage, mémoire active : 5..7 les deux fois (obtenu %s)" % [xs])
	_dire(evitees > 0, "la seconde lecture vient bien de la mémoire")
	Decoupe.memoriser(false)
	_dire(Decoupe.tableaux(carre, 0) == carre.surface_get_arrays(0), "hors d'un tranchage, la mémoire est éteinte")


func _carre_colore(avec_couleurs: bool) -> ArrayMesh:
	var coins := [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 2, 0), Vector3(0, 2, 0)]
	var teintes := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 1, 0)]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for k in triangle:
			v.append(coins[k])
			n.append(Vector3(0, 0, 1))
			c.append(teintes[k])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	if avec_couleurs:
		arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _couleurs_de(mesh: Mesh) -> PackedColorArray:
	var sortie := PackedColorArray()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_COLOR] == null:
			continue
		for col in (arrays[Mesh.ARRAY_COLOR] as PackedColorArray):
			sortie.append(col)
	return sortie


func _sommets_de(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if not arrays.is_empty():
			n += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


# ── les vérifications ───────────────────────────────────────────────────────────────────────────────

func _les_couleurs_survivent_au_tranchage() -> void:
	print("1. un mesh coloré tranché garde ses couleurs")
	# Une boîte qui coupe le carré en deux : x de 0 à 1.
	var morceau: ArrayMesh = Decoupe.trancher(_carre_colore(true),
		AABB(Vector3(-0.5, -0.5, -1), Vector3(1.5, 3, 2)))
	_dire(morceau.get_surface_count() > 0, "le tranchage ne rend rien")
	var couleurs: PackedColorArray = _couleurs_de(morceau)
	_dire(not couleurs.is_empty(),
		"la pièce tranchée n'a AUCUNE couleur de sommet — elle rendra blanc sous un matériau "
		+ "en vertex_color_use_as_albedo")
	_dire(couleurs.size() == _sommets_de(morceau),
		"%d couleur(s) pour %d sommet(s) : les tableaux doivent avoir la même longueur"
			% [couleurs.size(), _sommets_de(morceau)])
	print("   → %d sommets, %d couleurs" % [_sommets_de(morceau), couleurs.size()])


## ⚠ UNE INTERPOLATION NE PEUT PAS INVENTER UNE TEINTE. Toute couleur rendue doit rester dans
## l'enveloppe des quatre couleurs d'origine — ici, chaque canal entre 0 et 1, et aucune composante
## négative ni supérieure. Un tableau recopié de travers (décalé d'un sommet) passerait ce contrôle ;
## un tableau REMPLI DE BLANC ne le passe pas, puisque le blanc n'est pas dans l'enveloppe du bleu pur.
func _une_couleur_interpolee_reste_dans_l_enveloppe() -> void:
	print("2. une couleur interpolée reste dans l'enveloppe des couleurs d'origine")
	var morceau: ArrayMesh = Decoupe.trancher(_carre_colore(true),
		AABB(Vector3(-0.5, -0.5, -1), Vector3(1.5, 3, 2)))
	var couleurs: PackedColorArray = _couleurs_de(morceau)
	var dehors := 0
	var tous_blancs := true
	for col in couleurs:
		if col.r < -EPS or col.r > 1.0 + EPS or col.g < -EPS or col.g > 1.0 + EPS \
				or col.b < -EPS or col.b > 1.0 + EPS:
			dehors += 1
		if col.r < 0.99 or col.g < 0.99 or col.b < 0.99:
			tous_blancs = false
	_dire(dehors == 0, "%d couleur(s) hors de l'enveloppe des couleurs d'origine" % dehors)
	_dire(not tous_blancs,
		"toutes les couleurs rendues sont BLANCHES — c'est la signature d'un tableau fabriqué, "
		+ "pas d'un tableau transporté")
	print("   → %d couleurs, %d hors enveloppe, toutes blanches : %s"
		% [couleurs.size(), dehors, str(tous_blancs)])


## ⚠ LE SENS INVERSE COMPTE AUTANT. Fabriquer un tableau de blancs pour un mesh qui n'en a jamais eu
## forcerait un matériau en `vertex_color_use_as_albedo` à le blanchir — on réparerait un défaut en en
## créant un autre, et celui-là serait invisible puisque la plupart des matériaux ignorent les couleurs.
func _un_mesh_sans_couleur_n_en_gagne_pas() -> void:
	print("3. un mesh SANS couleur n'en gagne pas")
	var morceau: ArrayMesh = Decoupe.trancher(_carre_colore(false),
		AABB(Vector3(-0.5, -0.5, -1), Vector3(1.5, 3, 2)))
	_dire(morceau.get_surface_count() > 0, "le tranchage ne rend rien")
	_dire(_couleurs_de(morceau).is_empty(),
		"la pièce a gagné %d couleur(s) alors que la source n'en avait aucune"
			% _couleurs_de(morceau).size())
	print("   → aucune couleur inventée")


func _poser_conserve_les_couleurs() -> void:
	print("4. poser() conserve les couleurs")
	var pose: ArrayMesh = Decoupe.poser(_carre_colore(true),
		Transform3D(Basis(), Vector3(5, 0, 0)))
	_dire(not _couleurs_de(pose).is_empty(), "poser() a perdu les couleurs")
	_dire(_couleurs_de(pose).size() == _sommets_de(pose),
		"poser() : %d couleurs pour %d sommets"
			% [_couleurs_de(pose).size(), _sommets_de(pose)])
	print("   → %d couleurs conservées" % _couleurs_de(pose).size())


func _fusionner_conserve_les_couleurs() -> void:
	print("5. fusionner() conserve les couleurs")
	var a: ArrayMesh = _carre_colore(true)
	var b: ArrayMesh = Decoupe.poser(_carre_colore(true), Transform3D(Basis(), Vector3(4, 0, 0)))
	var fondu: ArrayMesh = Decoupe.fusionner([a, b])
	_dire(not _couleurs_de(fondu).is_empty(), "fusionner() a perdu les couleurs")
	_dire(_couleurs_de(fondu).size() == _sommets_de(fondu),
		"fusionner() : %d couleurs pour %d sommets"
			% [_couleurs_de(fondu).size(), _sommets_de(fondu)])
	# ⚠ ET LE SENS INVERSE : un morceau sans couleurs doit désactiver le tableau pour TOUS, sinon la
	# moitié du mesh recevrait du blanc fabriqué.
	var mele: ArrayMesh = Decoupe.fusionner([a, _carre_colore(false)])
	_dire(_couleurs_de(mele).is_empty(),
		"fusionner() a fabriqué des couleurs alors qu'un des morceaux n'en avait pas")
	print("   → %d couleurs fusionnées, et aucune fabriquée quand un morceau n'en a pas"
		% _couleurs_de(fondu).size())


## ⚠ L'INVARIANT QUE LE MODULE INVOQUAIT SANS QUE PERSONNE NE LE VÉRIFIE. Découper par deux boîtes qui
## se partagent l'espace doit rendre exactement l'aire de départ : un triangle perdu la fait baisser, un
## triangle compté deux fois la fait monter. Aucun « ça rend des triangles » n'attrape ces deux-là.
func _l_aire_se_conserve() -> void:
	print("6. l'aire se conserve à la découpe")
	var carre: ArrayMesh = _carre_colore(true)
	var totale: float = Decoupe.aire(carre)
	_dire(absf(totale - 4.0) < EPS, "le carré 2 × 2 devrait faire 4,0 d'aire, il en fait %.5f" % totale)

	# Deux boîtes qui se partagent l'espace au plan x = 0,7 — un plan qui coupe les DEUX triangles.
	var gauche: ArrayMesh = Decoupe.trancher(carre, AABB(Vector3(-10, -10, -10), Vector3(10.7, 20, 20)))
	var droite: ArrayMesh = Decoupe.trancher(carre, AABB(Vector3(0.7, -10, -10), Vector3(20, 20, 20)))
	var somme: float = Decoupe.aire(gauche) + Decoupe.aire(droite)
	_dire(absf(somme - totale) < EPS,
		"aire %.5f + %.5f = %.5f, au lieu de %.5f — un triangle est perdu ou compté deux fois"
			% [Decoupe.aire(gauche), Decoupe.aire(droite), somme, totale])
	_dire(Decoupe.aire(gauche) > EPS and Decoupe.aire(droite) > EPS,
		"le plan de coupe devait traverser le carré : les deux moitiés doivent être non vides")
	print("   → %.5f + %.5f = %.5f (attendu %.5f)"
		% [Decoupe.aire(gauche), Decoupe.aire(droite), somme, totale])



## ⚠ **UN SOMMET POSÉ SUR UN PLAN DE COUPE EST GARDÉ DES DEUX CÔTÉS** : le triangle d'une case voisine qui
## touche la boîte par une arête laissait un polygone réduit à un segment, et l'éventail le triangulait.
## Mesuré sur le témoin : 32 190 triangles d'aire nulle sur 49 802, tous sur les joints.
func _aucun_triangle_plat() -> void:
	print("7. aucun triangle plat à la découpe")
	# Un triangle de la case x > 0,5 qui touche la boîte [−0,5 ; 0,5] par son arête x = 0,5.
	var v := PackedVector3Array([Vector3(0.5, -0.4, 0), Vector3(0.5, 0.4, 0), Vector3(0.9, 0, 0)])
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = v
	var voisin := ArrayMesh.new()
	voisin.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	var boite := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var reste: ArrayMesh = Decoupe.trancher(voisin, boite)
	_dire(_sommets_de(reste) == 0, "un triangle qui ne fait que TOUCHER la boîte y laisse %d sommet(s)"
		% _sommets_de(reste))
	# ⚠ Et le contrôle négatif : ce qui entre VRAIMENT dans la boîte reste.
	var dedans: ArrayMesh = Decoupe.trancher(voisin, AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.2, 1, 1)))
	_dire(Decoupe.aire(dedans) > 0.01, "la partie du triangle réellement dans la boîte a disparu")
	print("   → touché : %d sommet(s) ; entré : aire %.3f" % [_sommets_de(reste), Decoupe.aire(dedans)])
