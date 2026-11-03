extends RefCounted
## LES AVIS DES LICENCES TIERCES — ce que MarchingBlocks contient d'autrui, et sous quelle licence. Montré dans
## « About », et écrit dans le dossier livré (`THIRD_PARTY_NOTICES.txt`, par `DEV_TOOLS/preparer_livraison.gd`) :
## UN texte, écrit ici seulement.
##   • Godot Engine (MIT) et TOUS ses composants tiers (polices comprises — Open Sans, Noto Sans, Inter… —,
##     FreeType, HarfBuzz, mbedTLS…), tels que le moteur lui-même les déclare (`Engine.get_copyright_info`) ;
##   • godot-cpp (MIT), le pont de la bibliothèque native.
## (Monocypher, l'Ed25519 des clés de licence, est parti avec la vente : logiciel libre, Jordan, 3 novembre 2026.)
## ⚠ Une bibliothèque ajoutée au cœur natif (`gdextension/`) s'AJOUTE à `PROPRES`, avec son texte.
## ⚠ Le texte de l'éditeur Godot (qui écrit le fichier livré) déclare un peu PLUS de composants que le modèle
## d'export officiel : un sur-ensemble, jamais un oubli.

const MIT_GODOT_CPP := """MIT License

Copyright (c) 2017-present Godot Engine contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""

## Ce que NOUS avons ajouté au moteur (la bibliothèque native).
const PROPRES := [
	{"nom": "godot-cpp", "url": "https://github.com/godotengine/godot-cpp", "licence": "MIT", "texte": MIT_GODOT_CPP},
]

const TRAIT := "------------------------------------------------------------------------------"


## Le texte entier (anglais : il est lu par l'utilisateur).
static func texte() -> String:
	var l := PackedStringArray()
	l.append("MarchingBlocks — third-party notices")
	l.append("")
	l.append("MarchingBlocks is © SpannerGames, free software under the GNU GPL v3.0. It is built with the Godot")
	l.append("Engine and the libraries below, each under its own license. Their full texts follow.")
	l.append("")
	l.append(TRAIT)
	l.append("Godot Engine — https://godotengine.org")
	l.append("")
	l.append(Engine.get_license_text().strip_edges())
	for p in PROPRES:
		l.append("")
		l.append(TRAIT)
		l.append("%s — %s — %s" % [p["nom"], p["url"], p["licence"]])
		l.append("")
		l.append(String(p["texte"]))
	l.append("")
	l.append(TRAIT)
	l.append("Third-party components of the Godot Engine")
	l.append("")
	var licences: Dictionary = Engine.get_license_info()
	for c in Engine.get_copyright_info():
		l.append("- " + str(c["name"]))
		for part in c["parts"]:
			for droit in part["copyright"]:
				l.append("    © " + str(droit))
			l.append("    License: " + str(part["license"]))
	var noms: Array = licences.keys()
	noms.sort()
	for nom in noms:
		l.append("")
		l.append(TRAIT)
		l.append("License: " + str(nom))
		l.append("")
		l.append(str(licences[nom]).strip_edges())
	return "\n".join(l) + "\n"
