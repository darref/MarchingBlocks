extends SceneTree
## VÉRIFIER UNE ZONE PEINTE — sans fenêtre, en deux secondes, autant de fois qu'on veut.
##
## Peindre à la main, c'est se tromper : une entrée sous laquelle aucune grotte ne passe, une coupe
## qui ne fait pas la longueur de son chemin, deux grottes sous la même case. Le greybox signale déjà
## tout ça (`greybox_ecran_partage.gd`), mais il faut le lancer AVEC une fenêtre et jouer jusqu'à l'endroit
## fautif. Cet outil-ci pose la même question au même chargeur, en ligne de commande.
##
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/verifier_zone.gd
##   godot --headless --path D:/UnderMend --script res://DEV_TOOLS/verifier_zone.gd -- res://NIVEAUX/autre.tscn
##
## ⚠ IL NE DIT PAS SEULEMENT « OUI » OU « NON ». Un vérificateur qui se tait quand tout va bien laisse
## une question ouverte : a-t-il lu ce que j'ai peint, ou n'a-t-il rien lu du tout ? Il imprime donc ce
## qu'il a VU — les grilles, les chemins, les entrées avec la grotte et la bouche qu'il en a DÉDUITES,
## les objets. C'est là qu'on repère une entrée branchée sur la mauvaise grotte, qu'aucune erreur ne
## peut signaler puisqu'elle est valide.
##
## Code de sortie : 0 si la carte est saine, 1 sinon.

const ZONE_PAR_DEFAUT := "res://NIVEAUX/zone_depart.tscn"


func _initialize() -> void:
	var chemin := ZONE_PAR_DEFAUT
	for argument in OS.get_cmdline_user_args():
		if argument.ends_with(".tscn"):
			chemin = argument

	if not ResourceLoader.exists(chemin):
		print("ZONE INTROUVABLE : %s" % chemin)
		quit(1)
		return

	var paquet := load(chemin) as PackedScene
	if paquet == null:
		print("ZONE ILLISIBLE : %s" % chemin)
		quit(1)
		return

	var zone := paquet.instantiate()
	root.add_child(zone)
	if not zone.has_method("construire"):
		print("« %s » n'est pas une zone : son nœud racine n'a pas de construire() (voir CLIENT/zone.gd)" % chemin)
		quit(1)
		return

	print("ZONE : %s" % chemin)
	var resultat: Dictionary = zone.construire()
	var monde = resultat["monde"]
	var chemins: Dictionary = resultat["chemins"]
	var entrees: Array = resultat["entrees"]
	var erreurs: Array = resultat["erreurs"]

	_montrer_grilles(monde, chemins)
	_montrer_entrees(entrees, chemins)
	_montrer_objets(monde)

	print("")
	if erreurs.is_empty():
		print("CARTE SAINE — aucune erreur.")
		quit(0)
		return
	print("CARTE FAUTIVE — %d erreur(s) :" % erreurs.size())
	for erreur in erreurs:
		print("  • %s" % erreur)
	quit(1)


func _montrer_grilles(monde, chemins: Dictionary) -> void:
	print("")
	print("GRILLES")
	var ids: Array = monde.grilles.keys()
	ids.sort()
	for id in ids:
		var g: Dictionary = monde.grilles[id]
		var murs := 0
		for y in g["hauteur"]:
			for x in g["largeur"]:
				if monde.est_mur(id, Vector2i(x, y)):
					murs += 1
		var cases: int = g["largeur"] * g["hauteur"]
		var quoi := "surface" if id == 0 else "grotte %d" % id
		print("  %-12s %3d × %-3d  %5d cases, %5d murées, %5d libres"
			% [quoi, g["largeur"], g["hauteur"], cases, murs, cases - murs])
		if chemins.has(id):
			var table: Array = chemins[id]
			var apercu := "%s → %s" % [table[0], table[table.size() - 1]] if table.size() > 1 else str(table)
			print("               chemin de %d cases : %s" % [table.size(), apercu])


## ⚠ Ce que le chargeur a DÉDUIT d'une entrée, pas ce qu'on a peint. Une entrée peut être parfaitement
## valide et mener ailleurs qu'on ne croit : c'est la seule chose qu'aucune erreur ne dira jamais.
func _montrer_entrees(entrees: Array, chemins: Dictionary) -> void:
	print("")
	print("ENTRÉES (%d)" % entrees.size())
	if entrees.is_empty():
		print("  aucune — rien ne relie les deux vues (charte §2)")
		return
	for e in entrees:
		print("  case %-10s → grotte %d, colonne %d, bouche %s"
			% [str(e["case"]), e["grotte"], e["colonne"], str(e["bouche"])])


func _montrer_objets(monde) -> void:
	print("")
	var comptes := {}
	for id in monde.objets:
		var type: String = monde.objets[id]["type"]
		comptes[type] = comptes.get(type, 0) + 1
	print("OBJETS (%d)" % monde.objets.size())
	if comptes.is_empty():
		print("  aucun")
		return
	var types: Array = comptes.keys()
	types.sort()
	for type in types:
		print("  %-16s %d" % [type, comptes[type]])
