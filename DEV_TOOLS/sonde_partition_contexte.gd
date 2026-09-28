extends SceneTree
##
## SONDE — combien de tuiles faut-il VRAIMENT pour deux contextes, et quelle taille de bloc ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_partition_contexte.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── LE CRITÈRE EST TRANCHÉ (mesuré par `sonde_deux_contextes.gd`) ───────────────────────────────────
##
## « Intérieur » = IL Y A DE LA ROCHE AU-DESSUS. Le critère par connexité (le vide communique-t-il avec
## le bord ?) est DISQUALIFIÉ : sur un massif percé d'un tunnel débouchant aux deux bouts, il déclare
## 0 case de tunnel sur 48 comme intérieure — on remettrait de la falaise au fond d'une galerie.
##
## ── PARTIE 1 : LA PARTITION EXACTE, PAR CALCUL ──────────────────────────────────────────────────────
##
## ⚠ **ON NE CHERCHE PAS CE QU'ON PEUT CALCULER.** Sous le critère du toit, une classe peut être
## EXTÉRIEURE seulement si aucune de ses cases vides du BAS n'a de matière juste au-dessus À L'INTÉRIEUR
## de son propre voisinage de huit : cette matière-là est dans la configuration, on ne peut pas l'ôter.
## En revanche une classe peut TOUJOURS être intérieure — il suffit d'ajouter de la roche plus haut,
## hors du voisinage.
##
## Donc :  intérieur possible  = toujours
##         extérieur possible  = aucune case vide du bas n'est coiffée dans le voisinage
##         tuiles à sculpter   = 68 (intérieur) + (nombre d'extérieures possibles)
##
## ⚠ Le test est invariant par rotation autour de Y — le groupe orienté préserve le haut et le bas —
## donc il est bien défini par CLASSE, et pas seulement par configuration.
##
## ── PARTIE 2 : LA TAILLE DU BLOC UNIQUE, À AMORCE CONÇUE ────────────────────────────────────────────
##
## Une recherche partant du cube plein ne trouve presque que de l'intérieur (tout est coiffé) ; une
## recherche partant du vide ne trouve que de l'extérieur. On part donc d'un TERRAIN irrégulier posé sur
## un RÉSEAU DE GROTTES — la forme même de ce qu'on veut — et on améliore de là.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

const VOISINS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func _initialize() -> void:
	print("=== SONDE — LA PARTITION DES CONTEXTES ===\n")
	var capables: Dictionary = _un_partition_exacte()
	_deux_taille_du_bloc(capables)
	quit(0)


# ── PARTIE 1 — LA PARTITION EXACTE ──────────────────────────────────────────────────────────────────

## Une configuration peut-elle être EXTÉRIEURE ? Non si une case vide du bas est coiffée dans le
## voisinage. `MB.BAS` = [0, 1, 4, 5] ; la case juste au-dessus de `t` est `t + 2` (le bit y).
func _exterieur_possible(bits: int) -> bool:
	for t in MB.BAS:
		var vide: bool = (bits & (1 << int(t))) == 0
		var dessus_plein: bool = (bits & (1 << (int(t) + 2))) != 0
		if vide and dessus_plein:
			return false
	return true


func _un_partition_exacte() -> Dictionary:
	print("── 1. LA PARTITION EXACTE DES 68 CLASSES (calcul, pas recherche) ──")
	var ext_possible := {}
	var ext := 0
	var int_seul: Array = []
	for c in MB.classes():
		var bits: int = c["bits"]
		if not MB.porte_une_surface(bits):
			continue
		if _exterieur_possible(bits):
			ext_possible[c["nom"]] = true
			ext += 1
		else:
			int_seul.append(c["nom"])
	var total: int = MB.pieces_a_sculpter().size()
	print("   %d classes de surface au total" % total)
	print("   %d peuvent être EXTÉRIEURES (rien ne les coiffe dans leur voisinage)" % ext)
	print("   %d sont STRUCTURELLEMENT INTÉRIEURES — un plafond ne peut pas être à l'air libre"
		% int_seul.size())
	print("\n   ⚠ TUILES À SCULPTER = %d (intérieur, toujours possible) + %d (extérieur) = %d"
		% [total, ext, total + ext])
	print("     et NON 2 × %d = %d, comme je l'avais estimé." % [total, total * 2])
	print("\n   les %d intérieures seulement :" % int_seul.size())
	int_seul.sort()
	for n in int_seul:
		print("        %s" % n)
	print("")
	return ext_possible


# ── PARTIE 2 — LA TAILLE DU BLOC UNIQUE ─────────────────────────────────────────────────────────────

## ⚠ LA CARTE DE COUVERTURE, EN UN BALAYAGE PAR COLONNE. Tester « y a-t-il de la roche au-dessus » en
## remontant à chaque appel rendait la recherche quarante fois trop lente.
func _couverture(pleines: Dictionary, n: int) -> Dictionary:
	var couverte := {}
	for x in n:
		for z in n:
			var vu_du_plein := false
			for y in range(n - 1, -1, -1):
				var c := Vector3i(x, y, z)
				if pleines.has(c):
					vu_du_plein = true
				elif vu_du_plein:
					couverte[c] = true
	return couverte


func _connexe(pleines: Dictionary) -> bool:
	if pleines.is_empty():
		return false
	var depart: Vector3i = pleines.keys()[0]
	var vus := {depart: true}
	var pile: Array = [depart]
	while not pile.is_empty():
		var p: Vector3i = pile.pop_back()
		for d in VOISINS:
			var q: Vector3i = p + d
			if pleines.has(q) and not vus.has(q):
				vus[q] = true
				pile.append(q)
	return vus.size() == pleines.size()


## Rend {"int": {noms}, "ext": {noms}}.
func _contextes(pleines: Dictionary, n: int) -> Dictionary:
	var couverte: Dictionary = _couverture(pleines, n)
	var dedans := {}
	var dehors := {}
	for vx in range(n - 1):
		for vy in range(n - 1):
			for vz in range(n - 1):
				var v := Vector3i(vx, vy, vz)
				var b: int = MB.bits(pleines, v)
				if not MB.porte_une_surface(b):
					continue
				var n_couv := 0
				var n_libre := 0
				for t in 8:
					var q: Vector3i = v + MB.COINS[t]
					if pleines.has(q):
						continue
					if couverte.has(q):
						n_couv += 1
					else:
						n_libre += 1
				var nom: String = MB.classer(b)["nom"]
				if n_couv > 0 and n_libre == 0:
					dedans[nom] = true
				elif n_libre > 0 and n_couv == 0:
					dehors[nom] = true
	return {"int": dedans, "ext": dehors}


## L'amorce CONÇUE : un terrain irrégulier posé sur un réseau de grottes.
func _amorce(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var pleines := {}
	# un relief : hauteur variable par colonne, entre n/2 et n-2
	var hauteurs := {}
	for x in n:
		for z in n:
			hauteurs[Vector2i(x, z)] = rng.randi_range(n / 2, n - 2)
	for x in n:
		for z in n:
			var h: int = hauteurs[Vector2i(x, z)]
			for y in range(0, h + 1):
				pleines[Vector3i(x, y, z)] = true
	# des grottes : marches aléatoires dans la moitié basse
	for galerie in 3:
		var p := Vector3i(rng.randi_range(1, n - 2), rng.randi_range(1, n / 2),
			rng.randi_range(1, n - 2))
		for pas in n * 4:
			pleines.erase(p)
			var q: Vector3i = p + VOISINS[rng.randi_range(0, 5)]
			if q.x >= 1 and q.z >= 1 and q.y >= 1 and q.x < n - 1 and q.z < n - 1 and q.y < n / 2 + 1:
				p = q
	return pleines


func _deux_taille_du_bloc(capables: Dictionary) -> void:
	print("── 2. LA TAILLE DU BLOC UNIQUE, À AMORCE CONÇUE ──")
	var total: int = MB.pieces_a_sculpter().size()
	var vise_ext: int = capables.size()
	print("   objectif : %d classes vues en INTÉRIEUR et %d en EXTÉRIEUR" % [total, vise_ext])
	print("   amorce : un terrain irrégulier sur un réseau de galeries, puis montée de colline\n")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	print("   N   sommets   INTÉRIEUR   EXTÉRIEUR   total couvert   connexe")
	for n in [8, 10, 12]:
		var meilleur := -1
		var m_int := 0
		var m_ext := 0
		var m_connexe := false
		for essai in 2:
			var pleines: Dictionary = _amorce(n, rng)
			var c: Dictionary = _contextes(pleines, n)
			var score: int = (c["int"] as Dictionary).size() + (c["ext"] as Dictionary).size()
			for pas in 500:
				var p := Vector3i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1),
					rng.randi_range(0, n - 1))
				var avait: bool = pleines.has(p)
				if avait:
					pleines.erase(p)
				else:
					pleines[p] = true
				var c2: Dictionary = _contextes(pleines, n)
				var s2: int = (c2["int"] as Dictionary).size() + (c2["ext"] as Dictionary).size()
				if s2 >= score:
					score = s2
					c = c2
				else:
					if avait:
						pleines[p] = true
					else:
						pleines.erase(p)
			if score > meilleur:
				meilleur = score
				m_int = (c["int"] as Dictionary).size()
				m_ext = (c["ext"] as Dictionary).size()
				m_connexe = _connexe(pleines)
		print("   %2d   %7d   %6d/%d   %6d/%d   %8d/%d   %s%s"
			% [n, (n - 1) * (n - 1) * (n - 1), m_int, total, m_ext, vise_ext,
				meilleur, total + vise_ext, "oui" if m_connexe else "NON",
				"   ← COMPLET" if m_int >= total and m_ext >= vise_ext else ""])
	print("\n   ⚠ PLANCHER, pas plafond : un bloc CONÇU par un artiste fera mieux qu'une montée de")
	print("     colline de 500 pas. Un score incomplet ne prouve pas l'impossibilité à cette taille.")
