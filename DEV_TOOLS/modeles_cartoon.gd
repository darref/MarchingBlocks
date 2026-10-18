extends RefCounted
## LES MODÈLES DU FEUILLAGE CARTOON (18 octobre 2026) — pour le monde cartoon de `batir_monde_cartoon.gd` : Jordan veut
## « de la peinture handpainted, pas de texture toute prête, un aspect cartoon minimaliste genre Pokémon ». Les arbres de
## Spirit3D (Tripo, textures photographiques) n'y vont pas : ces modèles sont CALCULÉS ici, en primitives de Godot à
## facettes (peu de segments), une couleur unie par matériau, sans image — écrits en `.glb` puis importés par la route du
## bouton « Import .glb… » de l'atelier Foliage, comme un modèle d'artiste.
##
## Chaque modèle a son pied à y = 0 (le sol) ; l'atelier le met ensuite à la hauteur voulue.

const VERT := "#4cb84a"
const VERT_CLAIR := "#6fd65f"
const VERT_SOMBRE := "#2f8a4e"
const ECORCE := "#8a5a35"


static func _mat(nom: String, couleur: String, rugosite := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.albedo_color = Color(couleur)
	m.roughness = rugosite
	return m


static func _piece(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, echelle := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "P%d" % parent.get_child_count()
	(mesh as PrimitiveMesh).material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	parent.add_child(mi)


static func _boule(r: float, segments := 9, anneaux := 5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = 2.0 * r
	s.radial_segments = segments
	s.rings = anneaux
	return s


static func _cylindre(bas: float, haut: float, h: float, segments := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bas
	c.top_radius = haut
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


## Le modèle `nom` (une scène), à écrire.
static func modele(nom: String) -> Node3D:
	var r := Node3D.new()
	r.name = nom
	var ecorce := _mat("Bark", ECORCE)
	match nom:
		"arbre_rond", "arbre_automne":
			var f := _mat("Leaves", VERT if nom == "arbre_rond" else "#f08a2a")
			var f2 := _mat("Leaves2", VERT_CLAIR if nom == "arbre_rond" else "#ffb547")
			_piece(r, _cylindre(0.2, 0.14, 1.4), ecorce, Vector3(0, 0.7, 0))
			_piece(r, _boule(0.95), f, Vector3(0, 2.0, 0))
			_piece(r, _boule(0.62), f2, Vector3(0.55, 2.45, 0.2))
			_piece(r, _boule(0.6), f, Vector3(-0.5, 1.75, -0.3))
		"sapin", "sapin_neige":
			var f := _mat("Needles", VERT_SOMBRE)
			var neige := _mat("Snow", "#f4f8ff")
			_piece(r, _cylindre(0.16, 0.12, 0.8), ecorce, Vector3(0, 0.4, 0))
			for i in 3:
				var rb := 1.0 - i * 0.26
				var mat := neige if nom == "sapin_neige" and i == 2 else f
				_piece(r, _cylindre(rb, 0.0, 1.3, 7), mat, Vector3(0, 1.2 + i * 0.75, 0))
		"buisson":
			var f := _mat("Leaves", "#56c25a")
			_piece(r, _boule(0.55), f, Vector3(0, 0.4, 0))
			_piece(r, _boule(0.42), f, Vector3(0.45, 0.3, 0.1))
			_piece(r, _boule(0.38), _mat("Leaves2", VERT_CLAIR), Vector3(-0.35, 0.32, 0.25))
		"fleurs":
			var tige := _mat("Stem", "#3f9e3c")
			var couleurs := ["#ff6fa5", "#ffd84d", "#ffffff", "#b98bff", "#ff8f4d"]
			for i in 6:
				var a := i * TAU / 6.0 + 0.3
				var p := Vector3(cos(a) * 0.28 * (i % 2 + 1) * 0.6, 0, sin(a) * 0.28 * (i % 2 + 1) * 0.6)
				var h := 0.35 + 0.12 * (i % 3)
				_piece(r, _cylindre(0.025, 0.025, h, 5), tige, p + Vector3(0, h * 0.5, 0))
				_piece(r, _boule(0.09, 7, 4), _mat("Petal%d" % i, couleurs[i % couleurs.size()]), p + Vector3(0, h, 0))
		"cactus":
			var v := _mat("Cactus", "#4caf50")
			_piece(r, _cylindre(0.28, 0.24, 1.8, 8), v, Vector3(0, 0.9, 0))
			_piece(r, _boule(0.24, 8, 4), v, Vector3(0, 1.8, 0))
			_piece(r, _cylindre(0.14, 0.14, 0.5, 7), v, Vector3(0.38, 0.85, 0), Vector3(0, 0, PI / 2))
			_piece(r, _cylindre(0.13, 0.11, 0.55, 7), v, Vector3(0.6, 1.1, 0))
			_piece(r, _cylindre(0.13, 0.13, 0.4, 7), v, Vector3(-0.34, 1.2, 0), Vector3(0, 0, PI / 2))
			_piece(r, _cylindre(0.12, 0.1, 0.45, 7), v, Vector3(-0.52, 1.42, 0))
			_piece(r, _boule(0.1, 6, 3), _mat("Flower", "#ff5d8f"), Vector3(0, 2.02, 0))
		"palmier":
			var tronc := _mat("Trunk", "#b98a55")
			for i in 5:
				_piece(r, _cylindre(0.17 - i * 0.015, 0.15 - i * 0.015, 0.75, 7), tronc,
					Vector3(i * 0.09, 0.37 + i * 0.72, 0), Vector3(0, 0, -0.08))
			var palme := _mat("Fronds", "#3fae4a")
			for i in 6:
				var a := i * TAU / 6.0
				var b := BoxMesh.new()
				b.size = Vector3(1.6, 0.06, 0.42)
				_piece(r, b, palme, Vector3(0.45 + cos(a) * 0.7, 3.55, sin(a) * 0.7), Vector3(0, -a, -0.45))
			_piece(r, _boule(0.14, 6, 3), _mat("Coconut", "#6b4a2f"), Vector3(0.5, 3.4, 0.15))
		"arbre_mort":
			var b := _mat("Bark", "#5e4a3a")
			_piece(r, _cylindre(0.22, 0.1, 2.6, 6), b, Vector3(0, 1.3, 0))
			_piece(r, _cylindre(0.08, 0.04, 1.1, 5), b, Vector3(0.35, 2.0, 0), Vector3(0, 0, -0.9))
			_piece(r, _cylindre(0.07, 0.03, 0.9, 5), b, Vector3(-0.3, 1.6, 0.1), Vector3(0.2, 0, 0.9))
			_piece(r, _boule(0.32, 7, 4), _mat("Moss", "#7a9a3a"), Vector3(0.1, 2.6, 0))
		"roseaux":
			var tige := _mat("Reed", "#6f8f3a")
			var epi := _mat("Cattail", "#6b4226")
			for i in 7:
				var a := i * 2.4
				var p := Vector3(cos(a) * 0.05 * i, 0, sin(a) * 0.05 * i)
				var h := 0.8 + 0.25 * (i % 3)
				_piece(r, _cylindre(0.03, 0.02, h, 5), tige, p + Vector3(0, h * 0.5, 0))
				if i % 2 == 0:
					_piece(r, _cylindre(0.06, 0.06, 0.22, 6), epi, p + Vector3(0, h - 0.05, 0))
		"rocher", "rocher_rouge", "rocher_noir":
			var c: String = {"rocher": "#9aa0a8", "rocher_rouge": "#cf6a3e", "rocher_noir": "#433b3d"}[nom]
			var m := _mat("Stone", c)
			_piece(r, _boule(0.7, 7, 4), m, Vector3(0, 0.35, 0), Vector3(0, 0.4, 0), Vector3(1.2, 0.8, 1.0))
			_piece(r, _boule(0.42, 6, 3), _mat("Stone2", c), Vector3(0.65, 0.2, 0.3), Vector3(0.3, 1.0, 0), Vector3(1, 0.8, 1))
		"cristal":
			var m := _mat("Crystal", "#b07cff", 0.3)
			var m2 := _mat("Crystal2", "#86e8ff", 0.3)
			for i in 5:
				var a := i * TAU / 5.0
				var h := 0.9 + 0.35 * (i % 3)
				_piece(r, _cylindre(0.16, 0.0, h, 6), m if i % 2 == 0 else m2,
					Vector3(cos(a) * 0.18, h * 0.45, sin(a) * 0.18), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))
			_piece(r, _cylindre(0.2, 0.0, 1.6, 6), m, Vector3(0, 0.8, 0))
		"champignon":
			_piece(r, _cylindre(0.16, 0.2, 0.9, 8), _mat("Stem", "#f3ead8"), Vector3(0, 0.45, 0))
			var chapeau := _boule(0.62, 10, 5)
			_piece(r, chapeau, _mat("Cap", "#e53b3b"), Vector3(0, 0.95, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	return r


const NOMS := ["arbre_rond", "arbre_automne", "sapin", "sapin_neige", "buisson", "fleurs", "cactus", "palmier",
	"arbre_mort", "roseaux", "rocher", "rocher_rouge", "rocher_noir", "cristal", "champignon"]


## Écrit chaque modèle en `<dossier>/<nom>.glb`. Rend {nom: chemin}.
static func ecrire_tout(dossier: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dossier)
	var sortie := {}
	for nom in NOMS:
		var scene := modele(nom)
		var chemin := dossier.path_join(nom + ".glb")
		var doc := GLTFDocument.new()
		var etat := GLTFState.new()
		var e := doc.append_from_scene(scene, etat)
		if e == OK:
			e = doc.write_to_filesystem(etat, chemin)
		scene.free()
		if e == OK:
			sortie[nom] = chemin
		else:
			push_warning("modèle %s : erreur %d" % [nom, e])
	return sortie
