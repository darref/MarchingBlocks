extends Node2D
## GREYBOX DE L'ÉCRAN PARTAGÉ — la zone PEINTE à l'épreuve des deux vues (charte §8, étape 2).
##
## Ce qu'on y juge : le balayage, la lisibilité à deux vues, et la question des cinq cases (charte §3) —
## voit-on assez de la grotte dans une bande de 80 pixels, et assez de la surface quand on est dessous ?
##
## ⚠ RIEN ICI N'EST ÉCRIT DEUX FOIS. La carte peinte (`NIVEAUX/zone_depart.tscn`) est la seule vérité :
## `CLIENT/niveau.gd` en déduit les grilles, les murs et les entrées, et ce script ne fait que montrer.
## Les erreurs de carte sont imprimées au démarrage plutôt que tues.
##
## ⚠ L'événement de grotte est un VRAI : un rai rouge, un pilier de glace et un œil posés dans la grille
## de la grotte 1, puis `Monde.resoudre()`. Ils sont posés EN CODE parce que le catalogue n'a pas encore
## ses tuiles — ça viendra avec la première énigme (charte §8, étape 3).
##
## CE QUI SE JOUE — les actions viennent de CLIENT/entrees.gd, donc clavier OU manette, indifféremment
##   ZQSD ou flèches, stick gauche ou croix   marcher (surface : quatre directions ; grotte : gauche, droite)
##   Maj, ou B, ou gâchette droite            courir
##   Espace ou A                              descendre par une entrée (à une case au plus) ; remonter
##
## CE QUI DÉBOGUE — clavier seulement, ces touches ne sont pas du jeu
##   R                poser le rai rouge dans la grotte 1 ; R encore : tout remettre en place
##   F3               imprimer l'état
##   F11, Alt+Entrée  plein écran (autoload CLIENT/fenetre.gd)

const MiseEnPage := preload("res://CLIENT/mise_en_page.gd")
const EcranPartage := preload("res://CLIENT/ecran_partage.gd")
const Entrees := preload("res://CLIENT/entrees.gd")
const Niveau := preload("res://CLIENT/niveau.gd")
const Couleur := preload("res://CORE/couleur.gd")
const Direction := preload("res://CORE/direction.gd")

const ZONE := "res://NIVEAUX/zone_depart.tscn"
const CASE := MiseEnPage.CASE
const SURFACE := 0
const VITESSE := 5.0  # cases par seconde
const COURSE := 2.0  # PROPOSÉ — ce que « courir » multiplie, à régler à l'essai
const PORTEE_ENTREE := 1.0  # en cases, pour descendre ou remonter
const LIGNE_DU_SOL := 8  # la rangée où l'on marche dans une coupe de dix cases
const TAILLE_JOUEUR := 20.0  # en pixels — plus petit qu'une case (32), il passe partout où une case est libre
## PROPOSÉ — combien de temps chaque événement est montré (charte §3, question ouverte).
const DUREES := {"transforme": 0.6, "detruit": 0.5, "active": 0.4, "desactive": 0.4}
## L'énigme de démonstration, en colonnes de la grotte 1.
const DEMO = {"rai": 1, "pilier": 6, "oeil": 9}

const OR := Color("#ebbb69")
const JOUEUR := Color("#f2efe6")
const GLACE := Color("#bfe8f2")
const EAU := Color("#4a8fd0")

var mep = MiseEnPage.new()
var ecran
var zone: Node2D
var monde
var chemins := {}
var entrees: Array = []  # {"case", "grotte", "colonne", "bouche"}
var entrees_cases: Array = []

var sous_terre := false
var grotte := 1
var pos_surface := Vector2(12.5, 22.5)  # en cases
var colonne := 4.5  # en colonnes de grotte — jamais 0 : les extrémités d'une galerie sont de la roche

var grotte_montree := 1
var colonne_montree := 4.5
var _rai_pose := false
var _en_attente: Array = []  # les événements rendus, pas encore montrés en entier

var _marque: Node2D
var _dessus: Node2D  # objets et faisceaux, par-dessus les tuiles de la grotte
var _corps_surface: CharacterBody2D
var _corps_grotte: CharacterBody2D
var _camera_surface: Camera2D
var _camera_grotte: Camera2D
var _noeuds_grottes := {}  # id -> le nœud de la grotte dans la vue


func _ready() -> void:
	Entrees.installer()  # idempotente : l'autoload l'a déjà fait, sauf en --script (la mesure)
	ecran = EcranPartage.new()
	add_child(ecran)

	zone = load(ZONE).instantiate()
	add_child(zone)
	var resultat: Dictionary = zone.construire()
	for erreur in resultat["erreurs"]:
		push_error("CARTE — " + erreur)
		print("CARTE FAUTIVE — " + erreur)
	monde = resultat["monde"]
	chemins = resultat["chemins"]
	entrees = resultat["entrees"]
	for e in entrees:
		entrees_cases.append(e["case"])
	_poser_la_demo()

	# Les calques peints passent dans les deux vues : la surface d'un côté, toutes les grottes de
	# l'autre — une seule visible à la fois, et elles occupent chacune leur propre coin de l'espace.
	zone.get_node("Surface").reparent(ecran.surface)
	zone.get_node("Grottes").reparent(ecran.grotte)
	for i in ecran.grotte.get_node("Grottes").get_child_count():
		_noeuds_grottes[i + 1] = ecran.grotte.get_node("Grottes").get_child(i)

	_marque = _calque(ecran.surface, _dessiner_marque)
	_camera_surface = _camera(ecran.surface)
	_dessus = _calque(ecran.grotte, _dessiner_dessus)
	_camera_grotte = _camera(ecran.grotte)
	print("GREYBOX — zone peinte, écran partagé")
	print("  ZQSD ou stick : marcher   Maj ou B : courir   Espace ou A : descendre / remonter")
	print("  R : rai rouge dans la grotte 1 (R : remettre)   F3 : état   F11 ou Alt+Entrée : plein écran")
	var branchees: Array = Entrees.manettes()
	print("  manettes : %s" % ("aucune branchée" if branchees.is_empty() else ", ".join(PackedStringArray(branchees))))
	print("  zone : %d×%d cases, %d grotte(s), %d entrée(s)" % [
		monde.grilles[SURFACE]["largeur"], monde.grilles[SURFACE]["hauteur"], chemins.size(), entrees.size()])
	_options()

	# ⚠ LES CORPS SONT CRÉÉS APRÈS LES OPTIONS. Elles déplacent le joueur (--pres, --sous-terre) ; un corps
	# posé avant resterait à l'ancienne place, et depuis que les extrémités d'une galerie sont creusées, il
	# s'y retrouvait DANS la roche — la physique l'éjectait alors hors de la grille (vu : colonne −0,15).
	_corps_surface = _corps(ecran.surface, pos_surface * CASE)
	_corps_grotte = _corps(ecran.grotte, Vector2(colonne * CASE, LIGNE_DU_SOL * CASE + CASE / 2.0))
	_seules_les_collisions_de(grotte)


var _capture := ""
var _capture_a := 0.0
var _horloge := 0.0
var _pousser := ""  # une action maintenue depuis la ligne de commande : vérifier une collision sans clavier

## Pour les vérifications sans clavier : après `--`, `--pres` (à une case d'une entrée), `--sous-terre`,
## `--rai`, et `--capture=chemin.png@secondes` qui enregistre l'image de BASE (320×160) à cet instant.
func _options() -> void:
	for option in OS.get_cmdline_user_args():
		if option == "--pres" and not entrees.is_empty():
			pos_surface = Vector2(entrees[0]["case"]) + Vector2(0.5, 1.5)
		elif option == "--sous-terre":
			sous_terre = true
			grotte = 1
			colonne = 8.5
		elif option == "--rai":
			_rai()
		elif option.begins_with("--pousser="):
			_pousser = option.get_slice("=", 1)
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
		print("capture de base : %s à %.2f s, séparateur %d — corps surface %s, corps grotte x=%.1f (colonne %.2f)" % [
			_capture, _horloge, mep.pixel(), _corps_surface.position, _corps_grotte.position.x, colonne])
		_capture = ""


## ⚠ Le déplacement vit ici, et pas dans `_process` : `move_and_slide()` ne parle au moteur physique
## qu'au pas fixe. Les murs qui l'arrêtent sont les collisions des tuiles, déduites de `mur` — le joueur
## et la lumière butent donc exactement sur la même chose.
func _physics_process(_delta: float) -> void:
	if _pousser != "":
		Input.action_press(_pousser)  # ⚠ outil de vérification, jamais du jeu : pousser sans clavier
	var dir := Entrees.deplacement()
	var vitesse := VITESSE * CASE * (COURSE if Entrees.court() else 1.0)
	if Entrees.agit():
		_passer_entree()
	if sous_terre:
		_corps_grotte.velocity = Vector2(dir.x * vitesse, 0.0)
		_corps_grotte.move_and_slide()
		colonne = _corps_grotte.position.x / CASE
	else:
		_corps_surface.velocity = dir * vitesse
		_corps_surface.move_and_slide()
		pos_surface = _corps_surface.position / CASE


func _process(delta: float) -> void:
	_capturer_si_demande(delta)
	var proche_de := MiseEnPage.entree_la_plus_proche(pos_surface, entrees_cases)
	mep.avancer(delta, sous_terre, proche_de["distance"])
	ecran.afficher(mep.pixel(), roundi(mep.balayage.cible))
	_suivre_evenements()
	_choisir_vue_grotte(proche_de["index"])

	var point_surface: Vector2 = Niveau.case_de_surface(chemins, grotte, colonne) if sous_terre else pos_surface
	ecran.centrer(_camera_surface, point_surface * CASE, false)
	ecran.centrer(_camera_grotte, Vector2(colonne_montree * CASE, MiseEnPage.HAUTEUR / 2.0), true)
	_marque.position = (point_surface * CASE).round()
	_marque.queue_redraw()
	_dessus.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var touche := event as InputEventKey
	if touche == null or not touche.pressed or touche.echo:
		return
	match touche.keycode:
		KEY_R:
			_rai()
		KEY_F3:
			_etat()


# ── l'énigme de démonstration ───────────────────────────────────────────────────────────────────────

func _poser_la_demo() -> void:
	monde.poser("PILIER_GLACE", 1, Vector2i(DEMO["pilier"], LIGNE_DU_SOL))
	monde.poser("OEIL_SACRE", 1, Vector2i(DEMO["oeil"], LIGNE_DU_SOL), {"couleur": Couleur.ROUGE})
	monde.resoudre()
	_rai_pose = false


func _rai() -> void:
	if _rai_pose:
		var id: int = monde.objet_en(1, Vector2i(DEMO["rai"], LIGNE_DU_SOL))
		if id != -1:
			monde.retirer(id)
		for c in [DEMO["pilier"], DEMO["oeil"]]:
			var ancien: int = monde.objet_en(1, Vector2i(c, LIGNE_DU_SOL))
			if ancien != -1:
				monde.retirer(ancien)
		_poser_la_demo()
		_en_attente.clear()
		print("énigme remise en place")
		return
	monde.poser("RAI_DE_CIEL", 1, Vector2i(DEMO["rai"], LIGNE_DU_SOL), {"direction": Direction.E, "couleur": Couleur.ROUGE})
	_rai_pose = true
	for e in monde.resoudre():
		print("  événement : ", e)
		if e["grille"] != SURFACE:
			mep.signaler(e["grille"], e["case"], DUREES[e["type"]])
			_en_attente.append(e)


# ── se déplacer d'une vue à l'autre ─────────────────────────────────────────────────────────────────

func _passer_entree() -> void:
	if sous_terre:
		for e in entrees:
			if e["grotte"] == grotte and absf(e["colonne"] + 0.5 - colonne) <= PORTEE_ENTREE:
				sous_terre = false
				pos_surface = Vector2(e["case"]) + Vector2(0.5, 1.5)
				_corps_surface.position = pos_surface * CASE
				print("remonté par l'entrée ", e["case"])
				return
		print("aucune bouche à portée")
		return
	var p := MiseEnPage.entree_la_plus_proche(pos_surface, entrees_cases)
	if p["index"] == -1 or p["distance"] > PORTEE_ENTREE:
		print("aucune entrée à portée (%.1f cases)" % p["distance"])
		return
	var e: Dictionary = entrees[p["index"]]
	sous_terre = true
	grotte = e["grotte"]
	colonne = e["colonne"] + 0.5
	_corps_grotte.position = Vector2(colonne * CASE, LIGNE_DU_SOL * CASE + CASE / 2.0)
	_seules_les_collisions_de(grotte)
	print("descendu dans la grotte %d, colonne %d" % [grotte, e["colonne"]])


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
	else:
		var courant: Dictionary = mep.evenements.courant()
		if not courant.is_empty():
			grotte_montree = courant["grille"]
			colonne_montree = courant["case"].x + 0.5
		elif mep.proche and entree_proche != -1:
			grotte_montree = entrees[entree_proche]["grotte"]
			colonne_montree = entrees[entree_proche]["colonne"] + 0.5
	for id in _noeuds_grottes:
		_noeuds_grottes[id].visible = (id == grotte_montree)


func _etat() -> void:
	print("sous_terre=%s grotte=%d pos=%s colonne=%.2f séparateur=%d cible=%d proche=%s événement=%s fps=%d" % [
		sous_terre, grotte, pos_surface, colonne, mep.pixel(), roundi(mep.balayage.cible), mep.proche,
		mep.evenements.courant(), Engine.get_frames_per_second()])


# ── le dessin par-dessus les tuiles ─────────────────────────────────────────────────────────────────

func _calque(vue: SubViewport, dessin: Callable) -> Node2D:
	var calque := Node2D.new()
	calque.z_index = 10
	vue.add_child(calque)
	calque.draw.connect(dessin)
	return calque


func _camera(vue: SubViewport) -> Camera2D:
	var camera := Camera2D.new()
	vue.add_child(camera)
	camera.make_current()
	return camera


## Un corps invisible : il ne sert qu'à se cogner. Ce qu'on VOIT est dessiné par-dessus, à la position
## que le corps a fini par atteindre — une seule autorité sur la position, et c'est la physique.
func _corps(vue: SubViewport, depart: Vector2) -> CharacterBody2D:
	var corps := CharacterBody2D.new()
	var forme := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(TAILLE_JOUEUR, TAILLE_JOUEUR)
	forme.shape = rectangle
	corps.add_child(forme)
	corps.position = depart
	vue.add_child(corps)
	return corps


## ⚠ TOUTES LES GROTTES OCCUPENT LE MÊME ESPACE dans leur vue : cachée, une grotte garde des roches
## solides, et le joueur se cognerait à une paroi qu'il ne voit pas. On n'active donc la collision que
## sur celle où il se trouve.
func _seules_les_collisions_de(id: int) -> void:
	for autre in _noeuds_grottes:
		for calque in _noeuds_grottes[autre].get_children():
			if calque is TileMapLayer:
				calque.collision_enabled = (autre == id)


func _dessiner_marque() -> void:
	if sous_terre:
		_contour(_marque, Rect2(-6, -6, 12, 12), OR)  # une projection, pas un second corps (charte §2)
	else:
		_marque.draw_rect(Rect2(-5, -5, 10, 10), JOUEUR)


func _dessiner_dessus() -> void:
	var g := grotte_montree
	var animations := {}
	var progression: float = mep.evenements.courant().get("progression", 1.0)
	for i in range(_en_attente.size() - 1, -1, -1):
		var e: Dictionary = _en_attente[i]
		if e["grille"] == g:
			animations[e["case"]] = {"type": e["type"], "p": progression if i == 0 else 0.0}

	for id in monde.objets:
		var o: Dictionary = monde.objets[id]
		if o["grille"] == g:
			_dessiner_objet(id, o, animations.get(o["case"], {}))
	_dessiner_faisceaux(_dessus, g)

	if sous_terre and grotte == g:
		_dessus.draw_rect(Rect2(roundi(colonne * CASE) - 5, LIGNE_DU_SOL * CASE + 6, 10, 10), JOUEUR)


func _dessiner_objet(id: int, o: Dictionary, animation: Dictionary) -> void:
	var x: int = o["case"].x * CASE
	var y: int = o["case"].y * CASE
	var p: float = animation.get("p", 1.0)
	match o["type"]:
		"RAI_DE_CIEL":
			_dessus.draw_rect(Rect2(x + 3, y + 3, 10, 10), _couleur(o["couleur"]))
		"PILIER_GLACE":
			_dessus.draw_rect(Rect2(x + 3, y, 10, CASE), GLACE)
		"FLAQUE":
			var hauteur := roundi(lerpf(CASE, 3.0, p))
			_dessus.draw_rect(Rect2(x + 1, y + CASE - hauteur, 14, hauteur), GLACE.lerp(EAU, p))
		"OEIL_SACRE":
			var eclat := p if animation.get("type", "") == "active" else (1.0 if monde.actifs.has(id) else 0.0)
			_dessus.draw_rect(Rect2(x + 4, y + 4, 8, 8), _couleur(o["couleur"]).darkened(0.7 * (1.0 - eclat)))
		"ENTREE":
			_contour(_dessus, Rect2(x, y, CASE, CASE), OR)
		_:
			_dessus.draw_rect(Rect2(x + 4, y + 4, 8, 8), Color.GRAY)


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
