extends Node
## CE QUE L'ACHETEUR VOIT DE LA VENTE — le contrat à accepter, la clé à coller (site), « About » (la licence en
## vigueur, le contrat, les avis des licences tierces), et le mot discret d'une mise à jour (site). Sobre, en anglais.
## Les règles vivent ailleurs, une fois : `edition.gd`, `licence.gd`, `contrat.gd`, `mises_a_jour.gd`, `avis_tiers.gd`.
##
## Au lancement (`au_lancement`, attendu par l'écran AVANT d'ouvrir un projet), dans l'exe livré seulement :
##   1. le CONTRAT, s'il n'a pas été accepté dans sa version — « I accept » ou « Quit » ;
##   2. (site) la CLÉ, s'il n'y en a pas de bonne — « Activate » ou « Quit » ;
##   3. (site) la vérification des mises à jour, sans attendre.
## Rend faux si l'utilisateur a choisi de quitter.

const Edition := preload("res://app/edition.gd")
const Licence := preload("res://app/licence.gd")
const Contrat := preload("res://app/contrat.gd")
const MisesAJour := preload("res://app/mises_a_jour.gd")
const Avis := preload("res://app/avis_tiers.gd")

## ⚠ À REMPLIR AVEC LE DOMAINE (comme `MisesAJour.URL`) : la page d'achat et de la démo. Tant qu'elle porte
## « A-REMPLIR », le lien n'est pas montré.
const URL_SITE := "https://A-REMPLIR.example/marchingblocks"

signal fini(continuer: bool)
signal mise_a_jour(version: String, lien: String)

var dialogue_contrat: AcceptDialog
var dialogue_cle: AcceptDialog
var dialogue_about: AcceptDialog
var dialogue_texte: AcceptDialog
var saisie_cle: TextEdit
var erreur_cle: Label
var _verif: Node
var _annuler_cle: Button
## La licence en vigueur (site) : ce que `Licence.lire` a rendu.
var licence: Dictionary = {}
## La clé publique qui vérifie (les suites en donnent une jetable : elles n'ont pas la clé privée de SpannerGames).
var cle_publique := Licence.CLE_PUBLIQUE


func au_lancement() -> bool:
	if not Edition.livree():
		return true
	if not Contrat.accepte():
		_montrer_le_contrat()
		if not await fini:
			return false
	if Edition.nom() == Edition.SITE:
		licence = Licence.en_vigueur(Licence.REGLAGES, cle_publique)
		if not licence.get("ok", false):
			_montrer_la_cle(false)
			if not await fini:
				return false
		_verifier_les_mises_a_jour()
	return true


# ── LE CONTRAT ─────────────────────────────────────────────────────────────────────────────────────────

func _montrer_le_contrat() -> void:
	dialogue_contrat = _dialogue("MarchingBlocks — License agreement", "I accept")
	dialogue_contrat.add_cancel_button("Quit")
	var col := _colonne(dialogue_contrat)
	col.add_child(_mot("Please read the license agreement. Using MarchingBlocks means accepting it.\n"
		+ "The French version prevails; the English translation follows it. It is also in LICENSE.txt, next to the app."))
	col.add_child(_texte_long(Contrat.texte()))
	dialogue_contrat.confirmed.connect(accepter_le_contrat)
	dialogue_contrat.canceled.connect(func() -> void:
		dialogue_contrat.hide()
		fini.emit(false))
	dialogue_contrat.popup_centered(Vector2i(820, 620))


func accepter_le_contrat() -> void:
	Contrat.accepter()
	dialogue_contrat.hide()
	fini.emit(true)


# ── LA CLÉ (site) ──────────────────────────────────────────────────────────────────────────────────────

## `changer` : depuis About (« Quit » devient « Cancel », et l'ancienne clé reste si l'on renonce).
func _montrer_la_cle(changer: bool) -> void:
	if dialogue_cle == null:
		dialogue_cle = _dialogue("Activate MarchingBlocks", "Activate")
		dialogue_cle.dialog_hide_on_ok = false
		_annuler_cle = dialogue_cle.add_cancel_button("Quit")
		var col := _colonne(dialogue_cle)
		col.add_child(_mot("Paste the license key from your purchase e-mail.\n"
			+ "It works offline, on every computer you use yourself."))
		saisie_cle = TextEdit.new()
		saisie_cle.custom_minimum_size = Vector2(560, 90)
		saisie_cle.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		saisie_cle.placeholder_text = "MBK1.…"
		col.add_child(saisie_cle)
		erreur_cle = _mot("")
		erreur_cle.add_theme_color_override("font_color", Color("#e0603c"))
		col.add_child(erreur_cle)
		if MisesAJour.url_remplie(URL_SITE):
			var lien := LinkButton.new()
			lien.text = "No key yet? Buy MarchingBlocks, or try the free demo"
			lien.uri = URL_SITE
			col.add_child(lien)
		dialogue_cle.confirmed.connect(activer)
		dialogue_cle.canceled.connect(func() -> void:
			dialogue_cle.hide()
			# Depuis About (« Cancel ») : l'ancienne clé reste, rien ne s'arrête.
			if not dialogue_cle.get_meta("changer", false):
				fini.emit(false))
	_annuler_cle.text = "Cancel" if changer else "Quit"
	dialogue_cle.set_meta("changer", changer)
	saisie_cle.text = ""
	erreur_cle.text = ""
	dialogue_cle.popup_centered()
	saisie_cle.grab_focus.call_deferred()   # on colle tout de suite (Ctrl+V), sans viser le champ


## « Activate » : la clé collée, lue ; bonne, elle est retenue et le dialogue se ferme.
func activer() -> void:
	var r := Licence.lire(saisie_cle.text, cle_publique)
	if not r["ok"]:
		erreur_cle.text = str(r["raison"])
		return
	Licence.enregistrer(saisie_cle.text)
	licence = r
	dialogue_cle.hide()
	if dialogue_about != null and dialogue_about.visible:
		_remplir_about()
	fini.emit(true)


# ── LES MISES À JOUR (site) ────────────────────────────────────────────────────────────────────────────

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
	col.add_child(_mot("Sculpt one block. Paint a world.\n© 2026 SpannerGames. All rights reserved."))
	match Edition.nom():
		Edition.SITE:
			if licence.get("ok", false):
				col.add_child(_mot("Licensed to %s%s" % [licence["nom"],
					(" (%s)" % licence["email"]) if str(licence["email"]) != "" else ""]))
			var changer := Button.new()
			changer.text = "Enter another license key"
			changer.pressed.connect(_montrer_la_cle.bind(true))
			col.add_child(changer)
		Edition.STEAM:
			col.add_child(_mot("Licensed through your Steam account."))
		Edition.ITCH:
			col.add_child(_mot("Bought on itch.io — a DRM-free copy. New versions come through your itch.io library."))
		Edition.DEMO:
			col.add_child(_mot("Free demo — everything works and saves; exporting is in the full version."))
	var rangee := HBoxContainer.new()
	var contrat := Button.new()
	contrat.text = "License agreement"
	contrat.pressed.connect(func() -> void: montrer_un_texte("License agreement", Contrat.texte()))
	rangee.add_child(contrat)
	var avis := Button.new()
	avis.text = "Third-party notices"
	avis.pressed.connect(func() -> void: montrer_un_texte("Third-party notices", Avis.texte()))
	rangee.add_child(avis)
	col.add_child(rangee)


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
