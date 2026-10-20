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
## ⚠ PAS ENCORE DANS LE `.mbworld` NI DANS LES GREFFONS (l'étape 4 de la charte).
## « EDIT SHAPE » (l'étape 2 bis) : le MODELEUR du témoin, sur le maillage du modèle SEUL (`temoin = null` : le chemin du
## maillage libre du modeleur), les copies du témoin cachées — EN PLACE (Jordan, 20 octobre 2026 : « on fait éditer dans
## un contexte de tuiles ? » — « oui ») : dans le MONDE, à la pose du franchisseur visé (ou la première du modèle),
## entouré de ses vraies tuiles ; sans pose, seul dans la vue du témoin. Chaque geste revient ici (`geste`, par `editor.gd`) et
## devient une action annulable du MODÈLE ; « Done » (ou Tab, Échap) rend le monde. Le modèle est alors « sculpté » :
## changer ses dimensions rebâtirait la forme de départ (on le dit, Ctrl+Z la rend).

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
var bouton_forme: Button
var choix_couche: OptionButton
var aide_forme: Label
## Vrai pendant « Edit shape » : le modeleur porte le maillage du modèle `e._franchisseur_edite`.
var edition := false
## La pose qu'on sculpte en place (null : le modèle seul, dans la vue du témoin).
var _pose_editee: Variant = null
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
	var ligne_couche := HBoxContainer.new()
	var lc: Label = e._texte("Material", 11, Palette.GRIS)
	lc.custom_minimum_size = Vector2(84, 0)
	ligne_couche.add_child(lc)
	choix_couche = OptionButton.new()
	choix_couche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choix_couche.focus_mode = Control.FOCUS_NONE
	choix_couche.tooltip_text = "The layer whose ground material it takes (in the exported world). Auto: the ground under its foot."
	choix_couche.item_selected.connect(_couche_choisie)
	ligne_couche.add_child(choix_couche)
	reglage_modele.add_child(ligne_couche)
	bouton_forme = e._bouton("Edit shape", "Sculpt this model in the modeler (the witness tools: 1 2 3, G R S E I, Ctrl+R, "
		+ "sculpt…). Done, Tab or Esc brings the world back.", basculer_forme, "visee_sculpt")
	reglage_modele.add_child(bouton_forme)
	aide_forme = e._texte("", 11, Palette.OLIVE)
	reglage_modele.add_child(aide_forme)
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
	m["maillage"] = FR.maillage_de_depart(m, e._retrait).vers_dictionnaire()
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
		(" [color=#e0603c]%d crossing(s) no longer fit where they are.[/color]" % refusees) if refusees > 0 else ""])
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
	if choix_couche != null:
		choix_couche.clear()
		choix_couche.add_item("Auto (the ground under it)")
		var k := 0
		for i in e._couches.size():
			choix_couche.add_item(str(e._couches[i]["nom"]))
			if str(e._couches[i]["nom"]) == str(m.get("couche", "")):
				k = i + 1
		choix_couche.select(k)
	if bouton_forme != null:
		bouton_forme.text = "Done editing" if edition else "Edit shape"
		aide_forme.text = ("Sculpting « %s » — the world comes back with Done, Tab or Esc." % m["nom"]) if edition \
			else ("Sculpted." if bool(m.get("sculpte", false)) else "The start shape: « Edit shape » to sculpt it.")
	_remplit = false


func _couche_choisie(i: int) -> void:
	if _remplit:
		return
	var m: Variant = modele_actif()
	if m == null:
		return
	m["couche"] = "" if i <= 0 else str(e._couches[i - 1]["nom"])
	e._enregistrer_plus_tard()


## LA MATIÈRE DE CHAQUE MODÈLE pour l'export : {id: le matériau de sol de sa couche}. La couche choisie, sinon celle du
## sol sous le pied de sa première pose ; son matériau « …_ground » (celui que le témoin met au sol), sinon le premier.
func materiaux_pour_l_export() -> Dictionary:
	var sortie := {}
	for m in modeles:
		var nom := str(m.get("couche", ""))
		if nom == "":
			for p in poses:
				if int(p["modele"]) == int(m["id"]):
					nom = _couche_sous((p["bas"] as Vector3i) + Vector3i.DOWN)
					break
		for i in e._couches.size():
			if str(e._couches[i]["nom"]) != nom:
				continue
			var t: RefCounted = e._temoin_de(e._couches[i])
			if t == null or t.materiaux.is_empty():
				break
			var k := 0
			for j in t.materiaux.size():
				if str(t.materiaux[j].get("nom", "")).ends_with("_ground"):
					k = j
					break
			sortie[int(m["id"])] = (t.materiaux[k] as Dictionary).duplicate(true)
	return sortie


## Le nom de la couche qui porte cette case, "" si aucune.
func _couche_sous(c: Vector3i) -> String:
	for i in e._couches.size():
		var g := e._vue.couche(i).get_node("Cases") as GridMap
		if g.get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
			return str(e._couches[i]["nom"])
	return ""


func activer(i: int) -> void:
	actif = i
	rafraichir_liste()


func modele_actif() -> Variant:
	return modeles[actif] if actif >= 0 and actif < modeles.size() else null


func nouveau_modele(genre: String) -> void:
	var m := FR.modele(_prochain_modele, NOMS_DES_GENRES[genre], genre, 1, 1, 2 if genre == "pente" else 1)
	_prochain_modele += 1
	m["maillage"] = FR.maillage_de_depart(m, e._retrait).vers_dictionnaire()
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
			m["maillage"] = FR.maillage_de_depart(m, e._retrait).vers_dictionnaire()
			modeles.append(m)
	if actif < 0 and not modeles.is_empty():
		actif = 0
	rafraichir_liste()
	e._vue.rafraichir()
	e._dire("[b]Crossings[/b] — aim at the foot of a wall: green, the stairs fit; click to set them. Right click removes. "
		+ "[i]Esc to go back to World.[/i]")


func sortir() -> void:
	if edition:
		finir_edition()
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


# ── EDIT SHAPE : LE MODELEUR SUR LE MODÈLE ───────────────────────────────────────────────────────────

func basculer_forme() -> void:
	if edition:
		finir_edition()
	else:
		editer_forme()


func editer_forme() -> void:
	var m: Variant = modele_actif()
	if m == null:
		return
	var me: RefCounted = ME.depuis_dictionnaire(m["maillage"]) if not (m["maillage"] as Dictionary).is_empty() else null
	if me == null:
		me = FR.maillage_de_depart(m, e._retrait)
	edition = true
	e._franchisseur_edite = m
	if _fantome != null:
		_fantome.visible = false
	_pose_editee = null
	for p in poses:
		if int(p["modele"]) == int(m["id"]):
			_pose_editee = p
			break
	var mo: Node = e._modeleur
	mo.temoin = null
	mo.occurrence = -1
	mo._occurrences.visible = false
	var centre_local := Vector3(float(m["largeur"]) / 2.0, float(m["hauteur"]) / 2.0, -float(m["longueur"]) / 2.0)
	if _pose_editee != null:
		# EN PLACE : le modeleur à la pose, dans le monde ; la copie posée là se cache le temps de la sculpture.
		mo.pose = FR.transformation(m, _pose_editee)
		mo._edition.transform = mo.pose   # ⚠ le modeleur ne le fait qu'en activant une copie de témoin
		mo.charger(me)
		e._vue.edition_dans_le_monde = true
		e._vue.edition = true
		e._vue.montrer("monde")
		e._vue.cadrer(mo.pose * centre_local)
		_tout_redessiner()
	else:
		mo.pose = Transform3D.IDENTITY
		mo._edition.transform = mo.pose
		mo.charger(me)
		e._vue.montrer("temoin")
		e._vue.regler_edition(true)
		e._vue.cadrer(centre_local)
	_remplir_reglages()
	e._dire("[b]Edit shape — « %s »[/b] — the witness tools on this model alone: 1 2 3 pick vertices, edges or faces; "
		% m["nom"] + "G R S E I, Ctrl+R, X M F as in Blender; sculpt with the brushes. Ctrl+Z undoes. "
		+ "[i]Done, Tab or Esc brings the world back.[/i]")


## Un geste du modeleur pendant « Edit shape » (`editor._geste_du_modeleur`) : une action du MODÈLE, déjà faite.
func geste(avant: RefCounted, apres: RefCounted, nom: String) -> void:
	var m: Variant = e._franchisseur_edite
	if m == null:
		return
	var id := int(m["id"])
	var d_avant: Dictionary = avant.vers_dictionnaire() if avant != null and avant.has_method("vers_dictionnaire") \
		else (m["maillage"] as Dictionary).duplicate(true)
	var d_apres: Dictionary = apres.vers_dictionnaire() if apres != null and apres.has_method("vers_dictionnaire") \
		else e._modeleur.maillage.vers_dictionnaire()
	var sculpte_avant := bool(m.get("sculpte", false))
	e._histoire.create_action("Crossing shape: " + nom)
	e._histoire.add_do_method(_poser_forme.bind(id, d_apres, true))
	e._histoire.add_undo_method(_poser_forme.bind(id, d_avant, sculpte_avant))
	e._histoire.commit_action(false)
	_poser_forme(id, d_apres, true, false)


func _poser_forme(id: int, d: Dictionary, sculpte: bool, dans_le_modeleur := true) -> void:
	for m in modeles:
		if int(m["id"]) != id:
			continue
		m["maillage"] = d.duplicate(true)
		m["sculpte"] = sculpte
		_maillages.erase(id)
		if dans_le_modeleur and edition and e._franchisseur_edite == m:
			e._modeleur.remplacer(ME.depuis_dictionnaire(d))
	_tout_redessiner()
	e._enregistrer_plus_tard()


func finir_edition() -> void:
	if not edition:
		return
	var m: Variant = e._franchisseur_edite
	if m != null and e._modeleur.maillage != null:
		m["maillage"] = e._modeleur.maillage.vers_dictionnaire()
		_maillages.erase(int(m["id"]))
	edition = false
	e._franchisseur_edite = null
	_pose_editee = null
	e._modeleur._occurrences.visible = true
	e._modeleur.pose = Transform3D.IDENTITY
	e._modeleur._edition.transform = Transform3D.IDENTITY
	e._vue.edition_dans_le_monde = false
	e._vue.regler_edition(false)
	e._vue.montrer("monde")
	_tout_redessiner()
	rafraichir_liste()
	e._enregistrer_plus_tard()
	e._dire("[b]Crossings[/b] — the shape is kept. Aim at the foot of a wall to set it.")


# ── LE DESSIN ────────────────────────────────────────────────────────────────────────────────────────

func _maillage_de(m: Dictionary) -> ArrayMesh:
	var id := int(m["id"])
	if not _maillages.has(id):
		var me: RefCounted = ME.depuis_dictionnaire(m["maillage"]) if not (m["maillage"] as Dictionary).is_empty() \
			else FR.maillage_de_depart(m, e._retrait)
		_maillages[id] = me.vers_array_mesh() if me != null else ArrayMesh.new()
	return _maillages[id]


func _tout_redessiner() -> void:
	if _racine == null:
		return
	for c in _racine.get_children():
		if c != _fantome:
			c.queue_free()
	var par_id := _par_id()
	var materiaux := _materiaux_des_poses()
	for p in poses:
		var m = par_id.get(int(p["modele"]))
		if m == null or p == _pose_editee:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _maillage_de(m)
		mi.material_override = materiaux.get(int(m["id"]), _mat_pose)
		mi.transform = FR.transformation(m, p)
		_racine.add_child(mi)


## LA MATIÈRE DES POSES DANS LA VUE — DEMANDÉ (Jordan, 20 octobre 2026, relayé par le trailer ultime : « les franchisseurs
## beiges unis dans l'appli ») : chaque modèle dessiné avec le matériau de sol de sa couche, celui que l'export lui donne
## (`materiaux_pour_l_export`), en TRIPLANAIRE en coordonnées du monde comme le greffon Godot (`mb_crossings_node.gd`) et
## les tuiles de l'appli (`MassifPeint.triplanaire`) : une répétition par `echelle` cases. Sans couche ni témoin, le beige
## d'avant. {id du modèle: matériau}.
func _materiaux_des_poses() -> Dictionary:
	var sortie := {}
	var d_par_id := materiaux_pour_l_export()
	for id in d_par_id:
		var d: Dictionary = d_par_id[id]
		if str(d.get("texture", "")) == "" and not d.has("couleur"):
			continue
		var me: RefCounted = ME.new()
		me.materiaux = [d]
		var sm := (me.materiau_godot(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = true
		sm.uv1_triplanar_sharpness = 4.0
		sm.uv1_scale = Vector3.ONE / maxf(0.01, float(d.get("echelle", 1.0)))
		sortie[int(id)] = sm
	return sortie


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
