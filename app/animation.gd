extends RefCounted
## L'ATELIER ANIMATION, À L'ÉCRAN — DÉCIDÉ (Jordan, 6 octobre 2026 : « un atelier d'animation complet avec possibilité
## de faire défilement, mais aussi frames (texture vidéo) […] animation pour chaque canal PBR […] une UI d'atelier où
## l'on ne crée que ce qu'on utilise, avec des + − »).
##
## Le modèle, le shader et les images sont dans le cœur (`animation_materiau.gd`) ; ici, la barre de droite, la lecture,
## l'import des images, et la rangée « Frame » de la section Paint de Texturing. `editor.gd` n'en garde que les
## branchements. L'atelier montre le TÉMOIN de la couche active (comme Geometry et Texturing) : on anime le matériau
## d'un témoin, et le monde le reçoit par le .glb lié.
##
##   • MATERIALS — ceux du témoin ; celui qu'on choisit est le matériau courant de Texturing aussi.
##   • TRACKS — RIEN tant qu'on n'en crée pas : « + » ajoute une piste (canal × genre), chaque piste a son « − ».
##   • PLAYBACK — lecture / pause, vitesse, retour à 0, une image tenue (toutes les pistes d'images la montrent).
## Chaque geste est UNE annulation (`editor._retoucher` puis `_inscrire_les_retouches`) ; un curseur fait UNE annulation
## par rafale (la minuterie des retouches de matériau).

const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## Les sources d'une piste neuve, dans la liste « + » (le genre, et pour les images d'où elles viennent).
const SOURCES := [
	["defilement", "", "Scroll", "The image slides across the faces, at a speed you set."],
	["images", "fichiers", "Frames from image files…", "A sequence of images (frame_001.png, frame_002.png…), "
		+ "played in the order of their names."],
	["images", "planche", "Frames from a sheet…", "One image cut into a grid of frames (a sprite sheet), read left "
		+ "to right, top to bottom."],
	["images", "vierges", "Blank frames to paint", "New frames filled with one colour: paint them one by one in "
		+ "Texturing (Paint, then Frame ◀ ▶)."],
	["pulsation", "", "Pulse", "The emission breathes: full, then down to a minimum, and back."],
]

var e: Node   # l'écran (editor.gd)

## L'image tenue par la lecture (−1 : les pistes jouent). Ne vaut que dans cet atelier.
var image_tenue := -1

var _etat: Label
var _liste_materiaux: VBoxContainer
var _corps: VBoxContainer          # tout ce qui dépend d'un matériau choisi
var _pistes: VBoxContainer
var _canal: OptionButton
var _source: OptionButton
var _reglages_source: HBoxContainer
var _colonnes: SpinBox
var _rangees: SpinBox
var _nombre: SpinBox
var _bouton_lecture: Button
var _vitesse: HSlider
var _tenue: SpinBox
var _horloge: Label
var _dialogue: FileDialog
var _en_attente := {}               # l'import demandé : {"canal", "source"}
var _signature := ""                # ce que montre la barre (redessinée quand le matériau change)

# La rangée « Frame » de la section Paint (Texturing).
var _rangee_peinture: HBoxContainer
var _image_peinte: Label


func _init(ecran: Node) -> void:
	e = ecran


# ── LA BARRE ─────────────────────────────────────────────────────────────────────────────────────────

func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("Animated textures", true, Icones.icone("film"))
	pile.add_child(sec)
	sec.contenu.add_child(e._texte("Animate any map of a witness material: Scroll slides it, Frames play a sequence of "
		+ "images (a texture video), Pulse makes the emission breathe. Nothing is added until you press +. Every copy "
		+ "of a tile, and the painted world, play it.", 11, Palette.GRIS))
	_etat = e._texte("", 11, Palette.AMBRE)
	sec.contenu.add_child(_etat)
	sec.contenu.add_child(e._petit_titre("MATERIAL"))
	_liste_materiaux = VBoxContainer.new()
	_liste_materiaux.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(_liste_materiaux)

	_corps = VBoxContainer.new()
	_corps.add_theme_constant_override("separation", 8)
	pile.add_child(_corps)
	var pistes := Section.new("Tracks", true, Icones.icone("couches"))
	_corps.add_child(pistes)
	_pistes = VBoxContainer.new()
	_pistes.add_theme_constant_override("separation", 8)
	pistes.contenu.add_child(_pistes)
	# LA RANGÉE « + » : un canal, une source, et le bouton. On ne crée que ce qu'on utilise.
	pistes.contenu.add_child(e._petit_titre("ADD A TRACK"))
	_canal = OptionButton.new()
	for c in Anim.CANAUX:
		_canal.add_item(Anim.NOMS_CANAUX[c])
		_canal.set_item_metadata(_canal.item_count - 1, c)
	_canal.tooltip_text = "Which map of the material the track animates."
	_canal.item_selected.connect(func(_i: int) -> void: _redire_les_sources())
	pistes.contenu.add_child(_canal)
	_source = OptionButton.new()
	_source.item_selected.connect(func(_i: int) -> void: _redire_les_reglages_source())
	pistes.contenu.add_child(_source)
	_reglages_source = HBoxContainer.new()
	_colonnes = _compteur("Cols", 1, 64, 4, "Columns of the sheet.")
	_rangees = _compteur("Rows", 1, 64, 4, "Rows of the sheet.")
	_nombre = _compteur("Frames", 0, Anim.IMAGES_MAXI, 0, "How many frames to read (0: every cell). For blank "
		+ "frames: how many to create.")
	for x in [_colonnes, _rangees, _nombre]:
		_reglages_source.add_child(x)
	pistes.contenu.add_child(_reglages_source)
	pistes.contenu.add_child(e._bouton("Add track", "Adds the track (+). Remove it with its − button.", _ajouter,
		"plus", Palette.PRINCIPAL))

	var lecture := Section.new("Playback", true, Icones.icone("jouer"))
	_corps.add_child(lecture)
	_bouton_lecture = e._bouton("Pause", "Plays or pauses every animated material — in the witness, the world and the "
		+ "Play test.", _basculer_lecture, "pause")
	lecture.contenu.add_child(e._rangee([_bouton_lecture, e._bouton("Restart", "Back to time 0.", func() -> void:
		Anim.temps = 0.0, "gauche")], 4))
	_vitesse = e._curseur_libre(lecture.contenu, "Speed", 0.0, 4.0, 0.05, "Plays faster or slower (1: the speed "
		+ "the tracks are set to). For this session only.")
	_vitesse.value = Anim.vitesse
	_vitesse.value_changed.connect(func(v: float) -> void: Anim.vitesse = v)
	var ligne := HBoxContainer.new()
	ligne.add_child(e._texte("Hold frame", 11, Palette.GRIS))
	_tenue = SpinBox.new()
	_tenue.min_value = -1
	_tenue.max_value = Anim.IMAGES_MAXI - 1
	_tenue.value = -1
	_tenue.tooltip_text = "−1: the frames play. Otherwise every Frames track shows this frame (counted from 0)."
	_tenue.value_changed.connect(func(v: float) -> void: image_tenue = int(v))
	_tenue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(_tenue)
	lecture.contenu.add_child(ligne)
	_horloge = e._texte("", 11, Palette.GRIS)
	lecture.contenu.add_child(_horloge)
	lecture.contenu.add_child(e._texte("Engines: Godot, Unity and Unreal receive frame 0 and the settings (glTF extras, "
		+ "« mb_animation »); the free plugins will play them in a later version. The frames live in the project's "
		+ "images folder.", 11, Palette.GRIS))

	_dialogue = FileDialog.new()
	_dialogue.access = FileDialog.ACCESS_FILESYSTEM
	_dialogue.use_native_dialog = true
	_dialogue.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Image")
	_dialogue.files_selected.connect(_fichiers_choisis)
	_dialogue.file_selected.connect(func(f: String) -> void: _fichiers_choisis(PackedStringArray([f])))
	pile.add_child(_dialogue)
	_redire_les_sources()
	redire()


func _compteur(nom: String, mini: int, maxi: int, valeur: int, aide: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mini
	s.max_value = maxi
	s.value = valeur
	s.prefix = nom
	s.tooltip_text = aide
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


## On entre dans l'atelier : le témoin de la couche active en édition (les matériaux sont les siens), la barre redite.
func entrer() -> void:
	e._regler_edition(true)
	redire()


# ── LE MATÉRIAU COURANT ──────────────────────────────────────────────────────────────────────────────

func _materiaux() -> Array:
	return e._modeleur.maillage.materiaux if e._modeleur.maillage != null else []


func _courant() -> int:
	var k: int = e._modeleur.materiau_courant
	return k if k >= 0 and k < _materiaux().size() else -1


func animation_courante() -> Dictionary:
	var k := _courant()
	return Anim.normaliser(_materiaux()[k].get("animation")) if k >= 0 else {}


## UN geste : la nouvelle animation du matériau courant, une annulation.
func poser(a: Dictionary, geste := true) -> void:
	if _courant() < 0:
		return
	var n := Anim.normaliser(a)
	e._retoucher("animation", n if not n.is_empty() else null)
	# ⚠ UN CURSEUR NE REDESSINE PAS LA BARRE : il serait détruit sous la souris en plein glissé.
	_signature = _signature_courante()
	if geste:
		e._inscrire_les_retouches()
		redire()


# ── LA BARRE REDITE ──────────────────────────────────────────────────────────────────────────────────

func redire() -> void:
	if _liste_materiaux == null:
		return
	for enfant in _liste_materiaux.get_children():
		_liste_materiaux.remove_child(enfant)
		enfant.queue_free()
	var mats := _materiaux()
	var groupe := ButtonGroup.new()
	for k in mats.size():
		var d: Dictionary = mats[k]
		var b := Button.new()
		var n := Anim.pistes(d.get("animation")).size()
		b.text = str(d.get("nom", "Material")) + ("   · %d track%s" % [n, "" if n == 1 else "s"] if n > 0 else "")
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.button_pressed = k == _courant()
		b.icon = Icones.icone("film") if n > 0 else null
		var kk := k
		b.pressed.connect(func() -> void:
			e._modeleur.materiau_courant = kk
			e._redire_les_materiaux()
			redire())
		_liste_materiaux.add_child(b)
	if e._modeleur.maillage == null:
		_etat.text = "Opening the witness of the active layer…"
	elif mats.is_empty():
		_etat.text = "This witness has no material yet: make one in Texturing (New material, Assign)."
	elif _courant() < 0:
		_etat.text = "Pick a material."
	else:
		_etat.text = ""
	_etat.visible = _etat.text != ""
	_corps.visible = _courant() >= 0
	_redire_les_pistes()
	_redire_les_sources()
	redire_la_peinture()


func _redire_les_pistes() -> void:
	for enfant in _pistes.get_children():
		_pistes.remove_child(enfant)
		enfant.queue_free()
	var a := animation_courante()
	var liste := Anim.pistes(a)
	if liste.is_empty():
		_pistes.add_child(e._texte("No track: this material is still. Add one below.", 11, Palette.GRIS))
	for p in liste:
		_pistes.add_child(_carte(p[0], p[1], a[p[0]][p[1]]))


## La carte d'une piste : son nom, son « − », et SES seuls réglages.
func _carte(canal: String, genre: String, g: Dictionary) -> Control:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", Palette.fond(Palette.bande_de(Palette.teinte("anim")), 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	cadre.add_child(v)
	var tete := HBoxContainer.new()
	var titre: Label = e._texte("%s · %s" % [Anim.NOMS_CANAUX[canal], Anim.NOMS_GENRES[genre]], 12, Palette.TEXTE)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tete.add_child(titre)
	var moins := Button.new()
	moins.icon = Icones.icone("moins")
	moins.tooltip_text = "Remove this track (−)."
	moins.focus_mode = Control.FOCUS_NONE
	moins.pressed.connect(func() -> void: poser(Anim.retirer(animation_courante(), canal, genre)))
	tete.add_child(moins)
	v.add_child(tete)
	match genre:
		"defilement":
			_curseur(v, canal, genre, "u", "Across (u)", -2.0, 2.0, 0.01, g, "Repeats of the image per second, "
				+ "across. ⚠ The tiles of the world are turned by quarter turns: across goes a different way on each.")
			_curseur(v, canal, genre, "v", "Along (v)", -2.0, 2.0, 0.01, g, "Repeats of the image per second, along "
				+ "— on walls in Box projection, up (−) or down (+) on every copy.")
		"images":
			var images: Array = g["images"]
			var taille := _taille_de(images)
			v.add_child(e._texte("%d frame%s, %d × %d" % [images.size(), "" if images.size() == 1 else "s", taille.x,
				taille.y], 11, Palette.GRIS))
			_curseur(v, canal, genre, "ips", "Frames/s", 0.5, Anim.IPS_MAXI, 0.5, g, "Frames per second.")
			_case(v, canal, genre, "aller_retour", "Ping-pong", g, "Plays forward, then backward, instead of looping.")
			v.add_child(e._rangee([
				e._bouton("Copy a frame", "Adds a copy of the held frame (or the last one) right after it — to paint "
					+ "the next one from it.", func() -> void: _dupliquer(canal), "copier"),
				e._bouton("Paint…", "Goes to Texturing with the brush on this track's frames (Frame ◀ ▶ in Paint)."
					if canal == "albedo" else "Only the base colour frames can be painted.", func() -> void:
					_peindre(canal), "remplir"),
			], 4))
		"pulsation":
			_curseur(v, canal, genre, "frequence", "Beats/s", 0.0, 5.0, 0.05, g, "How many times per second it "
				+ "breathes.")
			_curseur(v, canal, genre, "mini", "Low", 0.0, 1.0, 0.01, g, "The emission at the bottom of a breath "
				+ "(1: no pulse).")
	_case(v, canal, genre, "synchro", "Copies in sync", g, "Ticked: every copy plays together (a scroll stays "
		+ "continuous from tile to tile). Unticked: each copy starts at its own moment, drawn from its place — the "
		+ "repetition of a tile shows less.")
	return cadre


func _curseur(parent: Control, canal: String, genre: String, cle: String, nom: String, mini: float, maxi: float,
		pas: float, g: Dictionary, aide: String) -> void:
	var c: HSlider = e._curseur_libre(parent, nom, mini, maxi, pas, aide)
	c.value = float(g.get(cle, 0.0))
	var valeur: Label = e._texte("%.2f" % c.value, 11, Palette.GRIS)
	valeur.custom_minimum_size = Vector2(38, 0)
	c.get_parent().add_child(valeur)
	c.value_changed.connect(func(x: float) -> void:
		valeur.text = "%.2f" % x
		poser(Anim.regler(animation_courante(), canal, genre, cle, x), false))


func _case(parent: Control, canal: String, genre: String, cle: String, nom: String, g: Dictionary, aide: String) -> void:
	var c := CheckBox.new()
	c.text = nom
	c.tooltip_text = aide
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = bool(g.get(cle, false))
	c.toggled.connect(func(x: bool) -> void: poser(Anim.regler(animation_courante(), canal, genre, cle, x)))
	parent.add_child(c)


func _taille_de(images: Array) -> Vector2i:
	if images.is_empty():
		return Vector2i.ZERO
	var t: Dictionary = Peinture._toiles.get(images[0], {})
	if not t.is_empty():
		return (t["image"] as Image).get_size()
	var img := Image.load_from_file(images[0]) if FileAccess.file_exists(images[0]) else null
	return img.get_size() if img != null else Vector2i.ZERO


## Les sources possibles pour le canal choisi (la pulsation est celle de l'émission), sans celles qui existent déjà.
func _redire_les_sources() -> void:
	if _source == null:
		return
	var canal: String = _canal.get_item_metadata(_canal.selected)
	var a := animation_courante()
	var garde: Variant = _source.get_item_metadata(_source.selected) if _source.selected >= 0 else null
	_source.clear()
	for s in SOURCES:
		if not Anim.possible(canal, s[0]):
			continue
		if a.has(canal) and (a[canal] as Dictionary).has(s[0]):
			continue
		_source.add_item(s[2])
		_source.set_item_metadata(_source.item_count - 1, [s[0], s[1]])
		_source.set_item_tooltip(_source.item_count - 1, s[3])
		if garde == [s[0], s[1]]:
			_source.select(_source.item_count - 1)
	_source.disabled = _source.item_count == 0
	if _source.item_count == 0:
		_source.add_item("This map has every track")
	_redire_les_reglages_source()


func _redire_les_reglages_source() -> void:
	var s: Variant = _source.get_item_metadata(_source.selected) if _source.selected >= 0 else null
	var planche: bool = s is Array and s[1] == "planche"
	var vierges: bool = s is Array and s[1] == "vierges"
	_colonnes.visible = planche
	_rangees.visible = planche
	_nombre.visible = planche or vierges
	_reglages_source.visible = planche or vierges


# ── LES GESTES ───────────────────────────────────────────────────────────────────────────────────────

func _ajouter() -> void:
	if _courant() < 0 or _source.disabled:
		return
	var canal: String = _canal.get_item_metadata(_canal.selected)
	var s: Array = _source.get_item_metadata(_source.selected)
	match s[1]:
		"fichiers", "planche":
			_en_attente = {"canal": canal, "source": s[1]}
			_dialogue.file_mode = FileDialog.FILE_MODE_OPEN_FILES if s[1] == "fichiers" else FileDialog.FILE_MODE_OPEN_FILE
			_dialogue.title = "The frames, in order" if s[1] == "fichiers" else "A sprite sheet"
			_dialogue.popup_centered_ratio(0.6)
		"vierges":
			var taille := Vector2i(512, 512)
			var d: Dictionary = _materiaux()[_courant()]
			var img: String = str(d.get("texture", ""))
			if img != "" and not Peinture.toile(img).is_empty():
				taille = (Peinture.toile(img)["image"] as Image).get_size()
			var r: Dictionary = Anim.images_neuves(maxi(1, int(_nombre.value)), taille,
				d.get("couleur", Color.WHITE) if canal == "albedo" else (Color(0.5, 0.5, 1.0) if canal == "normale"
				else (Color.WHITE if canal == "orm" else Color.BLACK)), _dossier(), _base(canal))
			_finir_l_ajout(canal, r)
		_:
			_finir_l_ajout(canal, {}, s[0])


func _fichiers_choisis(fichiers: PackedStringArray) -> void:
	if _en_attente.is_empty():
		return
	var canal: String = _en_attente["canal"]
	var r: Dictionary
	if _en_attente["source"] == "planche":
		r = Anim.importer_planche(fichiers[0], int(_colonnes.value), int(_rangees.value), int(_nombre.value), _dossier(),
			_base(canal))
	else:
		r = Anim.importer_sequence(fichiers, _dossier(), _base(canal))
	_en_attente = {}
	_finir_l_ajout(canal, r)


## Ajoute la piste : `r` est le résultat d'un import ({"images"} ou {"erreur"}), vide pour une piste sans images.
func _finir_l_ajout(canal: String, r: Dictionary, genre := "images") -> void:
	if r.has("erreur"):
		e._dire("[color=#e0603c]No track added[/color] — %s." % r["erreur"])
		return
	var reglages := {}
	if genre == "images":
		reglages["images"] = r["images"]
	var a := Anim.ajouter(animation_courante(), canal, genre, reglages)
	if a.has("erreur"):
		e._dire("[color=#e0603c]No track added[/color] — %s." % a["erreur"])
		return
	poser(a)
	e._dire("[b]%s · %s[/b] added to « %s »%s. [i]Ctrl+Z removes it.[/i]" % [Anim.NOMS_CANAUX[canal],
		Anim.NOMS_GENRES[genre], _materiaux()[_courant()].get("nom", ""),
		(" — %d frames copied into the project" % (r["images"] as Array).size()) if genre == "images" else ""])


func _dupliquer(canal: String) -> void:
	var a := animation_courante()
	var images: Array = Anim.images_de(a, canal)
	var apres := clampi(image_tenue if image_tenue >= 0 else (e._modeleur.image_peinte if canal == "albedo"
		else images.size() - 1), 0, images.size() - 1)
	var r := Anim.dupliquer_image(images, apres, _dossier())
	if r.has("erreur"):
		e._dire("[color=#e0603c]%s[/color]" % r["erreur"])
		return
	poser(Anim.regler(a, canal, "images", "images", r["images"]))
	if canal == "albedo":
		e._modeleur.image_peinte = apres + 1
	redire_la_peinture()


func _peindre(canal: String) -> void:
	if canal != "albedo":
		e._dire("Only the base colour frames can be painted — the other maps are imported.")
		return
	e._changer_d_atelier("texture")
	if not e._modeleur.pinceau:
		e._bouton_pinceau.button_pressed = true
	redire_la_peinture()


func _signature_courante() -> String:
	return "%d|%d|%s" % [_courant(), _materiaux().size(), JSON.stringify(animation_courante())]


func _dossier() -> String:
	var base: String = e._modeleur.dossier_toiles if e._modeleur.dossier_toiles != "" \
		else e._projet.get_basename() + "_images"
	return base.path_join("animation")


func _base(canal: String) -> String:
	var nom := str(_materiaux()[_courant()].get("nom", "material")).to_lower().replace(" ", "_").validate_filename()
	return "%s_%s" % [nom, canal]


func _basculer_lecture() -> void:
	Anim.en_pause = not Anim.en_pause
	_bouton_lecture.text = "Play" if Anim.en_pause else "Pause"
	_bouton_lecture.icon = Icones.icone("jouer" if Anim.en_pause else "pause")


# ── LA RANGÉE « FRAME » DE LA PEINTURE (Texturing) ───────────────────────────────────────────────────

func rangee_peinture() -> Control:
	_rangee_peinture = HBoxContainer.new()
	_rangee_peinture.add_child(e._texte("Frame", 11, Palette.GRIS))
	for x in [["gauche", -1, "The previous frame."], ["droite", 1, "The next frame."]]:
		var b := Button.new()
		b.icon = Icones.icone(x[0])
		b.tooltip_text = x[2]
		b.focus_mode = Control.FOCUS_NONE
		var sens: int = x[1]
		b.pressed.connect(func() -> void: changer_d_image(sens))
		_rangee_peinture.add_child(b)
		if sens < 0:
			_image_peinte = e._texte("", 12, Palette.TEXTE)
			_image_peinte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_image_peinte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_rangee_peinture.add_child(_image_peinte)
	var copie := Button.new()
	copie.icon = Icones.icone("copier")
	copie.tooltip_text = "Adds a copy of this frame right after it, and paints the copy."
	copie.focus_mode = Control.FOCUS_NONE
	copie.pressed.connect(func() -> void: _dupliquer("albedo"))
	_rangee_peinture.add_child(copie)
	_rangee_peinture.tooltip_text = "The base colour of this material is animated by frames: the brush paints ONE frame."
	return _rangee_peinture


func changer_d_image(sens: int) -> void:
	var n := Anim.images_de(animation_courante(), "albedo").size()
	if n == 0:
		return
	e._modeleur.image_peinte = posmod(e._modeleur.image_peinte + sens, n)
	redire_la_peinture()
	e._redire_les_calques()


func redire_la_peinture() -> void:
	if _rangee_peinture == null:
		return
	var n := Anim.images_de(animation_courante(), "albedo").size()
	_rangee_peinture.visible = n > 0
	if n > 0:
		e._modeleur.image_peinte = clampi(e._modeleur.image_peinte, 0, n - 1)
		_image_peinte.text = "%d / %d" % [e._modeleur.image_peinte + 1, n]


# ── À CHAQUE IMAGE ───────────────────────────────────────────────────────────────────────────────────

## Le temps avance ; on PEINT une image d'animation (Texturing, pinceau allumé, albedo animé par images) : l'écran la
## montre, temps figé ; ailleurs, l'image tenue de la lecture (dans cet atelier seulement).
func suivre(delta: float) -> void:
	var peint: bool = e._atelier == "texture" and e._modeleur.pinceau \
		and not Anim.images_de(animation_courante(), "albedo").is_empty()
	Anim.fige = peint
	Anim.image_forcee = e._modeleur.image_peinte if peint else (image_tenue if e._atelier == "anim" else -1)
	Anim.avancer(delta)
	if _horloge != null and e._atelier == "anim":
		_horloge.text = "Time %.2f s%s" % [Anim.temps, "  · paused" if Anim.en_pause else ""]
	# Le matériau courant a changé ailleurs (Texturing, une annulation) : la barre le suit.
	var sig := _signature_courante()
	if sig != _signature and e._atelier in ["anim", "texture"]:
		_signature = sig
		if e._atelier == "anim":
			redire()
		else:
			redire_la_peinture()
