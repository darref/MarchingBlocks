extends RefCounted
## LE FORMAT DU MONDE PEINT v1 — ce que l'atelier World livre aux trois greffons.
##
## **DÉCIDÉ (Jordan, 29 septembre 2026)** : « dans WORLD, une section pour gérer le monde peint — déjà
## l'exporter vers les trois addons ». La charte le tenait OUVERT depuis le format des tuiles (§4 :
## « l'export des MONDES peints, `world.json` : couches, jeu de tuiles, cases »).
##
##   <nom>.mbworld/
##     world.json          les couches, dans l'ordre : nom, visibilité, jeu de tuiles, CASES
##     <jeu>.mbset/        un dossier de tuiles (format neutre, §4) par SOURCE distincte
##     water/<nom>.glb     la nappe CUITE d'une couche d'eau (charte §5, « le mode Fluids »), une par couche
##     transitions/        l'image du matériau REPRÉSENTANT de chaque couche (l'atelier Transitions), s'il y en a
##     foliage/<nom>.glb   les modèles du feuillage (l'atelier Foliage), COPIÉS comme les jeux de tuiles
##     crossings/<nom>.glb les modèles SCULPTÉS des franchisseurs (l'atelier Crossings, 20 octobre 2026), un par modèle
##     README.txt
##
## ⚠ PARITÉ DES GREFFONS (7 octobre 2026) : `transitions` et `foliage` entrent dans `world.json`, FACULTATIVES comme
## `water` — un monde exporté d'avant les lit absentes (rien ne se mêle, rien n'est planté), la version reste 1. Une clé
## que ces règles ne décrivent pas est ignorée par un lecteur qui ne la connaît pas.
##
## ⚠ **LE MONDE SE SUFFIT À LUI-MÊME** : ses jeux de tuiles voyagent DANS son dossier, et `world.json`
## les désigne par un chemin RELATIF. Un monde qui pointerait vers un `.mbset` ailleurs sur le disque
## arriverait chez l'acheteur sans ses tuiles.
## ⚠ **UNE SOURCE, UN DOSSIER** : deux couches tranchées du même travail partagent le même `.mbset`.
## ⚠ **UNE COUCHE SANS TUILES VOYAGE QUAND MÊME** — ses cases sont du travail — avec `"tileset": null`.
## Le greffon la montre sans tuiles, et le DIT (charte §3 : l'absence se voit).
## ⚠ **LES CASES SONT EN ESPACE DU FORMAT** (la case `c` occupe `[c, c+1]`, +Y en haut), à plat par
## triplets — `[x0, y0, z0, x1, y1, z1, …]` — TRIÉES, pour qu'un même monde s'écrive toujours pareil.
## Un greffon d'un autre repère les convertit par le repère MESURÉ de leur jeu de tuiles (§4), comme les
## cases qu'on y peint.

const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")

## ⚠ L'EAU VOYAGE DANS LE MONDE, PAS DANS UN JEU DE TUILES : un `.mbset` appartient à une couche de tuiles, l'eau au
## monde entier (DÉCIDÉ, Jordan, 1er octobre 2026). Ses noms d'aspect, en anglais pour les greffons.
const ASPECTS := {"stylise": "stylized", "transparent": "clear", "reflechissant": "reflective",
	"lave": "lava", "marais": "swamp", "acide": "acid"}

const FORMAT := "marchingblocks-world"
const FORMAT_EPREUVE := "marchingblocks-world-conformance"
const VERSION := 1


## LA RÈGLE DE LECTURE — écrite dans le README, et c'est elle que les trois greffons implémentent.
static func regle() -> PackedStringArray:
	return PackedStringArray([
		"MARCHINGBLOCKS WORLD v1 — world.json",
		"",
		"format   must be \"marchingblocks-world\". version: refuse anything newer than 1.",
		"layers   an array, in PRIORITY order (the first is the highest: where layers meet, its tiles are",
		"         placed — the tileset rule, step 7). Each layer:",
		"  name      a string",
		"  visible   true or false",
		"  tileset   the path of a tileset.json RELATIVE to world.json, or null (a layer without tiles:",
		"            its cells still travel; show that it has no tiles, never invent some)",
		"  cells     a flat array of integers, x y z per cell, in FORMAT space: cell c covers [c, c+1],",
		"            +Y is up. Its length is a multiple of 3. The same cell never appears twice.",
		"  variant_weights   (optional) an object: key → an array of INTEGERS, the weights of the base tile and",
		"                    of each variant of that key in the draw (the tileset rule, step 8)",
		"  variant_choices   (optional) a flat array of integers, x y z c per vertex (FORMAT space, the vertex of",
		"                    the tileset rule): at that vertex, place variant c (0 is the base tile). Its length",
		"                    is a multiple of 4. The same vertex never appears twice.",
		"Refuse the whole file, and say why, if any of these does not hold.",
	])


## LA RÈGLE DE L'EAU — écrite dans le README. ⚠ PAS ENCORE DANS `regle()` NI DANS LES CAS D'ÉPREUVE des greffons
## (étape 5 du mode Fluids) : la clé `water` est en plus, et les lecteurs actuels ne lisent que `layers`.
static func regle_eau() -> PackedStringArray:
	return PackedStringArray([
		"water    (optional) an array of water layers, in order. Each water layer:",
		"  name      a string",
		"  visible   true or false",
		"  look      a string: \"stylized\", \"clear\", \"reflective\", \"lava\", \"swamp\" or \"acid\" — a",
		"            SUGGESTION only (lava, swamp and acid flow and fill hollows exactly like water). The looks shipped",
		"            with the plugins are examples: assign any water shader you like, it gets the data below.",
		"  mesh      the path of a .glb RELATIVE to world.json, or null (nothing to draw). Its vertices are in",
		"            FORMAT space, like the cells. Every vertex carries the water data:",
		"              COLOR_0 r, g   the flow along x and z, mapped from [-1, 1] to [0, 1]; 0.5 0.5 is still water",
		"              COLOR_0 b      the kind of water: 0 still (lake, sea), 0.5 river, 0.75 foam (the churning",
		"                             water at the foot of a waterfall, its spray, a spring), 1 waterfall",
		"              COLOR_0 a      on still water and rivers, the depth below, in cells / 8, capped at 1 (1 too",
		"                             for a bottomless sea); on a waterfall and on foam, the amount of foam, 0 to 1",
		"              NORMAL         the shape of the water (a waterfall is a curved, closed sheet)",
		"              TEXCOORD_0     x, z on still water and rivers; across, height on a waterfall",
		"            Colours are quantized to 1/255.",
		"  sources   a flat array of integers, x y z per source cell: where the water was placed. The mesh",
		"            is deduced from them and from the cells of EVERY layer; a plugin may deduce it again.",
		"            Only ONE sea: taking the sources of every water layer in order, the first source in the void",
		"            is the sea; any other source in the void is refused (it makes no water).",
		"water_floor  (optional, beside water) where the ground of the tiles is drawn, for the heights of the water:",
		"            0.25 (inset: the top of a full cell y - 1 is seen at y - 0.25), 0 (centred: at y) or -0.25 (outset:",
		"            at y + 0.25). Absent: 0.25 (worlds exported before it). Any other value refuses the world. A plugin",
		"            that deduces the mesh again uses it (lakes at L + 1 - |floor| - 0.05, rivers at y + 0.3 - floor).",
	])


## LA RÈGLE DES TRANSITIONS (`transitions.gd`, `melange`) — écrite dans le README, les cas d'épreuve des greffons.
static func regle_transitions() -> PackedStringArray:
	var d := TR.reglages_en({})
	return PackedStringArray([
		"transitions   (optional) how two tile layers blend where they meet. The GEOMETRY never changes (the tiles are",
		"              the ones the tileset rule places); only the LOOK of the surface does. Absent: nothing blends.",
		"  pairs             an array of {a, b, active, a_covers_b, b_covers_a}: a < b are layer indices (in layers), active a",
		"                    bool, the two settings say how the first layer covers the second. The same pair never twice.",
		"  settings          softness in [0.05, 1] (default %s), reach in [-0.5, 0.5] (%s), irregularity in [0, 1] (%s),"
			% [d["softness"], d["reach"], d["irregularity"]],
		"                    grain in [0.25, 6] (%s), fills_hollows in [0, 1] (%s). A missing setting takes its default,"
			% [d["grain"], d["fills_hollows"]],
		"                    one out of range is clamped.",
		"  representatives   one per layer, in layer order: {image, color, scale, roughness}. image: a PNG path RELATIVE to",
		"                    world.json, or null (plain colour). color [r, g, b, a] multiplies the image AS IS (no sRGB",
		"                    conversion of the colour). scale: world cells per repeat of the image (at least 0.01). The image is",
		"                    projected in a box: weights w = |n|^4 / sum (n the world normal), samples at p.zy/scale, p.xz/scale,",
		"                    p.xy/scale. A layer's representative is what is laid over the OTHER layer's surface.",
		"  choices           a flat array x y z L per vertex (FORMAT space): at that vertex, layer L covers. The same vertex",
		"                    never twice. A choice of a layer that is not in the blending pair counts as no choice.",
		"  Only layers 0 to %d blend (a pair with a larger index blends nothing). Hidden layers place no cell." % (TR.MAXI - 1),
		"  Refuse the whole file, and say why, if any of these does not hold.",
		"THE BLEND at a point p of the surface of the tile of vertex v (that tile covers [v + 1/2, v + 3/2]; take v from the",
		"  TILE, never from p: on a joint, p belongs to two tiles):",
		"  f = clamp(p - v - 1/2, 0, 1) on each axis. Corner k = dx + 2 dy + 4 dz (d in {0, 1}^3) is the cell v + d: rank_k",
		"    = its layer index (-1 empty), choice_k = the layer chosen at VERTEX v + d (-1 none), weight w_k =",
		"    (dx ? f.x : 1 - f.x) (dy ? f.y : 1 - f.y) (dz ? f.z : 1 - f.z).",
		"  owner = the smallest rank among the corners; none: nothing. For every other rank r, part_r = the sum of its",
		"    weights; other = the rank with the largest part, ties to the first corner in k order; none: nothing.",
		"  The pair {owner, other} must be active (both directions known), else nothing. s = part_other / (part_other +",
		"    w_owner), where w_owner = the sum of the owner's weights.",
		"  covering_k = choice_k if it is owner or other, else owner (the higher priority). vote = the sum of w_k where",
		"    covering_k = other.",
		"  visible(S, x, h, n) = smoothstep(0.5 - S.softness / 2, 0.5 + S.softness / 2, x + (S.reach + S.fills_hollows (0.5",
		"    - h) + S.irregularity (n - 0.5)) 4 x (1 - x)) — the shift is ZERO at both ends.",
		"  alpha = vote visible(other covers owner, s, h_owner, n) + (1 - vote) (1 - visible(owner covers other, 1 - s,",
		"    h_other, n)): draw the OTHER layer's representative over the surface with that alpha (nothing below 0.004).",
		"  h_L = the luminance (0.299 r + 0.587 g + 0.114 b) of layer L's representative at p. n = a value noise in [0, 1]",
		"    at p times the grain of the direction (the conformance cases give n, the same for both directions).",
	])


## LA RÈGLE DU FEUILLAGE (`feuillage.gd`) — écrite dans le README, les cas d'épreuve des greffons.
static func regle_feuillage() -> PackedStringArray:
	return PackedStringArray([
		"foliage   (optional) the plants of the whole world (not of a layer). Absent: no plant.",
		"  models    an array of {id (an integer, unique), name, mesh (a .glb path RELATIVE to world.json, or null),",
		"            ground_offset (model units: how far its origin sits ABOVE the ground; negative buries it), scale,",
		"            scale_random (each plant draws a factor in [1 - a, 1 + a], a <= 0.9), footprint (radius in cells, at",
		"            scale 1), height (the top of the model above its origin, model units), wind (0 still to 1)}.",
		"            A missing number takes its default (0, 1, 0.2, 0.5, 1, 0.5); one of another type refuses the file.",
		"  plants    a flat array of numbers, 7 per plant: model id, x, y, z (the point ON THE GROUND, FORMAT space), yaw",
		"            (radians around +Y), scale (the plant's own draw), mode (0 placed in the air, 1 planted).",
		"            A plant of an unknown model refuses the file.",
		"  A plant's model sits at T = translate(p + (0, ground_offset s, 0)) rotateY(yaw) scale(s), s = model.scale * plant",
		"  scale; its height above the ground is max(0, (height + ground_offset) s).",
		"  WIND (each engine writes its own shader on the same data): per plant (ground = p.y, height above ground,",
		"  phase = (0.37 p.x + 0.71 p.z) mod 2 pi, amplitude = wind). In WORLD space, for a vertex P with normal N at time t:",
		"  h = clamp((P.y - ground) / height, 0, 1); b = 0.35 + 0.6 sin(1.1 t + phase) + 0.3 sin(2.3 t + 1.7 phase);",
		"  P.xz += normalize(%s, %s) b amplitude height 0.05 h^2; then P += N sin(7 t + P.(2.1, 1.7, 2.9)) 0.015 amplitude h."
			% [FE.SENS_DU_VENT.x, FE.SENS_DU_VENT.y],
		"  A height of 0 does not move.",
	])


## LA RÈGLE DES FRANCHISSEURS (`franchisseurs.gd`, 20 octobre 2026) — écrite dans le README, pour les greffons.
static func regle_franchisseurs() -> PackedStringArray:
	return PackedStringArray([
		"crossings (optional) stairs and slopes set OVER the painted world (not in a layer). Absent: none.",
		"  models      an array of {id (an integer, unique), name, kind (\"stairs\" or \"slope\"), width, height, depth",
		"              (integers, in cells: the width of the way up, the height it climbs, the cells of ground it takes in",
		"              front of the wall), mesh (a .glb path RELATIVE to world.json)}. The mesh is in MODEL space, in cells:",
		"              x in [0, width], y in [0, height], z in [-depth, 0] — it climbs toward -z, its foot at z = 0.",
		"  placements  a flat array of integers, 5 per crossing: model id, x, y, z of its FOOT cell (the empty cell on the",
		"              lower ground, the farthest from the wall, on the left going up), quarter (0 to 3): it climbs toward",
		"              (0, 0, -1), (1, 0, 0), (0, 0, 1), (-1, 0, 0) for quarters 0, 1, 2, 3. A placement of an unknown",
		"              model refuses the file.",
		"  In FORMAT space (cell c covers [c, c + 1]) a crossing sits at T = translate(C_world - B C_local) B, with B the",
		"  rotation of -quarter * 90 degrees around +Y, C_local = (width/2, height/2, -depth/2), and C_world = foot +",
		"  (0.5, 0, 0.5) + d (depth - 1)/2 + r (width - 1)/2 + (0, height/2, 0), d the climbing direction, r = (-d.z, 0, d.x).",
		"  Each engine gives it a COLLISION (its mesh's triangles): a character walks up it.",
	])


## Écrit le monde. `couches` : [{nom, visible, source, lot (MeshLibrary ou null), cases (Array de
## Vector3i), hauteurs ({nom de matériau: Texture2D}, le relief, 30 octobre 2026 ; facultatif)}], dans l'ordre. Rend {"dossier", "couches", "jeux", "sans_tuiles": [noms]} ou {"erreur"}.
## `eaux` : [{nom, visible, preset, sources (Array de Vector3i), maillage (ArrayMesh ou null)}], dans l'ordre.
## `transitions` (parité des greffons, 7 octobre 2026) : {"etat": l'état de l'atelier (ids des couches), "ids": l'id de
## chaque couche de `couches`, dans l'ordre, "representants": [{image (Image ou null), couleur, echelle, rugosite}] par
## couche, RÉSOLUS par l'écran} — {} : pas de transitions. `feuillage` : ce que le projet enregistre
## (`FE.vers_donnees` : modèles et plants à plat) — {} : pas de feuillage.
## `retrait_eau` (9 octobre 2026) : le cran du sol que l'eau suppose (`EauMaillage.nappe`) — `water_floor`.
static func exporter(couches: Array, dossier: String, nom: String, generateur: String, eaux: Array = [],
		transitions: Dictionary = {}, feuillage: Dictionary = {}, retrait_eau := 0.25, franchisseurs: Dictionary = {}) -> Dictionary:
	if couches.is_empty():
		return {"erreur": "this world has no layer"}
	var cible := dossier.path_join(_propre(nom, "world") + ".mbworld")
	DirAccess.make_dir_recursive_absolute(cible)
	var jeux := {}          # source → chemin relatif de son tileset.json
	var noms_pris := {}
	var sorties: Array = []
	var sans_tuiles: Array = []
	var images_manquantes: Array = []
	for c in couches:
		var source: String = str(c.get("source", ""))
		var lot = c.get("lot")
		var jeu: Variant = null
		if source != "" and lot is MeshLibrary and not (lot as MeshLibrary).get_item_list().is_empty():
			if not jeux.has(source):
				# Un nom de dossier par source : celui de la première couche qui l'emploie, rendu unique.
				var base := _propre(str(c["nom"]), "tileset")
				var n := base
				var i := 2
				while noms_pris.has(n):
					n = "%s_%d" % [base, i]
					i += 1
				noms_pris[n] = true
				var r: Dictionary = FN.exporter(lot, cible, n, generateur, c.get("hauteurs", {}))
				if r.has("erreur"):
					return {"erreur": "layer « %s »: %s" % [c["nom"], r["erreur"]]}
				images_manquantes.append_array(r.get("images_manquantes", []))
				jeux[source] = (r["dossier"] as String).get_file().path_join("tileset.json")
			jeu = jeux[source]
		else:
			sans_tuiles.append(str(c["nom"]))
		var sortie := {"name": str(c["nom"]), "visible": bool(c.get("visible", true)), "tileset": jeu,
			"cells": cases_a_plat(c.get("cases", []))}
		# LES VARIANTES VOULUES (4 octobre 2026) : les poids du tirage et les choix posés, s'il y en a.
		var poids: Dictionary = c.get("poids", {})
		if not poids.is_empty():
			var p := {}
			for cle in poids:
				p[FN.id_de_cle(cle)] = (poids[cle] as Array).map(func(w): return int(w))
			sortie["variant_weights"] = p
		var choix: Dictionary = c.get("choix", {})
		if not choix.is_empty():
			var sommets: Array = choix.keys()
			sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
				return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
			var plat: Array = []
			for s in sommets:
				plat.append_array([s.x, s.y, s.z, int(choix[s])])
			sortie["variant_choices"] = plat
		sorties.append(sortie)
	var sorties_eau: Array = []
	var noms_eau := {}
	for e in eaux:
		var maillage: Variant = null
		if e.get("maillage") is ArrayMesh:
			var base := _propre(str(e["nom"]), "water")
			var n := base
			var i := 2
			while noms_eau.has(n):
				n = "%s_%d" % [base, i]
				i += 1
			noms_eau[n] = true
			DirAccess.make_dir_recursive_absolute(cible.path_join("water"))
			var aspect: String = ASPECTS.get(str(e.get("preset", "")), "stylized")
			var raison := _ecrire_la_nappe(e["maillage"], cible.path_join("water").path_join(n + ".glb"), n, aspect)
			if raison != "":
				return {"erreur": "water « %s »: %s" % [e["nom"], raison]}
			maillage = "water/%s.glb" % n
		sorties_eau.append({"name": str(e["nom"]), "visible": bool(e.get("visible", true)),
			"look": ASPECTS.get(str(e.get("preset", "")), "stylized"), "mesh": maillage,
			"sources": _sources_a_plat(e.get("sources", []))})
	var monde := {"format": FORMAT, "version": VERSION, "generator": generateur, "name": _propre(nom, "world"),
		"layers": sorties, "water": sorties_eau, "water_floor": retrait_eau}
	# LES TRANSITIONS (l'atelier Transitions) : les ids de l'écran deviennent des INDICES de `layers`, les représentants
	# partent RÉSOLUS (le défaut « le matériau le plus porté » demande le témoin, qu'un greffon n'a pas), leurs images
	# recopiées dans `transitions/`.
	var tr_bilan := {}
	if not transitions.is_empty():
		var t := transitions_pour_le_monde(transitions.get("etat", {}), transitions.get("ids", []),
			transitions.get("representants", []))
		if not t.is_empty():
			for rel in t["images"]:
				DirAccess.make_dir_recursive_absolute(cible.path_join(str(rel).get_base_dir()))
				var img: Image = t["images"][rel]
				if img.save_png(cible.path_join(rel)) != OK:
					return {"erreur": "the transition image %s could not be written" % rel}
			monde["transitions"] = t["json"]
			tr_bilan = {"paires": (t["json"]["pairs"] as Array).size(), "choix": (t["json"]["choices"] as Array).size() / 4}
	# LE FEUILLAGE (l'atelier Foliage) : chaque modèle COPIÉ dans `foliage/` (comme un jeu de tuiles), ses réglages et
	# ses plants en anglais. Un modèle introuvable part sans maillage (`mesh` null), et c'est DIT.
	var fe_bilan := {}
	if not feuillage.is_empty() and not (feuillage.get("modeles", []) as Array).is_empty():
		var fe := _feuillage_pour_le_monde(feuillage, cible)
		if fe.has("erreur"):
			return {"erreur": fe["erreur"]}
		monde["foliage"] = fe["json"]
		fe_bilan = {"modeles": (fe["json"]["models"] as Array).size(), "plants": (fe["json"]["plants"] as Array).size() / 7,
			"sans_maillage": fe["sans_maillage"]}
	# LES FRANCHISSEURS (l'atelier Crossings) : le maillage SCULPTÉ de chaque modèle écrit en `.glb` dans `crossings/`, leurs
	# dimensions et leurs poses en anglais.
	var fr_bilan := {}
	if not franchisseurs.is_empty() and not (franchisseurs.get("modeles", []) as Array).is_empty():
		var fr := _franchisseurs_pour_le_monde(franchisseurs, cible, franchisseurs.get("materiaux", {}))
		if fr.has("erreur"):
			return {"erreur": fr["erreur"]}
		monde["crossings"] = fr["json"]
		fr_bilan = {"modeles": (fr["json"]["models"] as Array).size(),
			"poses": (fr["json"]["placements"] as Array).size() / 5}
	var f := FileAccess.open(cible.path_join("world.json"), FileAccess.WRITE)
	if f == null:
		return {"erreur": "world.json could not be written (error %d)" % FileAccess.get_open_error()}
	f.store_string(JSON.stringify(monde, "  "))
	f.close()
	var r2 := FileAccess.open(cible.path_join("README.txt"), FileAccess.WRITE)
	if r2 != null:
		r2.store_string("\n".join(regle()) + "\n\n" + "\n".join(regle_eau()) + "\n\n" + "\n".join(regle_transitions())
			+ "\n\n" + "\n".join(regle_feuillage()) + "\n\n" + "\n".join(regle_franchisseurs()) + "\n\nMade with %s. Open it with the free MarchingBlocks Paint "
			% generateur + "plugin for Godot, Unity or Unreal: Import MarchingBlocks world.\n")
		r2.close()
	return {"dossier": cible, "couches": sorties.size(), "jeux": jeux.size(), "sans_tuiles": sans_tuiles,
		"eaux": sorties_eau.size(), "nappes": noms_eau.size(), "transitions": tr_bilan, "feuillage": fe_bilan,
		"franchisseurs": fr_bilan, "images_manquantes": images_manquantes}


## Les franchisseurs du projet (`FR.vers_donnees`) pour le monde : {"json", } ou {"erreur"}. Un `.glb` par modèle, son
## maillage sculpté (ou la forme de départ s'il n'en a pas).
## `materiaux` : {id de modèle: le dictionnaire du matériau de sa couche (celui d'un témoin)} — son maillage le porte sur
## toutes ses faces, projeté en boîte comme les tuiles. Absent : la teinte de la légende.
static func _franchisseurs_pour_le_monde(d: Dictionary, cible: String, materiaux := {}) -> Dictionary:
	var FR := load("res://addons/marchingblocks_core/franchisseurs.gd")
	var ME := load("res://addons/marchingblocks_core/maillage_edite.gd")
	DirAccess.make_dir_recursive_absolute(cible.path_join("crossings"))
	var models: Array = []
	var pris := {}
	for m in d["modeles"]:
		var me: RefCounted = ME.depuis_dictionnaire(m["maillage"]) if (m.get("maillage", {}) as Dictionary).size() > 0 else null
		if me == null:
			me = FR.maillage_de_depart(m)
		var mat = materiaux.get(int(m["id"]), materiaux.get(str(int(m["id"])), null))
		if mat is Dictionary and not (mat as Dictionary).is_empty():
			me.materiaux = [(mat as Dictionary).duplicate(true)]
			for i in me.mats.size():
				me.mats[i] = 0
		var base := _propre(str(m["nom"]), "crossing")
		var nom := base
		var k := 2
		while pris.has(nom):
			nom = "%s_%d" % [base, k]
			k += 1
		pris[nom] = true
		var rel := "crossings/%s.glb" % nom
		var racine := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.name = nom
		mi.mesh = me.vers_array_mesh(true)
		racine.add_child(mi)
		var doc := GLTFDocument.new()
		var etat := GLTFState.new()
		var err := doc.append_from_scene(racine, etat)
		if err == OK:
			err = doc.write_to_filesystem(etat, cible.path_join(rel))
		racine.free()
		if err != OK:
			return {"erreur": "the crossing %s could not be written (error %d)" % [rel, err]}
		models.append({"id": int(m["id"]), "name": str(m["nom"]), "kind": "slope" if m["genre"] == "pente" else "stairs",
			"width": int(m["largeur"]), "height": int(m["hauteur"]), "depth": int(m["longueur"]), "mesh": rel})
	return {"json": {"models": models, "placements": (d.get("poses", []) as Array).duplicate()}}


## LES TRANSITIONS TELLES QUE `world.json` LES PORTE (`regle_transitions`). `etat` : {paires: {"idA|idB": {actif, couvre:
## {id: réglages}}}, choix: {sommet: id}} ; `ids` : l'id de chaque couche, dans l'ordre de `layers` ; `representants` :
## [{image, couleur, echelle, rugosite}] par couche. Rend {"json", "images": {chemin relatif: Image}}, ou {} s'il n'y a ni
## paire ni choix. Une paire ou un choix d'une couche qui n'existe plus est laissé de côté.
static func transitions_pour_le_monde(etat: Dictionary, ids: Array, representants: Array) -> Dictionary:
	var indice := {}
	for i in ids.size():
		indice[str(ids[i])] = i
	var paires: Array = []
	var p_etat: Dictionary = etat.get("paires", {})
	for cle in p_etat:
		var ab: PackedStringArray = String(cle).split("|")
		if ab.size() != 2 or not indice.has(ab[0]) or not indice.has(ab[1]) or ab[0] == ab[1]:
			continue
		var ia: int = indice[ab[0]]
		var ib: int = indice[ab[1]]
		var id_a: String = ab[0]
		var id_b: String = ab[1]
		if ia > ib:
			var t := ia
			ia = ib
			ib = t
			id_a = ab[1]
			id_b = ab[0]
		var couvre: Dictionary = p_etat[cle].get("couvre", {})
		paires.append({"a": ia, "b": ib, "active": bool(p_etat[cle].get("actif", false)),
			"a_covers_b": TR.reglages_en(couvre.get(id_a, {})), "b_covers_a": TR.reglages_en(couvre.get(id_b, {}))})
	paires.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return x["a"] < y["a"] or (x["a"] == y["a"] and x["b"] < y["b"]))
	var c_etat: Dictionary = etat.get("choix", {})
	var sommets: Array = c_etat.keys().filter(func(s): return indice.has(str(c_etat[s])))
	sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	var plat: Array = []
	for s: Vector3i in sommets:
		plat.append_array([s.x, s.y, s.z, int(indice[str(c_etat[s])])])
	if paires.is_empty() and plat.is_empty():
		return {}
	var reps: Array = []
	var images := {}
	for i in ids.size():
		var r: Dictionary = representants[i] if i < representants.size() and representants[i] is Dictionary else {}
		var chemin: Variant = null
		if r.get("image") is Image:
			var img: Image = (r["image"] as Image).duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			chemin = "transitions/representative_%d.png" % i
			images[chemin] = img
		var c: Color = r.get("couleur", Color.WHITE)
		reps.append({"image": chemin, "color": [c.r, c.g, c.b, c.a], "scale": maxf(float(r.get("echelle", 1.0)), 0.01),
			"roughness": float(r.get("rugosite", 0.8))})
	return {"json": {"pairs": paires, "representatives": reps, "choices": plat}, "images": images}


## LE FEUILLAGE tel que `world.json` le porte (`regle_feuillage`) : les modèles copiés dans `<monde>/foliage/`. `d` : ce
## que le projet enregistre (`FE.vers_donnees`). Rend {"json", "sans_maillage": [noms]} ou {"erreur"}.
static func _feuillage_pour_le_monde(d: Dictionary, cible: String) -> Dictionary:
	var erreurs: Array = []
	var lu := FE.depuis_donnees(d, erreurs)
	if lu.is_empty():
		return {"erreur": "foliage: %s" % ", ".join(PackedStringArray(erreurs))}
	var modeles: Array = []
	var pris := {}
	var copies := {}
	var sans_maillage: Array = []
	for m in lu["modeles"]:
		var chemin := str(m["chemin"])
		var mesh: Variant = null
		if copies.has(chemin):
			mesh = copies[chemin]
		elif chemin != "" and FileAccess.file_exists(chemin):
			var base := _propre(chemin.get_file().get_basename(), "model")
			var n := base
			var i := 2
			while pris.has(n):
				n = "%s_%d" % [base, i]
				i += 1
			pris[n] = true
			DirAccess.make_dir_recursive_absolute(cible.path_join("foliage"))
			if DirAccess.copy_absolute(chemin, cible.path_join("foliage").path_join(n + ".glb")) != OK:
				return {"erreur": "foliage: the model %s could not be copied" % chemin.get_file()}
			mesh = "foliage/%s.glb" % n
			copies[chemin] = mesh
		else:
			sans_maillage.append(str(m["nom"]))
		modeles.append({"id": int(m["id"]), "name": str(m["nom"]), "mesh": mesh,
			"ground_offset": float(m["decalage"]), "scale": float(m["echelle"]), "scale_random": float(m["echelle_alea"]),
			"footprint": float(m["rayon"]), "height": float(m["hauteur"]), "wind": float(m["vent"])})
	var plats: Array = (FE.vers_donnees(lu["modeles"], lu["plants"]) as Dictionary)["plants"]
	return {"json": {"models": modeles, "plants": plats}, "sans_maillage": sans_maillage}


## Les sources d'une couche d'eau, à plat, DANS L'ORDRE (une source n'est pas une case : l'ordre est celui où
## elles ont été posées, et il dit quelle rivière est laquelle).
static func _sources_a_plat(sources: Array) -> Array:
	var plat: Array = []
	for s in sources:
		var v: Vector3i = s
		plat.append_array([v.x, v.y, v.z])
	return plat


## Écrit une nappe en .glb : UN nœud, UN maillage nommés `nom` (⚠ l'importeur d'Unreal fait un StaticMesh par
## MAILLAGE : sans nom, il arriverait anonyme — charte §4), un matériau nommé `mb_water_<aspect>` que le greffon
## remplace. ⚠ On écrit une COPIE du maillage : celui de la vue garde son shader.
static func _ecrire_la_nappe(maillage: ArrayMesh, chemin: String, nom: String, aspect: String) -> String:
	var copie := maillage.duplicate() as ArrayMesh
	var mat := StandardMaterial3D.new()
	mat.resource_name = "mb_water_" + aspect
	mat.albedo_color = Color(0.2, 0.5, 0.75, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	copie.surface_set_material(0, mat)
	var racine := Node3D.new()
	racine.name = "world_water"
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = copie
	racine.add_child(mi)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var e := doc.append_from_scene(racine, etat)
	if e == OK:
		for m in etat.get_meshes():
			(m as GLTFMesh).resource_name = nom
		e = doc.write_to_filesystem(etat, chemin)
	racine.free()
	return "" if e == OK else "the water mesh could not be written (error %d)" % e


## Les cases, triées (y, puis z, puis x), à plat par triplets.
static func cases_a_plat(cases: Array) -> Array:
	var triees := cases.duplicate()
	triees.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var plat: Array = []
	var vues := {}
	for c in triees:
		if vues.has(c):
			continue
		vues[c] = true
		plat.append_array([c.x, c.y, c.z])
	return plat


static func _propre(nom: String, defaut: String) -> String:
	var n := ""
	for ch in nom.to_lower().strip_edges():
		n += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-" else "_"
	return n if n != "" else defaut


# ── LA LECTURE DE RÉFÉRENCE ET SES CAS D'ÉPREUVE ─────────────────────────────────────────────────────
#
# ⚠ Trois greffons liront `world.json` : la règle ci-dessus est exécutée ICI une fois, et ses réponses
# partent en `world_conformance.json` avec chacun (même parade que pour la pose et les outils, §4). Les
# cas exercent ce qu'ils nomment : coordonnées négatives, couche sans tuiles, couche cachée, et chaque
# refus.

## Lit un monde déjà décodé du JSON. Rend {"layers": [{name, visible, tileset, cells: [[x,y,z]…]}]} ou
## {"error": raison}.
static func lire(monde: Variant) -> Dictionary:
	if not monde is Dictionary or str((monde as Dictionary).get("format", "")) != FORMAT:
		return {"error": "not a MarchingBlocks world"}
	var v = monde.get("version")
	if not (v is float or v is int) or int(v) != v or int(v) < 1:
		return {"error": "no valid version"}
	if int(v) > VERSION:
		return {"error": "world format version %d is newer than this plugin (%d)" % [int(v), VERSION]}
	var couches = monde.get("layers")
	if not couches is Array:
		return {"error": "layers is not an array"}
	var sortie: Array = []
	for c in couches:
		if not c is Dictionary or not c.get("name") is String or not c.get("visible") is bool:
			return {"error": "a layer has no name or no visibility"}
		var jeu = c.get("tileset")
		if jeu != null and not jeu is String:
			return {"error": "layer « %s »: tileset is neither a path nor null" % c["name"]}
		var plat = c.get("cells")
		if not plat is Array or (plat as Array).size() % 3 != 0:
			return {"error": "layer « %s »: cells is not a list of x y z triples" % c["name"]}
		var cases: Array = []
		var vues := {}
		for i in range(0, plat.size(), 3):
			var t: Array = [plat[i], plat[i + 1], plat[i + 2]]
			for n in t:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "layer « %s »: a cell coordinate is not an integer" % c["name"]}
			var cle := Vector3i(int(t[0]), int(t[1]), int(t[2]))
			if vues.has(cle):
				return {"error": "layer « %s »: the cell %s appears twice" % [c["name"], cle]}
			vues[cle] = true
			cases.append([cle.x, cle.y, cle.z])
		# Les variantes (5 octobre 2026, dans les greffons) : les poids tels quels, les choix [x, y, z, c] triés par sommet.
		var var_lues := lire_variantes(c)
		if var_lues.has("error"):
			return var_lues
		var choix: Dictionary = var_lues["choices"]
		var sommets: Array = choix.keys()
		sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
		var choix_lus: Array = []
		for s in sommets:
			choix_lus.append([s.x, s.y, s.z, int(choix[s])])
		sortie.append({"name": c["name"], "visible": c["visible"], "tileset": jeu, "cells": cases,
			"variant_weights": var_lues["weights"], "variant_choices": choix_lus})
	return {"layers": sortie}


## Lit les variantes d'une couche de `world.json` : {"weights": {clé: [w]}, "choices": {Vector3i: c}} ou {"error"}.
static func lire_variantes(couche: Variant) -> Dictionary:
	if not couche is Dictionary:
		return {"error": "a layer is not an object"}
	var nom := str((couche as Dictionary).get("name", "?"))
	var w = couche.get("variant_weights", {})
	if not w is Dictionary:
		return {"error": "layer « %s »: variant_weights is not an object" % nom}
	var poids := {}
	for k in w:
		if not w[k] is Array or (w[k] as Array).any(func(x): return not (x is float or x is int) or int(x) != x):
			return {"error": "layer « %s »: the weights of « %s » are not integers" % [nom, k]}
		poids[str(k)] = (w[k] as Array).map(func(x): return int(x))
	var plat = couche.get("variant_choices", [])
	if not plat is Array or (plat as Array).size() % 4 != 0:
		return {"error": "layer « %s »: variant_choices is not a list of x y z c" % nom}
	var choix := {}
	for i in range(0, plat.size(), 4):
		for n in [plat[i], plat[i + 1], plat[i + 2], plat[i + 3]]:
			if not (n is float or n is int) or int(n) != n:
				return {"error": "layer « %s »: a variant choice is not made of integers" % nom}
		var s := Vector3i(int(plat[i]), int(plat[i + 1]), int(plat[i + 2]))
		if choix.has(s):
			return {"error": "layer « %s »: the vertex %s is chosen twice" % [nom, s]}
		choix[s] = int(plat[i + 3])
	return {"weights": poids, "choices": choix}


## LA LECTURE DE L'EAU, selon `regle_eau()`. Rend {"water": [{name, visible, look, mesh, sources: [[x,y,z]…]}]}
## ou {"error"}. Un monde sans clé `water` n'a pas d'eau. ⚠ Un aspect inconnu est ACCEPTÉ : c'est une suggestion.
static func lire_eau(monde: Variant) -> Dictionary:
	if not monde is Dictionary:
		return {"error": "not a MarchingBlocks world"}
	var liste = (monde as Dictionary).get("water", [])
	if not liste is Array:
		return {"error": "water is not an array"}
	var sortie: Array = []
	for e in liste:
		if not e is Dictionary or not e.get("name") is String or not e.get("visible") is bool \
				or not e.get("look") is String:
			return {"error": "a water layer has no name, visibility or look"}
		var m = e.get("mesh")
		if m != null and not m is String:
			return {"error": "water « %s »: mesh is neither a path nor null" % e["name"]}
		var plat = e.get("sources")
		if not plat is Array or (plat as Array).size() % 3 != 0:
			return {"error": "water « %s »: sources is not a list of x y z triples" % e["name"]}
		var sources: Array = []
		for i in range(0, plat.size(), 3):
			for n in [plat[i], plat[i + 1], plat[i + 2]]:
				if not (n is float or n is int) or int(n) != n:
					return {"error": "water « %s »: a source coordinate is not an integer" % e["name"]}
			sources.append([int(plat[i]), int(plat[i + 1]), int(plat[i + 2])])
		sortie.append({"name": e["name"], "visible": e["visible"], "look": e["look"], "mesh": m, "sources": sources})
	# LE SOL QUE L'EAU SUPPOSE (9 octobre 2026) : un monde d'avant n'en dit rien — il était aminci.
	var sol = (monde as Dictionary).get("water_floor", 0.25)
	if not _nombre(sol) or not float(sol) in [0.25, 0.0, -0.25]:
		return {"error": "water_floor is not 0.25, 0 or -0.25"}
	return {"water": sortie, "floor": float(sol)}


static func _entier(x: Variant) -> bool:
	return (x is float or x is int) and int(x) == x


static func _nombre(x: Variant) -> bool:
	return x is float or x is int


## LA LECTURE DES TRANSITIONS, selon `regle_transitions()` (parité des greffons, 7 octobre 2026). Rend {"transitions":
## {pairs, representatives, choices: [[x, y, z, L]…] triés}} — normalisées : réglages complets et bornés — ou {"error"}.
## Un monde sans la clé n'a pas de transitions (tout vide).
static func lire_transitions(monde: Variant) -> Dictionary:
	if not monde is Dictionary:
		return {"error": "not a MarchingBlocks world"}
	var n_couches: int = (monde.get("layers", []) as Array).size() if monde.get("layers") is Array else 0
	var t: Variant = (monde as Dictionary).get("transitions")
	if t == null:
		return {"transitions": {"pairs": [], "representatives": [], "choices": []}}
	if not t is Dictionary:
		return {"error": "transitions is not an object"}
	var paires: Variant = t.get("pairs", [])
	if not paires is Array:
		return {"error": "transitions: pairs is not an array"}
	var sortie_p: Array = []
	var vues := {}
	for p in paires:
		if not p is Dictionary or not _entier(p.get("a")) or not _entier(p.get("b")) or not p.get("active") is bool:
			return {"error": "transitions: a pair has no layers a, b or no active"}
		var a := int(p["a"])
		var b := int(p["b"])
		if a < 0 or b >= n_couches or a >= b:
			return {"error": "transitions: the pair %d, %d is not two layers a < b" % [a, b]}
		if vues.has(Vector2i(a, b)):
			return {"error": "transitions: the pair %d, %d appears twice" % [a, b]}
		vues[Vector2i(a, b)] = true
		var dirs := {}
		for k in ["a_covers_b", "b_covers_a"]:
			var r: Variant = p.get(k)
			if not r is Dictionary:
				return {"error": "transitions: the pair %d, %d has no %s" % [a, b, k]}
			for nom in r:
				if not _nombre(r[nom]):
					return {"error": "transitions: the setting %s of the pair %d, %d is not a number" % [nom, a, b]}
			dirs[k] = TR.reglages_en(TR.reglages_depuis_en(r))
		sortie_p.append({"a": a, "b": b, "active": p["active"], "a_covers_b": dirs["a_covers_b"],
			"b_covers_a": dirs["b_covers_a"]})
	var reps: Variant = t.get("representatives")
	if not reps is Array or (reps as Array).size() != n_couches:
		return {"error": "transitions: representatives is not one per layer"}
	var sortie_r: Array = []
	for r in reps:
		if not r is Dictionary or not (r.get("image") == null or r.get("image") is String):
			return {"error": "transitions: a representative's image is neither a path nor null"}
		var c: Variant = r.get("color")
		if not c is Array or (c as Array).size() != 4 or (c as Array).any(func(x): return not _nombre(x)):
			return {"error": "transitions: a representative's color is not four numbers"}
		if not _nombre(r.get("scale")) or not _nombre(r.get("roughness")):
			return {"error": "transitions: a representative's scale or roughness is not a number"}
		sortie_r.append({"image": r["image"], "color": (c as Array).map(func(x): return float(x)),
			"scale": maxf(float(r["scale"]), 0.01), "roughness": clampf(float(r["roughness"]), 0.0, 1.0)})
	var plat: Variant = t.get("choices", [])
	if not plat is Array or (plat as Array).size() % 4 != 0:
		return {"error": "transitions: choices is not a list of x y z L"}
	var choix := {}
	for i in range(0, plat.size(), 4):
		for x in [plat[i], plat[i + 1], plat[i + 2], plat[i + 3]]:
			if not _entier(x):
				return {"error": "transitions: a choice is not made of integers"}
		var s := Vector3i(int(plat[i]), int(plat[i + 1]), int(plat[i + 2]))
		if choix.has(s):
			return {"error": "transitions: the vertex %s is chosen twice" % s}
		if int(plat[i + 3]) < 0 or int(plat[i + 3]) >= n_couches:
			return {"error": "transitions: a choice names layer %d, which does not exist" % int(plat[i + 3])}
		choix[s] = int(plat[i + 3])
	var sommets: Array = choix.keys()
	sommets.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z))))
	var sortie_c: Array = []
	for s: Vector3i in sommets:
		sortie_c.append([s.x, s.y, s.z, choix[s]])
	return {"transitions": {"pairs": sortie_p, "representatives": sortie_r, "choices": sortie_c}}


## LA LECTURE DU FEUILLAGE, selon `regle_feuillage()` — la règle du projet (`FE.depuis_donnees`) sous les noms anglais,
## plus le chemin du maillage. Rend {"foliage": {models: [...], plants: [[id, x, y, z, lacet, échelle, mode 0 / 1]…]}} ou
## {"error"}. Un monde sans la clé n'a pas de feuillage.
const _MODELE_EN := {"decalage": "ground_offset", "echelle": "scale", "echelle_alea": "scale_random", "rayon": "footprint",
	"hauteur": "height", "vent": "wind"}


static func lire_feuillage(monde: Variant) -> Dictionary:
	if not monde is Dictionary:
		return {"error": "not a MarchingBlocks world"}
	var d: Variant = (monde as Dictionary).get("foliage")
	if d == null:
		return {"foliage": {"models": [], "plants": []}}
	if not d is Dictionary:
		return {"error": "foliage is not an object"}
	var liste: Variant = d.get("models", [])
	if not liste is Array:
		return {"error": "foliage: models is not an array"}
	var ms: Array = []
	for m in liste:
		if not m is Dictionary:
			return {"error": "foliage: a model is not an object"}
		if not _entier(m.get("id")):
			return {"error": "foliage: a model has no integer id"}
		if m.has("name") and not m["name"] is String:
			return {"error": "foliage: a model's name is not a string"}
		if not (m.get("mesh") == null or m.get("mesh") is String):
			return {"error": "foliage: a model's mesh is neither a path nor null"}
		var fr := {"id": m["id"], "chemin": m.get("mesh") if m.get("mesh") != null else ""}
		if m.has("name"):
			fr["nom"] = m["name"]
		for k in _MODELE_EN:
			if m.has(_MODELE_EN[k]):
				fr[k] = m[_MODELE_EN[k]]
		ms.append(fr)
	var erreurs: Array = []
	var lu := FE.depuis_donnees({"modeles": ms, "plants": d.get("plants", [])}, erreurs)
	if lu.is_empty():
		return {"error": "foliage: %s" % ", ".join(PackedStringArray(erreurs))}
	var modeles: Array = []
	for i in (lu["modeles"] as Array).size():
		var m: Dictionary = lu["modeles"][i]
		modeles.append({"id": int(m["id"]), "name": str(m["nom"]), "mesh": liste[i].get("mesh"),
			"ground_offset": m["decalage"], "scale": m["echelle"], "scale_random": m["echelle_alea"],
			"footprint": m["rayon"], "height": m["hauteur"], "wind": m["vent"]})
	var plants: Array = []
	var plat: Array = d.get("plants", [])
	for k in range(0, plat.size(), 7):
		plants.append([int(plat[k]), float(plat[k + 1]), float(plat[k + 2]), float(plat[k + 3]), float(plat[k + 4]),
			float(plat[k + 5]), 0 if int(plat[k + 6]) == 0 else 1])
	return {"foliage": {"models": modeles, "plants": plants}}


static func cas_d_epreuve() -> Dictionary:
	var bon := {"format": FORMAT, "version": VERSION, "generator": "conformance", "name": "sample",
		"layers": [
			{"name": "Rock", "visible": true, "tileset": "rock.mbset/tileset.json",
				"cells": cases_a_plat([Vector3i(0, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, -3),
					Vector3i(-7, -2, 5)])},
			{"name": "Ice", "visible": false, "tileset": null, "cells": cases_a_plat([Vector3i(2, 0, 2)])},
			{"name": "Empty", "visible": true, "tileset": "rock.mbset/tileset.json", "cells": []},
			{"name": "Varied", "visible": true, "tileset": "rock.mbset/tileset.json", "cells": cases_a_plat([Vector3i(4, 0, 4)]),
				"variant_weights": {"slab_b2h2": [2, 1, 0], "slab_b2h2_outdoor": [-1, 3]},
				"variant_choices": [5, 0, 5, 1, -3, -1, 2, 0, 0, 0, 0, 2]},
		]}
	var cas: Array = [{"name": "two layers, negative cells, a hidden layer without tiles, an empty layer",
		"world": bon}]
	var mauvais := {
		"newer version": {"version": VERSION + 1},
		"wrong format": {"format": "marchingblocks-tileset"},
		"no version": {"version": null},
		"cells not in triples": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [0, 0]}]},
		"a cell twice": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [1, 2, 3, 1, 2, 3]}]},
		"a fractional cell": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [0, 0.5, 0]}]},
		"tileset neither path nor null": {"layers": [{"name": "A", "visible": true, "tileset": 3, "cells": []}]},
		"layer without visibility": {"layers": [{"name": "A", "tileset": null, "cells": []}]},
		"variant choices not in fours": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [],
			"variant_choices": [0, 0, 0]}]},
		"a vertex chosen twice": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [],
			"variant_choices": [1, 2, 3, 1, 1, 2, 3, 0]}]},
		"a fractional variant choice": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [],
			"variant_choices": [1, 2, 3, 0.5]}]},
		"variant weights not an object": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [],
			"variant_weights": [1, 2]}]},
		"a fractional variant weight": {"layers": [{"name": "A", "visible": true, "tileset": null, "cells": [],
			"variant_weights": {"slab_b2h2": [1, 1.5]}}]},
	}
	for nom in mauvais:
		var m: Dictionary = bon.duplicate(true)
		m.merge(mauvais[nom], true)
		cas.append({"name": nom, "world": m})
	# L'attendu de chaque cas est la lecture de référence ; un refus s'écrit {"error": true} — la RAISON
	# n'est pas imposée aux greffons, seulement le refus.
	var ecrits: Array = []
	for c in cas:
		var lu := lire(JSON.parse_string(JSON.stringify(c["world"])))
		ecrits.append({"name": c["name"], "world": c["world"],
			"expected": {"error": true} if lu.has("error") else lu})
	return {"format": FORMAT_EPREUVE, "version": VERSION, "rule": Array(regle()), "cases": ecrits}
