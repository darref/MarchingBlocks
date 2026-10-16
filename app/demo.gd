extends RefCounted
## LA DÉMO GRATUITE — « tout le logiciel, sauf exporter » (Jordan, 16 octobre 2026 : « une démo qui peut tout faire sauf
## exporter » ; « il faut proposer quelque chose d'utilitaire maintenant »).
##
## **PROPOSÉ (Claude, 7 octobre 2026) — UN EXE À PART, PAS UN DRAPEAU** : la démo est le TROISIÈME export de la même
## base de code (préréglage « Demo », balise `edition_demo`, `edition.gd`). Pourquoi :
##   • Steam l'exige de toute façon : une démo Steam est une application à part (son AppID, son dépôt) ;
##   • le fichier gratuit n'est pas l'exe payant : l'exe complet ne circule qu'après l'achat ;
##   • aucune clé, aucun drapeau ne la change en version complète — sa balise est cuite dans le PCK chiffré.
##
## **CE QU'ELLE FAIT (16 octobre 2026) : TOUT, ENREGISTREMENT COMPRIS.** Ses projets vont dans `Documents/MarchingBlocks`,
## comme ceux de la version complète, qui les ouvre tels quels : ce qu'on a commencé dans la démo, on le continue après
## l'achat. Elle rouvre « ton monde », ouvre un projet d'ailleurs, « Save as », importe un travail de Blender.
## **CE QU'ELLE REFUSE, EN LE DISANT : TOUTE SORTIE** — le témoin pour Blender, le jeu de tuiles pour les moteurs (`.mbset`),
## le monde (`.mbworld`), le patron UV. ⚠ Avant le 16 octobre elle n'enregistrait rien (un bac jetable, vidé à la fermeture) :
## une démo qu'on ne peut pas garder n'était pas un outil.
## ⚠ PAS UN VERROU : le `.glb` lié qu'elle écrit à côté d'un projet porte les tuiles du témoin (sans la règle ni le
## manifeste qu'attendent les greffons). Le rempart reste le contrat, comme pour le chiffrement (charte §0).

## Les demandes de fichier (`editor._demander`) que la démo refuse : les sorties.
const REFUSEES := ["exporter", "tileset", "monde", "patron"]
const MESSAGE := ("[color=#f2ca79][b]Free demo[/b][/color] — everything works and your projects are saved, but "
	+ "exporting (the witness for Blender, the tile set and the world for Godot, Unity and Unreal, the UV layout) is "
	+ "in the full version. Your demo projects open in the full version as they are.")


static func refuse(action: String) -> bool:
	return action in REFUSEES
