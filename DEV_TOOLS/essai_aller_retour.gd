extends SceneTree
##
## L'ESSAI D'ALLER-RETOUR — exporter le MasterBlockSet, le relire, et vérifier que RIEN n'a bougé.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/essai_aller_retour.gd -- --dossier=C:/chemin/hors/du/projet
##
## ── CE QU'IL PROUVE, ET CE QU'IL NE PROUVE PAS ──────────────────────────────────────────────────────
##
## Jordan, 24 septembre : *« exporter ce MasterBlockSet vers la position du disque dur que l'on veut,
## le modéliser dans Blender, le réimporter, le passer au pipeline, et peindre avec pour constater que
## TOUT reste exact. »*
##
## Cet outil fait l'aller-retour SANS Blender : export → relecture → tranchage → comparaison. Si la
## chaîne perd quelque chose toute seule, ça se voit ici, avant qu'un artiste y passe des jours.
##
## ⚠ **CE QU'IL NE PROUVE PAS : que le mesh est identique au bit près.** Un `.glb` retriangule, réordonne
## et peut fusionner des surfaces. Exiger l'égalité binaire ferait rougir un test sur une propriété que
## personne ne veut. **Ce qui doit rester exact, c'est ce dont le pavage dépend** :
##
##   • les MÊMES classes sont récoltées — ni une de plus, ni une de moins ;
##   • aucune classe ne manque à la bibliothèque ;
##   • aucune erreur de tranchage n'apparaît au retour qui n'existait pas à l'aller ;
##   • les neuf blocs sont bien relus depuis le disque, et non silencieusement remplacés par leur
##     version calculée — c'est le piège : l'import retomberait sur le témoin et tout semblerait bien.
##
## ⚠ **LE DOSSIER EST HORS DE `res://` EXPRÈS.** Un `.glb` dans le projet passe par l'importateur de
## Godot ; hors du projet, il faut `GLTFDocument.append_from_file()`. C'est le cas réel — celui où
## l'artiste range son travail où il veut — et c'est donc celui qu'on éprouve.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

var _dossier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--dossier="):
			_dossier = option.substr("--dossier=".length())
	if _dossier == "":
		print("il faut --dossier=<chemin hors du projet>")
		quit(1)
		return

	print("=== ALLER-RETOUR DU MASTERBLOCKSET ===\n")
	print("dossier : %s\n" % _dossier)

	var fautes: Array = BlocsMaitres.anomalies()
	if not fautes.is_empty():
		print("REFUSÉ — %d anomalie(s) dans les blocs maîtres" % fautes.size())
		for f in fautes:
			print("   • %s" % f)
		quit(1)
		return

	if not DirAccess.dir_exists_absolute(_dossier):
		var err := DirAccess.make_dir_recursive_absolute(_dossier)
		if err != OK:
			print("impossible de créer « %s » (erreur %d)" % [_dossier, err])
			quit(1)
			return

	# ── 1. L'ALLER : le catalogue, tel que le greffon le construit aujourd'hui ───────────────────────
	var aller: Dictionary = BlocsMaitres.librairie()
	var classes_aller: Array = _noms(aller["lot"])
	print("── ALLER (catalogue) ──")
	print("   %d item(s), %d manquante(s), %d erreur(s) de tranchage"
		% [classes_aller.size(), (aller["manquantes"] as Array).size(),
			(aller["erreurs"] as Array).size()])

	# ── 2. L'EXPORT — UN SEUL BLOC DANS UN `.glb` ────────────────────────────────────────────────────
	# ⚠ Une BANDE a vécu ici : neuf blocs alignés au pas de six cases, parce qu'un seul fichier devait
	# les transporter tous. Avec un bloc unique il n'y a rien à aligner — il est à l'origine, et c'est
	# sa POSITION qui l'identifie au retour, jamais son nom.
	var fichier: String = _dossier.path_join("masterblock.glb")
	var raison: String = BlocsMaitres.exporter_le_bloc(fichier)
	print("\n── EXPORT (le bloc) ──")
	if raison != "":
		print("   ÉCHEC : %s" % raison)
		quit(1)
		return
	var taille: int = FileAccess.get_file_as_bytes(fichier).size()
	print("   écrit → %s  (%d octets)" % [fichier, taille])
	print("   bloc de %d³, débord toléré : %.2f case"
		% [BlocsMaitres.COTE, BlocsMaitres.DEBORD_TOLERE])

	# ── 3. LE RETOUR : on relit le bloc depuis le disque ────────────────────────────────────────────
	var retour: Dictionary = BlocsMaitres.librairie_depuis_glb(fichier)
	var classes_retour: Array = _noms(retour["lot"])
	print("\n── RETOUR (relu depuis le disque) ──")
	print("   %d bloc(s) réellement relu(s) : %s"
		% [(retour["sculptes"] as Array).size(),
			", ".join(PackedStringArray(retour["sculptes"]))])
	if not (retour["absents"] as Array).is_empty():
		print("   ⚠ %d bloc(s) NON relu(s), version calculée gardée : %s"
			% [(retour["absents"] as Array).size(),
				", ".join(PackedStringArray(retour["absents"]))])
	print("   %d item(s), %d manquante(s), %d erreur(s) de tranchage"
		% [classes_retour.size(), (retour["manquantes"] as Array).size(),
			(retour["erreurs"] as Array).size()])
	for e in (retour["erreurs"] as Array).slice(0, 6):
		print("      • %s" % String(e).left(150))

	# ── 4. LA COMPARAISON ───────────────────────────────────────────────────────────────────────────
	var perdues: Array = []
	var gagnees: Array = []
	var au_retour := {}
	for n in classes_retour:
		au_retour[n] = true
	var a_l_aller := {}
	for n in classes_aller:
		a_l_aller[n] = true
	for n in classes_aller:
		if not au_retour.has(n):
			perdues.append(n)
	for n in classes_retour:
		if not a_l_aller.has(n):
			gagnees.append(n)

	print("\n── COMPARAISON ──")
	print("   classes à l'aller : %d      au retour : %d" % [classes_aller.size(),
		classes_retour.size()])
	if perdues.is_empty() and gagnees.is_empty():
		print("   les DEUX jeux de classes sont IDENTIQUES")
	else:
		if not perdues.is_empty():
			print("   ⚠ %d PERDUE(S) au retour : %s"
				% [perdues.size(), ", ".join(PackedStringArray(perdues.slice(0, 10)))])
		if not gagnees.is_empty():
			print("   ⚠ %d APPARUE(S) au retour : %s"
				% [gagnees.size(), ", ".join(PackedStringArray(gagnees.slice(0, 10)))])

	# ⚠ ET LE PIÈGE PRINCIPAL : un import qui retombe sur le témoin rendrait tout « exact » sans avoir
	# rien relu. On exige donc que les NEUF aient été lus depuis le disque.
	var tout_relu: bool = (retour["absents"] as Array).is_empty()
	var tout_exact: bool = perdues.is_empty() and gagnees.is_empty() \
		and (retour["manquantes"] as Array).is_empty() \
		and (retour["erreurs"] as Array).is_empty() and tout_relu

	print("\nVERDICT : %s" % ("TOUT RESTE EXACT" if tout_exact else "quelque chose a bougé"))
	if not tout_relu:
		print("   ⚠ et surtout : tous les blocs n'ont pas été relus du disque — l'essai ne vaut rien")
	quit(0 if tout_exact else 1)


func _noms(lot: MeshLibrary) -> Array:
	var sortie: Array = []
	for id in lot.get_item_list():
		sortie.append(lot.get_item_name(id))
	sortie.sort()
	return sortie
