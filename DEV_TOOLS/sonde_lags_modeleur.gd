extends SceneTree
## SONDE — d'où viennent les « lags d'environ une seconde, à des moments différents » du modeleur ?
## (Jordan, 1er octobre 2026 : en édition de maillage, sélection, assignation de matériaux…)
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_lags_modeleur.gd -- <projet.mbproj>
##
## Chronomètre, sur le témoin de la couche active, chaque étape de ce qui tourne APRÈS un geste :
## l'enregistrement différé (une seconde après le dernier geste — d'où « à des moments différents »), et les
## routes que prennent la sélection, le dessin d'une tuile et les sections partagées.

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const SE := preload("res://addons/marchingblocks_core/sections.gd")
const Projet := preload("res://app/projet.gd")


func _initialize() -> void:
	var chemin: String = OS.get_cmdline_user_args()[0]
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	var c: Dictionary = d["couches"][int(d["active"])]
	var t: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(str(c["temoin"]))))
	var dossier := ProjectSettings.globalize_path("user://sonde_lags")
	DirAccess.make_dir_recursive_absolute(dossier)
	print("témoin %s : %d tuiles" % [str(c["temoin"]).get_file(), t.tuiles.size()])

	print("— L'ENREGISTREMENT DIFFÉRÉ (une seconde après le dernier geste) —")
	var t0 := Time.get_ticks_usec()
	var texte := JSON.stringify(t.vers_dictionnaire())
	_temps("vers_dictionnaire + JSON", t0)
	t0 = Time.get_ticks_usec()
	var f := FileAccess.open(dossier.path_join("t.mbtiles"), FileAccess.WRITE)
	f.store_string(texte)
	f.close()
	_temps("écrire le .mbtiles (%d Ko)" % (texte.length() / 1024), t0)
	var glb := dossier.path_join("t.glb")
	t0 = Time.get_ticks_usec()
	t.vers_glb(glb)
	_temps("vers_glb", t0)
	t0 = Time.get_ticks_usec()
	var bilan: Dictionary = BM.librairie_depuis_glb(glb)
	_temps("librairie_depuis_glb (le monde suit)", t0)
	t0 = Time.get_ticks_usec()
	Projet.mettre_en_cache(bilan["lot"], glb)
	_temps("mettre_en_cache (MD5 + ResourceSaver)", t0)

	print("— LES SECTIONS PARTAGÉES —")
	t0 = Time.get_ticks_usec()
	var s: RefCounted = SE.new(t)
	_temps("Sections.new", t0)
	t0 = Time.get_ticks_usec()
	s.indexer()
	_temps("indexer", t0)
	t0 = Time.get_ticks_usec()
	s.completer()
	_temps("completer (rien à reporter)", t0)
	t0 = Time.get_ticks_usec()
	s.absences()
	_temps("absences", t0)

	print("— DESSINER ET COPIER —")
	var cle := "mb_plaque_b2h2_dehors"
	var m: RefCounted = t.tuiles[cle]
	t0 = Time.get_ticks_usec()
	m.vers_array_mesh()
	_temps("vers_array_mesh d'une tuile (%d faces)" % m.faces.size(), t0)
	t0 = Time.get_ticks_usec()
	for k in t.tuiles:
		t.tuiles[k].vers_array_mesh()
	_temps("vers_array_mesh des %d tuiles (un matériau changé : toutes celles qui le portent)" % t.tuiles.size(), t0)
	t0 = Time.get_ticks_usec()
	m.copie()
	_temps("copie d'une tuile (l'annulation)", t0)
	t0 = Time.get_ticks_usec()
	t.copie()
	_temps("copie du témoin entier", t0)
	t0 = Time.get_ticks_usec()
	var _assemble = t.assemble() if t.has_method("assemble") else null
	_temps("assemble (le témoin d'un seul tenant)", t0)
	quit(0)


func _temps(nom: String, t0: int) -> void:
	print("  %-80s %7.1f ms" % [nom, (Time.get_ticks_usec() - t0) / 1000.0])
