extends RefCounted
## LES ICÔNES DE L'ÉCRAN — dessinées ici, en SVG, au trait.
##
## ⚠ **ELLES SONT BLANCHES, ET C'EST LE THÈME QUI LES TEINTE.** Un bouton module son icône par
## `icon_normal_color`, `icon_hover_color`, `icon_pressed_color`… (`palette.gd`) : une icône qui
## porterait sa couleur resterait grise sur un bouton enfoncé, et il en faudrait une par état.
## ⚠ **RENDUES AU DOUBLE DE LEUR TAILLE D'AFFICHAGE**, puis bornées par `icon_max_width` : un SVG
## rendu à 18 px et affiché sur un écran à 150 % serait flou.
## ⚠ **AUCUNE N'EST EMPRUNTÉE** : le logiciel est vendu, et une icône copiée d'un jeu sous licence
## porterait une obligation qu'on ne veut pas avoir à relire. Toutes sont des tracés simples, écrits ici.

const TAILLE_RENDU := 40.0

## Le contenu d'un SVG 24 × 24, au trait. `#FFF` est remplacé par la couleur demandée.
const TRACES := {
	# Les ateliers
	"jouer": '<path d="M7 4.5v15l12-7.5z"/>',
	"cube": '<path d="M12 2.5 3.5 7.2v9.6L12 21.5l8.5-4.7V7.2z"/><path d="M3.5 7.2 12 12l8.5-4.8M12 12v9.5"/>',
	"grille": '<rect x="3.5" y="3.5" width="17" height="17" rx="2"/><path d="M3.5 9.2h17M3.5 14.8h17M9.2 3.5v17M14.8 3.5v17" stroke-opacity="0.7"/>',
	"monde": '<path d="M2.5 15.5 12 20.5l9.5-5L12 10.5z"/><path d="M7 13l9.5 5M17 13l-9.5 5M12 10.5v-6M9.5 7 12 4.5 14.5 7"/>',
	# Le bandeau
	"livre": '<path d="M3 4.5h6a3 3 0 0 1 3 3v13a2.2 2.2 0 0 0-2.2-2.2H3z"/><path d="M21 4.5h-6a3 3 0 0 0-3 3v13a2.2 2.2 0 0 1 2.2-2.2H21z"/>',
	"ampoule": '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.9 10.6c.8.7 1.1 1.5 1.1 2.4h5.6c0-.9.3-1.7 1.1-2.4A6 6 0 0 0 12 3z"/>',
	# Le projet
	"nouveau": '<path d="M14 3H6.5A2.5 2.5 0 0 0 4 5.5v13A2.5 2.5 0 0 0 6.5 21h11a2.5 2.5 0 0 0 2.5-2.5V9z"/><path d="M14 3v6h6M12 12v6M9 15h6"/>',
	"ouvrir": '<path d="M3 7.5A2.5 2.5 0 0 1 5.5 5H9l2 2.5h7.5A2.5 2.5 0 0 1 21 10v7.5a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"/>',
	"enregistrer": '<path d="M5.5 3H16l5 5v10.5a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 18.5v-13A2.5 2.5 0 0 1 5.5 3z"/><path d="M7.5 3v5h7.5V3M7.5 21v-7h9v7"/>',
	# Le témoin et l'aller-retour
	"texture": '<rect x="3" y="3" width="18" height="18" rx="2.5"/><path d="M3 15.5l5-5 4.5 4.5 3-3L21 17.5"/><circle cx="15.5" cy="8" r="1.6"/>',
	"exporter": '<path d="M12 15V3.5M7 8.5l5-5 5 5"/><path d="M4 14.5v4A2.5 2.5 0 0 0 6.5 21h11a2.5 2.5 0 0 0 2.5-2.5v-4"/>',
	"importer": '<path d="M12 3.5V15M7 10l5 5 5-5"/><path d="M4 14.5v4A2.5 2.5 0 0 0 6.5 21h11a2.5 2.5 0 0 0 2.5-2.5v-4"/>',
	"clavier": '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6.5 10h.01M10 10h.01M14 10h.01M17.5 10h.01M7.5 14h9"/>',
	"rapport": '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3h11A2.5 2.5 0 0 1 20 5.5v8a2.5 2.5 0 0 1-2.5 2.5H9l-5 4.5z"/><path d="M8 8h8M8 11.5h5"/>',
	# Les outils
	"outils": '<path d="M14.7 6.3a4 4 0 0 0-5.3 5.3L3.5 17.5l3 3 5.9-5.9a4 4 0 0 0 5.3-5.3l-2.6 2.6-2.4-.6-.6-2.4z"/>',
	"visee_grille": '<path d="M2.5 16 12 20.5l9.5-4.5L12 11.5z"/><path d="M12 3v7M9 7.5l3 3 3-3"/>',
	# Naviguer : une boussole — on ne vise rien, on se déplace.
	"visee_naviguer": '<circle cx="12" cy="12" r="8.5"/><path d="M15.5 8.5 13.2 13.2 8.5 15.5l2.3-4.7z"/>',
	"visee_sculpt": '<path d="M15 9.5l5.5 3.2v6.1L15 22l-5.5-3.2v-6.1z"/><path d="M9.5 12.7 15 15.9l5.5-3.2M15 15.9V22"/><path d="M3 3l6 6M9 4v5H4"/>',
	"ajouter": '<rect x="3.5" y="3.5" width="17" height="17" rx="3"/><path d="M12 8v8M8 12h8"/>',
	"creuser": '<rect x="3.5" y="3.5" width="17" height="17" rx="3"/><path d="M8 12h8"/>',
	"selectionner": '<path d="M5 3.5 19 10.5l-6.2 2.2-2.3 6.3z"/>',
	"boite": '<rect x="3.5" y="3.5" width="17" height="17" rx="2" stroke-dasharray="3.5 2.6"/>',
	# Le rectangle est PLAT : un losange en perspective, comme le plan de l'étage que vise la grille.
	"rect": '<path d="M2.5 13.5 12 8.5l9.5 5-9.5 5z" stroke-dasharray="3.5 2.6"/>',
	# Remplir : le même losange, mais plein, et de la matière qui y tombe.
	"remplir": '<path d="M2.5 16 12 11l9.5 5-9.5 5z"/><path d="M12 2.5V8M9 5.5 12 8.5l3-3"/>',
	"sphere": '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12a8.5 3.2 0 0 0 17 0"/>',
	"disque": '<ellipse cx="12" cy="12.5" rx="9" ry="4"/>',
	"etage": '<path d="M3 10h18v4H3z"/><path d="M12 2.5v4.5M9.5 5 12 2.5 14.5 5M12 17v4.5M9.5 19 12 21.5 14.5 19"/>',
	# La sélection
	"poubelle": '<path d="M4 6.5h16M9.5 6.5V4h5v2.5M6 6.5 7 20h10l1-13.5"/><path d="M10 10.5v6M14 10.5v6"/>',
	"croix": '<path d="M17.5 6.5l-11 11M6.5 6.5l11 11"/>',
	"extruder_haut": '<path d="M12 16V4.5M7 9.5l5-5 5 5"/><path d="M4 20h16"/>',
	"extruder_bas": '<path d="M4 4h16"/><path d="M12 8v11.5M7 14.5l5 5 5-5"/>',
	"grandir": '<path d="M3.5 9V3.5H9M15 3.5h5.5V9M20.5 15v5.5H15M9 20.5H3.5V15"/><rect x="9" y="9" width="6" height="6" rx="1"/>',
	"retrecir": '<path d="M9 3.5V9H3.5M20.5 9H15V3.5M15 20.5V15h5.5M3.5 15H9v5.5"/>',
	"connexe": '<path d="M10 14a4 4 0 0 0 5.7 0l3-3A4 4 0 0 0 13 5.3l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
	"haut": '<path d="M12 19.5v-15M5.5 11 12 4.5 18.5 11"/>',
	"bas": '<path d="M12 4.5v15M5.5 13l6.5 6.5 6.5-6.5"/>',
	"gauche": '<path d="M19.5 12h-15M11 5.5 4.5 12l6.5 6.5"/>',
	"droite": '<path d="M4.5 12h15M13 5.5l6.5 6.5-6.5 6.5"/>',
	"deplacer": '<path d="M12 2.5v19M2.5 12h19M9 5.5l3-3 3 3M9 18.5l3 3 3-3M5.5 9l-3 3 3 3M18.5 9l3 3-3 3"/>',
	"copier": '<rect x="8.5" y="8.5" width="12.5" height="12.5" rx="2.5"/><path d="M15.5 8.5V5.5A2.5 2.5 0 0 0 13 3H5.5A2.5 2.5 0 0 0 3 5.5V13a2.5 2.5 0 0 0 2.5 2.5h3"/>',
	"couper": '<circle cx="6" cy="6" r="2.8"/><circle cx="6" cy="18" r="2.8"/><path d="M20.5 4 8.2 15.8M14.5 14.5 20.5 20.5M8.2 8.2 12 12"/>',
	"coller": '<rect x="5" y="4.5" width="14" height="16.5" rx="2.5"/><path d="M9 3h6v3.5H9z"/>',
	# Les couches
	"couches": '<path d="M12 3 2.5 8 12 13l9.5-5z"/><path d="M2.5 12.5 12 17.5l9.5-5"/><path d="M2.5 16.5 12 21.5l9.5-5"/>',
	"oeil": '<path d="M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
	"oeil_ferme": '<path d="M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7S2 12 2 12z" stroke-opacity="0.45"/><path d="M3.5 3.5l17 17"/>',
	"plus": '<path d="M12 5v14M5 12h14"/>',
	# Le tranchage et les opérations
	"couteau": '<path d="M19.5 3 7.5 15l2.5 2.5L21.5 6a2 2 0 0 0-2-3z"/><path d="M7.5 15l-4 4 2.5 2.5 4-4"/>',
	"elargir": '<path d="M3 12h18M6.5 8.5 3 12l3.5 3.5M17.5 8.5 21 12l-3.5 3.5"/>',
	"evider": '<rect x="3.5" y="3.5" width="17" height="17" rx="2.5"/><rect x="8.5" y="8.5" width="7" height="7" rx="1"/>',
	"gomme": '<path d="M20 20.5H9.5l-5.3-5.3a2 2 0 0 1 0-2.8L13.2 3.4a2 2 0 0 1 2.8 0l4.6 4.6a2 2 0 0 1 0 2.8L11 20.5"/><path d="M7.5 10.5l6 6"/>',
	"aide": '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.3a2.6 2.6 0 1 1 3.6 2.4c-.7.3-1.1.9-1.1 1.6v.6M12 17.2h.01"/>',
}

static var _cache := {}


## L'icône `nom`, blanche, prête à être teintée par le thème. `null` si le nom est inconnu — et on le DIT.
static func icone(nom: String) -> Texture2D:
	if _cache.has(nom):
		return _cache[nom]
	if not TRACES.has(nom):
		push_error("Icônes : « %s » n'existe pas" % nom)
		return null
	var svg: String = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
		+ 'fill="none" stroke="#FFF" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">'
		+ TRACES[nom] + "</svg>")
	var image := Image.new()
	var e: int = image.load_svg_from_string(svg, TAILLE_RENDU / 24.0)
	if e != OK:
		push_error("Icônes : « %s » ne se rend pas (erreur %d)" % [nom, e])
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[nom] = texture
	return texture
