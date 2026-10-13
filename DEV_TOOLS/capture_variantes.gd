extends SceneTree
## LES VARIANTES VOULUES, PHOTOGRAPHIÉES (4 octobre 2026) — une variante du SOL et une de la PAROI, peintes en rouge et
## relevées en leur cœur, puis le monde peint de la forme du témoin : le tirage les mêle ; puis l'outil Variant, un poids
## à 0, et le choix sur une sélection.
##
## LANCEMENT — ⚠ AVEC FENÊTRE :
##   xvfb-run -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --path . \
##       --script res://DEV_TOOLS/capture_variantes.gd -- --dossier=/tmp/captures
## ⚠ Comme `capture_app.gd` : un projet jetable, et `reglages.cfg` rendu tel quel à la fin.

const Projet := preload("res://app/projet.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const REGLAGES := "user://reglages.cfg"
const JETABLE := "user://capture/variantes.mbproj"

var _dossier := "D:/MarchingBlocks/ART/app"
var _ecran: Control
var _reglages_avant := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	DirAccess.make_dir_recursive_absolute(_dossier)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
	DirAccess.make_dir_recursive_absolute("user://capture")
	var f := FileAccess.open(JETABLE, FileAccess.WRITE)
	f.store_string(Projet.vers_texte([Projet.couche("Rock")], 0))
	f.close()
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", JETABLE)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler()


## La clé la plus répétée dont le nom contient `motif`.
func _la_plus_repetee(t: RefCounted, motif: String) -> String:
	var meilleure := ""
	for cle in t.tuiles:
		if cle.contains(motif) and (meilleure == "" or t.occurrences_de(cle).size() > t.occurrences_de(meilleure).size()):
			meilleure = cle
	return meilleure


func _derouler() -> void:
	await _images(20)
	var e := _ecran
	e._aller_a("witness")
	e._regler_edition(true)
	await _images(5)
	var mo: Node3D = e._modeleur
	var t: RefCounted = mo.temoin
	# Un matériau rouge, partagé : les variantes le portent, pour qu'on les voie.
	t.materiaux.append({"nom": "Variant red", "couleur": Color(0.85, 0.22, 0.18), "rugosite": 0.8, "metal": 0.0,
		"texture": "", "echelle": 1.0, "projection": "boite"})
	var rouge: int = t.materiaux.size() - 1
	for motif in ["plaque_b4h0", "plaque_b2h2"]:
		var cle := _la_plus_repetee(t, motif + "_dehors")
		var occ: Array = t.occurrences_de(cle)
		print("%s : %d copies" % [cle, occ.size()])
		mo.activer(occ[occ.size() / 2])
		e._variantes.creer()
		var v: RefCounted = t.tuiles[mo.cle]
		for fa in v.faces.size():
			v.mats[fa] = rouge
		for i in v.sommets.size():
			var p: Vector3 = v.sommets[i]
			if absf(p.x) < 0.45 and absf(p.y) < 0.45 and absf(p.z) < 0.45:
				v.sommets[i] = p + Vector3(0, 0.08, 0)
		e._temoin_modifie(t)
		mo.charger_temoin(t, mo.occurrence)
	await _images(10)
	_photo("variantes_1_temoin")
	e._peindre_la_forme_du_temoin()
	# L'ATELIER VARIANTS (13 octobre 2026) : le monde dans la vue, sa barre à droite.
	e._aller_a("variantes")
	var vue = e._vue
	vue._cible = Vector3(6.0, 5.0, 6.0)
	vue._azimut = 0.8
	vue._elevation = 0.55
	vue._distance = 24.0
	vue._caler()
	await _images(15)
	_photo("variantes_2_monde_tirage")
	# Toute la forme sélectionnée, « Variant 1 » : chaque sol et chaque paroi la montre.
	var tout := {}
	for c in vue.cases().get_used_cells():
		tout[c] = true
	vue.regler_selection(tout)
	e._variantes.choix_selection.select(2)
	e._variantes.appliquer_a_la_selection()
	vue.regler_selection({})
	await _images(10)
	_photo("variantes_3_tout_en_variante")
	e._variantes.tout_au_hasard()
	# La liste et la ligne des poids de la première tuile à variantes (la photo, les copies posées, « Sculpt »).
	if not e._variantes._lignes.is_empty():
		e._variantes.designer(e._variantes._lignes.keys()[0])
	await _images(10)
	_photo("variantes_4_outil")
	print("RAPPORT :\n", e._rapport.text)
	if _reglages_avant != "":
		var g := FileAccess.open(REGLAGES, FileAccess.WRITE)
		g.store_string(_reglages_avant)
		g.close()
	quit(0)


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _photo(nom: String) -> void:
	var img := root.get_texture().get_image()
	var chemin := _dossier.path_join(nom + ".png")
	var err := img.save_png(chemin)
	print("%s → %s" % [nom, chemin if err == OK else "ÉCHEC %d" % err])
