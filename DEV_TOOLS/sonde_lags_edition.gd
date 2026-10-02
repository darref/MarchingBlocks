extends SceneTree
## SONDE AVEC FENÊTRE — « même dans le soft en global il y a encore trop d'algos lents pendant l'édition » (Jordan,
## 2 octobre 2026). Mène l'appli sur l'EXEMPLE livré (194 692 cases dans « Hills »), installé dans un dossier À ELLE
## (jamais la copie de l'utilisateur), et chronomètre chaque geste courant de World : le geste lui-même, la pire image
## qui suit, et le retard cumulé sur 30 images (au-delà de 16,7 ms chacune). Ne conçoit rien, mesure.
##   godot --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_lags_edition.gd
## ⚠ Les réglages sont rendus à la fin ; le projet ouvert est une copie jetable.

const Exemple := preload("res://app/exemple.gd")
const REGLAGES := "user://reglages.cfg"
const DOSSIER := "user://sonde_lags_edition"
const SAUVEGARDE := "user://reglages.cfg.avant_sonde"
var _reglages_avant := ""
var _ecran: Control
var _chemin := ""


func _initialize() -> void:
	# ⚠ LES RÉGLAGES SONT COPIÉS SUR LE DISQUE AVANT D'ÊTRE TOUCHÉS : une sonde interrompue (erreur, arrêt) ne les
	# rendait pas, et ceux de l'utilisateur étaient perdus (2 octobre 2026). Une copie restée d'un passage interrompu
	# est rendue d'abord.
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		_reglages_avant = FileAccess.get_file_as_string(REGLAGES)
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	_vider(DOSSIER)
	var erreurs: Array = []
	var chemin := Exemple.installer(Exemple.ARCHIVE, DOSSIER, erreurs)
	if chemin == "":
		print("⚠ l'exemple ne s'installe pas : %s" % [erreurs])
		_rendre_les_reglages()
		quit(1)
		return
	_chemin = chemin
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", chemin)
	r.save(REGLAGES)
	load("res://app/editor.gd").racine_exemple = DOSSIER
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	_derouler.call_deferred()


func _vider(chemin: String) -> void:
	if not DirAccess.dir_exists_absolute(chemin):
		return
	for d in DirAccess.get_directories_at(chemin):
		_vider(chemin.path_join(d))
	for f in DirAccess.get_files_at(chemin):
		DirAccess.remove_absolute(chemin.path_join(f))
	DirAccess.remove_absolute(chemin)


func _derouler() -> void:
	for i in 30:
		await process_frame
	# ⚠ L'APPLI NE ROUVRE JAMAIS L'EXEMPLE AU LANCEMENT (« l'exemple ne s'impose pas ») : on l'ouvre.
	var t0 := Time.get_ticks_msec()
	var ok: bool = await _ecran._ouvrir(_chemin)
	print("ouverture de l'exemple : %s, %d ms" % [ok, Time.get_ticks_msec() - t0])
	await _mesurer("aller dans World", func(): _ecran._changer_d_atelier("monde"))
	var occ: Dictionary = _ecran._occupees()
	print("couche active : %d cases ; monde : %d cases" % [occ.size(), _ecran._occupees_du_monde().size()])
	await _mesurer("à vide (rien)", func(): pass)
	# Une colonne du dessus, pour poser et creuser.
	var haut := Vector3i(0, -999, 0)
	for p in occ:
		if p.y > haut.y:
			haut = p
	var neuve := haut + Vector3i.UP
	# LE SURVOL : la souris balaie la vue, l'aperçu suit (Add, pinceau 3).
	_ecran._choisir_outil("ajouter")
	var vue = _ecran._vue
	vue._cible = Vector3(haut) + Vector3(0.5, 0.5, 0.5)
	vue._distance = 40.0
	vue._caler()
	var taille: Vector2 = vue.size
	await _mesurer("survol : 20 mouvements de souris", func():
		for k in 20:
			vue._survoler(Vector2(taille.x * (0.3 + 0.02 * k), taille.y * 0.5)))
	await _mesurer("poser UNE case", func(): _ecran._appliquer({"poser": {neuve: true}, "effacer": {}}, "Add"))
	await _mesurer("Ctrl+Z", func(): _ecran._histoire.undo())
	await _mesurer("Ctrl+Y", func(): _ecran._histoire.redo())
	await _mesurer("Ctrl+Z", func(): _ecran._histoire.undo())
	# UN COUP DE PINCEAU : 20 touches d'une case chacune, comme un glissé.
	await _mesurer("coup de pinceau : 20 touches", func():
		_ecran._coup_commence()
		for k in 20:
			_ecran._touche({"poser": {neuve + Vector3i(k, 0, 0): true}, "effacer": {}}, "Add")
		_ecran._coup_fini())
	await _mesurer("Ctrl+Z du coup", func(): _ecran._histoire.undo())
	# UNE BOÎTE de 8 × 4 × 8 = 256 cases.
	var boite := {}
	for x in 8:
		for y in 4:
			for z in 8:
				boite[neuve + Vector3i(x, y, z)] = true
	await _mesurer("boîte de 256 cases", func(): _ecran._appliquer({"poser": boite, "effacer": {}}, "Add"))
	await _mesurer("Ctrl+Z de la boîte", func(): _ecran._histoire.undo())
	# LES COUCHES : changer, cacher, montrer.
	if _ecran._couches.size() > 1:
		await _mesurer("activer la couche 2", func(): _ecran._activer(1))
		await _mesurer("activer la couche 1", func(): _ecran._activer(0))
		await _mesurer("cacher la couche 2", func(): _ecran._montrer_couche(1, false))
		await _mesurer("montrer la couche 2", func(): _ecran._montrer_couche(1, true))
	# L'EAU : une mer au ras du monde, puis un geste loin d'elle et un geste dedans.
	var b: Dictionary = preload("res://addons/marchingblocks_core/fluides.gd").boite(_ecran._occupees_du_monde())
	var lo: Vector3i = b["lo"]
	await _mesurer("atelier Fluids", func(): _ecran._changer_d_atelier("fluides"))
	await _mesurer("poser une mer (niveau bas + 4)", func(): _ecran._eau_cliquee(Vector3i(lo.x, lo.y + 4, lo.z), MOUSE_BUTTON_LEFT))
	await _mesurer("retour dans World", func(): _ecran._changer_d_atelier("monde"))
	await _mesurer("poser une case en haut (eau présente)", func():
		_ecran._appliquer({"poser": {neuve: true}, "effacer": {}}, "Add"))
	await _mesurer("Ctrl+Z (eau présente)", func(): _ecran._histoire.undo())
	await _mesurer("coup de pinceau 20 touches (eau présente)", func():
		_ecran._coup_commence()
		for k in 20:
			_ecran._touche({"poser": {neuve + Vector3i(k, 0, 0): true}, "effacer": {}}, "Add")
		_ecran._coup_fini())
	await _mesurer("Ctrl+Z du coup (eau présente)", func(): _ecran._histoire.undo())
	# LES ATELIERS.
	await _mesurer("aller dans Geometry", func(): _ecran._changer_d_atelier("witness"))
	await _mesurer("revenir dans World", func(): _ecran._changer_d_atelier("monde"))
	await _mesurer("Ctrl+S", func(): _ecran._enregistrer_tout())
	_rendre_les_reglages()
	quit(0)


func _rendre_les_reglages() -> void:
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
		DirAccess.remove_absolute(SAUVEGARDE)


func _mesurer(nom: String, geste: Callable) -> void:
	await process_frame
	var t0 := Time.get_ticks_usec()
	await geste.call()
	var t_geste := (Time.get_ticks_usec() - t0) / 1000.0
	var pire := 0.0
	var somme := 0.0
	var avant := Time.get_ticks_usec()
	for k in 30:
		await process_frame
		var maintenant := Time.get_ticks_usec()
		var d := (maintenant - avant) / 1000.0
		avant = maintenant
		pire = maxf(pire, d)
		somme += maxf(0.0, d - 16.7)
	print("%-46s geste %8.1f ms · pire image %7.1f ms · retard %8.1f ms" % [nom, t_geste, pire, somme])
