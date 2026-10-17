extends "res://DEV_TOOLS/filmer_haut.gd"
##
## DEVLOG — UNE STATION SPATIALE, DANS UN PROJET NEUF « scifi » QU'ON GARDE. Demandé par Jordan (6 octobre 2026) : « un
## nouveau mbproject "scifi" que l'on gardera pour la suite, dans lequel tu places plusieurs types bien réfléchis de
## textures scifi de station spatiale futuriste avec du glow dans certaines parties, et tu works une station entière avant
## de traverser ses rooms cubiques et ses couloirs droits, en Play test avec un ciel noir et le fog. »
##
## ⚠ CE QUE LE LOGICIEL IMPOSE (relevé le 6 octobre 2026) :
##   - un projet = un .mbproj (couches, eaux) et, à côté, le .mbtiles et le .glb du témoin de chaque couche, et ses images
##     copiées dans `<projet>_layer<id>_images/`. Les chemins y sont ABSOLUS : le projet se bâtit à sa place finale,
##     `Documents/MarchingBlocks/scifi/` (choix de Jordan : « avec tes projets »), et se refait neuf à chaque tournage ;
##   - un témoin porte PLUSIEURS matériaux, choisis face par face : on les assigne par l'orientation de la face (sol,
##     mur, plafond), sur les 52 tuiles du témoin calculé — des cubes nets, sans biseau : des panneaux de station ;
##   - projection Box, échelle 1 : une image par case ; son ensemble PBR (normal, roughness, metallic, ao, EMISSION) est
##     lu à côté de l'albedo (`01_scripts/textures_scifi.py` dans SpannerGames, `BIBLIOTHEQUE/textures/scifi/`) ;
##   - l'émission des textures : écrite dans le produit par marchingblocks-bf à la demande de Jordan (6 octobre 2026) ;
##   - deux couches côte à côte au même niveau font des carrés (devlog vu de haut) : les SALLES ont leur sol une case
##     plus bas que les couloirs, et le seuil des portes est en coque (Hull) ;
##   - le stickman naît AU-DESSUS de la plus haute case de la colonne visée : dans une station fermée, sur le toit. Il naît
##     donc sur une PLATEFORME D'AMARRAGE à ciel ouvert, et entre par le sas.
##
## LANCEMENT — dans la COPIE de tournage :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/copies/tournage_figee --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/scifi.avi --script res://DEV_TOOLS/filmer_scifi.gd
##   `-- --seulement=<partie>` : textures, station, jeu (le projet est toujours refait : textures et station).
##   ⚠ `-- --refaire` est OBLIGATOIRE si `Documents/MarchingBlocks/scifi/` existe déjà : le projet est celui de Jordan.

const DOSSIER_SCIFI := "C:/Users/jorda/Documents/MarchingBlocks/scifi"
const PROJET_SCIFI := DOSSIER_SCIFI + "/scifi.mbproj"
const TEXTURES := "D:/SpannerGames/BIBLIOTHEQUE/textures/scifi"
## Les couches et leurs trois matériaux (sol, mur, plafond) ; la force d'émission de chacun.
const COUCHES_SCIFI := [
	{"nom": "Hull", "sol": "hull_floor", "mur": "hull_wall", "plafond": "hull_ceiling", "metal": 0.8, "rugosite": 0.45},
	{"nom": "Lab", "sol": "lab_floor", "mur": "lab_wall", "plafond": "lab_ceiling", "metal": 0.1, "rugosite": 0.3},
	{"nom": "Reactor", "sol": "reactor_floor", "mur": "reactor_wall", "plafond": "reactor_ceiling", "metal": 0.85, "rugosite": 0.45},
]
## LA STATION — des boîtes [x0, y0, z0, x1, y1, z1] d'INTÉRIEUR (le vide) ; les murs, le sol et le plafond les
## entourent d'une case. Les couloirs : 3 de large, 3 de haut, sol à y = 0. Les salles : sol une case plus bas (y = -1).
const PLATEFORME := [-40, 1, -5, -31, 1, 5]          # à ciel ouvert : un pont et un rebord, pas de plafond
const SAS := [-31, 1, -1, -20, 3, 1]
const HUB := [-19, 1, -4, -11, 5, 4]
const COULOIR_NORD := [-16, 1, -15, -14, 3, -5]
const LAB_A := [-20, 0, -25, -10, 5, -16]
const EPINE := [-11, 1, -1, 10, 3, 1]
const COULOIR_SUD := [-1, 1, 2, 1, 3, 9]
const LAB_B := [-5, 0, 10, 5, 5, 19]
const REACTEUR := [11, 0, -7, 24, 8, 7]
const COEUR := [16, 0, -1, 18, 8, 1]                 # le pilier d'énergie au centre du réacteur (plein)
## L'ordre où la station se bâtit à l'image, et la couche de chaque module.
const MODULES := [
	["Docking pad", PLATEFORME, "Hull", "pont"], ["Airlock", SAS, "Hull", "couloir"], ["Hub", HUB, "Hull", "salle_haut"],
	["North corridor", COULOIR_NORD, "Hull", "couloir"], ["Lab A", LAB_A, "Lab", "salle"],
	["The spine", EPINE, "Hull", "couloir"], ["South corridor", COULOIR_SUD, "Hull", "couloir"], ["Lab B", LAB_B, "Lab", "salle"],
	["Reactor", REACTEUR, "Reactor", "salle"],
]

var _cases_scifi := {}             # Vector3i → nom de couche, la station finale
var _module_de := {}               # Vector3i → indice du module qui l'a posée (l'ordre d'apparition)


func _initialize() -> void:
	super._initialize()


func _derouler() -> void:
	await _images(30)
	if not _preparer_le_projet():
		return
	await _ecran._ouvrir(PROJET_SCIFI)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	print("couches : %s" % [_couche])
	_aides()
	for partie in ["textures", "station", "jeu"]:
		if _seulement != "" and _seulement != partie and not partie in ["textures", "station"]:
			continue
		_plan(partie)
		await Callable(self, "_s_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_ecran._enregistrer()
	_rendre_les_reglages()
	quit(0)


## Le projet neuf, à sa place finale : trois couches vides (Hull, Lab, Reactor), aucune eau. Le dossier est vidé d'abord.
func _preparer_le_projet() -> bool:
	# ⚠ CE PROJET EST À JORDAN, IL LE GARDE (6 octobre 2026) : un nouveau tournage ne l'écrase que demandé
	# (`-- --refaire`), sinon le script s'arrête — ses retouches à la main ne doivent pas disparaître sans un mot.
	if FileAccess.file_exists(PROJET_SCIFI) and not "--refaire" in OS.get_cmdline_user_args():
		print("⚠ %s existe : le projet de Jordan n'est pas écrasé (relancer avec -- --refaire pour le refaire)" % PROJET_SCIFI)
		_rendre_les_reglages()
		quit(1)
		return false
	_vider(DOSSIER_SCIFI)
	DirAccess.make_dir_recursive_absolute(DOSSIER_SCIFI)
	var couches := []
	for i in COUCHES_SCIFI.size():
		couches.append({"nom": COUCHES_SCIFI[i]["nom"], "source": "", "visible": true, "cases": [], "temoin": "",
			"id": str(i + 1)})
	var f := FileAccess.open(PROJET_SCIFI, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 2, "active": 0,
		"couches": couches, "eaux": []}, "\t"))
	f.close()
	print("projet neuf : %s" % PROJET_SCIFI)
	return true


# ── 1. LES TEXTURES : trois couches, trois matériaux chacune ─────────────────────────────────────────

func _s_textures() -> void:
	for i in COUCHES_SCIFI.size():
		var d: Dictionary = COUCHES_SCIFI[i]
		_ecran._activer(_couche[d["nom"]])
		await _ecran._changer_d_atelier("texture")
		_ecran._regler_edition(true)
		await _images(20)
		var mo = _ecran._modeleur
		var t = mo.temoin
		var ks := {}
		for role in ["sol", "mur", "plafond"]:
			var k: int = mo.nouveau_materiau()
			var nom: String = d[role]
			_montrer("Layer %s" % d["nom"], {"sol": "Floor", "mur": "Walls", "plafond": "Ceiling"}[role] + " · " + nom)
			_ecran._action_fichier = "texture"
			_ecran._fichier_choisi("%s/%s/%s_albedo.png" % [TEXTURES, nom, nom])
			mo.regler_materiau(k, "nom", nom)
			mo.regler_materiau(k, "echelle", 1.0)
			mo.regler_materiau(k, "projection", "boite")
			mo.regler_materiau(k, "metal", d["metal"])
			mo.regler_materiau(k, "rugosite", d["rugosite"])
			_regler_l_emission(mo, k)
			ks[role] = k
			await _images(int(0.6 * FPS))
		# Chaque face, selon son orientation : le dessus est un sol, le dessous un plafond, le reste un mur.
		var n := 0
		for cle in t.tuiles:
			var tu = t.tuiles[cle]
			var par := {"sol": [], "mur": [], "plafond": []}
			for f in tu.faces.size():
				var ny: float = tu.normale(f).y
				par["sol" if ny > 0.7 else ("plafond" if ny < -0.7 else "mur")].append(f)
				n += 1
			for role in par:
				if not (par[role] as Array).is_empty():
					tu.assigner(par[role], ks[role])
		mo.redessiner()
		mo._rafraichir_les_tuiles_qui_portent(-2)
		_ecran._temoin_modifie(t)
		_montrer("Layer %s" % d["nom"], "Floor, walls, ceiling: by face direction")
		await _orbite_temoin(2.5)
		_ecran._enregistrer_le_temoin_modele(true)
		_ecran._regler_edition(false)
		print("couche %s : %d faces texturées, matériaux %s" % [d["nom"], n, ks])
	await _ecran._changer_d_atelier("monde")


## La force de l'émission d'un matériau. ⚠ La clé est celle du produit (marchingblocks-bf, 6 octobre 2026).
func _regler_l_emission(mo, k: int) -> void:
	mo.regler_materiau(k, "emission", 4.0)


func _orbite_temoin(duree: float) -> void:
	var az: float = _vue._azimut
	for i in int(duree * FPS):
		_vue._azimut = az + 0.5 * _doux(i / (duree * FPS))
		_vue._caler()
		await _images(1)


# ── 2. LA STATION : module par module ───────────────────────────────────────────────────────────────

func _s_station() -> void:
	_concevoir()
	_poser_camera(Vector3(-8, 2, -3), 0.7, 0.55, 62.0)
	await _images(10)
	for m in MODULES.size():
		var par_couche := {}
		for c in _module_de:
			if _module_de[c] == m:
				var nom: String = _cases_scifi[c]
				if not par_couche.has(nom):
					par_couche[nom] = {}
				par_couche[nom][c] = true
		_montrer(MODULES[m][2], MODULES[m][0])
		for nom in par_couche:
			_ecran._activer(_couche[nom])
			_ecran._appliquer({"poser": par_couche[nom], "effacer": {}}, "Add")
		await _tourner(1.1)
	var details := {}
	for c in _module_de:
		if _module_de[c] == MODULES.size():
			details[c] = true
	_montrer("Hull", "Solar wings, an antenna, portholes")
	_ecran._activer(_couche["Hull"])
	_ecran._appliquer({"poser": details, "effacer": {}}, "Add")
	var trous := {}
	for z in range(-24, -16, 2):
		for y in [2, 3]:
			trous[Vector3i(-21, y, z)] = true
	_ecran._activer(_couche["Lab"])
	_ecran._appliquer({"poser": {}, "effacer": trous}, "Dig")
	await _tourner(1.5)
	for nom in _couche:
		_ecran._activer(_couche[nom])
		await _ecran._reparer_les_diagonales(false)
	_ecran._activer(_couche["Hull"])
	_montrer("World", "A whole station: cubic rooms, straight corridors")
	await _tourner(3.0)
	print("station : %d cases" % _cases_scifi.size())


func _tourner(duree: float) -> void:
	for i in int(duree * FPS):
		_vue._azimut += 0.004
		_vue._caler()
		await _images(1)


## La station, case par case : chaque module pose sa coque (l'intérieur agrandi d'une case), puis TOUS les intérieurs
## sont vidés, couloirs prolongés d'une case dans les murs des salles (les portes). Le seuil et le linteau d'une porte
## sont en coque : la matière ne change pas au même niveau.
func _concevoir() -> void:
	_cases_scifi.clear()
	_module_de.clear()
	var vides := {}
	for m in MODULES.size():
		var b: Array = MODULES[m][1]
		var nom: String = MODULES[m][2]
		var genre: String = MODULES[m][3]
		var haut: int = b[4] + (0 if genre == "pont" else 1)
		for x in range(b[0] - 1, b[3] + 2):
			for z in range(b[2] - 1, b[5] + 2):
				for y in range(b[1] - 1, haut + 1):
					var c := Vector3i(x, y, z)
					# Les couloirs écrasent les murs des salles qu'ils percent (le cadre de la porte est en coque).
					if _cases_scifi.has(c) and genre != "couloir":
						continue
					_cases_scifi[c] = nom
					_module_de[c] = m
		var vide := b.duplicate()
		if genre == "couloir":
			# Le couloir perce d'une case les murs de part et d'autre, dans son axe.
			if b[3] - b[0] > b[5] - b[2]:
				vide[0] -= 1
				vide[3] += 1
			else:
				vide[2] -= 1
				vide[5] += 1
		for x in range(vide[0], vide[3] + 1):
			for z in range(vide[2], vide[5] + 1):
				for y in range(vide[1], vide[4] + 1):
					vides[Vector3i(x, y, z)] = true
		if genre == "pont":
			# Le pont : un rebord d'une case sur trois côtés, ouvert vers le sas (à l'est).
			for x in range(b[0] - 1, b[3] + 2):
				for z in range(b[2] - 1, b[5] + 2):
					var bord: bool = x == b[0] - 1 or z == b[2] - 1 or z == b[5] + 1
					if not bord:
						vides[Vector3i(x, b[1], z)] = true
	for c in vides:
		_cases_scifi.erase(c)
		_module_de.erase(c)
	# LES DÉTAILS DU DEHORS (essai du 6 octobre 2026 : vue de dehors, la station n'était que des boîtes) : deux ailes
	# solaires d'une case d'épaisseur sur des mâts, une antenne sur le hub, des hublots dans le mur ouest du labo A.
	var d := MODULES.size()
	for cote in [-1, 1]:
		for z in range(9, 22):
			var zz: int = cote * z
			_cases_scifi[Vector3i(17, 5, zz)] = "Hull"          # le mât
			_module_de[Vector3i(17, 5, zz)] = d
			if z >= 11:
				for x in range(12, 23):
					var c := Vector3i(x, 6, zz)
					_cases_scifi[c] = "Hull"
					_module_de[c] = d
	for y in range(7, 14):
		_cases_scifi[Vector3i(-15, y, 0)] = "Hull"
		_module_de[Vector3i(-15, y, 0)] = d
	for x in range(-17, -12):
		_cases_scifi[Vector3i(x, 12, 0)] = "Hull"
		_module_de[Vector3i(x, 12, 0)] = d
	for z in range(-24, -16, 2):
		for y in [2, 3]:
			_cases_scifi.erase(Vector3i(-21, y, z))
			_module_de.erase(Vector3i(-21, y, z))
	# Le cœur du réacteur : un pilier plein, en Reactor.
	for x in range(COEUR[0], COEUR[3] + 1):
		for z in range(COEUR[2], COEUR[5] + 1):
			for y in range(COEUR[1], COEUR[4] + 1):
				var c := Vector3i(x, y, z)
				_cases_scifi[c] = "Reactor"
				_module_de[c] = MODULES.size() - 1


# ── 3. LE JEU : ciel noir, brouillard, glow ; la traversée ──────────────────────────────────────────

func _s_jeu() -> void:
	var p0 := Vector3((PLATEFORME[0] + PLATEFORME[3]) * 0.5 + 0.5, 1, 0.5)
	_vue._cible = p0
	_cam_haut = false
	_cam_d = 3.0
	_cam_e = 0.28
	# Le rendu de l'espace : AVANT d'entrer (commencer_partie réapplique tout).
	for r in [["ciel_haut", Color.BLACK], ["ciel_horizon", Color.BLACK], ["ciel_sol", Color.BLACK],
			["soleil_disque", false], ["soleil_energie", 0.6], ["soleil_hauteur", 35.0], ["soleil_couleur", Color("#9fb4ff")],
			["ambiante_couleur", Color("#3a4660")], ["ambiante_energie", 1.6], ["ssao", false], ["ssil", false],
			["glow", true], ["glow_intensite", 1.3], ["brouillard", true], ["brouillard_densite", 0.035],
			["brouillard_couleur", Color("#0a1020")], ["exposition", 1.15]]:
		_vue.regler_rendu(r[0], r[1])
	await _cliquer_bouton("Play test", "Play test: black sky, fog, glow")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.3)
	await _images(int(1.5 * FPS))
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	_vue._azimut = PI * 0.5   # regarder vers l'est, le sas
	await _regarder_autour(3.0)
	var y := 1.0
	await _aller([Vector3(-30.5, y, 0.5), Vector3(-20.5, y, 0.5), Vector3(-14.5, y, 0.5)], "W A S D", "Through the airlock")
	await _aller([Vector3(-14.5, y, -4.5), Vector3(-14.5, y, -15.5), Vector3(-14.5, 0, -21.5)], "W A S D",
		"North, to the lab")
	await _regarder_autour(3.5)
	await _aller([Vector3(-14.5, y, -15.5), Vector3(-14.5, y, -0.5), Vector3(-10.5, y, 0.5), Vector3(0.5, y, 0.5)],
		"Space", "Back up, and along the spine", true)
	await _aller([Vector3(0.5, y, 9.0), Vector3(0.5, 0, 14.5)], "W A S D", "The second lab")
	await _regarder_autour(3.0)
	await _aller([Vector3(0.5, y, 9.0), Vector3(0.5, y, 0.5), Vector3(10.5, y, 0.5), Vector3(13.5, 0, 4.5)],
		"Space", "And into the reactor", true)
	await _aller([Vector3(20.5, 0, 4.5), Vector3(20.5, 0, -4.5), Vector3(13.5, 0, -4.5), Vector3(13.5, 0, 3.5)],
		"W A S D", "Around the core")
	_cam_d = 6.0
	_cam_e = 0.5
	await _regarder_autour(4.0)
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
