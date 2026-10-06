extends "res://DEV_TOOLS/filmer_haut.gd"
##
## DEVLOG — L'ATELIER TRANSITIONS. Demandé par Jordan (6 octobre 2026 : « fait un dev log pour chaque nouveauté »). La
## playlist : D:/SpannerGames/PROJETS/MarchingBlocks/CLAUDE.md ; l'atelier : charte du produit §5, « L'atelier Transitions ».
##
## ⚠ CE QUE LE LOGICIEL IMPOSE, ET QUI DESSINE LE MONDE (relevé le 6 octobre 2026) :
##   - deux couches côte à côte AU MÊME NIVEAU font une frontière en marches de case (le devlog vu de haut l'évitait :
##     « sinon ça fait des carrés ») — c'est EXACTEMENT ce que Transitions adoucit : le monde de ce devlog les met côte à
##     côte exprès, sur un sol plat, puis sur des marches (le fondu suit les marches) ;
##   - la transition porte sur l'ASPECT, jamais sur la géométrie : une paire cochée ne change aucune tuile ;
##   - qui couvre : la couche la plus HAUTE de la liste (rang 0), sauf là où le pinceau « … covers » l'a choisi ; Up / Down
##     change l'ordre — donc qui couvre partout où rien n'est peint ;
##   - une paire a DEUX réglages (A couvre B, B couvre A) ; le pinceau ne touche que les sommets où les deux couches de la
##     paire CHOISIE se rencontrent ;
##   - les greffons ne l'ont pas encore (le manuel le dit) : la vidéo reste dans l'appli.
## Tout passe par de vrais événements (souris, clavier) ; le curseur et la carte de touche sont les deux aides de tournage
## de `filmer_ui.gd`.
##
## LANCEMENT — dans la COPIE de tournage (worktree à part, `custom_user_dir_name="MB_tournage_transitions"`) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_transitions.gd D:/MB_tournage_transitions/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MB_tournage_transitions --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/transitions.avi \
##       --script res://DEV_TOOLS/filmer_transitions.gd
##   `-- --seulement=<partie>` : franc, paires, reglages, sens, ordre, monde, jeu (le monde est toujours bâti).

## LE MONDE — x vers l'est, z vers le sud. Un sol plat (dessus en y = 0) où trois couches se touchent AU MÊME NIVEAU,
## puis des marches : une mesa de roche dans le sable, une colline d'herbe, une dune.
const TX0 := -26
const TX1 := 26
const TZ0 := -18
const TZ1 := 18
const T_FOND := -3
## Les trois zones : le centre de chacune (la plus proche l'emporte, distances bruitées).
const T_CENTRES := {"Grass": Vector2(-13, 5), "Desert": Vector2(13, 6), "GreyRock": Vector2(0, -11)}
## Les reliefs : [centre, rayons, montée, matière]. Deux entrées superposées = deux marches.
const T_RELIEFS := [
	[Vector2(9, -4), Vector2(5.5, 4.0), 1, "GreyRock"],     # la mesa de roche, au bord du sable
	[Vector2(9, -4), Vector2(3.0, 2.2), 2, "GreyRock"],
	[Vector2(-15, -5), Vector2(5.0, 4.0), 1, "Grass"],      # la colline d'herbe
	[Vector2(-15, -5), Vector2(2.5, 2.0), 2, "Grass"],
	[Vector2(16, 11), Vector2(5.0, 3.0), 1, "Desert"],      # une dune
]
## Le carrefour des trois zones (relu sur la carte au premier essai).
const T_CARREFOUR := Vector2(0, 0)

var _th := {}                # Vector2i → hauteur du dessus
var _tm := {}                # Vector2i → nom de couche
var _tbruit := FastNoiseLite.new()
var _tr: RefCounted          # l'atelier Transitions de l'écran
var _id := {}                # nom de couche → id


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	_tr = _ecran._transitions
	for i in _ecran._couches.size():
		var c: Dictionary = _ecran._couches[i]
		_couche[str(c.get("nom", ""))] = i
		_id[str(c.get("nom", ""))] = str(c.get("id", ""))
	print("couches (rang 0 = la plus haute de la liste) : %s, ids %s" % [_couche, _id])
	for c in _ecran._couches:
		var mats: Array = _tr.materiaux_de(c)
		print("matériaux de %s (représentant par défaut %d) :" % [c["nom"], _tr.indice_representant(c)])
		for k in mats.size():
			print("   %d %s %s %s" % [k, mats[k].get("nom", "?"), mats[k].get("couleur", ""), mats[k].get("texture", "")])
	if _seulement == "materiaux":
		_rendre_les_reglages()
		quit(0)
		return
	_cam_haut = false
	_aides()
	_plan("monde_bati")
	await _t_batir()
	# ⚠ « ordre » (Up / Down) N'EST PAS TOURNÉ : au premier tournage, après Up, la bande de transition restait à
	# l'ancienne frontière (la texture des rangs n'est pas refaite par la route rapide d'Up / Down) — un défaut du
	# produit, signalé, pas montré. `-- --seulement=ordre` le rejoue.
	var parties := ["franc", "paires", "reglages", "sens", "monde", "jeu"]
	if _seulement == "ordre":
		parties = ["paires", "ordre"]
	for partie in parties:
		if _seulement != "" and _seulement != partie and _seulement != "ordre":
			continue
		_plan(partie)
		await Callable(self, "_t_" + partie).call()
		await _images(int(0.4 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


# ── 0. LE MONDE : trois couches côte à côte, posées par le vrai pinceau de cases (`_appliquer`) ─────────

func _t_batir() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_t_relief()
	var par := {}
	for nom in _couche:
		par[nom] = {}
	for k in _th:
		for y in range(T_FOND, int(_th[k]) + 1):
			(par[_tm[k]] as Dictionary)[Vector3i(k.x, y, k.y)] = true
	for nom in par:
		print("monde : %s %d cases" % [nom, (par[nom] as Dictionary).size()])
	_regarder(Vector3(8, 46, 50), Vector3(0, 0, 0))
	await _images(10)
	for etape in [["GreyRock", "Layer · GreyRock", "Rock to the north, a mesa"],
			["Grass", "Layer · Grass", "Grass to the west, a hill"],
			["Desert", "Layer · Desert", "Sand to the east, a dune"]]:
		_ecran._activer(_couche[etape[0]])
		_montrer(etape[1], etape[2])
		var tout: Dictionary = par[etape[0]]
		for bande in 2:
			var part := {}
			for c in tout:
				if (c.z < 0) == (bande == 0):
					part[c] = true
			_ecran._appliquer({"poser": part, "effacer": {}}, "Add")
			await _t_derive(0.7)
		await _t_derive(0.5)
	_ecran._activer(_couche["GreyRock"])
	await _ecran._reparer_les_diagonales(false)
	await _t_derive(1.2)


## La caméra tourne doucement autour de sa cible pendant que le monde se pose.
func _t_derive(duree: float, vitesse := 0.0016) -> void:
	for i in int(duree * FPS):
		_vue._azimut += vitesse
		_vue._caler()
		await _images(1)


func _t_relief() -> void:
	_tbruit.seed = 7
	_tbruit.frequency = 0.08
	for x in range(TX0, TX1 + 1):
		for z in range(TZ0, TZ1 + 1):
			var k := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var meilleur := ""
			var dmin := 1e9
			var i := 0
			for nom in T_CENTRES:
				i += 1
				var d: float = (T_CENTRES[nom] as Vector2).distance_to(p) + 7.0 * _tbruit.get_noise_2d(p.x * 0.8 + 200.0 * i, p.y * 0.8)
				if d < dmin:
					dmin = d
					meilleur = nom
			var h := 0
			var m := meilleur
			for r in T_RELIEFS:
				var q := (p - (r[0] as Vector2)) / (r[1] as Vector2)
				if q.length() < 1.0 + 0.18 * _tbruit.get_noise_2d(p.x * 1.7, p.y * 1.7):
					if int(r[2]) >= h:
						h = int(r[2])
						m = r[3]
			_th[k] = h
			_tm[k] = m
	# ⚠ PAS DE DAMIER (contacts diagonaux) : dans un carré de 2 × 2 colonnes, une diagonale toute plus haute que l'autre
	# se toucherait par l'arête — on remonte la paire basse (la règle de `filmer_haut._sans_damier`).
	for passe in 30:
		var change := 0
		for x in range(TX0, TX1):
			for z in range(TZ0, TZ1):
				var a := Vector2i(x, z)
				var b := Vector2i(x + 1, z)
				var c := Vector2i(x, z + 1)
				var d := Vector2i(x + 1, z + 1)
				for paire in [[a, d, b, c], [b, c, a, d]]:
					var haut := mini(_th[paire[0]], _th[paire[1]])
					if haut > maxi(_th[paire[2]], _th[paire[3]]):
						for q in [paire[2], paire[3]]:
							_th[q] = maxi(_th[q], haut)
							_tm[q] = _tm[paire[0]]
						change += 1
		if change == 0:
			break


## La colonne de matière `a`, au niveau `h` (−1 : tout niveau), voisine d'une colonne de `b` au MÊME niveau, la plus proche
## de `pres` : le dessus de leur frontière, en coordonnées du monde.
func _t_bord(a: String, b: String, pres: Vector2, meme_niveau := true) -> Vector3:
	var meilleur := Vector3.ZERO
	var dmin := 1e9
	for k in _th:
		if _tm[k] != a:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if not _th.has(n) or _tm[n] != b or (meme_niveau and _th[n] != _th[k]):
				continue
			var p := Vector2(k) + Vector2(0.5, 0.5) + Vector2(d) * 0.5
			var dist := p.distance_to(pres)
			if dist < dmin:
				dmin = dist
				meilleur = Vector3(p.x, maxi(int(_th[k]), int(_th[n])) + 1.0, p.y)
	return meilleur


## Les points de la frontière a | b (même niveau) dans un rayon `r` autour de `centre`, rangés le long de `sens`.
func _t_frontiere(a: String, b: String, centre: Vector2, r: float, sens: Vector2) -> Array:
	var pts := []
	for k in _th:
		if _tm[k] != a:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + d
			if not _th.has(n) or _tm[n] != b or _th[n] != _th[k]:
				continue
			var p := Vector2(k) + Vector2(0.5, 0.5) + Vector2(d) * 0.5
			if p.distance_to(centre) < r:
				pts.append(Vector3(p.x, int(_th[k]) + 1.0, p.y))
	pts.sort_custom(func(u, v) -> bool: return Vector2(u.x, u.z).dot(sens) < Vector2(v.x, v.z).dot(sens))
	return pts


# ── 1. LA FRONTIÈRE FRANCHE : sans transition ───────────────────────────────────────────────────────

func _t_franc() -> void:
	var c := _t_carrefour()
	_regarder(c + Vector3(-6, 13, 15), c)
	await _images(6)
	_montrer("Same level", "Three layers side by side: a hard, blocky edge")
	await _t_derive(3.5, 0.004)
	var gd := _t_bord("Grass", "Desert", T_CENTRES["Grass"].lerp(T_CENTRES["Desert"], 0.5))
	_regarder(gd + Vector3(-2, 6.5, 8), gd)
	await _images(4)
	_montrer("No transition", "Grass meets sand, cell by cell")
	await _t_derive(2.5, 0.003)


## Le point du sol plat où les trois couches sont le plus proches les unes des autres.
func _t_carrefour() -> Vector3:
	var best := Vector2i.ZERO
	var bscore := 1e9
	for k in _th:
		if _th[k] != 0:
			continue
		var vus := {}
		var score := 0.0
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var n: Vector2i = k + Vector2i(dx, dz)
				if _th.has(n) and _th[n] == 0:
					vus[_tm[n]] = true
		if vus.size() == 3:
			score = Vector2(k).length()
			if score < bscore:
				bscore = score
				best = k
	return Vector3(best.x + 0.5, 1.0, best.y + 0.5)


# ── 2. LES PAIRES : l'atelier, une case cochée, le fondu ────────────────────────────────────────────

func _t_paires() -> void:
	var gd := _t_bord("Grass", "Desert", T_CENTRES["Grass"].lerp(T_CENTRES["Desert"], 0.5))
	_regarder(gd + Vector3(-2, 6.5, 8), gd)
	await _cliquer_bouton("Transitions", "The Transitions workshop", "Where two layers meet")
	await _images(int(0.8 * FPS))
	await _t_cocher("Grass", "Desert", "Tick a pair: grass and sand blend")
	await _images(int(1.6 * FPS))
	# ⚠ LE REPRÉSENTANT PAR DÉFAUT est le matériau que le témoin porte le plus : dans l'exemple, la FALAISE (Material 2) —
	# une bande brune, avec un liseré franc au bout (vu au premier tournage). Le vrai geste : prendre le dessus (Material 1).
	_montrer("Default", "Each layer blends its most-worn material: here, the cliff")
	await _images(int(2.0 * FPS))
	await _t_representant("Grass", "Material 1", "Grass blends its top: the grass")
	await _images(int(0.8 * FPS))
	await _t_representant("Desert", "Material 1", "Desert blends its top: the sand")
	await _images(int(2.0 * FPS))
	var c := _t_carrefour()
	_regarder(c + Vector3(-6, 13, 15), c)
	await _images(10)
	await _t_cocher("GreyRock", "Grass", "Rock and grass")
	await _images(int(1.2 * FPS))
	await _t_cocher("GreyRock", "Desert", "Rock and sand")
	await _images(int(1.0 * FPS))
	_montrer("Transitions", "The tiles do not change: only their look blends")
	await _t_derive(3.0, 0.004)


## Le matériau représentant d'une couche, choisi dans sa liste (REPRESENTATIVE MATERIALS).
func _t_representant(nom: String, materiau: String, detail: String) -> void:
	var liste: OptionButton = null
	for ligne in _tr._materiaux.get_children():
		if (ligne.get_child(0) as Label).text == nom:
			liste = ligne.get_child(1)
	if liste == null:
		print("⚠ pas de liste de représentant pour %s" % nom)
		return
	await _t_rendre_visible(liste)
	await _choisir_dans_la_liste(liste, materiau, detail)
	await _images(4)
	print("représentant de %s : %d" % [nom, _tr.indice_representant(_ecran._couches[_couche[nom]])])


## La case de la paire, cliquée par la souris (sa ligne : « A · B » dans l'ordre des ids).
func _t_cocher(a: String, b: String, detail: String) -> void:
	var ligne := _t_ligne_de_paire(a, b)
	if ligne == null:
		print("⚠ paire introuvable : %s · %s" % [a, b])
		return
	var case_: CheckBox = ligne.get_child(0)
	await _t_rendre_visible(case_)
	await _bouger(case_.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)
	# ⚠ La case est refaite au clic (`dire(true)`) : on relit l'état, pas la case libérée.
	print("paire %s · %s allumée : %s" % [a, b, _tr.actif()])


func _t_ligne_de_paire(a: String, b: String) -> HBoxContainer:
	for ligne in _tr._liste.get_children():
		var t: String = (ligne.get_child(1) as Button).text
		if t == "%s  ·  %s" % [a, b] or t == "%s  ·  %s" % [b, a]:
			return ligne
	return null


## Un contrôle de la barre de droite sous le bord : la molette fait défiler son panneau (comme `_cliquer_bouton`).
func _t_rendre_visible(c: Control) -> void:
	var ecran := Rect2(Vector2(0, 40), Vector2(root.size) - Vector2(0, 40))
	if ecran.encloses(c.get_global_rect()):
		return
	var defile := c.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile == null:
		return
	await _bouger((defile as Control).get_global_rect().get_center(), 0.4)
	var sens := MOUSE_BUTTON_WHEEL_DOWN if c.get_global_rect().end.y > ecran.end.y else MOUSE_BUTTON_WHEEL_UP
	for i in 60:
		if ecran.encloses(c.get_global_rect()):
			break
		_presser(sens, true)
		_presser(sens, false)
		await _images(2)
	await _images(12)


# ── 3. LES RÉGLAGES : chaque curseur change l'image en direct ───────────────────────────────────────

func _t_reglages() -> void:
	# La paire Grass · Desert ; la couvrante par défaut est la plus haute de la liste.
	await _t_choisir_paire("Grass", "Desert")
	var haut := _t_prioritaire("Grass", "Desert")
	var gd := _t_bord("Grass", "Desert", T_CENTRES["Grass"].lerp(T_CENTRES["Desert"], 0.5))
	_regarder(gd + Vector3(-1.5, 5.5, 6.5), gd)
	await _images(8)
	await _t_curseur(haut, "largeur", 0.05, 1.4, "Softness", "Low: a sharp line")
	await _images(int(0.8 * FPS))
	await _t_curseur(haut, "largeur", 1.0, 1.6, "Softness", "High: a long blend")
	await _images(int(0.8 * FPS))
	await _t_curseur(haut, "largeur", 0.5, 0.8, "Softness", "In between")
	await _t_curseur(haut, "avance", 0.5, 1.6, "Reach", "The covering layer spreads further")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "avance", -0.5, 1.8, "Reach", "…or holds back")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "avance", 0.2, 0.8, "Reach", "")
	await _t_curseur(haut, "bruit", 1.0, 1.4, "Irregularity", "An uneven edge")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "grain", 5.0, 1.6, "Grain", "Finer irregularity")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "grain", 1.0, 1.0, "Grain", "Coarser")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "creux", 1.0, 1.4, "Fills hollows", "It settles in the dark parts first")
	await _images(int(1.2 * FPS))


func _t_choisir_paire(a: String, b: String) -> void:
	var ligne := _t_ligne_de_paire(a, b)
	if ligne == null:
		return
	var bouton: Button = ligne.get_child(1)
	await _t_rendre_visible(bouton)
	await _bouger(bouton.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "The pair %s · %s: its settings" % [a, b])


## Le nom de la couche la plus haute de la liste des deux (celle qui couvre par défaut).
func _t_prioritaire(a: String, b: String) -> String:
	var r: Dictionary = _tr.rangs()
	return a if int(r[_id[a]]) < int(r[_id[b]]) else b


## Le curseur du réglage `k` quand `couvrante` couvre : la souris le saisit et le glisse jusqu'à `v`.
func _t_curseur(couvrante: String, k: String, v: float, duree: float, carte: String, detail: String) -> void:
	var curseur: HSlider = null
	for enfant in _descendants(_tr._editeur):
		if enfant is HSlider and (enfant as HSlider).get_meta("reglage", []) == [_id[couvrante], k]:
			curseur = enfant
	if curseur == null:
		print("⚠ curseur introuvable : %s %s" % [couvrante, k])
		return
	await _t_glisser_curseur(curseur, v, duree, carte, detail)
	print("réglage %s %s : %.2f (voulu %.2f)" % [couvrante, k, curseur.value, v])


## Un curseur : la souris saisit sa poignée et la glisse jusqu'à `v` (un vrai glissé : `drag_started`, `drag_ended`).
func _t_glisser_curseur(curseur: HSlider, v: float, duree: float, carte: String, detail: String) -> void:
	await _t_rendre_visible(curseur)
	var r := curseur.get_global_rect()
	var de := _t_x_du_curseur(curseur, curseur.value)
	await _bouger(Vector2(de, r.get_center().y), 0.4)
	if detail != "":
		_montrer(carte, detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(2)
	await _bouger(Vector2(_t_x_du_curseur(curseur, v), r.get_center().y), duree)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(4)


func _t_x_du_curseur(c: HSlider, v: float) -> float:
	var r := c.get_global_rect()
	var g := 8.0   # la demi-largeur de la poignée : la piste utile est un peu plus courte que le contrôle
	var t := (v - c.min_value) / (c.max_value - c.min_value)
	return r.position.x + g + t * (r.size.x - 2.0 * g)


func _descendants(n: Node) -> Array:
	var sortie: Array = []
	for e in n.get_children():
		sortie.append(e)
		sortie.append_array(_descendants(e))
	return sortie


# ── 4. LES DEUX SENS : le sable sur la roche n'est pas la roche sur le sable ; le pinceau ────────────

func _t_sens() -> void:
	await _t_choisir_paire("GreyRock", "Desert")
	var haut := _t_prioritaire("GreyRock", "Desert")
	var bas := "Desert" if haut == "GreyRock" else "GreyRock"
	var rd := _t_bord("GreyRock", "Desert", Vector2(3, -2))
	_regarder(rd + Vector3(-1, 7, 8), rd)
	await _images(8)
	# Le sens par défaut (la plus haute couvre) : franc, irrégulier ; puis l'autre sens : doux, qui remplit les creux.
	_montrer("Two settings", "When %s covers %s…" % [haut, bas])
	await _t_curseur(haut, "largeur", 0.1, 1.0, "Softness", "")
	await _t_curseur(haut, "bruit", 0.9, 1.0, "Irregularity", "")
	await _t_curseur(haut, "grain", 3.0, 1.0, "Grain", "")
	await _images(int(0.6 * FPS))
	_montrer("Two settings", "…and when %s covers %s" % [bas, haut])
	await _t_curseur(bas, "largeur", 0.9, 1.0, "Softness", "")
	await _t_curseur(bas, "avance", 0.4, 1.0, "Reach", "")
	await _t_curseur(bas, "creux", 1.0, 1.0, "Fills hollows", "")
	# Le pinceau : « bas covers », glissé le long d'une partie de la frontière.
	await _t_rendre_visible(_tr._pinceau)
	await _choisir_dans_la_liste(_tr._pinceau, "« %s » covers" % bas, "Brush: %s covers here" % bas)
	await _t_glisser_curseur(_tr.curseur_rayon, 2, 0.6, "Radius", "Brush radius: 2 cells")
	var pts := _t_frontiere("GreyRock", "Desert", Vector2(rd.x, rd.z), 6.0, Vector2(1, 0))
	print("frontière roche | sable : %d points" % pts.size())
	await _t_glisser(pts, 2.4, MOUSE_BUTTON_LEFT, "Left drag", "%s covers %s, place by place" % [bas, haut])
	await _images(int(1.4 * FPS))
	var moitie := pts.slice(0, maxi(1, pts.size() / 3))
	await _t_glisser(moitie, 1.2, MOUSE_BUTTON_RIGHT, "Right drag", "Back to the priority")
	await _images(int(1.2 * FPS))
	print("choix peints : %d" % (_tr.etat["choix"] as Dictionary).size())


## Un glissé de la souris par ces points du monde, bouton `bouton` tenu.
func _t_glisser(points: Array, duree: float, bouton: int, carte: String, detail: String) -> void:
	if points.is_empty():
		print("⚠ rien à glisser")
		return
	await _bouger(_sur(points[0]), 0.4)
	_montrer(carte, detail)
	_presser(bouton, true)
	var n := int(duree * FPS)
	for i in n:
		var t := float(i + 1) / float(n) * (points.size() - 1)
		var j := mini(int(t), points.size() - 2) if points.size() > 1 else 0
		var p: Vector3 = points[0] if points.size() == 1 else (points[j] as Vector3).lerp(points[j + 1], t - j)
		var avant := _souris
		_souris = _sur(p)
		var m := InputEventMouseMotion.new()
		m.position = _souris
		m.global_position = _souris
		m.relative = _souris - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
	_presser(bouton, false)
	await _images(4)


# ── 5. L'ORDRE : Up / Down change qui couvre, partout où rien n'est peint ───────────────────────────

func _t_ordre() -> void:
	var gd := _t_bord("Grass", "Desert", T_CENTRES["Grass"].lerp(T_CENTRES["Desert"], 0.5))
	_regarder(gd + Vector3(-1.5, 6.5, 7.5), gd)
	await _images(8)
	var bas := "Desert" if _t_prioritaire("Grass", "Desert") == "Grass" else "Grass"
	var b := _t_bouton_couche(bas)
	if b == null:
		print("⚠ couche introuvable : %s" % bas)
		return
	await _t_rendre_visible(b)
	await _bouger(b.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "The layer %s" % bas)
	while _t_prioritaire("Grass", "Desert") != bas:
		var avant: int = _ecran._active
		await _cliquer_bouton("Up", "Up: %s now covers" % bas, "Moves the active layer up")
		await _images(int(0.6 * FPS))
		if _ecran._active == avant:
			break
	print("ordre : %s" % [_ecran._couches.map(func(c): return c["nom"])])
	await _images(int(2.0 * FPS))
	await _touche(KEY_Z, "Ctrl + Z", "Undo: back to the old order", true)
	await _images(int(1.4 * FPS))


func _t_bouton_couche(nom: String) -> Button:
	for ligne in _ecran._liste_couches.get_children():
		for e in ligne.get_children():
			if e is Button and (e as Button).text.begins_with(nom + "\n"):
				return e
	return null


# ── 6. LE MONDE : Échap ramène à World — la teinte jaune s'en va, le fondu reste ────────────────────

func _t_monde() -> void:
	await _touche(KEY_ESCAPE, "Esc", "Back to World: the blend stays")
	var c := _t_carrefour()
	_regarder(c + Vector3(0, 20, 26), c)
	await _images(6)
	await _t_derive(4.0, 0.006)


# ── 7. LE JEU : le Play test, sa lumière, le stickman qui traverse les frontières ───────────────────

func _t_jeu() -> void:
	var c := _t_carrefour()
	_vue._cible = Vector3(c.x - 6, 1, c.z + 4)
	_cam_haut = false
	_cam_d = 8.0
	_cam_e = 0.55
	await _cliquer_bouton("Play test", "Play test: the same blend, in the real light")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.3)
	await _images(int(0.5 * FPS))
	_montrer("Render", "A low, warm sun")
	for reglage in [["soleil_hauteur", 28.0], ["soleil_azimut", 210.0], ["soleil_couleur", Color(1.0, 0.88, 0.72)],
			["soleil_energie", 1.5], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 1.0]]:
		_vue.regler_rendu(reglage[0], reglage[1])
		await _images(3)
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	# Il marche vers l'est, de l'herbe au sable, puis vole par-dessus la roche.
	await _t_vers(Vector3(c.x + 8, 1, c.z + 4), 4.0, "W A S D", "Walk from grass to sand")
	await _touche(KEY_F, "F", "Fly")
	_cam_d = 11.0
	_cam_e = 0.75
	await _t_vers(Vector3(9, 6, -4), 4.0, "W + Space", "Over the rock mesa", true)
	await _t_vers(Vector3(-15, 6, -5), 6.0, "W A S D", "And back over the grass hill", true)
	await _images(int(1.0 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


## Le stickman va vers `cible` (W, la caméra tournée vers elle), en `duree` secondes au plus. `monter` : Espace tenu tant
## qu'il est sous la hauteur de la cible (en vol).
func _t_vers(cible: Vector3, duree: float, carte: String, detail: String, monter := false) -> void:
	var p: CharacterBody3D = _vue.personnage
	_montrer(carte, detail)
	for i in int(duree * FPS):
		var d: Vector3 = cible - p.global_position
		var plat := Vector2(d.x, d.z)
		if plat.length() < 0.6:
			break
		var u := plat.normalized()
		_vue._azimut = lerp_angle(_vue._azimut, atan2(-u.x, -u.y), 0.08)
		_cle(KEY_W, true)
		if monter:
			_cle(KEY_SPACE, d.y > 0.3)
		await _images(1)
	_cle(KEY_W, false)
	_cle(KEY_SPACE, false)
	print("stickman en %s (visé %s)" % [p.global_position, cible])
