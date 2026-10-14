extends RefCounted
## LES VARIANTES VOULUES, À L'ÉCRAN — DÉCIDÉ (Jordan, 4 octobre 2026 : « des tuiles alternatives pour les parties qui se
## répètent beaucoup, comme le plein de falaise, les runs de corner, les pleins de ground […] simplement avec un mode
## choix en monde et un mode choix aléatoire » ; puis « choisis le mieux »).
##
## Une section et un ATELIER, et rien d'autre dans `editor.gd` que leurs branchements :
##   • WITNESS GEOMETRY — « Variants » : la copie en édition montre la base ou une variante de sa clé ; « New variant
##     from this copy » en fait une (une copie de la tuile, que cette occurrence montre désormais), « Show » change ce
##     qu'elle montre, « Delete this variant ». On la sculpte comme n'importe quelle tuile : ses copies suivent, ses
##     bords sont ceux de sa clé (les sections partagées), et le témoin la montre posée à côté de ses voisines.
##   • L'ATELIER VARIANTS (13 octobre 2026 ; une section de World jusque-là) : l'outil Variant (un clic sur une tuile
##     pose la suivante, le clic droit rend le tirage), la liste des tuiles qui ont des variantes, les POIDS du tirage
##     pour la clé désignée, la sélection (Random / Base / Variant k sur ses sommets), et deux boutons qui mènent à
##     Witness geometry (« Sculpt », « New variant of this tile »). World n'en garde qu'un renvoi.
## La règle est dans le cœur (`MB.tuile_du_sommet`) ; les poids et les choix appartiennent à la COUCHE (le projet), les
## variantes à son TÉMOIN. Chaque geste est UNE annulation.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")
const PlancheTuiles := preload("res://app/planche_tuiles.gd")

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


# ── L'ATELIER VARIANTS ───────────────────────────────────────────────────────────────────────────────
## DEMANDÉ PAR JORDAN (13 octobre 2026 : « les variations ne devraient pas être un atelier à part entière ? »), et la
## répartition proposée puis acceptée : la vue montre le monde peint (comme World, Fluids, Transitions) ; la barre de
## droite RASSEMBLE ce qui était une section de World — l'outil Variant, la liste des tuiles qui ont des variantes, les
## poids, la sélection ; le SCULPT reste dans Witness geometry, et deux boutons y mènent (« Sculpt » une tuile ou une
## variante, « New variant of this tile »). Échap ramène à World ; entrer prend l'outil Variant, sortir rend l'outil de
## World d'avant (la discipline de Fluids et de Transitions).

var _outil_avant := "ajouter"
var _liste: VBoxContainer         # les tuiles qui ont des variantes, une ligne chacune
var _lignes := {}                 # clé → la ligne (Button) de la liste
var _boutons_sculpter: Array = [] # les boutons « Sculpt » de la ligne des poids (base, variante 1…), dans l'ordre
var bouton_nouvelle: Button       # « New variant of this tile »
var _photos := {}                 # tuile → [empreinte du maillage, SubViewport] (refaite si la tuile change)
var _studio: Node                 # où vivent les SubViewport des photos (dans l'arbre, sinon rien n'est rendu)
var _planche: Node                # une planche jamais montrée : elle sait photographier une tuile


func batir_atelier(pile: VBoxContainer) -> void:
	_studio = Node.new()
	_studio.name = "PhotosDesVariantes"
	pile.add_child(_studio)
	var outil := Section.new("Variant tool", true, Icones.icone("variante"))
	pile.add_child(outil)
	bouton_outil = Button.new()
	bouton_outil.text = "Variant tool"
	bouton_outil.icon = Icones.icone("variante")
	bouton_outil.toggle_mode = true
	bouton_outil.focus_mode = Control.FOCUS_NONE
	bouton_outil.custom_minimum_size = Vector2(0, 32)
	bouton_outil.tooltip_text = ("Click a tile of the world: it shows its next variant (base, variant 1, 2…). "
		+ "Right click gives it back to the random draw.")
	bouton_outil.pressed.connect(choisir_l_outil)
	outil.contenu.add_child(bouton_outil)
	outil.contenu.add_child(e._texte("Variants are other sculptures of a tile, with the same borders. The world mixes "
		+ "them at random, by their weights; a tile you click keeps the one you picked. They are sculpted in Witness "
		+ "geometry: « Sculpt » takes you there.", 11, Palette.GRIS))

	var tuiles := Section.new("Tiles with variants", true, Icones.icone("couches"))
	pile.add_child(tuiles)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 4)
	tuiles.contenu.add_child(_liste)

	var poids := Section.new("The tile", true, Icones.icone("cube"))
	pile.add_child(poids)
	etiquette_monde = e._texte("", 11, Palette.GRIS)
	poids.contenu.add_child(etiquette_monde)
	poids.contenu.add_child(e._petit_titre("WEIGHTS  ·  PLACED"))
	ligne_poids = GridContainer.new()
	ligne_poids.columns = 4
	ligne_poids.add_theme_constant_override("h_separation", 6)
	poids.contenu.add_child(ligne_poids)
	bouton_nouvelle = e._bouton("New variant of this tile", "Makes a variant of this tile from its clearest copy in "
		+ "the witness, and takes you to Witness geometry to sculpt it. Its borders stay those of the tile, so it fits "
		+ "wherever the tile fits. One Ctrl+Z.", nouvelle_variante, "plus")
	poids.contenu.add_child(bouton_nouvelle)

	var sel := Section.new("On the selection", true, Icones.icone("selectionner"))
	pile.add_child(sel)
	sel.contenu.add_child(e._texte("The selection made in World (Select, Rect, Box).", 11, Palette.GRIS))
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
	sel.contenu.add_child(ligne)
	sel.contenu.add_child(e._bouton("Back to random everywhere", "Forgets every variant you picked in this layer. "
		+ "Ctrl+Z brings them back.", tout_au_hasard, "gomme"))
	sel.contenu.add_child(e._bouton("Leave", "Back to World (Esc), with the tool you had there.",
		func() -> void: e._changer_d_atelier("monde"), "gauche"))
	# F et ² ont leurs boutons (TOUT RACCOURCI A SON BOUTON, 13 octobre 2026), comme dans Fluids et Transitions.
	sel.contenu.add_child(e._rangee_vue())
	dire_poids()


## World ne garde qu'un renvoi d'une ligne (Jordan, 13 octobre 2026 : les variantes ont leur atelier).
func batir_renvoi(pile: VBoxContainer) -> void:
	var sec := Section.new("Variants", true, Icones.icone("variante"))
	pile.add_child(sec)
	sec.contenu.add_child(e._bouton("Variants workspace", "Mix the variants of your tiles: the Variant tool, the weights "
		+ "of the random draw, the picks on the selection. Esc comes back here.",
		func() -> void: e._changer_d_atelier("variantes"), "variante"))


## En entrant : l'outil devient Variant (celui de World est retenu) ; la liste et la ligne des poids sont redites.
func entrer() -> void:
	if e._vue.outil != "variante":
		_outil_avant = e._vue.outil
	e._vue.oublier_ancre()
	if not e._vue.collage.is_empty():
		e._vue.annuler_collage()
	choisir_l_outil()
	dire_poids()
	e._dire("[b]Variants[/b] — click a tile to show its next variant, right click gives it back to the random draw; "
		+ "the list on the right shows the tiles that have variants. [i]Esc goes back to World.[/i]")


## En sortant : l'outil de World d'avant revient (son bouton enfoncé), et plus aucun clic ne change de variante.
func sortir() -> void:
	if e._vue.outil != "variante":
		return
	e._vue.outil = _outil_avant if _outil_avant != "variante" else "ajouter"
	e._vue.oublier_ancre()
	if e._vue.outil == "forme":
		(e._boutons_forme_speciale[e._vue.forme_speciale["quoi"]] as Button).set_pressed_no_signal(true)
	elif e._boutons_outil.has(e._vue.outil):
		(e._boutons_outil[e._vue.outil] as Button).set_pressed_no_signal(true)
	outil_change()
	e._contexte_des_outils()
	e._vue.rafraichir()


func choisir_l_outil() -> void:
	e._vue.outil = "variante"
	for b in e._boutons_outil.values():
		(b as Button).set_pressed_no_signal(false)
	for b in e._boutons_forme_speciale.values():
		(b as Button).set_pressed_no_signal(false)
	if bouton_outil != null:
		bouton_outil.set_pressed_no_signal(true)
	e._basculer_navigation(false)
	e._contexte_des_outils()
	e._vue.rafraichir()


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


## Combien de sommets de la couche active montrent la tuile `nom` (lu dans la grille `Rendu` : ce qui est POSÉ).
func posees(nom: String, index: Dictionary) -> int:
	var m: Node = _massif()
	if m == null or not index.has(nom):
		return 0
	return (m.get_node("Rendu") as GridMap).get_used_cells_by_item(index[nom]).size()


## Les clés qui ont au moins une variante dans le lot de la couche active, triées.
static func cles_a_variantes(index: Dictionary) -> Array:
	var cles := {}
	for nom in index:
		if MB.rang_de_variante(nom) > 0:
			cles[MB.cle_de_tuile(nom)] = true
	var l: Array = cles.keys()
	l.sort()
	return l


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
		e._dire("[b]%s[/b] has no variant — « New variant of this tile » makes one." % nom_lisible(cle).trim_suffix(" · base"))
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


## Une ligne de la liste choisie : la ligne des poids parle de sa clé.
## ⚠ LA LISTE N'EST PAS REBÂTIE ICI : le clic vient d'une de ses lignes, la libérer sous la souris casserait le geste
## (comme les compteurs des poids). Les lignes changent seulement d'état.
func designer(cle: String) -> void:
	cle_designee = cle
	for c in _lignes:
		(_lignes[c] as Button).set_pressed_no_signal(c == cle)
	_dire_la_ligne()


func appliquer_a_la_selection() -> void:
	var m: Node = _massif()
	if e._vue.selection.is_empty():
		e._dire("[i]Select some cells first (in World: Select, Rect, Box).[/i]")
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
	_redire_les_comptes()


# ── VERS WITNESS GEOMETRY ────────────────────────────────────────────────────────────────────────────

## « Sculpt » : Witness geometry, en édition, sur la copie la plus lisible de `tuile` (la base ou une variante) — la
## vue la cadre, une boîte blanche la montre, et c'est elle qu'on édite. ⚠ PAS UN GESTE : rien ne change au témoin.
func sculpter(tuile: String) -> void:
	var t: RefCounted = e._temoin_de(e._couches[e._active])
	if t.occurrences_de(tuile).is_empty():
		e._dire("[i]No copy of the witness shows %s — in Witness geometry, « This copy shows » makes one show it.[/i]"
			% nom_lisible(tuile))
		return
	await e._changer_d_atelier("witness")
	await e._basculer_edition(true)
	e._aller_a_la_tuile(tuile)
	e._dire(("[b]Sculpt %s[/b] — every copy that shows it follows; its borders are shared with its tile. "
		+ "[i]The Variants workspace takes you back to the world.[/i]") % nom_lisible(tuile))


## « New variant of this tile » : Witness geometry, la copie la plus lisible de la BASE de la clé désignée, et la
## variante naît d'elle — le geste même de « New variant from this copy » (une annulation).
func nouvelle_variante() -> void:
	if cle_designee == "":
		e._dire("[i]Point at a tile with the Variant tool, or pick one in the list.[/i]")
		return
	var cle := cle_designee
	var t: RefCounted = e._temoin_de(e._couches[e._active])
	if t.occurrences_de(cle).is_empty():
		e._dire("[i]No copy of the witness of this layer shows the base of %s.[/i]" % nom_lisible(cle))
		return
	if t.nombre_de_variantes(cle) >= MB.VARIANTES_MAXI:
		e._dire("[i]This tile already has %d variants.[/i]" % MB.VARIANTES_MAXI)
		return
	await e._changer_d_atelier("witness")
	await e._basculer_edition(true)
	e._aller_a_la_tuile(cle)
	creer()


# ── LA LISTE ET LA LIGNE DES POIDS ───────────────────────────────────────────────────────────────────

## LA LIGNE DES POIDS de la clé désignée : par tuile (base, variante 1…) son nom, son poids, combien de ses copies le
## monde pose, et « Sculpt ». La liste est redite avec elle.
func dire_poids() -> void:
	_dire_la_liste()
	_dire_la_ligne()


func _dire_la_ligne() -> void:
	if ligne_poids == null:
		return
	for enfant in ligne_poids.get_children():
		ligne_poids.remove_child(enfant)
		enfant.queue_free()
	_compteurs = []
	_boutons_sculpter = []
	var m: Node = _massif()
	bouton_nouvelle.disabled = m == null or cle_designee == ""
	if m == null or cle_designee == "":
		etiquette_monde.text = "Point at a tile with the Variant tool, or pick one in the list: its weights show here."
		return
	var index := _index()
	var n: int = MB.nombre_de_variantes(cle_designee, index)
	if n == 0:
		etiquette_monde.text = "%s has no variant yet." % nom_lisible(cle_designee).trim_suffix(" · base")
	else:
		etiquette_monde.text = "%s — %d variant(s). The random draw picks each tile in proportion to its weight." % [
			nom_lisible(cle_designee).trim_suffix(" · base"), n]
	var w: Array = (m.poids as Dictionary).get(cle_designee, [])
	for k in n + 1:
		var nom := MB.nom_de_variante(cle_designee, k)
		var nom_ligne: Label = e._texte("Base" if k == 0 else "Variant %d" % k, 11, Palette.TEXTE)
		nom_ligne.autowrap_mode = TextServer.AUTOWRAP_OFF   # « Variant 1 » se coupait en deux (vu à l'image)
		ligne_poids.add_child(nom_ligne)
		var b := SpinBox.new()
		b.min_value = 0
		b.max_value = POIDS_MAXI
		b.step = 1
		b.value = int(w[k]) if k < w.size() else 1
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "0: never drawn. Picked tiles keep their pick."
		b.editable = n > 0
		b.value_changed.connect(regler_poids.bind(cle_designee, k))
		ligne_poids.add_child(b)
		_compteurs.append(b)
		var compte: Label = e._texte("×%d" % posees(nom, index), 11, Palette.GRIS)
		compte.autowrap_mode = TextServer.AUTOWRAP_OFF
		compte.tooltip_text = "How many tiles of the active layer show it."
		ligne_poids.add_child(compte)
		var s: Button = e._bouton("Sculpt", "Sculpt this %s in Witness geometry: the view goes to its clearest copy, in "
			% ("tile's base" if k == 0 else "variant") + "edit mode.", sculpter.bind(nom), "cube")
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		ligne_poids.add_child(s)
		_boutons_sculpter.append(s)


## Les comptes « ×N » changent avec chaque choix : la ligne et la liste sont redites (rien d'autre ne bouge).
func _redire_les_comptes() -> void:
	if ligne_poids == null:
		return
	var index := _index()
	for k in _compteurs.size():
		var compte: Label = ligne_poids.get_child(k * 4 + 2)
		compte.text = "×%d" % posees(MB.nom_de_variante(cle_designee, k), index)
	_dire_la_liste()


## LA LISTE DES TUILES QUI ONT DES VARIANTES (couche active) : une ligne par clé — sa photo, son nom, combien de
## variantes, combien de copies le monde pose (base / variante 1 / …) ; un clic la désigne.
func _dire_la_liste() -> void:
	if _liste == null:
		return
	for enfant in _liste.get_children():
		_liste.remove_child(enfant)
		enfant.queue_free()
	_lignes = {}
	var index := _index()
	var cles := cles_a_variantes(index)
	if cles.is_empty():
		_liste.add_child(e._texte("No tile of this layer has variants yet. Point at a tile with the Variant tool, then "
			+ "« New variant of this tile ».", 11, Palette.GRIS))
		return
	# La photo si le témoin est déjà chargé ; on ne le charge jamais pour elle.
	var t: RefCounted = e._couches[e._active].get("_temoin", null) if e._active < e._couches.size() else null
	for cle in cles:
		var n: int = MB.nombre_de_variantes(cle, index)
		var parts: Array = []
		for k in n + 1:
			parts.append(str(posees(MB.nom_de_variante(cle, k), index)))
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%s\n%d variant(s) · placed %s" % [nom_lisible(cle).trim_suffix(" · base"), n, " / ".join(parts)]
		b.tooltip_text = "Tiles placed in the active layer: base / variant 1 / … Click to see its weights."
		b.button_pressed = cle == cle_designee
		var photo := _photo(t, cle)
		if photo != null:
			b.icon = photo
			b.add_theme_constant_override("icon_max_width", 48)
		b.pressed.connect(designer.bind(cle))
		_liste.add_child(b)
		_lignes[cle] = b


## La photo de la base d'une clé (la planche des tuiles sait la prendre), gardée tant que la tuile ne change pas.
func _photo(t: RefCounted, cle: String) -> Texture2D:
	if t == null or not t.tuiles.has(cle) or _studio == null or not _studio.is_inside_tree():
		return null
	var maillage: RefCounted = t.tuiles[cle]
	var empreinte: int = PlancheTuiles.empreinte_de(maillage)
	var deja: Array = _photos.get(cle, [])
	if not deja.is_empty() and int(deja[0]) == empreinte:
		return (deja[1] as SubViewport).get_texture()
	if not deja.is_empty():
		(deja[1] as Node).queue_free()
	if _planche == null:
		_planche = PlancheTuiles.new()
	var bits := 0
	for c in MB.classes():
		if c["nom"] == MB.nom_nu(cle):
			bits = c["bits"]
	var vue: SubViewport = _planche._photographier(maillage.vers_array_mesh(), bits)
	_studio.add_child(vue)
	_photos[cle] = [empreinte, vue]
	return vue.get_texture()


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
		_redire_les_comptes()


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_PREDELETE and _planche != null:
		_planche.free()
