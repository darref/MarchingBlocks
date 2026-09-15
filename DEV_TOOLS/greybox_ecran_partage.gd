extends Node2D
## GREYBOX DE L'ÉCRAN PARTAGÉ — la mise en page à l'épreuve, avant tout pixel art (charte §8, étape 2).
##
## Ce qu'on y juge : le balayage, les bandes noires, la fenêtre 2:1, et la question des cinq cases
## (charte §3) — voit-on assez de la grotte dans une bande de 80 pixels ?
##
## ⚠ L'événement de grotte est un VRAI : un rai rouge, un pilier de glace et un œil rouge dans la grille
## de la grotte 1. `Monde.resoudre()` rend un « transforme » puis un « active », qui portent leur grille
## et leur case — exactement ce que le jeu lira. Rien ici ne recalcule une règle.
##
## TOUCHES
##   flèches          marcher (surface : quatre directions ; grotte : gauche, droite)
##   Espace           descendre par une entrée (à une case au plus) ; remonter par sa bouche
##   R                poser le rai rouge dans la grotte 1 ; R encore : tout remettre en place
##   F3               imprimer l'état
##   F11, Alt+Entrée  plein écran (autoload CLIENT/fenetre.gd)

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")
const EcranPartage := preload("res://CLIENT/ecran_partage.gd")
const Monde := preload("res://CORE/monde.gd")
const Direction := preload("res://CORE/direction.gd")
const Couleur := preload("res://CORE/couleur.gd")

const CASE := MiseEnPage.CASE
const SURFACE := 0
const CARTE := Vector2i(48, 30)
const HAUTEUR_GROTTE := 10
const LIGNE_DU_SOL := 8  # la rangée où l'on marche ; la 9 est la roche du sol
const VITESSE := 5.0  # cases par seconde
const PORTEE_ENTREE := 1.0  # en cases, pour descendre ou remonter
## PROPOSÉ — combien de temps chaque événement est montré (charte §3, question ouverte).
const DUREES := {"transforme": 0.6, "detruit": 0.5, "active": 0.4, "desactive": 0.4}

## Chaque grotte est un CHEMIN sur la grille de surface (charte §2), fait de segments droits. La table
## d'entiers qui en sort est la seule vérité : la longueur de la coupe s'en déduit.
const TRACES := {
	1: [Vector2i(8, 6), Vector2i(20, 6), Vector2i(20, 12), Vector2i(26, 12)],
	2: [Vector2i(30, 20), Vector2i(44, 20)],
}
## Les entrées : [case de surface, grotte, colonne de la bouche].
const ENTREES := [
	[Vector2i(10, 6), 1, 2],
	[Vector2i(26, 12), 1, 24],
	[Vector2i(36, 20), 2, 6],
]
const CASE_RAI := Vector2i(9, LIGNE_DU_SOL)

const NUIT := Color("#130E22")
const OR := Color("#EBBB69")
const VERT_A := Color("#3d6b3a")
const VERT_B := Color("#467644")
const TRACE := Color("#2e4f33")
const JOUEUR := Color("#f2efe6")
const ROCHE := Color("#1c1628")
const TUNNEL_A := Color("#3a3150")
const TUNNEL_B := Color("#41375a")
const PUITS := Color("#5a4d78")
const GLACE := Color("#bfe8f2")
const EAU := Color("#4a8fd0")

var mep = MiseEnPage.new()
var ecran
var monde
var chemins := {}  # grotte -> Array de Vector2i
var entrees_cases: Array = []

var sous_terre := false
var grotte := 1
var pos_surface := Vector2(14.5, 9.5)  # en cases
var colonne := 0.5  # en colonnes de grotte

var grotte_montree := 1
var colonne_montree := 2.5
var _rai_pose := false
var _en_attente: Array = []  # les événements rendus pas encore montrés en entier, dans l'ordre

var _carte: Node2D
var _marque: Node2D
var _coupe: Node2D
var _camera_surface: Camera2D
var _camera_grotte: Camera2D


func _ready() -> void:
	for g in TRACES:
		chemins[g] = _chemin(TRACES[g])
	for e in ENTREES:
		entrees_cases.append(e[0])
		if chemins[e[1]][e[2]] != e[0]:
			push_error("Greybox : la colonne %d de la grotte %d n'est pas sous l'entrée %s" % [e[2], e[1], e[0]])
	_construire_monde()

	ecran = EcranPartage.new()
	add_child(ecran)
	_carte = _calque(ecran.surface, _dessiner_carte)
	_marque = _calque(ecran.surface, _dessiner_marque)
	_camera_surface = _camera(ecran.surface)
	_coupe = _calque(ecran.grotte, _dessiner_coupe)
	_camera_grotte = _camera(ecran.grotte)

	print("GREYBOX — écran partagé")
	print("  flèches : marcher   Espace : descendre / remonter   R : rai rouge dans la grotte 1 (R : remettre)")
	print("  F3 : état   F11 ou Alt+Entrée : plein écran")
	_options()


var _capture := ""
var _capture_a := 0.0
var _horloge := 0.0

## Pour les vérifications sans clavier : après `--`, `--pres` (à une case d'une entrée), `--sous-terre`,
## `--rai`, et `--capture=chemin.png@secondes` qui enregistre l'image de BASE (320×160) à cet instant.
func _options() -> void:
	for option in OS.get_cmdline_user_args():
		if option == "--pres":
			pos_surface = Vector2(10.5, 7.5)
		elif option == "--sous-terre":
			sous_terre = true
			grotte = 1
			colonne = 12.5
		elif option == "--rai":
			_rai()
		elif option.begins_with("--capture="):
			var valeur := option.get_slice("=", 1)
			_capture = valeur.get_slice("@", 0)
			_capture_a = float(valeur.get_slice("@", 1)) if "@" in valeur else 1.5


func _capturer_si_demande(delta: float) -> void:
	if _capture == "":
		return
	_horloge += delta
	if _horloge >= _capture_a:
		get_viewport().get_texture().get_image().save_png(_capture)
		print("capture de base : %s à %.2f s, séparateur %d" % [_capture, _horloge, mep.pixel()])
		_capture = ""


func _process(delta: float) -> void:
	_capturer_si_demande(delta)
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if sous_terre:
		colonne = clampf(colonne + dir.x * VITESSE * delta, 0.5, chemins[grotte].size() - 0.5)
	else:
		pos_surface = (pos_surface + dir * VITESSE * delta).clamp(Vector2(0.5, 0.5), Vector2(CARTE) - Vector2(0.5, 0.5))

	var proche_de := MiseEnPage.entree_la_plus_proche(pos_surface, entrees_cases)
	mep.avancer(delta, sous_terre, proche_de["distance"])
	ecran.afficher(mep.pixel(), roundi(mep.balayage.cible))
	_suivre_evenements()
	_choisir_vue_grotte(proche_de["index"])

	var point_surface: Vector2 = _projection() if sous_terre else pos_surface
	ecran.centrer(_camera_surface, point_surface * CASE, false)
	ecran.centrer(_camera_grotte, Vector2(colonne_montree * CASE, HAUTEUR_GROTTE * CASE / 2.0), true)
	_marque.position = (point_surface * CASE).round()
	_marque.queue_redraw()
	_coupe.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	match touche.keycode:
		KEY_SPACE:
			_passer_entree()
		KEY_R:
			_rai()
		KEY_F3:
			_etat()


# ── le monde ────────────────────────────────────────────────────────────────────────────────────────

func _construire_monde() -> void:
	monde = Monde.new()
	monde.ajouter_grille(SURFACE, CARTE.x, CARTE.y)
	for g in chemins:
		monde.ajouter_grille(g, chemins[g].size(), HAUTEUR_GROTTE)
	for e in ENTREES:
		monde.poser("ENTREE", SURFACE, e[0], {"vers_grille": e[1], "vers_case": Vector2i(e[2], 1), "vers_direction": Direction.S})
	monde.poser("PILIER_GLACE", 1, Vector2i(14, LIGNE_DU_SOL))
	monde.poser("OEIL_SACRE", 1, Vector2i(17, LIGNE_DU_SOL), {"couleur": Couleur.ROUGE})
	for erreur in monde.valider():
		push_error("Greybox : " + erreur)
	monde.resoudre()
	_rai_pose = false


func _rai() -> void:
	if _rai_pose:
		_construire_monde()
		_en_attente.clear()
		print("énigme remise en place")
		return
	monde.poser("RAI_DE_CIEL", 1, CASE_RAI, {"direction": Direction.E, "couleur": Couleur.ROUGE})
	_rai_pose = true
	for e in monde.resoudre():
		print("  événement : ", e)
		if e["grille"] != SURFACE:
			mep.signaler(e["grille"], e["case"], DUREES[e["type"]])
			_en_attente.append(e)


func _passer_entree() -> void:
	if sous_terre:
		for e in ENTREES:
			if e[1] == grotte and absf(e[2] + 0.5 - colonne) <= PORTEE_ENTREE:
				sous_terre = false
				pos_surface = Vector2(e[0]) + Vector2(0.5, 1.5)
				print("remonté par l'entrée ", e[0])
				return
		print("aucune bouche à portée")
		return
	var p := MiseEnPage.entree_la_plus_proche(pos_surface, entrees_cases)
	if p["index"] == -1 or p["distance"] > PORTEE_ENTREE:
		print("aucune entrée à portée (%.1f cases)" % p["distance"])
		return
	var e: Array = ENTREES[p["index"]]
	sous_terre = true
	grotte = e[1]
	colonne = e[2] + 0.5
	print("descendu dans la grotte %d, colonne %d" % [grotte, e[2]])


## Oublie les événements que MiseEnPage a fini de montrer : la tête de `_en_attente` est celle qu'elle montre.
func _suivre_evenements() -> void:
	var courant: Dictionary = mep.evenements.courant()
	if courant.is_empty():
		_en_attente.clear()
		return
	while not _en_attente.is_empty() and (_en_attente[0]["grille"] != courant["grille"] or _en_attente[0]["case"] != courant["case"]):
		_en_attente.pop_front()


## Ce que montre la vue de la grotte. Rien à montrer (la bande se referme) : on garde la dernière vue.
func _choisir_vue_grotte(entree_proche: int) -> void:
	if sous_terre:
		grotte_montree = grotte
		colonne_montree = colonne
		return
	var courant: Dictionary = mep.evenements.courant()
	if not courant.is_empty():
		grotte_montree = courant["grille"]
		colonne_montree = courant["case"].x + 0.5
	elif mep.proche and entree_proche != -1:
		grotte_montree = ENTREES[entree_proche][1]
		colonne_montree = ENTREES[entree_proche][2] + 0.5


## La projection du joueur de la grotte sur la surface : la table dit la case, l'interpolation entre deux
## cases voisines ne sert qu'à faire défiler la caméra sans à-coup.
func _projection() -> Vector2:
	var ch: Array = chemins[grotte]
	var c := colonne - 0.5
	var i := clampi(floori(c), 0, ch.size() - 1)
	var j := mini(i + 1, ch.size() - 1)
	return Vector2(ch[i]).lerp(Vector2(ch[j]), clampf(c - i, 0.0, 1.0)) + Vector2(0.5, 0.5)


func _etat() -> void:
	print("sous_terre=%s grotte=%d pos=%s colonne=%.2f séparateur=%d cible=%d proche=%s événement=%s fps=%d" % [
		sous_terre, grotte, pos_surface, colonne, mep.pixel(), roundi(mep.balayage.cible), mep.proche,
		mep.evenements.courant(), Engine.get_frames_per_second()])


static func _chemin(points: Array) -> Array:
	var cases: Array = [points[0]]
	for i in range(1, points.size()):
		var pas: Vector2i = (points[i] - points[i - 1]).sign()
		if pas.x != 0 and pas.y != 0:
			push_error("Greybox : segment en diagonale — OUVERT, charte §2")
			return cases
		var c: Vector2i = points[i - 1]
		while c != points[i]:
			c += pas
			cases.append(c)
	return cases


# ── le dessin ───────────────────────────────────────────────────────────────────────────────────────

func _calque(vue: SubViewport, dessin: Callable) -> Node2D:
	var calque := Node2D.new()
	vue.add_child(calque)
	calque.draw.connect(dessin)
	return calque


func _camera(vue: SubViewport) -> Camera2D:
	var camera := Camera2D.new()
	vue.add_child(camera)
	camera.make_current()
	return camera


func _dessiner_carte() -> void:
	_carte.draw_rect(Rect2(-4000, -4000, 9000, 9000), NUIT)
	for y in CARTE.y:
		for x in CARTE.x:
			_carte.draw_rect(Rect2(x * CASE, y * CASE, CASE, CASE), VERT_A if (x + y) % 2 == 0 else VERT_B)
	for g in chemins:
		for c in chemins[g]:
			_carte.draw_rect(Rect2(c.x * CASE + 5, c.y * CASE + 5, 6, 6), TRACE)
	for e in ENTREES:
		var c: Vector2i = e[0]
		_carte.draw_rect(Rect2(c.x * CASE, c.y * CASE, CASE, CASE), OR)
		_carte.draw_rect(Rect2(c.x * CASE + 1, c.y * CASE + 1, CASE - 2, CASE - 2), NUIT)


func _dessiner_marque() -> void:
	if sous_terre:
		_contour(_marque, Rect2(-6, -6, 12, 12), OR)  # une projection, pas un second corps (charte §2)
	else:
		_marque.draw_rect(Rect2(-5, -5, 10, 10), JOUEUR)


func _dessiner_coupe() -> void:
	var g := grotte_montree
	var n: int = chemins[g].size()
	_coupe.draw_rect(Rect2(-4000, -40, 9000, 240), ROCHE)
	for x in n:
		_coupe.draw_rect(Rect2(x * CASE, CASE, CASE, LIGNE_DU_SOL * CASE), TUNNEL_A if x % 2 == 0 else TUNNEL_B)
	for e in ENTREES:
		if e[1] == g:
			_coupe.draw_rect(Rect2(e[2] * CASE, 0, CASE, CASE), PUITS)
			_contour(_coupe, Rect2(e[2] * CASE, 0, CASE, CASE), OR)

	var animations := {}  # case -> progression de l'événement qui s'y joue (0 : pas encore montré)
	var progression: float = mep.evenements.courant().get("progression", 1.0)
	for i in range(_en_attente.size() - 1, -1, -1):
		var e: Dictionary = _en_attente[i]
		if e["grille"] == g:
			animations[e["case"]] = {"type": e["type"], "p": progression if i == 0 else 0.0}

	for id in monde.objets:
		var o: Dictionary = monde.objets[id]
		if o["grille"] == g:
			_dessiner_objet(id, o, animations.get(o["case"], {}))
	_dessiner_faisceaux(_coupe, g)

	if sous_terre and grotte == g:
		_coupe.draw_rect(Rect2(roundi(colonne * CASE) - 5, LIGNE_DU_SOL * CASE + 6, 10, 10), JOUEUR)


func _dessiner_objet(id: int, o: Dictionary, animation: Dictionary) -> void:
	var x: int = o["case"].x * CASE
	var y: int = o["case"].y * CASE
	var p: float = animation.get("p", 1.0)
	match o["type"]:
		"RAI_DE_CIEL":
			_coupe.draw_rect(Rect2(x + 3, y + 3, 10, 10), _couleur(o["couleur"]))
		"PILIER_GLACE":
			_coupe.draw_rect(Rect2(x + 3, y, 10, CASE), GLACE)
		"FLAQUE":
			var hauteur := roundi(lerpf(CASE, 3.0, p))
			_coupe.draw_rect(Rect2(x + 1, y + CASE - hauteur, 14, hauteur), GLACE.lerp(EAU, p))
		"OEIL_SACRE":
			var eclat := p if animation.get("type", "") == "active" else (1.0 if monde.actifs.has(id) else 0.0)
			_coupe.draw_rect(Rect2(x + 4, y + 4, 8, 8), _couleur(o["couleur"]).darkened(0.7 * (1.0 - eclat)))
		_:
			_coupe.draw_rect(Rect2(x + 4, y + 4, 8, 8), Color.GRAY)


## Les faisceaux de `Monde.faisceaux`, tels quels — arrêtés à la première case dont l'événement n'a pas
## encore été montré : ce qu'on voit est vrai, la lumière ne passe pas une glace qui n'a pas fini de fondre.
func _dessiner_faisceaux(calque: Node2D, g: int) -> void:
	var cachees := {}
	for e in _en_attente:
		cachees[Vector3i(e["grille"], e["case"].x, e["case"].y)] = true
	for f in monde.faisceaux:
		var source: Dictionary = monde.objets[f["source"]]
		var avant := {"grille": source["grille"], "case": source["case"]}
		for pas in f["pas"]:
			if pas["grille"] == g and avant["grille"] == g:
				calque.draw_line(_centre(avant["case"]), _centre(pas["case"]), _couleur(pas["couleur"]))
			avant = pas
			if cachees.has(Vector3i(pas["grille"], pas["case"].x, pas["case"].y)):
				break


func _centre(c: Vector2i) -> Vector2:
	return Vector2(c * CASE) + Vector2(CASE / 2.0, CASE / 2.0)


static func _couleur(c: int) -> Color:
	return Color(float(c & 1), float((c >> 1) & 1), float((c >> 2) & 1))


static func _contour(calque: CanvasItem, r: Rect2, couleur: Color) -> void:
	calque.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), couleur)
	calque.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), couleur)
	calque.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), couleur)
	calque.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), couleur)
