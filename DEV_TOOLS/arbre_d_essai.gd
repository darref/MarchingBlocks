extends RefCounted
## UN ARBRE D'ESSAI pour l'atelier Foliage (6 octobre 2026) — écrit en `.glb` par Godot lui-même, pour que les tests
## n'aient besoin d'aucun fichier livré. Ses mesures sont écrites ICI, à la main, et c'est elles que les tests
## attendent :
##   • un TRONC (cylindre, rayons 0,15 en bas et 0,12 en haut, haut de 1,5) de y = −0,3 (les racines, sous l'origine)
##     à y = 1,2, écorce opaque ;
##   • une COURONNE (sphère de rayon 0,7) centrée en y = 1,6 : son sommet à 2,3, sa largeur 1,4 ; feuillage en
##     DÉCOUPE alpha, double face.
## Donc : le point le plus bas −0,3 (« posé sur sa base » : décalage 0,3), le haut 2,3, la plus grande largeur 1,4.

const BAS := -0.3
const HAUT := 2.3
const LARGEUR := 1.4
const TRONC_Y := 0.45


static func ecrire(chemin: String) -> String:
	var racine := Node3D.new()
	racine.name = "Arbre"
	var tronc := MeshInstance3D.new()
	tronc.name = "Tronc"
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = 0.15
	cyl.top_radius = 0.12
	cyl.height = 1.5
	var ecorce := StandardMaterial3D.new()
	ecorce.resource_name = "Bark"
	ecorce.albedo_color = Color("#6b4a2f")
	cyl.material = ecorce
	tronc.mesh = cyl
	tronc.position = Vector3(0, TRONC_Y, 0)
	racine.add_child(tronc)
	var couronne := MeshInstance3D.new()
	couronne.name = "Couronne"
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	var feuilles := StandardMaterial3D.new()
	feuilles.resource_name = "Leaves"
	feuilles.albedo_color = Color("#4f8a3a")
	feuilles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	feuilles.alpha_scissor_threshold = 0.5
	feuilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material = feuilles
	couronne.mesh = sphere
	couronne.position = Vector3(0, 1.6, 0)
	racine.add_child(couronne)
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var e := doc.append_from_scene(racine, etat)
	if e == OK:
		e = doc.write_to_filesystem(etat, chemin)
	racine.free()
	return "" if e == OK else "écriture du .glb : erreur %d" % e
