extends SceneTree
##
## TEST — le tranchage d'un bloc maître (étape 6).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_tranchage.gd
##
## ⚠ **LE SUJET D'ESSAI EST BÂTI EN BOÎTES BRUTES, JAMAIS DEPUIS LE REPLI.** C'est la leçon que Jordan a
## donnée sur la planche : colorier une face d'après sa normale puis regarder la couleur pour conclure
## que la normale est bonne ne prouve rien. Trancher la géométrie du repli pour retrouver le repli
## serait la même tautologie. Le bloc est donc un empilement de `BoxMesh`, plus un relief posé dessus —
## exactement le « simple cube avec un relief moche » que Jordan avait demandé, en code, donc
## reproductible et sans fichier d'art.
##
## ── LES ATTENTES, DÉRIVÉES DU MODÈLE ET NON RELUES DU TRANCHEUR ─────────────────────────────────────
##
##   • un bloc PLEIN n'a aucun coin rentrant, donc aucun de ses sommets ne voit cinq, six ou sept
##     cellules pleines : il ne peut livrer que les classes CONVEXES, et `manquantes()` doit être
##     non vide ;
##   • CREUSER une cellule d'angle fabrique un rentrant : les classes concaves apparaissent alors ;
##   • chaque pièce tient dans le CUBE UNITÉ — les pièces sortent à l'échelle unité, et une composition
##     d'échelle inversée les ferait sortir à l'échelle `cellule`, ce qui se verrait ici ;
##   • les OCTANTS VIDES SONT VIDES, revérifié avec les boîtes du test et non celles du module ;
##   • des dimensions fausses d'une case entière sont SIGNALÉES ; un relief qui déborde d'un quart de
##     case ne l'est pas — le débord est du relief jusqu'à une demi-case.
##
## ⚠ **RÉSERVE POSÉE D'AVANCE** : ce bloc naïf garde ses FACES INTERNES entre cellules voisines (on
## empile des boîtes, on ne fait pas de CSG). Si le contrôle de couture s'en plaint, ce sera un défaut
## du SUJET D'ESSAI, pas du modèle — et il faudra l'écrire ainsi, jamais désactiver le contrôle pour
## obtenir du vert.
##
## ── CE QUE CE TEST NE GARDE PAS, ET C'EST MESURÉ ────────────────────────────────────────────────────
##
## Le banc de mutations rend 7 ROUGES sur 9. Les deux qui restent MUETTES ne sont pas des défauts du
## trancheur : ce sont des limites de ce fichier, et `DEV_TOOLS/sonde_tranchage.gd` en a mesuré la
## cause plutôt que de la supposer. Elles sont écrites ici pour que personne ne les redécouvre.
##
## **1. « condition borde-le-vide supprimée » — MUETTE.** Le raffinement est juste : un octant plein
##    dont les trois voisins sont pleins est INTÉRIEUR, il ne porte aucune surface, et l'exiger de lui
##    serait un faux positif. Mais il est INEXERCÉ ici. Mesuré : `mb_coin_creux_b4h3` et
##    `mb_coin_creux_b3h4` sont bien livrés, leurs octants intérieurs sont bien `[0,1,2,4]` et
##    `[0,2,3,6]` — et **tous portent de la surface**, parce que l'empilement de boîtes conserve ses
##    faces internes. L'attente est donc satisfaite des deux côtés de la mutation.
##    ⚠ POUR LA LEVER : un sujet SANS faces internes — un solide booléen, ou une coque bâtie à la main.
##    C'est exactement ce qu'est un vrai bloc sculpté, donc la mutation mordrait sur de l'art réel.
##
## **2. « origine prise au COIN » — MUETTE.** Les deux formules ne divergent que sur un bloc à relief,
##    et seulement de **0,125** sur l'axe où le relief pousse (mesuré). Or un décalage de 0,125
##    n'AFFAME aucun octant de bord : chacun continue d'attraper de la géométrie. Mesuré en simulant la
##    mutation par pré-translation — origine au centre et origine au coin rendent **8 pièces, 0 erreur
##    d'octant, 21 au total, mêmes classes**, à l'identique.
##    ⚠ POUR LA LEVER : un contrôle de POSITION ABSOLUE, pas d'occupation — par exemple exiger que la
##    surface horizontale d'une `mb_plaque_b4h0` tombe exactement sur le plan central de sa pièce. Le
##    contrôle par octants est, par nature, trop grossier pour un écart de cette taille.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

const CELLULE := 1.0

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — le tranchage d'un bloc maître ===\n")
	_un_bloc_plein_ne_donne_que_du_convexe()
	_creuser_un_angle_fabrique_le_concave()
	_les_pieces_tiennent_dans_le_cube_unite()
	_les_octants_vides_sont_vides()
	_les_dimensions_fausses_sont_signalees()
	_le_relief_modere_ne_derange_pas()
	_un_bloc_absent_est_refuse()
	_la_couture_range_par_germe_oriente()
	_la_couture_utilise_vraiment_la_cle()

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

## Un bloc de `cases` cellules, moins les `creuses`, bâti en BOÎTES BRUTES.
## `relief` : la hauteur des bosses posées sur le dessus, en fraction de cellule (0 pour aucun).
##
## ⚠ AUCUN APPEL À `repli_procedural` ICI. Ce bloc ne sait rien des classes, des octants ni des
## rotations : c'est un tas de cubes. C'est ce qui en fait un sujet d'essai INDÉPENDANT.
## ⚠ `decalage` DÉPLACE LE BLOC HORS DE L'ORIGINE, et ce n'est pas un détail : sur un bloc cubique posé
## en (0,0,0), « l'origine prise au centre » et « l'origine prise au coin » désignent LE MÊME POINT. La
## mutation correspondante était donc inobservable, et revenait muette. Un mesh importé n'est presque
## jamais à l'origine : le sujet d'essai ne doit pas l'être non plus.
## ⚠ `damier` DÉCIDE SI LE RELIEF EST SEAM-LÉGAL, et c'est une distinction que le banc a rendue
## nécessaire. En damier (défaut), une cellule sur deux porte une bosse : deux pièces de MÊME
## configuration présentent alors des germes différents, ce qui viole le contrat de couture — mon bloc
## d'essai était réellement illégal, et `verifier_couture` avait raison de le refuser. Avec `damier`
## à `false`, la bosse est sur TOUTES les cellules, identique : le germe redevient une fonction de la
## seule configuration, donc le bloc est légal et doit passer SANS AUCUNE erreur.
func _bloc(cases: Vector3i, creuses: Array, relief: float, decalage := Vector3.ZERO,
		damier := true) -> ArrayMesh:
	var absentes := {}
	for c in creuses:
		absentes[Vector3i(c)] = true
	var morceaux: Array = []
	for x in cases.x:
		for y in cases.y:
			for z in cases.z:
				if absentes.has(Vector3i(x, y, z)):
					continue
				var boite := BoxMesh.new()
				boite.size = Vector3.ONE * CELLULE
				var brut := ArrayMesh.new()
				brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boite.surface_get_arrays(0))
				morceaux.append(Decoupe.poser(brut, Transform3D(Basis(),
					(Vector3(x, y, z) + Vector3.ONE * 0.5) * CELLULE + decalage)))
	# Le relief « moche » : de petites bosses posées sur la face du dessus, décalées exprès pour ne pas
	# tomber sur les plans de coupe.
	if relief > 0.0:
		for x in cases.x:
			for z in cases.z:
				if damier and (x + z) % 2 != 0:
					continue
				var bosse := BoxMesh.new()
				bosse.size = Vector3(0.4, relief, 0.4) * CELLULE
				var brut := ArrayMesh.new()
				brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bosse.surface_get_arrays(0))
				morceaux.append(Decoupe.poser(brut, Transform3D(Basis(),
					Vector3(x + 0.5, cases.y, z + 0.5) * CELLULE + Vector3.UP * relief * 0.5)))
	return Decoupe.fusionner(morceaux)


## La boîte d'un octant, RÉTRÉCIE, et RECALCULÉE ICI. ⚠ Appeler celle du module reviendrait à lui
## demander de se juger lui-même.
##
## ⚠ **POURQUOI RÉTRÉCIE, ET C'EST UN ÉCHEC DE CE TEST QUI L'A APPRIS.** Sa première version prenait la
## boîte pleine et déclarait 43 octants fautifs. Or la surface d'une pièce est POSÉE sur les plans
## centraux — c'est là qu'est la frontière entre un octant plein et son voisin vide — et la découpe
## garde la géométrie posée sur le plan de coupe. Un quad de frontière était donc compté des deux côtés.
## La preuve que le juge avait tort plutôt que l'accusé : avec cette règle, **le repli procédural
## lui-même était fautif**, alors qu'il est la référence.
##
## La propriété correcte est « rien STRICTEMENT à l'intérieur d'un octant vide ». La marge doit rester
## PETITE : les défauts visés translatent ou tournent la pièce d'un quart de cellule au moins.
const MARGE := 0.02


func _octant(t: int) -> AABB:
	var coin: Vector3i = MB.COINS[t]
	return AABB(Vector3(
		-0.5 if coin.x == 0 else 0.0,
		-0.5 if coin.y == 0 else 0.0,
		-0.5 if coin.z == 0 else 0.0), Vector3.ONE * 0.5).grow(-MARGE)


# ── 1. un bloc plein ────────────────────────────────────────────────────────────────────────────────

func _un_bloc_plein_ne_donne_que_du_convexe() -> void:
	print("1. un bloc PLEIN ne peut livrer que les classes convexes")
	var erreurs: Array = []
	var pieces: Dictionary = Tranchage.trancher(_bloc(Vector3i(3, 3, 3), [], 0.0),
		Vector3i(3, 3, 3), CELLULE, [], erreurs)
	_dire(not pieces.is_empty(), "un bloc 3×3×3 devrait livrer des pièces")

	# ⚠ DÉRIVÉ DU MODÈLE : un parallélépipède n'a aucun coin rentrant, donc aucun sommet n'y voit 5, 6
	# ou 7 cellules pleines. Toute classe à `pleines` ≥ 5 doit donc être ABSENTE.
	var par_nom := {}
	for c in MB.classes():
		par_nom[c["nom"]] = c["pleines"]
	# ⚠ SUFFIXE RETIRÉ : depuis la récolte à deux contextes une clé peut valoir « <classe>_dehors », et
	# `par_nom.get(nom, 0)` rendait alors 0 — donc AUCUNE concave n'était jamais comptée, et ce contrôle
	# passait au vert sans rien regarder.
	var concaves_trouvees: Array = []
	for nom in pieces:
		if par_nom.get(MB.nom_nu(nom), 0) >= 5:
			concaves_trouvees.append(nom)
	_dire(concaves_trouvees.is_empty(),
		"un bloc plein ne peut pas livrer de classe concave, il en livre %s" % str(concaves_trouvees))

	var manquantes: Array = Tranchage.manquantes(pieces)
	_dire(not manquantes.is_empty(),
		"un bloc plein DOIT laisser des classes manquantes — c'est ce qui dit au sculpteur quoi creuser")
	print("   → %d classes livrées, %d manquantes (les concaves, par construction)"
		% [pieces.size(), manquantes.size()])


# ── 2. creuser un angle ─────────────────────────────────────────────────────────────────────────────

func _creuser_un_angle_fabrique_le_concave() -> void:
	print("\n2. creuser une cellule d'angle fabrique les classes concaves")
	var erreurs: Array = []
	var creuses := [Vector3i(2, 2, 2)]
	var pieces: Dictionary = Tranchage.trancher(_bloc(Vector3i(3, 3, 3), creuses, 0.0),
		Vector3i(3, 3, 3), CELLULE, creuses, erreurs)
	var par_nom := {}
	for c in MB.classes():
		par_nom[c["nom"]] = c["pleines"]
	# ⚠ SUFFIXE RETIRÉ, et c'est ce qui faisait ROUGIR ce contrôle : la concave sortait bien, mais sous
	# « mb_coin_creux_b4h3_dehors », et le compteur cherchait un nom nu. Le tranchage était juste ;
	# l'interface avait changé sous le test.
	var concaves := 0
	var en_variante := 0
	for nom in pieces:
		if par_nom.get(MB.nom_nu(nom), 0) >= 5:
			concaves += 1
			if (nom as String).ends_with(MB.SUFFIXE_DEHORS):
				en_variante += 1
	_dire(concaves > 0, "creuser un angle devrait faire apparaître au moins une classe concave")
	# ⚠ **ET L'ASSERTION QUI MANQUAIT : la concave doit être comptée QUEL QUE SOIT SON CONTEXTE.**
	# Sans elle, retirer le suffixe ne ferait que repeindre ce contrôle en vert : il redeviendrait
	# aveugle le jour où la classe ne sortirait plus qu'en variante. Ici elle en sort — on l'exige.
	_dire(en_variante > 0,
		"la concave de ce bloc sort à l'air libre : elle doit être comptée sous sa variante aussi")
	# ⚠ ET LE CONTRÔLE INVERSE, sans lequel « tout apparaît toujours » passerait : un seul angle creusé
	# ne peut pas livrer TOUTES les concaves.
	_dire(not Tranchage.manquantes(pieces).is_empty(),
		"un seul angle creusé ne peut pas livrer toutes les classes")
	print("   → %d classes livrées dont %d concaves" % [pieces.size(), concaves])


# ── 3. L'ÉCHELLE ────────────────────────────────────────────────────────────────────────────────────

## ⚠ LE PIÈGE QUE CE TEST EXISTE POUR ATTRAPER : les pièces sortent à l'échelle UNITÉ. Si la composition
## de transformations du trancheur applique l'échelle dans le mauvais ordre, elles sortent à l'échelle
## `cellule` — et avec `cellule` valant 1,0 dans les autres essais, personne ne le verrait. On tranche
## donc avec une cellule de 2,0, où l'erreur double la taille des pièces.
func _les_pieces_tiennent_dans_le_cube_unite() -> void:
	print("\n3. les pièces sortent à l'échelle UNITÉ, quelle que soit la cellule du bloc")
	var cube := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	for cellule in [1.0, 2.0, 0.5]:
		var erreurs: Array = []
		var morceaux: Array = []
		for x in 3:
			for y in 3:
				for z in 3:
					var boite := BoxMesh.new()
					boite.size = Vector3.ONE * cellule
					var brut := ArrayMesh.new()
					brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boite.surface_get_arrays(0))
					morceaux.append(Decoupe.poser(brut, Transform3D(Basis(),
						(Vector3(x, y, z) + Vector3.ONE * 0.5) * cellule)))
		var pieces: Dictionary = Tranchage.trancher(Decoupe.fusionner(morceaux),
			Vector3i(3, 3, 3), cellule, [], erreurs)
		var dehors: Array = []
		for nom in pieces:
			if not Decoupe.tient_dans(pieces[nom], cube, 0.001):
				dehors.append(nom)
		_dire(dehors.is_empty(),
			"cellule %.1f : %d pièce(s) sortent du cube unité — %s" % [cellule, dehors.size(),
				str(dehors.slice(0, 3))])
		print("   cellule %.1f → %d pièces, toutes dans le cube unité" % [cellule, pieces.size()])


# ── 4. OÙ LA MATIÈRE SE TROUVE ──────────────────────────────────────────────────────────────────────

## ⚠ LE CONTRÔLE QUE L'ANCIEN TRANCHEUR N'AVAIT PAS, ET QUI LAISSAIT TROIS MUTATIONS MUETTES. Origine
## prise au coin, pièce non ramenée à sa référence, rotation inversée : les trois DÉPLACENT la matière
## sans changer son aire ni sa boîte. Seul « où tombe-t-elle » les attrape.
##
## ⚠ Revérifié avec les boîtes d'octant DU TEST, pas celles du module.
func _les_octants_vides_sont_vides() -> void:
	print("\n4. la matière ne tombe jamais dans un octant vide")
	var erreurs: Array = []
	# ⚠ **LA CELLULE CENTRALE EST CREUSÉE, ET C'EST LE BANC QUI L'A EXIGÉ.** Privé de deux COINS, ce
	# bloc ne produisait aucune classe à octant INTÉRIEUR — un octant plein dont les trois voisins sont
	# pleins — donc le raffinement « qui borde le vide » n'était jamais exercé : le supprimer ne faisait
	# rougir personne. Creuser le CENTRE fait voir 7 pleines et 1 vide à tout sommet de {0,1}³, donc
	# `mb_coin_creux`, dont l'octant opposé au creux est précisément intérieur.
	var creuses := [Vector3i(1, 1, 1), Vector3i(2, 2, 2)]
	var pieces: Dictionary = Tranchage.trancher(
		_bloc(Vector3i(3, 3, 3), creuses, 0.0, Vector3(1.7, -0.3, 2.1)),
		Vector3i(3, 3, 3), CELLULE, creuses, erreurs)
	var par_bits := {}
	for c in MB.classes():
		par_bits[c["nom"]] = c["bits"]

	# ⚠ **ET SURTOUT : ON LIT `erreurs`.** La version précédente le passait au trancheur puis le jetait.
	# Retirer un contrôle qui remplit une liste que personne ne consulte ne change évidemment rien —
	# c'est ce qui rendait muettes les mutations « contrôle des octants retiré » et « couture retirée ».
	_dire(erreurs.is_empty(), "le trancheur signale : %s" % str(erreurs.slice(0, 3)))

	# ⚠ **LA RÈGLE EST RETOURNÉE — DÉCIDÉ PAR JORDAN, 20 septembre 2026.** On ne demande plus « aucune
	# matière dans un octant vide » : le DÉBORDEMENT est légal, c'est ce qu'est le relief. On demande
	# l'inverse, et c'est ce que la matière déplacée viole :
	#
	#     tout octant PLEIN qui BORDE LE VIDE doit porter de la surface.
	#
	# ⚠ « Tout octant plein » serait faux : un octant dont les trois voisins sont pleins est INTÉRIEUR,
	# il n'a aucune surface. Recalculé ici, sans rien demander au module.
	var triangles := 0
	var muets := 0
	for nom in pieces:
		var bits: int = par_bits.get(nom, 0)
		var attendus := {}
		for t in 8:
			if not (bits & (1 << t)):
				continue
			for axe in 3:
				if not (bits & (1 << (t ^ (1 << axe)))):
					attendus[t] = true
					break
		var trouves := {}
		for s in pieces[nom].get_surface_count():
			var arrays: Array = pieces[nom].surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
				if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for i in range(0, v.size() - 2, 3):
				triangles += 1
				var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
				var nn: Vector3 = n[i] if n.size() > i else Vector3.ZERO
				var t := 0
				var ok := true
				for axe in 3:
					var bit := -1
					if c[axe] > 0.001:
						bit = 1
					elif c[axe] < -0.001:
						bit = 0
					elif absf(nn[axe]) > 0.5:
						bit = 0 if nn[axe] > 0.0 else 1
					if bit < 0:
						ok = false
						break
					t += bit << axe
				if ok:
					trouves[t] = true
		for t in attendus:
			if not trouves.has(t):
				muets += 1
				if muets <= 4:
					_dire(false, "« %s » : l'octant %d borde le vide mais ne porte aucune surface"
						% [nom, t])
	_dire(muets == 0, "%d octant(s) bordant le vide sont muets" % muets)
	_dire(triangles > 40, "trop peu de triangles examinés (%d) pour conclure" % triangles)
	print("   → %d pièces, %d triangles, tous les octants de bord portent leur surface"
		% [pieces.size(), triangles])

	# ⚠ ET LA CONSÉQUENCE DE (A), VÉRIFIÉE PLUTÔT QU'ESPÉRÉE : un bloc à RELIEF ne doit plus produire la
	# moindre erreur d'OCTANT. S'il est refusé, ce doit être par la COUTURE — et c'est le bon verdict,
	# puisque mon relief en damier fait porter des germes différents à deux pièces de même configuration.
	# ⚠ **LA COUTURE A CHANGÉ DE STATUT — DÉCIDÉ (Jordan, 24 septembre 2026), ET CE N'EST PAS UN
	# RELÂCHEMENT.** L'en-tête de ce fichier interdit de « désactiver le contrôle pour obtenir du vert »,
	# et je ne le désactive pas : je le DÉPLACE. Le partage a été posé ainsi — l'artiste a toute liberté
	# dans chaque case, la connectivité globale est SA responsabilité, et le trancheur ne vérifie que son
	# propre travail. Or la couture compare des pièces ENTRE ELLES : c'est un jugement sur l'art, pas sur
	# la coupe. Elle part donc dans `remarques` et ne refuse plus.
	#
	# ⚠ **MAIS ELLE DOIT TOUJOURS SIGNALER**, sinon elle ne garde plus rien : le damier reste le sujet qui
	# la met en défaut, et on exige encore qu'elle le voie. La seule chose qui change, c'est la liste où
	# elle écrit.
	var relief: Array = []
	var remarques_relief: Array = []
	Tranchage.trancher(_bloc(Vector3i(3, 2, 3), [], 0.25), Vector3i(3, 2, 3), CELLULE, [], relief,
		true, remarques_relief)
	var octant_sur_relief: Array = []
	for e in relief:
		if "octant" in String(e):
			octant_sur_relief.append(e)
	var couture_sur_relief := 0
	for e in remarques_relief:
		if "couture" in String(e):
			couture_sur_relief += 1
	_dire(octant_sur_relief.is_empty(),
		"un bloc à relief ne doit plus produire d'erreur d'octant : %s" % str(octant_sur_relief.slice(0, 2)))
	_dire(relief.is_empty(),
		"la couture ne doit plus REFUSER : %s" % str(relief.slice(0, 2)))
	_dire(couture_sur_relief > 0,
		"le relief en damier doit toujours être SIGNALÉ par la couture — sinon elle ne garde rien")
	print("   → relief en damier : 0 erreur, %d remarque(s) de couture (le bon signalement)"
		% couture_sur_relief)

	# ⚠ **DÉBORDER N'EST PAS ALTÉRER LA COUTURE — ET J'AI CONFONDU LES DEUX, DEUX FOIS.**
	#
	# J'ai voulu fabriquer ici un relief « seam-légal » en le posant sur toutes les cellules au lieu
	# d'une sur deux. Échec : 21 erreurs de couture, autant que le damier. La mesure dit pourquoi — les
	# plans de coupe passent par les CENTRES de cellule, et je centrais chaque bosse en (x+0,5 ; z+0,5),
	# donc EXACTEMENT sur l'intersection de deux plans. Et elles ne couvraient que la couche du haut :
	# une face `coin` près du sommet portait une bosse dans sa bande, la même face plus bas n'en portait
	# pas. *Uniforme en plan* n'est pas *uniforme dans l'espace*.
	#
	# LA DISTINCTION, QU'IL FAUT RETENIR : sous la règle (A), le relief a le droit de DÉBORDER une
	# frontière de cellule ; il n'a pas le droit de MODIFIER LA BANDE DE COUTURE. Un débordement loin
	# d'un plan de coupe est légal ; une bosse à cheval sur un plan change le germe.
	#
	# Ce sujet ne sert donc pas à prouver la légalité de couture — il sert à ce que l'AABB DÉBORDE les
	# dimensions déclarées, seul cas où « origine au centre » et « origine au coin » cessent de désigner
	# le même point (mesuré, `sonde_tranchage.gd`). On n'assère donc que ce qu'il vise : **aucune erreur
	# d'OCTANT**, quelle que soit la forme du relief.
	var propre: Array = []
	var remarques_propre: Array = []
	var pieces_relief: Dictionary = Tranchage.trancher(
		_bloc(Vector3i(3, 2, 3), [], 0.25, Vector3.ZERO, false),
		Vector3i(3, 2, 3), CELLULE, [], propre, true, remarques_propre)
	var octants_uniforme: Array = []
	for e in propre:
		if "octant" in String(e):
			octants_uniforme.append(e)
	_dire(octants_uniforme.is_empty(),
		"un relief qui déborde ne doit produire AUCUNE erreur d'octant : %s"
			% str(octants_uniforme.slice(0, 2)))
	_dire(not pieces_relief.is_empty(), "le bloc à relief doit livrer des pièces")
	print("   → relief débordant : %d pièces, %d erreur(s), %d remarque(s) de couture"
		% [pieces_relief.size(), propre.size(), remarques_propre.size()])

	# ── LES CONTRÔLES POSITIFS ──────────────────────────────────────────────────────────────────────
	#
	# ⚠ **UN CONTRÔLE QUI N'A JAMAIS L'OCCASION DE RÉUSSIR NE GARDE RIEN.** Le banc l'a montré : couper
	# `verifier_octants` et `verifier_couture` du module ne faisait rougir personne, parce qu'aucun
	# sujet ne les met en défaut. On leur donne donc, exprès, ce qu'ils doivent refuser.
	var nom_temoin := ""
	for nom in pieces:
		nom_temoin = nom
		break
	if nom_temoin != "":
		# ⚠ **DEUX TÉMOINS, PAS UN — ET C'EST LE BANC QUI L'A EXIGÉ.** `verifier_octants` a deux reports
		# distincts : `hors` (triangle attribué à un octant que la classe dit vide) et `egares` (triangle
		# qu'on ne sait rattacher à aucun octant). Ma première pièce témoin, translatée, déclenchait LES
		# DEUX : couper l'une des branches laissait l'autre parler, donc les deux mutations revenaient
		# muettes. Il faut donc un témoin par branche.
		#
		# TÉMOIN « hors » — une ROTATION d'un quart de tour. Tout reste posé sur les plans, donc tout
		# reste attribuable ; mais la matière atterrit dans des octants que la classe dit vides.
		var tournee := {nom_temoin: Decoupe.poser(pieces[nom_temoin],
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))}
		# ⚠ ON ASSERTE LE REFUS, PAS SA FORMULATION — et c'est un échec qui me l'a appris. Cette
		# assertion cherchait le mot « VIDE » en majuscules ; j'ai réécrit le message du module deux
		# éditions plus tard, il dit désormais « borde le vide », et le test a rougi alors que le
		# contrôle avait parfaitement fait son travail. Filtrer sur le TEXTE d'un message, c'est se
		# rendre fragile à sa propre plume. La propriété est « le juge refuse » ; ce qui lui donne sa
		# force, c'est le contrôle NÉGATIF juste en dessous — la pièce intacte doit rester muette.
		var crie_hors: Array = []
		Tranchage.verifier_octants(tournee, {nom_temoin: par_bits[nom_temoin]}, crie_hors)
		_dire(not crie_hors.is_empty(),
			"une pièce TOURNÉE doit être refusée : la matière quitte les octants qui bordent le vide")

		# ⚠ IL N'Y A PLUS QU'UN SEUL TÉMOIN, et c'est (A) qui l'a voulu. Le contrôle avait deux branches
		# — « matière dans un octant vide » et « triangle inattribuable » — et le relief produit
		# légitimement les DEUX. Elles ont disparu avec la règle qu'elles servaient. Il ne reste qu'une
		# chose à refuser : un octant qui borde le vide et ne porte aucune surface.

		# Et la contre-épreuve : la pièce INTACTE ne doit rien déclencher, sinon le contrôle crie
		# toujours et ne distingue rien.
		var muet: Array = []
		Tranchage.verifier_octants({nom_temoin: pieces[nom_temoin]},
			{nom_temoin: par_bits[nom_temoin]}, muet)
		_dire(muet.is_empty(), "la pièce intacte ne doit RIEN déclencher : %s" % str(muet.slice(0, 2)))

		# La couture : deux pièces de MÊME configuration dont l'une est réduite de moitié présentent des
		# germes incompatibles. Le contrôle doit le dire.
		var petite := Decoupe.poser(pieces[nom_temoin],
			Transform3D(Basis().scaled(Vector3.ONE * 0.5), Vector3.ZERO))
		var couture: Array = []
		Tranchage.verifier_couture({"a": pieces[nom_temoin], "b": petite},
			{"a": par_bits[nom_temoin], "b": par_bits[nom_temoin]}, couture)
		_dire(not couture.is_empty(),
			"deux germes incompatibles DOIVENT être refusés par verifier_couture")
	print("   → contrôles positifs : le juge sait refuser, et sait se taire")


# ── 5. les dimensions fausses ───────────────────────────────────────────────────────────────────────

func _les_dimensions_fausses_sont_signalees() -> void:
	print("\n5. des dimensions fausses d'une case entière sont signalées")
	# Un bloc de QUATRE cases déclaré pour TROIS.
	var erreurs: Array = []
	Tranchage.trancher(_bloc(Vector3i(4, 1, 1), [], 0.0), Vector3i(3, 1, 1), CELLULE, [], erreurs)
	_dire(not erreurs.is_empty(), "quatre cases déclarées pour trois doit être SIGNALÉ")
	var parle_du_debord := false
	for e in erreurs:
		if "de trop" in String(e):
			parle_du_debord = true
	_dire(parle_du_debord, "l'erreur devrait parler du débord : %s" % str(erreurs.slice(0, 2)))

	# ⚠ ET DANS L'AUTRE SENS : un bloc plus PETIT que déclaré est tout aussi faux. Ne rien dire de ce
	# côté-là laissait passer exactement le cas que l'ancien trancheur ratait.
	var moins: Array = []
	Tranchage.trancher(_bloc(Vector3i(2, 1, 1), [], 0.0), Vector3i(3, 1, 1), CELLULE, [], moins)
	_dire(not moins.is_empty(), "deux cases déclarées pour trois doit AUSSI être signalé")
	print("   → signalé dans les deux sens, trop grand comme trop petit")


# ── 6. le relief ────────────────────────────────────────────────────────────────────────────────────

func _le_relief_modere_ne_derange_pas() -> void:
	print("\n6. un relief modéré n'est pas pris pour une erreur de dimensions")
	# ⚠ Un bloc qui porte du relief DÉBORDE toujours sa boîte. Tant que le débord reste sous la
	# demi-case, c'est du relief : le refuser interdirait tout bloc sculpté.
	var erreurs: Array = []
	var pieces: Dictionary = Tranchage.trancher(_bloc(Vector3i(3, 2, 3), [], 0.25),
		Vector3i(3, 2, 3), CELLULE, [], erreurs)
	var dimensions: Array = []
	for e in erreurs:
		if "de trop" in String(e):
			dimensions.append(e)
	_dire(dimensions.is_empty(),
		"un relief de 0,25 case ne doit pas être pris pour une dimension fausse : %s" % str(dimensions))
	_dire(not pieces.is_empty(), "le bloc à relief devrait quand même livrer des pièces")
	print("   → relief de 0,25 case accepté, %d pièces livrées" % pieces.size())


# ── 7. un bloc absent ───────────────────────────────────────────────────────────────────────────────

func _un_bloc_absent_est_refuse() -> void:
	print("\n7. un bloc absent ou des dimensions nulles sont refusés")
	var a: Array = []
	_dire(Tranchage.trancher(null, Vector3i(3, 3, 3), CELLULE, [], a).is_empty(),
		"un bloc nul ne doit rien livrer")
	_dire(not a.is_empty(), "un bloc nul doit être signalé")
	var b: Array = []
	_dire(Tranchage.trancher(_bloc(Vector3i(1, 1, 1), [], 0.0), Vector3i(0, 3, 3), CELLULE, [], b).is_empty(),
		"des dimensions nulles ne doivent rien livrer")
	_dire(not b.is_empty(), "des dimensions nulles doivent être signalées")
	var c: Array = []
	_dire(Tranchage.trancher(_bloc(Vector3i(1, 1, 1), [], 0.0), Vector3i(1, 1, 1), 0.0, [], c).is_empty(),
		"une cellule nulle ne doit rien livrer")
	_dire(not c.is_empty(), "une cellule nulle doit être signalée")
	print("   → refusé, et dit pourquoi")


# ── 8. LA COUTURE RANGE PAR GERME ORIENTÉ, PAS PAR FORME LIBRE ──────────────────────────────────────

## ⚠ **CE TEST EXISTE POUR UN DÉFAUT QUI ACCUSAIT L'ARTISTE À TORT.** `verifier_couture` regroupait ses
## relevés par `MB.forme_de_face()` — les SIX formes du modèle LIBRE. Or le modèle est ORIENTÉ et compte
## VINGT-HUIT germes : une face `y+` de forme « mur » est un SOL, une face `x+` de la même forme est un
## MUR, et le modèle dit expressément qu'ils n'ont aucune raison de se ressembler. Le contrôle exigeait
## pourtant la même aire des deux.
##
## ⚠ **ON TESTE LA CLÉ, PAS LE COMPORTEMENT, ET C'EST DÉLIBÉRÉ.** Fabriquer un bloc légal dont les faces
## horizontales et verticales diffèrent demanderait un sujet d'essai retors, et l'assertion resterait
## floue. La clé, elle, se vérifie exactement : c'est là qu'est le défaut, donc c'est là qu'on regarde.
func _la_couture_range_par_germe_oriente() -> void:
	print("\n8. la couture range par GERME orienté, pas par forme libre")

	# ⚠ DÉRIVÉ DU MODÈLE, pas relu du trancheur : `marching_blocks.gd` annonce 28 germes, dont 12 sur
	# les faces horizontales et 16 sur les verticales. On exige les deux chiffres.
	_dire(Tranchage.nombre_de_germes() == 28,
		"le groupe orienté définit 28 germes, la table en compte %d" % Tranchage.nombre_de_germes())

	var horizontaux := {}
	var verticaux := {}
	var melanges: Array = []
	for face in MB.FACES:
		var est_horizontal: bool = face["nom"] == "y-" or face["nom"] == "y+"
		for m in 16:
			var pleins: Array = []
			for i in 4:
				if (m & (1 << i)) != 0:
					pleins.append(int(face["coins"][i]))
			var germe: String = Tranchage.germe_canonique(face["coins"], pleins)
			if est_horizontal:
				horizontaux[germe] = true
			else:
				verticaux[germe] = true
	for g in horizontaux:
		if verticaux.has(g):
			melanges.append(g)
	# ⚠ Une rotation autour de Y n'envoie JAMAIS une face horizontale sur une verticale : aucune orbite
	# ne peut donc contenir les deux. Si c'était le cas, le repli serait faux.
	_dire(melanges.is_empty(),
		"aucun germe ne peut vivre à la fois sur une face horizontale et verticale : %s"
			% str(melanges.slice(0, 3)))
	_dire(horizontaux.size() == 12,
		"12 germes horizontaux attendus, %d trouvés" % horizontaux.size())
	_dire(verticaux.size() == 16,
		"16 germes verticaux attendus, %d trouvés" % verticaux.size())

	# ⚠ **L'ASSERTION QUI ROUGIT SUR LE DÉFAUT EXACT.** Deux faces de MÊME FORME (« mur »), l'une
	# horizontale et l'autre verticale, doivent avoir des germes DIFFÉRENTS. Revenir au regroupement par
	# forme les confond, et ce test rougit immédiatement.
	var sol: Array = []       # face y+ : coins [2, 3, 7, 6] — deux cellules voisines
	var mur: Array = []       # face x+ : coins [1, 3, 7, 5] — deux cellules voisines
	for face in MB.FACES:
		if face["nom"] == "y+":
			sol = [int(face["coins"][0]), int(face["coins"][1])]
		elif face["nom"] == "x+":
			mur = [int(face["coins"][0]), int(face["coins"][1])]
	var forme_sol: String = MB.forme_de_face([true, true, false, false])
	var g_sol: String = Tranchage.germe_canonique(
		MB.FACES[3]["coins"] if MB.FACES[3]["nom"] == "y+" else _coins("y+"), sol)
	var g_mur: String = Tranchage.germe_canonique(_coins("x+"), mur)
	_dire(forme_sol == "mur", "le sujet d'essai doit bien être de forme « mur », il est « %s »" % forme_sol)
	_dire(g_sol != g_mur,
		"un germe de SOL et un germe de MUR de même forme doivent être DISTINCTS — les deux valent %s"
			% g_sol)
	print("   → 28 germes (12 horizontaux, 16 verticaux), sol et mur bien séparés")


func _coins(nom: String) -> Array:
	for face in MB.FACES:
		if face["nom"] == nom:
			return face["coins"]
	return []


# ── 9. ET SURTOUT : `verifier_couture` SE SERT-ELLE DE LA CLÉ ? ─────────────────────────────────────

## ⚠ **CE TEST EXISTE PARCE QUE LE BANC DE MUTATIONS A ATTRAPÉ MON PROPRE TEST 8 EN DÉFAUT.** Remettre le
## regroupement par `forme` dans `verifier_couture` laissait le test 8 **entièrement VERT** : il n'exerce
## que `germe_canonique()`, et rien ne vérifiait que le contrôle s'en serve. J'avais corrigé le défaut et
## livré un garde qui ne le gardait pas — la mutation muette exacte que la charte proscrit.
##
## ⚠ **LES BANDES SONT FABRIQUÉES EN QUADS POSÉS À LA MAIN, pas en tranchant un bloc.** C'est le seul
## moyen de fixer l'aire de chaque face au chiffre près, donc de rendre l'assertion NETTE. Trancher un
## bloc donnerait des aires qu'il faudrait constater après coup, et une assertion qu'on ajuste à son
## résultat ne garde rien.
func _la_couture_utilise_vraiment_la_cle() -> void:
	print("\n9. `verifier_couture` se sert de la clé de germe, et pas de la forme")

	# Configuration 136 : les coins 3 et 7 sont pleins. Ils sont COMMUNS aux faces `y+` ([2,3,7,6]) et
	# `x+` ([1,3,7,5]), et voisins dans l'ordre cyclique des deux — donc les deux faces sont de forme
	# « mur », l'une étant un SOL et l'autre un MUR.
	var bits := 136
	var forme_y := ""
	var forme_x := ""
	for face in MB.FACES:
		var quatre: Array = []
		for t in face["coins"]:
			quatre.append((bits & (1 << int(t))) != 0)
		if face["nom"] == "y+":
			forme_y = MB.forme_de_face(quatre)
		elif face["nom"] == "x+":
			forme_x = MB.forme_de_face(quatre)
	# ⚠ ON VÉRIFIE LE SUJET D'ESSAI AVANT DE S'EN SERVIR : si les deux faces n'étaient pas de la MÊME
	# forme, la mutation ne serait pas exercée et ce test redeviendrait muet sans prévenir.
	_dire(forme_y == "mur" and forme_x == "mur",
		"le sujet doit présenter « mur » sur y+ ET sur x+, il donne « %s » et « %s »" % [forme_y, forme_x])

	# ── CONTRÔLE NÉGATIF : la correction. Deux formes identiques, deux germes distincts, deux aires
	# légitimement différentes → SILENCE.
	var sol := _quad_plat(1, 0.46, -0.4, 0.0)     # dans la bande y+, aire 0,16
	var mur := _quad_plat(0, 0.46, -0.4, 0.4)     # dans la bande x+, aire 0,64
	var piece: ArrayMesh = Decoupe.fusionner([sol, mur])
	var muet: Array = []
	Tranchage.verifier_couture({"legal": piece}, {"legal": bits}, muet)
	_dire(muet.is_empty(),
		"un SOL et un MUR de même forme ont le droit de différer — la couture doit se taire : %s"
			% str(muet.slice(0, 2)))

	# ── CONTRÔLE POSITIF : le juge mord encore. Deux pièces de MÊME germe, deux aires différentes.
	var petit: ArrayMesh = Decoupe.fusionner([_quad_plat(1, 0.46, -0.4, 0.0)])
	var grand: ArrayMesh = Decoupe.fusionner([_quad_plat(1, 0.46, -0.4, 0.4)])
	var crie: Array = []
	Tranchage.verifier_couture({"a": petit, "b": grand}, {"a": bits, "b": bits}, crie)
	_dire(not crie.is_empty(),
		"deux faces du MÊME germe portant des aires différentes DOIVENT être signalées")
	print("   → le sol et le mur sont laissés libres, deux germes égaux sont toujours confrontés")


## Un quad plat, pour fabriquer une bande de couture d'aire choisie. `axe` porte la normale (0=x, 1=y,
## 2=z), `plan` est sa coordonnée sur cet axe, `bas` et `haut` son étendue dans les deux autres.
## ⚠ Son aire vaut exactement `(haut − bas)²`, et c'est ce qui rend les assertions ci-dessus nettes.
func _quad_plat(axe: int, plan: float, bas: float, haut: float) -> ArrayMesh:
	var autres: Array = []
	for k in 3:
		if k != axe:
			autres.append(k)
	var coins: Array = []
	for pas in [[0, 0], [0, 1], [1, 1], [1, 0]]:
		var p := Vector3.ZERO
		p[axe] = plan
		p[autres[0]] = bas if pas[0] == 0 else haut
		p[autres[1]] = bas if pas[1] == 0 else haut
		coins.append(p)
	var normale := Vector3.ZERO
	normale[axe] = 1.0
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for k in [0, 1, 2, 0, 2, 3]:
		v.append(coins[k])
		n.append(normale)
	var res: Array = []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = v
	res[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res)
	return m
