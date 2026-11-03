extends Node
## « ABOUT », LES DONS ET LES MISES À JOUR — ce que l'utilisateur voit du logiciel libre (Jordan, 3 novembre 2026 :
## « MarchingBlocks devient OpenSource et réclame des dons »). Sobre, en anglais. Remplace la vente (le contrat à
## accepter, la clé, les éditions site / Steam / itch / démo : tout cela est retiré, l'historique git le garde).
## Les règles vivent ailleurs, une fois : `dons.gd`, `mises_a_jour.gd` (et le dépôt), `avis_tiers.gd`, `LICENSE`.
##
## Au lancement (`au_lancement`), dans l'exe livré seulement : la vérification des mises à jour, sans attendre. Rien
## à accepter, rien à activer : la GPL n'est pas un contrat à signer pour se servir du logiciel.

const MisesAJour := preload("res://app/mises_a_jour.gd")
const Avis := preload("res://app/avis_tiers.gd")
const Dons := preload("res://app/dons.gd")

## LA LICENCE, telle que livrée (le `LICENSE` du dépôt, GPL-3.0, embarqué par les préréglages d'export).
const LICENCE := "res://LICENSE"

signal mise_a_jour(version: String, lien: String)

var dialogue_about: AcceptDialog
var dialogue_texte: AcceptDialog
var _verif: Node


## L'exe livré (pas l'éditeur Godot ni une suite) vérifie ses mises à jour.
func au_lancement() -> void:
	if OS.has_feature("template"):
		_verifier_les_mises_a_jour()


static func texte_de_la_licence() -> String:
	return FileAccess.get_file_as_string(LICENCE)


# ── LES MISES À JOUR ───────────────────────────────────────────────────────────────────────────────────

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
	var titre := _mot("MarchingBlocks v%s" % ProjectSettings.get_setting("application/config/version", ""))
	titre.add_theme_font_size_override("font_size", 16)
	col.add_child(titre)
	col.add_child(_mot("Sculpt one block. Paint a world.\n© 2026 SpannerGames. Free and open-source software under the "
		+ "GNU General Public License v3.0. The MarchingBlocks name and logo are trademarks of SpannerGames."))
	var source := LinkButton.new()
	source.text = "Source code on GitHub"
	source.uri = MisesAJour.DEPOT
	col.add_child(source)
	col.add_child(HSeparator.new())
	col.add_child(_mot(Dons.APPEL))
	col.add_child(liens_de_dons())
	var rangee := HBoxContainer.new()
	var licence := Button.new()
	licence.text = "License (GPL-3.0)"
	licence.pressed.connect(func() -> void: montrer_un_texte("License", texte_de_la_licence()))
	rangee.add_child(licence)
	var avis := Button.new()
	avis.text = "Third-party notices"
	avis.pressed.connect(func() -> void: montrer_un_texte("Third-party notices", Avis.texte()))
	rangee.add_child(avis)
	col.add_child(rangee)


## Un bouton par plateforme de dons (`dons.gd`), qui ouvre sa page dans le navigateur.
static func liens_de_dons() -> HBoxContainer:
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 12)
	for p in Dons.PLATEFORMES:
		var lien := LinkButton.new()
		lien.text = "Donate on %s" % p["nom"]
		lien.uri = p["url"]
		rangee.add_child(lien)
	return rangee


func montrer_un_texte(titre: String, texte: String) -> void:
	if dialogue_texte == null:
		dialogue_texte = _dialogue(titre, "Close")
		_colonne(dialogue_texte).add_child(_texte_long(""))
	# Depuis « About » (exclusive), le texte s'ouvre comme SA fille : deux exclusives sœurs, Godot refuse la seconde
	# (« the parent window already has another exclusive child », vu par `test_a_propos` le 3 novembre 2026).
	var parent: Node = dialogue_about if dialogue_about != null and dialogue_about.visible else self
	if dialogue_texte.get_parent() != parent:
		dialogue_texte.reparent(parent, false)
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
