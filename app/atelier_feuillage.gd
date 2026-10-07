extends RefCounted
## L'ATELIER FOLIAGE — DEMANDÉ PAR JORDAN (6 octobre 2026) : « un placement dans le monde de foliages comme des arbres
## dont on importe le fichier 3D comme glb et on place dans cet atelier sur un socle qui représente le sol pour cerner à
## quel offset l'objet sera placé par rapport au sol, et ensuite prévoir toutes les règles intelligentes de placement ;
## l'atelier Foliage a le monde dans sa vue comme World mais il ne pourra que placer des foliages, n'importe où avec des
## modes : dans le vide, planté au sol voisinage libre, planté au sol débordement ».
##
## La règle vit dans le cœur (`feuillage.gd`) ; le dessin et le vent dans `feuillage_vue.gd` ; le socle dans
## `socle_feuillage.gd`. Ici : la barre de droite, les clics dans le monde, l'annulation, le projet. Rien dans
## `editor.gd` que des branchements (comme `variantes.gd`).
##
## ⚠ LE FEUILLAGE APPARTIENT AU MONDE ENTIER, PAS À UNE COUCHE DE TUILES (PROPOSÉ, comme l'eau) : un arbre planté sur
## l'herbe d'une couche n'est pas « de » cette couche. Il est rangé par MODÈLE, et le projet porte ses modèles et ses
## plants (`"feuillage"` dans le `.mbproj`). Le `.glb` est COPIÉ dans le projet (`<projet>_foliage/`), comme les images
## des matériaux : un projet déplacé garde ses arbres.
## ⚠ IL NE SUIT PAS LE MONDE (OUVERT) : creuser sous un arbre le laisse en l'air. Il est posé au moment du clic.
## ⚠ PAS ENCORE DANS LE `.mbworld` NI DANS LES GREFFONS : dans la liste des greffons à faire (charte §0).

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const FeuillageVue := preload("res://app/feuillage_vue.gd")
const Socle := preload("res://app/socle_feuillage.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## La portée du rayon de la souris, en cases.
const PORTEE := 600.0
## Le pinceau pose un nouveau coup quand la souris a parcouru cette part de son rayon.
const PAS_DU_PINCEAU := 0.4

const NOMS_DES_MODES := {"air": "In the air", "sol_libre": "Planted · free", "sol_debord": "Planted · overflow"}
const RAISONS := {
	"dans_la_matiere": "inside the matter",
	"trop_pentu": "the ground is too steep",
	"dans_l_eau": "in the water",
	"au_bord": "its footprint is not on the ground (an edge, a wall)",
	"sous_la_matiere": "the matter is in the way above it",
	"trop_pres": "too close to another plant",
	"deja_la": "there is one here already",
	"pas_de_sol": "no ground under it",
}

var e: Node   # l'écran (editor.gd)
var modeles: Array = []
var plants: Array = []
var actif := -1
var mode := "sol_libre"
var pinceau := false
var lacet_alea := true
var rng := RandomNumberGenerator.new()
var _ix := FE.index([], {})
var _prochain_modele := 1
var _prochain_plant := 1
var _outil_avant := "ajouter"
var _vue_f: FeuillageVue

# Le coup en cours
var _coup := -1
var _ajoutes: Array = []
var _effaces: Array = []
var _dernier: Variant = null

# L'écran
var socle: Socle
var liste: VBoxContainer
var etiquette: Label
var etiquette_modele: Label
var nom_modele: LineEdit
var curseurs := {}       # clé → HSlider (réglages du modèle et du pinceau)
var _valeurs := {}       # clé → Label
var _boutons_mode := {}
var _boutons_outil := {}
var _remplit := false
var reglage_modele: VBoxContainer

# Le sol des tuiles : les triangles de chaque tuile posée, rangés par seaux (voir `_sol`).
var _tri_cache := {}
var _faces_par_item := {}


func _init(ecran: Node) -> void:
	e = ecran
	rng.randomize()


func brancher(vue_f: FeuillageVue) -> void:
	_vue_f = vue_f


# ── LA BARRE ─────────────────────────────────────────────────────────────────────────────────────────

func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("Foliage", true, Icones.icone("arbre"))
	pile.add_child(sec)
	var aide: Label = e._texte("Trees, bushes, grass: import a .glb, set it on the pedestal (where its ground is), then "
		+ "click in the world to plant it. Right click removes. It sways in the wind.", 11, Palette.GRIS)
	sec.contenu.add_child(aide)
	sec.contenu.add_child(e._bouton("Leave", "Back to World and its painting tools (Esc).",
		e._changer_d_atelier.bind("monde"), "croix"))
	sec.contenu.add_child(e._petit_titre("MODELS"))
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(liste)
	sec.contenu.add_child(e._rangee([
		e._bouton("Import .glb…", "A 3D model (glTF binary): it is copied into the project.",
			func() -> void: e._demander("feuillage"), "plus"),
	], 4))

	# Le modèle actif : son socle et ses réglages.
	reglage_modele = VBoxContainer.new()
	reglage_modele.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(reglage_modele)
	etiquette_modele = e._texte("", 11, Palette.OLIVE)
	reglage_modele.add_child(etiquette_modele)
	socle = Socle.new()
	socle.tooltip_text = ("The pedestal: its top is the GROUND. Drag to turn around, wheel to zoom. The ring is the "
		+ "footprint that « Planted · free » keeps clear.")
	reglage_modele.add_child(socle)
	_curseur(reglage_modele, "decalage", "Ground offset", -2.0, 2.0, 0.005, false,
		"How high the model's origin sits above the ground, in model units. Lower it to sink the roots.")
	reglage_modele.add_child(e._bouton("Sit its base on the ground", "Its lowest point exactly on the ground.",
		_asseoir, "bas"))
	_curseur(reglage_modele, "echelle", "Scale", 0.05, 50.0, 0.01, true, "The size of every plant of this model.")
	_curseur(reglage_modele, "echelle_alea", "Random size", 0.0, 0.9, 0.01, false,
		"Each plant draws a size between 1 − this and 1 + this.")
	_curseur(reglage_modele, "rayon", "Footprint", 0.05, 30.0, 0.01, true,
		"The radius, in cells (at scale 1), that « Planted · free » keeps on the ground and clear of other plants.")
	_curseur(reglage_modele, "vent", "Wind", 0.0, 1.0, 0.01, false, "How much it sways in the wind (0: still).")
	nom_modele = LineEdit.new()
	nom_modele.placeholder_text = "Name"
	nom_modele.text_submitted.connect(func(t: String) -> void: _renommer(t))
	nom_modele.focus_exited.connect(func() -> void: _renommer(nom_modele.text))
	reglage_modele.add_child(nom_modele)
	reglage_modele.add_child(e._rangee([
		e._bouton("Remove its plants", "Removes every plant of this model from the world (Ctrl+Z brings them back).",
			_effacer_tout, "poubelle"),
		e._bouton("Delete model", "Deletes the model and its plants (Ctrl+Z brings them back).",
			_supprimer_modele, "poubelle", Palette.DANGER),
	], 4))

	# Le placement.
	sec.contenu.add_child(e._petit_titre("PLACING"))
	sec.contenu.add_child(e._rangee_de_choix(_boutons_mode, [
		["air", "In the air", "haut", "Anywhere: on the plane of the grid floor (PgUp / PgDn), even over nothing."],
		["sol_libre", "Planted · free", "arbre", "On the ground you see, with room around it: refused on a slope, in "
			+ "the water, at an edge, under an overhang, or on another plant's footprint."],
		["sol_debord", "Planted · overflow", "arbre", "On the ground you see, overflowing edges, walls and other plants "
			+ "as it likes. Only the brush spacing keeps plants apart."],
	], _choisir_mode, "", 1))
	(_boutons_mode[mode] as Button).set_pressed_no_signal(true)
	sec.contenu.add_child(e._rangee_de_choix(_boutons_outil, [
		["un", "One per click", "plus", "A click plants one, where you click."],
		["pinceau", "Brush", "disque", "Paint plants: each dab tries several spots in the brush, and keeps those "
			+ "the rules accept."],
	], _choisir_outil, "", 2))
	(_boutons_outil["un"] as Button).set_pressed_no_signal(true)
	_curseur(sec.contenu, "pinceau_rayon", "Brush size", 0.5, 40.0, 0.1, true, "The brush radius, in cells (Alt+wheel).")
	_curseur(sec.contenu, "pinceau_essais", "Density", 1.0, 40.0, 1.0, false,
		"How many spots each dab tries (Shift+wheel).")
	_curseur(sec.contenu, "espacement", "Spacing", 0.0, 20.0, 0.05, false,
		"No two plants closer than this, in cells — in every mode.")
	_curseur(sec.contenu, "pente", "Max slope", 0.0, 90.0, 1.0, false,
		"Planted modes refuse a ground steeper than this, in degrees.")
	curseurs["pinceau_rayon"].value = 3.0
	curseurs["pinceau_essais"].value = 6.0
	curseurs["espacement"].value = 0.0
	curseurs["pente"].value = FE.PENTE_MAXI
	var tourner := CheckBox.new()
	tourner.text = "Random rotation"
	tourner.button_pressed = true
	tourner.focus_mode = Control.FOCUS_NONE
	tourner.toggled.connect(func(oui: bool) -> void: lacet_alea = oui)
	sec.contenu.add_child(tourner)
	etiquette = e._texte("", 11, Palette.GRIS)
	sec.contenu.add_child(etiquette)
	sec.contenu.add_child(e._texte("Not exported to the .mbworld yet, and the engine plugins do not plant foliage yet. "
		+ "A plant does not follow the ground if you dig under it later.", 10, Palette.GRIS))
	rafraichir_liste()


func _curseur(parent: Control, cle: String, nom: String, mini: float, maxi: float, pas: float, exp: bool,
		aide: String) -> void:
	var ligne := HBoxContainer.new()
	var l: Label = e._texte(nom, 11, Palette.GRIS)
	l.custom_minimum_size = Vector2(84, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(l)
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = pas
	c.exp_edit = exp
	c.tooltip_text = aide
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(c)
	var v: Label = e._texte("", 11, Palette.TEXTE)
	v.custom_minimum_size = Vector2(38, 0)
	v.size_flags_horizontal = Control.SIZE_FILL
	ligne.add_child(v)
	parent.add_child(ligne)
	curseurs[cle] = c
	_valeurs[cle] = v
	c.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x)) if pas >= 1.0 else ("%.2f" % x)
		_regle(cle, x))
	v.text = str(int(c.value)) if pas >= 1.0 else ("%.2f" % c.value)


func _regle(cle: String, x: float) -> void:
	if _remplit:
		return
	if cle in ["decalage", "echelle", "echelle_alea", "rayon", "vent"]:
		var m: Variant = modele_actif()
		if m == null:
			return
		m[cle] = x
		if cle in ["echelle", "rayon"]:
			_ix = FE.index(plants, _par_id())
		_dessiner_modele(m)
		socle.montrer(m)
		e._enregistrer_plus_tard()


func _choisir_mode(m: String) -> void:
	mode = m
	(_boutons_mode[m] as Button).set_pressed_no_signal(true)


func _choisir_outil(o: String) -> void:
	pinceau = o == "pinceau"
	(_boutons_outil[o] as Button).set_pressed_no_signal(true)


func modele_actif() -> Variant:
	return modeles[actif] if actif >= 0 and actif < modeles.size() else null


func _par_id() -> Dictionary:
	var d := {}
	for m in modeles:
		d[m["id"]] = m
	return d


func _plants_de(m: Dictionary) -> Array:
	return plants.filter(func(pl): return pl["modele"] == m["id"])


func rafraichir_liste() -> void:
	if liste == null:
		return
	for c in liste.get_children():
		c.queue_free()
	var groupe := ButtonGroup.new()
	for i in modeles.size():
		var m: Dictionary = modeles[i]
		var b := Button.new()
		var d := FeuillageVue.charger(str(m["chemin"]))
		b.text = "%s · %d" % [m["nom"], _plants_de(m).size()] + ("  ⚠ missing file" if d["erreur"] != "" else "")
		b.tooltip_text = str(m["chemin"]) + ("\n" + str(d["erreur"]) if d["erreur"] != "" else "")
		b.icon = Icones.icone("arbre")
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.button_pressed = i == actif
		b.pressed.connect(activer.bind(i))
		liste.add_child(b)
	if modeles.is_empty():
		liste.add_child(e._texte("No model yet — import a .glb.", 11, Palette.GRIS))
	reglage_modele.visible = modele_actif() != null
	_remplir_reglages()
	_dire_les_comptes()


func _dire_les_comptes() -> void:
	if etiquette != null:
		etiquette.text = "%d plant(s) in the world · %d model(s)" % [plants.size(), modeles.size()]


func activer(i: int) -> void:
	actif = i
	rafraichir_liste()


func _remplir_reglages() -> void:
	var m: Variant = modele_actif()
	if m == null or socle == null:
		if socle != null:
			socle.montrer(null)
		return
	_remplit = true
	var h := maxf(float(m["hauteur"]), 0.5)
	(curseurs["decalage"] as HSlider).min_value = -h
	(curseurs["decalage"] as HSlider).max_value = h * 0.5
	for cle in ["decalage", "echelle", "echelle_alea", "rayon", "vent"]:
		(curseurs[cle] as HSlider).value = float(m[cle])
		_valeurs[cle].text = "%.2f" % float(m[cle])
	nom_modele.text = str(m["nom"])
	_remplit = false
	var d := FeuillageVue.charger(str(m["chemin"]))
	etiquette_modele.text = ("%s — %.2f tall, %d part(s)" % [str(m["chemin"]).get_file(),
		(d["aabb"] as AABB).size.y, (d["parties"] as Array).size()]) if d["erreur"] == "" \
		else "⚠ %s: %s" % [str(m["chemin"]).get_file(), d["erreur"]]
	socle.montrer(m)


# ── LES MODÈLES ──────────────────────────────────────────────────────────────────────────────────────

## Un `.glb` choisi : copié dans le projet, lu, réglé par défaut (posé sur sa base), puis ajouté — UNE annulation.
func importer(fichier: String) -> void:
	var copie := _copier_dans_le_projet(fichier)
	var d := FeuillageVue.charger(copie)
	if d["erreur"] != "":
		e._dire("[color=#e0603c]Foliage[/color] — %s: %s." % [fichier.get_file(), d["erreur"]])
		return
	var m := FE.modele(_prochain_modele, fichier.get_file().get_basename(), copie)
	_prochain_modele += 1
	m.merge(FeuillageVue.reglages_par_defaut(d), true)
	e._histoire.create_action("Foliage: import « %s »" % m["nom"])
	e._histoire.add_do_method(_inserer_modele.bind(m, modeles.size(), []))
	e._histoire.add_undo_method(_retirer_modele.bind(m))
	e._histoire.commit_action()
	e._dire(("[b]Foliage model imported[/b] — « %s », %.2f tall. Set its ground on the pedestal, then click in the "
		+ "world to plant it.") % [m["nom"], (d["aabb"] as AABB).size.y])


## Le `.glb` copié dans `<projet>_foliage/` (le même fichier déjà là est repris ; un autre du même nom va à côté).
func _copier_dans_le_projet(fichier: String) -> String:
	var projet: String = e._projet
	if projet == "":
		return fichier
	var dossier := projet.get_basename() + "_foliage"
	if fichier.get_base_dir().simplify_path() == dossier.simplify_path():
		return fichier
	DirAccess.make_dir_recursive_absolute(dossier)
	var base := fichier.get_file().get_basename()
	var md5 := FileAccess.get_md5(fichier)
	for k in range(1, 100):
		var cible := dossier.path_join(base + ("" if k == 1 else "_%d" % k) + ".glb")
		if FileAccess.file_exists(cible):
			if FileAccess.get_md5(cible) == md5:
				return cible
			continue
		if DirAccess.copy_absolute(fichier, cible) != OK:
			return fichier
		return cible
	return fichier


func _inserer_modele(m: Dictionary, i: int, ses_plants: Array) -> void:
	modeles.insert(i, m)
	plants.append_array(ses_plants)
	actif = i
	_tout_redessiner()


func _retirer_modele(m: Dictionary) -> void:
	var i := modeles.find(m)
	if i < 0:
		return
	modeles.remove_at(i)
	plants = plants.filter(func(pl): return pl["modele"] != m["id"])
	actif = mini(actif, modeles.size() - 1)
	_tout_redessiner()


func _supprimer_modele() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var ses_plants := _plants_de(m)
	e._histoire.create_action("Foliage: delete « %s »" % m["nom"])
	e._histoire.add_do_method(_retirer_modele.bind(m))
	e._histoire.add_undo_method(_inserer_modele.bind(m, actif, ses_plants))
	e._histoire.commit_action()
	e._dire("[b]Model deleted[/b] — « %s » and its %d plant(s). [i]Ctrl+Z brings them back.[/i]"
		% [m["nom"], ses_plants.size()])


func _effacer_tout() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var ses_plants := _plants_de(m)
	if ses_plants.is_empty():
		return
	_valider([], ses_plants)


func _renommer(t: String) -> void:
	var m: Variant = modele_actif()
	t = t.strip_edges()
	if m == null or t == "" or t == m["nom"]:
		return
	m["nom"] = t
	rafraichir_liste()
	e._enregistrer_plus_tard()


func _asseoir() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var d := FeuillageVue.charger(str(m["chemin"]))
	if d["erreur"] != "":
		return
	(curseurs["decalage"] as HSlider).value = -(d["aabb"] as AABB).position.y


# ── LE MONDE ─────────────────────────────────────────────────────────────────────────────────────────

func entrer() -> void:
	if e._vue.outil != "feuillage":
		_outil_avant = e._vue.outil
	e._vue.outil = "feuillage"
	e._vue.oublier_ancre()
	if not e._vue.collage.is_empty():
		e._vue.annuler_collage()
	e._basculer_navigation(false)
	if actif < 0 and not modeles.is_empty():
		actif = 0
	rafraichir_liste()
	e._vue.rafraichir()
	e._dire("[b]Foliage[/b] — click to plant the model, right click to remove. Choose where it may grow: in the air, "
		+ "planted with room around it, or planted overflowing. [i]Esc to go back to World.[/i]")


func sortir() -> void:
	if e._vue.outil != "feuillage":
		return
	e._vue.outil = _outil_avant if _outil_avant != "feuillage" else "ajouter"
	_vue_f.montrer_fantome(null, [], Color.WHITE)
	_vue_f.montrer_anneaux([])
	if e._boutons_outil.has(e._vue.outil):
		(e._boutons_outil[e._vue.outil] as Button).set_pressed_no_signal(true)
	e._contexte_des_outils()
	e._vue.rafraichir()


## Le monde tel que la règle le lit.
func monde() -> Dictionary:
	return {
		"plein": func(c: Vector3i) -> bool: return e._vue._occupe_visible(c),
		"sol": _sol,
		"eau": func(p: Vector3) -> bool: return not e._eau_sous(FE.case_d_eau(p)).is_empty(),
	}


## Le point visé sous la souris : {"p", "normale", "y_haut"} (le sol, ou le plan de la grille en mode « air »), {} si
## rien. ⚠ PLANTÉ, ON VISE LA MATIÈRE PUIS ON DESCEND SUR LA SURFACE VUE : le rayon trouve la case (l'occupation, comme
## Sculpt), puis le sol est cherché par un rayon vertical contre les TRIANGLES des tuiles posées — un arbre se plante
## sur ce qu'on voit (l'aminci est un quart de case sous le dessus de la case, une sculpture ailleurs encore).
func vise(position: Vector2) -> Dictionary:
	var cam: Camera3D = e._vue.camera()
	var o := cam.project_ray_origin(position)
	var d := cam.project_ray_normal(position)
	if mode == "air":
		var y := float(e._vue.etage)
		if absf(d.y) < 1e-5:
			return {}
		var t := (y - o.y) / d.y
		if t <= 0.0:
			return {}
		return {"p": o + d * t, "normale": Vector3.UP, "y_haut": y}
	var r: Dictionary = Outils.rayon(func(c: Vector3i) -> bool: return e._vue._occupe_visible(c), o, d, PORTEE)
	if not r["touche"]:
		return {}
	var n: Vector3i = r["normale"]
	var c: Vector3i = r["case"]
	var axe := 0 if n.x != 0 else (1 if n.y != 0 else 2)
	var plan := float(c[axe]) + (1.0 if n[axe] > 0 else 0.0)
	var p := o + d * ((plan - o[axe]) / d[axe])
	var y_haut := float(c.y + 2)
	if n.y == 0:
		# Une paroi : le sol est devant elle, à son pied.
		p += Vector3(n) * 0.3
		y_haut = float(c.y + 1)
	elif n.y < 0:
		y_haut = float(c.y)
	var g = _sol(p.x, p.z, y_haut)
	if g == null:
		return {}
	return {"p": Vector3(p.x, g["y"], p.z), "normale": g["normale"], "y_haut": y_haut}


func survoler(position: Vector2) -> void:
	var m: Variant = modele_actif()
	var v := vise(position)
	if m == null or v.is_empty():
		_vue_f.montrer_fantome(null, [], Color.WHITE)
		_vue_f.montrer_anneaux([])
		return
	var anneaux: Array = []
	if pinceau:
		anneaux.append([v["p"], float(curseurs["pinceau_rayon"].value), Color(0.71, 0.74, 0.52)])
		_vue_f.montrer_fantome(null, [], Color.WHITE)
	else:
		var pl := FE.plant(-1, int(m["id"]), v["p"], 0.0, 1.0, mode)
		var raison := FE.verifier(m, pl, v["normale"], mode, monde(), _ix, _par_id(), _espacement(), _pente())
		var teinte := Color(0.45, 0.85, 0.45) if raison == "" else Color(0.95, 0.35, 0.3)
		_vue_f.montrer_fantome(m, [FE.transformation(m, pl)], teinte)
		anneaux.append([v["p"], float(m["rayon"]) * float(m["echelle"]), teinte])
	_vue_f.montrer_anneaux(anneaux)


func coup(position: Vector2, bouton: int, phase: int) -> void:
	match phase:
		0:
			_coup = bouton
			_ajoutes = []
			_effaces = []
			_dernier = null
			if bouton == MOUSE_BUTTON_LEFT and modele_actif() == null:
				e._dire("[i]Import a model first (« Import .glb… »).[/i]")
				_coup = -1
				return
			_appliquer(position)
		1:
			if _coup >= 0 and pinceau:
				_appliquer(position)
		2:
			if _coup >= 0:
				_coup = -1
				_finir()


func _espacement() -> float:
	return float(curseurs["espacement"].value) if curseurs.has("espacement") else 0.0


func _pente() -> float:
	return float(curseurs["pente"].value) if curseurs.has("pente") else FE.PENTE_MAXI


func _appliquer(position: Vector2) -> void:
	var v := vise(position)
	if v.is_empty():
		if not pinceau and _coup == MOUSE_BUTTON_LEFT:
			e._dire("[color=#e0603c]Foliage[/color] — " + ("no ground there." if mode != "air"
				else "the floor plane is not under the mouse."))
		return
	var rayon: float = curseurs["pinceau_rayon"].value
	if pinceau and _dernier != null and ((v["p"] as Vector3) - (_dernier as Vector3)).length() < rayon * PAS_DU_PINCEAU:
		return
	_dernier = v["p"]
	var modeles_ := _par_id()
	if _coup == MOUSE_BUTTON_RIGHT:
		var m: Variant = modele_actif()
		var portee := rayon if pinceau else maxf(0.6, float(m["rayon"]) * float(m["echelle"]) if m != null else 0.6)
		var pris := FE.a_effacer(_ix, v["p"], portee)
		if not pinceau and pris.size() > 1:
			pris.sort_custom(func(a, b): return ((a["p"] as Vector3) - v["p"]).length() < ((b["p"] as Vector3) - v["p"]).length())
			pris = [pris[0]]
		for pl in pris:
			FE.desindexer(_ix, pl)
			plants.erase(pl)
			_effaces.append(pl)
		if not pris.is_empty():
			_tout_redessiner(false)
		return
	var m: Dictionary = modele_actif()
	if pinceau:
		var centre := Vector3(v["p"].x, float(v["y_haut"]) + 1.0 if mode != "air" else v["p"].y, v["p"].z)
		var r := FE.semer(m, centre, rayon, int(curseurs["pinceau_essais"].value), mode, monde(), _ix, modeles_, rng,
			_espacement(), lacet_alea, _pente())
		for pl in r["plants"]:
			pl["id"] = _prochain_plant
			_prochain_plant += 1
			plants.append(pl)
			_ajoutes.append(pl)
		if not (r["plants"] as Array).is_empty():
			_dessiner_modele(m)
		return
	var r1 := FE.planter(m, v["p"], v["normale"], mode, monde(), _ix, modeles_, rng, _espacement(), lacet_alea, _pente())
	if r1["plant"] == null:
		e._dire("[color=#e0603c]Not planted[/color] — %s. [i](%s)[/i]" % [RAISONS.get(r1["raison"], r1["raison"]),
			NOMS_DES_MODES[mode]])
		return
	var pl: Dictionary = r1["plant"]
	pl["id"] = _prochain_plant
	_prochain_plant += 1
	plants.append(pl)
	FE.indexer(_ix, pl, modeles_)
	_ajoutes.append(pl)
	_dessiner_modele(m)


## La fin d'un coup : ce qu'il a planté et effacé devient UNE action (déjà faite à l'écran).
func _finir() -> void:
	if _ajoutes.is_empty() and _effaces.is_empty():
		return
	var a := _ajoutes.duplicate()
	var f := _effaces.duplicate()
	e._histoire.create_action("Foliage: " + ("plant %d" % a.size() if not a.is_empty() else "remove %d" % f.size()))
	e._histoire.add_do_method(_faire.bind(a, f))
	e._histoire.add_undo_method(_defaire.bind(a, f))
	e._histoire.commit_action(false)
	e._dire(("[b]%d planted[/b]" % a.size() if not a.is_empty() else "[b]%d removed[/b]" % f.size())
		+ " [i]Ctrl+Z undoes it.[/i]")
	_dire_les_comptes()
	rafraichir_liste()


## Une action déjà faite (le coup, l'effacement de tout un modèle).
func _valider(ajoutes: Array, effaces: Array) -> void:
	e._histoire.create_action("Foliage: remove %d" % effaces.size())
	e._histoire.add_do_method(_faire.bind(ajoutes, effaces))
	e._histoire.add_undo_method(_defaire.bind(ajoutes, effaces))
	e._histoire.commit_action()


func _faire(ajoutes: Array, effaces: Array) -> void:
	for pl in effaces:
		plants.erase(pl)
	for pl in ajoutes:
		if not plants.has(pl):
			plants.append(pl)
	_tout_redessiner()


func _defaire(ajoutes: Array, effaces: Array) -> void:
	for pl in ajoutes:
		plants.erase(pl)
	for pl in effaces:
		if not plants.has(pl):
			plants.append(pl)
	_tout_redessiner()


func _dessiner_modele(m: Dictionary) -> void:
	if _vue_f != null:
		_vue_f.poser_modele(m, _plants_de(m))


func _tout_redessiner(liste_aussi := true) -> void:
	_ix = FE.index(plants, _par_id())
	if _vue_f != null:
		_vue_f.poser(modeles, plants)
	if liste_aussi:
		rafraichir_liste()
	else:
		_dire_les_comptes()


## La molette (Alt : la taille du pinceau ; Maj : la densité).
func molette(sens: int, alt: bool, maj: bool) -> bool:
	if alt:
		return e._cran(curseurs["pinceau_rayon"], sens, "Brush size", 1.15)
	if maj:
		return e._cran(curseurs["pinceau_essais"], sens, "Density")
	return false


# ── LE SOL DES TUILES ────────────────────────────────────────────────────────────────────────────────

## Le sol sous (x, z), cherché vers le bas depuis `y_haut` : le premier triangle des tuiles POSÉES (couches visibles)
## que rencontre un rayon vertical. {y, normale}, ou null. Sans tuile (une couche sans lot), le dessus des cases.
## ⚠ LE SOMMET `v` PORTE LA PIÈCE [v + ½, v + 3/2] (charte §2) : la colonne de tuiles sous x est ⌊x − ½⌋, et ses
## voisines (un relief déborde) ; on descend niveau par niveau, et un niveau sous le premier touché suffit.
func _sol(x: float, z: float, y_haut: float) -> Variant:
	var grilles: Array = []
	for i in e._vue.nombre_de_couches():
		var c: Node = e._vue.couche(i)
		if (c as Node3D).visible:
			var g := c.get_node_or_null("Rendu") as GridMap
			if g != null and g.mesh_library != null:
				grilles.append(g)
	if grilles.is_empty():
		return FE.sol_des_cases(func(c: Vector3i) -> bool: return e._vue._occupe_visible(c), x, z, y_haut)
	var vx := floori(x - 0.5)
	var vz := floori(z - 0.5)
	var de := Vector3(x, y_haut, z)
	var meilleur := -INF
	var normale := Vector3.UP
	var touche_a := 1 << 30
	var vy := floori(y_haut - 0.5) + 1
	for _niveau in 96:
		if meilleur > -INF and vy < touche_a - 1:
			break   # un niveau sous le premier touché suffit (un relief déborde d'une case au plus)
		for g: GridMap in grilles:
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var cell := Vector3i(vx + dx, vy, vz + dz)
					if g.get_cell_item(cell) < 0:
						continue
					for tri in _triangles_sous(g, cell, x, z):
						var h = Geometry3D.ray_intersects_triangle(de, Vector3.DOWN, tri[0], tri[1], tri[2])
						if h == null:
							continue
						var y: float = (h as Vector3).y
						if y > meilleur and y <= y_haut:
							meilleur = y
							var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
							normale = -n if n.y < 0.0 else n
							touche_a = mini(touche_a, vy)
		vy -= 1
	if meilleur == -INF:
		return null
	return {"y": meilleur, "normale": normale}


## Les triangles de la tuile posée en `cell` dont la boîte en x, z contient (x, z) — par seaux de 4 × 4 (en cache).
func _triangles_sous(g: GridMap, cell: Vector3i, x: float, z: float) -> Array:
	var cle := "%d|%d|%s|%d|%d" % [g.get_instance_id(), g.mesh_library.get_instance_id(), cell, g.get_cell_item(cell),
		g.get_cell_item_orientation(cell)]
	if not _tri_cache.has(cle):
		if not _faces_par_item.has(g):
			_faces_par_item[g] = {}
		var faces: PackedVector3Array = e._vue._triangles_de_la_case(g, cell, _faces_par_item[g])
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in faces:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		var seaux: Array = []
		for k in 16:
			seaux.append([])
		var taille := (hi - lo) / 4.0
		for t in range(0, faces.size() - 2, 3):
			var a := faces[t]
			var b := faces[t + 1]
			var c := faces[t + 2]
			var tlo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var thi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			var i0 := _case_du_seau(tlo, lo, taille)
			var i1 := _case_du_seau(thi, lo, taille)
			for i in range(i0.x, i1.x + 1):
				for j in range(i0.y, i1.y + 1):
					(seaux[j * 4 + i] as Array).append([a, b, c])
		_tri_cache[cle] = {"lo": lo, "hi": hi, "taille": taille, "seaux": seaux}
	var t: Dictionary = _tri_cache[cle]
	var q := Vector2(x, z)
	if q.x < t["lo"].x or q.y < t["lo"].y or q.x > t["hi"].x or q.y > t["hi"].y:
		return []
	var k := _case_du_seau(q, t["lo"], t["taille"])
	return t["seaux"][k.y * 4 + k.x]


static func _case_du_seau(q: Vector2, lo: Vector2, taille: Vector2) -> Vector2i:
	var i := 0 if taille.x <= 0.0 else clampi(floori((q.x - lo.x) / taille.x), 0, 3)
	var j := 0 if taille.y <= 0.0 else clampi(floori((q.y - lo.y) / taille.y), 0, 3)
	return Vector2i(i, j)


# ── LE PROJET ────────────────────────────────────────────────────────────────────────────────────────

func vers_donnees() -> Dictionary:
	return FE.vers_donnees(modeles, plants)


## Le feuillage d'un projet ouvert (déjà lu et vérifié par `Projet.depuis_texte`).
func charger(d: Dictionary) -> void:
	modeles = (d.get("modeles", []) as Array).duplicate()
	plants = (d.get("plants", []) as Array).duplicate()
	_prochain_modele = 1
	for m in modeles:
		_prochain_modele = maxi(_prochain_modele, int(m["id"]) + 1)
	_prochain_plant = plants.size() + 1
	actif = 0 if not modeles.is_empty() else -1
	_tri_cache.clear()
	_faces_par_item.clear()
	_tout_redessiner()


func vider() -> void:
	modeles = []
	plants = []
	actif = -1
	_prochain_modele = 1
	_prochain_plant = 1
	_tri_cache.clear()
	_faces_par_item.clear()
	_coup = -1
	_tout_redessiner()
