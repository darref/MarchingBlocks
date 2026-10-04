extends GLTFDocumentExtension
## LES IMAGES DÉJÀ DÉCODÉES, GARDÉES D'UNE RELECTURE À L'AUTRE (4 octobre 2026, la nuit).
##
## ⚠ MESURÉ (l'exemple, headless) : relire le `.glb` lié d'une couche (`BlocsMaitres.tuiles_liees`, chaque fois que le
## monde suit son témoin — un passage dans World après une retouche) coûtait ~360 ms dans `append_from_file`, presque tout
## à DÉCODER ses PNG (albedo, normale, ORM, en 1k et 2k). Une retouche de géométrie n'en change aucun : on les redécodait
## à l'identique. Repris : ~53 ms.
##
## Le pendant de `png_en_memoire.gd` à la lecture : une image PNG (« image/png », ou sans type et à la signature PNG) est
## décodée par `Image.load_png_from_buffer` — ce que fait Godot —, gardée sous l'empreinte de ses OCTETS (MD5, puis les
## octets comparés : jamais une image pour une autre), et rendue en COPIE (`copy_from` : le document peut la retoucher).
## Tout autre format est laissé à Godot (l'image reste vide). En mémoire seulement, bornée (`OCTETS_MAXI`) : au-delà, on
## oublie ce que la relecture courante n'a pas lu.
## ⚠ Branchée le temps d'UNE relecture (`brancher` … `debrancher`), jamais à demeure, comme `png_en_memoire.gd`.

const OCTETS_MAXI := 512 * 1024 * 1024

## {MD5 des octets: [octets (PackedByteArray), Image décodée]}.
static var _gardees := {}
## Combien d'images décodées / reprises lors de la dernière relecture.
static var decodees := 0
static var reprises := 0
## Faux : la lecture de Godot telle quelle (`brancher` rend null). Pour que les tests aient leur référence.
static var actif := true
var _vues := {}


static func brancher() -> GLTFDocumentExtension:
	if not actif:
		return null
	var ext = load("res://addons/marchingblocks_core/images_relues.gd").new()
	decodees = 0
	reprises = 0
	GLTFDocument.register_gltf_document_extension(ext)
	return ext


## Retire l'extension ; garde les images de cette relecture, les autres tant que le tout reste sous `OCTETS_MAXI`.
static func debrancher(ext: GLTFDocumentExtension) -> void:
	if ext == null:
		return
	GLTFDocument.unregister_gltf_document_extension(ext)
	var vues: Dictionary = ext.get("_vues")
	var total := 0
	for k in vues:
		total += (_gardees[k][1] as Image).get_data_size()
	for k in _gardees.keys():
		if vues.has(k):
			continue
		total += (_gardees[k][1] as Image).get_data_size()
		if total > OCTETS_MAXI:
			_gardees.erase(k)


static func oublier() -> void:
	_gardees.clear()


func _parse_image_data(_state: GLTFState, image_data: PackedByteArray, mime_type: String, ret_image: Image) -> Error:
	var png := mime_type == "image/png" or (mime_type == "" and image_data.size() > 8
		and image_data.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
	if not png:
		return OK   # l'image reste vide : Godot la lit lui-même
	var h := HashingContext.new()
	h.start(HashingContext.HASH_MD5)
	h.update(image_data)
	var cle := h.finish().hex_encode()
	var garde: Variant = _gardees.get(cle, null)
	if garde != null and garde[0] == image_data:
		_vues[cle] = true
		reprises += 1
		ret_image.copy_from(garde[1])
		return OK
	var image := Image.new()
	if image.load_png_from_buffer(image_data) != OK:
		return OK   # illisible : Godot essaie à son tour, et le dit
	decodees += 1
	_vues[cle] = true
	_gardees[cle] = [image_data, image]
	ret_image.copy_from(image)
	return OK
