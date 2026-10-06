extends RefCounted
##
## L'ÎLE FILMÉE — construite par les VRAIS gestes de l'appli (`_appliquer` par couche, la réparation des contacts
## diagonaux, l'eau par `_eau_cliquee`), sur l'exemple livré vidé (pour ses trois témoins : GreyRock, Grass, Desert).
## Un volcan et son lac de lave, un plateau et son lac retenu par un bouchon de roche, un marais, des plages, la mer.
## Partagée par les tournages (`filmer_trailer.gd`, `filmer_ui.gd`) : une règle, un endroit.

const Projet := preload("res://app/projet.gd")

## L'ÎLE — une règle, un endroit : tous les lieux du monde filmé.
const MER := 5                            # le niveau de la mer
const RAYON := 34.0                       # le rayon de l'île
const VOLCAN := Vector2i(15, -13)
const LAC := Vector2i(-12, 6)             # le lac du plateau
const PLATEAU := 17                       # le bord du lac
const CHENAL_X := -12                     # le chenal part du lac vers le nord (z croissant)
const BOUCHON := [12, 13]                 # les z du bouchon de roche qui retient le lac
const MARAIS := Vector2i(14, 15)

var _arbre: SceneTree
var _ecran
var _couche: Dictionary
var _bruit := FastNoiseLite.new()


func _init(arbre: SceneTree, ecran, couche: Dictionary) -> void:
	_arbre = arbre
	_ecran = ecran
	_couche = couche


func construire() -> void:
	var t0 := Time.get_ticks_msec()
	# Vider l'exemple : ses cases, puis ses eaux.
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	await _images(2)

	_bruit.seed = 7
	_bruit.frequency = 0.045
	_bruit.fractal_octaves = 4
	var par_couche := {"GreyRock": {}, "Grass": {}, "Desert": {}}
	var n := int(RAYON) + 4
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var h := hauteur(x, z)
			if h < 0:
				continue
			var dessus := dessus(x, z, h)
			for y in range(0, h + 1):
				var nom := "GreyRock"
				if y > h - (2 if dessus == "Desert" else 1):
					nom = dessus
				par_couche[nom][Vector3i(x, y, z)] = true
	for nom in par_couche:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": par_couche[nom], "effacer": {}}, "Add")
		print("couche %s : %d cases" % [nom, par_couche[nom].size()])
	# Les contacts diagonaux qui resteraient : le vrai bouton « Fix diagonal contacts · Fill », dans la roche.
	_ecran._activer(_couche["GreyRock"])
	_ecran._reparer_les_diagonales(false)
	await _images(2)

	# L'EAU, par le vrai clic de l'atelier Fluids : la mer (épinglée puis posée), le lac, le marais, la lave.
	_ecran._changer_d_atelier("fluides")
	var large := Vector3i(int(RAYON) + 3, MER, 0)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "transparent"
	_ecran._eau_cliquee(Vector3i(LAC.x, PLATEAU - 2, LAC.y), MOUSE_BUTTON_LEFT)
	_nouvelle_eau("Swamp", "marais")
	_ecran._eau_cliquee(Vector3i(MARAIS.x, MER + 1, MARAIS.y), MOUSE_BUTTON_LEFT)
	_nouvelle_eau("Lava", "lave")
	_ecran._eau_cliquee(Vector3i(VOLCAN.x, 26, VOLCAN.y), MOUSE_BUTTON_LEFT)
	for e in _ecran._eaux:
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._recalculer_eau(false)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	print("l'île est construite en %d ms" % (Time.get_ticks_msec() - t0))


func _nouvelle_eau(nom: String, preset: String) -> void:
	var etat := Projet.couche_d_eau(nom)
	etat["preset"] = preset
	_ecran._ajouter_eau(etat)


## La hauteur du dessus de la colonne (x, z) ; -1 : pas de terre.
func hauteur(x: int, z: int) -> int:
	var p := Vector2(x, z)
	var b := _bruit.get_noise_2d(x, z)
	var r := p.length() / RAYON + b * 0.12
	if r > 1.0:
		return -1
	var h := pow(1.0 - r, 0.7) * 16.0 + b * 4.0
	# Le nord du chenal finit en FALAISE au-dessus de la mer : la cascade y tombe.
	if absf(x - CHENAL_X) < 9 and z > 10 and r < 0.97:
		h = maxf(h, 11.0 + b * 2.0)
	# Le volcan, et son cratère.
	var dv := p.distance_to(Vector2(VOLCAN))
	if dv < 11.0:
		h = maxf(h, 31.0 * pow(1.0 - dv / 11.0, 0.9) + 4.0)
		if dv < 3.2:
			h = 25.0
		elif dv < 4.2:
			# ⚠ UNE LÈVRE CONTINUE (marchingblocks-76, 5 octobre 2026) : sans elle, huit cases isolées à 26 se
			# touchaient par une arête — des contacts diagonaux, et leurs cubes rouges au bord du cratère.
			h = maxf(h, 27.0)
	# Le plateau du lac : un bord à PLATEAU, une cuvette au milieu.
	var dl := p.distance_to(Vector2(LAC))
	if dl < 10.0:
		var plat := lerpf(float(PLATEAU), h, clampf((dl - 7.5) / 2.5, 0.0, 1.0))
		h = maxf(h, plat) if dl >= 7.5 else float(PLATEAU)
		if dl < 5.0:
			h = PLATEAU - 4
	# Le chenal : du bord du lac vers le nord, en pente douce ; le BOUCHON reste plein (on l'ouvrira au plan 4).
	if absi(x - CHENAL_X) <= 1 and z > LAC.y + 4 and z < 34:
		if not BOUCHON.has(z):
			h = minf(h, lerpf(float(PLATEAU - 4), 9.0, clampf((z - 10) / 18.0, 0.0, 1.0)))
	# Le marais : une cuvette basse, bordée.
	var dm := p.distance_to(Vector2(MARAIS))
	if dm < 6.5:
		h = MER + 3 if dm >= 4.5 else MER
	return int(round(h))


## La couche du dessus : la plage au ras de l'eau, la roche sur le volcan et les pentes raides, l'herbe ailleurs.
func dessus(x: int, z: int, h: int) -> String:
	if Vector2(x, z).distance_to(Vector2(VOLCAN)) < 11.0:
		return "GreyRock"
	if h <= MER + 1:
		return "Desert"
	var pente := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var hv := hauteur(x + d.x, z + d.y)
		pente = maxi(pente, absi(h - hv) if hv >= 0 else h)
	return "GreyRock" if pente >= 4 else "Grass"


func _images(n: int) -> void:
	for i in n:
		await _arbre.process_frame
