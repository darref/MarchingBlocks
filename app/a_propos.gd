extends Node
## « ABOUT » ET LES MISES À JOUR — MarchingBlocks est OPEN SOURCE (MIT, charte §0, « open source ») : pas de contrat à
## accepter, pas de clé. About dit la version, la licence, les avis des licences tierces, le dépôt GitHub et comment
## soutenir le projet (GitHub Sponsors, Buy Me a Coffee). Dans l'exe livré seulement, la dernière version publiée sur
## GitHub est vérifiée au lancement, sans attendre (`mises_a_jour.gd`). Sobre, en anglais.

const Edition := preload("res://app/edition.gd")
const MisesAJour := preload("res://app/mises_a_jour.gd")
const Avis := preload("res://app/avis_tiers.gd")

## La licence du projet (le fichier `LICENSE` à la racine du dépôt, embarqué par les préréglages d'export).
const LICENCE := "res://LICENSE"
const DEPOT := "https://github.com/darref/MarchingBlocks"
const SPONSORS := "https://github.com/sponsors/darref"
## ⚠ À COMPLÉTER : la page Buy Me a Coffee de Jordan. Tant qu'elle est vide, le lien n'est pas montré.
const CAFE := ""

signal mise_a_jour(version: String, lien: String)

var dialogue_about: AcceptDialog
var dialogue_texte: AcceptDialog
var _verif: Node


## Au lancement (appelé par l'écran AVANT d'ouvrir un projet) : la vérification des mises à jour, dans l'exe livré
## seulement, sans attendre. Rien n'arrête l'appli : ni contrat, ni clé.
func au_lancement() -> void:
	if Edition.livree():
		_verifier_les_mises_a_jour()


static func licence() -> String:
	return FileAccess.get_file_as_string(LICENCE)


func _verifier_les_mises_a_jour() -> void:
	_verif = MisesAJour.new()
	add_child(_verif)
	_verif.disponible.connect(func(v: String, l: String) -> void: mise_a_jour.emit(v, l))
	_verif.lancer(str(ProjectSettings.get_setting("application/config/version", "")))


# ── ABOUT ──────────────────────────────────────────────────────────────────────────────────────────────

func ouvrir_about() -> void:
	if dialogue_about == null:
		dialogue_about = _dialogue("About MarchingBlocks", "Close")
		_colonne(dialogue_about)
	_remplir_about()
	dialogue_about.popup_centered(Vector2i(520, 0))


func _remplir_about() -> void:
	var col: VBoxContainer = dialogue_about.get_meta("colonne")
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	var titre := _mot("MarchingBlocks v%s — %s" % [ProjectSettings.get_setting("application/config/version", ""),
		Edition.libelle()])
	titre.add_theme_font_size_override("font_size", 16)
	col.add_child(titre)
	col.add_child(_mot("Sculpt one block. Paint a world.\nFree and open source software, under the MIT license.\n"
		+ "© 2026 Jordan Ferrad (SpannerGames) and contributors."))
	for l in liens():
		var b := LinkButton.new()
		b.text = l[0]
		b.uri = l[1]
		col.add_child(b)
	var rangee := HBoxContainer.new()
	var lic := Button.new()
	lic.text = "License (MIT)"
	lic.pressed.connect(func() -> void: montrer_un_texte("License", licence()))
	rangee.add_child(lic)
	var avis := Button.new()
	avis.text = "Third-party notices"
	avis.pressed.connect(func() -> void: montrer_un_texte("Third-party notices", Avis.texte()))
	rangee.add_child(avis)
	col.add_child(rangee)


## Les liens d'About : [texte, adresse]. Une adresse vide (la page Buy Me a Coffee pas encore donnée) n'est pas montrée.
static func liens() -> Array:
	var l: Array = [["Source code, issues, releases (GitHub)", DEPOT], ["Support the project — GitHub Sponsors", SPONSORS]]
	if CAFE.begins_with("https://"):
		l.append(["Support the project — Buy Me a Coffee", CAFE])
	return l


func montrer_un_texte(titre: String, texte: String) -> void:
	if dialogue_texte == null:
		dialogue_texte = _dialogue(titre, "Close")
		_colonne(dialogue_texte).add_child(_texte_long(""))
	dialogue_texte.title = titre
	var col: VBoxContainer = dialogue_texte.get_meta("colonne")
	(col.get_child(0) as TextEdit).text = texte
	dialogue_texte.popup_centered(Vector2i(820, 620))


# ── LES BRIQUES ────────────────────────────────────────────────────────────────────────────────────────

func _dialogue(titre: String, ok: String) -> AcceptDialog:
	var d := AcceptDialog.new()
	d.title = titre
	d.ok_button_text = ok
	d.exclusive = true
	d.unresizable = false
	add_child(d)
	return d


func _colonne(d: AcceptDialog) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	d.add_child(col)
	d.set_meta("colonne", col)
	return col


func _mot(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	return l


func _texte_long(texte: String) -> TextEdit:
	var t := TextEdit.new()
	t.text = texte
	t.editable = false
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(780, 460)
	return t
