extends RefCounted
## LA PALETTE DE L'ÉCRAN — celle de SoluTiles, relevée dans son `ui/editor.tscn`.
##
## ⚠ UN SEUL ENDROIT : SoluTiles répétait ses couleurs en surcharges nœud par nœud dans sa scène.
## Ici l'écran est bâti en code, donc chaque couleur est nommée une fois et lue partout.

const BARRE_TITRE := Color(0.129, 0.141, 0.149)
const PANNEAU := Color(0.106, 0.118, 0.125)
const TEXTE := Color(0.878, 0.878, 0.851)
const GRIS := Color(0.588, 0.612, 0.588)
const OLIVE := Color(0.706, 0.741, 0.522)
const AMBRE := Color(0.949, 0.792, 0.475)
const ATTENTE := Color(0.075, 0.082, 0.09, 0.95)
const FOND_VUE := Color("#101216")
const ROUGE := Color("#e0603c")


static func fond(couleur: Color, rayon := 0, marge := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = couleur
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge
	s.content_margin_right = marge
	s.content_margin_top = marge
	s.content_margin_bottom = marge
	return s
