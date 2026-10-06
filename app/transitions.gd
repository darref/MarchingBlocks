extends RefCounted
## L'ATELIER TRANSITIONS, À L'ÉCRAN — DÉCIDÉ (Jordan, 6 octobre 2026 : « go pour l'atelier transitions »).
##
## La règle et le rendu sont dans le cœur (`transitions.gd`) ; ici, l'état (dans le projet), la barre de droite et le
## pinceau, et rien d'autre dans `editor.gd` que leurs branchements :
##   • PAIRS — chaque paire de couches, une case pour l'allumer (rien n'est dessiné tant qu'aucune n'est allumée) ;
##   • la paire choisie — qui couvre par défaut (la plus haute de la liste), et les DEUX réglages : quand A couvre B,
##     quand B couvre A ;
##   • REPRESENTATIVE MATERIALS — par couche, le matériau de son témoin qui se mêle à la surface de l'autre ;
##   • BRUSH — dans la vue : « A couvre » / « B couvre » au clic gauche, la priorité rendue au clic droit.
## Chaque geste est UNE annulation.

const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const Rendu := preload("res://addons/marchingblocks_core/transitions_rendu.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const Peinture := preload("res://addons/marchingblocks_core/peinture.gd")
const Palette := preload("res://app/palette.gd")
const Icones := preload("res://app/icones.gd")
const Section := preload("res://app/section.gd")

const NOMS_REGLAGES := {"largeur": ["Softness", 0.05], "avance": ["Reach", 0.05], "bruit": ["Irregularity", 0.05],
	"grain": ["Grain", 0.25], "creux": ["Fills hollows", 0.05]}
const AIDES_REGLAGES := {
	"largeur": "How soft the edge is: low, a sharp line; high, a long blend.",
	"avance": "How far the covering layer spreads past the middle of the border (negative: it holds back).",
	"bruit": "How irregular the edge is.",
	"grain": "The size of that irregularity (higher: finer).",
	"creux": "The covering layer fills the HOLLOWS of the other first — the dark parts of its material: sand in the "
		+ "cracks of a rock.",
}
## Le rayon du pinceau, en cases.
const RAYON_MAXI := 6

var e: Node   # l'écran (editor.gd)
var etat: Dictionary = {"paires": {}, "representants": {}, "choix": {}}
var rendu: RefCounted = Rendu.new()

var paire_choisie := ""          # « idA|idB »
var couvrant_peint := ""         # l'id de la couche que le pinceau fait couvrir ("" : la priorité)
var rayon := 1

var _liste: VBoxContainer
var _editeur: VBoxContainer
var _materiaux: VBoxContainer
var _pinceau: OptionButton
var curseur_rayon: HSlider
var _signature := ""
var _a_poser_table := true
var _a_poser_representants := true
var _branches := {}              # matériau → true : ceux qui portent notre passage
var _branchement_vu := 0
var _trait := {}                 # le trait en cours : {avant: choix d'avant}
var _instantane := {}            # les paires avant qu'un curseur bouge


func _init(ecran: Node) -> void:
	e = ecran


# ── L'ÉTAT ───────────────────────────────────────────────────────────────────────────────────────────

func vider() -> void:
	etat = {"paires": {}, "representants": {}, "choix": {}}
	paire_choisie = ""
	couvrant_peint = ""
	_tout_refaire()


func poser_etat(t: Dictionary) -> void:
	etat = t.duplicate(true) if not t.is_empty() else {"paires": {}, "representants": {}, "choix": {}}
	_tout_refaire()


func _tout_refaire() -> void:
	rendu.donnees = {}
	_a_poser_table = true
	_a_poser_representants = true
	_signature = ""


## {id: rang} des couches de l'écran.
func rangs() -> Dictionary:
	var sortie := {}
	for i in e._couches.size():
		sortie[str(e._couches[i].get("id", ""))] = i
	return sortie


func _paire(cle: String) -> Dictionary:
	if not etat["paires"].has(cle):
		var ids := cle.split("|")
		etat["paires"][cle] = TR.paire_neuve(ids[0], ids[1])
	return etat["paires"][cle]


## Une paire allumée dont les deux couches existent : sinon rien n'est dessiné, et le passage est retiré.
func actif() -> bool:
	return not TR.table(etat["paires"], rangs()).is_empty()


func _nom(id: String) -> String:
	for c in e._couches:
		if str(c.get("id", "")) == id:
			return str(c["nom"])
	return "?"


# ── LE RENDU QUI SUIT LE MONDE ──────────────────────────────────────────────────────────────────────

## Des cases ont changé (`_suivre_les_cases`) : leurs rangs dans la texture.
func cases_changees(cases_: Array) -> void:
	if rendu.a_reconstruire():
		return
	for c in cases_:
		if not rendu.case(c, int(e._union.get(c, -1))):
			return


## L'union a été refaite (une couche cachée, montrée, déplacée, supprimée) : les rangs ont pu changer.
func union_refaite() -> void:
	_tout_refaire()


func _choix_en_rangs() -> Dictionary:
	var r := rangs()
	var sortie := {}
	for s in etat["choix"]:
		var id := str(etat["choix"][s])
		if r.has(id):
			sortie[s] = r[id]
	return sortie


## Une fois par image (`editor._process`) : la texture envoyée, la table et les représentants à jour, le passage posé
## sur les matériaux des tuiles — ou retiré quand plus rien n'est allumé.
func suivre() -> void:
	if not actif():
		if not _branches.is_empty():
			_debrancher()
		return
	if rendu.a_reconstruire():
		rendu.reconstruire(e._union, _choix_en_rangs())
	if _a_poser_table:
		rendu.poser_table(TR.table(etat["paires"], rangs()))
		_a_poser_table = false
	if _a_poser_representants:
		rendu.poser_representants(_representants())
		_a_poser_representants = false
	rendu.envoyer()
	rendu.materiau.set_shader_parameter("montrer_choix", e._atelier == "transitions")
	if Time.get_ticks_msec() - _branchement_vu >= 500:
		_brancher()


## LE PASSAGE SUR CHAQUE MATÉRIAU DES TUILES POSÉES (relu deux fois par seconde : un lot change par bien des routes —
## tranchage, monde qui suit son témoin, ouverture). Un matériau qui a déjà son propre `next_pass` est laissé.
func _brancher() -> void:
	_branchement_vu = Time.get_ticks_msec()
	for i in e._vue.nombre_de_couches():
		var lot: MeshLibrary = (e._vue.couche(i).get_node("Rendu") as GridMap).mesh_library
		if lot == null:
			continue
		for id in lot.get_item_list():
			var m: Mesh = lot.get_item_mesh(id)
			if m == null:
				continue
			for s in m.get_surface_count():
				var mat: Material = m.surface_get_material(s)
				if mat == null or _branches.has(mat):
					continue
				if mat.next_pass == null:
					mat.next_pass = rendu.materiau
					_branches[mat] = true


func _debrancher() -> void:
	for mat in _branches:
		if is_instance_valid(mat) and (mat as Material).next_pass == rendu.materiau:
			(mat as Material).next_pass = null
	_branches = {}


func materiaux_branches() -> int:
	return _branches.size()


## Les représentants, par rang : l'image (et la couleur, la répétition, la rugosité) du matériau choisi pour chaque
## couche ; la teinte du dessus de la légende pour une couche sans matériau.
func _representants() -> Array:
	var sortie: Array = []
	for c in e._couches:
		sortie.append(_representant(c))
	return sortie


func _representant(c: Dictionary) -> Dictionary:
	var mats := materiaux_de(c)
	var k := indice_representant(c)
	if k < 0 or k >= mats.size():
		return {"image": null, "couleur": RP.COULEUR_DESSUS, "echelle": 1.0, "rugosite": 0.9}
	var d: Dictionary = mats[k]
	var img: Image = null
	var chemin := str(d.get("texture", ""))
	if chemin != "":
		var tex: Texture2D = Peinture.texture_de(chemin)
		img = tex.get_image() if tex != null else null
	return {"image": img, "couleur": d.get("couleur", Color.WHITE), "echelle": float(d.get("echelle", 1.0)),
		"rugosite": float(d.get("rugosite", 0.8))}


## Les matériaux du témoin d'une couche (le témoin est chargé s'il ne l'est pas).
func materiaux_de(c: Dictionary) -> Array:
	var t: RefCounted = e._temoin_de(c)
	return t.materiaux if t != null else []


## Le matériau représentant d'une couche : celui qu'on a choisi, sinon le plus porté par les faces de son témoin, sinon
## la légende (−1).
func indice_representant(c: Dictionary) -> int:
	var id := str(c.get("id", ""))
	if etat["representants"].has(id):
		return int(etat["representants"][id])
	var t: RefCounted = e._temoin_de(c)
	if t == null or t.materiaux.is_empty():
		return -1
	var comptes := {}
	for nom in t.tuiles:
		for k in t.tuiles[nom].mats:
			if int(k) >= 0:
				comptes[int(k)] = int(comptes.get(int(k), 0)) + 1
	var meilleur := -1
	for k in comptes:
		if meilleur < 0 or comptes[k] > comptes[meilleur] or (comptes[k] == comptes[meilleur] and k < meilleur):
			meilleur = k
	return meilleur


# ── LA BARRE DE DROITE ──────────────────────────────────────────────────────────────────────────────

func batir(pile: VBoxContainer) -> void:
	var sec := Section.new("Transitions", true, Icones.icone("couches"))
	pile.add_child(sec)
	sec.contenu.add_child(e._texte("Where two layers meet, the look of one spreads over the other: sand over rock, "
		+ "moss over stone. The tiles do not change — only their colours blend, from each layer's representative "
		+ "material. Which layer covers is the higher one in the layer list, unless you paint it otherwise.", 11,
		Palette.GRIS))
	sec.contenu.add_child(e._bouton("Leave", "Back to World (Esc).", e._changer_d_atelier.bind("monde"), "croix"))
	sec.contenu.add_child(e._petit_titre("PAIRS OF LAYERS"))
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(_liste)
	_editeur = VBoxContainer.new()
	_editeur.add_theme_constant_override("separation", 4)
	sec.contenu.add_child(_editeur)

	var sec_m := Section.new("Representative materials", true, Icones.icone("texture"))
	pile.add_child(sec_m)
	sec_m.contenu.add_child(e._texte("The material of each layer that blends over the other layer's tiles. It is "
		+ "projected like a box, so a tileable image works best.", 11, Palette.GRIS))
	_materiaux = VBoxContainer.new()
	_materiaux.add_theme_constant_override("separation", 4)
	sec_m.contenu.add_child(_materiaux)

	var sec_p := Section.new("Brush", true, Icones.icone("sphere"))
	pile.add_child(sec_p)
	sec_p.contenu.add_child(e._texte("Click near a border in the view: that layer covers there. Right click gives the "
		+ "place back to the priority. Painted places show a yellow tint, in this workspace only.", 11, Palette.GRIS))
	_pinceau = OptionButton.new()
	_pinceau.focus_mode = Control.FOCUS_NONE
	_pinceau.item_selected.connect(func(i: int) -> void: couvrant_peint = str(_pinceau.get_item_metadata(i)))
	sec_p.contenu.add_child(_pinceau)
	curseur_rayon = e._curseur_libre(sec_p.contenu, "Radius", 0, RAYON_MAXI, 1,
		"How many cells around the click are painted (Alt + wheel).")
	curseur_rayon.value = rayon
	curseur_rayon.value_changed.connect(func(v: float) -> void: rayon = int(v))
	sec_p.contenu.add_child(e._bouton("Clear the painted places of this pair", "Every place painted for the chosen "
		+ "pair goes back to the priority. One Ctrl+Z.", effacer_les_choix, "gomme"))
	dire(true)


## La barre redite : la liste des paires, l'éditeur de la paire choisie, les représentants, le pinceau. `force` : même si
## les couches n'ont pas changé.
func dire(force := false) -> void:
	if _liste == null:
		return
	var sig := ""
	for c in e._couches:
		sig += "%s:%s;" % [c.get("id", ""), c["nom"]]
	if sig == _signature and not force:
		return
	_signature = sig
	for boite in [_liste, _editeur, _materiaux]:
		for enfant in boite.get_children():
			boite.remove_child(enfant)
			enfant.queue_free()
	var ids: Array = []
	for c in e._couches:
		ids.append(str(c.get("id", "")))
	if ids.size() < 2:
		_liste.add_child(e._texte("One layer only: add a second layer in World, paint it against the first, and "
			+ "their border can blend here.", 11, Palette.GRIS))
	var cles: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			cles.append(TR.cle_de_paire(ids[i], ids[j]))
	if not cles.has(paire_choisie):
		paire_choisie = cles[0] if not cles.is_empty() else ""
	var groupe := ButtonGroup.new()
	for cle in cles:
		var ab: PackedStringArray = String(cle).split("|")
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		var case_actif := CheckBox.new()
		case_actif.focus_mode = Control.FOCUS_NONE
		case_actif.button_pressed = bool(etat["paires"].get(cle, {}).get("actif", false))
		case_actif.tooltip_text = "Blend the border of these two layers."
		case_actif.toggled.connect(func(oui: bool) -> void: allumer(cle, oui))
		ligne.add_child(case_actif)
		var b := Button.new()
		b.text = "%s  ·  %s" % [_nom(ab[0]), _nom(ab[1])]
		b.toggle_mode = true
		b.button_group = groupe
		b.button_pressed = cle == paire_choisie
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			paire_choisie = cle
			dire(true))
		ligne.add_child(b)
		_liste.add_child(ligne)
	_dire_l_editeur()
	_dire_les_materiaux()
	_dire_le_pinceau()


func _dire_l_editeur() -> void:
	if paire_choisie == "":
		return
	var ab: PackedStringArray = paire_choisie.split("|")
	var r := rangs()
	var haut: String = ab[0] if int(r.get(ab[0], 99)) < int(r.get(ab[1], 99)) else ab[1]
	_editeur.add_child(e._texte("By default « %s » covers: it is higher in the layer list. The brush changes it here and "
		% _nom(haut) + "there.", 11, Palette.GRIS))
	var p := _paire(paire_choisie)
	for c in [ab[0], ab[1]]:
		var d: String = ab[1] if c == ab[0] else ab[0]
		_editeur.add_child(e._petit_titre("WHEN « %s » COVERS « %s »" % [_nom(c).to_upper(), _nom(d).to_upper()]))
		var rg: Dictionary = TR.reglages((p["couvre"] as Dictionary).get(c, {}))
		for k in TR.REGLAGES:
			var curseur: HSlider = e._curseur_libre(_editeur, NOMS_REGLAGES[k][0], TR.BORNES[k][0], TR.BORNES[k][1],
				NOMS_REGLAGES[k][1], AIDES_REGLAGES[k])
			curseur.value = rg[k]
			curseur.set_meta("reglage", [c, k])
			curseur.drag_started.connect(func() -> void: _instantane = (etat["paires"] as Dictionary).duplicate(true))
			curseur.value_changed.connect(func(v: float) -> void: regler(c, k, v))
			curseur.drag_ended.connect(func(change: bool) -> void: _fin_de_reglage(change))


func _dire_les_materiaux() -> void:
	for c in e._couches:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		var l: Label = e._texte(str(c["nom"]), 11)
		l.custom_minimum_size = Vector2(80, 0)
		l.clip_text = true
		ligne.add_child(l)
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.clip_text = true
		o.add_item("Legend colour", 0)
		o.set_item_metadata(0, -1)
		var mats := materiaux_de(c)
		for k in mats.size():
			o.add_item(str(mats[k].get("nom", "Material %d" % k)))
			o.set_item_metadata(o.item_count - 1, k)
		var courant := indice_representant(c)
		for i in o.item_count:
			if int(o.get_item_metadata(i)) == courant:
				o.select(i)
		var id := str(c.get("id", ""))
		o.item_selected.connect(func(i: int) -> void: choisir_representant(id, int(o.get_item_metadata(i))))
		ligne.add_child(o)
		_materiaux.add_child(ligne)


func _dire_le_pinceau() -> void:
	_pinceau.clear()
	if paire_choisie == "":
		return
	var ab: PackedStringArray = paire_choisie.split("|")
	for id in ab:
		_pinceau.add_item("« %s » covers" % _nom(id))
		_pinceau.set_item_metadata(_pinceau.item_count - 1, id)
	_pinceau.add_item("By priority")
	_pinceau.set_item_metadata(_pinceau.item_count - 1, "")
	var trouve := false
	for i in _pinceau.item_count:
		if str(_pinceau.get_item_metadata(i)) == couvrant_peint:
			_pinceau.select(i)
			trouve = true
	if not trouve:
		_pinceau.select(0)
		couvrant_peint = str(_pinceau.get_item_metadata(0))


# ── LES GESTES (une annulation chacun) ──────────────────────────────────────────────────────────────

func allumer(cle: String, oui: bool) -> void:
	var avant: Dictionary = (etat["paires"] as Dictionary).duplicate(true)
	_paire(cle)["actif"] = oui
	_geste_paires("Transition %s" % ("on" if oui else "off"), avant, (etat["paires"] as Dictionary).duplicate(true))
	e._dire(("[b]Transition on[/b] — « %s » and « %s » blend where they meet. [i]Paint in the view to choose which "
		+ "covers.[/i]" if oui else "[i]Transition off — « %s » and « %s » meet without blending.[/i]")
		% [_nom(cle.split("|")[0]), _nom(cle.split("|")[1])])


## Un curseur bouge : le réglage est posé tout de suite (la vue suit) ; l'annulation se fait au lâcher.
func regler(c: String, k: String, v: float) -> void:
	var p := _paire(paire_choisie)
	if not (p["couvre"] as Dictionary).has(c):
		p["couvre"][c] = TR.REGLAGES.duplicate()
	p["couvre"][c][k] = v
	_a_poser_table = true
	if _instantane.is_empty():   # un clic sans glisser, ou une valeur posée par le code
		e._enregistrer_plus_tard()


func _fin_de_reglage(change: bool) -> void:
	if not change or _instantane.is_empty():
		_instantane = {}
		return
	_geste_paires("Transition settings", _instantane, (etat["paires"] as Dictionary).duplicate(true), false)
	_instantane = {}


func _geste_paires(nom: String, avant: Dictionary, apres: Dictionary, executer := true) -> void:
	e._histoire.create_action(nom)
	e._histoire.add_do_method(_poser_paires.bind(apres))
	e._histoire.add_undo_method(_poser_paires.bind(avant))
	e._histoire.commit_action(executer)
	if not executer:
		e._enregistrer_plus_tard()


func _poser_paires(p: Dictionary) -> void:
	etat["paires"] = p.duplicate(true)
	_a_poser_table = true
	dire(true)
	e._enregistrer_plus_tard()


func choisir_representant(id: String, k: int) -> void:
	var avant: Dictionary = (etat["representants"] as Dictionary).duplicate()
	var apres := avant.duplicate()
	apres[id] = k
	e._histoire.create_action("Transition material")
	e._histoire.add_do_method(_poser_representants.bind(apres))
	e._histoire.add_undo_method(_poser_representants.bind(avant))
	e._histoire.commit_action()


func _poser_representants(r: Dictionary) -> void:
	etat["representants"] = r.duplicate()
	_a_poser_representants = true
	dire(true)
	e._enregistrer_plus_tard()


## LE PINCEAU : `phase` "debut", "suite" ou "fin" ; `sommet` celui de la surface visée (null : rien sous la souris).
func peindre(sommet: Variant, bouton: int, phase: String) -> void:
	if phase == "debut":
		_trait = {"avant": (etat["choix"] as Dictionary).duplicate(), "touches": 0}
	if _trait.is_empty():
		return
	if phase != "fin" and sommet != null:
		var couvrant := "" if bouton == MOUSE_BUTTON_RIGHT else couvrant_peint
		_trait["touches"] = int(_trait["touches"]) + _peindre_autour(sommet, couvrant)
	if phase == "fin":
		var avant: Dictionary = _trait["avant"]
		var touches := int(_trait["touches"])
		_trait = {}
		if touches == 0:
			e._dire("[i]Nothing to paint here: point at a place where two layers of the chosen pair meet.[/i]")
			return
		var apres: Dictionary = (etat["choix"] as Dictionary).duplicate()
		e._histoire.create_action("Transition brush")
		e._histoire.add_do_method(_poser_choix.bind(apres))
		e._histoire.add_undo_method(_poser_choix.bind(avant))
		e._histoire.commit_action(false)
		e._enregistrer_plus_tard()
		if not actif():
			e._dire("[i]Painted — but this pair is off: tick it in the list to see the blend.[/i]")


## Les sommets à moins de `rayon` cases de `centre` où se rencontrent les deux couches de la paire choisie reçoivent
## `couvrant` ("" : la priorité). Rend combien ont changé.
func _peindre_autour(centre: Vector3i, couvrant: String) -> int:
	if paire_choisie == "":
		return 0
	var r := rangs()
	var ab: PackedStringArray = paire_choisie.split("|")
	if not r.has(ab[0]) or not r.has(ab[1]):
		return 0
	var ra := int(r[ab[0]])
	var rb := int(r[ab[1]])
	var n := 0
	for dx in range(-rayon, rayon + 1):
		for dy in range(-rayon, rayon + 1):
			for dz in range(-rayon, rayon + 1):
				if dx * dx + dy * dy + dz * dz > rayon * rayon:
					continue
				var s: Vector3i = centre + Vector3i(dx, dy, dz)
				if not _rencontre(s, ra, rb):
					continue
				var avant := str(etat["choix"].get(s, ""))
				if avant == couvrant:
					continue
				if couvrant == "":
					etat["choix"].erase(s)
				else:
					etat["choix"][s] = couvrant
				rendu.choix(s, int(r[couvrant]) if couvrant != "" else -1)
				n += 1
	return n


## Les huit cases du sommet `s` portent-elles les deux rangs ?
func _rencontre(s: Vector3i, ra: int, rb: int) -> bool:
	var a := false
	var b := false
	for k in 8:
		var c := s + Vector3i(k & 1, (k >> 1) & 1, (k >> 2) & 1)
		var rg := int(e._union.get(c, -1))
		a = a or rg == ra
		b = b or rg == rb
	return a and b


## Les choix posés tels quels (l'annulation) : seuls les sommets qui changent sont réécrits dans la texture.
func _poser_choix(choix: Dictionary) -> void:
	var avant: Dictionary = etat["choix"]
	etat["choix"] = choix.duplicate()
	var r := rangs()
	var touches := {}
	for s in avant:
		touches[s] = true
	for s in choix:
		touches[s] = true
	for s in touches:
		if str(avant.get(s, "")) != str(choix.get(s, "")):
			var id := str(choix.get(s, ""))
			rendu.choix(s, int(r[id]) if r.has(id) else -1)
	e._enregistrer_plus_tard()


func effacer_les_choix() -> void:
	if paire_choisie == "":
		return
	var r := rangs()
	var ab: PackedStringArray = paire_choisie.split("|")
	var avant: Dictionary = (etat["choix"] as Dictionary).duplicate()
	var apres := {}
	for s in avant:
		if not (str(avant[s]) in ab and r.has(ab[0]) and r.has(ab[1]) and _rencontre(s, int(r[ab[0]]), int(r[ab[1]]))):
			apres[s] = avant[s]
	if apres.size() == avant.size():
		e._dire("[i]No place is painted for this pair.[/i]")
		return
	e._histoire.create_action("Transition brush: clear")
	e._histoire.add_do_method(_poser_choix.bind(apres))
	e._histoire.add_undo_method(_poser_choix.bind(avant))
	e._histoire.commit_action()
	e._dire("[b]Cleared[/b] — %d place(s) back to the priority." % (avant.size() - apres.size()))


