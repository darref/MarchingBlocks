extends RefCounted
## LA DÉMO GRATUITE — « tout le logiciel, sans enregistrer ni exporter » (stratégie de lancement, « Démo » ; elle répond
## au remboursement de 2 heures de Steam : on juge l'outil avant d'acheter).
##
## **PROPOSÉ (Claude, 7 octobre 2026) — UN EXE À PART, PAS UN DRAPEAU** : la démo est le TROISIÈME export de la même
## base de code (préréglage « Demo », balise `edition_demo`, `edition.gd`). Pourquoi :
##   • Steam l'exige de toute façon : une démo Steam est une application à part (son AppID, son dépôt) ;
##   • le fichier gratuit du site n'est pas l'exe payant : l'exe complet ne circule qu'après l'achat ;
##   • aucune clé, aucun drapeau ne la change en version complète — sa balise est cuite dans le PCK chiffré ;
##   • un même exe « sans clé = démo » mêlerait les deux parcours (l'acheteur qui a mal collé sa clé se croirait
##     floué de ses enregistrements). Le prix : un export de plus, fait par la même commande.
##
## CE QU'ELLE FAIT : tout, mais dans un BAC jetable (`BAC`, vidé au lancement et à la fermeture) — le projet neuf et
## l'exemple y vivent, l'enregistrement automatique y écrit (les ateliers relisent ce qu'ils écrivent, ils marchent
## donc tous). CE QU'ELLE REFUSE : ouvrir un projet d'ailleurs (l'enregistrement automatique le réécrirait),
## « Save as », et toute sortie — le témoin pour Blender, le jeu de tuiles, le monde, le patron UV.
## ⚠ PAS UN VERROU : le bac est un dossier ordinaire pendant la séance. Ce qui y vaut quelque chose pour un moteur
## (le `.mbset`) ne s'écrit jamais.

const BAC := "user://demo_scratch"
## Les demandes de fichier (`editor._demander`) que la démo refuse.
const REFUSEES := ["ouvrir", "enregistrer", "exporter", "tileset", "monde", "patron"]
const MESSAGE := ("[color=#f2ca79][b]Free demo[/b][/color] — everything works, but saving, opening your own "
	+ "projects and exporting are in the full version. Your work here is wiped when you close MarchingBlocks.")


static func refuse(action: String) -> bool:
	return action in REFUSEES


## Ce chemin est-il dans le bac ?
static func dans_le_bac(chemin: String) -> bool:
	if chemin == "":
		return false
	var bac := ProjectSettings.globalize_path(BAC).replace("\\", "/").simplify_path().trim_suffix("/") + "/"
	var a := ProjectSettings.globalize_path(chemin).replace("\\", "/").simplify_path()
	return a.to_lower().begins_with(bac.to_lower())


## Vide le bac (tout ce qu'il contient), et le recrée vide.
static func vider_le_bac() -> void:
	_effacer(ProjectSettings.globalize_path(BAC))
	DirAccess.make_dir_recursive_absolute(BAC)


static func _effacer(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		FileAccess.set_read_only_attribute(dossier.path_join(f), false)
		d.remove(f)
	for s in d.get_directories():
		_effacer(dossier.path_join(s))
	FileAccess.set_read_only_attribute(dossier, false)
	DirAccess.remove_absolute(dossier)
