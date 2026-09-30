extends RefCounted
## LES FORMES DU TÉMOIN — ce que chaque morceau du bloc de 12³ DEVIENT dans le monde peint.
##
## ⚠ **UNE SEULE DESCRIPTION DES FORMES, ET C'EST CELLE-CI (charte §6).** Elles vivaient dans
## `DEV_TOOLS/planete_paysage.gd`, qui les pose l'une après l'autre ; l'appli en a besoin pour la
## LÉGENDE de l'atelier Witness (demandée par Jordan le 29 septembre 2026 : « on ne reconnaît pas du
## premier coup d'œil ce qu'il faut altérer au witness pour retrouver quoi et où dans le monde »).
## Recopier les boîtes dans l'appli, c'était deux descriptions qui divergent au premier retouchage :
## `planete_paysage.gd` lit donc `FORMES` pour bâtir le témoin, et la légende lit la même table.
##
## ⚠ **LES GESTES SONT DANS L'ORDRE OÙ ILS SONT POSÉS, ET L'ORDRE COMPTE** : une case creusée après une
## case pleine l'emporte. Réordonner cette table change le témoin — `test_formes_du_temoin` le garde en
## rebâtissant le bloc et en le comparant à `BlocsMaitres.BLOCS`.
##
## ⚠ **CE QUI N'EST DANS AUCUNE FORME SE DÉDUIT, IL NE SE DÉCLARE PAS** : la réparation et le finisseur
## de `planete_paysage.gd` ajoutent quelques cases qu'aucune forme n'explique. `cases_du_finisseur()` les
## rend par DIFFÉRENCE entre le témoin livré et ce que bâtissent les formes — une liste écrite ici
## mentirait le jour où l'on recolle un autre témoin.
##
## Chaque forme : `nom` et `monde` en ANGLAIS (lus à l'écran, charte §7) ; `journal` en français (ce
## qu'imprime `planete_paysage.gd`) ; `gestes` = [coin a, coin b, plein] ; `zone` (facultative) = des
## boîtes [a, b] qui disent OÙ regarder, quand ce n'est pas l'union des gestes.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

const N := 11   # BM.COTE − 1

const FORMES := [
	{
		"id": "plateau", "nom": "Plateau & cliffs",
		"journal": "LES DEUX MASSIFS et LE CANYON qui les sépare",
		"monde": "Open ground on top, cliff faces on the sides: every raised plateau, hill flank and cliff.",
		"gestes": [
			[Vector3i(0, 0, 0), Vector3i(N, 1, N), true],     # le socle : deux couches de roche mère
			[Vector3i(0, 2, 0), Vector3i(5, 7, N), true],     # le grand massif, à l'ouest
			[Vector3i(9, 2, 0), Vector3i(N, 5, N), true],     # le massif de l'est, plus bas
		],
		# ⚠ Le dessus et la falaise, pas le massif entier : la salle est DEDANS, et l'éclairer ici dirait
		# à l'artiste que la grotte fait partie du plateau.
		# ⚠ LES DEUX MASSIFS : la première zone ne prenait que celui de l'ouest, et 16 des 541 sommets
		# récoltés — le dessus et la falaise du massif de l'est — n'appartenaient à AUCUNE carte ; l'atelier
		# World disait alors « this corner belongs to no named shape » (vu à l'image, 29 septembre 2026).
		"zone": [[Vector3i(0, 7, 0), Vector3i(5, 7, N)], [Vector3i(5, 2, 0), Vector3i(5, 7, N)],
			[Vector3i(9, 5, 0), Vector3i(N, 5, N)], [Vector3i(9, 2, 0), Vector3i(9, 5, N)]],
	},
	{
		# ⚠ AUCUN GESTE : le canyon est le vide que les deux massifs laissent entre eux.
		"id": "canyon", "nom": "Canyon",
		"journal": "",
		"monde": "The gap between two masses: valley floors hemmed in by walls, gorges, trenches.",
		"gestes": [],
		"zone": [[Vector3i(6, 2, 0), Vector3i(8, 3, N)]],
	},
	{
		"id": "arche", "nom": "Arch",
		"journal": "L'ARCHE (deux piles, un tablier, un vide entre elles)",
		"monde": "Two piers and a lintel with sky beneath: natural arches, gateways, open spans.",
		"gestes": [
			[Vector3i(6, 2, 3), Vector3i(6, 6, 4), true],
			[Vector3i(8, 2, 3), Vector3i(8, 6, 4), true],
			[Vector3i(6, 7, 3), Vector3i(8, 7, 4), true],
		],
	},
	{
		"id": "pont", "nom": "Bridge",
		"journal": "LE PONT (un tablier fin, d'une paroi à l'autre)",
		"monde": "A deck one cell thick across a gap: bridges, thin slabs, walkways.",
		"gestes": [[Vector3i(6, 5, 8), Vector3i(8, 5, 9), true]],
	},
	{
		"id": "salle", "nom": "Cave hall",
		"journal": "LA SALLE (creusée dans le grand massif)",
		"monde": "An enclosed room: cave floors, walls and ceilings — the UNDERGROUND tiles.",
		"gestes": [[Vector3i(1, 3, 3), Vector3i(4, 5, 8), false]],
	},
	{
		"id": "bouche", "nom": "Cave mouth",
		"journal": "LA BOUCHE DE GROTTE (elle perce la paroi du canyon)",
		"monde": "Where a cave opens onto the open air: every entrance cut into a cliff.",
		"gestes": [[Vector3i(5, 3, 5), Vector3i(5, 5, 7), false]],
	},
	{
		"id": "cheminee", "nom": "Chimney",
		"journal": "LA CHEMINÉE (de la salle jusqu'au ciel)",
		"monde": "A shaft from a cave up to the sky: skylights, holes in a cave roof.",
		"gestes": [[Vector3i(2, 6, 7), Vector3i(3, 7, 8), false]],
	},
	{
		"id": "auvent", "nom": "Overhang",
		"journal": "L'AUVENT (le massif surplombe le canyon)",
		"monde": "Rock jutting out over empty space: the underside of a ledge under the open sky.",
		"gestes": [[Vector3i(6, 7, 6), Vector3i(6, 7, 9), true]],
	},
	{
		"id": "corniche", "nom": "Cornice",
		"journal": "LA CORNICHE (une banquette à mi-paroi)",
		"monde": "A shelf halfway up a cliff: ledges, terraces, paths along a wall.",
		"gestes": [[Vector3i(6, 4, 0), Vector3i(6, 4, 2), true]],
	},
	{
		"id": "tunnel", "nom": "Tunnel",
		"journal": "LE TUNNEL (il débouche dans le canyon)",
		"monde": "A passage through the rock, open at its end: tunnels and galleries.",
		"gestes": [[Vector3i(9, 3, 2), Vector3i(N, 4, 3), false]],
	},
	{
		"id": "puits", "nom": "Pit",
		"journal": "LE PUITS (un trou ouvert au ciel)",
		"monde": "A vertical hole open to the sky: pits, wells, sinkholes seen from above.",
		"gestes": [[Vector3i(10, 2, 9), Vector3i(11, 5, 10), false]],
	},
	{
		"id": "crete", "nom": "Ridge & pass",
		"journal": "LA CRÊTE et son COL",
		"monde": "A crest one cell wide and the notch in it: ridgelines, low walls, mountain passes.",
		"gestes": [
			[Vector3i(11, 6, 4), Vector3i(11, 7, N), true],
			[Vector3i(11, 6, 6), Vector3i(11, 7, 7), false],
		],
	},
	{
		"id": "aiguille", "nom": "Needle",
		"journal": "L'AIGUILLE (un piton isolé)",
		"monde": "A lone pillar standing on the ground: spires, pinnacles, columns.",
		"gestes": [[Vector3i(9, 6, 6), Vector3i(9, 8, 6), true]],
	},
	{
		"id": "promontoire", "nom": "Promontory",
		"journal": "LE PROMONTOIRE (le plateau échancré laisse un cap)",
		"monde": "A cape sticking out of the plateau: headlands, spurs, outer corners of a cliff.",
		"gestes": [[Vector3i(4, 7, 3), Vector3i(5, 7, 4), false]],
	},
	{
		"id": "butte", "nom": "Mound",
		"journal": "LA BUTTE (un monticule)",
		"monde": "A bump on flat ground: hillocks, raised blocks on open terrain.",
		"gestes": [[Vector3i(2, 8, 9), Vector3i(3, 8, 10), true]],
	},
	{
		"id": "pilier", "nom": "Cave pillar",
		"journal": "LE PILIER DE SALLE (du sol au plafond)",
		"monde": "A column from cave floor to cave ceiling.",
		"gestes": [[Vector3i(2, 3, 4), Vector3i(2, 5, 4), true]],
	},
	{
		"id": "alcove", "nom": "Alcove",
		"journal": "L'ALCÔVE (la salle écartée d'un côté)",
		"monde": "A recess in the side of a cave: niches, inner corners underground.",
		"gestes": [[Vector3i(1, 3, 9), Vector3i(2, 5, 9), false]],
	},
	{
		"id": "bossage", "nom": "Wall boss",
		"journal": "LE BOSSAGE (une bosse sur la paroi)",
		"monde": "A bump on a cave wall: relief on underground walls.",
		"gestes": [[Vector3i(4, 3, 6), Vector3i(4, 4, 6), true]],
	},
	{
		"id": "banquette", "nom": "Cave bench",
		"journal": "LA BANQUETTE EN L (au pied des parois de la salle)",
		"monde": "A low L-shaped step along cave walls: underground steps no open-air shape can give.",
		"gestes": [
			[Vector3i(1, 3, 6), Vector3i(1, 3, 8), true],
			[Vector3i(2, 3, 8), Vector3i(3, 3, 8), true],
		],
	},
	{
		"id": "marche", "nom": "Corner step",
		"journal": "LA MARCHE D'ANGLE (un gradin en L, surmonté au coin)",
		"monde": "An L-shaped step on the plateau, raised at its corner: outdoor stairs and terraces.",
		"gestes": [
			[Vector3i(1, 8, 1), Vector3i(3, 8, 1), true],
			[Vector3i(1, 8, 2), Vector3i(1, 8, 3), true],
			[Vector3i(1, 9, 1), Vector3i(1, 9, 1), true],
		],
	},
	{
		"id": "caillou", "nom": "Edge boulder",
		"journal": "LE CAILLOU AU BORD",
		"monde": "A single block at a cliff edge: boulders, crenels, one-cell bumps.",
		"gestes": [[Vector3i(5, 8, 8), Vector3i(5, 8, 8), true]],
	},
	{
		"id": "stalactite", "nom": "Stalactite",
		"journal": "LA STALACTITE",
		"monde": "A single cell hanging from a ceiling: stalactites, hanging rock.",
		"gestes": [[Vector3i(3, 5, 7), Vector3i(3, 5, 7), true]],
	},
]

## La carte des cases que le finisseur et la réparation ont ajoutées — pas dans `FORMES` : déduite.
const FINISSEUR := {
	"id": "finisseur", "nom": "Twists",
	"monde": "Small twisted steps no landscape shape makes. They carry rare tiles: sculpt them too.",
}


## Les cases pleines après les gestes des formes `0 .. jusqu_a` (toutes par défaut).
static func batir(jusqu_a := -1) -> Dictionary:
	var p := {}
	var fin: int = FORMES.size() if jusqu_a < 0 else mini(jusqu_a + 1, FORMES.size())
	for i in fin:
		for g in (FORMES[i]["gestes"] as Array):
			poser(p, g[0], g[1], g[2])
	return p


static func poser(p: Dictionary, a: Vector3i, b: Vector3i, plein: bool) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				if plein:
					p[Vector3i(x, y, z)] = true
				else:
					p.erase(Vector3i(x, y, z))


## Les cases où le témoin livré diffère de ce que bâtissent les formes : le travail de la réparation et
## du finisseur, qu'aucune forme n'explique.
static func cases_du_finisseur() -> Array:
	var temoin: Dictionary = BM.cases(0)
	var formes: Dictionary = batir()
	var sortie: Array = []
	for c in temoin:
		if not formes.has(c):
			sortie.append(c)
	for c in formes:
		if not temoin.has(c):
			sortie.append(c)
	sortie.sort()
	return sortie


## LA LÉGENDE : une entrée par carte, dans l'ordre de `FORMES`, puis le finisseur s'il a posé quelque
## chose. Chacune porte ses `cases` (où regarder) et les CLÉS de tuiles que ses sommets livrent.
##
## ⚠ **LES CLÉS SONT CELLES DU TRANCHEUR** (`Tranchage.cle_du_sommet`) : la légende dit ce que la récolte
## prendra ici, pas une seconde idée de ce qu'est une tuile. Un sommet compte pour une forme dès qu'une
## de ses huit cases est dans la zone ; seuls les sommets INTÉRIEURS comptent, comme à la récolte.
## ⚠ **MESURÉ (29 septembre 2026) : l'union des cartes rend les 52 tuiles du monde** — aucune tuile ne
## vient d'un endroit que la légende ne montre pas. Et presque aucune n'est propre à UNE carte (les
## formes se chevauchent) : le compte dit combien de tuiles on touche en sculptant ici, rien de plus.
static func legende() -> Array:
	var sortie: Array = []
	for f in FORMES:
		var carte: Dictionary = f.duplicate()
		carte["cases"] = _cases_de_la_zone(f)
		sortie.append(carte)
	var fin := cases_du_finisseur()
	if not fin.is_empty():
		var carte: Dictionary = FINISSEUR.duplicate()
		carte["cases"] = fin
		sortie.append(carte)
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	for carte in sortie:
		var dans := {}
		for c in (carte["cases"] as Array):
			dans[c] = true
		var cles := {}
		for x in BM.COTE - 1:
			for y in BM.COTE - 1:
				for z in BM.COTE - 1:
					var v := Vector3i(x, y, z)
					for t in 8:
						if dans.has(v + MB.COINS[t]):
							var k: Dictionary = Tranchage.cle_du_sommet(pleines, v, plafond)
							if not k.is_empty():
								cles[k["cle"]] = true
							break
		var liste: Array = cles.keys()
		liste.sort()
		carte["cles"] = liste
	return sortie


## LE SENS INVERSE — les cartes dont la zone touche un sommet du témoin, LA PLUS PETITE D'ABORD.
##
## ⚠ **LA PLUS PETITE, PARCE QUE LES ZONES SE CHEVAUCHENT** : un pied de l'arche est aussi au fond du
## canyon. La forme la plus petite qui contient le sommet est la plus précise — c'est elle qu'on nomme ;
## les autres suivent. Même critère que `legende()` : une des huit cases du sommet dans la zone.
static func cartes_du_sommet(legende: Array, sommet: Vector3i) -> Array:
	var sortie: Array = []
	for carte in legende:
		var cases: Array = carte["cases"]
		for t in 8:
			if cases.has(sommet + MB.COINS[t]):
				sortie.append(carte)
				break
	sortie.sort_custom(func(a, b): return (a["cases"] as Array).size() < (b["cases"] as Array).size())
	return sortie


## D'OÙ VIENT UNE TUILE POSÉE : le sommet du témoin où elle a été découpée, lu dans le LOT par son nom
## (`BlocsMaitres.META_SOMMETS`). `null` si le lot ne le sait pas — le repli procédural, qui ne vient
## d'aucun témoin.
static func sommet_source(lot: MeshLibrary, nom: String) -> Variant:
	if lot == null:
		return null
	return (lot.get_meta(BM.META_SOMMETS, {}) as Dictionary).get(nom, null)


static func _cases_de_la_zone(f: Dictionary) -> Array:
	var p := {}
	if f.has("zone"):
		for boite in (f["zone"] as Array):
			poser(p, boite[0], boite[1], true)
	else:
		for g in (f["gestes"] as Array):
			poser(p, g[0], g[1], true)
	var sortie: Array = p.keys()
	sortie.sort()
	return sortie
