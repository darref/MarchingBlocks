extends RefCounted
## LES DONS — DÉCIDÉ (Jordan, 3 novembre 2026 : « MarchingBlocks devient OpenSource et réclame des dons sur de multiples
## plateformes dont déjà Ko-fi et GitHub Sponsors »). Le logiciel est libre (GPL-3.0) et gratuit ; il vit des dons.
##
## LA LISTE DES PLATEFORMES, écrite ICI pour l'appli (« About », le bouton « Support » de la barre). Une plateforme
## ajoutée s'ajoute ici, et AUSSI dans `.github/FUNDING.yml` (le bouton « Sponsor » de GitHub, qui a son format) et dans
## `README.md` : `test_a_propos` vérifie que les trois disent la même chose.
## ⚠ Les liens ne s'ouvrent qu'en https (`OS.shell_open`), jamais construits à partir d'une saisie.

const PLATEFORMES := [
	{"nom": "Ko-fi", "url": "https://ko-fi.com/darref", "funding": "ko_fi: darref"},
	{"nom": "GitHub Sponsors", "url": "https://github.com/sponsors/darref", "funding": "github: darref"},
]

const APPEL := ("MarchingBlocks is free and open source, made by one developer. If it helps you build your worlds, "
	+ "a donation keeps it going.")
