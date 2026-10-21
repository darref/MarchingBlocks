extends "res://app/preshapes/forme.gd"
## LE PHARE : une tour ronde qui s'effile, des bandes de couleur, une galerie en surplomb, la lanterne et son toit.


func _init() -> void:
	id = "phare"
	nom = "Lighthouse"
	famille = "antique"
	aide = "A tapering round tower, painted bands, an overhanging gallery, the lantern room and its cap."


func facteurs() -> Array:
	return [
		f("hauteur", "Height", 6, 64, 24, "The tower, up to the gallery."),
		f("rayon", "Radius", 1, 8, 3, "At the foot."),
		f("effile", "Taper", 0.0, 0.8, 0.3, "How much thinner it gets at the top.", 0.01),
		f("bandes", "Bands", 0, 8, 4, "Painted bands (Roofs layer) along the tower; 0: plain."),
		coche("galerie", "Gallery", true, "A ring walkway around the top."),
		f("lanterne", "Lantern", 0, 6, 3, "The lantern room above the gallery."),
		f("socle", "Base", 0, 8, 2, "A wider base building at the foot."),
	]


func packs() -> Array:
	return [
		["Striped lighthouse", {"bandes": 5}],
		["Stone tower light", {"bandes": 0, "rayon": 4, "effile": 0.15, "hauteur": 18}],
		["Pharos", {"hauteur": 44, "rayon": 6, "effile": 0.45, "socle": 5, "bandes": 0}],
	]


func construire(v: Dictionary, b: Bati, _rng: RandomNumberGenerator) -> void:
	var H := int(v["hauteur"])
	var r0: float = v["rayon"]
	var S := int(v["socle"])
	if S > 0:
		b.boite(Vector3i(-int(r0) - 3, 0, -int(r0) - 3), Vector3i(int(r0) + 3, S - 1, int(r0) + 3), "pierre")
	var nb := int(v["bandes"])
	var hb := maxi(1, H / maxi(1, nb * 2))
	var r_haut := r0
	for y in H:
		var r: float = maxf(0.6, r0 * (1.0 - v["effile"] * float(y) / H))
		r_haut = r
		var role := "toit" if nb > 0 and (y / hb) % 2 == 1 else "pierre"
		b.cylindre(0, 0, r, y, y, role)
	var yg := H
	if v["galerie"]:
		b.cylindre(0, 0, r_haut + 1.5, yg, yg, "pierre")
		b.cylindre(0, 0, r_haut + 1.5, yg + 1, yg + 1, "pierre", r_haut + 0.6)
	var lt := int(v["lanterne"])
	if lt > 0:
		var rl := maxf(0.6, r_haut - 0.5)
		b.cylindre(0, 0, rl, yg + 1, yg + lt, "pierre", rl - 1.0)
		b.cylindre(0, 0, rl + 0.5, yg + lt + 1, yg + lt + 1, "toit")
		b.case(0, yg + lt + 2, 0, "toit")
