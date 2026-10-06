extends "res://DEV_TOOLS/filmer_ui.gd"
##
## DEVLOG — LES BORDS PARTAGÉS ENTRE COUCHES : « plus de fente où deux couches se touchent » (commit 6e272dc, 6 octobre
## 2026). Demandé par Jordan le même jour : « fait un dev log pour chaque nouveauté ».
##
## L'HISTOIRE, TOUTE AVEC LE VRAI PRODUIT :
##   1. une scène de roche (la couche GreyRock de l'exemple, son témoin sculpté par Jordan) ;
##   2. « New layer » : une couche neuve part du TÉMOIN CALCULÉ — c'est l'un des cas réels de divergence que la charte
##      du produit nomme (« une couche neuve sur le témoin calculé quand l'active est sculptée ») ; on la peint sur la
##      moitié de la scène ;
##   3. à leur frontière, une FENTE : on voit la mer au travers (rien n'est exagéré — mesuré par `sonde_bords_film.gd` :
##      31 joints ouverts de 0,35 à 0,75 case sur cette scène) ;
##   4. GreyRock active, Geometry, Tab : la section Mesh le DIT (« N point(s) differ ») ; « Match other layers to this
##      one » ; World : la frontière est fermée (0 joint ouvert, même sonde) ;
##   5. un geste G sur un sommet de BORD d'une tuile de GreyRock : la nouvelle couche suit, la frontière reste fermée ;
##      Ctrl+Z ; puis le Play test au soleil bas sur la frontière, et l'exemple entier vu de loin.
##
## ⚠ POURQUOI PAS « UN GESTE SUR LA COUCHE B SEULE » POUR CRÉER LA DIVERGENCE : depuis 6e272dc, un geste sur un bord de B
## ENTRAÎNE A — c'est justement la nouveauté. On ne peut plus fabriquer de fente par un geste ; elle vient des cas que le
## bouton rattrape (une couche neuve sur le témoin calculé, un projet d'avant, un témoin revenu de Blender).
##
## Hérite des gestes et des aides de tournage de filmer_ui.gd (vrais événements ; curseur et carte de touche dessinés).
##
## LANCEMENT — dans une COPIE de tournage (worktree à dossier de données à part, 1920 × 1080) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_bords.gd D:/MB_tournage_bords/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MB_tournage_bords --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/bords.avi --script res://DEV_TOOLS/filmer_bords.gd

## LA SCÈNE — une règle, un endroit. Loin de l'exemple (qui s'étend jusqu'à x = 153), au-dessus de la mer : la mer se
## voit AU TRAVERS de la fente. A (GreyRock) à l'ouest de FRONTIERE_X, la couche neuve à l'est.
const O := Vector3i(170, 20, 0)
const LARGEUR := 16
const PROFONDEUR := 12
const FRONTIERE_X := 178.0
## Les marches : le dessus est à +3 (z ≥ 6), +4 (3 ≤ z < 6), +5 (z < 3) au-dessus de O.y — la frontière traverse les
## dessus, les contremarches et les arêtes.

var _a := {}
var _b := {}


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_scene()
	_ecran._activer(_couche["GreyRock"])
	_ecran._appliquer({"poser": _a.merged(_b), "effacer": {}}, "Add")
	_aides()
	_poser_camera(Vector3(FRONTIERE_X, O.y + 5, O.z + 6), -0.4, 0.5, 15.0)
	await _images(20)
	for partie in ["neuve", "fente", "dire", "caler", "geste", "jeu", "large"]:
		if _seulement != "" and _seulement != partie and not partie in ["neuve"]:
			continue
		_plan(partie)
		await Callable(self, "_b_" + partie).call()
		await _images(int(0.4 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


func _scene() -> void:
	for x in LARGEUR:
		for z in PROFONDEUR:
			var dessus := 3
			if z < 6:
				dessus = 4
			if z < 3:
				dessus = 5
			for y in range(0, dessus + 1):
				var c := O + Vector3i(x, y, z)
				if O.x + x < FRONTIERE_X:
					_a[c] = true
				else:
					_b[c] = true


# ── 1. LA COUCHE NEUVE ───────────────────────────────────────────────────────────────────────────────

func _b_neuve() -> void:
	_montrer("GreyRock", "A layer of the example, with its own sculpted witness")
	await _orbite(-0.4, 0.15, 15.0, 13.0, 3.0)
	var avant: int = _ecran._couches.size()
	await _cliquer_bouton("New layer", "A new layer starts from the computed witness")
	await _images(10)
	if _ecran._couches.size() == avant:
		print("⚠ le clic sur New layer n'a rien créé")
	_montrer("Paint", "The new layer, right next to the rock")
	var xs := range(int(FRONTIERE_X), O.x + LARGEUR)
	for k in range(0, xs.size(), 2):
		var part := {}
		for c in _b:
			if c.x == xs[k] or (k + 1 < xs.size() and c.x == xs[k + 1]):
				part[c] = true
		_ecran._appliquer({"poser": part, "effacer": {}}, "Add")
		await _orbite(_vue._azimut, _vue._azimut + 0.03, _vue._distance, _vue._distance, 0.35)
	await _orbite(_vue._azimut, _vue._azimut + 0.15, _vue._distance, 12.0, 1.5)


# ── 2. LA FENTE ──────────────────────────────────────────────────────────────────────────────────────

func _b_fente() -> void:
	_montrer("Two witnesses", "Where the two layers meet, their tiles do not join")
	await _glisser_vers(Vector3(FRONTIERE_X, O.y + 4, O.z + 9.5), -1.2, 0.6, 5.0, 2.0)
	_montrer("A gap", "The sea shows through it")
	await _travelling(Vector3(FRONTIERE_X, O.y + 4, O.z + 10.5), Vector3(FRONTIERE_X, O.y + 4.5, O.z + 4.0), -1.2, 0.6, 5.0, 4.0)
	await _glisser_vers(Vector3(FRONTIERE_X, O.y + 4.5, O.z + 5.0), -0.6, 0.35, 8.0, 2.0)
	await _images(int(1.0 * FPS))


# ── 3. GEOMETRY LE DIT ───────────────────────────────────────────────────────────────────────────────

func _b_dire() -> void:
	await _cliquer_couche("GreyRock", "Make the rock layer active")
	await _cliquer_bouton("Geometry", "Geometry workshop")
	await _images(15)
	await _touche(KEY_TAB, "Tab", "Edit the witness of GreyRock")
	_cadrer_le_temoin()
	await _images(int(1.5 * FPS))
	var l: Label = _ecran._ecarts_texte
	if l == null or not l.is_visible_in_tree():
		print("⚠ la ligne des écarts n'est pas visible")
		return
	await _faire_voir(l)
	await _vers_le_controle(l, 0.8)
	_montrer("Geometry", "\"%s\"" % _court(l.text))
	await _images(int(3.0 * FPS))


# ── 4. LE BOUTON, ET LE MONDE FERMÉ ─────────────────────────────────────────────────────────────────

func _b_caler() -> void:
	await _cliquer_bouton("Match other layers to this one", "Match other layers to this one")
	await _images(int(1.4 * FPS))
	var l: Label = _ecran._ecarts_texte
	if l != null:
		_montrer("Geometry", "\"%s\"" % _court(l.text))
	await _images(int(2.2 * FPS))
	_montrer("Honest", "What it cannot match, it says (the report, bottom left)")
	await _images(int(2.2 * FPS))
	await _cliquer_bouton("World", "Back to World")
	await _images(15)
	_poser_camera(Vector3(FRONTIERE_X, O.y + 5, O.z + 6), -0.4, 0.5, 13.0)
	await _images(10)
	_montrer("Closed", "The new layer took the rock's borders")
	await _glisser_vers(Vector3(FRONTIERE_X, O.y + 4, O.z + 9.5), -1.2, 0.6, 5.0, 2.0)
	await _travelling(Vector3(FRONTIERE_X, O.y + 4, O.z + 10.5), Vector3(FRONTIERE_X, O.y + 4.5, O.z + 4.0), -1.2, 0.6, 5.0, 4.0)
	await _images(int(0.6 * FPS))


# ── 5. UN GESTE SUR UN BORD ENTRAÎNE L'AUTRE COUCHE ─────────────────────────────────────────────────

func _b_geste() -> void:
	await _cliquer_bouton("Geometry", "Geometry workshop")
	await _images(15)
	if not _vue.edition:
		await _touche(KEY_TAB, "Tab", "Edit the witness")
	var mo: Node3D = _ecran._modeleur
	_cadrer_le_temoin()
	await _touche(KEY_1, "1", "Vertex mode")
	# La tuile du dessus plat (la plus posée sur la scène), et l'un de ses sommets de BORD, au milieu d'un côté.
	var cle := _tuile_du_dessus()
	var occs: Array = mo.temoin.occurrences_de(cle)
	if occs.is_empty():
		print("⚠ pas d'occurrence de %s" % cle)
		return
	mo.activer(int(occs[0]))
	mo.sections.indexer()
	var i_bord := _sommet_de_bord(mo)
	if i_bord < 0:
		print("⚠ pas de sommet de bord")
		return
	var p: Vector3 = mo.pose * (mo.maillage.sommets[i_bord] as Vector3)
	_poser_camera(p, 0.7, 0.55, 4.5)
	await _images(10)
	# Le clic, un peu DANS la tuile (le rayon doit toucher l'une de ses faces) : le sommet le plus proche est pris.
	var centre: Vector3 = mo.pose * Vector3.ZERO
	var vise: Vector3 = p.lerp(Vector3(centre.x, p.y, centre.z), 0.12)
	await _bouger(_sur(vise), 0.7)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "A vertex on the border of a rock tile")
	if not mo.sel_s.has(i_bord):
		print("⚠ le clic a pris %s (%s) au lieu de %d : sélection posée" % [mo.sel_s.keys(), mo.cle, i_bord])
		if mo.cle != cle:
			mo.activer(int(occs[0]))
		mo.tout_choisir(false)
		mo.sel_s = {i_bord: true}
		mo._dessiner_selection()
	var ta: RefCounted = mo.temoin
	var tb: RefCounted = _ecran._temoin_de(_ecran._couches[_couche_neuve()])
	var photo_b := {}
	for c in tb.tuiles:
		photo_b[c] = (tb.tuiles[c].sommets as PackedVector3Array).duplicate()
	await _touche(KEY_G, "G", "Grab")
	await _touche(KEY_Z, "Z", "Up")
	_montrer("0 . 4", "Four tenths of a cell")
	for k in [KEY_0, KEY_PERIOD, KEY_4]:
		_cle(k, true)
		await _images(3)
		_cle(k, false)
		await _images(6)
	await _images(int(0.6 * FPS))
	await _touche(KEY_ENTER, "Enter", "Every copy of the tile follows — in every layer")
	var suit := 0
	for c in tb.tuiles:
		if tb.tuiles[c].sommets != photo_b[c]:
			suit += 1
	print("GESTE : %d tuiles de la couche neuve suivent, bride %.2f, témoin A %s" % [suit, mo.bride, ta != null])
	await _images(int(1.4 * FPS))
	await _cliquer_bouton("World", "Back to World")
	await _images(15)
	_poser_camera(Vector3(FRONTIERE_X, O.y + 5, O.z + 6), -0.4, 0.5, 13.0)
	await _images(10)
	_montrer("Both layers moved", "And where they meet, still no gap")
	await _glisser_vers(Vector3(FRONTIERE_X, O.y + 4, O.z + 9.5), -1.2, 0.6, 5.0, 2.0)
	await _travelling(Vector3(FRONTIERE_X, O.y + 4, O.z + 10.5), Vector3(FRONTIERE_X, O.y + 4.5, O.z + 4.0), -1.2, 0.6, 5.0, 3.5)
	await _touche(KEY_Z, "Ctrl + Z", "One undo, for every layer", true)
	# ⚠ EN WORLD, Ctrl+Z D'UN GESTE DU TÉMOIN NE REFAIT PAS LE MONDE : il suit à la prochaine entrée dans World.
	_plan("rhabiller")
	_ecran._changer_d_atelier("witness")
	await _images(5)
	await _ecran._changer_d_atelier("monde")
	_poser_camera(Vector3(FRONTIERE_X, O.y + 4.5, O.z + 4.0), -1.2, 0.6, 5.0)
	await _images(int(1.5 * FPS))


# ── 6. LE PLAY TEST, AU SOLEIL BAS, SUR LA FRONTIÈRE ────────────────────────────────────────────────

func _b_jeu() -> void:
	_poser_camera(Vector3(FRONTIERE_X - 5.5, O.y + 4, O.z + 9.5), 1.57, 0.4, 8.0)
	await _images(5)
	await _cliquer_bouton("Play test", "Play test")
	await _images(int(1.0 * FPS))
	for reglage in [["soleil_hauteur", 16.0], ["soleil_azimut", 200.0], ["soleil_couleur", Color(1.0, 0.86, 0.68)],
			["soleil_energie", 1.6], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 0.8]]:
		_vue.regler_rendu(reglage[0], reglage[1])
	await _images(int(0.8 * FPS))
	_montrer("Play test", "Walk from the rock onto the new layer")
	_vue._azimut = -PI * 0.5
	_cle(KEY_W, true)
	await _images(int(3.2 * FPS))
	_cle(KEY_W, false)
	await _images(int(0.8 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	await _images(10)


# ── 7. LE MONDE ENTIER ───────────────────────────────────────────────────────────────────────────────

func _b_large() -> void:
	_vue.cadrer_toute_la_matiere()
	var az: float = _vue._azimut
	var d: float = _vue._distance
	_montrer("All layers", "Match moved the borders of the example's layers too")
	await _orbite(az, az + 0.5, d, d * 0.85, 5.0)


# ── L'OUTILLAGE PROPRE À CE DEVLOG ───────────────────────────────────────────────────────────────────

func _cadrer_le_temoin() -> void:
	var mo: Node3D = _ecran._modeleur
	if mo.temoin == null:
		return
	# Tout le témoin (ses 1056 copies liées), vu du dehors : la boîte de leurs poses.
	var boite := AABB((mo.temoin.occurrences[0]["pose"] as Transform3D).origin, Vector3.ZERO)
	for o in mo.temoin.occurrences:
		boite = boite.expand((o["pose"] as Transform3D).origin)
	_poser_camera(boite.get_center(), 0.7, 0.6, boite.size.length() * 1.1)


## ⚠ UN BOUTON PEUT ÊTRE DANS L'ÉCRAN MAIS CACHÉ PAR SON PANNEAU DÉFILANT (« New layer », sous la liste des couches) :
## la molette fait défiler ce panneau jusqu'à ce que le bouton y tienne, puis on attend que le défilement s'arrête.
func _cliquer_bouton(texte: String, detail: String, infobulle := "") -> void:
	var b := _bouton(_ecran, texte, infobulle)
	if b == null:
		print("⚠ bouton introuvable : %s" % texte)
		return
	await _cliquer_controle(b, detail)


func _cliquer_controle(b: Control, detail: String) -> void:
	await _faire_voir(b)
	await _bouger(b.get_global_rect().get_center(), 0.6)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)


func _faire_voir(b: Control) -> void:
	var defile: Node = b.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile != null:
		var zone: Rect2 = (defile as Control).get_global_rect().intersection(Rect2(Vector2(0, 40), Vector2(root.size) - Vector2(0, 40)))
		if not zone.encloses(b.get_global_rect()):
			await _bouger(zone.get_center(), 0.4)
			var sens := MOUSE_BUTTON_WHEEL_DOWN if b.get_global_rect().end.y > zone.end.y else MOUSE_BUTTON_WHEEL_UP
			for i in 60:
				if zone.encloses(b.get_global_rect()):
					break
				_presser(sens, true)
				_presser(sens, false)
				await _images(2)
			await _images(12)


func _orbite(az0: float, az1: float, d0: float, d1: float, duree: float) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i + 1) / n)
		_vue._azimut = lerpf(az0, az1, t)
		_vue._distance = lerpf(d0, d1, t)
		_vue._caler()
		await _images(1)


func _glisser_vers(cible: Vector3, az: float, el: float, d: float, duree: float) -> void:
	var c0: Vector3 = _vue._cible
	var a0: float = _vue._azimut
	var e0: float = _vue._elevation
	var d0: float = _vue._distance
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i + 1) / n)
		_vue._cible = c0.lerp(cible, t)
		_vue._azimut = lerp_angle(a0, az, t)
		_vue._elevation = lerpf(e0, el, t)
		_vue._distance = lerpf(d0, d, t)
		_vue._caler()
		await _images(1)


func _travelling(de: Vector3, a: Vector3, az: float, el: float, d: float, duree: float) -> void:
	var n := int(duree * FPS)
	for i in n:
		var t := float(i + 1) / n
		_vue._cible = de.lerp(a, t)
		_vue._azimut = az
		_vue._elevation = el
		_vue._distance = d
		_vue._caler()
		await _images(1)


func _vers_le_controle(c: Control, duree: float) -> void:
	await _bouger(c.get_global_rect().get_center() + Vector2(c.get_global_rect().size.x * 0.3, 0), duree)


func _cliquer_couche(nom: String, detail: String) -> void:
	var b := _ligne_de_couche(_ecran, nom)
	if b == null:
		print("⚠ ligne de couche introuvable : %s" % nom)
		_ecran._activer(_couche[nom])
		return
	await _cliquer_controle(b, detail)
	if _ecran._active != _couche[nom]:
		print("⚠ le clic n'a pas activé %s" % nom)
		_ecran._activer(_couche[nom])


func _ligne_de_couche(n: Node, nom: String) -> Button:
	if n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.begins_with(nom + "\n"):
		return n
	for e in n.get_children():
		var t := _ligne_de_couche(e, nom)
		if t != null:
			return t
	return null


func _couche_neuve() -> int:
	for i in _ecran._couches.size():
		if not _couche.has(str(_ecran._couches[i].get("nom", ""))):
			return i
	return _ecran._couches.size() - 1


## La tuile la plus posée par GreyRock sur la scène (le dessus plat) : lue dans SA grille de rendu.
func _tuile_du_dessus() -> String:
	var g := _vue.couche(_couche["GreyRock"]).get_node("Rendu") as GridMap
	var compte := {}
	for c in g.get_used_cells():
		if c.x >= O.x and c.x < int(FRONTIERE_X) and c.z >= O.z and c.z < O.z + PROFONDEUR and c.y >= O.y + 3:
			var nom := g.mesh_library.get_item_name(g.get_cell_item(c))
			compte[nom] = compte.get(nom, 0) + 1
	var meilleure := ""
	for nom in compte:
		if meilleure == "" or compte[nom] > compte[meilleure]:
			meilleure = nom
	print("TUILES DU DESSUS ", compte, " → ", meilleure)
	var mo: Node3D = _ecran._modeleur
	if not mo.temoin.tuiles.has(meilleure):
		for c in mo.temoin.tuiles:
			if meilleure.begins_with(c) or c.begins_with(meilleure):
				return c
	return meilleure


## Un sommet de BORD de la tuile en édition, sur UN seul plan (pas sur une arête de case), dont le plan est vertical
## dans le monde, le plus haut possible (sur le dessus), le plus près du milieu de son côté.
func _sommet_de_bord(mo: Node3D) -> int:
	var cle: String = mo.cle
	var meilleur := -1
	var note := -INF
	for i in (mo.sections.bords[cle] as Dictionary):
		var b: Array = mo.sections.bords[cle][i]
		if b.size() != 1:
			continue
		var axe_local: int = b[0]["axe"]
		var n_monde: Vector3 = (mo.pose.basis * _unitaire(axe_local)).abs()
		if n_monde.y > 0.5:
			continue
		var p: Vector3 = mo.pose * (mo.maillage.sommets[i] as Vector3)
		var centre: Vector3 = mo.pose * Vector3.ZERO
		var lateral := Vector2(p.x - centre.x, p.z - centre.z)
		var s := p.y * 4.0 - absf(lateral.dot(Vector2(n_monde.z, n_monde.x)))
		if s > note:
			note = s
			meilleur = i
	return meilleur


func _unitaire(axe: int) -> Vector3:
	var v := Vector3.ZERO
	v[axe] = 1.0
	return v


func _court(t: String) -> String:
	return t.replace("Borders: ", "").split(" — ")[0]
