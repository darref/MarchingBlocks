extends RefCounted
## L'ÉDITION DE L'EXE — « release » ou « dev ». MarchingBlocks est OPEN SOURCE (MIT, Jordan, 3 novembre 2026) : une
## seule édition livrée, sans clé, sans démo, sans contrat à accepter (charte §0, « open source »).
##   • "release" — un exe exporté (`OS.has_feature("template")`) : il s'inscrit dans Windows, vérifie les mises à jour ;
##   • "dev"     — l'éditeur Godot et les suites : rien de tout cela.

const RELEASE := "release"
const DEV := "dev"

## Pour les suites : une édition imposée ("" : celle de l'exe).
static var forcee := ""


static func nom() -> String:
	if forcee != "":
		return forcee
	return d_apres(OS.has_feature)


## La règle, pure : `a_la_balise` dit si une balise est présente (`OS.has_feature` dans l'appli).
static func d_apres(a_la_balise: Callable) -> String:
	return RELEASE if a_la_balise.call("template") else DEV


## L'exe est-il livré (pas l'éditeur ni une suite) ? Les associations de fichiers, les mises à jour…
static func livree() -> bool:
	return nom() != DEV


## Le nom affiché (About).
static func libelle() -> String:
	return "Release build" if livree() else "Development build"
