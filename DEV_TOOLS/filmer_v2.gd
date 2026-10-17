extends "res://DEV_TOOLS/filmer_paysage.gd"
##
## DEVLOG — LE PAYSAGE, REFAIT SUR LE MONDE DE JORDAN. Demandé par Jordan (6 octobre 2026) : « refais paysage avec
## C:\Users\jorda\Documents\MarchingBlocks\v2notartist ». Son monde « Hills » (294 598 cases, une couche, pas d'eau) :
## une cuvette basse à y = -12 à l'ouest et au sud, un plateau à 0, une butte à 4, une arête à 11-17 à l'est.
##
## ⚠ LE PROJET DE JORDAN N'EST JAMAIS OUVERT LUI-MÊME : il est COPIÉ dans les données de la copie de tournage
## (`user://filmer_v2`), ses chemins absolus réécrits vers la copie ; c'est la copie qui s'ouvre et s'enregistre.
## Ce qu'on y ajoute, par les vrais gestes de Fluids : la mer dans la cuvette, un lac dans le creux du plateau, une
## rivière qui tombe du plateau dans la mer. Puis le Play test, la lumière dorée, et une PROMENADE en vol (le chemin
## lissé suivi en poursuite — la leçon de « il tourne en rond »).
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/v2.avi --script res://DEV_TOOLS/filmer_v2.gd

const SOURCE_V2 := "C:/Users/jorda/Documents/MarchingBlocks/v2notartist"
const COPIE_V2 := "user://filmer_v2"
const MER_V2 := -11

var _dessus := {}                  # (x, z) → y du dessus, lu dans le monde ouvert


func _derouler() -> void:
	await _images(30)
	var projet := _copier_le_projet()
	if projet == "":
		_rendre_les_reglages()
		quit(1)
		return
	var ok: bool = await _ecran._ouvrir(projet)
	print("ouverture de la copie : %s (%s)" % [ok, projet])
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for c: Vector3i in _ecran._occupees_du_monde():
		var k := Vector2i(c.x, c.z)
		if not _dessus.has(k) or c.y > _dessus[k]:
			_dessus[k] = c.y
	print("monde : %d colonnes" % _dessus.size())
	_aides()
	await _images(20)
	for partie in ["tour", "eaux", "lumiere", "vol", "meteo"]:
		_plan(partie)
		await Callable(self, "_v_" + partie).call()
		await _images(int(0.4 * FPS))
	_plan("fin")
	_rendre_les_reglages()
	quit(0)


## Copie le dossier du projet (sans y toucher) et réécrit ses chemins absolus. Rend le chemin du .mbproj copié.
func _copier_le_projet() -> String:
	_vider(COPIE_V2)
	var dest := ProjectSettings.globalize_path(COPIE_V2)
	var mbproj := ""
	var a_faire := [""]
	while not a_faire.is_empty():
		var rel: String = a_faire.pop_back()
		var src := SOURCE_V2.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dest.path_join(rel))
		for d in DirAccess.get_directories_at(src):
			a_faire.append(rel.path_join(d))
		for f in DirAccess.get_files_at(src):
			var depuis := src.path_join(f)
			var vers := dest.path_join(rel).path_join(f)
			if f.get_extension() in ["mbproj", "mbtiles"]:
				var t := FileAccess.get_file_as_string(depuis).replace(SOURCE_V2, dest)
				var o := FileAccess.open(vers, FileAccess.WRITE)
				o.store_string(t)
				o.close()
				if f.get_extension() == "mbproj":
					mbproj = vers
			else:
				DirAccess.copy_absolute(depuis, vers)
	print("projet copié : %s" % mbproj)
	return mbproj


# ── 1. LE TOUR DU MONDE, DANS WORLD ──────────────────────────────────────────────────────────────────

func _v_tour() -> void:
	_regarder(Vector3(-10, 60, 110), Vector3(4, 0, 22))
	await _images(10)
	_montrer("World", "A world sculpted by hand — art at 40 %")
	await _orbite(5.0, _vue._azimut, _vue._azimut + 0.9, _vue._distance, _vue._distance * 0.85)
	_regarder(Vector3(-40, 22, 40), Vector3(10, 4, 10))
	await _orbite(4.0, _vue._azimut, _vue._azimut - 0.6, _vue._distance, _vue._distance * 0.8)


# ── 2. L'EAU : la mer dans la cuvette, un lac dans le creux du plateau, une rivière qui en tombe ───────

func _v_eaux() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _images(10)
	var avant := int(_ecran._compteur_etage.value)
	_montrer("PgUp / PgDn", "Water height: y = %d" % MER_V2)
	for i in absi(MER_V2 - avant):
		var k := KEY_PAGEUP if MER_V2 > avant else KEY_PAGEDOWN
		_cle(k, true)
		_cle(k, false)
		await _images(1)
	# Un point du vide : une colonne sans rien dessous, au bord du monde.
	var vide := Vector3(62.5, MER_V2, -18.5)
	_regarder(vide + Vector3(-30, 40, 60), vide + Vector3(-20, 0, 10))
	await _images(10)
	_dans_l_image(vide, "la mer")
	await _bouger(_sur(vide), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click the void", "The sea: pick its height")
	await _clic(MOUSE_BUTTON_LEFT, "Click again", "Place the sea")
	await _ecran._recalculer_eau(false)
	await _images(int(1.0 * FPS))
	print("mer : %d cases ; en suspens %s ; %s" % [(_ecran._ocean_eau as Dictionary).size(), _ecran._mer_choisie,
		_ecran._rapport.text.left(120)])
	# ⚠ PREMIER ESSAI : la mer n'a pas été posée (0 case ; « There is water here already »). Si les clics n'ont rien
	# fait, on appelle ce qu'ils appellent — épingler puis valider — et le journal le dit.
	if (_ecran._ocean_eau as Dictionary).is_empty():
		print("⚠ la mer n'est pas posée : `_choisir_la_mer` puis `_valider_la_mer`")
		if _ecran._mer_choisie == null:
			_ecran._choisir_la_mer(Vector3i(62, MER_V2, -19))
		_ecran._valider_la_mer()
		await _ecran._recalculer_eau(false)
		print("mer : %d cases" % (_ecran._ocean_eau as Dictionary).size())
	# Le lac : le creux le plus bas du plateau (une colonne nettement sous ses voisines).
	# Le creux du plateau, mesuré dans le projet de Jordan : un puits de 7 × 19 colonnes descendu à -12, en x 5..11,
	# autour de z = -8 (le chercher par voisinage échouait : il est plus large que 3 cases).
	var creux := Vector3i(8, -12, -8)
	if creux != Vector3i.ZERO:
		_regarder(Vector3(creux) + Vector3(12, 22, 18), Vector3(creux))
		await _images(12)
		await _source_au(creux + Vector3i.UP, "A hollow on the plateau: a lake")
	# La rivière : au bord ouest du plateau, l'eau file à la chute la plus proche et tombe dans la mer.
	var bord := _bord_du_plateau()
	_regarder(Vector3(bord) + Vector3(-24, 10, 16), Vector3(bord) + Vector3(0, -6, 0))
	await _images(12)
	await _source_au(bord + Vector3i.UP, "A spring at the edge: it falls into the sea")
	await _ecran._recalculer_eau(false)
	await _orbite(4.0, _vue._azimut, _vue._azimut + 0.5, _vue._distance, _vue._distance * 0.9)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


func _source_au(c: Vector3i, detail: String) -> void:
	var n0: int = (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size()
	await _forme_au(Vector3(c) + Vector3(0.5, 0.02, 0.5), detail)
	await _images(int(0.5 * FPS))
	if (_ecran._eaux[_ecran._eau_active]["sources"] as Array).size() == n0:
		print("⚠ le clic n'a rien posé ; `_eau_cliquee` appelé sur %s" % c)
		_ecran._eau_cliquee(c, MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	print("source %s : %s" % [c, _ecran._rapport.text.left(140)])
	await _images(int(1.0 * FPS))


## La colonne du plateau (dessus ≥ 0) la plus basse parmi celles dont les quatre voisines sont plus hautes de 3 et plus.
func _creux_du_plateau() -> Vector3i:
	var meilleur := Vector3i.ZERO
	var plus_bas := 999
	for k: Vector2i in _dessus:
		var h: int = _dessus[k]
		if h > -3 or h <= -12:
			continue
		var entoure := true
		for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
			if int(_dessus.get(k + d, -99)) < h + 3:
				entoure = false
		if entoure and h < plus_bas:
			plus_bas = h
			meilleur = Vector3i(k.x, h, k.y)
	print("creux du plateau : %s" % meilleur)
	return meilleur


## Une colonne du plateau (dessus 0) à deux cases de son bord ouest, au-dessus de la cuvette (-12).
func _bord_du_plateau() -> Vector3i:
	for z in range(4, 20):
		for x in range(-40, 0):
			var k := Vector2i(x, z)
			if int(_dessus.get(k, -99)) == 0 and int(_dessus.get(k + Vector2i(-2, 0), -99)) <= -10:
				print("bord du plateau : %s" % Vector3i(x + 1, 0, z))
				return Vector3i(x + 1, 0, z)
	return Vector3i(-28, 0, 10)


# ── 3. LA LUMIÈRE : celle de `filmer_paysage` (le rendu par défaut, un soleil doré, du glow) ─────────

func _v_lumiere() -> void:
	# Sur le plateau (au premier essai, (-6, 30) était le fond de la cuvette, sous les surplombs).
	_vue._cible = Vector3(-6, 2, 10)
	await _p_lumiere_reglages()


func _p_lumiere_reglages() -> void:
	await _cliquer_bouton("Play test", "Play test: the real light")
	await _images(int(1.0 * FPS))
	_montrer("Render", "Golden hour: low warm sun")
	for reglage in [["soleil_hauteur", 30.0], ["soleil_azimut", 200.0], ["soleil_couleur", Color(1.0, 0.88, 0.72)],
			["soleil_energie", 1.5], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 1.0]]:
		_vue.regler_rendu(reglage[0], reglage[1])
		await _images(4)
	await _images(int(1.0 * FPS))


# ── 4. LA PROMENADE EN VOL ───────────────────────────────────────────────────────────────────────────

func _v_vol() -> void:
	await _p_vol()


## Le chemin de la promenade dans CE monde : le plateau, la butte, le lac, le long de la falaise au-dessus de la mer, puis
## l'arête de l'est.
func _promenade() -> Array:
	var cles := [Vector2(-6, 10), Vector2(-20, 16), Vector2(-26, 8), Vector2(-22, -8), Vector2(-6, -14),
		Vector2(8, -6), Vector2(4, 8), Vector2(-4, 14), Vector2(10, 24), Vector2(24, 28), Vector2(34, 40),
		Vector2(46, 52), Vector2(60, 58), Vector2(68, 44), Vector2(52, 36), Vector2(36, 50), Vector2(22, 62)]
	var chemin := []
	for i in cles.size() - 1:
		var p0: Vector2 = cles[maxi(i - 1, 0)]
		var p1: Vector2 = cles[i]
		var p2: Vector2 = cles[i + 1]
		var p3: Vector2 = cles[mini(i + 2, cles.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2)))
		for j in n:
			var t := float(j) / n
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			chemin.append(Vector3(q.x, 0, q.y))
	return chemin


## Le sol sous un point : le PLUS HAUT dessus dans un rayon de 2 cases (au premier essai, il restait coincé sous un
## surplomb : 1 571 colonnes de ce monde ont du vide sous de la matière).
func _sol_sous(p: Vector3) -> float:
	var h := MER_V2 - 1
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			h = maxi(h, int(_dessus.get(Vector2i(floori(p.x) + dx, floori(p.z) + dz), MER_V2 - 1)))
	return float(h) + 1.0


# ── 5. LA MÉTÉO (celle de `filmer_paysage`) ──────────────────────────────────────────────────────────

func _v_meteo() -> void:
	await _p_meteo()
