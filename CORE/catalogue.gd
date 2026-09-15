extends RefCounted
## LE CATALOGUE — tout ce qui peut se poser dans une énigme, écrit en DONNÉES.
##
## Ajouter un objet au jeu, c'est ajouter une entrée ici, jamais du code : le traceur et la
## résolution ne connaissent AUCUN objet par son nom, ils ne lisent que les champs ci-dessous. C'est
## ce qui permet de construire le jeu au fur et à mesure sans revenir sur ce qui existe.
##
## ⚠ CE QUE LE CATALOGUE NE SAIT PAS ÉCRIRE COMPTE AUTANT QUE CE QU'IL SAIT ÉCRIRE. Il n'existe ni
## « bloque si actif », ni « émet si inactif », ni condition « aucun » : ce qui est MAINTENU ne peut
## qu'AJOUTER de la lumière. C'est cette absence qui garantit qu'une résolution se termine, quel que
## soit le montage (en-tête de `resolution.gd`). Ce qu'une fiche ne peut pas payer, elle ne doit pas
## pouvoir l'écrire — et `verifier()` refuse ce qu'on essaierait d'y glisser.
##
## CHAMPS D'UN TYPE
##   optique       — ce que la case fait à un faisceau qui y entre :
##                     "miroir"             réfléchit                     (props : orientation)
##                     "vitre"              filtre, et concentre en laser  (props : filtre, concentre)
##                     "bloque"             arrête
##                     "traverse"           laisse passer
##                     "traverse_si_actif"  arrête tant qu'inactif, laisse passer une fois actif
##                     "portail"            renvoie dans une autre grille  (props : vers_*)
##   emission      — "" | "toujours" | "si_actif"          (props : direction, couleur, laser)
##   destructible  — un laser le détruit ; surchargeable objet par objet
##   reactions     — couleur -> {"active": true} | {"devient": TYPE}      (au plus UN « devient »)
##   active_sur_sa_couleur — s'active sous un faisceau de la couleur de SA propriété `couleur`
##   depend        — actif selon d'autres activables       (props : depend_de, mode "tous" | "un")
##   props         — propriétés d'objet et leurs valeurs par défaut

const Couleur := preload("res://CORE/couleur.gd")
const Direction := preload("res://CORE/direction.gd")

const TYPES := {
	# ── ce qui émet ────────────────────────────────────────────────────────────────────────────────
	"RAI_DE_CIEL": {
		"optique": "bloque",
		"emission": "toujours",
		"props": {"direction": Direction.S, "couleur": Couleur.BLANC, "laser": false},
	},

	# ── ce qui conduit la lumière ──────────────────────────────────────────────────────────────────
	"MIROIR": {
		"optique": "miroir",
		"props": {"orientation": 0},
	},
	"VITRE": {
		"optique": "vitre",
		"props": {"filtre": Couleur.BLANC, "concentre": false},
	},

	# ── ce qui réagit, et ne revient pas ───────────────────────────────────────────────────────────
	"PILIER_GLACE": {
		"optique": "bloque",
		"reactions": {Couleur.ROUGE: {"devient": "FLAQUE"}},
	},
	"FLAQUE": {
		"optique": "traverse",
	},
	"COLONNE_FEU": {
		"optique": "traverse",
		"reactions": {Couleur.BLEU: {"devient": "COLONNE_ETEINTE"}},
	},
	"COLONNE_ETEINTE": {
		"optique": "traverse",
	},

	# ── ce qui s'active tant qu'on l'éclaire ───────────────────────────────────────────────────────
	"OEIL_SACRE": {
		"optique": "bloque",
		"destructible": true,
		"active_sur_sa_couleur": true,
		"props": {"couleur": Couleur.JAUNE},
	},
	"CRISTAL": {
		"optique": "bloque",
		"destructible": true,
		"active_sur_sa_couleur": true,
		"emission": "si_actif",
		"props": {"couleur": Couleur.ROUGE, "direction": Direction.E, "laser": false},
	},

	# ── ce qui dépend d'autres activables ──────────────────────────────────────────────────────────
	"PORTE_ANTIQUE": {
		"optique": "traverse_si_actif",
		"depend": true,
		"props": {"depend_de": [], "mode": "tous"},
	},

	# ── le seul lien entre les vues ────────────────────────────────────────────────────────────────
	"ENTREE": {
		"optique": "portail",
		"props": {"vers_grille": 0, "vers_case": Vector2i.ZERO, "vers_direction": Direction.S},
	},
}

const OPTIQUES := ["miroir", "vitre", "bloque", "traverse", "traverse_si_actif", "portail"]
const EMISSIONS := ["", "toujours", "si_actif"]
const CLES := ["optique", "emission", "destructible", "reactions", "active_sur_sa_couleur", "depend", "props"]
const PROPS_REQUISES := {
	"miroir": ["orientation"],
	"vitre": ["filtre", "concentre"],
	"portail": ["vers_grille", "vers_case", "vers_direction"],
}


static func peut_etre_actif(nom: String, types: Dictionary = TYPES) -> bool:
	var t: Dictionary = types[nom]
	if t.get("active_sur_sa_couleur", false) or t.get("depend", false):
		return true
	var reactions: Dictionary = t.get("reactions", {})
	for c in reactions:
		if reactions[c].has("active"):
			return true
	return false


## Rend la liste des fautes d'un catalogue — vide s'il est sain. Prend le catalogue en paramètre pour
## que le test puisse lui présenter ce qu'il doit refuser.
static func verifier(types: Dictionary = TYPES) -> Array:
	var erreurs: Array = []
	for nom in types:
		var t: Dictionary = types[nom]
		for cle in t:
			if not cle in CLES:
				erreurs.append("%s : clé inconnue « %s »" % [nom, cle])

		var optique: String = t.get("optique", "")
		if not optique in OPTIQUES:
			erreurs.append("%s : optique inconnue « %s »" % [nom, optique])
		var props: Dictionary = t.get("props", {})
		for p in PROPS_REQUISES.get(optique, []):
			if not props.has(p):
				erreurs.append("%s : l'optique « %s » demande la propriété « %s »" % [nom, optique, p])

		var emission: String = t.get("emission", "")
		if not emission in EMISSIONS:
			erreurs.append("%s : emission inconnue « %s »" % [nom, emission])
		elif emission != "":
			for p in ["direction", "couleur", "laser"]:
				if not props.has(p):
					erreurs.append("%s : une émission demande la propriété « %s »" % [nom, p])
		if (emission == "si_actif" or optique == "traverse_si_actif") and not peut_etre_actif(nom, types):
			erreurs.append("%s : ne peut jamais être actif, donc son effet « si actif » est mort" % nom)
		if t.get("active_sur_sa_couleur", false) and not props.has("couleur"):
			erreurs.append("%s : « active_sur_sa_couleur » demande la propriété « couleur »" % nom)

		var reactions: Dictionary = t.get("reactions", {})
		var destins := 0
		for c in reactions:
			if typeof(c) != TYPE_INT or c < Couleur.ROUGE or c > Couleur.BLANC:
				erreurs.append("%s : réaction sur une couleur invalide « %s »" % [nom, str(c)])
			var r: Dictionary = reactions[c]
			if r.size() != 1 or not (r.has("active") or r.has("devient")):
				erreurs.append("%s : une réaction est {\"active\": true} ou {\"devient\": TYPE}" % nom)
			if r.has("devient"):
				destins += 1
				if not types.has(r["devient"]):
					erreurs.append("%s : devient un type inconnu « %s »" % [nom, r["devient"]])
		if destins > 1:
			erreurs.append("%s : deux destins — un objet ne devient qu'UNE chose, sinon l'ordre des faisceaux trancherait" % nom)

		if t.get("depend", false):
			if not reactions.is_empty() or t.get("active_sur_sa_couleur", false):
				erreurs.append("%s : un dépendant ne réagit pas à la lumière, il lit ses activables" % nom)
			for p in ["depend_de", "mode"]:
				if not props.has(p):
					erreurs.append("%s : un dépendant demande la propriété « %s »" % [nom, p])

	# Chaque type a au plus un destin : le graphe des transformations est une suite de flèches, et une
	# flèche qui revient sur ses pas ferait tourner la résolution sans fin.
	for nom in types:
		var vus := {}
		var courant: String = nom
		while courant != "":
			if vus.has(courant):
				erreurs.append("%s : cycle de transformations — une résolution ne se terminerait pas" % nom)
				break
			vus[courant] = true
			courant = _destin(types, courant)
	return erreurs


static func _destin(types: Dictionary, nom: String) -> String:
	if not types.has(nom):
		return ""
	var reactions: Dictionary = types[nom].get("reactions", {})
	for c in reactions:
		if reactions[c].has("devient"):
			return reactions[c]["devient"]
	return ""
