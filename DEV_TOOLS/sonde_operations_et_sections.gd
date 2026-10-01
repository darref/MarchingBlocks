extends SceneTree
## SONDE — quelles opérations du modeleur ROMPENT les sections partagées ? (Jordan, 1er octobre 2026 : « la
## subdivision sans qu'elle ne subdivise aussi ses voisines ne rompt-elle pas théoriquement les sections
## partagées et fait des trous ? »)
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_operations_et_sections.gd
##
## Chaque opération est appliquée, sur un témoin NEUF, à la paroi (la tuile la plus partagée), au contact d'un
## bord. On compte ensuite `Sections.absences()` : les points de bord présents dans une face d'une classe et
## absents d'une autre — un point sans correspondant, que rien ne pourra entraîner, donc une fente dès qu'il
## bouge, ou tout de suite s'il n'est déjà plus sur le bord d'avant.

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const SE := preload("res://addons/marchingblocks_core/sections.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")

var _modele: RefCounted


func _initialize() -> void:
	_modele = TL.depuis_le_temoin_calcule()
	var cle := "mb_plaque_b2h2_dehors"
	var ops := {
		"subdiviser une face au bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.subdiviser([f]),
		"biseauter une arête QUI TOUCHE le bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.biseauter([e_touche], 0.05),
		"biseauter une arête POSÉE SUR le bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.biseauter([e_bord], 0.05),
		"inset d'une face au bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.inserer([f], 0.05),
		"extruder une face au bord (+0,1)": func(t, m, s, f, e_bord, e_touche, v2):
			var r: Dictionary = m.extruder_faces([f])
			m.transformer(r["sommets"], Transform3D(Basis(), r["normale"] * 0.1), m.sommets.duplicate()),
		"supprimer une face au bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.supprimer_faces([f]),
		"fusionner deux sommets de bord": func(t, m, s, f, e_bord, e_touche, v2):
			m.fusionner(v2),
		"loop cut SANS report (le geste brut)": func(t, m, s, f, e_bord, e_touche, v2):
			m.couper_en_boucle(e_touche, 0.5),
		"loop cut AVEC report (Sections.completer)": func(t, m, s, f, e_bord, e_touche, v2):
			m.couper_en_boucle(e_touche, 0.5)
			s.completer(),
	}
	for nom in ops:
		var t: RefCounted = _modele.copie()
		var s: RefCounted = SE.new(t)
		var avant: int = s.absences()
		var m: RefCounted = t.tuiles[cle]
		var reperes := _reperes(m, s, cle)
		ops[nom].call(t, m, s, reperes["face"], reperes["arete_bord"], reperes["arete_touche"], reperes["deux"])
		var apres: int = s.absences()
		var r: Dictionary = s.completer()
		print("%-44s absences %d → %d ; après report : %d (%d coupes, %d échecs)" % [nom, avant, apres, s.absences(), r["coupes"], r["echecs"]])
	quit(0)


## Une face qui touche le bord, une arête posée sur le bord, une arête qui y aboutit, deux sommets de bord voisins.
func _reperes(m: RefCounted, s: RefCounted, cle: String) -> Dictionary:
	var sortie := {"face": -1, "arete_bord": Vector2i(-1, -1), "arete_touche": Vector2i(-1, -1), "deux": []}
	for f in m.faces.size():
		var face: PackedInt32Array = m.faces[f]
		for k in face.size():
			var a := face[k]
			var b := face[(k + 1) % face.size()]
			var ba: bool = s.est_de_bord(cle, a)
			var bb: bool = s.est_de_bord(cle, b)
			if ba and bb and sortie["arete_bord"].x < 0:
				sortie["arete_bord"] = ME.arete(a, b)
				sortie["deux"] = [a, b]
				sortie["face"] = f
			elif ba != bb and sortie["arete_touche"].x < 0:
				sortie["arete_touche"] = ME.arete(a, b)
	return sortie
