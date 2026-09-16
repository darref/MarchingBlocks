extends SceneTree
##
## LE LOT DE TUILES TEMPORAIRE — généré, pas dessiné.
##
## ⚠ CE LOT EST UN PLACEHOLDER ASSUMÉ, et il le montre : des aplats propres, une palette de quatorze
## couleurs, aucune prétention. Il sert à peindre la zone de départ et à juger la lisibilité à deux vues
## (charte §3), en attendant le lot final que Jordan achètera.
##
## ⚠ POURQUOI UNE PALETTE RESTREINTE ET PARTAGÉE. La charte (§5) veut que le monde vivant et le monde
## intriqué soient la MÊME carte, repeinte par permutation de palette — le tour du Monde des Ténèbres
## d'ALTTP. Ça n'est possible que si toutes les tuiles puisent dans une palette commune et courte. Un
## lot acheté qui ne respecte pas ça coûtera deux jeux de tuiles au lieu d'un : c'est un critère
## d'achat, pas un détail.
##
## CE QUI EST PRODUIT
##   ART/tuiles.png   l'atlas, 16×16 par tuile
##   ART/tuiles.tres  le TileSet, avec trois données personnalisées par tuile :
##                      nom   (String) — pour retrouver une tuile sans connaître sa position
##                      mur   (bool)   — ce qui arrête la lumière et le joueur
##                      objet (String) — un type du catalogue posé par cette tuile, sinon ""
##
## ⚠ LE TILESET EST LA SEULE TABLE. Personne n'écrit ailleurs « la tuile 3 est un rocher » : on demande
## au TileSet la tuile nommée « rocher ». Remplacer l'atlas par un lot acheté ne cassera donc aucune
## carte, tant que les noms restent.
##
## LANCEMENT — deux temps, parce que Godot doit importer le PNG entre les deux :
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_tuiles.gd
##   godot --headless --path D:/UnderMend --import
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/faire_tuiles.gd

## ⚠ 32 depuis le 16 septembre 2026 : le lot acheté pour la surface est en 32×32, et une seule taille de
## case vaut pour tout le jeu. Ce lot-ci ne sert plus qu'aux GROTTES, en attendant un lot de côté.
const COTE := 32
const COLONNES := 8
const DOSSIER := "res://ART"
const IMAGE := DOSSIER + "/tuiles.png"
const TILESET := DOSSIER + "/tuiles.tres"

## Quatorze couleurs, et pas une de plus.
const PALETTE := {
	"nuit": Color("#130e22"),
	"or": Color("#ebbb69"),
	"roche_sombre": Color("#1c1628"),
	"roche": Color("#2e2740"),
	"roche_claire": Color("#443a5e"),
	"terre": Color("#6b4f3a"),
	"terre_claire": Color("#856546"),
	"herbe_sombre": Color("#2f5a3a"),
	"herbe": Color("#3d6b3a"),
	"herbe_claire": Color("#4e8244"),
	"eau_sombre": Color("#1f4a7a"),
	"eau": Color("#2f6aa8"),
	"clair": Color("#bfe8f2"),
	"os": Color("#f2efe6"),
}

## L'ordre de cette liste est l'ordre dans l'atlas, mais RIEN ne s'y réfère par position : on cherche
## par `nom`. Ajouter une tuile au milieu ne casse donc aucune carte déjà peinte... à condition de ne
## pas en RETIRER une (les cartes peintes gardent, elles, des coordonnées d'atlas).
const TUILES := [
	# ── la surface, vue de dessus ─────────────────────────────────────────────────────────────────
	{"nom": "herbe", "mur": false, "fond": "herbe", "motif": "taches", "encre": "herbe_claire"},
	{"nom": "herbe_haute", "mur": false, "fond": "herbe_sombre", "motif": "touffes", "encre": "herbe"},
	{"nom": "fleurs", "mur": false, "fond": "herbe", "motif": "points", "encre": "or"},
	{"nom": "terre", "mur": false, "fond": "terre", "motif": "taches", "encre": "terre_claire"},
	{"nom": "dalle", "mur": false, "fond": "roche_claire", "motif": "cadre", "encre": "roche"},
	{"nom": "rocher", "mur": true, "fond": "roche", "motif": "blocs", "encre": "roche_claire"},
	{"nom": "buisson", "mur": true, "fond": "herbe_sombre", "motif": "touffes", "encre": "herbe_sombre"},
	{"nom": "eau", "mur": true, "fond": "eau", "motif": "vagues", "encre": "eau_sombre"},
	{"nom": "falaise", "mur": true, "fond": "roche_sombre", "motif": "bord_haut", "encre": "roche"},

	# ── la grotte, vue de côté ────────────────────────────────────────────────────────────────────
	{"nom": "roche_pleine", "mur": true, "fond": "roche_sombre", "motif": "blocs", "encre": "roche"},
	{"nom": "air", "mur": false, "fond": "nuit", "motif": "uni", "encre": "nuit"},
	{"nom": "sol_grotte", "mur": true, "fond": "roche", "motif": "bord_haut", "encre": "roche_claire"},
	{"nom": "plafond", "mur": true, "fond": "roche", "motif": "bord_bas", "encre": "roche_claire"},
	{"nom": "gravats", "mur": false, "fond": "nuit", "motif": "cailloux", "encre": "roche_claire"},
	{"nom": "puits", "mur": false, "fond": "roche_sombre", "motif": "halo", "encre": "or"},

	# ── ce qui pose un objet du catalogue ─────────────────────────────────────────────────────────
	{"nom": "entree", "mur": false, "objet": "ENTREE", "fond": "nuit", "motif": "cadre", "encre": "or"},
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER))
	var image := _peindre_atlas()
	var erreur := image.save_png(IMAGE)
	if erreur != OK:
		print("ÉCHEC — impossible d'écrire %s (%d)" % [IMAGE, erreur])
		quit(1)
		return
	print("atlas écrit : %s — %d tuiles, %d×%d px" % [IMAGE, TUILES.size(), image.get_width(), image.get_height()])

	var texture: Texture2D = load(IMAGE) if ResourceLoader.exists(IMAGE) else null
	if texture == null:
		print("le PNG n'est pas encore importé — lance « godot --headless --path D:/UnderMend --import »,")
		print("puis relance cet outil : il écrira alors %s" % TILESET)
		quit(0)
		return
	_ecrire_tileset(texture)
	quit(0)


func _peindre_atlas() -> Image:
	var lignes := ceili(float(TUILES.size()) / COLONNES)
	var image := Image.create_empty(COLONNES * COTE, lignes * COTE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in TUILES.size():
		_peindre(image, Vector2i(i % COLONNES, i / COLONNES) * COTE, TUILES[i], i)
	return image


## ⚠ Le hasard est SEMÉ par l'indice de la tuile : régénérer l'atlas redonne exactement la même image,
## donc un atlas régénéré ne fait pas bouger un pixel dans git sans raison.
func _peindre(image: Image, origine: Vector2i, tuile: Dictionary, graine: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine * 7919 + 13
	var fond: Color = PALETTE[tuile["fond"]]
	var encre: Color = PALETTE[tuile["encre"]]
	image.fill_rect(Rect2i(origine, Vector2i(COTE, COTE)), fond)

	# ⚠ Tous les motifs se mesurent en UNITÉS de COTE/16, jamais en pixels fixes : le jour où la taille
	# de case a doublé, les dessins ont suivi au lieu de se tasser dans un coin.
	var u := COTE / 16
	match tuile["motif"]:
		"uni":
			pass
		"taches":
			for n in 10 * u:
				var p := origine + Vector2i(hasard.randi_range(0, COTE - 2 * u), hasard.randi_range(0, COTE - u))
				image.fill_rect(Rect2i(p, Vector2i(2 * u, u)), encre)
		"points":
			for n in 5 * u:
				var p := origine + Vector2i(hasard.randi_range(u, COTE - 2 * u), hasard.randi_range(u, COTE - 2 * u))
				image.fill_rect(Rect2i(p, Vector2i(u, u)), encre)
		"touffes":
			for n in 7 * u:
				var x := hasard.randi_range(u, COTE - 2 * u)
				var h := hasard.randi_range(3 * u, 6 * u)
				image.fill_rect(Rect2i(origine + Vector2i(x, COTE - h - u), Vector2i(u, h)), encre)
		"cadre":
			image.fill_rect(Rect2i(origine, Vector2i(COTE, u)), encre)
			image.fill_rect(Rect2i(origine + Vector2i(0, COTE - u), Vector2i(COTE, u)), encre)
			image.fill_rect(Rect2i(origine, Vector2i(u, COTE)), encre)
			image.fill_rect(Rect2i(origine + Vector2i(COTE - u, 0), Vector2i(u, COTE)), encre)
		"blocs":
			var hauteur := COTE / 4
			for ligne in 4:
				var decalage := 0 if ligne % 2 == 0 else COTE / 2
				image.fill_rect(Rect2i(origine + Vector2i(0, ligne * hauteur), Vector2i(COTE, u)), encre)
				image.fill_rect(Rect2i(origine + Vector2i(decalage, ligne * hauteur), Vector2i(u, hauteur)), encre)
		"vagues":
			for ligne in 4:
				var x := hasard.randi_range(u, 6 * u)
				image.fill_rect(Rect2i(origine + Vector2i(x, ligne * (COTE / 4) + 2 * u), Vector2i(6 * u, u)), encre)
		"bord_haut":
			image.fill_rect(Rect2i(origine, Vector2i(COTE, 3 * u)), encre)
		"bord_bas":
			image.fill_rect(Rect2i(origine + Vector2i(0, COTE - 3 * u), Vector2i(COTE, 3 * u)), encre)
		"cailloux":
			for n in 6 * u:
				var p := origine + Vector2i(hasard.randi_range(0, COTE - 3 * u), hasard.randi_range(COTE - 5 * u, COTE - 2 * u))
				image.fill_rect(Rect2i(p, Vector2i(2 * u, 2 * u)), encre)
		"halo":
			# un puits de lumière : l'or s'éteint vers le bas, et c'est le seul dégradé du lot
			for y in COTE:
				var force := 1.0 - float(y) / COTE
				image.fill_rect(Rect2i(origine + Vector2i(4, y), Vector2i(8, 1)), fond.lerp(encre, force))
		_:
			print("motif inconnu : %s" % tuile["motif"])


func _ecrire_tileset(texture: Texture2D) -> void:
	var jeu := TileSet.new()
	jeu.tile_size = Vector2i(COTE, COTE)
	for nom in ["nom", "mur", "objet"]:
		var indice := jeu.get_custom_data_layers_count()
		jeu.add_custom_data_layer()
		jeu.set_custom_data_layer_name(indice, nom)
		jeu.set_custom_data_layer_type(indice, TYPE_BOOL if nom == "mur" else TYPE_STRING)

	# ⚠ LA COLLISION EST DÉDUITE DE `mur`, jamais posée tuile par tuile. Autrement une tuile finirait
	# par arrêter la lumière sans arrêter les pieds (ou l'inverse), et ça ne se verrait qu'en jouant.
	# Une seule couche physique, le carré plein : `DEV_TOOLS/test_niveau.gd` vérifie la correspondance.
	jeu.add_physics_layer()
	jeu.set_physics_layer_collision_layer(0, 1)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(COTE, COTE)
	# ⚠ La source rejoint le TileSet AVANT qu'on crée les tuiles : une TileData ne connaît ses données
	# personnalisées que par le TileSet auquel elle appartient. Attachée après, elle les refuse en silence.
	jeu.add_source(source, 0)
	for i in TUILES.size():
		var coords := Vector2i(i % COLONNES, i / COLONNES)
		source.create_tile(coords)
		var donnees := source.get_tile_data(coords, 0)
		donnees.set_custom_data("nom", TUILES[i]["nom"])
		donnees.set_custom_data("mur", TUILES[i]["mur"])
		donnees.set_custom_data("objet", TUILES[i].get("objet", ""))
		if TUILES[i]["mur"]:
			var demi := COTE / 2.0
			donnees.add_collision_polygon(0)
			donnees.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-demi, -demi), Vector2(demi, -demi), Vector2(demi, demi), Vector2(-demi, demi)]))

	var erreur := ResourceSaver.save(jeu, TILESET)
	if erreur != OK:
		print("ÉCHEC — impossible d'écrire %s (%d)" % [TILESET, erreur])
		return
	print("tileset écrit : %s — %d tuiles nommées" % [TILESET, TUILES.size()])
