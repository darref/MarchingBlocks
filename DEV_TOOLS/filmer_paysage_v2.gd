extends "res://DEV_TOOLS/filmer_paysage.gd"
##
## DEVLOG « A NATURAL LANDSCAPE » — SECONDE VERSION (7 octobre 2026). Le rush de la v1 (`paysage.avi`) a été écrasé par une
## prise ratée le 6 octobre ; on refilme. Le paysage, les eaux et le plan de la vidéo sont ceux de `filmer_paysage.gd`
## (hérités sans changement) ; trois choses changent, toutes VUES à la planche de la première prise du 7 octobre :
##
##   1. ⚠ LE STICKMAN TOURNAIT SUR PLACE 30 S au bord du lac (prise 1, de 1:13 à 1:45 du rush) : la promenade refermait son
##      tour du lac au point d'entrée puis repartait vers le nord-est par un DEMI-TOUR ; à ce pli, le point « le plus proche,
##      vers l'avant » ne progressait plus (le point suivant était toujours plus loin que le pli), et la poursuite visait
##      derrière lui. Désormais : le tour du lac s'arrête aux trois quarts (il sort vers le nord-est dans son élan, sans
##      pli), et un point du chemin passé à moins de 2,5 cases compte comme ATTEINT (le pointeur avance quoi qu'il arrive).
##   2. LES RÉGLAGES DE RENDU PASSENT PAR LE PANNEAU DU PLAY TEST : la v1 les écrivait dans la vue (`regler_rendu`), et la
##      barre de droite montrait encore « Sun height 48 » sous un soleil à 30° — l'écran disait faux. La souris glisse
##      désormais les vrais curseurs (Sun height, Sun direction, Sun strength) ; couleurs et glow passent par LEURS
##      contrôles (le signal du contrôle appelle la vue, comme une main).
##   3. LA MÉTÉO PASSE PAR LA LISTE « WEATHER » du panneau (l'item choisi, puis son signal) : la liste montre le temps filmé.
##
## LANCEMENT — dans une COPIE de tournage (worktree de `main`, `custom_user_dir`) :
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_refilm --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/paysage_v2.avi \
##       --script res://DEV_TOOLS/filmer_paysage_v2.gd


# ── 3. LA LUMIÈRE, par le panneau ────────────────────────────────────────────────────────────────────

func _p_lumiere() -> void:
	_vue._cible = Vector3(_x_vallee(RIVAGE - 4), 8, RIVAGE - 4)
	await _cliquer_bouton("Play test", "Play test: the real light")
	await _images(int(1.0 * FPS))
	var c: Dictionary = _ecran._controles_rendu
	await _curseur_rendu(c.get("soleil_hauteur"), 32.0, "Drag", "Sun height: a low sun")
	# ⚠ LE SOLEIL ÉTAIT EN FACE (prise 2 du 7 octobre) : la lumière d'un DirectionalLight3D part le long de son −Z ; à
	# 180° (et aux 200° de la v1) elle va vers le sud, le soleil est AU NORD — droit devant une caméra qui remonte la
	# vallée vers le nord : tous les versants à contre-jour, presque noirs. À 20°, le soleil est au sud, un peu à
	# l'ouest : dans le dos de la caméra, et assez de côté pour que le relief garde ses ombres.
	await _curseur_rendu(c.get("soleil_azimut"), 20.0, "Drag", "Sun direction: behind the camera")
	await _curseur_rendu(c.get("soleil_energie"), 1.5, "Drag", "Sun strength")
	_montrer("Render", "Golden hour: warm sun, warm horizon, glow")
	_couleur_rendu(c.get("soleil_couleur"), Color(1.0, 0.88, 0.72))
	await _images(4)
	_couleur_rendu(c.get("ciel_horizon"), Color("#f2b98a"))
	await _images(4)
	var g = c.get("glow")
	if g is CheckButton and not (g as CheckButton).button_pressed:
		(g as CheckButton).button_pressed = true   # émet `toggled` : la route du contrôle
	var gi = c.get("glow_intensite")
	if gi is HSlider:
		(gi as HSlider).value = 1.0                 # émet `value_changed`
	await _images(int(1.5 * FPS))
	print("rendu : hauteur %s, azimut %s, énergie %s, glow %s" % [_vue.rendu.get("soleil_hauteur"),
		_vue.rendu.get("soleil_azimut"), _vue.rendu.get("soleil_energie"), _vue.rendu.get("glow")])


## Un curseur du panneau glissé à la souris s'il est DANS l'image ; sinon sa valeur est posée (son signal fait le reste).
func _curseur_rendu(s, valeur: float, carte: String, detail: String) -> void:
	if not (s is HSlider):
		print("⚠ curseur de rendu introuvable : %s" % detail)
		return
	var r: Rect2 = (s as HSlider).get_global_rect()
	if r.position.y < 50.0 or r.end.y > 1070.0 or not (s as HSlider).is_visible_in_tree():
		(s as HSlider).value = valeur
		_montrer(carte, detail)
		await _images(int(0.8 * FPS))
		return
	var x_de := func(v: float) -> float:
		var t: float = (v - float(s.min_value)) / (float(s.max_value) - float(s.min_value))
		return r.position.x + 8.0 + t * (r.size.x - 16.0)
	await _bouger(Vector2(x_de.call(s.value), r.get_center().y), 0.5)
	_montrer(carte, detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(2)
	await _bouger(Vector2(x_de.call(valeur), r.get_center().y), 0.9)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(int(0.3 * FPS))
	print("curseur %s → %.2f" % [detail, s.value])


func _couleur_rendu(b, couleur: Color) -> void:
	if b is ColorPickerButton:
		(b as ColorPickerButton).color = couleur
		(b as ColorPickerButton).color_changed.emit(couleur)
	else:
		print("⚠ bouton de couleur introuvable")


# ── 4. LE VOL, sans pli ni piétinement ─────────────────────────────────────────────────────────────────

func _p_vol() -> void:
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	var chemin := _promenade()
	# La souris sort de la vue avant de voler (la boîte de la tuile la suit).
	await _bouger(Vector2(1900, 1060), 0.3)
	await _touche(KEY_F, "F", "Fly")
	_montrer("W A S D", "A walk through the landscape")
	_cle(KEY_W, true)
	var k := 0
	for i in int(75 * FPS):
		var pos := p.global_position
		var ici := func(j: int) -> float:
			return Vector2(chemin[j].x - pos.x, chemin[j].z - pos.z).length()
		# Le point le plus proche vers l'avant, OU un point déjà frôlé (< 2,5 cases) : le pointeur avance toujours.
		while k < chemin.size() - 1 and (ici.call(k + 1) < ici.call(k) or ici.call(k) < 2.5):
			k += 1
		if k >= chemin.size() - 2:
			break
		var vise: Vector3 = chemin[mini(k + 8, chemin.size() - 1)]
		var plat := Vector2(vise.x - pos.x, vise.z - pos.z)
		_vue._azimut = lerp_angle(_vue._azimut, atan2(-plat.x, -plat.y), 0.12)
		_vue._distance = 7.5
		_vue._elevation = 0.32
		var devant := pos + Vector3(plat.normalized().x, 0, plat.normalized().y) * 4.0
		var haut := pos.y - maxf(_sol_sous(pos), _sol_sous(devant))
		if i % int(2 * FPS) == 0:
			if pos.distance_to(_derniere_pos) < 1.0 and i > 0:
				_montee = int(1 * FPS)
			_derniere_pos = pos
		if _montee > 0:
			_montee -= 1
			_cle(KEY_SPACE, true)
			_cle(KEY_Q, false)
		else:
			_cle(KEY_SPACE, haut < 4.0)
			_cle(KEY_Q, haut > 7.0)
		if i % int(8 * FPS) == 0:
			print("promenade : point %d/%d, stickman en %s" % [k, chemin.size(), pos])
		await _images(1)
	print("promenade finie : point %d/%d" % [k, chemin.size()])
	_cle(KEY_SPACE, false)
	_cle(KEY_Q, false)
	_cle(KEY_W, false)
	await _images(int(0.5 * FPS))


## La promenade : la plage, la vallée en remontant les cascades, les TROIS QUARTS du tour du lac (sortie vers le
## nord-est dans le sens du tour : aucun demi-tour), puis par-dessus l'arête jusqu'au versant d'en face.
func _promenade() -> Array:
	var cles := []
	var x0 := _x_vallee(RIVAGE - 4)
	cles.append(Vector2(x0 + 26, RIVAGE - 2))
	cles.append(Vector2(x0 + 10, RIVAGE - 3))
	for z in range(RIVAGE - 6, LAC.y + 8, -6):
		cles.append(Vector2(_x_vallee(z), z))
	for t in range(0, 6):
		var a := PI * 0.5 + t * PI * 2.0 / 8.0
		cles.append(Vector2(LAC.x, LAC.y) + Vector2(cos(a), sin(a)) * 10.0)
	cles.append(Vector2(LAC.x + 18, LAC.y - 14))
	cles.append(Vector2(LAC.x + 34, LAC.y - 4))
	cles.append(Vector2(LAC.x + 40, LAC.y + 16))
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


# ── 5. LA MÉTÉO, par la liste du panneau ─────────────────────────────────────────────────────────────

func _p_meteo() -> void:
	await _touche(KEY_F, "F", "Land")
	await _touche(KEY_BACKSPACE, "Backspace", "Back to the start")
	await _images(int(1.0 * FPS))
	# ⚠ Prise 2 : au point de départ (sur la plage, adossé au versant), à élévation 0,3 le bras de la caméra butait contre
	# la pente et la TÊTE du stickman remplissait l'image sous la pluie et la neige. Plus haut, plus loin.
	# ⚠ Prise 3 : même plus haut, la tête revenait 1 à 2 s à chaque changement de temps — au point de départ, le stickman est
	# sur la plage AU PIED DU VERSANT, et le bras-ressort de la caméra (`_suivre`) bute contre la pente selon l'azimut. On
	# s'envole donc de quelques cases avant la météo : rien derrière la caméra que le ciel.
	await _touche(KEY_F, "F", "Fly")
	_cle(KEY_SPACE, true)
	await _images(int(1.4 * FPS))
	_cle(KEY_SPACE, false)
	await _images(int(0.4 * FPS))
	_vue._distance = 11.0
	_vue._elevation = 0.55
	for m in [["pluie", "Rain"], ["neige", "Slow snow"], ["brouillard", "Fog"], ["aucune", "Clear again"]]:
		_montrer("Weather", m[1])
		var o: OptionButton = _ecran._choix_meteo
		var idx := -1
		var meteos: Array = _vue.METEOS
		for i in meteos.size():
			if meteos[i][0] == m[0]:
				idx = i
		# ⚠ Prise 3 : la souris allait à la liste puis revenait (0,7 s) ; pendant ce temps la caméra n'était plus tenue et
		# retombait contre la tête du stickman à CHAQUE changement de temps (vu à la planche : 1 à 2 s de tête par météo).
		# La caméra est désormais tenue à chaque image, du choix jusqu'au suivant ; la liste montre le temps choisi.
		if o != null and idx >= 0:
			o.select(idx)
			o.item_selected.emit(idx)
		else:
			_vue.regler_meteo(m[0])
		for i in int(3.5 * FPS):
			_vue._azimut += 0.004
			_vue._distance = 11.0
			_vue._elevation = 0.55
			await _images(1)
	_vue._distance = 9.0
	await _images(10)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
