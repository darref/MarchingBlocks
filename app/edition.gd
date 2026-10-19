extends RefCounted
## L'ÉDITION DE L'EXE — SITE, STEAM ou DÉMO (charte §0, « la vente »). Une seule base de code, TROIS exports :
## chaque préréglage d'export (`export_presets.cfg`) pose sa balise (`custom_features`), que l'exe lit par
## `OS.has_feature`. Rien ne se décide sur la ligne de commande : une balise d'export est cuite dans le PCK chiffré.
##   • "site"  — vendu sur le site : la clé de licence est EXIGÉE (`licence.gd`), les mises à jour se vérifient ;
##   • "steam" — vendu sur Steam : sans clé (le compte Steam tient lieu de licence), Steam livre les mises à jour ;
##   • "itch"  — vendu sur itch.io (la 1.0.0, Jordan, 19 octobre 2026 : « exporte la 1.0.0 en mode release, que je vais
##               vendre depuis itch ») : sans clé, comme Steam — itch livre un fichier, pas nos clés nominatives, et ses
##               acheteurs attendent un logiciel sans DRM ; l'appli itch livre les mises à jour ;
##   • "demo"  — gratuite : tout le logiciel, enregistrement compris, sans exporter (`demo.gd`, 16 octobre 2026) ;
##   • "dev"   — l'éditeur Godot et les suites : rien de tout cela.
## ⚠ UN EXE EXPORTÉ SANS BALISE EST UN EXE DU SITE (clé exigée) : un préréglage oublié ou recopié ne doit JAMAIS
## livrer le logiciel complet sans clé.

const SITE := "site"
const STEAM := "steam"
const ITCH := "itch"
const DEMO := "demo"
const DEV := "dev"
## ⚠ L'ORDRE COMPTE si deux balises se trouvaient ensemble (un préréglage mal recopié) : la plus RESTREINTE gagne —
## la démo, puis le site (clé exigée), puis Steam, puis itch.
const BALISES := {"edition_demo": DEMO, "edition_site": SITE, "edition_steam": STEAM, "edition_itch": ITCH}

## Pour les suites : une édition imposée ("" : celle de l'exe).
static var forcee := ""


static func nom() -> String:
	if forcee != "":
		return forcee
	return d_apres(OS.has_feature)


## La règle, pure : `a_la_balise` dit si une balise est présente (`OS.has_feature` dans l'appli).
static func d_apres(a_la_balise: Callable) -> String:
	for balise in BALISES:
		if a_la_balise.call(balise):
			return BALISES[balise]
	return SITE if a_la_balise.call("template") else DEV


static func est_demo() -> bool:
	return nom() == DEMO


## L'exe est-il livré à un client (pas l'éditeur ni une suite) ? Le contrat à accepter, les associations…
static func livree() -> bool:
	return nom() != DEV


## Le nom affiché (About).
static func libelle() -> String:
	match nom():
		SITE:
			return "Full version"
		STEAM:
			return "Steam"
		ITCH:
			return "itch.io"
		DEMO:
			return "Free demo"
	return "Development build"
