extends "res://DEV_TOOLS/filmer_transitions.gd"
##
## DEVLOG — L'ATELIER TRANSITIONS, DEUXIÈME VERSION. Demandée par Jordan (7 octobre 2026 : « refait la vidéo sans oublier
## la transition entre CHAQUE matière »). La playlist : D:/SpannerGames/PROJETS/MarchingBlocks/CLAUDE.md ; l'atelier :
## charte du produit §5, « L'atelier Transitions ». Hérite de la v1 (`filmer_transitions.gd`, inchangée) : le monde, les
## aides (curseurs, listes, glissés), le Play test.
##
## CE QUI CHANGE PAR RAPPORT À LA V1 :
##   - CHAQUE PAIRE de matières du monde (les trois couches de l'exemple : trois paires) est montrée franche, puis cochée,
##     RÉGLÉE et montrée fondue ; à la fin, aucune frontière franche ne reste à l'image (vérifié sur des images extraites) ;
##   - chaque couche prend le DESSUS de son témoin pour représentant (la v1 laissait la falaise à GreyRock) ;
##   - UP / DOWN est tourné (le défaut de la bande restée à l'ancienne frontière est corrigé dans `main`, `7a7f665`) : la
##     couche du bas de la liste monte en haut, et qui couvre s'inverse à TOUTES ses frontières ;
##   - aucun réglage final n'est « net » (Softness au plus bas) : un trait net serait une frontière franche.
##
## LANCEMENT — dans la COPIE de tournage (worktree à part, `custom_user_dir_name="MB_tournage_transitions2"`) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_transitions_v2.gd D:/MB_tournage_transitions2/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/MB_tournage_transitions2 --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/transitions_v2.avi \
##       --script res://DEV_TOOLS/filmer_transitions_v2.gd
##   `-- --seulement=materiaux` : les couches, leurs matériaux, les frontières de chaque paire, puis quitte.

## Les trois paires, dans l'ordre où la vidéo les montre : [a, b, nom à l'écran, point près de leur frontière].
var _paires_v2: Array = []
## La couche qui montera en haut de la liste (Up) : celle du bas.
var _montante := ""


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	_tr = _ecran._transitions
	for i in _ecran._couches.size():
		var c: Dictionary = _ecran._couches[i]
		_couche[str(c.get("nom", ""))] = i
		_id[str(c.get("nom", ""))] = str(c.get("id", ""))
	print("couches (rang 0 = la plus haute de la liste) : %s, ids %s" % [_couche, _id])
	for c in _ecran._couches:
		var mats: Array = _tr.materiaux_de(c)
		print("matériaux de %s (représentant par défaut %d) :" % [c["nom"], _tr.indice_representant(c)])
		for k in mats.size():
			print("   %d %s %s %s" % [k, mats[k].get("nom", "?"), mats[k].get("couleur", ""), mats[k].get("texture", "")])
	_paires_v2 = [
		["Grass", "Desert", "Grass · Sand", T_CENTRES["Grass"].lerp(T_CENTRES["Desert"], 0.5)],
		["GreyRock", "Grass", "Rock · Grass", T_CENTRES["GreyRock"].lerp(T_CENTRES["Grass"], 0.5)],
		["GreyRock", "Desert", "Rock · Sand", T_CENTRES["GreyRock"].lerp(T_CENTRES["Desert"], 0.5)],
	]
	_montante = str(_ecran._couches[_ecran._couches.size() - 1]["nom"])
	if _seulement == "materiaux":
		_t_relief()
		_t_compter_les_frontieres()
		_rendre_les_reglages()
		quit(0)
		return
	_cam_haut = false
	_aides()
	_plan("monde_bati")
	await _t_batir()
	_t_compter_les_frontieres()
	# ⚠ « toutes » APRÈS Échap (« monde ») : dans l'atelier, les endroits peints portent une TEINTE JAUNE unie aux bords
	# nets — vue à la première prise, elle passait pour une frontière franche et cachait le fondu dessous.
	var parties := ["franc", "paires", "reglages", "rocherbe", "sens", "ordre", "pinceau", "monde", "toutes", "jeu"]
	for partie in parties:
		if _seulement != "" and _seulement != partie:
			continue
		_plan(partie)
		await Callable(self, "_v2_" + partie).call()
		await _images(int(0.4 * FPS))
	_plan("fin")
	_t_etat_final()
	_rendre_les_reglages()
	quit(0)


## Chaque paire : combien de faces de colonnes la séparent, au même niveau et en marche (la vidéo exige qu'elles se
## touchent toutes).
func _t_compter_les_frontieres() -> void:
	for p in _paires_v2:
		var meme := 0
		var marche := 0
		for k in _th:
			if _tm[k] != p[0]:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = k + d
				if _th.has(n) and _tm[n] == p[1]:
					if _th[n] == _th[k]:
						meme += 1
					else:
						marche += 1
		print("frontière %s | %s : %d faces au même niveau, %d en marche ; point de vue %s" % [p[0], p[1], meme, marche,
			_t_bord(p[0], p[1], p[3])])


## L'état relu à la fin : chaque paire allumée, ses deux réglages, les représentants, l'ordre.
func _t_etat_final() -> void:
	print("ORDRE FINAL : %s" % [_ecran._couches.map(func(c): return c["nom"])])
	for cle in _tr.etat["paires"]:
		print("PAIRE %s : %s" % [cle, _tr.etat["paires"][cle]])
	print("REPRÉSENTANTS : %s" % [_tr.etat["representants"]])
	print("CHOIX PEINTS : %d" % (_tr.etat["choix"] as Dictionary).size())
	print("MATÉRIAUX PORTANT LE PASSAGE : %d" % _tr.materiaux_branches())


## Le plan rapproché d'une frontière (la paire i de `_paires_v2`).
func _v2_vue_bord(i: int, recul := 1.0) -> void:
	var p: Array = _paires_v2[i]
	var b := _t_bord(p[0], p[1], p[3])
	_regarder(b + Vector3(-2, 6.5, 8) * recul, b)


func _v2_vue_carrefour() -> void:
	var c := _t_carrefour()
	_regarder(c + Vector3(-6, 13, 15), c)


# ── 1. LES TROIS FRONTIÈRES FRANCHES ────────────────────────────────────────────────────────────────

func _v2_franc() -> void:
	_v2_vue_carrefour()
	await _images(6)
	_montrer("Same level", "Three layers, three hard borders")
	await _t_derive(3.0, 0.004)
	for i in _paires_v2.size():
		_v2_vue_bord(i)
		await _images(4)
		_montrer("No transition", "%s: cell by cell" % _paires_v2[i][2])
		await _t_derive(2.2, 0.003)


# ── 2. CHAQUE PAIRE COCHÉE, LE REPRÉSENTANT DE CHAQUE COUCHE ────────────────────────────────────────

func _v2_paires() -> void:
	_v2_vue_bord(0)
	await _cliquer_bouton("Transitions", "The Transitions workshop", "Where two layers meet")
	await _images(int(0.8 * FPS))
	await _t_cocher("Grass", "Desert", "Pair 1 of 3: grass and sand blend")
	await _images(int(1.4 * FPS))
	# ⚠ LE REPRÉSENTANT PAR DÉFAUT est le matériau que le témoin porte le plus : dans l'exemple, la FALAISE (Material 2) —
	# une bande brune. Le vrai geste : prendre le dessus (Material 1), pour CHAQUE couche (la v1 oubliait GreyRock).
	_montrer("Default", "Each layer blends its most-worn material: the cliff")
	await _images(int(1.8 * FPS))
	await _t_representant("Grass", "Material 1", "Grass blends its top: the grass")
	await _images(int(0.6 * FPS))
	await _t_representant("Desert", "Material 1", "Desert blends its top: the sand")
	await _images(int(1.6 * FPS))
	_v2_vue_bord(1)
	await _images(6)
	_montrer("Rock · Grass", "Still a hard border")
	await _images(int(1.2 * FPS))
	await _t_cocher("GreyRock", "Grass", "Pair 2 of 3: rock and grass")
	await _images(int(1.0 * FPS))
	await _t_representant("GreyRock", "Material 1", "GreyRock blends its top: the rock")
	await _images(int(1.4 * FPS))
	_v2_vue_bord(2)
	await _images(6)
	_montrer("Rock · Sand", "Still a hard border")
	await _images(int(1.2 * FPS))
	await _t_cocher("GreyRock", "Desert", "Pair 3 of 3: rock and sand")
	await _images(int(1.6 * FPS))
	_v2_vue_carrefour()
	await _images(6)
	_montrer("Transitions", "Three pairs, three blends: the tiles do not change")
	await _t_derive(3.0, 0.004)


# ── 3. GRASS · DESERT : chaque réglage en direct ────────────────────────────────────────────────────

func _v2_reglages() -> void:
	await _t_choisir_paire("Grass", "Desert")
	var haut := _t_prioritaire("Grass", "Desert")
	var b := _t_bord("Grass", "Desert", _paires_v2[0][3])
	_regarder(b + Vector3(-1.5, 5.5, 6.5), b)
	await _images(8)
	await _t_curseur(haut, "largeur", 0.05, 1.2, "Softness", "Low: a sharp line")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "largeur", 1.0, 1.4, "Softness", "High: a long blend")
	await _images(int(0.6 * FPS))
	await _t_curseur(haut, "largeur", 0.6, 0.7, "Softness", "In between")
	await _t_curseur(haut, "avance", 0.5, 1.4, "Reach", "The covering layer spreads further")
	await _images(int(0.5 * FPS))
	await _t_curseur(haut, "avance", -0.5, 1.6, "Reach", "…or holds back")
	await _images(int(0.5 * FPS))
	await _t_curseur(haut, "avance", 0.4, 0.9, "Reach", "")
	await _t_curseur(haut, "bruit", 1.0, 1.2, "Irregularity", "An uneven edge")
	await _images(int(0.5 * FPS))
	await _t_curseur(haut, "grain", 5.0, 1.4, "Grain", "Finer irregularity")
	await _images(int(0.5 * FPS))
	await _t_curseur(haut, "grain", 1.2, 0.9, "Grain", "Coarser")
	await _images(int(0.5 * FPS))
	await _t_curseur(haut, "creux", 1.0, 1.2, "Fills hollows", "It settles in the dark parts first")
	await _images(int(1.0 * FPS))


# ── 4. GREYROCK · GRASS : la deuxième paire a ses propres réglages ──────────────────────────────────

func _v2_rocherbe() -> void:
	await _t_choisir_paire("GreyRock", "Grass")
	var haut := _t_prioritaire("GreyRock", "Grass")
	var bas := "Grass" if haut == "GreyRock" else "GreyRock"
	var b := _t_bord("GreyRock", "Grass", _paires_v2[1][3])
	_regarder(b + Vector3(-1.5, 5.5, 6.5), b)
	await _images(8)
	_montrer("Rock · Grass", "Its own settings")
	await _images(int(0.8 * FPS))
	await _t_curseur(haut, "largeur", 0.85, 1.2, "Softness", "A wide, soft blend")
	await _images(int(0.4 * FPS))
	await _t_curseur(haut, "bruit", 0.8, 1.0, "Irregularity", "Patchy")
	await _images(int(0.4 * FPS))
	await _t_curseur(haut, "creux", 1.0, 1.0, "Fills hollows", "%s fills the hollows of %s" % [haut, bas])
	await _images(int(1.2 * FPS))


# ── 5. GREYROCK · DESERT : les deux sens d'une paire ────────────────────────────────────────────────

func _v2_sens() -> void:
	await _t_choisir_paire("GreyRock", "Desert")
	var haut := _t_prioritaire("GreyRock", "Desert")
	var bas := "Desert" if haut == "GreyRock" else "GreyRock"
	_v2_vue_bord(2, 0.9)
	await _images(8)
	# ⚠ AUCUN RÉGLAGE NET : Softness 0,35 au plus bas — un trait net serait une frontière franche à la fin.
	_montrer("Two settings", "When %s covers %s…" % [haut, bas])
	await _t_curseur(haut, "largeur", 0.35, 0.9, "Softness", "")
	await _t_curseur(haut, "bruit", 0.9, 0.9, "Irregularity", "")
	await _t_curseur(haut, "grain", 3.0, 0.9, "Grain", "")
	await _images(int(0.5 * FPS))
	_montrer("Two settings", "…and when %s covers %s" % [bas, haut])
	await _t_curseur(bas, "largeur", 0.9, 0.9, "Softness", "")
	await _t_curseur(bas, "avance", 0.4, 0.9, "Reach", "")
	await _t_curseur(bas, "creux", 1.0, 0.9, "Fills hollows", "")
	await _images(int(0.6 * FPS))


# ── 6. L'ORDRE : Up — la couche du bas de la liste passe en haut, et couvre à toutes ses frontières ─────

func _v2_ordre() -> void:
	var autres: Array = []
	for i in _paires_v2.size():
		if _paires_v2[i][0] == _montante or _paires_v2[i][1] == _montante:
			autres.append(i)
	# Avant : chaque frontière de la couche du bas, de près.
	for i in autres:
		var p: Array = _paires_v2[i]
		var autre: String = p[1] if p[0] == _montante else p[0]
		_v2_vue_bord(i, 0.8)
		await _images(4)
		_montrer("Layer order", "%s is higher: it covers %s" % [autre, _montante])
		await _t_derive(1.8, 0.002)
	_v2_vue_carrefour()
	await _images(6)
	var b := _t_bouton_couche(_montante)
	if b == null:
		print("⚠ couche introuvable : %s" % _montante)
		return
	await _t_rendre_visible(b)
	await _bouger(b.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", "The layer %s, last in the list" % _montante)
	await _images(int(0.4 * FPS))
	for n in _ecran._couches.size():
		if _couche_rang(_montante) == 0:
			break
		var avant: int = _ecran._active
		await _cliquer_bouton("Up", "Up: %s moves up the list" % _montante, "Moves the active layer up")
		await _images(int(0.8 * FPS))
		if _ecran._active == avant:
			print("⚠ Up n'a rien fait")
			break
	print("ordre après Up : %s" % [_ecran._couches.map(func(c): return c["nom"])])
	_montrer("Layer order", "%s is on top: it covers at every border" % _montante)
	await _t_derive(2.2, 0.004)
	for i in autres:
		var p: Array = _paires_v2[i]
		var autre: String = p[1] if p[0] == _montante else p[0]
		_v2_vue_bord(i, 0.8)
		await _images(4)
		_montrer("Layer order", "Now %s covers %s" % [_montante, autre])
		await _t_derive(1.8, 0.002)


func _couche_rang(nom: String) -> int:
	for i in _ecran._couches.size():
		if str(_ecran._couches[i]["nom"]) == nom:
			return i
	return -1


# ── 7. LE PINCEAU : « … covers », place par place, puis le clic droit ───────────────────────────────

func _v2_pinceau() -> void:
	await _t_choisir_paire("GreyRock", "Desert")
	var haut := _t_prioritaire("GreyRock", "Desert")
	var bas := "Desert" if haut == "GreyRock" else "GreyRock"
	var rd := _t_bord("GreyRock", "Desert", _paires_v2[2][3])
	_regarder(rd + Vector3(-1, 7, 8), rd)
	await _images(8)
	await _t_rendre_visible(_tr._pinceau)
	await _choisir_dans_la_liste(_tr._pinceau, "« %s » covers" % bas, "Brush: %s covers here" % bas)
	await _t_glisser_curseur(_tr.curseur_rayon, 2, 0.5, "Radius", "Brush radius: 2 cells")
	var pts := _t_frontiere("GreyRock", "Desert", Vector2(rd.x, rd.z), 6.0, Vector2(1, 0))
	print("frontière roche | sable : %d points" % pts.size())
	await _t_glisser(pts, 2.2, MOUSE_BUTTON_LEFT, "Left drag", "%s covers %s, place by place" % [bas, haut])
	await _images(int(1.2 * FPS))
	var moitie := pts.slice(0, maxi(1, pts.size() / 3))
	await _t_glisser(moitie, 1.0, MOUSE_BUTTON_RIGHT, "Right drag", "Back to the order of the list")
	await _images(int(1.0 * FPS))
	print("choix peints : %d" % (_tr.etat["choix"] as Dictionary).size())


# ── 8. TOUTES LES FRONTIÈRES : plus une seule franche ───────────────────────────────────────────────

func _v2_toutes() -> void:
	_v2_vue_carrefour()
	await _images(6)
	_montrer("Every border", "Three pairs, all blended")
	await _t_derive(2.4, 0.004)
	for i in _paires_v2.size():
		_v2_vue_bord(i)
		await _images(4)
		_montrer("Blended", _paires_v2[i][2])
		await _t_derive(1.8, 0.003)


# ── 9. ET 10. LE MONDE, LE JEU : ceux de la v1 ──────────────────────────────────────────────────────

func _v2_monde() -> void:
	_v2_vue_bord(2)
	await _images(4)
	await _touche(KEY_ESCAPE, "Esc", "Back to World: the yellow tint goes, the blend stays")
	await _t_derive(2.0, 0.003)


func _v2_jeu() -> void:
	await _t_jeu()
