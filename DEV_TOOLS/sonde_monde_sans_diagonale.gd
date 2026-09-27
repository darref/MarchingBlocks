extends SceneTree

## SONDE — ET SI LE MONDE N'AVAIT AUCUN CONTACT DIAGONAL ?
##
## ⚠ **LA QUESTION EST DE JORDAN (25 septembre 2026)** : « si on n'autorisait que des trous, tunnels,
## grottes et n'importe quel autre enfoncement CARRÉS, on aurait un témoin unique beaucoup plus simple
## et intuitif ? à condition que le pinceau n'autorise de creuser qu'en carré ? car c'est toutes les
## possibilités de creusage qui prennent la grande majorité du témoin unique et le rendent trop gros. »
##
## ⚠ **LA FORME DE L'OUTIL NE SUFFIT PAS — c'est la correction à apporter à l'idée.** Deux creusements
## carrés parfaitement légitimes, en (0,0) et en (1,1), se touchent par un coin : cela produit un
## CONTACT DIAGONAL. La contrainte utile ne porte donc pas sur le geste mais sur le RÉSULTAT, et elle se
## vérifie sur les huit cases d'un sommet au moment de peindre.
##
## ⚠ **ON MESURE AVANT DE CONCEVOIR (charte §6).** La charte enregistre déjà « interdire ces contacts
## fait tomber la couverture à 52/90 » — mais comme un ÉCHEC du témoin. Si le nombre de classes
## ATTEIGNABLES sous cette règle vaut lui aussi 52, ce n'était pas un échec : c'était la mesure du monde
## que Jordan décrit, et un témoin sans contact diagonal le couvrirait à 100 %.
##
## ⚠ **ELLE NE DIT PAS SI LE MONDE RESTE BEAU.** Interdire les contacts diagonaux interdit aussi des
## reliefs que l'on aimait peut-être — c'est un appauvrissement volontaire du vocabulaire, et seul
## Jordan peut dire si le monde y perd quelque chose qu'il voulait.

const MB := preload("res://addons/marching_blocks_plugin_godot/marching_blocks.gd")
const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")
const Tranchage := preload("res://addons/marching_blocks_plugin_godot/tranchage.gd")


## L'index d'une case dans le voisinage 2×2×2 vaut `x + 2y + 4z`.
## ⚠ DÉDUIT de `_trois_formes()` du vérificateur, qui lit `bas` en `x + 4z` et `haut` en `x + 2 + 4z` —
## pas supposé. Une erreur de disposition ici ferait mesurer une tout autre question.
func _coord(i: int) -> Vector3i:
	return Vector3i(i & 1, (i >> 1) & 1, (i >> 2) & 1)


## ⚠ **LE CRITÈRE : aucune des six faces du voisinage ne montre la forme « diagonale ».** On emploie
## `MB.forme_de_face()` par `MB.faces_de()` — la MÊME fonction qui définit les germes et le contrat de
## couture. Réécrire ici ce qu'est une diagonale en ferait une seconde description, et c'est justement
## la règle que le pinceau devra appliquer : elle doit être la même des deux côtés.
## ⚠ **LE PRÉDICAT A DÉMÉNAGÉ DANS `marching_blocks.gd` (25 septembre 2026)** — le vérificateur et le
## pinceau en ont besoin aussi. Cette sonde l'appelle désormais au lieu de le porter, et le contrôle du
## déménagement est qu'elle redise exactement **35 classes, 17 à l'air libre, 52 tuiles**.
func _sans_diagonale_de_face(bits: int) -> bool:
	return MB.sans_contact_diagonal(bits)


## Le critère renforcé : en plus, la matière du voisinage se tient par les FACES.
## ⚠ Il attrape ce que le précédent laisse passer — deux cases opposées en coin, (0,0,0) et (1,1,1), que
## chaque face voit comme un simple « coin » isolé. Deux cubes qui ne se touchent que par un point sont
## non-manifold aussi, et le pinceau devrait les refuser de la même façon.
func _matiere_tenue_par_les_faces(bits: int) -> bool:
	var pleines: Array = []
	for i in 8:
		if (bits & (1 << i)) != 0:
			pleines.append(i)
	if pleines.size() <= 1:
		return true
	var vus := {pleines[0]: true}
	var pile: Array = [pleines[0]]
	while not pile.is_empty():
		var a: int = pile.pop_back()
		var pa: Vector3i = _coord(a)
		for b in pleines:
			if vus.has(b):
				continue
			var pb: Vector3i = _coord(b)
			var ecart: int = absi(pa.x - pb.x) + absi(pa.y - pb.y) + absi(pa.z - pb.z)
			if ecart == 1:
				vus[b] = true
				pile.append(b)
	return vus.size() == pleines.size()


func _initialize() -> void:
	print("=== ET SI LE MONDE N'AVAIT AUCUN CONTACT DIAGONAL ? ===\n")

	var total_int: int = MB.pieces_a_sculpter().size()
	var total_ext: int = MB.classes_exterieures().size()
	print("le monde ACTUEL : %d classes d'intérieur + %d variantes d'extérieur = %d tuiles\n"
		% [total_int, total_ext, total_int + total_ext])

	for essai in [
		{"nom": "aucune FACE en diagonale", "strict": false},
		{"nom": "+ la matière tenue par les faces", "strict": true},
	]:
		var noms := {}
		var ext := {}
		for c in MB.classes():
			var bits: int = c["bits"]
			if not MB.porte_une_surface(bits):
				continue
			if not _sans_diagonale_de_face(bits):
				continue
			if essai["strict"] and not _matiere_tenue_par_les_faces(bits):
				continue
			noms[c["nom"]] = true
			if MB.exterieur_possible(bits):
				ext[c["nom"]] = true
		print("── %s ──" % essai["nom"])
		print("   %d classes atteignables sur %d  ·  %d peuvent être à l'air libre"
			% [noms.size(), total_int, ext.size()])
		print("   soit %d TUILES à sculpter, au lieu de %d  (−%.0f %%)"
			% [noms.size() + ext.size(), total_int + total_ext,
				100.0 * (1.0 - float(noms.size() + ext.size()) / float(total_int + total_ext))])
		if not essai["strict"]:
			_les_germes_qui_restent()
			_ce_que_le_paysage_couvre(noms, ext)
		print("")
	quit(0)


## Combien de RACCORDS l'artiste aurait encore à sculpter.
## ⚠ C'est un second bénéfice, distinct du nombre de tuiles : les germes sont le cahier des charges de
## bordure, et `sonde_germes.gd` a mesuré que le témoin paysage en exhibe 18 sur 22, les 4 manquants
## étant TOUS de forme « diagonale ». S'ils disparaissent, ce témoin devient complet en raccords.
func _les_germes_qui_restent() -> void:
	var total := 0
	var restants := 0
	for g in MB.germes():
		var forme: String = g["forme"]
		if forme == "rien" or forme == "plein":
			continue
		total += 1
		if forme != "diagonale":
			restants += 1
	print("   germes à coudre : %d au lieu de %d  (les %d diagonaux disparaissent)"
		% [restants, total, total - restants])


## ⚠ **LA QUESTION DÉCISIVE : le témoin paysage couvre-t-il DÉJÀ ce monde-là ?** S'il le couvre, l'idée
## de Jordan ne simplifie pas seulement le témoin — elle rend le SECOND témoin inutile.
func _ce_que_le_paysage_couvre(atteignables: Dictionary, ext_possibles: Dictionary) -> void:
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	var vus := {}
	var vus_ext := {}
	for vx in range(BM.COTE - 1):
		for vy in range(BM.COTE - 1):
			for vz in range(BM.COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var nom: String = MB.classer(b)["nom"]
				if MB.exterieur_possible(b) and MB.sous_le_ciel(pleines, v, plafond):
					vus_ext[nom] = true
				else:
					vus[nom] = true
	var manque_int: Array = []
	for nom in atteignables:
		if not vus.has(nom):
			manque_int.append(nom)
	var manque_ext: Array = []
	for nom in ext_possibles:
		if not vus_ext.has(nom):
			manque_ext.append(nom)
	print("   le témoin PAYSAGE (bloc 0) en couvre %d/%d en intérieur, %d/%d en extérieur"
		% [atteignables.size() - manque_int.size(), atteignables.size(),
			ext_possibles.size() - manque_ext.size(), ext_possibles.size()])
	if manque_int.is_empty() and manque_ext.is_empty():
		print("   → IL COUVRE DÉJÀ TOUT CE MONDE : le second témoin devient inutile.")
	else:
		print("   manque en intérieur : %s" % str(manque_int))
		print("   manque en extérieur : %s" % str(manque_ext))
