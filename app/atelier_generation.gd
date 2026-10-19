extends RefCounted
## L'ATELIER GENERATE — la 1.0.0 (Jordan, 19 octobre 2026 : « des mondes de taille / forme / réseaux de chemins /
## souterrains / aspects différents ? contrôlables ? » — « fais-le » ; sans IA).
##
## Le calcul vit dans `generateur.gd` (pur, gardé par `test_generateur`). Ici : la barre de droite (les champs, l'aperçu
## vu de haut, la couche de chaque rôle), et le geste « Generate », qui pose le monde par l'écran en UNE action annulable
## (`editor._poser_le_monde_genere`). Rien dans `editor.gd` que des branchements (comme `atelier_feuillage.gd`).
##
## ⚠ LE MONDE GÉNÉRÉ EST UN MONDE ORDINAIRE : il remplace les cases de TOUTES les couches dans sa boîte (et l'eau), puis
## on le reprend aux outils de World. Ctrl+Z rend l'ancien.
## ⚠ LES TÉMOINS NE SONT PAS GÉNÉRÉS : chaque rôle prend une couche du projet, avec ses tuiles et ses matériaux. Un rôle
## sans couche prend celle de son repli (`Generateur.REPLI` : le sable sans couche devient du sol…).

const G := preload("res://app/generateur.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## Les mots qui désignent une couche faite pour un rôle (le nom de la couche, en minuscules) : le premier choix proposé.
const MOTS := {
	"sol": ["grass", "meadow", "herbe", "prairie", "flowers", "ground", "sol"],
	"sol2": ["forest", "autumn", "foret", "flowers", "moss", "swamp", "mud"],
	"sable": ["sand", "beach", "desert", "sable", "plage", "dune"],
	"roche": ["rock", "stone", "cliff", "greyrock", "roche", "canyon", "mountain"],
	"neige": ["snow", "ice", "neige", "glace", "glacier"],
	"chemin": ["path", "cobble", "road", "gravel", "chemin", "pave", "brick"],
	"souterrain": ["cave", "cavern", "crystal", "grotte", "mushroom", "underground"],
}
## Les mots qui envoient un modèle de feuillage sur un rôle (son nom, en minuscules) ; un modèle qu'aucun mot ne range
## pousse sur les deux sols. ⚠ En français aussi (vu à l'image : les « cristal » du monde cartoon poussaient dans l'herbe).
const MOTS_FEUILLAGE := {
	"sable": ["cactus", "palm", "dune", "desert", "beach", "agave", "palmier", "plage"],
	"roche": ["rock", "pebble", "stone", "boulder", "roche", "rocher", "caillou", "galet", "pierre"],
	"neige": ["snow", "ice", "crystal", "frost", "neige", "glace", "cristal", "givre"],
}
const AIDES := {
	"largeur": "How many cells wide (x).", "profondeur": "How many cells deep (z).",
	"hauteur": "The highest a peak can rise, in cells.",
	"mer": "The sea level, in cells. 0: no sea — the land floats over nothing.",
	"relief": "Flat (0) to mountainous (1): how many massifs, and how high.",
	"detail": "Smooth (0) to rugged (1) coasts and hills.",
	"falaises": "Gentle slopes of one cell (0) to sheer cliffs of four (1).",
	"lieux": "Places (paved squares) linked by paths that never climb more than one cell at a time.",
	"boucles": "0: a single tree of paths. 1: paths loop between places.",
	"souterrains": "0: no caves. 1: many rooms joined by galleries three cells high, opening by stairs.",
	"puits": "The share of cave entrances that are wells (fly to climb out) instead of stairs.",
	"lacs": "Lakes dug in the land; the water fills them.", "sources": "River sources on the heights.",
	"lave": "Lava pools on the mountains.",
	"sable": "How wide the shores are.", "roche": "How much of the land is rock (the high ground).",
	"neige": "How much of the top is snow.",
	"feuillage": "How many plants: the foliage models of this project, picked by their name (trees and grass on the "
		+ "ground, cactus and palms on the shores, pebbles on rock, crystals on snow).", "sol2": "How much of the ground is the second ground (patches).",
}

var e: Node   # l'écran (editor.gd)
var champs := G.champs({})
## rôle → id de couche (`couche["id"]`) ; un rôle absent ou "" prend la couche proposée par son nom, ou son repli.
var couches_des_roles := {}

var _curseurs := {}
var _valeurs := {}
var _choix_roles := {}
var _forme: OptionButton
var _graine: SpinBox
var _melange: CheckBox
var _parois: CheckBox
var _tout: CheckBox
var _image: TextureRect
var _bilan: Label
var _nom_croquis: Label
var _remplit := false
var _apercu_prevu := false
var _apercu_age := 0


func _init(ecran: Node) -> void:
	e = ecran


func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("World generator", true, Icones.icone("generer"))
	pile.add_child(sec)
	sec.contenu.add_child(e._texte("Set the fields, look at the map, then Generate: a whole world, painted with the "
		+ "layers of this project. The same seed always makes the same world. No AI: rules and noise.", 11,
		Palette.GRIS))
	sec.contenu.add_child(e._bouton("Leave", "Back to World and its painting tools (Esc).",
		e._changer_d_atelier.bind("monde"), "croix"))
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.custom_minimum_size = Vector2(0, 230)
	_image.tooltip_text = ("Seen from above. Green: ground · gray: rock · white: snow · tan: shores and paths · "
		+ "red: places · black: cave entrances · blue dots: lakes and rivers · orange: lava.")
	sec.contenu.add_child(_image)
	_bilan = e._texte("", 10, Palette.GRIS)
	_bilan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sec.contenu.add_child(_bilan)

	sec.contenu.add_child(e._petit_titre("SEED"))
	var ligne := HBoxContainer.new()
	_graine = SpinBox.new()
	_graine.min_value = 0
	_graine.max_value = 999999
	_graine.step = 1
	_graine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graine.tooltip_text = "The same seed and the same fields make exactly the same world."
	_graine.value_changed.connect(func(v: float) -> void: _regle("graine", int(v)))
	ligne.add_child(_graine)
	ligne.add_child(e._bouton("New seed", "Another world with the same fields.", _nouvelle_graine, "variante"))
	sec.contenu.add_child(ligne)

	sec.contenu.add_child(e._petit_titre("SIZE AND SHAPE"))
	_forme = OptionButton.new()
	for f in G.FORMES:
		_forme.add_item(G.NOMS_FORMES[f])
	_forme.tooltip_text = ("The outline of the land. Sketch: paint an image in any app — blue sea, green land, gray "
		+ "mountains, white peaks, yellow shores, red dots for places — and pick it below.")
	_forme.item_selected.connect(func(k: int) -> void: _regle("forme", G.FORMES[k]))
	sec.contenu.add_child(_forme)
	_nom_croquis = e._texte("", 10, Palette.GRIS)
	sec.contenu.add_child(e._rangee([e._bouton("Sketch image…", "A PNG or JPG: blue sea, green land, gray mountains, "
		+ "white peaks, yellow shores, red dots for places.", func() -> void: e._demander("croquis"), "texture")], 4))
	sec.contenu.add_child(_nom_croquis)
	_curseur(sec.contenu, "largeur", "Width", 16, 256, 1)
	_curseur(sec.contenu, "profondeur", "Depth", 16, 256, 1)
	_curseur(sec.contenu, "hauteur", "Height", 8, 64, 1)

	sec.contenu.add_child(e._petit_titre("RELIEF"))
	_curseur(sec.contenu, "relief", "Relief", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "detail", "Ruggedness", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "falaises", "Cliffs", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "mer", "Sea level", 0, 24, 1)

	sec.contenu.add_child(e._petit_titre("PATHS"))
	_curseur(sec.contenu, "lieux", "Places", 0, 12, 1)
	_curseur(sec.contenu, "boucles", "Loops", 0.0, 1.0, 0.01)

	sec.contenu.add_child(e._petit_titre("UNDERGROUND"))
	_curseur(sec.contenu, "souterrains", "Caves", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "puits", "Wells", 0.0, 1.0, 0.01)

	sec.contenu.add_child(e._petit_titre("WATER"))
	_curseur(sec.contenu, "lacs", "Lakes", 0, 8, 1)
	_curseur(sec.contenu, "sources", "Rivers", 0, 8, 1)
	_curseur(sec.contenu, "lave", "Lava pools", 0, 4, 1)

	sec.contenu.add_child(e._petit_titre("LOOK"))
	_curseur(sec.contenu, "sable", "Shores", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "roche", "Rock", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "neige", "Snow", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "sol2", "2nd ground", 0.0, 1.0, 0.01)
	_curseur(sec.contenu, "feuillage", "Foliage", 0.0, 1.0, 0.01)
	_melange = CheckBox.new()
	_melange.text = "Blend materials"
	_melange.tooltip_text = ("Off: one material per level — two materials never meet on the same flat ground (they "
		+ "make squares). On: they do, and their transitions are switched on.")
	_melange.focus_mode = Control.FOCUS_NONE
	_melange.toggled.connect(func(oui: bool) -> void: _regle("melange", oui))
	sec.contenu.add_child(_melange)
	_parois = CheckBox.new()
	_parois.text = "Rock under the surface"
	_parois.tooltip_text = "Every cell under the top one is Rock: cliffs show the rock layer, tops keep theirs."
	_parois.focus_mode = Control.FOCUS_NONE
	_parois.toggled.connect(func(oui: bool) -> void: _regle("parois_roche", oui))
	sec.contenu.add_child(_parois)

	sec.contenu.add_child(e._petit_titre("LAYERS"))
	sec.contenu.add_child(e._texte("Each part of the world is painted with one layer of this project.", 10, Palette.GRIS))
	for r in G.ROLES:
		var l := HBoxContainer.new()
		var t: Label = e._texte(G.NOMS_ROLES[r], 11, Palette.GRIS)
		t.custom_minimum_size = Vector2(96, 0)
		l.add_child(t)
		var o := OptionButton.new()
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.fit_to_longest_item = false
		o.clip_text = true
		o.item_selected.connect(func(k: int) -> void: _role_choisi(r, k))
		l.add_child(o)
		_choix_roles[r] = o
		sec.contenu.add_child(l)

	_tout = CheckBox.new()
	_tout.text = "Replace the whole world"
	_tout.tooltip_text = ("On: every cell of every layer goes, and every plant — only the generated world stays. Off: "
		+ "only the cells inside the generator's box change; the rest of your world stays around it.")
	_tout.focus_mode = Control.FOCUS_NONE
	_tout.toggled.connect(func(oui: bool) -> void: _regle("tout_remplacer", oui))
	sec.contenu.add_child(_tout)
	var go: Button = e._bouton("Generate the world", ("Paints the world on the map with the layers above, and replaces "
		+ "the water. Ctrl+Z gives the old world back."), generer, "generer", Palette.PRINCIPAL)
	go.custom_minimum_size = Vector2(0, 40)
	sec.contenu.add_child(go)
	sec.contenu.add_child(e._texte("The world stays an ordinary world: paint, dig and plant on it afterwards. Foliage "
		+ "uses the models imported in the Foliage workshop.", 10, Palette.GRIS))
	_remplir()


func _curseur(parent: Control, cle: String, nom: String, mini: float, maxi: float, pas: float) -> void:
	var ligne := HBoxContainer.new()
	var l: Label = e._texte(nom, 11, Palette.GRIS)
	l.custom_minimum_size = Vector2(84, 0)
	l.tooltip_text = AIDES.get(cle, "")
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(l)
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = pas
	c.tooltip_text = AIDES.get(cle, "")
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(c)
	var v: Label = e._texte("", 11, Palette.TEXTE)
	v.custom_minimum_size = Vector2(34, 0)
	ligne.add_child(v)
	parent.add_child(ligne)
	_curseurs[cle] = c
	_valeurs[cle] = v
	c.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x)) if pas >= 1.0 else ("%.2f" % x)
		_regle(cle, int(x) if pas >= 1.0 else x))


## Les champs vers les contrôles (à l'ouverture d'un projet, à l'entrée dans l'atelier).
func _remplir() -> void:
	if _forme == null:
		return
	_remplit = true
	for cle in _curseurs:
		(_curseurs[cle] as HSlider).value = float(champs[cle])
		(_valeurs[cle] as Label).text = str(int(champs[cle])) if (_curseurs[cle] as HSlider).step >= 1.0 \
			else ("%.2f" % float(champs[cle]))
	_graine.value = int(champs["graine"])
	_forme.select(G.FORMES.find(champs["forme"]))
	_melange.button_pressed = bool(champs["melange"])
	_parois.button_pressed = bool(champs["parois_roche"])
	_tout.button_pressed = bool(champs["tout_remplacer"])
	_nom_croquis.text = str(champs["croquis"]).get_file() if str(champs["croquis"]) != "" else "No sketch picked."
	_remplit = false
	rafraichir_couches()


func _regle(cle: String, v: Variant) -> void:
	if _remplit:
		return
	champs[cle] = v
	champs = G.champs(champs)
	e._enregistrer_plus_tard()
	apercu_plus_tard()


func _nouvelle_graine() -> void:
	_graine.value = (int(champs["graine"]) * 7919 + 104729 + Time.get_ticks_usec()) % 1000000


func croquis_choisi(fichier: String) -> void:
	champs["croquis"] = fichier
	champs["forme"] = "croquis"
	_remplir()
	e._enregistrer_plus_tard()
	apercu_plus_tard()


## LA LISTE DES COUCHES de chaque rôle : « (fallback) » d'abord, puis les couches du projet.
func rafraichir_couches() -> void:
	if _choix_roles.is_empty():
		return
	for r in G.ROLES:
		var o: OptionButton = _choix_roles[r]
		o.clear()
		o.add_item("(as %s)" % G.NOMS_ROLES[G.REPLI[r]].to_lower() if G.REPLI.has(r) else "(first layer)")
		for c in e._couches:
			o.add_item(str(c["nom"]))
		var i := _couche_du_role(r, false)
		o.select(i + 1 if i >= 0 else 0)


func _role_choisi(r: String, k: int) -> void:
	couches_des_roles[r] = "-" if k == 0 else str(e._couches[k - 1].get("id", ""))
	e._enregistrer_plus_tard()


## La couche (indice) qui peint ce rôle : celle choisie, sinon celle dont le nom le dit ; −1 : aucune (avec `repli`,
## celle du rôle de repli).
func _couche_du_role(r: String, repli := true) -> int:
	var voulu := str(couches_des_roles.get(r, ""))
	if voulu == "-":
		return _couche_du_role(G.REPLI[r]) if repli and G.REPLI.has(r) else -1
	for i in e._couches.size():
		if voulu != "" and str(e._couches[i].get("id", "")) == voulu:
			return i
	if voulu == "":
		for mot in MOTS[r]:
			for i in e._couches.size():
				if str(e._couches[i]["nom"]).to_lower().contains(mot):
					return i
	if repli:
		if G.REPLI.has(r) and G.REPLI[r] != r:
			return _couche_du_role(G.REPLI[r])
		return 0 if not e._couches.is_empty() else -1
	return -1


## Le rôle → l'indice de couche, pour tous les rôles.
func couches_par_role() -> Dictionary:
	var sortie := {}
	for r in G.ROLES:
		sortie[r] = _couche_du_role(r)
	return sortie


func entrer() -> void:
	_remplir()
	apercu_plus_tard()
	e._dire("[b]Generate[/b] — set the fields on the right and watch the map; « Generate the world » paints it with "
		+ "the layers listed under LAYERS. [i]Ctrl+Z gives the old world back.[/i]")


func sortir() -> void:
	pass


## L'APERÇU suit les réglages, sans geler l'écran à chaque cran du curseur : il attend que la main s'arrête.
func apercu_plus_tard() -> void:
	_apercu_age += 1
	var age := _apercu_age
	if e.get_tree() == null:
		return
	await e.get_tree().create_timer(0.3).timeout
	if age != _apercu_age or not is_instance_valid(e) or e._atelier != "generer":
		return
	apercu()


func apercu() -> void:
	var m := G.generer(champs, true)
	_image.texture = ImageTexture.create_from_image(G.apercu(m, 256))
	_bilan.text = _dire_le_bilan(m, false)


func _dire_le_bilan(m: Dictionary, entier: bool) -> String:
	var r: Dictionary = m["rapport"]
	var t := "%d × %d × %d cells · %d place(s), %d path(s) · %d lake(s), %d river source(s), %d lava pool(s)" % [
		int(m["largeur"]), int(m["profondeur"]), int(m["hauteur"]), int(r.get("lieux", 0)), int(r.get("chemins", 0)),
		int(r.get("lacs", 0)), int(r.get("sources", 0)), int(r.get("laves", 0))]
	if entier:
		t += " · %d cave room(s), %d galler(ies), %d entrance(s) · %d cells" % [int(r.get("salles", 0)),
			int(r.get("galeries", 0)), int(r.get("entrees", 0)), int(r.get("cases", 0))]
	if e._feuillage.modeles.is_empty() and float(champs["feuillage"]) > 0.0:
		t += "
No foliage model in this project: import some in Foliage to plant the world."
	if str(r.get("croquis", "")) == "illisible":
		t += "\n⚠ The sketch image cannot be read: an island instead."
	return t


func generer() -> void:
	if e._couches.is_empty():
		e._dire("[color=#e0603c]Generate[/color] — this project has no layer to paint with. Add one in World first.")
		return
	await e._attendre("Generating the world", "the land, the paths, the caves", 0)
	var m := G.generer(champs)
	var cible := couches_par_role()
	e._fin_attente()
	await e._poser_le_monde_genere(m, cible)
	_bilan.text = _dire_le_bilan(m, true)


## LE FEUILLAGE DU MONDE GÉNÉRÉ : sur chaque point semé (`monde["semis"]`), un modèle du projet tiré parmi ceux de son
## rôle (les petits plus souvent que les grands), posé sur le vrai sol des tuiles et vérifié comme le pinceau de Foliage
## (« Planted · free » pour un arbre, « overflow » pour une herbe). Rend les plants, sans les poser (l'écran en fait une
## action). `garder` : les plants qui restent (hors de la boîte), pour l'espacement.
func plants_du_monde(monde: Dictionary, garder: Array) -> Array:
	var af: RefCounted = e._feuillage
	var semis: Array = monde.get("semis", [])
	if af.modeles.is_empty() or semis.is_empty():
		return []
	var par_role := {}
	for mo in af.modeles:
		var nom := str(mo["nom"]).to_lower()
		var roles := ["sol", "sol2"]
		for r in MOTS_FEUILLAGE:
			for mot in MOTS_FEUILLAGE[r]:
				if nom.contains(mot):
					roles = [r]
		var taille := maxf(float(mo.get("rayon", 0.5)) * float(mo.get("echelle", 1.0)), 0.15)
		for r in roles:
			if not par_role.has(r):
				par_role[r] = []
			par_role[r].append([mo, 1.0 / taille])
	# Le sable et le second sol sans modèle à eux prennent ceux du sol (une herbe sur la dune) ; la roche et la neige non
	# (un arbre de prairie n'a rien à faire sur un glacier).
	for r in ["sable", "sol2"]:
		if not par_role.has(r) and par_role.has("sol"):
			par_role[r] = par_role["sol"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(champs["graine"]), "feuillage"])
	var modeles_: Dictionary = af._par_id()
	var ix := FE.index(garder, modeles_)
	var sol: Dictionary = af.monde()
	var sortie: Array = []
	for s in semis:
		var choix: Array = par_role.get(s[3], [])
		if choix.is_empty():
			continue
		var total := 0.0
		for c in choix:
			total += float(c[1])
		var tire := rng.randf() * total
		var mo: Dictionary = choix[0][0]
		for c in choix:
			tire -= float(c[1])
			if tire <= 0.0:
				mo = c[0]
				break
		var t := FE.tirer(mo, rng)
		var mode := "sol_libre" if float(mo.get("rayon", 0.5)) * float(mo.get("echelle", 1.0)) >= 0.5 else "sol_debord"
		var r := FE.semer_candidats(mo, float(s[2]), [[s[0], s[1], t["lacet"], t["echelle"]]], mode, sol, ix, modeles_)
		for pl in r["plants"]:
			pl["id"] = af._prochain_plant
			af._prochain_plant += 1
			sortie.append(pl)
	return sortie


func vers_donnees() -> Dictionary:
	return {"champs": champs.duplicate(), "couches": couches_des_roles.duplicate()}


func charger(d: Dictionary) -> void:
	champs = G.champs(d.get("champs", {}) if d.get("champs", {}) is Dictionary else {})
	couches_des_roles = (d.get("couches", {}) as Dictionary).duplicate() if d.get("couches", {}) is Dictionary else {}
	_remplir()
