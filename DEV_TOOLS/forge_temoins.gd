extends RefCounted
##
## LA FORGE DES TÉMOINS À THÈME — demandée par Jordan (16 octobre 2026) : « modéliser et peindre des témoins avec leur
## thème, plaine désert roche volcan plage boue gravier rocaille mur de pierre glace neige, avec un niveau de subdivision
## sweet spot pour qu'un monde tienne sans lagger ». Des fonctions PURES sur un `TemoinLie` (sans écran), que mène
## `batir_monde_client.gd` et que garde `test_forge_temoins.gd`. Elles n'ajoutent RIEN au logiciel : ce sont les gestes
## du modeleur (Subdivide, le Smooth propagé par les sections partagées, Draw / Inflate, New variant, Assign), menés sur
## toutes les tuiles à la fois.
##
## ⚠ LA SUBDIVISION PAR LOT (mesuré le 16 octobre 2026, `sonde_subdivision_temoin.gd`) : subdiviser tuile après tuile en
## complétant après chacune s'emballait (10 min, 2,6 Go sans finir) — la complétion reporte les milieux d'une tuile chez
## ses voisines, que leur propre subdivision refend ensuite, et ainsi de suite. TOUTES les tuiles subdivisées d'abord, puis
## UNE complétion : 0 coupe à reporter, 0 absence (une arête de bord commune a le même milieu partout), 0,6 s par niveau.
##
## ⚠ UNE BASE COMMUNE, DES DEDANS PROPRES À CHAQUE THÈME : toutes les couches d'un monde partagent leurs bords (charte §3,
## « les bords partagés entre couches »). La base (subdivisée, arrondie — les bords y bougent, propagés à toutes les
## tuiles) est donc la MÊME pour tous les thèmes ; chaque thème ne retouche ensuite que le DEDANS de ses tuiles (les
## sommets hors des plans de coupe, avec un poids qui s'éteint en approchant d'un plan) : les bords restent ceux de la base,
## et le raccord entre couches est garanti par construction. Les variantes de même (leur dedans seul).

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")

const EPS := 1e-4


static func triangles(t: RefCounted) -> int:
	var n := 0
	for c in t.tuiles:
		for f in t.tuiles[c].faces:
			n += (f as PackedInt32Array).size() - 2
	return n


## Subdivise TOUTES les tuiles `niveaux` fois, une complétion par niveau. Rend {coupes, echecs, absences}.
static func subdiviser_tout(t: RefCounted, niveaux: int) -> Dictionary:
	var bilan := {"coupes": 0, "echecs": 0, "absences": 0}
	if niveaux <= 0:
		return bilan
	var s = Sections.new(t)
	for n in niveaux:
		for c in t.tuiles:
			var m: RefCounted = t.tuiles[c]
			m.subdiviser(range(m.faces.size()))
		var r: Dictionary = s.completer()
		bilan["coupes"] += int(r["coupes"])
		bilan["echecs"] += int(r["echecs"])
	bilan["absences"] = s.absences()
	return bilan


## Le sommet est-il posé sur un plan de coupe (|x|, |y| ou |z| = 0,5 dans le repère de sa tuile) ?
static func sur_un_plan(p: Vector3) -> bool:
	return absf(absf(p.x) - 0.5) < EPS or absf(absf(p.y) - 0.5) < EPS or absf(absf(p.z) - 0.5) < EPS


## Le poids d'un sommet du DEDANS : 0 sur un plan de coupe, 1 à `marge` de lui et au-delà.
static func poids_dedans(p: Vector3, marge: float) -> float:
	var d := 0.5 - maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
	return clampf(d / maxf(marge, 1e-4), 0.0, 1.0)


## LE LISSAGE DE LA BASE, sur toutes les tuiles à la fois : le Smooth du sculpt (chaque sommet vers la moyenne de ses
## voisins), les sommets de bord ramenés dans leur plan et PROPAGÉS par groupe (un groupe relié par les sections reçoit le
## mouvement de son membre le plus déplacé, `Sections.propager_par_groupe_plusieurs`) — le chemin du pinceau. Une passe
## qui replierait une face (dans n'importe quelle tuile) est rejouée à moitié de force, jusqu'à 1/16.
## Rend {passes, adoucies, refusees, conflits}.
static func lisser_base(t: RefCounted, passes: int, force: float) -> Dictionary:
	var bilan := {"passes": 0, "adoucies": 0, "refusees": 0, "conflits": 0}
	var s = Sections.new(t)
	for p in passes:
		s.indexer()
		var gardes := {}
		for c in t.tuiles:
			var m: RefCounted = t.tuiles[c]
			gardes[c] = m.gardes_de_repli(range(m.faces.size()))
		var f := force
		while true:
			var photo: Dictionary = s.photo()
			var bords := {}
			for c in t.tuiles:
				var m: RefCounted = t.tuiles[c]
				var d: Dictionary = m.pinceau_sculpt("smooth", Vector3.ZERO, Vector3.UP, 10.0, f, 1.0)
				var dc := {}
				for i in d:
					var v: Vector3 = d[i]
					if s.est_de_bord(c, i):
						dc[i] = s.projeter(c, i, v)
					else:
						# Un sommet sur un plan sans classe (une face de motif vide ou plein — mesuré : il n'y en a pas) reste
						# dans son plan, par prudence.
						var q: Vector3 = m.sommets[i]
						for a in 3:
							if absf(absf(q[a]) - 0.5) < EPS:
								v[a] = 0.0
						m.sommets[i] = q + v
				if not dc.is_empty():
					bords[c] = dc
			var r: Dictionary = s.propager_par_groupe_plusieurs(bords)
			bilan["conflits"] += s.conflits
			s.deplacer(r, photo)
			var replie := false
			for c in gardes:
				if (t.tuiles[c] as RefCounted).replie(gardes[c]):
					replie = true
					break
			if not replie:
				bilan["passes"] += 1
				break
			for c in photo:
				s.tuile(c).sommets = (photo[c] as PackedVector3Array).duplicate()
			f *= 0.5
			bilan["adoucies"] += 1
			if f < force / 16.0:
				bilan["refusees"] += 1
				break
	return bilan


## RETOUCHER LE DEDANS d'une tuile : `deplacement(p: Vector3, n: Vector3) -> Vector3` pour chaque sommet, multiplié par
## son poids du dedans (`marge`). Un repli fait rejouer à moitié (jusqu'à 1/16). Rend le facteur appliqué (0 : refusé).
static func retoucher_dedans(m: RefCounted, deplacement: Callable, marge := 0.18) -> float:
	var depart: PackedVector3Array = (m.sommets as PackedVector3Array).duplicate()
	var normales: Dictionary = m.normales_des_sommets(range(depart.size()))
	var gardes: Array = m.gardes_de_repli(range(m.faces.size()))
	var k := 1.0
	while k >= 1.0 / 16.0:
		for i in depart.size():
			var p: Vector3 = depart[i]
			var w := poids_dedans(p, marge)
			if w <= 0.0:
				m.sommets[i] = p
				continue
			m.sommets[i] = p + (deplacement.call(p, normales.get(i, Vector3.UP)) as Vector3) * (w * k)
		if not m.replie(gardes):
			return k
		k *= 0.5
	m.sommets = depart
	return 0.0


## Un Laplacien du DEDANS seul (les bords ne bougent pas) — des formes plus douces (dunes, neige).
static func lisser_dedans(m: RefCounted, passes: int, force: float, marge := 0.18) -> void:
	for p in passes:
		var d: Dictionary = m.pinceau_sculpt("smooth", Vector3.ZERO, Vector3.UP, 10.0, force, 1.0)
		var gardes: Array = m.gardes_de_repli(range(m.faces.size()))
		var depart: PackedVector3Array = (m.sommets as PackedVector3Array).duplicate()
		for i in d:
			m.sommets[i] = depart[i] + (d[i] as Vector3) * poids_dedans(depart[i], marge)
		if m.replie(gardes):
			m.sommets = depart
			return


## UN BRUIT DE RELIEF le long de la normale (bosses, rocaille, bourrelets) : `amplitude` en cases, `frequence` en
## cycles par case ; `bas` : le bruit ne creuse pas (rocaille : il ne fait que gonfler). Déterministe (graine).
static func bruit(graine: int, frequence: float, octaves := 3) -> FastNoiseLite:
	var b := FastNoiseLite.new()
	b.seed = graine
	b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	b.frequency = frequence
	b.fractal_octaves = octaves
	return b


static func bosseler(m: RefCounted, b: FastNoiseLite, amplitude: float, decalage: Vector3, gonfle := false,
		seulement_vers := Vector3.ZERO, marge := 0.18) -> float:
	return retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
		var v := b.get_noise_3dv(p + decalage)
		if gonfle:
			v = absf(v)
		var w := 1.0
		if seulement_vers != Vector3.ZERO:
			w = clampf(n.dot(seulement_vers), 0.0, 1.0)
		return n * (v * amplitude * w), marge)


## UN MATÉRIAU PAR ORIENTATION : les faces dont la normale monte (n.y > `seuil`) prennent `k_sol`, les autres `k_paroi`
## (les plafonds aussi, sauf `k_plafond` ≥ 0). Sur toutes les tuiles, variantes comprises.
static func assigner_par_orientation(t: RefCounted, k_sol: int, k_paroi: int, seuil := 0.55, k_plafond := -1) -> void:
	for c in t.tuiles:
		var m: RefCounted = t.tuiles[c]
		var sol := []
		var paroi := []
		var plafond := []
		for f in m.faces.size():
			var n: Vector3 = m.normale(f)
			if n.y > seuil:
				sol.append(f)
			elif k_plafond >= 0 and n.y < -seuil:
				plafond.append(f)
			else:
				paroi.append(f)
		if not sol.is_empty():
			m.assigner(sol, k_sol)
		if not paroi.is_empty():
			m.assigner(paroi, k_paroi)
		if not plafond.is_empty():
			m.assigner(plafond, k_plafond)


## LES VARIANTES VOULUES : pour chaque clé de `cles`, `combien` variantes, copies de la base dont seul le DEDANS est
## retouché par `retouche(m, k)` (k = 1, 2…) — leurs bords restent ceux de leur clé, le raccord est garanti (charte §3).
## Rend {clé: [noms des variantes]}.
static func creer_variantes(t: RefCounted, cles: Array, combien: int, retouche: Callable) -> Dictionary:
	var sortie := {}
	for c in cles:
		if not t.tuiles.has(c):
			continue
		var occ: Array = t.occurrences_de(c)
		if occ.is_empty():
			continue
		sortie[c] = []
		for k in range(1, combien + 1):
			# L'occurrence k (ou la dernière) montre la variante : le témoin la fait voir parmi ses vraies voisines.
			var i: int = int(occ[mini(k, occ.size() - 1)])
			var nom: String = t.creer_variante(i)
			if nom == "":
				break
			retouche.call(t.tuiles[nom], k)
			sortie[c].append(nom)
	return sortie
