extends SceneTree
##
## TEST — le classificateur « Marching Blocks », en modèle ORIENTÉ.
##
## LANCEMENT
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_marching_blocks.gd
##
## ⚠ CE QUE CE TEST GARDE :
##
##   • la table des 24 rotations est REMESURÉE contre un vrai GridMap — jamais crue ;
##   • l'ALLER-RETOUR : poser le mesh de référence avec l'orientation rendue doit REPRODUIRE la
##     configuration demandée. C'est la seule vérification qui distingue « une table bien formée » de
##     « une table juste » ;
##   • tous les comptes sont recalculés ICI de façon INDÉPENDANTE, jamais relus depuis le module.
##
## ⚠ ET IL A DÉJÀ SERVI DEUX FOIS. Sa première exécution a trouvé QUATRE représentants faux sur
## vingt-trois, que j'avais saisis à la main sous un commentaire disant qu'il ne fallait pas les saisir
## à la main. Tout se dérive désormais ; ce test garde que ça le reste.
##
## ── LE MODÈLE ORIENTÉ (Jordan, 19 septembre 2026) ───────────────────────────────────────────────────
##
## Le groupe de pose est réduit aux rotations qui GARDENT LE HAUT. Sa raison, mot pour mot : *« c'est
## une liberté trop importante à l'artiste de différencier le haut, le milieu et le bas de son art. »*
## Conséquence chiffrée : 70 classes au lieu de 23, 68 pièces à sculpter au lieu de 21 — et le sol plat
## cesse d'être le même objet que le mur plat.

const MB := preload("res://addons/undermend/marching_blocks.gd")

## ⚠ LES CHIFFRES ATTENDUS SONT ÉCRITS ICI, EN DUR ET EXPRÈS. Ils viennent d'un calcul d'orbites mené
## HORS du moteur (Burnside vérifié sur les trois groupes). Si le module se met à en rendre d'autres,
## c'est le module qui a changé, pas la vérité.
const CLASSES_ATTENDUES := 70
const A_SCULPTER := 68
const QUARTS := [0, 10, 16, 22]
const GERMES := 28
const GERMES_HORIZONTAUX := 12
const GERMES_VERTICAUX := 16
## Répartition des 70 classes par nombre de cellules pleines en HAUT (de 4 à 0).
const PAR_HAUT := [6, 16, 26, 16, 6]

var _ok := 0
var _echecs := 0
var _premier := ""


func _initialize() -> void:
	print("=== TEST — Marching Blocks, modèle « %s » ===\n" % MB.GROUPE)
	_la_table_des_rotations_se_remesure()
	_le_groupe_garde_le_haut()
	_aucune_anomalie_et_les_256_repondent()
	_l_aller_retour_reproduit_la_configuration()
	_les_classes_partitionnent_les_256()
	_le_haut_et_le_bas_sont_des_invariants()
	_les_noms_sont_derives_et_uniques()
	_les_familles_tiennent_toujours()
	_le_contrat_de_couture_tient()
	_les_germes_de_bordure()
	_l_echantillonnage_est_coherent()
	_les_tuiles_de_run_se_repetent()
	_les_symetries_imposees()
	_le_lieu_et_la_matiere_sont_deux_questions()

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


## Rotation d'une configuration, RÉIMPLÉMENTÉE ICI EXPRÈS. ⚠ Appeler celle du module reviendrait à lui
## demander de se juger lui-même : c'est la leçon du moteur de lumière que ce projet a porté avant de
## devenir un greffon — son test vérifiait la réflexion contre un calcul INDÉPENDANT, jamais contre sa
## propre formule.
func _tourner(bits: int, coins: Array) -> int:
	var sortie := 0
	for t in 8:
		if bits & (1 << t):
			sortie |= 1 << int(coins[t])
	return sortie


func _compte(bits: int) -> int:
	var n := 0
	for t in 8:
		if bits & (1 << t):
			n += 1
	return n


# ── 1. la table des rotations, remesurée ────────────────────────────────────────────────────────────

func _la_table_des_rotations_se_remesure() -> void:
	print("1. les 24 rotations, remesurées contre un vrai GridMap")
	var grille := GridMap.new()
	var vues := {}
	for entree in MB.ROTATIONS:
		var index: int = entree["index"]
		var base: Basis = grille.get_basis_with_orthogonal_index(index)
		_dire(absf(base.determinant() - 1.0) < 0.0001, "l'index %d n'est pas une rotation propre" % index)
		var mesure: Array = []
		for t in 8:
			var c: Vector3i = MB.COINS[t]
			var v := Vector3(c.x, c.y, c.z) * 2.0 - Vector3.ONE
			var w: Vector3 = base * v
			mesure.append(int(roundf((w.x + 1.0) * 0.5))
				+ 2 * int(roundf((w.y + 1.0) * 0.5))
				+ 4 * int(roundf((w.z + 1.0) * 0.5)))
		_dire(mesure == entree["coins"],
			"l'index %d : la table dit %s, le GridMap mesure %s" % [index, str(entree["coins"]), str(mesure)])
		var cle := str(mesure)
		_dire(not vues.has(cle), "l'index %d refait la rotation de l'index %s" % [index, str(vues.get(cle, -1))])
		vues[cle] = index
	_dire(MB.ROTATIONS.size() == 24, "%d rotations déclarées, il en faut 24" % MB.ROTATIONS.size())
	_dire(vues.size() == 24, "%d rotations DISTINCTES, il en faut 24" % vues.size())
	grille.free()
	print("   → 24 rotations déclarées, 24 mesurées, toutes distinctes")


# ── 2. le groupe garde le haut ──────────────────────────────────────────────────────────────────────

func _le_groupe_garde_le_haut() -> void:
	print("\n2. le groupe actif garde le HAUT")
	var actives: Array = MB.rotations_actives()
	var index: Array = []
	for r in actives:
		index.append(r["index"])
	index.sort()
	_dire(index == QUARTS,
		"le groupe actif est %s, on attend %s (les quarts de tour autour de Y)" % [str(index), str(QUARTS)])

	# ⚠ VÉRIFIÉ INDÉPENDAMMENT : une rotation garde le haut si et seulement si elle préserve le bit y de
	# chaque coin. On le recalcule ici plutôt que de croire le filtre du module.
	for r in actives:
		for t in 8:
			_dire(((int(r["coins"][t]) >> 1) & 1) == ((t >> 1) & 1),
				"l'index %d envoie le coin %d en %d : le haut n'est pas gardé"
					% [r["index"], t, int(r["coins"][t])])
	# Et aucune des vingt autres ne doit le garder.
	var gardent := 0
	for r in MB.ROTATIONS:
		var garde := true
		for t in 8:
			if ((int(r["coins"][t]) >> 1) & 1) != ((t >> 1) & 1):
				garde = false
		if garde:
			gardent += 1
	_dire(gardent == 4, "%d rotations gardent le haut, il en faut exactement 4" % gardent)
	print("   → 4 rotations actives : %s — les QUARTS du modèle 2D, retrouvés par le calcul" % str(index))


# ── 3. aucune anomalie ──────────────────────────────────────────────────────────────────────────────

func _aucune_anomalie_et_les_256_repondent() -> void:
	print("\n3. aucune anomalie, et les 256 configurations ont toutes une réponse")
	var anomalies: Array = MB.anomalies()
	_dire(anomalies.is_empty(), "anomalies signalées : %s" % str(anomalies.slice(0, 5)))
	for b in 256:
		var r: Dictionary = MB.classer(b)
		_dire(r["nom"] != "", "configuration %d : aucune classe nommée" % b)
		_dire(r["orientation"] >= 0 and r["orientation"] < 24,
			"configuration %d : orientation %d hors bornes" % [b, r["orientation"]])
		_dire(r["surface"] == (b != 0 and b != 255),
			"configuration %d : « surface » mal rendu" % b)
	print("   → 0 anomalie, 256 réponses, 2 sans surface (le vide et le ventre plein)")


# ── 4. L'ALLER-RETOUR ───────────────────────────────────────────────────────────────────────────────

func _l_aller_retour_reproduit_la_configuration() -> void:
	print("\n4. poser la référence avec l'orientation rendue REPRODUIT la configuration")
	var index_vers_coins := {}
	for entree in MB.ROTATIONS:
		index_vers_coins[entree["index"]] = entree["coins"]
	var classes: Array = MB.classes()
	var faux := 0
	for b in 256:
		var r: Dictionary = MB.classer(b)
		var reference: int = classes[r["classe"]]["bits"]
		var coins: Array = index_vers_coins.get(r["orientation"], [])
		if coins.is_empty():
			_dire(false, "configuration %d : orientation %d absente" % [b, r["orientation"]])
			continue
		# ⚠ ET L'ORIENTATION DOIT APPARTENIR AU GROUPE ACTIF : rendre une rotation que le modèle orienté
		# s'interdit coucherait la pièce, et l'herbe partirait sur le flanc.
		_dire(QUARTS.has(r["orientation"]),
			"configuration %d : orientation %d hors du groupe actif" % [b, r["orientation"]])
		if _tourner(reference, coins) != b:
			faux += 1
			if faux <= 6:
				_dire(false, "configuration %d (%s, orientation %d) : la référence tournée donne %d"
					% [b, r["nom"], r["orientation"], _tourner(reference, coins)])
	_dire(faux == 0, "%d configuration(s) ne se reproduisent pas depuis leur référence" % faux)
	print("   → les 256 se reproduisent exactement, et toujours par une rotation autorisée")


# ── 5. les classes partitionnent les 256 ────────────────────────────────────────────────────────────

func _les_classes_partitionnent_les_256() -> void:
	print("\n5. %d classes, 256 configurations" % CLASSES_ATTENDUES)
	var classes: Array = MB.classes()
	_dire(classes.size() == CLASSES_ATTENDUES,
		"%d classes dérivées, il en faut %d" % [classes.size(), CLASSES_ATTENDUES])

	var par_classe := {}
	for b in 256:
		var c: int = MB.classer(b)["classe"]
		par_classe[c] = par_classe.get(c, 0) + 1
	var total := 0
	for c in par_classe:
		total += par_classe[c]
	_dire(total == 256, "les orbites totalisent %d configurations au lieu de 256" % total)
	_dire(par_classe.size() == CLASSES_ATTENDUES,
		"%d classes employées, il en faut %d" % [par_classe.size(), CLASSES_ATTENDUES])

	for c in classes.size():
		_dire(par_classe.get(c, 0) == classes[c]["orbite"],
			"« %s » annonce une orbite de %d, on en compte %d"
				% [classes[c]["nom"], classes[c]["orbite"], par_classe.get(c, 0)])
		_dire(_compte(classes[c]["bits"]) == classes[c]["pleines"],
			"« %s » annonce %d cellules pleines" % [classes[c]["nom"], classes[c]["pleines"]])
		# ⚠ Le représentant est le plus petit de son orbite — c'est ce que j'avais cassé à la main.
		var minimum: int = 256
		for r in MB.rotations_actives():
			minimum = mini(minimum, _tourner(classes[c]["bits"], r["coins"]))
		_dire(minimum == classes[c]["bits"],
			"« %s » : référence %d, minimum de l'orbite %d" % [classes[c]["nom"], classes[c]["bits"], minimum])

	_dire(MB.pieces_a_sculpter().size() == A_SCULPTER,
		"%d pièces à sculpter, il en faut %d" % [MB.pieces_a_sculpter().size(), A_SCULPTER])
	print("   → %d classes, orbites totalisant 256, %d pièces à sculpter"
		% [classes.size(), MB.pieces_a_sculpter().size()])


# ── 6. le haut et le bas sont des invariants ────────────────────────────────────────────────────────

## ⚠ C'EST LA VÉRIFICATION QUI DIT QUE L'ORIENTATION SERT À QUELQUE CHOSE. Sous le groupe actif, le
## nombre de cellules pleines en BAS et en HAUT ne bouge pas : ce sont des invariants de classe. C'est
## exactement ce qui permet à l'artiste de mettre de l'herbe en haut et de la roche en bas.
func _le_haut_et_le_bas_sont_des_invariants() -> void:
	print("\n6. « bas » et « haut » sont invariants sous le groupe actif")
	for b in 256:
		var bas := 0
		var haut := 0
		for t in MB.BAS:
			if b & (1 << t):
				bas += 1
		for t in MB.HAUT:
			if b & (1 << t):
				haut += 1
		for r in MB.rotations_actives():
			var t2: int = _tourner(b, r["coins"])
			var bas2 := 0
			var haut2 := 0
			for t in MB.BAS:
				if t2 & (1 << t):
					bas2 += 1
			for t in MB.HAUT:
				if t2 & (1 << t):
					haut2 += 1
			if bas2 != bas or haut2 != haut:
				_dire(false, "configuration %d tournée par %d : (%d,%d) devient (%d,%d)"
					% [b, r["index"], bas, haut, bas2, haut2])
				return
	_ok += 1

	# La répartition des classes par nombre de cellules hautes, recalculée ici.
	var classes: Array = MB.classes()
	var par_haut := [0, 0, 0, 0, 0]
	var grille := {}
	for c in classes:
		par_haut[c["haut"]] += 1
		var cle := "%d,%d" % [c["bas"], c["haut"]]
		grille[cle] = grille.get(cle, 0) + 1
		_dire(c["bas"] + c["haut"] == c["pleines"],
			"« %s » : bas %d + haut %d ≠ %d pleines" % [c["nom"], c["bas"], c["haut"], c["pleines"]])
	var attendu := [PAR_HAUT[4], PAR_HAUT[3], PAR_HAUT[2], PAR_HAUT[1], PAR_HAUT[0]]
	_dire(par_haut == attendu, "répartition par haut %s, on attend %s" % [str(par_haut), str(attendu)])

	# ⚠ DEUX SYMÉTRIES STRUCTURELLES, GRATUITES ET SÉVÈRES : la grille (bas, haut) est symétrique par
	# échange des deux (on retourne le cube), et par complément (on échange matière et vide).
	for bas in 5:
		for haut in 5:
			var ici: int = grille.get("%d,%d" % [bas, haut], 0)
			_dire(ici == grille.get("%d,%d" % [haut, bas], 0),
				"(%d,%d) compte %d, (%d,%d) devrait compter pareil" % [bas, haut, ici, haut, bas])
			_dire(ici == grille.get("%d,%d" % [4 - bas, 4 - haut], 0),
				"(%d,%d) compte %d, son complément (%d,%d) devrait compter pareil"
					% [bas, haut, ici, 4 - bas, 4 - haut])
	print("   → bas/haut invariants, répartition %s, symétrique dans les deux sens" % str(par_haut))


# ── 7. les noms ─────────────────────────────────────────────────────────────────────────────────────

func _les_noms_sont_derives_et_uniques() -> void:
	print("\n7. les noms sont dérivés, uniques et lisibles")
	var vus := {}
	var avec_suffixe := 0
	for c in MB.classes():
		var nom: String = c["nom"]
		_dire(not vus.has(nom), "le nom « %s » est porté deux fois" % nom)
		vus[nom] = true
		_dire(nom.begins_with("mb_"), "« %s » ne porte pas le préfixe mb_" % nom)
		# Le nom DIT le bas et le haut : c'est ce qui le rend lisible pour le sculpteur.
		_dire(nom.contains("_b%dh%d" % [c["bas"], c["haut"]]),
			"« %s » devrait contenir _b%dh%d" % [nom, c["bas"], c["haut"]])
		if nom.get_slice("_", nom.get_slice_count("_") - 1).length() == 1:
			avec_suffixe += 1
	_dire(vus.size() == CLASSES_ATTENDUES,
		"%d noms distincts, il en faut %d" % [vus.size(), CLASSES_ATTENDUES])
	print("   → %d noms distincts, dont %d désambiguïsés par un suffixe" % [vus.size(), avec_suffixe])


# ── 8. les familles ─────────────────────────────────────────────────────────────────────────────────

## ⚠ LES FAMILLES NE DÉPENDENT PAS DU GROUPE : ce sont les 23 silhouettes du repli complet. Tout ce qui
## a été mesuré sur elles reste vrai, et sert ici de socle stable.
func _les_familles_tiennent_toujours() -> void:
	print("\n8. les 23 familles (repli complet) tiennent toujours")
	var familles: Array = MB.familles()
	_dire(familles.size() == 23, "%d familles, il en faut 23" % familles.size())

	var attendue := [1, 1, 3, 3, 7, 3, 3, 1, 1]
	var compte := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var orbites := 0
	for f in familles:
		compte[f["pleines"]] += 1
		orbites += f["orbite"]
	_dire(compte == attendue, "distribution %s au lieu de %s" % [str(compte), str(attendue)])
	_dire(orbites == 256, "les orbites de famille totalisent %d au lieu de 256" % orbites)

	# Compléments : 8 paires + 7 auto-complémentaires, et les 7 sont les familles à quatre cellules.
	var par_bits := {}
	for i in familles.size():
		par_bits[familles[i]["bits"]] = i
	var famille_de := {}
	for b in 256:
		for i in familles.size():
			var trouve := false
			for r in MB.ROTATIONS:
				if _tourner(familles[i]["bits"], r["coins"]) == b:
					famille_de[b] = i
					trouve = true
					break
			if trouve:
				break
	var paires := {}
	var auto := 0
	for i in familles.size():
		var autre: int = famille_de[MB.complement(familles[i]["bits"])]
		if autre == i:
			auto += 1
			_dire(familles[i]["pleines"] == 4,
				"« %s » est son propre complément mais a %d cellules pleines"
					% [familles[i]["nom"], familles[i]["pleines"]])
		else:
			paires[str(mini(i, autre)) + "-" + str(maxi(i, autre))] = true
	_dire(auto == 7, "%d familles auto-complémentaires, il en faut 7" % auto)
	_dire(paires.size() == 8, "%d paires complémentaires, il en faut 8" % paires.size())

	# Une seule paire chirale — celle des vrilles.
	var chirales: Array = []
	for f in familles:
		if f["chirale"]:
			chirales.append(f["nom"])
	chirales.sort()
	_dire(chirales == ["mb_vrille_d", "mb_vrille_g"],
		"familles chirales : %s, on attend les deux vrilles" % str(chirales))
	print("   → 23 familles, distribution %s, 8 paires + 7 auto, une paire chirale" % str(compte))


# ── 9. LE CONTRAT DE COUTURE ────────────────────────────────────────────────────────────────────────

func _le_contrat_de_couture_tient() -> void:
	print("\n9. le contrat de couture : deux voisines présentent la MÊME face")
	# ⚠ EXHAUSTIF, ET INDÉPENDANT DU GROUPE : la face ne dépend que des quatre cellules communes.
	for axe in [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)]:
		var ici := "x+" if axe.x == 1 else ("y+" if axe.y == 1 else "z+")
		var la := "x-" if axe.x == 1 else ("y-" if axe.y == 1 else "z-")
		var cellules: Array = []
		for t in 8:
			cellules.append(MB.COINS[t])
		for t in 8:
			var c: Vector3i = axe + MB.COINS[t]
			if not cellules.has(c):
				cellules.append(c)
		var faux := 0
		for masque in (1 << cellules.size()):
			var pleines := {}
			for i in cellules.size():
				if masque & (1 << i):
					pleines[cellules[i]] = true
			var a := _forme_nommee(MB.faces_de(MB.bits(pleines, Vector3i.ZERO)), ici)
			var b := _forme_nommee(MB.faces_de(MB.bits(pleines, axe)), la)
			if a != b:
				faux += 1
				if faux <= 3:
					_dire(false, "axe %s, remplissage %d : %s dit « %s », %s dit « %s »"
						% [str(axe), masque, ici, a, la, b])
		_dire(faux == 0, "axe %s : %d désaccords sur %d remplissages"
			% [str(axe), faux, 1 << cellules.size()])
		print("   axe %s : %d remplissages, aucun désaccord" % [str(axe), 1 << cellules.size()])

	var atteintes := {}
	for b in 256:
		for f in MB.faces_de(b):
			atteintes[f["forme"]] = true
	_dire(atteintes.size() == 6, "%d formes de face employées, il en faut 6" % atteintes.size())
	_dire(not MB.pont_sur_face_ambigue(),
		"le défaut doit rester « jamais de pont » — deux massifs qui se touchent par un coin laissent "
		+ "le passage OUVERT")
	# Le damier porte six faces ambiguës — le cas le plus dur, et c'est une famille.
	for f in MB.familles():
		if f["nom"] == "mb_damier":
			var n := 0
			for face in MB.faces_de(f["bits"]):
				if face["forme"] == "diagonale":
					n += 1
			_dire(n == 6, "le damier devrait porter 6 faces ambiguës, pas %d" % n)
	print("   → 6 formes de face, le damier en porte 6 d'ambiguës, jamais de pont")


func _forme_nommee(faces: Array, nom: String) -> String:
	for f in faces:
		if f["nom"] == nom:
			return f["forme"]
	return "?"


# ── 10. les germes de bordure ───────────────────────────────────────────────────────────────────────

## ⚠ LE VRAI CAHIER DES CHARGES DE BORDURE. En modèle libre il y a 6 germes ; en modèle orienté il y en
## a 28, car un germe de SOL n'est plus un germe de MUR. C'est le prix de l'orientation sur la bordure,
## et il reste bien plus petit que le nombre de pièces : 28 bordures pour 68 pièces.
func _les_germes_de_bordure() -> void:
	print("\n10. les germes de bordure")
	var germes: Array = MB.germes()
	_dire(germes.size() == GERMES, "%d germes, il en faut %d" % [germes.size(), GERMES])
	var horizontaux := 0
	var couverture := 0
	for g in germes:
		if g["horizontal"]:
			horizontaux += 1
		couverture += g["faces"]
	_dire(horizontaux == GERMES_HORIZONTAUX,
		"%d germes horizontaux, il en faut %d" % [horizontaux, GERMES_HORIZONTAUX])
	_dire(germes.size() - horizontaux == GERMES_VERTICAUX,
		"%d germes verticaux, il en faut %d" % [germes.size() - horizontaux, GERMES_VERTICAUX])
	# ⚠ Les germes doivent couvrir exactement les 6 × 16 = 96 couples (face, configuration).
	_dire(couverture == 96, "les germes couvrent %d couples (face, configuration) au lieu de 96" % couverture)
	print("   → %d germes (%d horizontaux, %d verticaux) couvrant les 96 couples"
		% [germes.size(), horizontaux, germes.size() - horizontaux])


# ── 11. l'échantillonnage ───────────────────────────────────────────────────────────────────────────

func _l_echantillonnage_est_coherent() -> void:
	print("\n11. une cellule peinte touche exactement huit sommets")
	var cellule := Vector3i(3, -2, 5)
	var sommets: Array = MB.sommets_de(cellule)
	_dire(sommets.size() == 8, "%d sommets touchés, il en faut 8" % sommets.size())
	var distincts := {}
	for s in sommets:
		distincts[s] = true
	_dire(distincts.size() == 8, "%d sommets DISTINCTS, il en faut 8" % distincts.size())
	var pleines := {cellule: true}
	for s in sommets:
		_dire(MB.bits(pleines, s) != 0, "le sommet %s devrait voir la cellule" % str(s))
	_dire(MB.bits(pleines, cellule + Vector3i(2, 0, 0)) == 0,
		"un sommet à deux cases ne devrait pas voir la cellule")
	var seule: Dictionary = MB.classer(MB.bits(pleines, cellule))
	_dire(seule["famille"] == "mb_coin", "une cellule seule devrait être de famille mb_coin")
	_dire(seule["nom"] == "mb_coin_b1h0",
		"une cellule seule vue d'en haut devrait donner mb_coin_b1h0, pas « %s »" % seule["nom"])
	print("   → 8 sommets distincts, et une cellule seule donne %s" % seule["nom"])


# ── 12. les tuiles de RUN ───────────────────────────────────────────────────────────────────────────

## ⚠ ET C'EST ICI QUE SE VOIT CE QUE LE MODÈLE ORIENTÉ ACHÈTE : le sol plat rend `mb_plaque_b4h0`, le
## mur plat rend `mb_plaque_b2h2`. **Deux classes différentes, donc deux sculpts différents.** En modèle
## libre, c'était la même pièce couchée — et l'herbe serait partie sur le flanc.
func _les_tuiles_de_run_se_repetent() -> void:
	print("\n12. les tuiles de RUN : classe ET orientation CONSTANTES")
	for essai in [
		{"nom": "sol plat, axe x", "cellules": _pave(-4, 4, 0, 0, -4, 4),
			"depart": Vector3i(-2, 0, 0), "pas": Vector3i(1, 0, 0), "attendue": "mb_plaque_b4h0"},
		{"nom": "sol plat, axe z", "cellules": _pave(-4, 4, 0, 0, -4, 4),
			"depart": Vector3i(0, 0, -2), "pas": Vector3i(0, 0, 1), "attendue": "mb_plaque_b4h0"},
		{"nom": "mur vertical plat", "cellules": _pave(-4, 0, -4, 4, -4, 4),
			"depart": Vector3i(0, -2, 0), "pas": Vector3i(0, 1, 0), "attendue": "mb_plaque_b2h2"},
		{"nom": "falaise droite", "cellules": _pave(-4, 0, 0, 0, -4, 4),
			"depart": Vector3i(0, 0, -2), "pas": Vector3i(0, 0, 1), "attendue": "mb_arete_b2h0"},
		{"nom": "arête verticale convexe", "cellules": _pave(-4, 0, -4, 4, -4, 0),
			"depart": Vector3i(0, -2, 0), "pas": Vector3i(0, 1, 0), "attendue": "mb_arete_b1h1"},
	]:
		var cellules: Dictionary = essai["cellules"]
		var couples := {}
		var noms := {}
		for i in 5:
			var sommet: Vector3i = essai["depart"] + essai["pas"] * i
			var r: Dictionary = MB.classer(MB.bits(cellules, sommet))
			couples["%d/%d" % [r["classe"], r["orientation"]]] = true
			noms[r["nom"]] = true
		_dire(couples.size() == 1,
			"%s : %d couples (classe, orientation) le long du run, il en faut UN — %s"
				% [essai["nom"], couples.size(), str(couples.keys())])
		_dire(noms.has(essai["attendue"]),
			"%s : attendait « %s », a obtenu %s" % [essai["nom"], essai["attendue"], str(noms.keys())])
		print("   %-26s → %s  %s" % [essai["nom"], str(noms.keys()), str(couples.keys())])

	# ⚠ LA VÉRIFICATION QUI JUSTIFIE TOUT LE SURCOÛT : le sol et le mur ne sont PAS la même classe.
	var sol: Dictionary = MB.classer(MB.bits(_pave(-4, 4, 0, 0, -4, 4), Vector3i.ZERO))
	var mur: Dictionary = MB.classer(MB.bits(_pave(-4, 0, -4, 4, -4, 4), Vector3i.ZERO))
	_dire(sol["famille"] == mur["famille"], "le sol et le mur devraient être de la même FAMILLE")
	_dire(sol["classe"] != mur["classe"],
		"le sol et le mur plat doivent être deux CLASSES distinctes — c'est tout l'objet du modèle orienté")
	print("   → sol « %s » ≠ mur « %s », même famille « %s »" % [sol["nom"], mur["nom"], sol["famille"]])


## Un pavé plein de cellules, bornes INCLUSES.
func _pave(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> Dictionary:
	var cellules := {}
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				cellules[Vector3i(x, y, z)] = true
	return cellules


# ── 13. les symétries imposées ──────────────────────────────────────────────────────────────────────

## ⚠ LE THÉORÈME ORBITE-STABILISATEUR EST UN CONTRÔLE GRATUIT ET TRÈS SERRÉ : pour chaque classe,
## |orbite| × |stabilisateur| = |G|, sans exception.
##
## ⚠ ET LA COHÉRENCE QUI FAIT VIVRE LE MODÈLE : deux faces identifiées par le stabilisateur DOIVENT
## porter la même forme. Si une seule classe y manquait, l'idée d'un vocabulaire de germes partagé
## serait morte, et la couture avec.
func _les_symetries_imposees() -> void:
	print("\n13. les symétries imposées dans chaque bloc (stabilisateurs)")
	var classes: Array = MB.classes()
	var taille: int = MB.rotations_actives().size()
	var libres := 0
	for c in classes.size():
		var stab: Array = MB.stabilisateur(c)
		_dire(stab.has(0), "« %s » : le stabilisateur doit contenir l'identité" % classes[c]["nom"])
		_dire(stab.size() * classes[c]["orbite"] == taille,
			"« %s » : orbite %d × stabilisateur %d ≠ %d"
				% [classes[c]["nom"], classes[c]["orbite"], stab.size(), taille])
		if stab.size() == 1:
			libres += 1
		var formes := {}
		for f in MB.faces_de(classes[c]["bits"]):
			formes[f["nom"]] = f["forme"]
		var couvertes := {}
		for groupe in MB.faces_identifiees(c):
			var reference := ""
			for nom in groupe:
				couvertes[nom] = true
				if reference == "":
					reference = formes[nom]
				else:
					_dire(formes[nom] == reference,
						"« %s » : les faces %s sont identifiées mais portent « %s » et « %s »"
							% [classes[c]["nom"], str(groupe), reference, formes[nom]])
		_dire(couvertes.size() == 6,
			"« %s » : les groupes de faces en couvrent %d sur 6" % [classes[c]["nom"], couvertes.size()])
	print("   → %d stabilisateurs, orbite × stabilisateur = %d partout, %d classes totalement libres"
		% [classes.size(), taille, libres])


# ── 14. le lieu et la matière ───────────────────────────────────────────────────────────────────────

## ⚠ **`sous_le_ciel()` ET `case_sous_roche()` SE RESSEMBLENT ET RÉPONDENT À DEUX QUESTIONS.** L'une
## qualifie un LIEU DE POSE — le sommet où une pièce ira, et elle sonde les huit colonnes à partir de
## `sommet.y + 2` parce que les deux étages de la pièce ne se coiffent pas eux-mêmes. L'autre qualifie
## un MORCEAU DE MATIÈRE — une case pleine, pour la peindre dans le témoin, et elle ne regarde que SA
## colonne, dès la case juste au-dessus.
##
## ⚠ **LE SCÉNARIO EST CONSTRUIT POUR QUE LES DEUX RÉPONSES DIFFÈRENT**, sinon rien ne garderait la
## distinction : le jour où quelqu'un les fusionnera « puisqu'elles font la même chose », ce contrôle
## doit rougir. ⚠ Et les attendus sont écrits à la main, jamais calculés par les fonctions éprouvées —
## c'est la faute que `test_massif_peint` a déjà payée : un attendu qui bouge avec le mesuré rend toute
## mutation muette.
func _le_lieu_et_la_matiere_sont_deux_questions() -> void:
	print("\n14. le lieu de pose et le morceau de matière — deux questions distinctes")

	# Un auvent : un socle plein en y = 0..1 sur 4 × 4, et une dalle en y = 3 qui ne couvre QUE la
	# moitié x ≤ 1. La colonne x = 3 reste à ciel ouvert de bout en bout.
	var pleines: Dictionary = _pave(0, 3, 0, 1, 0, 3)
	for x in 2:
		for z in 4:
			pleines[Vector3i(x, 3, z)] = true
	var plafond := 3

	_dire(MB.plafond_de(pleines) == plafond,
		"le plafond dérivé doit être %d, pas %d" % [plafond, MB.plafond_de(pleines)])

	# ── la MATIÈRE : ce qui a quelque chose de plein au-dessus, dans SA colonne ──
	_dire(MB.case_sous_roche(pleines, Vector3i(0, 0, 0), plafond),
		"(0,0,0) porte (0,1,0) et la dalle au-dessus : sous roche")
	_dire(MB.case_sous_roche(pleines, Vector3i(0, 1, 0), plafond),
		"(0,1,0) est coiffée par la dalle PAR-DESSUS UN VIDE : sous roche quand même")
	_dire(not MB.case_sous_roche(pleines, Vector3i(0, 3, 0), plafond),
		"la dalle elle-même n'a rien au-dessus : à l'air libre")
	_dire(MB.case_sous_roche(pleines, Vector3i(3, 0, 0), plafond),
		"(3,0,0) porte (3,1,0) : sous roche, même hors de l'auvent")
	_dire(not MB.case_sous_roche(pleines, Vector3i(3, 1, 0), plafond),
		"(3,1,0) est le sommet d'une colonne non couverte : à l'air libre")
	_dire(not MB.case_sous_roche(pleines, Vector3i(9, 9, 9), plafond),
		"une case hors de l'occupation n'a rien au-dessus d'elle")

	# ── LE LIEU : le sommet (2,1,1) a ses huit cases en x = 2..3, donc HORS de l'auvent, et
	# `sous_le_ciel` balaie à partir de y = 3 — la dalle ne l'atteint pas.
	_dire(MB.sous_le_ciel(pleines, Vector3i(2, 1, 1), plafond),
		"le sommet (2,1,1) est hors de l'auvent : c'est un lieu de pose à l'air libre")
	# ⚠ ET LE COUPLE QUI SÉPARE LES DEUX FONCTIONS, AU MÊME ENDROIT. La matière de (3,0,0) est
	# ENTERRÉE — (3,1,0) la couvre — tandis que le lieu de pose (2,1,1), qui la touche, est à CIEL
	# OUVERT. Les deux disent « oui » à des questions de polarité opposée : écrire l'une comme la
	# négation de l'autre ferait tomber la première à faux.
	_dire(MB.case_sous_roche(pleines, Vector3i(3, 0, 0), plafond)
			and MB.sous_le_ciel(pleines, Vector3i(2, 1, 1), plafond),
		"au même endroit : la matière (3,0,0) doit être enterrée ET le lieu (2,1,1) à ciel ouvert")
	# Le sommet (0,1,1) est SOUS l'auvent : ses colonnes portent la dalle en y = 3.
	_dire(not MB.sous_le_ciel(pleines, Vector3i(0, 1, 1), plafond),
		"le sommet (0,1,1) est coiffé par la dalle : ce n'est pas un lieu à l'air libre")
	# ⚠ ET LA CORRECTION QUI A COÛTÉ QUATRE TOURS : une pièce ne se coiffe pas elle-même. Le sommet
	# (0,2,1) a ses cases en y = 2..3, dont la dalle ; partir de `sommet.y + 1` le déclarerait couvert.
	_dire(MB.sous_le_ciel(pleines, Vector3i(0, 2, 1), plafond),
		"une pièce ne se coiffe pas elle-même : (0,2,1) reste un lieu à l'air libre")
	print("   → sous l'auvent et à côté, le lieu et la matière donnent bien des réponses différentes")
