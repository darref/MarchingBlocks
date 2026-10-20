extends RefCounted
## L'ATELIER CROSSINGS — LES FRANCHISSEURS. DÉCIDÉ (Jordan, 20 octobre 2026 : « il faut un workshop de franchiseurs
## (escaliers, pentes) éditables, et placables par dessus le terrain là où le test le permet », puis « Test de pose,
## sculpté, commençons avec pente et escaliers »). Charte, « l'atelier des franchisseurs ».
##
## La règle vit dans le cœur (`franchisseurs.gd`, gardée par `test_franchisseurs`). Ici : la barre de droite, la visée
## dans le monde (le fantôme vert ou rouge), les clics, l'annulation, le projet. Rien dans `editor.gd` que des
## branchements (comme `atelier_feuillage.gd`, dont c'est le patron).
##
## ⚠ UN FRANCHISSEUR APPARTIENT AU MONDE ENTIER, PAS À UNE COUCHE (comme le feuillage et l'eau) : il est posé PAR-DESSUS
## les tuiles, jamais dedans — la règle de pose des tuiles ne change pas.
## ⚠ IL NE SUIT PAS LE MONDE (comme le feuillage) : creuser sous un escalier le laisse en l'air ; il est posé au clic.
## ⚠ PAS ENCORE DANS LE `.mbworld` NI DANS LES GREFFONS (l'étape 4 de la charte), NI DANS LE MODELEUR (l'étape 2 bis : le
## bouton « Edit shape » viendra) : aujourd'hui, la forme de départ et ses dimensions.

const FR := preload("res://addons/marchingblocks_core/franchisseurs.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const Outils := preload("res://addons/marchingblocks_core/outils.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## La portée du rayon de la souris, en cases.
const PORTEE := 600.0
const VERT := Color(0.45, 0.85, 0.45, 0.6)
const ROUGE := Color(0.95, 0.35, 0.3, 0.6)
const NOMS_DES_GENRES := {"escalier": "Stairs", "pente": "Slope"}

var e: Node   # l'écran (editor.gd)
var modeles: Array = []
var poses: Array = []
var actif := -1
var quart_prefere := 0
var _prochain_modele := 1
var _prochain_pose := 1
var _outil_avant := "ajouter"

# Le dessin : un nœud du monde (`vue.franchisseurs`), un MeshInstance3D par pose, le fantôme.
var _racine: Node3D
var _fantome: MeshInstance3D
var _mat_fantome: StandardMaterial3D
var _mat_pose: StandardMaterial3D
var _maillages := {}   # id de modèle → ArrayMesh

# L'écran
var liste: VBoxContainer
var etiquette: Label
var reglage_modele: VBoxContainer
var nom_modele: LineEdit
var curseurs := {}
var _valeurs := {}
var _remplit := false


func _init(ecran: Node) -> void:
	e = ecran


func brancher(racine: Node3D) -> void:
	_racine = racine
	_mat_pose = StandardMaterial3D.new()
	_mat_pose.albedo_color = Color(0.78, 0.74, 0.66)
	_mat_pose.roughness = 0.9
	_mat_fantome = StandardMaterial3D.new()
	_mat_fantome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_fantome.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_fantome.albedo_color = VERT
	_mat_fantome.no_depth_test = true
	_fantome = MeshInstance3D.new()
	_fantome.name = "Fantome"
	_fantome.material_override = _mat_fantome
	_fantome.visible = false
	_racine.add_child(_fantome)


# ── LA BARRE ─────────────────────────────────────────────────────────────────────────────────────────

func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("Crossings", true, Icones.icone("escalier"))
	pile.add_child(sec)
	sec.contenu.add_child(e._texte("Stairs and slopes, set OVER the painted world where a wall can be climbed: aim at the "
		+ "foot of a wall (or at the wall itself) — green, it fits; red, it does not, and the bar says why. Click to set, "
		+ "right click removes.", 11, Palette.GRIS))
	sec.contenu.add_child(e._bouton("Leave", "Back to World and its painting tools (Esc).",
		e._changer_d_atelier.bind("monde"), "croix"))
	sec.contenu.add_child(e._rangee_vue())
	sec.contenu.add_child(e._petit_titre("MODELS"))
	liste = VBoxContainer.new()
	liste.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(liste)
	sec.contenu.add_child(e._rangee([
		e._bouton("New stairs", "A flight of stairs, to sculpt: one cell wide, one high, one deep to start.",
			nouveau_modele.bind("escalier"), "plus"),
		e._bouton("New slope", "A slope, to sculpt: one cell wide, one high, two deep to start.",
			nouveau_modele.bind("pente"), "plus"),
	], 4))
	reglage_modele = VBoxContainer.new()
	reglage_modele.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(reglage_modele)
	_curseur(reglage_modele, "largeur", "Width", 1, 8, "How many cells wide the way up is.")
	_curseur(reglage_modele, "hauteur", "Height", 1, 6, "How many cells it climbs: the height of the wall it needs.")
	_curseur(reglage_modele, "longueur", "Depth", 1, 12, "How many cells of ground it takes in front of the wall.")
	nom_modele = LineEdit.new()
	nom_modele.placeholder_text = "Name"
	nom_modele.text_submitted.connect(func(t: String) -> void: _renommer(t))
	nom_modele.focus_exited.connect(func() -> void: _renommer(nom_modele.text))
	reglage_modele.add_child(nom_modele)
	reglage_modele.add_child(e._rangee([
		e._bouton("Remove all", "Removes every crossing of this model from the world (Ctrl+Z brings them back).",
			_effacer_tout, "poubelle"),
		e._bouton("Delete model", "Deletes the model and its crossings (Ctrl+Z brings them back).",
			_supprimer_modele, "poubelle", Palette.DANGER),
	], 4))
	etiquette = e._texte("", 11, Palette.GRIS)
	sec.contenu.add_child(etiquette)
	rafraichir_liste()


func _curseur(parent: Control, cle: String, nom: String, mini: int, maxi: int, aide: String) -> void:
	var ligne := HBoxContainer.new()
	var l: Label = e._texte(nom, 11, Palette.GRIS)
	l.custom_minimum_size = Vector2(84, 0)
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(l)
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = 1
	c.tooltip_text = aide
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ligne.add_child(c)
	var v: Label = e._texte("", 11, Palette.TEXTE)
	v.custom_minimum_size = Vector2(38, 0)
	ligne.add_child(v)
	parent.add_child(ligne)
	curseurs[cle] = c
	_valeurs[cle] = v
	c.value_changed.connect(func(x: float) -> void:
		v.text = str(int(x))
		_regle(cle, int(x)))


## Une dimension du modèle actif : sa forme de départ est rebâtie à ces dimensions (⚠ une forme resculptée serait
## perdue : on le dit). Les poses déjà là gardent leur place ; celles qui ne tiennent plus sont DITES, pas retirées.
func _regle(cle: String, x: int) -> void:
	if _remplit:
		return
	var m: Variant = modele_actif()
	if m == null or int(m[cle]) == x:
		return
	var avant: Dictionary = (m as Dictionary).duplicate(true)
	m[cle] = x
	var perdu := bool(m.get("sculpte", false))
	m["maillage"] = FR.maillage_de_depart(m).vers_dictionnaire()
	m["sculpte"] = false
	var apres: Dictionary = (m as Dictionary).duplicate(true)
	e._histoire.create_action("Crossing: %s %d" % [cle, x])
	e._histoire.add_do_method(_remettre_modele.bind(int(m["id"]), apres))
	e._histoire.add_undo_method(_remettre_modele.bind(int(m["id"]), avant))
	e._histoire.commit_action(false)
	_maillages.erase(int(m["id"]))
	_tout_redessiner()
	var refusees := _poses_qui_ne_tiennent_plus(m)
	e._dire("[b]%s[/b] — %d × %d × %d cells.%s%s" % [m["nom"], m["largeur"], m["hauteur"], m["longueur"],
		" [color=#e0603c]Its sculpted shape was rebuilt from the start shape (Ctrl+Z brings it back).[/color]" if perdu else "",
		(" [color=#e0603c]%d crossing(s) no longer fit where they are.[/color]" % refusees) if refusees > 0 else ""))
	e._enregistrer_plus_tard()


func _remettre_modele(id: int, d: Dictionary) -> void:
	for i in modeles.size():
		if int(modeles[i]["id"]) == id:
			modeles[i] = d.duplicate(true)
	_maillages.erase(id)
	_tout_redessiner()
	rafraichir_liste()


func _poses_qui_ne_tiennent_plus(m: Dictionary) -> int:
	var prises := FR.prises_de(_par_id(), poses)
	var n := 0
	for p in poses:
		if int(p["modele"]) == int(m["id"]) and FR.verifier(m, p, _plein(), prises) != "":
			n += 1
	return n


func rafraichir_liste() -> void:
	if liste == null:
		return
	for c in liste.get_children():
		c.queue_free()
	var groupe := ButtonGroup.new()
	for i in modeles.size():
		var m: Dictionary = modeles[i]
		var b := Button.new()
		b.text = "%s · %d×%d×%d · %d" % [m["nom"], m["largeur"], m["hauteur"], m["longueur"], _poses_de(m).size()]
		b.tooltip_text = "%s, %d cell(s) wide, climbs %d, takes %d in front of the wall." % [
			NOMS_DES_GENRES.get(m["genre"], m["genre"]), m["largeur"], m["hauteur"], m["longueur"]]
		b.icon = Icones.icone("escalier")
		b.toggle_mode = true
		b.button_group = groupe
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.button_pressed = i == actif
		b.pressed.connect(activer.bind(i))
		liste.add_child(b)
	if modeles.is_empty():
		liste.add_child(e._texte("No model yet — « New stairs » or « New slope ».", 11, Palette.GRIS))
	reglage_modele.visible = modele_actif() != null
	_remplir_reglages()
	if etiquette != null:
		etiquette.text = "%d crossing(s) in the world · %d model(s)" % [poses.size(), modeles.size()]


func _remplir_reglages() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	_remplit = true
	for cle in ["largeur", "hauteur", "longueur"]:
		(curseurs[cle] as HSlider).value = int(m[cle])
		(_valeurs[cle] as Label).text = str(int(m[cle]))
	nom_modele.text = str(m["nom"])
	_remplit = false


func activer(i: int) -> void:
	actif = i
	rafraichir_liste()


func modele_actif() -> Variant:
	return modeles[actif] if actif >= 0 and actif < modeles.size() else null


func nouveau_modele(genre: String) -> void:
	var m := FR.modele(_prochain_modele, NOMS_DES_GENRES[genre], genre, 1, 1, 2 if genre == "pente" else 1)
	_prochain_modele += 1
	m["maillage"] = FR.maillage_de_depart(m).vers_dictionnaire()
	e._histoire.create_action("Crossing: new %s" % m["nom"])
	e._histoire.add_do_method(_inserer_modele.bind(m))
	e._histoire.add_undo_method(_retirer_modele.bind(m))
	e._histoire.commit_action()
	actif = modeles.find(m)
	rafraichir_liste()
	e._enregistrer_plus_tard()


func _inserer_modele(m: Dictionary) -> void:
	if not modeles.has(m):
		modeles.append(m)
	rafraichir_liste()


func _retirer_modele(m: Dictionary) -> void:
	modeles.erase(m)
	actif = clampi(actif, -1, modeles.size() - 1)
	_maillages.erase(int(m["id"]))
	rafraichir_liste()


func _renommer(t: String) -> void:
	var m: Variant = modele_actif()
	t = t.strip_edges()
	if m == null or t == "" or t == m["nom"]:
		return
	m["nom"] = t
	rafraichir_liste()
	e._enregistrer_plus_tard()


func _effacer_tout() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var pris := _poses_de(m)
	if pris.is_empty():
		return
	_valider([], pris, "remove %d" % pris.size())


func _supprimer_modele() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var pris := _poses_de(m)
	e._histoire.create_action("Crossing: delete %s" % m["nom"])
	e._histoire.add_do_method(_faire.bind([], pris))
	e._histoire.add_do_method(_retirer_modele.bind(m))
	e._histoire.add_undo_method(_inserer_modele.bind(m))
	e._histoire.add_undo_method(_defaire.bind([], pris))
	e._histoire.commit_action()
	e._enregistrer_plus_tard()


# ── LE MONDE ─────────────────────────────────────────────────────────────────────────────────────────

func entrer() -> void:
	if e._vue.outil != "franchisseurs":
		_outil_avant = e._vue.outil
	e._vue.outil = "franchisseurs"
	e._vue.oublier_ancre()
	if not e._vue.collage.is_empty():
		e._vue.annuler_collage()
	e._basculer_navigation(false)
	if modeles.is_empty():
		# Les deux modèles de départ : un escalier et une pente, à poser tout de suite (et à resculpter).
		for g in ["escalier", "pente"]:
			var m := FR.modele(_prochain_modele, NOMS_DES_GENRES[g], g, 1, 1, 2 if g == "pente" else 1)
			_prochain_modele += 1
			m["maillage"] = FR.maillage_de_depart(m).vers_dictionnaire()
			modeles.append(m)
	if actif < 0 and not modeles.is_empty():
		actif = 0
	rafraichir_liste()
	e._vue.rafraichir()
	e._dire("[b]Crossings[/b] — aim at the foot of a wall: green, the stairs fit; click to set them. Right click removes. "
		+ "[i]Esc to go back to World.[/i]")


func sortir() -> void:
	if e._vue.outil != "franchisseurs":
		return
	e._vue.outil = _outil_avant if _outil_avant != "franchisseurs" else "ajouter"
	if _fantome != null:
		_fantome.visible = false
	if e._boutons_outil.has(e._vue.outil):
		(e._boutons_outil[e._vue.outil] as Button).set_pressed_no_signal(true)
	e._contexte_des_outils()
	e._vue.rafraichir()


func _plein() -> Callable:
	return func(c: Vector3i) -> bool: return e._vue._occupe_visible(c)


## LA CASE VISÉE : {"bas": la case vide du pied, "vers": le quart de tour que la visée suggère (−1 : aucun)}, {} si rien.
## Sur le DESSUS d'une case : le pied est la case vide au-dessus, l'orientation se cherche. Sur une PAROI : le pied est la
## case vide devant elle, et la montée va vers la paroi.
func vise(position: Vector2) -> Dictionary:
	var cam: Camera3D = e._vue.camera()
	var o := cam.project_ray_origin(position)
	var d := cam.project_ray_normal(position)
	var r: Dictionary = Outils.rayon(_plein(), o, d, PORTEE)
	if not r["touche"]:
		return {}
	var n: Vector3i = r["normale"]
	var c: Vector3i = r["case"]
	if n.y > 0:
		return {"bas": c + Vector3i.UP, "vers": -1}
	if n.y < 0:
		return {}
	# Visée haut sur une paroi : le pied descend jusqu'au sol devant elle.
	var bas := c + n
	var plein := _plein()
	for k in 32:
		if plein.call(bas + Vector3i.DOWN):
			break
		bas += Vector3i.DOWN
	return {"bas": bas, "vers": FR.DIRECTIONS.find(-n)}


## La pose que la visée propose : {"pose", "raison"} — orientée de la visée, sinon du premier quart qui passe, sinon
## du quart préféré (rouge, avec la raison de ce quart-là).
func proposer(position: Vector2) -> Dictionary:
	var m: Variant = modele_actif()
	var v := vise(position)
	if m == null or v.is_empty():
		return {}
	var prises := FR.prises_de(_par_id(), poses)
	var q: int = v["vers"]
	if q < 0:
		q = FR.orienter(m, v["bas"], _plein(), prises, quart_prefere)
		if q < 0:
			q = quart_prefere
	var p := FR.pose(-1, int(m["id"]), v["bas"], q)
	return {"pose": p, "raison": FR.verifier(m, p, _plein(), prises)}


func survoler(position: Vector2) -> void:
	if _fantome == null:
		return
	var pr := proposer(position)
	if pr.is_empty():
		_fantome.visible = false
		return
	var m: Dictionary = modele_actif()
	_fantome.mesh = _maillage_de(m)
	_fantome.transform = FR.transformation(m, pr["pose"])
	_mat_fantome.albedo_color = VERT if pr["raison"] == "" else ROUGE
	_fantome.visible = true


func coup(position: Vector2, bouton: int, phase: int) -> void:
	if phase != 0:
		return
	if bouton == MOUSE_BUTTON_RIGHT:
		var v := vise(position)
		if v.is_empty():
			return
		var prises := FR.prises_de(_par_id(), poses)
		var touche: Variant = null
		for c in [v["bas"], (v["bas"] as Vector3i) + Vector3i.DOWN]:
			if prises.has(c):
				touche = prises[c]
				break
		for p in poses:
			if touche != null and p["id"] == touche:
				_valider([], [p], "remove 1")
				return
		return
	if modele_actif() == null:
		e._dire("[i]Make a model first (« New stairs »).[/i]")
		return
	var pr := proposer(position)
	if pr.is_empty():
		e._dire("[color=#e0603c]Crossings[/color] — aim at the ground or at a wall.")
		return
	if pr["raison"] != "":
		e._dire("[color=#e0603c]Not set[/color] — %s." % FR.RAISONS.get(pr["raison"], pr["raison"]))
		return
	var p: Dictionary = pr["pose"]
	p["id"] = _prochain_pose
	_prochain_pose += 1
	quart_prefere = int(p["quart"])
	_valider([p], [], "set 1")


func _valider(ajoutes: Array, effaces: Array, quoi: String) -> void:
	e._histoire.create_action("Crossing: " + quoi)
	e._histoire.add_do_method(_faire.bind(ajoutes, effaces))
	e._histoire.add_undo_method(_defaire.bind(ajoutes, effaces))
	e._histoire.commit_action()
	e._dire("[b]Crossing: %s[/b] [i]Ctrl+Z undoes it.[/i]" % quoi)
	e._enregistrer_plus_tard()


func _faire(ajoutes: Array, effaces: Array) -> void:
	for p in effaces:
		poses.erase(p)
	for p in ajoutes:
		if not poses.has(p):
			poses.append(p)
	_tout_redessiner()
	rafraichir_liste()


func _defaire(ajoutes: Array, effaces: Array) -> void:
	for p in ajoutes:
		poses.erase(p)
	for p in effaces:
		if not poses.has(p):
			poses.append(p)
	_tout_redessiner()
	rafraichir_liste()


# ── LE DESSIN ────────────────────────────────────────────────────────────────────────────────────────

func _maillage_de(m: Dictionary) -> ArrayMesh:
	var id := int(m["id"])
	if not _maillages.has(id):
		var me: RefCounted = ME.depuis_dictionnaire(m["maillage"]) if not (m["maillage"] as Dictionary).is_empty() \
			else FR.maillage_de_depart(m)
		_maillages[id] = me.vers_array_mesh() if me != null else ArrayMesh.new()
	return _maillages[id]


func _tout_redessiner() -> void:
	if _racine == null:
		return
	for c in _racine.get_children():
		if c != _fantome:
			c.queue_free()
	var par_id := _par_id()
	for p in poses:
		var m = par_id.get(int(p["modele"]))
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _maillage_de(m)
		mi.material_override = _mat_pose
		mi.transform = FR.transformation(m, p)
		_racine.add_child(mi)


func _par_id() -> Dictionary:
	var d := {}
	for m in modeles:
		d[int(m["id"])] = m
	return d


func _poses_de(m: Dictionary) -> Array:
	return poses.filter(func(p): return int(p["modele"]) == int(m["id"]))


# ── LE PROJET ────────────────────────────────────────────────────────────────────────────────────────

func vers_donnees() -> Dictionary:
	return FR.vers_donnees(modeles, poses)


## Les franchisseurs d'un projet ouvert (déjà lus et vérifiés par `Projet.depuis_texte`).
func charger(d: Dictionary) -> void:
	modeles = (d.get("modeles", []) as Array).duplicate()
	poses = (d.get("poses", []) as Array).duplicate()
	_prochain_modele = 1
	for m in modeles:
		_prochain_modele = maxi(_prochain_modele, int(m["id"]) + 1)
	_prochain_pose = poses.size() + 1
	actif = 0 if not modeles.is_empty() else -1
	_maillages.clear()
	_tout_redessiner()
	rafraichir_liste()


func vider() -> void:
	modeles = []
	poses = []
	actif = -1
	_prochain_modele = 1
	_prochain_pose = 1
	_maillages.clear()
	_tout_redessiner()
	rafraichir_liste()
