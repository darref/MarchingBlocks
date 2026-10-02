extends SceneTree
##
## RÉPARER LES TÉMOINS D'UN PROJET — demandé par Jordan (2 octobre 2026) : les témoins de l'exemple ont des trous
## « qui datent de quand la subdivision ne se répandait pas à tout le témoin » (avant `_completer_apres`, charte
## §3, « les gestes topologiques rompaient les sections partagées »).
##
## LANCEMENT :
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/reparer_temoins.gd -- --projet=<.mbproj> [--ecrire]
##
## ⚠ **`completer` NE SUFFIT PAS ICI — MESURÉ sur l'exemple** : il pose un point absent sur l'arête qui le CONTIENT ;
## or les points de la subdivision d'alors avaient été DÉPLACÉS (0,04 à 0,13 case) hors des arêtes des autres faces
## — 159 échecs sur 159. D'où `_conformer` : dans chaque classe, la section portée par le plus de faces (la
## MAJORITÉ — 27 faces sur 32 dans l'exemple) fait foi ; dans chaque autre face, chaque point majoritaire MANQUANT
## prend le sommet intrus le plus proche, et les intrus restants GLISSENT DANS LEUR PLAN sur la section majoritaire ; puis `completer` reporte
## les points qui manquent, désormais posés sur des arêtes. Un sommet posé sur une ARÊTE de case (deux plans) n'est
## jamais déplacé — il est dit. ⚠ Ça défait, sur ces bords seulement, la sculpture des faces minoritaires.
## `--remettre=cle1,cle2` (DÉCIDÉ par Jordan, 2 octobre 2026, pour l'exemple) : ces tuiles, ABÎMÉES dans leur maillage
## (faces en double retournées l'une contre l'autre, faces superposées, trous — aucune réparation de section ne les
## referme), repartent de leur version PROPRE du témoin calculé, re-branchée sur les matériaux du témoin ; puis
## `_conformer` cale leurs bords sur la section majoritaire. Leur sculpture et leur peinture sont perdues — à refaire.
## Sans `--ecrire`, il MESURE seulement. Avec, chaque `.mbtiles` réparé est réécrit, l'original gardé à côté en
## `.avant_reparation` (jamais écrasé s'il existe déjà).
## ⚠ L'APPLI DOIT ÊTRE FERMÉE : ouverte sur ce projet, elle réécrirait l'ancien témoin à la fermeture.
## ⚠ LA MESURE NE PASSE PAS PAR `sections.gd` SEULE : `_sans_partenaire` (recopié de `test_sections`) compte, sur
##   les VRAIS joints du témoin, les sommets sans partenaire dans la tuile d'en face.

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")
## Au-delà (en cases), un intrus n'est pas apparié à un point manquant, et un manquant n'est pas posé sur une arête.
const RAYON_D_APPARIEMENT := 0.1


func _initialize() -> void:
	var projet := ""
	var ecrire := false
	var remettre: Array = []
	var jumelles := {}   # tuile abîmée → tuile saine de MÊME FORME dont elle reprend la géométrie
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--projet="):
			projet = a.substr("--projet=".length())
		elif a == "--ecrire":
			ecrire = true
		elif a.begins_with("--remettre="):
			remettre = Array(a.substr("--remettre=".length()).split(",", false))
		elif a.begins_with("--depuis="):
			for paire in a.substr("--depuis=".length()).split(",", false):
				jumelles[paire.split(":")[1]] = paire.split(":")[0]
	var etat = JSON.parse_string(FileAccess.get_file_as_string(projet))
	if not (etat is Dictionary):
		print("⚠ projet illisible : ", projet)
		quit(1)
		return
	var code := 0
	for c in etat["couches"]:
		var chemin := str(c.get("temoin", ""))
		if chemin == "" or not FileAccess.file_exists(chemin):
			continue
		print("\n« %s » — %s" % [c["nom"], chemin])
		var d = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		var t: RefCounted = TL.depuis_dictionnaire(d)
		var a0: int = Sections.new(t).absences()
		var o0 := _sans_partenaire(t)
		print("  avant : %d point(s) absent(s) de leur classe, %d sommet(s) de joint sans partenaire ; %s" % [a0, o0, _variete(t)])
		var remises := 0
		for cle in remettre:
			if not t.tuiles.has(cle):
				print("  ⚠ pas de tuile « %s »" % cle)
				code = 1
				continue
			if _calcule == null:
				_calcule = TL.depuis_le_temoin_calcule()
			var neuve: RefCounted = _calcule.tuiles[cle].copie()
			for mt in neuve.mats:
				if int(mt) >= 0:
					print("  ⚠ la tuile calculée « %s » porte un matériau : refusé" % cle)
					quit(1)
					return
			t.tuiles[cle] = neuve
			remises += 1
		for cle in jumelles:
			t.tuiles[cle] = t.tuiles[jumelles[cle]].copie()
			remises += 1
		if remises > 0:
			t._partager()   # la tuile neuve lit les matériaux du témoin (elle ne porte que la légende)
			print("  remises à neuf : %d tuile(s) ; %s" % [remises, _variete(t)])
		var s = Sections.new(t)
		var c0: Dictionary = _conformer(t, s)
		print("  conformés à la section majoritaire : %d sommet(s) déplacé(s), %d inséré(s), %d non inséré(s) (jusqu'à %.4f case) dans %d tuile(s), %d sur une arête laissé(s), %d face(s) repliée(s)"
			% [c0["deplaces"], c0["inseres"], c0["non_inseres"], c0["plus_loin"], c0["tuiles"], c0["sur_arete"], c0["replies"]])
		if c0["replies"] > 0 or c0["sur_arete"] > 0 or c0["non_inseres"] > 0:
			code = 1
		var r: Dictionary = s.completer()
		var a1: int = s.absences()
		var o1 := _sans_partenaire(t)
		print("  complété : %d coupe(s) dans %d tuile(s), %d échec(s)" % [r["coupes"], (r["touchees"] as Array).size(), r["echecs"]])
		var v1 := _variete(t)
		print("  après : %d absent(s), %d sans partenaire ; %s" % [a1, o1, v1])
		if r["echecs"] > 0 or a1 > 0 or o1 > 0 or not v1.begins_with("0 "):
			code = 1
		if ecrire and code == 0 and (r["coupes"] > 0 or remises > 0 or c0["deplaces"] > 0):
			var garde := chemin + ".avant_reparation"
			if not FileAccess.file_exists(garde):
				DirAccess.copy_absolute(chemin, garde)
			var f := FileAccess.open(chemin, FileAccess.WRITE)
			f.store_string(JSON.stringify(t.vers_dictionnaire()))
			f.close()
			# ⚠ LE .glb LIÉ AUSSI : le monde de la couche se rhabille depuis lui à l'ouverture (son empreinte change) ;
			# sans lui, il garderait les tuiles ABÎMÉES de son cache.
			var glb := chemin.get_basename() + ".glb"
			if FileAccess.file_exists(glb) and not FileAccess.file_exists(glb + ".avant_reparation"):
				DirAccess.copy_absolute(glb, glb + ".avant_reparation")
			var raison: String = t.vers_glb(glb)
			print("  %s : %s" % [glb.get_file(), "réécrit" if raison == "" else "⚠ " + raison])
			var relu: RefCounted = TL.depuis_dictionnaire(JSON.parse_string(FileAccess.get_file_as_string(chemin)))
			print("  écrit (original : %s) — relu : %d absent(s), %d sans partenaire"
				% [garde.get_file(), Sections.new(relu).absences(), _sans_partenaire(relu)])
	quit(code)


var _calcule: RefCounted = null


## La variété du témoin : arêtes OUVERTES hors des plans de coupe (des trous) et arêtes à plus de deux faces.
func _variete(t: RefCounted) -> String:
	var ouvertes := 0
	var plus := 0
	var abimees := []
	for cle in t.tuiles:
		var m: RefCounted = t.tuiles[cle]
		var compte := {}
		for f in m.faces:
			var face: PackedInt32Array = f
			for j in face.size():
				var e: Vector2i = m.arete(face[j], face[(j + 1) % face.size()])
				compte[e] = compte.get(e, 0) + 1
		var avant := ouvertes + plus
		for e in compte:
			if compte[e] > 2:
				plus += 1
			elif compte[e] == 1:
				var a: Vector3 = m.sommets[e.x]
				var b: Vector3 = m.sommets[e.y]
				var sur := false
				for ax in 3:
					for sg in [-0.5, 0.5]:
						sur = sur or (absf(a[ax] - sg) < 0.0005 and absf(b[ax] - sg) < 0.0005)
				if not sur:
					ouvertes += 1
		if ouvertes + plus > avant:
			abimees.append(cle)
	return "%d arête(s) ouverte(s) hors des coupes, %d à plus de deux faces%s" % [ouvertes, plus,
		"" if abimees.is_empty() else " (%s)" % ", ".join(PackedStringArray(abimees))]


## Dans chaque classe, la section la plus portée fait foi ; les sommets des autres faces qui n'y sont pas glissent,
## dans leur plan, sur le point le plus proche de la section majoritaire (ses SEGMENTS, orbite du groupe comprise).
func _conformer(t: RefCounted, s) -> Dictionary:
	var bilan := {"deplaces": 0, "inseres": 0, "non_inseres": 0, "plus_loin": 0.0, "tuiles": 0, "sur_arete": 0,
		"replies": 0}
	s.indexer()
	var touchees := {}
	for k in s.points.size():
		# Les points de chaque nœud, puis la signature la plus portée.
		var de_noeud := {}
		for canon in s.points[k]:
			for mbr in s.points[k][canon]:
				if not de_noeud.has(mbr["noeud"]):
					de_noeud[mbr["noeud"]] = {}
				de_noeud[mbr["noeud"]][canon] = true
		var signatures := {}
		for n in de_noeud:
			var cles: Array = de_noeud[n].keys()
			cles.sort()
			var sig := str(cles)
			if not signatures.has(sig):
				signatures[sig] = []
			signatures[sig].append(n)
		if signatures.size() <= 1:
			continue
		var majorite: Array = []
		for sig in signatures:
			if (signatures[sig] as Array).size() > majorite.size():
				majorite = signatures[sig]
		var ref: String = majorite[0]
		var points_ref: Dictionary = de_noeud[ref]
		# Les segments de la section de référence, dans le repère de la RACINE de la classe, et leur orbite.
		var p := ref.split("|")
		var m_ref: RefCounted = t.tuiles[p[0]]
		var axe_r := int(p[1])
		var plan_r := 0.5 * int(p[2])
		var segments: Array = []
		for f in m_ref.faces:
			var face: PackedInt32Array = f
			for j in face.size():
				var a: Vector3 = m_ref.sommets[face[j]]
				var b: Vector3 = m_ref.sommets[face[(j + 1) % face.size()]]
				if absf(a[axe_r] - plan_r) < 0.0005 and absf(b[axe_r] - plan_r) < 0.0005:
					var qa: Vector2 = s.appliquer(s._carte_de[ref], s._dans_la_face(a, axe_r))
					var qb: Vector2 = s.appliquer(s._carte_de[ref], s._dans_la_face(b, axe_r))
					for h in s._groupes[k]:
						segments.append([s.appliquer(h, qa), s.appliquer(h, qb)])
		# Les points de la majorité dans le repère RACINE (orbite comprise), puis chaque nœud hors majorité.
		var maj := {}
		for canon in points_ref:
			for h in s._groupes[k]:
				maj[s.appliquer_i(h, canon)] = true
		var a_inserer: Array = []   # [nœud, point racine] : les manquants qu'aucun intrus n'a pris
		var sommets_de := {}   # nœud → [{cle, i, q}]
		for cle in s.bords:
			for i in s.bords[cle]:
				for f in s.bords[cle][i]:
					if f["classe"] != k:
						continue
					if not sommets_de.has(f["noeud"]):
						sommets_de[f["noeud"]] = []
					sommets_de[f["noeud"]].append({"cle": cle, "i": i, "q": f["q"]})
		for n in sommets_de:
			if majorite.has(n):
				continue
			var presents := {}
			var intrus: Array = []
			for e in sommets_de[n]:
				presents[e["q"]] = true
				if not maj.has(e["q"]):
					intrus.append(e)
			# 1. Les points majoritaires MANQUANTS prennent les intrus, par paires de la plus courte à la plus longue
			#    (jusqu'à `RAYON_D_APPARIEMENT`) : les coins de la section reviennent, sans envoyer un intrus au loin.
			var cibles := {}   # indice dans intrus → point racine (Vector2)
			var manquants: Array = maj.keys().filter(func(m): return not presents.has(m))
			var paires: Array = []
			for mq in manquants:
				for j in intrus.size():
					paires.append([Vector2(intrus[j]["q"]).distance_to(Vector2(mq)) / s.QUANTUM, mq, j])
			paires.sort_custom(func(x, y): return x[0] < y[0])
			var pris := {}
			for pr in paires:
				if pr[0] > RAYON_D_APPARIEMENT or pris.has(pr[1]) or cibles.has(pr[2]):
					continue
				pris[pr[1]] = true
				cibles[pr[2]] = Vector2(pr[1]) / s.QUANTUM
			for mq in manquants:
				if not pris.has(mq):
					a_inserer.append([n, Vector2(mq) / s.QUANTUM])
			# 2. Les autres intrus glissent sur la section majoritaire.
			for j in intrus.size():
				if cibles.has(j):
					continue
				var q: Vector2 = Vector2(intrus[j]["q"]) / s.QUANTUM
				var d_min := INF
				for sg in segments:
					var c: Vector2 = Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1])
					if c.distance_to(q) < d_min:
						d_min = c.distance_to(q)
						cibles[j] = c
			for j in cibles:
				var e: Dictionary = intrus[j]
				var cle: String = e["cle"]
				var axe := int(String(n).split("|")[1])
				var m: RefCounted = t.tuiles[cle]
				var v: Vector3 = m.sommets[e["i"]]
				var autres := 0
				for a2 in 3:
					if a2 != axe and absf(absf(v[a2]) - 0.5) < 0.0005:
						autres += 1
				if autres > 0:
					bilan["sur_arete"] += 1
					continue
				if not touchees.has(cle):
					var toutes: Array = []
					for fi in m.faces.size():
						toutes.append(fi)
					touchees[cle] = m.gardes_de_repli(toutes)
				var vers: Vector2 = cibles[j]
				m.sommets[e["i"]] = s._hors_de_la_face(v, axe, s.appliquer(s.inverse(s._carte_de[n]), vers))
				bilan["deplaces"] += 1
				bilan["plus_loin"] = maxf(bilan["plus_loin"], (Vector2(e["q"]) / s.QUANTUM).distance_to(vers))
		# 3. Un manquant qu'aucun intrus n'a pris : inséré sur l'arête de bord la plus proche de sa face (plus loin
		#    que `RAYON_D_APPARIEMENT` : dit, jamais inventé), puis posé exactement.
		for ai in a_inserer:
			var n2: String = ai[0]
			var pp := n2.split("|")
			var cle2: String = pp[0]
			var axe2 := int(pp[1])
			var plan2 := 0.5 * int(pp[2])
			var m2: RefCounted = t.tuiles[cle2]
			var cible3: Vector3 = s._hors_de_la_face(Vector3.ZERO, axe2, s.appliquer(s.inverse(s._carte_de[n2]), ai[1]))
			cible3[axe2] = plan2
			var meilleure := Vector2i(-1, -1)
			var d_min := INF
			var sur := Vector3.ZERO
			for f in m2.faces:
				var face: PackedInt32Array = f
				for j in face.size():
					var va: Vector3 = m2.sommets[face[j]]
					var vb: Vector3 = m2.sommets[face[(j + 1) % face.size()]]
					if absf(va[axe2] - plan2) >= 0.0005 or absf(vb[axe2] - plan2) >= 0.0005:
						continue
					var c3: Vector3 = Geometry3D.get_closest_point_to_segment(cible3, va, vb)
					if c3.distance_to(cible3) < d_min and c3.distance_to(va) > 1e-4 and c3.distance_to(vb) > 1e-4:
						d_min = c3.distance_to(cible3)
						meilleure = m2.arete(face[j], face[(j + 1) % face.size()])
						sur = c3
			if meilleure.x < 0 or d_min > RAYON_D_APPARIEMENT:
				bilan["non_inseres"] += 1
				var bord := []
				for v in m2.sommets:
					if absf(v[axe2] - plan2) < 0.0005:
						bord.append(s.appliquer(s._carte_de[n2], s._dans_la_face(v, axe2)))
				print("    non inséré : %s, point %s, arête la plus proche à %.4f ; section de la face : %s" % [n2, ai[1], d_min, bord])
				continue
			if not touchees.has(cle2):
				var toutes2: Array = []
				for fi in m2.faces.size():
					toutes2.append(fi)
				touchees[cle2] = m2.gardes_de_repli(toutes2)
			var neuf: int = m2._inserer_sur_arete(meilleure, sur)
			if neuf < 0:
				bilan["non_inseres"] += 1
				continue
			m2.sommets[neuf] = cible3
			bilan["inseres"] += 1
			bilan["plus_loin"] = maxf(bilan["plus_loin"], d_min)
	bilan["tuiles"] = touchees.size()
	for cle in touchees:
		if t.tuiles[cle].replie(touchees[cle]):
			bilan["replies"] += 1
	return bilan


## Les sommets posés sur le plan d'un joint du témoin qui n'ont PAS de partenaire exact dans la tuile d'en face
## (recopié de `test_sections._sans_partenaire` : une autorité qui ne passe pas par `sections.gd`).
func _sans_partenaire(t: RefCounted) -> int:
	var occ := {}
	for o in t.occurrences:
		occ[o["sommet"]] = o
	var n := 0
	for s in occ:
		var oa: Dictionary = occ[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ.has(s + e):
					continue
				var ob: Dictionary = occ[s + e]
				var tb: RefCounted = t.tuiles[ob["cle"]]
				var index_b := {}
				for j in tb.sommets.size():
					index_b[Vector3i(((ob["pose"] as Transform3D) * tb.sommets[j] * 10000.0).round())] = true
				var ta: RefCounted = t.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in ta.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * ta.sommets[i]
					if absf(pw[axe] - plan) <= 0.0005 and not index_b.has(Vector3i((pw * 10000.0).round())):
						n += 1
	return n
