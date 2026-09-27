@tool
extends RefCounted
## LE PBR ESPACE MONDE — le matériau que la case « Texturer en PBR espace monde » pose sur le témoin.
##
## ⚠ **C'EST LE MODE PBR ANNONCÉ PAR LA CHARTE §1, PAS UN SUBSTITUT À LA GÉOMÉTRIE.** Le relief reste
## réel ; ce matériau habille chaque teinte d'un set complet — albédo, normale, AO, rugosité, hauteur
## (POM) — projeté dans l'espace MONDE, pour que les tuiles se raccordent sans couture.
##
## ⚠ **IL SUIT DANS LES TUILES PARCE QU'IL EST POSÉ AVANT LE TRANCHAGE** (`BlocsMaitres.librairie()`), et
## que la découpe recopie le matériau de la source. Le poser après coup sur chaque tuile donnerait la
## même image, mais ce serait une seconde règle pour un fait qui en a déjà une.
##
## Les textures sont bâties par `DEV_TOOLS/batir_pbr_monde.gd`. Absentes, `matiere()` rend `null` et
## l'écran le DIT — jamais un matériau à moitié vide qui rendrait du noir.

const RP := preload("res://addons/undermend/repli_procedural.gd")

const DOSSIER := "res://ART/pbr_monde/"
const SHADER := "res://addons/undermend/pbr_monde.gdshader"


## Les trois tableaux sont-ils là ?
static func disponible() -> bool:
	for nom in ["albedo", "normale", "orh"]:
		if not ResourceLoader.exists(DOSSIER + nom + ".res"):
			return false
	return true


## Le matériau, ou `null` si les textures n'ont pas été bâties.
static func matiere() -> ShaderMaterial:
	if not disponible():
		return null
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.set_shader_parameter("albedos", load(DOSSIER + "albedo.res"))
	m.set_shader_parameter("normales", load(DOSSIER + "normale.res"))
	m.set_shader_parameter("orh", load(DOSSIER + "orh.res"))
	# ⚠ LES TEINTES VIENNENT DE LEUR SOURCE, DANS L'ORDRE DES COUCHES : `batir_pbr_monde.gd` empile ses
	# couches en parcourant `RP.TEINTES`, et on les nomme ici dans le même parcours.
	var teintes := PackedVector3Array()
	for t in RP.TEINTES:
		var c: Color = t["couleur"]
		teintes.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("teintes", teintes)
	return m
