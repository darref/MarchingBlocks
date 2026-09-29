extends RefCounted
##
## LE FAUX TRAVAIL D'ARTISTE — ce qu'un artiste renverrait, fabriqué pour éprouver le retour sans lui.
##
## ⚠ **CE N'EST PAS DE L'ART, C'EST UN BANC D'ESSAI.** Il exerce ce que le témoin calculé n'exerce jamais :
##   • du RELIEF qui déplace les sommets hors des plans de sous-voxels — donc des triangles À CHEVAL sur
##     les plans de coupe, que la découpe doit vraiment couper (le témoin n'en a aucun) ;
##   • un LISERÉ D'HERBE qui DÉPASSE du volume lisse : une frange fine au bord des sols qui surplombent un
##     vide, qui sort de sa case et longe les plans de coupe (Jordan, 29 septembre 2026 : « monolithique »
##     ne doit pas interdire les dépassements de faces) ;
##   • la frange SOUDÉE au volume, dans le même objet : c'est le cas général que Jordan a nommé — tout
##     dépassement de faces rattaché au volume et fusionné, qui rend le volume NON LISSE (ni fermé, ni
##     manifold). Le liseré n'est qu'un exemple. Avec `separe`, il part dans un SECOND objet, placé AVANT
##     le terrain — comme un artiste qui range son herbe à part ;
##   • une TEXTURE peinte sur les UV canoniques, avec ou sans la discipline des coupes (charte §3).
##
## ⚠ **LE RELIEF EST ÉQUIVARIANT, ET C'EST CE QUI EN FAIT UN ARTISTE « DISCIPLINÉ ».** Le déplacement est
## le gradient d'un champ φ périodique (période 1 case) et invariant par les quarts de tour autour des
## sommets du réseau : deux pièces de même classe reçoivent donc le même relief, et le contrat de couture
## tient. Le mode `maladroit` prend un champ QUELCONQUE — c'est le contrôle négatif : la couture DOIT
## alors le dire.
## ⚠ La texture se peint à partir de la position 3D d'ORIGINE (celle que les UV canoniques ont lue), comme
## un artiste peint son modèle déplié avant de le sculpter : les UV collent aux sommets qu'on déplace.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

## Le relief : l'amplitude du gradient. ⚠ Mesurée plutôt que choisie : le plus grand déplacement est
## rendu par `fabriquer()` et affiché par le test.
const AMPLITUDE := 0.004
## La frange : jusqu'où elle sort de la falaise, et de combien elle retombe à son bout.
## ⚠ 0,6 case depuis une paroi rentrée d'un quart (x + 0,75) : elle SORT DE SA CASE (jusqu'à x + 1,35) sans
## atteindre le plan de coupe suivant (x + 1,5), au-delà duquel le germe est vide.
const FRANGE_LARGEUR := 0.6
## ⚠ 0,05 ET NON 0,15 : partie d'un dessus rentré (y + 0,75), une frange qui retombe de 0,15 plus le relief
## (≤ 0,084) frôlait ou franchissait le plan de coupe HORIZONTAL (y + 0,5) — que la tuile du dessous ne peut
## pas porter, ses huit cases ne disant pas s'il y a une frange. Mesuré : 221 remarques de couture.
const FRANGE_TOMBE := 0.05
## La bande, autour de chaque plan de coupe, que la discipline peint d'une matière COMMUNE.
const BANDE := 0.2
## La matière commune des coupes.
const BASE := Color(0.46, 0.44, 0.40)
## Pixels par tuile d'atlas.
const TEXELS := 32


## φ — le champ dont le relief est le gradient.
## ⚠ Invariant par les quarts de tour autour de +Y passant par un sommet (entier) et par translation
## d'une case : on SYMÉTRISE un motif quelconque sur ses quatre quarts de tour. Aucune symétrie de miroir :
## le relief traverse les plans de coupe au lieu de s'y arrêter.
static func _phi(p: Vector3) -> float:
	var somme := 0.0
	var x := p.x
	var z := p.z
	for _k in 4:
		somme += sin(TAU * x + 0.7) * cos(TAU * z + 0.3) + 0.5 * sin(TAU * (x + z) + 1.1)
		var t := x
		x = z
		z = -t
	return somme * cos(TAU * p.y + 0.9)


## Le champ d'un artiste qui n'a pas lu la règle : ni périodique, ni symétrique.
static func _phi_maladroit(p: Vector3) -> float:
	return 6.0 * sin(1.3 * p.x + 0.5 * p.z + 0.2) * cos(0.9 * p.y + 0.4) + 3.0 * sin(0.7 * p.z - 1.9 * p.x)


static func deplacement(p: Vector3, maladroit := false) -> Vector3:
	var e := 0.001
	var g := Vector3.ZERO
	for axe in 3:
		var d := Vector3.ZERO
		d[axe] = e
		if maladroit:
			g[axe] = (_phi_maladroit(p + d) - _phi_maladroit(p - d)) / (2.0 * e)
		else:
			g[axe] = (_phi(p + d) - _phi(p - d)) / (2.0 * e)
	return g * AMPLITUDE


## Les triangles de la FRANGE, aux positions d'ORIGINE (avant relief), dans l'ordre HORAIRE de Godot.
## Une frange le long de chaque arête haute d'une case pleine dont le dessus, le côté et le dessus du côté
## sont vides : le bord d'un sol qui surplombe un vide. ⚠ Double face — dessus et dessous sur les mêmes
## sommets —, comme une carte d'herbe : elle n'est pas fermée, et c'est voulu.
##
## ⚠ **LA RÈGLE NE LIT QUE LES CASES QUE VOIENT LES PIÈCES QU'ELLE TRAVERSE — ET LA PREMIÈRE VERSION NE
## LE FAISAIT PAS (29 septembre 2026).** Elle ne posait la frange que sous un ciel OUVERT et au-dessus
## d'une chute de deux sous-voxels, et la faisait large de 0,8 : deux exemplaires d'une même clé en
## recevaient une ou pas, et sa pointe franchissait le plan de coupe suivant pour entrer dans une région
## dont le germe est VIDE — une tuile qui n'existe pas. `verifier_couture` a rendu 579 remarques, et elles
## étaient JUSTES. C'est la règle que ce faux enseigne : **un dépassement peut sortir de sa case, mais ce
## qui franchit une coupe doit ne dépendre que du germe de cette face.** `largeur` > 0,75 la viole exprès.
## ⚠ Coupée au milieu de l'arête (le plan de coupe qu'elle longe) : chaque moitié garde les UV de SA pièce,
## sans quoi l'UV canonique d'un triangle à cheval serait rabattue au bord du carré.
static func triangles_de_la_frange(largeur := FRANGE_LARGEUR) -> PackedVector3Array:
	var pleines: Dictionary = BM.cases(0)
	var r := 0.25   # le retrait de l'aminci
	var sortie := PackedVector3Array()
	for cle in pleines:
		var c: Vector3i = cle
		if pleines.has(c + Vector3i.UP):
			continue
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if pleines.has(c + d) or pleines.has(c + d + Vector3i.UP):
				continue
			var axe: int = 0 if d.x != 0 else 2
			var autre: int = 2 if axe == 0 else 0
			var unite := Vector3i.ZERO
			unite[autre] = 1
			var bas: float = c[autre] + (r if not pleines.has(c - unite) else 0.0)
			var haut: float = c[autre] + 1.0 - (r if not pleines.has(c + unite) else 0.0)
			var milieu: float = c[autre] + 0.5
			for troncon in [[bas, milieu], [milieu, haut]]:
				var a := Vector3.ZERO
				a.y = c.y + 1.0 - r
				a[axe] = c[axe] + (1.0 - r if d[axe] > 0 else r)
				a[autre] = troncon[0]
				var b := a
				b[autre] = troncon[1]
				var dehors: Vector3 = Vector3(d) * largeur + Vector3.DOWN * FRANGE_TOMBE
				var quad: Array = [a, b, b + dehors, a + dehors]
				for sens in [1.0, -1.0]:
					var ordre: Array = quad
					var normale: Vector3 = Vector3.UP * float(sens)
					if (quad[1] - quad[0]).cross(quad[2] - quad[0]).dot(normale) > 0.0:
						ordre = [quad[3], quad[2], quad[1], quad[0]]
					for k in [0, 1, 2, 0, 2, 3]:
						sortie.append(ordre[k])
	return sortie


## LA TEXTURE, peinte dans l'atlas du témoin par ce que chaque texel représente en 3D.
## `discipline` : la bande autour des coupes prend la matière commune ; sinon, tout porte la teinte de sa clé.
## ⚠ Elle ne recopie PAS la disposition de l'atlas : elle rastérise les triangles dans leurs UV
## et demande au MODÈLE la clé de chacun (`Tranchage.cle_du_sommet`).
static func texture(triangles: PackedVector3Array, uv: PackedVector2Array, discipline: bool) -> Image:
	var atlas: Dictionary = BM.atlas_du_temoin(0)
	var cote: int = int(atlas["n"]) * TEXELS
	var image := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	image.fill(BASE)
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	var teintes := {}
	for t in range(0, triangles.size() - 2, 3):
		var a: Vector3 = triangles[t]
		var b: Vector3 = triangles[t + 1]
		var c: Vector3 = triangles[t + 2]
		var centre: Vector3 = (a + b + c) / 3.0
		var v := Vector3i(floori(centre.x - 0.5), floori(centre.y - 0.5), floori(centre.z - 0.5))
		var r: Dictionary = Tranchage.cle_du_sommet(pleines, v, plafond)
		var cle: String = r.get("cle", "")
		if not teintes.has(cle):
			teintes[cle] = Color.from_hsv(fposmod(teintes.size() * 0.618034, 1.0), 0.65, 0.85)
		var teinte: Color = teintes[cle]
		var normale: Vector3 = -(b - a).cross(c - a)
		var axe_n: int = 0
		for j in 3:
			if absf(normale[j]) > absf(normale[axe_n]):
				axe_n = j
		var pa: Vector2 = uv[t] * cote
		var pb: Vector2 = uv[t + 1] * cote
		var pc: Vector2 = uv[t + 2] * cote
		var aire: float = (pb - pa).cross(pc - pa)
		if absf(aire) < 0.000001:
			continue
		var mini: Vector2 = pa.min(pb).min(pc).floor()
		var maxi: Vector2 = pa.max(pb).max(pc).ceil()
		for py in range(maxi(0, int(mini.y)), mini(cote, int(maxi.y) + 1)):
			for px in range(maxi(0, int(mini.x)), mini(cote, int(maxi.x) + 1)):
				var q := Vector2(px + 0.5, py + 0.5)
				var wa: float = (pb - q).cross(pc - q) / aire
				var wb: float = (pc - q).cross(pa - q) / aire
				var wc: float = 1.0 - wa - wb
				if wa < -0.02 or wb < -0.02 or wc < -0.02:
					continue
				var p: Vector3 = a * wa + b * wb + c * wc
				var pres := false
				for j in 3:
					if j != axe_n and absf(fposmod(p[j], 1.0) - 0.5) < BANDE:
						pres = true
				image.set_pixel(px, py, BASE if (discipline and pres) else teinte)
	return image


## Un triangle est-il À CHEVAL sur un plan de coupe (x = k + ½) de l'un des `axes` ? Toucher un plan
## n'est pas le traverser : il faut des sommets STRICTEMENT des deux côtés.
static func a_cheval(a: Vector3, b: Vector3, c: Vector3, axes: Array) -> bool:
	for axe in axes:
		var mini: float = minf(minf(a[axe], b[axe]), c[axe])
		var maxi: float = maxf(maxf(a[axe], b[axe]), c[axe])
		if ceilf(mini - 0.5 + 0.0005) <= floorf(maxi - 0.5 - 0.0005):
			return true
	return false


## Un triangle franchit-il une frontière de CASE (x ou z entier) ? C'est « sortir de sa case ».
static func hors_de_sa_case(a: Vector3, b: Vector3, c: Vector3) -> bool:
	for axe in [0, 2]:
		var mini: float = minf(minf(a[axe], b[axe]), c[axe])
		var maxi: float = maxf(maxf(a[axe], b[axe]), c[axe])
		if ceilf(mini + 0.0005) <= floorf(maxi - 0.0005):
			return true
	return false


## FABRIQUE le faux travail dans `chemin` (.glb). Rend {"erreur", "triangles", "a_cheval", "frange",
## "frange_hors_case", "plus_grand_deplacement"} — ce qu'il exerce, MESURÉ sur ce qu'il a écrit.
static func fabriquer(chemin: String, discipline := true, maladroit := false, separe := false,
		largeur := FRANGE_LARGEUR) -> Dictionary:
	var terrain := PackedVector3Array()
	var brut: ArrayMesh = BM.maillage_moitie(0)
	for s in brut.get_surface_count():
		terrain.append_array(brut.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var frange: PackedVector3Array = triangles_de_la_frange(largeur)
	var uv_de: Callable = BM._uv_du_temoin(0)
	var tous := PackedVector3Array(terrain)
	tous.append_array(frange)
	var uv := PackedVector2Array()
	for t in range(0, tous.size() - 2, 3):
		uv.append_array(uv_de.call(tous[t], tous[t + 1], tous[t + 2]))
	var matiere := StandardMaterial3D.new()
	matiere.resource_name = "faux_artiste"
	matiere.albedo_texture = ImageTexture.create_from_image(texture(tous, uv, discipline))

	var racine := Node3D.new()
	racine.name = "FauxArtiste"
	var mesure := {"triangles": tous.size() / 3, "a_cheval": 0, "frange": frange.size() / 3,
		"frange_hors_case": 0, "plus_grand_deplacement": 0.0}
	# ⚠ SÉPARÉE, LA FRANGE PASSE D'ABORD : un lecteur qui ne prendrait que le premier objet perdrait le
	# terrain.
	var morceaux: Array = [["Frange", terrain.size(), tous.size()], ["Terrain", 0, terrain.size()]] \
		if separe else [["Terrain", 0, tous.size()]]
	for morceau in morceaux:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var v := PackedVector3Array()
		var u := PackedVector2Array()
		for i in range(int(morceau[1]), int(morceau[2])):
			var d: Vector3 = deplacement(tous[i], maladroit)
			mesure["plus_grand_deplacement"] = maxf(mesure["plus_grand_deplacement"], d.length())
			v.append(tous[i] + d)
			u.append(uv[i])
		for t in range(0, v.size() - 2, 3):
			if a_cheval(v[t], v[t + 1], v[t + 2], [0, 1, 2]):
				mesure["a_cheval"] += 1
			if t >= terrain.size() - int(morceau[1]) and hors_de_sa_case(v[t], v[t + 1], v[t + 2]):
				mesure["frange_hors_case"] += 1
		if v.is_empty():
			continue
		# ⚠ SOUDÉ : un sommet par (position, UV), et des indices — la frange partage les sommets de
		# l'arête du volume où elle s'attache. Là où l'UV change, le glTF coupe de toute façon (§4).
		var connus := {}
		var vs := PackedVector3Array()
		var us := PackedVector2Array()
		var indices := PackedInt32Array()
		for i in v.size():
			var cle := "%d,%d,%d|%d,%d" % [roundi(v[i].x * 100000.0), roundi(v[i].y * 100000.0),
				roundi(v[i].z * 100000.0), roundi(u[i].x * 1000000.0), roundi(u[i].y * 1000000.0)]
			if not connus.has(cle):
				connus[cle] = vs.size()
				vs.append(v[i])
				us.append(u[i])
			indices.append(connus[cle])
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_TEX_UV] = us
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, matiere)
		var instance := MeshInstance3D.new()
		instance.name = morceau[0]
		instance.mesh = mesh
		racine.add_child(instance)

	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_scene(racine, etat)
	if err == OK:
		err = document.write_to_filesystem(etat, chemin)
	racine.free()
	mesure["erreur"] = "" if err == OK else "l'écriture du .glb a rendu %d" % err
	return mesure
