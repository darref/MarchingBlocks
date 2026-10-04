extends RefCounted
## LES VARIANTES VOULUES, À L'ÉCRAN — DÉCIDÉ (Jordan, 4 octobre 2026 : « des tuiles alternatives pour les parties qui se
## répètent beaucoup, comme le plein de falaise, les runs de corner, les pleins de ground […] simplement avec un mode
## choix en monde et un mode choix aléatoire » ; puis « choisis le mieux »).
##
## Deux sections, et rien d'autre dans `editor.gd` que leurs branchements :
##   • WITNESS GEOMETRY — « Variants » : la copie en édition montre la base ou une variante de sa clé ; « New variant
##     from this copy » en fait une (une copie de la tuile, que cette occurrence montre désormais), « Show » change ce
##     qu'elle montre, « Delete this variant ». On la sculpte comme n'importe quelle tuile : ses copies suivent, ses
##     bords sont ceux de sa clé (les sections partagées), et le témoin la montre posée à côté de ses voisines.
##   • WORLD — « Variants » : l'outil Variant (un clic sur une tuile pose la suivante, le clic droit rend le tirage), les
##     POIDS du tirage pour la clé désignée, et la sélection (Random / Base / Variant k sur ses sommets).
## La règle est dans le cœur (`MB.tuile_du_sommet`) ; les poids et les choix appartiennent à la COUCHE (le projet), les
## variantes à son TÉMOIN. Chaque geste est UNE annulation.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

## Un poids va de 0 (jamais tirée) à POIDS_MAXI.
const POIDS_MAXI := 20

var e: Node   # l'écran (editor.gd)

# World
var bouton_outil: Button
var etiquette_monde: Label
var ligne_poids: GridContainer
var choix_selection: OptionButton
var cle_designee := ""        # la clé dont la ligne des poids parle
var _compteurs: Array = []    # les compteurs de la ligne des poids (base, variante 1…)
# Witness geometry
var etiquette_temoin: Label
var montrer: OptionButton
var bouton_creer: Button
var bouton_supprimer: Button
var _dit_pour := ""           # ce que la section du témoin dit déjà (occurrence|tuile|nombre)


func _init(ecran: Node) -> void:
	e = ecran


## Le nom lisible d'une tuile (« slab b2h2 outdoor · variant 1 »).
static func nom_lisible(tuile: String) -> String:
	var k: int = MB.rang_de_variante(tuile)
	var base: String = FN.id_de_cle(MB.cle_de_tuile(tuile)).replace("_", " ")
	return base + (" · variant %d" % k if k > 0 else " · base")


# ── WITNESS GEOMETRY ─────────────────────────────────────────────────────────────────────────────────

func batir_temoin(pile: VBoxContainer) -> void:
	var sec := Section.new("Variants", true, Icones.icone("variante"))
	pile.add_child(sec)
	sec.contenu.add_child(e._texte("A tile that repeats a lot (a cliff, a ground, a run of corners) can have "
		+ "variants: other sculptures of the same tile, with the SAME borders. World mixes them at random, or "
		+ "where you pick them.", 11, Palette.GRIS))
	etiquette_temoin = e._texte("", 11, Palette.OLIVE)
	sec.contenu.add_child(etiquette_temoin)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	ligne.add_child(e._texte("This copy shows", 11, Palette.TEXTE))
	montrer = OptionButton.new()
	montrer.focus_mode = Control.FOCUS_NONE
	montrer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	montrer.tooltip_text = "Which tile this copy of the witness shows: the base, or one of its variants."
	montrer.item_selected.connect(func(i: int) -> void: affecter(montrer.get_item_id(i)))
	ligne.add_child(montrer)
	sec.contenu.add_child(ligne)
	bouton_creer = e._bouton("New variant from this copy", "Makes a variant of this tile, a copy of what this copy "
		+ "shows, and this copy shows it. Sculpt it: only the copies that show it follow. Its borders stay those of "
		+ "the tile, so it fits wherever the tile fits.", creer, "plus")
	bouton_supprimer = e._bouton("Delete this variant", "Its copies show the base again; the next variants move down "
		+ "one rank. Ctrl+Z brings it back.", supprimer, "poubelle", Palette.DANGER)
	sec.contenu.add_child(e._grille([bouton_creer, bouton_supprimer], 1))


## Relue à chaque image dans Geometry (rien ne change tant que l'occurrence et ses variantes ne changent pas).
func dire_temoin() -> void:
	if etiquette_temoin == null:
		return
	var m: Node3D = e._modeleur
	var t: RefCounted = m.temoin
	var ok: bool = t != null and m.occurrence >= 0 and m.occurrence < t.occurrences.size() and e._vue.edition
	var sig := "-"
	if ok:
		var o: Dictionary = t.occurrences[m.occurrence]
		sig = "%d|%s|%d|%d" % [m.occurrence, o["cle"], t.nombre_de_variantes(o["modele"]), t.occurrences_de(o["cle"]).size()]
	if sig == _dit_pour:
		return
	_dit_pour = sig
	montrer.clear()
	bouton_creer.disabled = not ok
	bouton_supprimer.disabled = true
	montrer.disabled = not ok
	if not ok:
		etiquette_temoin.text = "Edit the witness (Tab) and click a copy."
		return
	var o: Dictionary = t.occurrences[m.occurrence]
	var modele: String = o["modele"]
	var n: int = t.nombre_de_variantes(modele)
	var k: int = MB.rang_de_variante(o["cle"])
	etiquette_temoin.text = "%s — %d variant(s); %d cop%s show this one." % [nom_lisible(o["cle"]), n,
		t.occurrences_de(o["cle"]).size(), "y" if t.occurrences_de(o["cle"]).size() == 1 else "ies"]
	montrer.add_item("Base", 0)
	for j in range(1, n + 1):
		montrer.add_item("Variant %d" % j, j)
	montrer.select(k)
	bouton_creer.disabled = n >= MB.VARIANTES_MAXI
	bouton_supprimer.disabled = k == 0


func creer() -> void:
	_geste_temoin("New variant", func(t: RefCounted, i: int) -> String:
		var nom: String = t.creer_variante(i)
		return "" if nom != "" else "This tile already has %d variants." % MB.VARIANTES_MAXI)


func affecter(k: int) -> void:
	_geste_temoin("Show variant %d" % k if k > 0 else "Show the base", func(t: RefCounted, i: int) -> String:
		return "" if t.affecter(i, k) else "No such variant.")


func supprimer() -> void:
	_geste_temoin("Delete variant", func(t: RefCounted, i: int) -> String:
		return "" if t.supprimer_variante(t.occurrences[i]["cle"]) else "This copy shows the base: nothing to delete.")


## UN GESTE SUR LES VARIANTES DU TÉMOIN : l'état d'avant et d'après (`etat_des_variantes`), UNE annulation, le témoin
## redessiné sur la même occurrence, et marqué modifié (il s'écrit, et le monde le suit en passant dans World).
func _geste_temoin(nom: String, action: Callable) -> void:
	var m: Node3D = e._modeleur
	var t: RefCounted = m.temoin
	if t == null or m.occurrence < 0:
		e._dire("[i]Edit the witness (Tab) and click a copy first.[/i]")
		return
	if m.modal != "":
		m.annuler()
	var i: int = m.occurrence
	var avant: Dictionary = t.etat_des_variantes()
	var refus: String = action.call(t, i)
	if refus != "":
		e._dire("[i]%s[/i]" % refus)
		_dit_pour = ""
		return
	var apres: Dictionary = t.etat_des_variantes()
	e._histoire.create_action("Witness: " + nom)
	e._histoire.add_do_method(_poser_temoin.bind(t, apres, i))
	e._histoire.add_undo_method(_poser_temoin.bind(t, avant, i))
	e._histoire.commit_action(false)
	_recharger(t, i)
	e._dire("[b]%s[/b] — this copy shows %s." % [nom, nom_lisible(t.occurrences[i]["cle"])])


func _poser_temoin(t: RefCounted, etat: Dictionary, i: int) -> void:
	t.poser_etat_des_variantes(etat)
	_recharger(t, i)


func _recharger(t: RefCounted, i: int) -> void:
	var m: Node3D = e._modeleur
	if m.temoin == t:
		m.charger_temoin(t, i)
	e._temoin_modifie(t)
	_dit_pour = ""


# ── WORLD ────────────────────────────────────────────────────────────────────────────────────────────

func batir_monde(pile: VBoxContainer) -> void:
	var sec := Section.new("Variants", true, Icones.icone("variante"))
	pile.add_child(sec)
	bouton_outil = Button.new()
	bouton_outil.text = "Variant tool"
	bouton_outil.icon = Icones.icone("variante")
	bouton_outil.toggle_mode = true
	bouton_outil.focus_mode = Control.FOCUS_NONE
	bouton_outil.custom_minimum_size = Vector2(0, 32)
	bouton_outil.tooltip_text = ("Click a tile of the world: it shows its next variant (base, variant 1, 2…). "
		+ "Right click gives it back to the random draw.\nVariants are made in Witness geometry.")
	bouton_outil.pressed.connect(choisir_l_outil)
	sec.contenu.add_child(bouton_outil)
	etiquette_monde = e._texte("Variants of a tile are mixed at random, by the weights below; a tile you click "
		+ "keeps the one you picked.", 11, Palette.GRIS)
	sec.contenu.add_child(etiquette_monde)
	sec.contenu.add_child(e._petit_titre("RANDOM DRAW  ·  WEIGHTS"))
	ligne_poids = GridContainer.new()
	ligne_poids.columns = 2
	ligne_poids.add_theme_constant_override("h_separation", 8)
	sec.contenu.add_child(ligne_poids)
	sec.contenu.add_child(e._petit_titre("ON THE SELECTION"))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	choix_selection = OptionButton.new()
	choix_selection.focus_mode = Control.FOCUS_NONE
	choix_selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choix_selection.add_item("Random", -1)
	choix_selection.add_item("Base", 0)
	for k in range(1, MB.VARIANTES_MAXI + 1):
		choix_selection.add_item("Variant %d" % k, k)
	ligne.add_child(choix_selection)
	ligne.add_child(e._bouton("Apply", "Every tile touching the selected cells shows this (when its tile has that "
		+ "variant). Random gives them back to the draw. One Ctrl+Z.", appliquer_a_la_selection))
	sec.contenu.add_child(ligne)
	sec.contenu.add_child(e._bouton("Back to random everywhere", "Forgets every variant you picked in this layer. "
		+ "Ctrl+Z brings them back.", tout_au_hasard, "gomme"))
	dire_poids()


func choisir_l_outil() -> void:
	e._vue.outil = "variante"
	for b in e._boutons_outil.values():
		(b as Button).set_pressed_no_signal(false)
	for b in e._boutons_forme_speciale.values():
		(b as Button).set_pressed_no_signal(false)
	bouton_outil.set_pressed_no_signal(true)
	e._basculer_navigation(false)
	e._contexte_des_outils()
	e._vue.rafraichir()
	e._dire("[b]Variant tool[/b] — click a tile to show its next variant; right click gives it back to the "
		+ "random draw.")


## L'outil courant n'est plus Variant (un autre a été choisi) : le bouton se relâche.
func outil_change() -> void:
	if bouton_outil != null:
		bouton_outil.set_pressed_no_signal(e._vue.outil == "variante")


func _massif() -> Node:
	return e._vue.couche(e._active)


func _index() -> Dictionary:
	var m: Node = _massif()
	var lot: MeshLibrary = m.get_node("Rendu").mesh_library if m != null else null
	var index := {}
	if lot != null:
		for id in lot.get_item_list():
			index[lot.get_item_name(id)] = id
	return index


## UN CLIC DE L'OUTIL : gauche, la variante suivante (base → 1 → … → base) ; droit, le tirage.
func cliquer(info: Dictionary, bouton: int) -> void:
	if info.is_empty():
		e._dire("[i]Point at a tile of the active layer.[/i]")
		return
	var m: Node = _massif()
	var s: Vector3i = info["sommet"]
	var cle: String = m.cle_posee(s)
	if cle == "":
		e._dire("[i]No tile there in the active layer.[/i]")
		return
	cle_designee = cle
	dire_poids()
	var n: int = MB.nombre_de_variantes(cle, _index())
	if n == 0:
		e._dire("[b]%s[/b] has no variant — make one in Witness geometry (Variants)." % nom_lisible(cle).trim_suffix(" · base"))
		return
	var avant: Dictionary = (m.choix as Dictionary).duplicate()
	var apres: Dictionary = avant.duplicate()
	var dit := ""
	if bouton == MOUSE_BUTTON_RIGHT:
		if not apres.has(s):
			e._dire("[i]This tile already follows the random draw.[/i]")
			return
		apres.erase(s)
		dit = "back to the random draw"
	else:
		var k: int = MB.rang_de_variante(m.tuile_posee(s))
		apres[s] = (k + 1) % (n + 1)
		dit = "now " + nom_lisible(MB.nom_de_variante(cle, int(apres[s])))
	_geste_choix("Variant", m, avant, apres, [s])
	e._dire("[b]Variant[/b] — %s: %s. Right click gives it back to the draw." % [nom_lisible(cle).trim_suffix(" · base"), dit])


## La tuile survolée (outil Variant) : la ligne des poids parle de sa clé.
func survoler(info: Dictionary) -> void:
	if e._vue.outil != "variante" or info.is_empty():
		return
	var cle: String = _massif().cle_posee(info["sommet"])
	if cle != "" and cle != cle_designee:
		cle_designee = cle
		dire_poids()


func appliquer_a_la_selection() -> void:
	var m: Node = _massif()
	if e._vue.selection.is_empty():
		e._dire("[i]Select some cells first.[/i]")
		return
	var k: int = choix_selection.get_selected_id()
	var index := _index()
	var sommets := {}
	for c in e._vue.selection:
		for s in MB.sommets_de(c):
			sommets[s] = true
	var avant: Dictionary = (m.choix as Dictionary).duplicate()
	var apres: Dictionary = avant.duplicate()
	var touches := 0
	for s in sommets:
		var cle: String = m.cle_posee(s)
		if cle == "":
			continue
		var n: int = MB.nombre_de_variantes(cle, index)
		if k < 0:
			if apres.has(s):
				apres.erase(s)
				touches += 1
		elif n > 0 and k <= n:
			apres[s] = k
			touches += 1
	if touches == 0:
		e._dire("[i]No tile of the selection has %s.[/i]" % ("a variant picked" if k < 0 else
			("variants" if k == 0 else "a variant %d" % k)))
		return
	_geste_choix("Variants on the selection", m, avant, apres, sommets.keys())
	e._dire("[b]Variants[/b] — %d tile(s) of the selection: %s." % [touches, choix_selection.get_item_text(
		choix_selection.selected)])


func tout_au_hasard() -> void:
	var m: Node = _massif()
	if (m.choix as Dictionary).is_empty():
		e._dire("[i]No variant is picked in this layer.[/i]")
		return
	var avant: Dictionary = (m.choix as Dictionary).duplicate()
	_geste_choix("Variants: back to random", m, avant, {}, avant.keys())


## UN GESTE SUR LES CHOIX d'une couche : une annulation ; seuls les sommets touchés sont refaits.
func _geste_choix(nom: String, m: Node, avant: Dictionary, apres: Dictionary, sommets: Array) -> void:
	e._histoire.create_action(nom)
	e._histoire.add_do_method(_poser_choix.bind(m, apres, sommets))
	e._histoire.add_undo_method(_poser_choix.bind(m, avant, sommets))
	e._histoire.commit_action()


func _poser_choix(m: Node, choix: Dictionary, sommets: Array) -> void:
	m.choix = choix.duplicate()
	m.reconstruire_sommets(sommets)
	e._enregistrer_plus_tard()


## LA LIGNE DES POIDS de la clé désignée : un compteur par tuile (base, variante 1…).
func dire_poids() -> void:
	if ligne_poids == null:
		return
	for enfant in ligne_poids.get_children():
		enfant.queue_free()
	_compteurs = []
	var m: Node = _massif()
	if m == null or cle_designee == "":
		etiquette_monde.text = ("Point at a tile with the Variant tool: its weights show here.")
		return
	var n: int = MB.nombre_de_variantes(cle_designee, _index())
	if n == 0:
		etiquette_monde.text = "%s has no variant — make one in Witness geometry." % nom_lisible(cle_designee).trim_suffix(" · base")
		return
	etiquette_monde.text = "%s — %d variant(s). The random draw picks each tile in proportion to its weight." % [
		nom_lisible(cle_designee).trim_suffix(" · base"), n]
	var w: Array = (m.poids as Dictionary).get(cle_designee, [])
	for k in n + 1:
		ligne_poids.add_child(e._texte("Base" if k == 0 else "Variant %d" % k, 11, Palette.TEXTE))
		var b := SpinBox.new()
		b.min_value = 0
		b.max_value = POIDS_MAXI
		b.step = 1
		b.value = int(w[k]) if k < w.size() else 1
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "0: never drawn. Picked tiles keep their pick."
		b.value_changed.connect(regler_poids.bind(cle_designee, k))
		ligne_poids.add_child(b)
		_compteurs.append(b)


func regler_poids(v: float, cle: String, k: int) -> void:
	var m: Node = _massif()
	var avant: Dictionary = (m.poids as Dictionary).duplicate(true)
	var apres: Dictionary = avant.duplicate(true)
	var n: int = MB.nombre_de_variantes(cle, _index())
	var w: Array = (apres.get(cle, []) as Array).duplicate()
	while w.size() < n + 1:
		w.append(1)
	if int(w[k]) == int(v):
		return
	w[k] = int(v)
	apres[cle] = w
	e._histoire.create_action("Variant weights")
	e._histoire.add_do_method(_poser_poids.bind(m, apres))
	e._histoire.add_undo_method(_poser_poids.bind(m, avant))
	e._histoire.commit_action()


## ⚠ LES COMPTEURS NE SONT PAS REBÂTIS ICI : l'action s'exécute PENDANT le `value_changed` du compteur qu'on tient
## (`commit_action`) ; le libérer sous la souris casserait le geste. Leurs valeurs sont reposées sans signal.
func _poser_poids(m: Node, poids: Dictionary) -> void:
	m.poids = poids.duplicate(true)
	m.reconstruire()
	e._enregistrer_plus_tard()
	if m == _massif() and cle_designee != "":
		var w: Array = poids.get(cle_designee, [])
		for k in _compteurs.size():
			(_compteurs[k] as SpinBox).set_value_no_signal(int(w[k]) if k < w.size() else 1)
