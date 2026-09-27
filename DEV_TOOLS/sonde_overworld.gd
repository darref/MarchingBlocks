extends SceneTree

## SONDE — CE QUE LE MONDE PEINT DE JORDAN CONTIENT DÉJÀ, ET CE QUE LA NOUVELLE RÈGLE LUI FERAIT.
##
## ⚠ **LA QUESTION EST DE JORDAN (25 septembre 2026)** : « tu parles du paysage que j'ai dessiné dans
## overworld ? si c'est ça je le complète jusqu'à avoir toutes les tuiles ». Sa proposition remplace le
## témoin que j'avais dessiné : un paysage RÉELLEMENT peint, complété jusqu'à couvrir, au lieu d'une
## grille imaginée pour couvrir. La charte dit « la main tient la FORME » ; là, la main tient tout, et
## la machine ne fait plus que dire ce qui manque.
##
## ⚠ **CE QU'ELLE DOIT DIRE AVANT QU'IL PEIGNE, PAS APRÈS** :
##   1. combien des 52 tuiles du monde sans diagonale son monde couvre DÉJÀ ;
##   2. **combien de cases la règle de complétion lui retirerait** — sa peinture a été faite sous le
##      modèle à 90 tuiles, qui autorise les contacts diagonaux. Basculer MODIFIERAIT son travail
##      existant, et il doit connaître l'ampleur avant de dire oui ;
##   3. l'étendue, parce qu'un monde entier ne part pas dans un `.glb` de travail.
##
## ⚠ **ELLE NE MODIFIE RIEN.** La complétion est appliquée à une COPIE ; le fichier de Jordan n'est
## jamais touché, et la sonde ne sait pas écrire.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")

const SCENE := "res://NIVEAUX/OverWorld/Overworld.tscn"


func _initialize() -> void:
	print("=== LE MONDE PEINT DE JORDAN ===\n")
	var paquet: PackedScene = load(SCENE)
	if paquet == null:
		print("⚠ illisible : %s" % SCENE)
		quit(1)
		return
	var racine: Node = paquet.instantiate()
	var grilles: Array = []
	_trouver(racine, grilles)
	if grilles.is_empty():
		print("⚠ aucune grille « Cases » trouvée")
		quit(1)
		return

	var tout := {}
	for g in grilles:
		var grille: GridMap = g
		var pleines := {}
		for c in grille.get_used_cells():
			pleines[c as Vector3i] = true
			tout[c as Vector3i] = true
		print("── %s ──" % grille.get_parent().name)
		_dire(pleines)
	if grilles.size() > 1:
		print("── LES DEUX ENSEMBLE ──")
		_dire(tout)
	racine.free()
	quit(0)


func _trouver(n: Node, sortie: Array) -> void:
	if n is GridMap and n.name == "Cases":
		sortie.append(n)
	for e in n.get_children():
		_trouver(e, sortie)


func _dire(pleines: Dictionary) -> void:
	if pleines.is_empty():
		print("   (vide)\n")
		return
	var mini := Vector3i(2147483647, 2147483647, 2147483647)
	var maxi := Vector3i(-2147483648, -2147483648, -2147483648)
	for c in pleines:
		var p: Vector3i = c
		mini = Vector3i(mini_de(mini.x, p.x), mini_de(mini.y, p.y), mini_de(mini.z, p.z))
		maxi = Vector3i(maxi_de(maxi.x, p.x), maxi_de(maxi.y, p.y), maxi_de(maxi.z, p.z))
	var etendue: Vector3i = maxi - mini + Vector3i.ONE
	print("   %d cases  ·  étendue %d × %d × %d" % [pleines.size(), etendue.x, etendue.y, etendue.z])

	# ── CE QU'IL COUVRE, dans le monde ACTUEL et dans le monde SANS DIAGONALE ──────────────────────
	var plafond: int = MB.plafond_de(pleines)
	var nus := {}
	var ext := {}
	for vx in range(mini.x - 1, maxi.x + 1):
		for vy in range(mini.y - 1, maxi.y + 1):
			for vz in range(mini.z - 1, maxi.z + 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var nom: String = MB.classer(b)["nom"]
				if MB.exterieur_possible(b) and MB.sous_le_ciel(pleines, v, plafond):
					ext[nom] = true
				else:
					nus[nom] = true
	print("   monde ACTUEL (90 tuiles)  : INTÉRIEUR %d/%d  EXTÉRIEUR %d/%d  → %d/90"
		% [nus.size(), MB.pieces_a_sculpter().size(), ext.size(),
			MB.classes_exterieures().size(), nus.size() + ext.size()])

	var atteignables := {}
	var ext_possibles := {}
	for c in MB.classes():
		if not MB.porte_une_surface(c["bits"]) or not MB.sans_contact_diagonal(c["bits"]):
			continue
		atteignables[c["nom"]] = true
		if MB.exterieur_possible(c["bits"]):
			ext_possibles[c["nom"]] = true
	var vus_int := 0
	var manque_int: Array = []
	for nom in atteignables:
		if nus.has(nom):
			vus_int += 1
		else:
			manque_int.append(nom)
	var vus_ext := 0
	var manque_ext: Array = []
	for nom in ext_possibles:
		if ext.has(nom):
			vus_ext += 1
		else:
			manque_ext.append(nom)
	print("   monde SANS DIAGONALE (52) : INTÉRIEUR %d/%d  EXTÉRIEUR %d/%d  → %d/52"
		% [vus_int, atteignables.size(), vus_ext, ext_possibles.size(), vus_int + vus_ext])

	# ── ⚠ CE QUE LE BASCULEMENT COÛTERAIT À SA PEINTURE ───────────────────────────────────────────
	# Appliqué à une COPIE. C'est LE chiffre à connaître avant de décider, pas après.
	var contacts: int = MB.contacts_par_arete(pleines)
	var copie: Dictionary = pleines.duplicate()
	var retirees: int = MB.completer_les_carres(copie)
	print("   ⚠ contacts diagonaux : %d  ·  la complétion retirerait %d case(s) (%.1f %%)"
		% [contacts, retirees, 100.0 * float(retirees) / float(pleines.size())])
	if not manque_int.is_empty() or not manque_ext.is_empty():
		print("   il resterait à peindre : %d classe(s) d'intérieur, %d variante(s) d'extérieur"
			% [manque_int.size(), manque_ext.size()])
		print("      intérieur : %s" % str(manque_int.slice(0, 10)))
		print("      extérieur : %s" % str(manque_ext.slice(0, 10)))
	print("")


func mini_de(a: int, b: int) -> int:
	return a if a < b else b


func maxi_de(a: int, b: int) -> int:
	return a if a > b else b
