extends SceneTree
##
## SONDE — LE PROFIL RÉEL D'UN REBORD, EN COUPE
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_profil_rebord.gd -- --z=16
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## ⚠ **J'AI DESSINÉ À JORDAN UN SCHÉMA DE REBORD SORTI DE MA TÊTE, PAS DE LA GÉOMÉTRIE.** Il était faux,
## et il l'a vu au premier coup d'œil : *« je ne peux pas choisir car ton schéma est faux »*. Tout le
## reste de ce projet est mesuré ; ce dessin-là ne l'était pas, et il servait à trancher une décision.
##
## Cette sonde ne dessine rien. Elle IMPRIME l'occupation réelle en sous-voxels — celle dont la coque
## exportée est exactement la frontière — lue par `BlocsMaitres.sous_voxels()`, la même fonction que le
## mailleur. ⚠ Pas de seconde description du retrait : c'est tout l'objet de l'extraction.
##
## ── CE QU'ELLE MONTRE, ET CE QU'ELLE NE MONTRE PAS ──────────────────────────────────────────────────
##
## Trois panneaux du MÊME plan de coupe :
##   1. le SOLIDE (retrait 0) — les cellules pleines, sans amincissement ;
##   2. l'AMINCI (retrait 0,25) — ce qui part réellement chez l'artiste, avec ses rebords ;
##   3. l'AMINCI CHANFREINÉ — les sous-voxels que le geste de Jordan couperait en diagonale.
##
## ⚠ **LE PANNEAU 3 EST UNE PROJECTION, PAS UNE PROMESSE.** Le chanfrein est une opération en 3D ; ce
## plan n'en montre que la trace. Un sous-voxel marqué `/` est coupé en diagonale VU DANS CE PLAN — il
## peut l'être autrement dans un plan voisin. La sonde marque donc ce qui est COUPÉ, jamais « retiré ».

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

## Le plan de coupe à imprimer, en SOUS-VOXELS sur z. Par défaut le milieu du bloc.
var _z := -1


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--z="):
			_z = int(option.substr("--z=".length()))
	var cote_sous: int = BM.COTE * BM.SOUS
	if _z < 0:
		_z = cote_sous / 2

	print("=== LE PROFIL RÉEL D'UN REBORD, EN COUPE ===\n")
	print("bloc : %d cellules de côté  ·  %d sous-voxels par cellule  ·  grille %d × %d × %d"
		% [BM.COTE, BM.SOUS, cote_sous, cote_sous, cote_sous])
	print("plan imprimé : z = %d sous-voxels (soit z = %.2f cellule)\n" % [_z, float(_z) / float(BM.SOUS)])

	var cases: Dictionary = BM.cases(0)
	var solide: Dictionary = BM.sous_voxels(cases, 0.0)
	var aminci: Dictionary = BM.sous_voxels(cases, 0.25)

	_imprimer("1. LE SOLIDE (retrait 0) — les cellules pleines", solide, cote_sous, false)
	_imprimer("2. L'AMINCI (retrait 0,25) — CE QUI PART CHEZ L'ARTISTE", aminci, cote_sous, false)
	_imprimer("3. L'AMINCI CHANFREINÉ — « / » = coin coupé en diagonale", aminci, cote_sous, true)

	_compter(aminci, cote_sous)

	print("\n⚠ Le panneau 3 est la TRACE d'une opération 3D dans ce plan, pas la promesse d'un rendu.")
	print("   Pour voir un autre plan : --z=<0..%d>" % (cote_sous - 1))
	quit(0)


## Imprime une tranche. `chanfreiner` marque les sous-voxels dont le coin serait coupé.
func _imprimer(titre: String, pleins: Dictionary, cote_sous: int, chanfreiner: bool) -> void:
	print("── %s ──" % titre)
	print("   %s" % _regle(cote_sous))
	# ⚠ y DESCENDANT à l'impression : le haut du monde doit être en haut de la page, sinon on lit le
	# profil à l'envers — et c'est précisément ce genre d'inversion muette qui rend un schéma faux.
	for y in range(cote_sous - 1, -1, -1):
		var ligne := ""
		for x in cote_sous:
			var ici: bool = pleins.has(Vector3i(x, y, _z))
			if not ici:
				ligne += "."
			elif chanfreiner and _coin_coupe(pleins, x, y):
				ligne += "/"
			else:
				ligne += "#"
		print("   %s%s  %s" % [_bord(y), ligne, _bord(y)])
	print("   %s" % _regle(cote_sous))
	print("")


## Un sous-voxel plein forme-t-il un coin SAILLANT dans ce plan ? ⚠ Il faut un voisin vide sur x ET un
## voisin vide sur y : un seul côté exposé est une face plate, pas un coin, et le chanfreiner
## raboterait la surface au lieu d'en couper l'arête.
func _coin_coupe(pleins: Dictionary, x: int, y: int) -> bool:
	var gauche: bool = not pleins.has(Vector3i(x - 1, y, _z))
	var droite: bool = not pleins.has(Vector3i(x + 1, y, _z))
	var bas: bool = not pleins.has(Vector3i(x, y - 1, _z))
	var haut: bool = not pleins.has(Vector3i(x, y + 1, _z))
	return (gauche or droite) and (bas or haut)


## La règle horizontale : `|` aux bords de cellule, `:` aux PLANS DE COUPE.
## ⚠ Les plans passent par les CENTRES des cellules, donc au sous-voxel `SOUS/2` de chaque groupe —
## les placer aux bords décalerait toute la lecture d'une demi-case.
func _regle(cote_sous: int) -> String:
	var s := "  "
	for x in cote_sous:
		if x % BM.SOUS == 0:
			s += "|"
		elif x % BM.SOUS == BM.SOUS / 2:
			s += ":"
		else:
			s += " "
	return s + "   | bord de cellule    : plan de coupe"


func _bord(y: int) -> String:
	if y % BM.SOUS == 0:
		return "--"
	if y % BM.SOUS == BM.SOUS / 2:
		return ".."
	return "  "


## Combien de coins ce plan porte-t-il, et de quelle sorte ? ⚠ Un compte SANS l'image ne dirait pas si
## le chanfrein tombe au bon endroit ; l'image SANS le compte ne dirait pas s'il est rare ou partout.
func _compter(pleins: Dictionary, cote_sous: int) -> void:
	var coins := 0
	var pleins_ici := 0
	for y in cote_sous:
		for x in cote_sous:
			if not pleins.has(Vector3i(x, y, _z)):
				continue
			pleins_ici += 1
			if _coin_coupe(pleins, x, y):
				coins += 1
	print("── CE QUE CE PLAN PORTE ──")
	print("   %d sous-voxel(s) plein(s), dont %d formant un coin saillant (%.1f %%)"
		% [pleins_ici, coins, 100.0 * float(coins) / maxf(1.0, float(pleins_ici))])
