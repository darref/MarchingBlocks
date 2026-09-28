extends SceneTree

## SONDE — LES LÈVRES D'UN SOUS-VOXEL, CELLES QUE JORDAN APPELLE « CONTREMARCHES »
##
## ⚠ **JORDAN, 26 septembre 2026, corrigeant ma cible** : *« tu as mis à 45 degrés quelque chose de
## plus grand que les contremarches ; ce que j'appelle les contremarches était juste des rebords de
## 1 sous-voxel qui longeaient chaque transition de formes, et ils étaient très facilement
## reconnaissables. »*
##
## ⚠ **J'AVAIS MESURÉ LA MAUVAISE CHOSE PENDANT TOUT UN TOUR.** `sonde_reste_t_il_des_marches` prouve —
## correctement — qu'il ne reste aucune paroi verticale sur une chute d'UNE CELLULE. Mais la plainte ne
## portait pas sur les cellules : elle porte sur le rebord que l'AMINCISSEMENT pose là où une face se
## rétracte d'un sous-voxel tandis que celle d'en dessous reste à fleur. Ce fait est déjà dans la charte
## §4 (« 91 paliers larges d'un seul sous-voxel sur 261 ») — je ne l'ai pas relié à ce qu'il décrivait.
##
## ── D'OÙ VIENT LA LÈVRE, ET POURQUOI ELLE LONGE CHAQUE TRANSITION ───────────────────────────────────
##
## L'amincissement rentre une face d'un sous-voxel **quand elle donne sur du vide**, et la laisse à
## fleur quand elle touche une case pleine. Le long d'un mur droit, toutes les cases ont le même voisin
## vide : le mur reste plan. Mais là où la silhouette change — une case de plus, une case de moins —
## la case du haut se rétracte et celle du dessous non. **Il reste une bande plate d'exactement un
## sous-voxel, qui suit la transition.** Ce n'est pas un bogue du mailleur : c'est la définition de
## l'aminci.
##
## ── L'INSTRUMENT ────────────────────────────────────────────────────────────────────────────────────
##
## On échantillonne le CHAMP DE HAUTEURS **du maillage rendu**, à un huitième de case — deux points par
## sous-voxel, le minimum pour qu'une bande d'un sous-voxel existe. On y découpe les **PLATS** : les
## régions connexes de même hauteur. L'épaisseur d'un plat est le rayon du plus gros disque qu'il
## contient, obtenu par propagation depuis ses bords. Une lèvre d'un sous-voxel a une épaisseur de
## 1 point ; une terrasse d'une case en a 4.
##
## ⚠ **UN POINT EST PLAT PARCE QUE SON TRIANGLE EST HORIZONTAL, JAMAIS PARCE QUE SES VOISINS SONT À LA
## MÊME HAUTEUR — et la seconde version s'y est fait prendre.** En groupant les points de hauteur égale,
## chaque point d'une PENTE forme une région d'un seul point, donc « un plat épais d'un point » : la
## sonde annonçait 458 lèvres sur les faces directes et 392 sur le lissé, c'est-à-dire un décompte de
## la surface inclinée. On lit donc la normale du triangle qui a gagné l'échantillon ; une pente
## n'apporte alors plus aucun point, et il n'y a plus rien à confondre.
##
## ⚠ **LA PREMIÈRE VERSION MESURAIT PAR LIGNES DE BALAYAGE, ET ELLE A DÉMENTI SA PROPRE PRÉDICTION POUR
## UNE MAUVAISE RAISON.** Elle relevait la longueur des suites de points de même hauteur, ligne par
## ligne : sur un plat RECTILIGNE (l'aminci, le solide) c'est bien la largeur, mais sur un plat
## TRIANGULAIRE — ce que produit la triangulation en éventail des faces directes — chaque ligne se
## termine par deux ou trois points, et la pointe du triangle se compte comme une lèvre. Elle annonçait
## ainsi **147 lèvres** sur un mailleur qui n'a aucun sous-voxel, et dont tous les sommets sont sur un
## réseau au demi-case. Une épaisseur ne dépend d'aucune direction ; une largeur de ligne, si.
##
## ⚠ **LIRE LE MAILLAGE ET NON L'OCCUPATION, C'EST CE QUI REND LES TROIS CANDIDATS COMPARABLES.**
## `sonde_escaliers` lit `BM.sous_voxels()` : elle ne sait donc rien dire ni du lissé ni des faces
## directes, qui n'ont pas de sous-voxels du tout. Trois mailleurs jugés par trois instruments ne se
## comparent pas (charte §6).
##
## ⚠ **ELLE NE VOIT QUE LA SURFACE DU DESSUS**, comme `sonde_escaliers` : ni surplombs, ni plafonds de
## grotte. C'est assumé — les rebords que Jordan désigne sont sur ce qu'on voit d'en haut.
##
## ⚠ **PRÉDICTION, ÉCRITE AVANT LA MESURE** (charte §6) :
##   • l'AMINCI, ce qui part aujourd'hui chez l'artiste → beaucoup de paliers d'un sous-voxel ;
##   • les FACES DIRECTES → **aucun**, ce mailleur n'a pas de sous-voxels : tous ses sommets tombent
##     sur un réseau au demi-case (les milieux des arêtes du cube de la pièce) ;
##   • le LISSÉ à 0,35 → inconnu, et c'est précisément la question : le chanfrein suspendu suffit-il ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_rebords_un_sous_voxel.gd

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
## ⚠ Pour `triangles_de()` : un `.glb` revenu de Blender est INDEXÉ, les maillages d'ici ne le sont pas.
const Topologie := preload("res://DEV_TOOLS/topologie.gd")

## ⚠ **`--fichier=<le .glb>` FAIT ENTRER LE SCULPT DE JORDAN DANS LE MÊME TABLEAU.** Le 26 septembre
## 2026, plutôt que de décrire son geste, il l'a modelé sur le témoin : c'est la seule façon de le
## mesurer sans l'interpréter — et j'avais déjà interprété de travers une fois ce jour-là.
var _fichier := ""

const COTE := 8
## Un SEIZIÈME de case. ⚠ **LA RÉSOLUTION EST CELLE DU PLUS PETIT DÉTAIL MESURÉ, PAS CELLE DE LA
## QUESTION POSÉE.** Elle valait 0,125 — deux points par sous-voxel — ce qui suffit tant que la
## géométrie ne descend pas sous 0,25. Le chanfrein à 1/8 de case y a mis des faces de 0,125 : un seul
## point par détail, donc des régions d'un point partout, et la sonde lui trouvait **15 lèvres** là où
## il n'en a pas. Deux points par plus petit détail, toujours.
const PAS := 0.0625
## À partir de quand une face est HORIZONTALE. ⚠ **Le seuil doit être serré, et j'ai payé le contraire.**
## À 0,99 — huit degrés de tolérance — le lissé à 0,35 rendait 281 « lèvres » : ce n'étaient pas des
## lèvres mais les facettes d'un chanfrein DOUX, qui penche de quelques degrés seulement. Une vraie
## lèvre est EXACTEMENT horizontale, un chanfrein ne l'est jamais ; le seuil est donc à la précision
## machine près, et il sépare alors les deux sans rien supposer.
const HORIZONTAL := 0.9999
## Deux hauteurs sont « la même » en deçà de ça. ⚠ Il doit rester très loin sous la pente à 45°, qui
## monte de PAS par point : sinon une rampe se lirait comme un palier, et tout serait faux.
##
## ⚠ **IL EST DÉRIVÉ DE `HORIZONTAL`, ET IL A ÉTÉ ÉCRIT EN DUR — C'EST CE QUI A FAIT MENTIR LA SONDE SUR
## LE SCULPT DE JORDAN.** À 0,0005, il était BIEN PLUS STRICT que le seuil d'horizontalité : une face
## que `HORIZONTAL` accepte peut pencher de 0,8°, donc monter de 0,0018 par point — trois fois le seuil.
## Chaque point d'un grand plat à peine incliné formait donc sa propre région, et la sonde annonçait
## **201 lèvres** sur un maillage qui n'en a aucune. Deux seuils qui décrivent la même tolérance doivent
## être DÉDUITS l'un de l'autre, jamais écrits deux fois (charte §6).
const PLAT := PAS * 3.0 * sqrt(1.0 - HORIZONTAL * HORIZONTAL) / HORIZONTAL
## Un sous-voxel, en cases. La largeur qu'on traque.
const SOUS_VOXEL := 0.25


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
	print("=== LES REBORDS D'UN SOUS-VOXEL ===\n")
	print("PRÉDICTION (écrite avant la mesure) :")
	print("   l'AMINCI (ce qui part)  → beaucoup de plats épais d'UN sous-voxel")
	print("   les FACES DIRECTES      → aucun : ce mailleur n'a pas de sous-voxels")
	print("   le LISSÉ à 0,35         → inconnu, c'est la question\n")

	_examiner("L'AMINCI — CE QUI PART AUJOURD'HUI CHEZ L'ARTISTE", BM.maillage_moitie(0))
	_examiner("LE LISSÉ à 0,35 — le chanfrein suspendu", BM.maillage_lisse(0, 0.5, 0.35))
	_examiner("LE LISSÉ à 1,00 — le maillage dual complet", BM.maillage_lisse(0, 0.5, 1.0))
	_examiner("LES FACES DIRECTES — le mailleur d'hier soir", BM.maillage_direct(0))
	# ⚠ La piste bâtie sur le geste MESURÉ de Jordan, pas sur une intention (voir `maillage_chanfreine`).
	_examiner("LE CHANFREIN à 1/8 de case — la piste", BM.maillage_chanfreine(0))
	# ⚠ **LE CONTRÔLE QUI DOIT ROUGIR À L'ENVERS** : le SOLIDE, sans amincissement, n'a aucune lèvre —
	# la charte le mesure déjà (« ses 244 contremarches sont à 100 % des multiples d'une cellule »). Si
	# la sonde lui en trouvait, c'est elle qui serait fausse, pas le solide.
	_examiner("LE SOLIDE (retrait 0) — il ne doit avoir AUCUNE lèvre", BM.maillage(0))

	if _fichier != "":
		var sculpte: ArrayMesh = _lire(_fichier)
		if sculpte == null:
			print("⚠ illisible comme glTF : %s
" % _fichier)
		else:
			_examiner("LE SCULPT DE JORDAN — %s" % _fichier.get_file(), sculpte)

	print("⚠ Cette sonde ne voit que la surface du DESSUS : ni surplombs, ni plafonds de grotte.")
	quit(0)


func _examiner(quoi: String, mesh: ArrayMesh) -> void:
	print("── %s ──" % quoi)
	if mesh.get_surface_count() == 0:
		print("   ⚠ aucune surface\n")
		return
	var champ: Dictionary = _champ_de_hauteurs(mesh)
	var epaisseurs: Array = _plats(champ["hauteur"], champ["horizontal"])

	var par_epaisseur := {}
	for e in epaisseurs:
		par_epaisseur[e] = int(par_epaisseur.get(e, 0)) + 1
	var clefs: Array = par_epaisseur.keys()
	clefs.sort()
	print("   plats relevés : %d" % epaisseurs.size())
	var levres := 0
	for e in clefs:
		var cases: float = float(e) * 2.0 * PAS
		var marque := ""
		if float(e) * 2.0 * PAS <= SOUS_VOXEL + 0.001:
			marque = "   ← LA LÈVRE D'UN SOUS-VOXEL"
			levres += int(par_epaisseur[e])
		print("      épaisseur %d point(s) ≈ %.3f case : %d plat(s)%s"
			% [e, cases, par_epaisseur[e], marque])
	print("   → LÈVRES D'UN SOUS-VOXEL OU MOINS : %d   %s\n"
		% [levres, "⚠ c'est ce que Jordan voit" if levres > 0 else "✓ aucune"])


## LE CHAMP DE HAUTEURS DU MAILLAGE : pour chaque point de la grille, le plus haut triangle au-dessus.
##
## ⚠ **ON RASTÉRISE LES TRIANGLES PLUTÔT QUE DE LANCER DES RAYONS.** Un lancer de rayon demanderait un
## monde physique et des corps ; ici la géométrie suffit, et rien ne dépend d'un moteur.
## ⚠ Les triangles VERTICAUX se projettent sur une aire nulle : ils n'ont pas de hauteur à donner et
## sont écartés, sans quoi une division par zéro peuplerait le champ de valeurs infinies.
func _champ_de_hauteurs(mesh: ArrayMesh) -> Dictionary:
	var v: PackedVector3Array = Topologie.triangles_de(mesh)
	var hauteur := {}
	# ⚠ La normale GÉOMÉTRIQUE, pas celle qui est stockée : souder force une normale moyenne par
	# sommet, et une face parfaitement horizontale en ressortirait penchée (charte §4).
	var horizontal := {}
	for t in range(0, v.size() - 2, 3):
		var a: Vector3 = v[t]
		var b: Vector3 = v[t + 1]
		var c: Vector3 = v[t + 2]
		var aire: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(aire) < 0.000001:
			continue
		var x0: int = floori(minf(a.x, minf(b.x, c.x)) / PAS)
		var x1: int = ceili(maxf(a.x, maxf(b.x, c.x)) / PAS)
		var z0: int = floori(minf(a.z, minf(b.z, c.z)) / PAS)
		var z1: int = ceili(maxf(a.z, maxf(b.z, c.z)) / PAS)
		for i in range(x0, x1 + 1):
			for j in range(z0, z1 + 1):
				var px: float = (float(i) + 0.5) * PAS
				var pz: float = (float(j) + 0.5) * PAS
				var u: float = ((b.x - px) * (c.z - pz) - (c.x - px) * (b.z - pz)) / aire
				var w: float = ((c.x - px) * (a.z - pz) - (a.x - px) * (c.z - pz)) / aire
				var t2: float = 1.0 - u - w
				if u < -0.0001 or w < -0.0001 or t2 < -0.0001:
					continue
				var y: float = u * a.y + w * b.y + t2 * c.y
				var cle := Vector2i(i, j)
				if not hauteur.has(cle) or y > float(hauteur[cle]):
					hauteur[cle] = y
					var normale: Vector3 = (b - a).cross(c - a).normalized()
					horizontal[cle] = absf(normale.y) > HORIZONTAL
	return {"hauteur": hauteur, "horizontal": horizontal}


## LES PLATS et leur ÉPAISSEUR : régions connexes de même hauteur, mesurées par propagation.
##
## ⚠ **L'ÉPAISSEUR EST LE RAYON DU PLUS GROS DISQUE INSCRIT**, en points de grille : on marque à 1 tout
## point du plat qui touche l'extérieur, puis l'on propage. Un ruban large de deux points rend 1 ; une
## terrasse d'une case, 4. C'est ce qui distingue une LÈVRE d'une pointe de plat triangulaire, qu'une
## mesure par lignes confondait.
##
## ⚠ **ON N'INCLUT PAS LES DIAGONALES DANS LE VOISINAGE.** Un ruban en escalier vu en 8-connexité se
## replie sur lui-même et paraît deux fois plus épais qu'il n'est.
func _plats(hauteur: Dictionary, horizontal: Dictionary) -> Array:
	var restants := {}
	for c in hauteur:
		if bool(horizontal.get(c, false)):
			restants[c] = true
	var voisinage: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var sortie: Array = []
	while not restants.is_empty():
		var depart: Vector2i = restants.keys()[0]
		var y0: float = float(hauteur[depart])
		var region := {}
		var pile: Array = [depart]
		restants.erase(depart)
		region[depart] = true
		while not pile.is_empty():
			var p: Vector2i = pile.pop_back()
			for d in voisinage:
				var q: Vector2i = p + d
				if not restants.has(q):
					continue
				if absf(float(hauteur[q]) - y0) >= PLAT:
					continue
				restants.erase(q)
				region[q] = true
				pile.append(q)
		sortie.append(_epaisseur(region, voisinage))
	return sortie


## Le rayon du plus gros disque inscrit dans une région, en points. Propagation depuis les bords.
func _epaisseur(region: Dictionary, voisinage: Array) -> int:
	var distance := {}
	var front: Array = []
	for c in region:
		var p: Vector2i = c
		for d in voisinage:
			if not region.has(p + d):
				distance[p] = 1
				front.append(p)
				break
	var i := 0
	var maxi_vu := 0
	while i < front.size():
		var p: Vector2i = front[i]
		i += 1
		var dp: int = int(distance[p])
		maxi_vu = maxi(maxi_vu, dp)
		for d in voisinage:
			var q: Vector2i = p + d
			if region.has(q) and not distance.has(q):
				distance[q] = dp + 1
				front.append(q)
	return maxi_vu


## Le maillage d'un `.glb`. ⚠ **ON RECONNAÎT UN NŒUD À CE QU'IL SAIT FAIRE, pas à sa classe** : le
## chemin glTF de l'éditeur rend des `ImporterMeshInstance3D`, qui n'héritent PAS de `MeshInstance3D`,
## et un `is MeshInstance3D` déclarait « aucun ArrayMesh » sur un fichier parfaitement valide (charte §4).
func _lire(chemin: String) -> ArrayMesh:
	if not FileAccess.file_exists(chemin):
		return null
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(chemin, etat) != OK:
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		return null
	var trouve: ArrayMesh = _chercher(scene)
	scene.queue_free()
	return trouve


func _chercher(noeud: Node) -> ArrayMesh:
	if noeud.has_method("get_mesh"):
		var m = noeud.call("get_mesh")
		if m is ArrayMesh:
			return m
	for enfant in noeud.get_children():
		var t: ArrayMesh = _chercher(enfant)
		if t != null:
			return t
	return null
