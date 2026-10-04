extends GLTFDocumentExtension
## LES PNG DÉJÀ ENCODÉS, GARDÉS D'UNE ÉCRITURE À L'AUTRE (4 octobre 2026).
##
## ⚠ MESURÉ (l'exemple, avec fenêtre, RTX 2060) : écrire le `.glb` lié du témoin (`TemoinLie.vers_glb`, à chaque passage
## dans World après une retouche) coûtait ~3,3 s, dont ~3,2 s dans `GLTFDocument.write_to_filesystem` — l'encodage PNG
## des textures (albedo, normale, ORM, en 1k et 2k). Une retouche de GÉOMÉTRIE ne change aucune image : on les
## réencodait toutes, à l'identique.
##
## Ce format (`FORMAT`) fait exactement ce que fait le PNG de Godot — `Image.save_png_to_buffer`, « image/png », la
## texture qui cite son image — mais retient les octets encodés sous l'empreinte des PIXELS de l'image (MD5 des données,
## taille, format, mipmaps). Une image inchangée rend les MÊMES octets sans être réencodée : le fichier écrit est le même,
## octet pour octet (gardé par `test_temoin_lie`).
## ⚠ PAS UNE EMPREINTE PAR OBJET : `GLTFDocument` relit chaque texture (`get_image`, une copie neuve à chaque écriture).
## ⚠ EN MÉMOIRE ET SUR LE DISQUE (`DOSSIER`, le cache de l'appli, à côté des lots tranchés) : sans le disque, la
## première écriture d'une session encodait encore tout (~2,9 s). Le disque est borné (`OCTETS_MAXI_DISQUE`), les plus
## anciens partent d'abord ; une entrée illisible ou vide est réencodée.
## ⚠ Enregistrée le temps d'UNE écriture (`brancher` … `debrancher`), jamais à demeure : une extension globale se
## mêlerait de tout import et de tout export de l'appli.

const FORMAT := "MB_PNG"
const DOSSIER := "user://cache/png"
## En mémoire : au-delà, on oublie les octets qui ne servaient pas à l'écriture courante.
const OCTETS_MAXI := 256 * 1024 * 1024
const OCTETS_MAXI_DISQUE := 512 * 1024 * 1024

## {empreinte: PackedByteArray}, d'une écriture à l'autre.
static var _gardes := {}
## Combien d'images encodées / reprises (de la mémoire ou du disque) lors de la dernière écriture.
static var encodees := 0
static var reprises := 0
## Le dossier du cache sur disque ; "" : pas de disque (les tests qui veulent éprouver la mémoire seule).
static var dossier := DOSSIER
## Faux : l'écriture de Godot telle quelle (`brancher` rend null). Pour que les tests aient leur référence.
static var actif := true
var _vues := {}


## Branche le format sur `document`. ⚠ AVANT `append_from_scene` : c'est là que `GLTFDocument` choisit l'extension qui
## sauvera les images (branché après, « Unknown image format » et un `.glb` sans images — vu le 4 octobre 2026).
## Toujours suivi de `debrancher`, quoi qu'il arrive.
static func brancher(document: GLTFDocument) -> GLTFDocumentExtension:
	if not actif:
		return null
	var ext = load("res://addons/marchingblocks_core/png_en_memoire.gd").new()
	encodees = 0
	reprises = 0
	document.image_format = FORMAT
	GLTFDocument.register_gltf_document_extension(ext)
	return ext


## Retire l'extension ; garde en mémoire les images de cette écriture, les autres tant que le tout reste sous
## `OCTETS_MAXI` ; sur le disque, les plus anciennes partent au-delà de `OCTETS_MAXI_DISQUE`.
static func debrancher(ext: GLTFDocumentExtension) -> void:
	if ext == null:
		return
	GLTFDocument.unregister_gltf_document_extension(ext)
	var vues: Dictionary = ext.get("_vues")
	var total := 0
	for k in vues:
		total += (_gardes[k] as PackedByteArray).size()
	for k in _gardes.keys():
		if vues.has(k):
			continue
		total += (_gardes[k] as PackedByteArray).size()
		if total > OCTETS_MAXI:
			_gardes.erase(k)
	if dossier == "" or not DirAccess.dir_exists_absolute(dossier):
		return
	var fichiers: Array = []
	var sur_disque := 0
	for nom in DirAccess.get_files_at(dossier):
		var chemin := dossier.path_join(nom)
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f == null:
			continue
		var taille := f.get_length()
		f.close()
		sur_disque += taille
		fichiers.append([FileAccess.get_modified_time(chemin), chemin, taille, vues.has(nom.get_basename())])
	if sur_disque <= OCTETS_MAXI_DISQUE:
		return
	fichiers.sort_custom(func(a, b): return a[0] < b[0])
	for e in fichiers:
		if sur_disque <= OCTETS_MAXI_DISQUE:
			break
		if e[3]:
			continue
		DirAccess.remove_absolute(e[1])
		sur_disque -= int(e[2])


static func oublier() -> void:
	_gardes.clear()


func _get_saveable_image_formats() -> PackedStringArray:
	return PackedStringArray([FORMAT])


func _serialize_image_to_bytes(_state: GLTFState, image: Image, image_dict: Dictionary, _image_format: String,
		_lossy_quality: float) -> PackedByteArray:
	image_dict["mimeType"] = "image/png"
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(image.get_data())
	var s := image.get_size()
	# Un nom de fichier : l'empreinte des pixels, puis format, mipmaps, taille.
	var cle := "%s_%d_%d_%dx%d" % [h.finish().hex_encode(), image.get_format(), int(image.has_mipmaps()), s.x, s.y]
	_vues[cle] = true
	if _gardes.has(cle):
		reprises += 1
		return _gardes[cle]
	var chemin := "" if dossier == "" else dossier.path_join(cle + ".png")
	if chemin != "" and FileAccess.file_exists(chemin):
		var lus := FileAccess.get_file_as_bytes(chemin)
		if not lus.is_empty():
			reprises += 1
			_gardes[cle] = lus
			return lus
	encodees += 1
	var octets := image.save_png_to_buffer()
	_gardes[cle] = octets
	if chemin != "" and not octets.is_empty():
		DirAccess.make_dir_recursive_absolute(dossier)
		# Écrit à côté puis remplacé : une écriture coupée ne laisse jamais un PNG tronqué sous une bonne empreinte.
		var f := FileAccess.open(chemin + ".part", FileAccess.WRITE)
		if f != null:
			f.store_buffer(octets)
			f.close()
			DirAccess.rename_absolute(chemin + ".part", chemin)
	return octets


## Ce que le PNG de Godot écrit pour la texture : elle cite son image.
func _serialize_texture_json(_state: GLTFState, texture_json: Dictionary, gltf_texture: GLTFTexture,
		_image_format: String) -> Error:
	texture_json["source"] = gltf_texture.src_image
	return OK
