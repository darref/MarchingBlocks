extends RefCounted
## LES AVIS DES LICENCES TIERCES — ce que MarchingBlocks contient d'autrui, et sous quelle licence. Montré dans
## « About », et écrit dans le dossier livré (`THIRD_PARTY_NOTICES.txt`, par `DEV_TOOLS/preparer_livraison.gd`) :
## UN texte, écrit ici seulement.
##   • Godot Engine (MIT) et TOUS ses composants tiers (polices comprises — Open Sans, Noto Sans, Inter… —,
##     FreeType, HarfBuzz, mbedTLS…), tels que le moteur lui-même les déclare (`Engine.get_copyright_info`) ;
##   • godot-cpp (MIT), le pont de la bibliothèque native ;
##   • Monocypher (BSD-2 ou CC0, au choix : on reproduit la BSD-2), l'Ed25519 des anciennes clés de licence — encore
##     compilé dans la bibliothèque native livrée (à retirer de `gdextension/` au prochain build des DLL).
## ⚠ Une bibliothèque ajoutée au cœur natif (`gdextension/`) s'AJOUTE à `PROPRES`, avec son texte.
## ⚠ Le texte de l'éditeur Godot (qui écrit le fichier livré) déclare un peu PLUS de composants que le modèle
## d'export recompilé (sans D3D12 ni AccessKit) : un sur-ensemble, jamais un oubli.

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

const BSD2_MONOCYPHER := """Copyright (c) 2017-2023, Loup Vaillant
Copyright (c) 2017-2019, Michael Savage
Copyright (c) 2017-2023, Fabio Scotoni
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the
   distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."""

## Ce que NOUS avons ajouté au moteur (la bibliothèque native).
const PROPRES := [
	{"nom": "godot-cpp", "url": "https://github.com/godotengine/godot-cpp", "licence": "MIT", "texte": MIT_GODOT_CPP},
	{"nom": "Monocypher 4.0.2", "url": "https://monocypher.org",
		"licence": "BSD-2-Clause (dual-licensed with CC0-1.0)", "texte": BSD2_MONOCYPHER},
]

const TRAIT := "------------------------------------------------------------------------------"


## Le texte entier (anglais : il est lu par l'acheteur).
static func texte() -> String:
	var l := PackedStringArray()
	l.append("MarchingBlocks — third-party notices")
	l.append("")
	l.append("MarchingBlocks is © SpannerGames. It is built with the Godot Engine and the libraries below, each")
	l.append("under its own license. Their full texts follow.")
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
