extends RefCounted
## L'ATELIER PRESHAPE — la 1.1.0 (Jordan, 21 octobre 2026 : « un atelier preshape qui contiendra des listes d'algo très
## ergonomiquement pour créer une multitude de grandes formes paramétrables sur une quantité suffisante et intelligente
## de facteurs […], packs d'un clic, avec vision de la forme en temps réel dans le ghost pendant qu'on la paramètre »).
##
## Les formes vivent dans `app/preshapes/` (pures, gardées par `test_preshapes`). Ici : la barre de droite (la liste,
## les packs, les curseurs DESSINÉS depuis les facteurs déclarés de la forme, la couche de chaque rôle), le FANTÔME qui
## suit la souris et se refait à chaque cran, et la POSE en une action annulable. Rien dans `editor.gd` que des
## branchements (comme `atelier_generation.gd`).
##
## ⚠ LE FANTÔME NE SE REBÂTIT PAS EN BOUGEANT : ses cubes sont en cases LOCALES, la souris ne déplace que leur nœud. Il se
## rebâtit quand un réglage change (au plus une fois par image), sans réparer les contacts (la pose, elle, répare).
## ⚠ LA POSE PASSE PAR LES COUCHES EXCLUSIVES : une case posée dans une couche est retirée des autres, ce que la forme
## creuse est retiré de toutes ; les contacts par une arête de la COUTURE avec le monde sont comblés ; les transitions
## entre les couches qui se touchent sont allumées (charte : aucune transition désactivée). Un Ctrl+Z rend tout.

const C := preload("res://app/preshapes/catalogue.gd")
const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const TRC := preload("res://addons/marchingblocks_core/transitions.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## Les mots qui désignent une couche faite pour un rôle (le nom de la couche, en minuscules) : le premier choix proposé.
const MOTS := {
	"sol": ["grass", "meadow", "herbe", "prairie", "ground", "sol"],
	"sol2": ["forest", "autumn", "foret", "moss", "hedge", "haie", "swamp", "mud"],
	"sable": ["sand", "beach", "desert", "sable", "plage", "dune"],
	"roche": ["rock", "stone", "cliff", "roche", "canyon", "mountain", "pierre"],
	"neige": ["snow", "ice", "neige", "glace", "glacier"],
	"chemin": ["path", "cobble", "road", "gravel", "chemin", "pave", "paving"],
	"pierre": ["brick", "masonry", "wall", "castle", "ruin", "marble", "mur", "brique", "temple", "cobble"],
	"toit": ["roof", "tile", "toit", "tuile", "shingle", "thatch"],
}
const TEINTE_CREUSE := Color(0.92, 0.36, 0.24, 0.22)
const ALPHA := 0.42

var e: Node   # l'écran (editor.gd)
## La forme choisie, ses valeurs (une par forme : changer de forme et revenir garde ses réglages), la graine.
var forme_id := "montagne"
var valeurs_par_forme := {}
var graine := 1
var quart := 0
var decalage := 0
var ancrer := true
## rôle → id de couche (`couche["id"]`) ; absent : la couche proposée par son nom, ou celle de son repli.
var couches_des_roles := {}
## Les packs de l'utilisateur : [{"forme", "nom", "valeurs"}], enregistrés avec le projet.
var packs_perso: Array = []
## Les formes posées, avec leur recette : [{"forme", "nom", "valeurs", "graine", "quart", "decalage", "ancre": [x, y, z]}].
var poses: Array = []

var _racine: Node3D
var _nuage: MultiMeshInstance3D
var _nuage_creux: MultiMeshInstance3D
var _nuage_fondations: MultiMeshInstance3D
var _forme_locale := {}
var _ancre: Variant = null
var _cle_fondations := ""
var _a_refaire := false
var _remplit := false

var _famille: OptionButton
var _recherche: LineEdit
var _liste: ItemList
var _liste_ids: Array = []
var _description: Label
var _grille_packs: GridContainer
var _nom_pack: LineEdit
var _facteurs: VBoxContainer
var _graine_boite: SpinBox
var _decalage_boite: SpinBox
var _quart_texte: Label
var _ancrer_case: CheckBox
var _roles: VBoxContainer
var _choix_roles := {}
var _bilan: Label
var _liste_poses: ItemList
var _vignettes := {}
var _a_peindre: Array = []


func _init(ecran: Node) -> void:
	e = ecran


## Le nœud du fantôme dans la vue (`vue.preformes`).
func brancher(racine: Node3D) -> void:
	_racine = racine
	_nuage = _nouveau_nuage(1.02)
	_nuage_creux = _nouveau_nuage(1.0)
	_nuage_fondations = _nouveau_nuage(1.0)


func _nouveau_nuage(cote: float) -> MultiMeshInstance3D:
	var boite := BoxMesh.new()
	boite.size = Vector3.ONE * cote
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	boite.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = boite
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.visible = false
	_racine.add_child(instance)
	return instance


static func _remplir(nuage: MultiMeshInstance3D, cases: Array, couleurs: Variant) -> void:
	var mm := nuage.multimesh
	mm.instance_count = cases.size()
	for i in cases.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cases[i]) + Vector3.ONE * 0.5))
		mm.set_instance_color(i, couleurs[i] if couleurs is Array else couleurs)
	nuage.visible = not cases.is_empty()


# ── LA BARRE ─────────────────────────────────────────────────────────────────────────────────────────

func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("Preshape", true, Icones.icone("preformes"))
	pile.add_child(sec)
	var c := sec.contenu
	c.add_child(e._texte("Pick a shape, set its factors or click a pack, and watch the ghost follow the mouse. Left click "
		+ "sets it into the world, right click turns it. Ctrl+Z takes it back.", 11, Palette.GRIS))
	c.add_child(e._bouton("Leave", "Back to World and its painting tools (Esc).", e._changer_d_atelier.bind("monde"),
		"croix"))

	c.add_child(e._petit_titre("SHAPES"))
	_famille = OptionButton.new()
	_famille.add_item("All families")
	for f in C.FAMILLES:
		_famille.add_item(C.NOMS_FAMILLES[f])
	_famille.tooltip_text = "Show one family of shapes."
	_famille.item_selected.connect(func(_k: int) -> void: _remplir_la_liste())
	c.add_child(_famille)
	_recherche = LineEdit.new()
	_recherche.placeholder_text = "Search: castle, arch, dune…"
	_recherche.clear_button_enabled = true
	_recherche.text_changed.connect(func(_t: String) -> void: _remplir_la_liste())
	c.add_child(_recherche)
	_liste = ItemList.new()
	_liste.custom_minimum_size = Vector2(0, 190)
	_liste.focus_mode = Control.FOCUS_NONE
	_liste.item_selected.connect(func(k: int) -> void: choisir(_liste_ids[k]))
	c.add_child(_liste)
	_description = e._texte("", 10, Palette.GRIS)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_description)

	c.add_child(e._petit_titre("PACKS"))
	c.add_child(e._texte("One click sets every factor. Right click removes one of yours.", 10, Palette.GRIS))
	_grille_packs = GridContainer.new()
	_grille_packs.columns = 2
	_grille_packs.add_theme_constant_override("h_separation", 4)
	_grille_packs.add_theme_constant_override("v_separation", 4)
	c.add_child(_grille_packs)
	var ligne := HBoxContainer.new()
	_nom_pack = LineEdit.new()
	_nom_pack.placeholder_text = "My pack"
	_nom_pack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(_nom_pack)
	ligne.add_child(e._bouton("Save as pack", "Keeps the factors below as a pack of this project.", _enregistrer_pack,
		"plus"))
	c.add_child(ligne)

	c.add_child(e._petit_titre("FACTORS"))
	_facteurs = VBoxContainer.new()
	c.add_child(_facteurs)
	c.add_child(e._rangee([e._bouton("Defaults", "Every factor of this shape back to its default.", _par_defaut,
		"gomme")], 4))

	c.add_child(e._petit_titre("SEED"))
	var lg := HBoxContainer.new()
	_graine_boite = SpinBox.new()
	_graine_boite.min_value = 0
	_graine_boite.max_value = 999999
	_graine_boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graine_boite.tooltip_text = "The same seed and the same factors make exactly the same shape."
	_graine_boite.value_changed.connect(func(v: float) -> void:
		if not _remplit:
			graine = int(v)
			_regle())
	lg.add_child(_graine_boite)
	lg.add_child(e._bouton("Another draw", "The same factors, another seed.", _autre_tirage, "variante"))
	c.add_child(lg)

	c.add_child(e._petit_titre("PLACING"))
	var lt := HBoxContainer.new()
	lt.add_child(e._bouton("Turn", "A quarter turn to the left (Shift+wheel, or right click in the view).",
		tourner.bind(-1), "gauche"))
	lt.add_child(e._bouton("Turn", "A quarter turn to the right (Shift+wheel, or right click in the view).",
		tourner.bind(1), "droite"))
	_quart_texte = e._texte("0°", 11, Palette.TEXTE)
	lt.add_child(_quart_texte)
	c.add_child(lt)
	var lh := HBoxContainer.new()
	var th: Label = e._texte("Height", 11, Palette.GRIS)
	th.custom_minimum_size = Vector2(84, 0)
	lh.add_child(th)
	_decalage_boite = SpinBox.new()
	_decalage_boite.min_value = -64
	_decalage_boite.max_value = 64
	_decalage_boite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decalage_boite.tooltip_text = ("Above (+) or into (−) the ground you aim at, in cells (Alt+wheel). Sink a mountain "
		+ "to bury its foot, raise a floating island.")
	_decalage_boite.value_changed.connect(func(v: float) -> void:
		if not _remplit:
			decalage = int(v)
			_regle())
	lh.add_child(_decalage_boite)
	c.add_child(lh)
	_ancrer_case = CheckBox.new()
	_ancrer_case.text = "Anchor to the ground"
	_ancrer_case.tooltip_text = ("The foot of the shape goes down to the world's matter under it (up to %d cells): no "
		+ "floating edges on a slope. Never under an arch or a floating island.") % C.ANCRAGE_MAXI
	_ancrer_case.focus_mode = Control.FOCUS_NONE
	_ancrer_case.toggled.connect(func(oui: bool) -> void:
		if not _remplit:
			ancrer = oui
			_cle_fondations = ""
			e._enregistrer_plus_tard()
			_suivre_l_ancre())
	c.add_child(_ancrer_case)

	c.add_child(e._petit_titre("LAYERS"))
	c.add_child(e._texte("Each part of the shape is painted with one layer of this project.", 10, Palette.GRIS))
	_roles = VBoxContainer.new()
	c.add_child(_roles)
	_bilan = e._texte("", 10, Palette.GRIS)
	_bilan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_bilan)

	c.add_child(e._petit_titre("PLACED IN THIS WORLD"))
	_liste_poses = ItemList.new()
	_liste_poses.custom_minimum_size = Vector2(0, 90)
	_liste_poses.focus_mode = Control.FOCUS_NONE
	_liste_poses.tooltip_text = "Every shape set in this world, with its recipe."
	c.add_child(_liste_poses)
	c.add_child(e._rangee([e._bouton("Load its recipe", ("The selected shape's factors, seed and turn come back on the "
		+ "right: set it again, or change it first."), _reprendre_la_recette, "ouvrir")], 4))
	_remplir_tout()


func _remplir_tout() -> void:
	if _liste == null:
		return
	_remplit = true
	_graine_boite.value = graine
	_decalage_boite.value = decalage
	_ancrer_case.button_pressed = ancrer
	_quart_texte.text = "%d°" % (quart * 90)
	_remplit = false
	_remplir_la_liste()
	_batir_les_facteurs()
	_batir_les_packs()
	rafraichir_couches()
	_remplir_les_poses()


func _remplir_la_liste() -> void:
	_liste.clear()
	_liste_ids.clear()
	var fam := "" if _famille.selected <= 0 else str(C.FAMILLES[_famille.selected - 1])
	var mot := _recherche.text.strip_edges().to_lower()
	for f in C.de_la_famille(fam):
		var texte := "%s — %s" % [f.nom, C.NOMS_FAMILLES[f.famille]]
		if mot != "" and not (texte.to_lower().contains(mot) or str(f.aide).to_lower().contains(mot)):
			continue
		_liste.add_item(f.nom)
		_liste.set_item_tooltip(_liste.item_count - 1, "%s\n%s" % [C.NOMS_FAMILLES[f.famille], f.aide])
		_liste_ids.append(f.id)
		if f.id == forme_id:
			_liste.select(_liste.item_count - 1)


func choisir(id: String) -> void:
	if C.forme(id) == null:
		return
	forme_id = id
	_batir_les_facteurs()
	_batir_les_packs()
	e._enregistrer_plus_tard()
	_regle()


func valeurs() -> Dictionary:
	var f: RefCounted = C.forme(forme_id)
	if not valeurs_par_forme.has(forme_id):
		valeurs_par_forme[forme_id] = C.valeurs(f)
	return valeurs_par_forme[forme_id]


## LES CURSEURS, DESSINÉS DEPUIS LES FACTEURS DÉCLARÉS : aucune interface écrite à la main par forme.
func _batir_les_facteurs() -> void:
	for n in _facteurs.get_children():
		_facteurs.remove_child(n)
		n.queue_free()
	var f: RefCounted = C.forme(forme_id)
	if f == null:
		return
	_description.text = f.aide
	var v := valeurs()
	for d in f.facteurs():
		var cle: String = d["cle"]
		var ligne := HBoxContainer.new()
		var l: Label = e._texte(d["nom"], 11, Palette.GRIS)
		l.custom_minimum_size = Vector2(84, 0)
		l.tooltip_text = d["aide"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(l)
		if d.has("choix"):
			var o := OptionButton.new()
			for t in d["choix"]:
				o.add_item(t)
			o.select(int(v[cle]))
			o.tooltip_text = d["aide"]
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.item_selected.connect(func(k: int) -> void: _regle_facteur(cle, k))
			ligne.add_child(o)
		elif d.get("bool", false):
			var b := CheckBox.new()
			b.button_pressed = bool(v[cle])
			b.tooltip_text = d["aide"]
			b.focus_mode = Control.FOCUS_NONE
			b.toggled.connect(func(oui: bool) -> void: _regle_facteur(cle, oui))
			ligne.add_child(b)
		else:
			var s := HSlider.new()
			s.min_value = d["mini"]
			s.max_value = d["maxi"]
			s.step = d["pas"]
			s.value = float(v[cle])
			s.tooltip_text = d["aide"]
			s.focus_mode = Control.FOCUS_NONE
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ligne.add_child(s)
			var entier: bool = float(d["pas"]) >= 1.0
			var val: Label = e._texte(str(int(v[cle])) if entier else "%.2f" % float(v[cle]), 11, Palette.TEXTE)
			val.custom_minimum_size = Vector2(34, 0)
			ligne.add_child(val)
			s.value_changed.connect(func(x: float) -> void:
				val.text = str(int(x)) if entier else "%.2f" % x
				_regle_facteur(cle, int(x) if entier else x))
		_facteurs.add_child(ligne)


func _regle_facteur(cle: String, x: Variant) -> void:
	valeurs()[cle] = x
	e._enregistrer_plus_tard()
	_regle()


func _par_defaut() -> void:
	valeurs_par_forme[forme_id] = C.valeurs(C.forme(forme_id))
	_batir_les_facteurs()
	_regle()


func _autre_tirage() -> void:
	_graine_boite.value = (graine * 7919 + 104729 + Time.get_ticks_usec()) % 1000000


func tourner(sens: int) -> void:
	quart = posmod(quart + sens, 4)
	_quart_texte.text = "%d°" % (quart * 90)
	e._enregistrer_plus_tard()
	_regle()


func hausser(sens: int) -> void:
	_decalage_boite.value = clampi(decalage + sens, -64, 64)


# ── LES PACKS ────────────────────────────────────────────────────────────────────────────────────────

func _packs_de(id: String) -> Array:
	var sortie: Array = []
	var f: RefCounted = C.forme(id)
	for p in f.packs():
		sortie.append({"nom": p[0], "valeurs": p[1], "perso": false})
	for p in packs_perso:
		if p["forme"] == id:
			sortie.append({"nom": p["nom"], "valeurs": p["valeurs"], "perso": true})
	return sortie


func _batir_les_packs() -> void:
	for n in _grille_packs.get_children():
		_grille_packs.remove_child(n)
		n.queue_free()
	for p in _packs_de(forme_id):
		var b := Button.new()
		b.text = p["nom"]
		b.clip_text = true
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = ("%s — your pack (right click removes it)" if p["perso"] else "%s") % p["nom"]
		b.add_theme_constant_override("icon_max_width", 32)
		b.pressed.connect(_appliquer_pack.bind(p["valeurs"]))
		if p["perso"]:
			b.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					_retirer_pack(p["nom"]))
		var cle := "%s/%s/%s" % [forme_id, p["nom"], hash(p["valeurs"])]
		if _vignettes.has(cle):
			b.icon = _vignettes[cle]
		else:
			_a_peindre.append([b, cle, forme_id, p["valeurs"]])
		_grille_packs.add_child(b)
	_peindre_les_vignettes()


## LES VIGNETTES, une par image : une forme bâtie coûte jusqu'à quelques centaines de ms, cinq d'un coup gèleraient
## l'écran au choix d'une forme.
func _peindre_les_vignettes() -> void:
	while not _a_peindre.is_empty():
		if e.get_tree() == null:
			return
		await e.get_tree().process_frame
		if _a_peindre.is_empty():
			return
		var t: Array = _a_peindre.pop_front()
		if not is_instance_valid(t[0]):
			continue
		var r := C.construire(t[2], t[3], 1, 0, 0, false)
		var tex := ImageTexture.create_from_image(C.vignette(r, 32))
		_vignettes[t[1]] = tex
		(t[0] as Button).icon = tex


func _appliquer_pack(entree: Dictionary) -> void:
	valeurs_par_forme[forme_id] = C.valeurs(C.forme(forme_id), entree)
	_batir_les_facteurs()
	e._enregistrer_plus_tard()
	_regle()


func _enregistrer_pack() -> void:
	var nom := _nom_pack.text.strip_edges()
	if nom == "":
		nom = "%s %d" % [C.forme(forme_id).nom, packs_perso.size() + 1]
	packs_perso = packs_perso.filter(func(p): return not (p["forme"] == forme_id and p["nom"] == nom))
	packs_perso.append({"forme": forme_id, "nom": nom, "valeurs": valeurs().duplicate()})
	_nom_pack.text = ""
	_batir_les_packs()
	e._enregistrer_plus_tard()
	e._dire("[b]Pack saved[/b] — « %s », with this project." % nom)


func _retirer_pack(nom: String) -> void:
	packs_perso = packs_perso.filter(func(p): return not (p["forme"] == forme_id and p["nom"] == nom))
	_batir_les_packs.call_deferred()
	e._enregistrer_plus_tard()
	e._dire("[i]Pack « %s » removed.[/i]" % nom)


# ── LES COUCHES DES RÔLES ───────────────────────────────────────────────────────────────────────────

func rafraichir_couches() -> void:
	if _roles == null:
		return
	for n in _roles.get_children():
		_roles.remove_child(n)
		n.queue_free()
	_choix_roles.clear()
	var roles: Array = (_forme_locale.get("cases", {}) as Dictionary).keys()
	roles.sort_custom(func(a, b): return C.ROLES.find(a) < C.ROLES.find(b))
	for r in roles:
		var l := HBoxContainer.new()
		var pastille := ColorRect.new()
		pastille.color = C.TEINTES.get(r, Color.WHITE)
		pastille.custom_minimum_size = Vector2(10, 10)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_child(pastille)
		var t: Label = e._texte(C.NOMS_ROLES.get(r, r), 11, Palette.GRIS)
		t.custom_minimum_size = Vector2(90, 0)
		t.tooltip_text = "The part of the shape the ghost shows in this color."
		l.add_child(t)
		var o := OptionButton.new()
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.fit_to_longest_item = false
		o.clip_text = true
		o.add_item("(as %s)" % C.NOMS_ROLES[C.REPLI[r]].to_lower() if C.REPLI.has(r) else "(first layer)")
		for c in e._couches:
			o.add_item(str(c["nom"]))
		var i := couche_du_role(r, false)
		o.select(i + 1 if i >= 0 else 0)
		o.item_selected.connect(func(k: int) -> void:
			couches_des_roles[r] = "-" if k == 0 else str(e._couches[k - 1].get("id", ""))
			e._enregistrer_plus_tard())
		l.add_child(o)
		_choix_roles[r] = o
		_roles.add_child(l)


## La couche (indice) qui peint ce rôle : celle choisie, sinon celle dont le nom le dit ; −1 : aucune (avec `repli`,
## celle du rôle de repli, puis la première).
func couche_du_role(r: String, repli := true) -> int:
	var voulu := str(couches_des_roles.get(r, ""))
	if voulu != "" and voulu != "-":
		for i in e._couches.size():
			if str(e._couches[i].get("id", "")) == voulu:
				return i
	if voulu == "":
		for mot in MOTS.get(r, []):
			for i in e._couches.size():
				if str(e._couches[i]["nom"]).to_lower().contains(mot):
					return i
	if repli:
		if C.REPLI.has(r):
			return couche_du_role(C.REPLI[r])
		return 0 if not e._couches.is_empty() else -1
	return -1


# ── LE FANTÔME ───────────────────────────────────────────────────────────────────────────────────────

func entrer() -> void:
	e._vue.outil = "preformes"
	e._vue.oublier_ancre()
	if not e._vue.collage.is_empty():
		e._vue.annuler_collage()
	e._basculer_navigation(false)
	_remplir_tout()
	_refaire()
	e._dire("[b]Preshape[/b] — pick a shape on the right; the ghost follows the mouse. [b]Left click[/b] sets it, "
		+ "[b]right click[/b] turns it, [b]Alt+wheel[/b] raises or sinks it. [i]Ctrl+Z takes it back. Esc to go back "
		+ "to World.[/i]")


func sortir() -> void:
	if _racine != null:
		for n in [_nuage, _nuage_creux, _nuage_fondations]:
			n.visible = false
	if e._vue.outil == "preformes":
		e._vue.outil = "ajouter"
		if e._boutons_outil.has("ajouter"):
			(e._boutons_outil["ajouter"] as Button).set_pressed_no_signal(true)
		e._contexte_des_outils()
	_ancre = null


## Un réglage a changé : le fantôme se refait à l'image suivante (une seule fois, quel que soit le nombre de crans).
func _regle() -> void:
	if _a_refaire:
		return
	_a_refaire = true
	(func() -> void:
		_a_refaire = false
		if e._atelier == "preformes":
			_refaire()).call_deferred()


func _refaire() -> void:
	_forme_locale = C.construire(forme_id, valeurs(), graine, quart, -decalage, false)
	var t := C.pleines(_forme_locale)
	var montrees := C.coquille(t)
	var couleurs: Array = []
	for c in montrees:
		var col: Color = C.TEINTES.get(t[c], Color.WHITE)
		col.a = ALPHA
		couleurs.append(col)
	_remplir(_nuage, montrees, couleurs)
	_remplir(_nuage_creux, C.coquille(_forme_locale["creuser"]), TEINTE_CREUSE)
	_cle_fondations = ""
	var roles_avant: Array = _choix_roles.keys()
	var roles: Array = (_forme_locale["cases"] as Dictionary).keys()
	roles_avant.sort()
	roles.sort()
	if roles != roles_avant:
		rafraichir_couches()
	var b: AABB = _forme_locale["boite"]
	_bilan.text = "%d cells · %d × %d × %d%s" % [int(_forme_locale["compte"]), int(b.size.x), int(b.size.z), int(b.size.y),
		(" · digs %d cells" % (_forme_locale["creuser"] as Dictionary).size()) if not (_forme_locale["creuser"] as Dictionary).is_empty() else ""]
	_suivre_l_ancre()


## La souris survole la vue : le fantôme se pose contre la face visée.
func survoler(position: Vector2) -> void:
	if _racine == null:
		return
	var point: Dictionary = e._vue.point_vise(position, "ajouter")
	if point.is_empty():
		_ancre = null
	else:
		_ancre = Outils.ancre("ajouter", point)
	_suivre_l_ancre()


func _suivre_l_ancre() -> void:
	if _racine == null:
		return
	var vu: bool = _ancre != null and e._atelier == "preformes"
	_racine.visible = vu
	if not vu:
		return
	_racine.position = Vector3(_ancre as Vector3i)
	# Les fondations dépendent du monde sous la forme : refaites quand l'ancre change, pas à chaque pixel.
	var cle := "%s|%s|%s" % [_ancre, ancrer, _forme_locale.get("compte", 0)]
	if cle == _cle_fondations:
		return
	_cle_fondations = cle
	var fo := _fondations(_forme_locale, _ancre) if ancrer else {}
	var cases: Array = fo.keys()
	var couleurs: Array = []
	for c in cases:
		var col: Color = C.TEINTES.get(fo[c], Color.WHITE)
		col.a = ALPHA * 0.6
		couleurs.append(col)
	_remplir(_nuage_fondations, cases, couleurs)


func _fondations(r: Dictionary, ancre: Vector3i) -> Dictionary:
	var occupe := func(c: Vector3i) -> bool: return e._vue._occupe_visible(c)
	return C.fondations(r, ancre, occupe, decalage)


func coup(position: Vector2, bouton: int, phase: int) -> void:
	if phase != 0:
		return
	if bouton == MOUSE_BUTTON_RIGHT:
		tourner(1)
		return
	survoler(position)
	if _ancre == null:
		e._dire("[i]Aim at the ground (or the grid) to set the shape.[/i]")
		return
	await poser(_ancre)


# ── LA POSE ──────────────────────────────────────────────────────────────────────────────────────────

## LA POSE en `ancre` (une case du monde) : UNE action annulable — le creusé retiré de toutes les couches, chaque case
## posée dans la couche de son rôle et retirée des autres, la couture réparée, les transitions qui manquent allumées.
func poser(ancre: Vector3i) -> void:
	if e._couches.is_empty():
		e._dire("[color=#e0603c]Preshape[/color] — this project has no layer to paint with. Add one in World first.")
		return
	var f: RefCounted = C.forme(forme_id)
	await e._attendre("Setting « %s »" % f.nom, "the shape, its seams with the world", 0)
	var r := C.construire(forme_id, valeurs(), graine, quart, -decalage, true)
	if ancrer:
		var fo := _fondations(r, ancre)
		for c in fo:
			if not (r["cases"] as Dictionary).has(fo[c]):
				r["cases"][fo[c]] = {}
			r["cases"][fo[c]][c] = true
	# Le rôle → la couche ; les cases en coordonnées du monde.
	var par_couche := {}   # indice → {case: true}
	var creuser := {}
	for c in r["creuser"]:
		creuser[c + ancre] = true
	var sans_couche: Array = []
	for role in r["cases"]:
		var i := couche_du_role(role)
		if i < 0:
			sans_couche.append(role)
			continue
		if not par_couche.has(i):
			par_couche[i] = {}
		for c in r["cases"][role]:
			par_couche[i][c + ancre] = true
	_reparer_la_couture(par_couche, creuser, r["boite"], ancre)
	# Les changements, grille par grille.
	var par_grille := {}
	var sans_tuiles: Array = []
	var posees := {}
	for i in par_couche:
		for c in par_couche[i]:
			posees[c] = i
	for i in e._vue.nombre_de_couches():
		var g := e._vue.couche(i).get_node("Cases") as GridMap
		var id: int = g.mesh_library.find_item_by_name("case") if g.mesh_library != null else -1
		var ch := {}
		for c in creuser:
			if not posees.has(c) and g.get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
				ch[c] = [g.get_cell_item(c), GridMap.INVALID_CELL_ITEM]
		for c in posees:
			var avant: int = g.get_cell_item(c)
			if int(posees[c]) == i:
				if id < 0:
					continue
				if avant != id:
					ch[c] = [avant, id]
			elif avant != GridMap.INVALID_CELL_ITEM:
				ch[c] = [avant, GridMap.INVALID_CELL_ITEM]
		if par_couche.has(i) and id < 0:
			sans_tuiles.append(str(e._couches[i]["nom"]))
		if not ch.is_empty():
			par_grille[g] = ch
	var recette := {"forme": forme_id, "nom": f.nom, "valeurs": valeurs().duplicate(), "graine": graine, "quart": quart,
		"decalage": decalage, "ancre": [ancre.x, ancre.y, ancre.z]}
	var h: UndoRedo = e._histoire
	h.create_action("Preshape: %s" % f.nom)
	var touchees: Array = []
	var total := 0
	for g in par_grille:
		for c in par_grille[g]:
			h.add_do_method((g as GridMap).set_cell_item.bind(c, par_grille[g][c][1]))
			h.add_undo_method((g as GridMap).set_cell_item.bind(c, par_grille[g][c][0]))
		touchees.append_array((par_grille[g] as Dictionary).keys())
		total += (par_grille[g] as Dictionary).size()
	h.add_do_method(e._reconstruire.bind(null, touchees))
	h.add_undo_method(e._reconstruire.bind(null, touchees))
	h.add_do_method(_noter_la_pose.bind(recette, true))
	h.add_undo_method(_noter_la_pose.bind(recette, false))
	var trans := _transitions_a_allumer(posees, creuser)
	var allumees: int = trans["n"]
	if allumees > 0:
		h.add_do_method(e._transitions._poser_paires.bind(trans["apres"]))
		h.add_undo_method(e._transitions._poser_paires.bind(trans["avant"]))
	h.commit_action()
	e._fin_attente()
	e._enregistrer_plus_tard()
	var texte := ("[b]%s set[/b] — %d cells changed%s. [i]Ctrl+Z takes it back.[/i]") % [f.nom, total,
		(", %d transition(s) switched on" % allumees) if allumees > 0 else ""]
	if not sans_tuiles.is_empty():
		texte += ("\n[color=#e0603c]%s has no tiles yet[/color]: its cells were not painted. Slice its witness in "
			+ "Project, or give its part to another layer under LAYERS.") % ", ".join(PackedStringArray(sans_tuiles))
	e._dire(texte)


## LA COUTURE : les contacts par une arête entre la forme et le monde autour (une marche qui touche un talus en biais),
## comblés par `FS.reparer_les_diagonales`, partis des cases de la forme et de leurs voisines. Chaque case ajoutée va
## dans la couche d'une voisine (celle de la forme d'abord).
func _reparer_la_couture(par_couche: Dictionary, creuser: Dictionary, boite: AABB, ancre: Vector3i) -> void:
	var pleines := {}
	var bas := Vector3i(boite.position) + ancre - Vector3i.ONE * 2
	var haut := Vector3i(boite.end) + ancre + Vector3i.ONE * 2
	var union: Dictionary = e._union
	# Le monde dans la boîte de la forme (élargie de deux cases), moins ce qu'elle creuse.
	for x in range(bas.x, haut.x + 1):
		for z in range(bas.z, haut.z + 1):
			for y in range(bas.y, haut.y + 1):
				var c := Vector3i(x, y, z)
				if union.has(c) and not creuser.has(c):
					pleines[c] = int(union[c])
	# Le départ : les cases de la forme et leurs voisines du monde (un damier de la couture en a toujours une).
	var depart := {}
	for i in par_couche:
		for c in par_couche[i]:
			pleines[c] = int(i)
	for i in par_couche:
		for c in par_couche[i]:
			depart[c] = true
			for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				if pleines.has(c + d):
					depart[c + d] = true
	var rep: Dictionary = FS.reparer_les_diagonales(pleines, false, {}, {}, depart.keys())
	for c in rep["poser"]:
		var couche := -1
		for d in [Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP]:
			if pleines.has(c + d):
				couche = int(pleines[c + d])
				break
		if couche < 0:
			continue
		if not par_couche.has(couche):
			par_couche[couche] = {}
		par_couche[couche][c] = true


## LES TRANSITIONS QUI MANQUENT (charte : aucune transition désactivée) — entre deux couches dont des cases se toucheront
## après la pose, une case de la forme d'un côté. Calculées AVANT la pose (le monde d'alors, plus la forme, moins le
## creusé) et rendues comme {"avant", "apres", "n"} : les paires vont dans la MÊME action que les cases — un Ctrl+Z rend
## tout (allumées une à une, chacune était une action, et le premier Ctrl+Z n'éteignait qu'une transition).
func _transitions_a_allumer(posees: Dictionary, creuser: Dictionary) -> Dictionary:
	var union: Dictionary = e._union
	var couche_de := func(c: Vector3i) -> int:
		if posees.has(c):
			return int(posees[c])
		if creuser.has(c):
			return -1
		return int(union.get(c, -1))
	var paires := {}
	for c in posees:
		var a: int = posees[c]
		for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			var b: int = couche_de.call(c + d)
			if b >= 0 and b != a:
				paires[Vector2i(mini(a, b), maxi(a, b))] = true
	var tr: RefCounted = e._transitions
	var avant: Dictionary = (tr.etat["paires"] as Dictionary).duplicate(true)
	var n := 0
	for p in paires:
		var cle: String = TRC.cle_de_paire(str(e._couches[p.x]["id"]), str(e._couches[p.y]["id"]))
		if bool((avant.get(cle, {}) as Dictionary).get("actif", false)):
			continue
		tr._paire(cle)["actif"] = true
		n += 1
	var apres: Dictionary = (tr.etat["paires"] as Dictionary).duplicate(true)
	tr.etat["paires"] = avant.duplicate(true)
	return {"avant": avant, "apres": apres, "n": n}


func _noter_la_pose(recette: Dictionary, oui: bool) -> void:
	if oui:
		poses.append(recette)
	else:
		poses.erase(recette)
	_remplir_les_poses()


func _remplir_les_poses() -> void:
	if _liste_poses == null:
		return
	_liste_poses.clear()
	for p in poses:
		var a: Array = p["ancre"]
		_liste_poses.add_item("%s at %d, %d, %d" % [p["nom"], int(a[0]), int(a[1]), int(a[2])])


func _reprendre_la_recette() -> void:
	var k := _liste_poses.get_selected_items()
	if k.is_empty():
		e._dire("[i]Select a shape in the list first.[/i]")
		return
	var p: Dictionary = poses[k[0]]
	if C.forme(str(p["forme"])) == null:
		return
	forme_id = p["forme"]
	valeurs_par_forme[forme_id] = C.valeurs(C.forme(forme_id), p["valeurs"])
	graine = int(p["graine"])
	quart = int(p["quart"])
	decalage = int(p["decalage"])
	_remplir_tout()
	_regle()
	e._dire("[b]Recipe loaded[/b] — « %s ». Change it, then click to set it again." % p["nom"])


# ── LE PROJET ────────────────────────────────────────────────────────────────────────────────────────

func vers_donnees() -> Dictionary:
	if poses.is_empty() and packs_perso.is_empty() and valeurs_par_forme.is_empty():
		return {}
	return {"forme": forme_id, "valeurs": valeurs_par_forme.duplicate(true), "graine": graine, "quart": quart,
		"decalage": decalage, "ancrer": ancrer, "couches": couches_des_roles.duplicate(),
		"packs": packs_perso.duplicate(true), "poses": poses.duplicate(true)}


## Un projet d'avant n'a rien ; une entrée abîmée est ignorée (ce sont des réglages et des recettes, pas le monde).
func charger(d: Dictionary) -> void:
	forme_id = str(d.get("forme", "montagne"))
	if C.forme(forme_id) == null:
		forme_id = "montagne"
	valeurs_par_forme = {}
	var vs: Variant = d.get("valeurs", {})
	if vs is Dictionary:
		for id in vs:
			if C.forme(str(id)) != null and vs[id] is Dictionary:
				valeurs_par_forme[str(id)] = C.valeurs(C.forme(str(id)), vs[id])
	graine = int(d.get("graine", 1)) if (d.get("graine", 1) is int or d.get("graine", 1) is float) else 1
	quart = posmod(int(d.get("quart", 0)) if d.get("quart", 0) is float or d.get("quart", 0) is int else 0, 4)
	decalage = clampi(int(d.get("decalage", 0)) if d.get("decalage", 0) is float or d.get("decalage", 0) is int else 0, -64, 64)
	ancrer = bool(d.get("ancrer", true))
	couches_des_roles = (d.get("couches", {}) as Dictionary).duplicate() if d.get("couches", {}) is Dictionary else {}
	packs_perso = []
	for p in d.get("packs", []) if d.get("packs", []) is Array else []:
		if p is Dictionary and C.forme(str(p.get("forme", ""))) != null and p.get("valeurs") is Dictionary:
			packs_perso.append({"forme": str(p["forme"]), "nom": str(p.get("nom", "Pack")), "valeurs": p["valeurs"]})
	poses = []
	for p in d.get("poses", []) if d.get("poses", []) is Array else []:
		if p is Dictionary and p.get("ancre") is Array and (p["ancre"] as Array).size() == 3:
			poses.append(p)
	_remplir_tout()
