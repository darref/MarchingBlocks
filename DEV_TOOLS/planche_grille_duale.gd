extends SceneTree
## LA PLANCHE DE LA GRILLE DUALE — à regarder AVANT de sculpter quoi que ce soit.
##
## ⚠ C'est une planche de contrôle, au sens du §6 de la charte : on regarde avant d'engager une zone
## entière. Elle ne décide rien, elle MONTRE — ce qu'il y a à sculpter, où passent les plans de coupe,
## et ce qu'une case peinte déclenche réellement.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_grille_duale.gd -- --sortie=D:/chemin/planche.png
##
## CE QU'ELLE DIT, ET C'EST TOUT LE SUJET :
##   • une PIÈCE est un carré de la taille d'une case, centré sur un CROISEMENT de la grille ;
##   • on la coupe sur les plans qui passent au MILIEU des cases (le contour gris de chaque pièce) ;
##   • le mur du massif tombe donc PILE sur une ligne de grille (le trait d'or), par construction —
##     ce n'est plus un choix du sculpteur, et c'est ça qui supprime toute une famille de pièges.

const LARGEUR := 1360
const HAUTEUR := 1180

const FOND := Color("#14161a")
const MATIERE := Color("#8f7f66")
const MATIERE_SOMBRE := Color("#6d5f4b")
const VIDE := Color("#1d2026")
const OR := Color("#ebbb69")           # la frontière de case : là où tombe le mur
const COUPE := Color("#5b6472")        # le plan de coupe : le contour d'une pièce
const TEXTE := Color("#d8d4cc")
const TEXTE_PALE := Color("#8d9099")

## Les quatre quadrants d'une pièce, dans le sens HORAIRE en partant du nord-ouest.
## L'indice EST le quart de tour : tourner la pièce d'un quart décale les bits d'un cran.
const NO := 0
const NE := 1
const SE := 2
const SO := 3

const NOMS := ["rien", "coin", "mur", "diagonale", "rentrant", "plein"]


func _initialize() -> void:
	var sortie := "planche_grille_duale.png"
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			sortie = option.substr("--sortie=".length())

	var vue := SubViewport.new()
	vue.size = Vector2i(LARGEUR, HAUTEUR)
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vue.transparent_bg = false
	root.add_child(vue)

	var dessin := Planche.new()
	vue.add_child(dessin)

	# Deux images pour que le SubViewport ait rendu avant la capture.
	await process_frame
	await process_frame
	var image := vue.get_texture().get_image()
	var err := image.save_png(sortie)
	print("planche %d×%d → %s (%s)" % [image.get_width(), image.get_height(), sortie,
		"écrite" if err == OK else "ERREUR %d" % err])
	quit(0 if err == OK else 1)


class Planche extends Node2D:
	var police: Font = ThemeDB.fallback_font

	## La configuration d'un croisement : quels quadrants sont pleins → quelle forme, quel quart de tour.
	## ⚠ SEIZE configurations, SIX formes. C'est tout le calcul de la grille duale, et il tient ici.
	static func classer(bits: int) -> Dictionary:
		var pleins := 0
		for i in 4:
			if bits & (1 << i):
				pleins += 1
		if pleins == 0:
			return {"forme": "rien", "quart": 0}
		if pleins == 4:
			return {"forme": "plein", "quart": 0}
		if pleins == 1:
			for i in 4:
				if bits & (1 << i):
					return {"forme": "coin", "quart": i}
		if pleins == 3:
			for i in 4:
				if not (bits & (1 << i)):
					return {"forme": "rentrant", "quart": i}
		# Deux quadrants : adjacents (un mur droit) ou diagonaux (le cas ambigu).
		for i in 4:
			if (bits & (1 << i)) and (bits & (1 << ((i + 1) % 4))):
				return {"forme": "mur", "quart": i}
		return {"forme": "diagonale", "quart": 0 if (bits & 1) else 1}

	func _draw() -> void:
		draw_rect(Rect2(0, 0, LARGEUR, HAUTEUR), FOND, true)
		_titre(Vector2(40, 46), "GRILLE DUALE — ce qu'il faut sculpter, et où passent les plans de coupe", 22)
		_texte(Vector2(40, 74),
			"une PIÈCE est un carré de la taille d'une case, centré sur un CROISEMENT ·"
			+ "  trait d'or = frontière de case, là où tombe le mur ·  contour gris = plan de coupe", 14, TEXTE_PALE)

		_panneau_formes(Vector2(40, 120))
		_panneau_configurations(Vector2(40, 400))
		_panneau_cas_concret(Vector2(40, 730))

	# ── panneau 1 : les six formes à sculpter ───────────────────────────────────────────────────────

	func _panneau_formes(origine: Vector2) -> void:
		_titre(origine, "1.  LES SIX FORMES — cinq à sculpter, la sixième ne dessine rien", 17)
		_texte(origine + Vector2(0, 24),
			"× 3 bandes verticales (pied / milieu / dessus) = 15 sculpts, et AUCUNE forme peinte n'est irreprésentable.",
			13, TEXTE_PALE)

		var exemples := [0b0000, 0b0001, 0b0011, 0b0101, 0b0111, 0b1111]
		var cote := 118.0
		for i in exemples.size():
			var centre := origine + Vector2(78 + i * 212, 130)
			var info: Dictionary = classer(exemples[i])
			_piece(centre, cote, exemples[i], true)
			_texte_centre(centre + Vector2(0, cote * 0.5 + 26), info["forme"], 16, TEXTE)
			_texte_centre(centre + Vector2(0, cote * 0.5 + 46), _legende(info["forme"]), 12, TEXTE_PALE)

	func _legende(forme: String) -> String:
		match forme:
			"rien": return "aucune case pleine"
			"coin": return "un angle extérieur"
			"mur": return "un mur droit"
			"diagonale": return "le cas ambigu"
			"rentrant": return "un angle rentrant"
			"plein": return "l'intérieur"
		return ""

	# ── panneau 2 : les seize configurations ────────────────────────────────────────────────────────

	func _panneau_configurations(origine: Vector2) -> void:
		_titre(origine, "2.  LES SEIZE CONFIGURATIONS — toutes servies par les six formes et une rotation", 17)
		_texte(origine + Vector2(0, 24),
			"1 rien · 4 coins · 4 murs · 2 diagonales · 4 rentrants · 1 plein = 16.  Aucun refus possible, jamais.",
			13, TEXTE_PALE)

		var cote := 74.0
		for bits in 16:
			var colonne: int = bits % 8
			var rangee: int = bits / 8
			var centre := origine + Vector2(60 + colonne * 162, 106 + rangee * 118)
			var info: Dictionary = classer(bits)
			_piece(centre, cote, bits, false)
			var etiquette: String = info["forme"]
			if info["quart"] != 0:
				etiquette += "  ×%d" % info["quart"]
			_texte_centre(centre + Vector2(0, cote * 0.5 + 20), etiquette, 13, TEXTE)

	# ── panneau 3 : un cas concret ──────────────────────────────────────────────────────────────────

	func _panneau_cas_concret(origine: Vector2) -> void:
		_titre(origine, "3.  UN CAS CONCRET — le peintre pose un carré de 2 × 2 cases", 17)
		_texte(origine + Vector2(0, 24),
			"⚠ une case peinte touche QUATRE croisements : le rendu vit sur une grille décalée d'une demi-case.",
			13, TEXTE_PALE)

		var case_px := 64.0
		var depart := origine + Vector2(60, 92)
		var pleines := {Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(1, 2): true, Vector2i(2, 2): true}

		# À gauche : ce que le peintre peint — des CASES.
		_texte(depart + Vector2(0, -18), "ce qu'il peint : 4 cases", 14, TEXTE)
		for y in 4:
			for x in 4:
				var r := Rect2(depart + Vector2(x * case_px, y * case_px), Vector2(case_px, case_px))
				draw_rect(r, MATIERE if pleines.has(Vector2i(x, y)) else VIDE, true)
				draw_rect(r, COUPE, false, 1.0)

		# À droite : ce que le plugin pose — neuf pièces centrées sur les croisements.
		# ⚠ ON NE DESSINE PAS la croix d'or de chaque pièce ici, et c'est délibéré : ce qu'il faut voir,
		# c'est que les neuf pièces assemblées redonnent EXACTEMENT la silhouette peinte. Neuf croix
		# noyaient précisément ça — la première version de cette planche l'a montré.
		var droite := depart + Vector2(4 * case_px + 150, 0)
		_texte(droite + Vector2(0, -18), "ce qu'il pose : 9 pièces — 4 coins, 4 murs, 1 plein", 14, TEXTE)
		for y in 4:
			for x in 4:
				draw_rect(Rect2(droite + Vector2(x * case_px, y * case_px), Vector2(case_px, case_px)), VIDE, true)
		var comptes := {}
		for cy in range(1, 4):
			for cx in range(1, 4):
				var bits := 0
				if pleines.has(Vector2i(cx - 1, cy - 1)):
					bits |= 1 << NO
				if pleines.has(Vector2i(cx, cy - 1)):
					bits |= 1 << NE
				if pleines.has(Vector2i(cx, cy)):
					bits |= 1 << SE
				if pleines.has(Vector2i(cx - 1, cy)):
					bits |= 1 << SO
				if bits == 0:
					continue
				var info: Dictionary = classer(bits)
				comptes[info["forme"]] = comptes.get(info["forme"], 0) + 1
				var centre := droite + Vector2(cx * case_px, cy * case_px)
				var demi := case_px * 0.5
				var quadrants := [Vector2(-demi, -demi), Vector2(0, -demi), Vector2(0, 0), Vector2(-demi, 0)]
				for q in 4:
					if bits & (1 << q):
						draw_rect(Rect2(centre + quadrants[q], Vector2(demi, demi)), MATIERE, true)
				draw_rect(Rect2(centre - Vector2(demi, demi), Vector2(case_px, case_px)), COUPE, false, 1.5)
				draw_circle(centre, 3.0, COUPE)
		# La silhouette du massif, en or : elle tombe PILE sur la frontière des cases peintes.
		draw_rect(Rect2(droite + Vector2(case_px, case_px), Vector2(2.0 * case_px, 2.0 * case_px)), OR, false, 3.0)
		_texte(droite + Vector2(0, 4.0 * case_px + 30),
			"le trait d'or est la frontière des cases : la silhouette assemblée tombe dessus, exactement.",
			13, OR)
		# ⚠ Prédiction posée AVANT de regarder : 4 coins, 4 murs, 1 plein. La planche l'imprime.
		print("cas concret — pièces posées : %s" % str(comptes))

	# ── le dessin d'une pièce ───────────────────────────────────────────────────────────────────────

	## Une pièce : un carré centré sur un croisement, quatre quadrants, le contour = les plans de coupe,
	## la croix intérieure = les frontières de cases (donc la ligne du mur).
	func _piece(centre: Vector2, cote: float, bits: int, avec_reperes: bool) -> void:
		var demi := cote * 0.5
		var coins := [Vector2(-demi, -demi), Vector2(0, -demi), Vector2(0, 0), Vector2(-demi, 0)]
		for q in 4:
			var r := Rect2(centre + coins[q], Vector2(demi, demi))
			draw_rect(r, MATIERE if (bits & (1 << q)) else VIDE, true)
		# La frontière des cases : la croix qui passe par le centre de la pièce.
		draw_line(centre + Vector2(-demi, 0), centre + Vector2(demi, 0), OR, 1.5)
		draw_line(centre + Vector2(0, -demi), centre + Vector2(0, demi), OR, 1.5)
		# Le plan de coupe : le contour de la pièce.
		draw_rect(Rect2(centre - Vector2(demi, demi), Vector2(cote, cote)), COUPE, false, 2.0)
		if avec_reperes:
			draw_circle(centre, 3.0, OR)

	# ── le texte ────────────────────────────────────────────────────────────────────────────────────

	func _titre(pos: Vector2, texte: String, taille: int) -> void:
		draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, TEXTE)

	func _texte(pos: Vector2, texte: String, taille: int, teinte: Color) -> void:
		draw_string(police, pos, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, teinte)

	func _texte_centre(pos: Vector2, texte: String, taille: int, teinte: Color) -> void:
		var largeur := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		draw_string(police, pos - Vector2(largeur * 0.5, 0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, teinte)
