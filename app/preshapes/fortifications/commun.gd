extends RefCounted
## CE QUE LES FORTIFICATIONS PARTAGENT : un mur droit avec son chemin de ronde et ses créneaux, une tour ronde ou
## carrée. Une règle, un endroit : le château, le bastion, la motte et le rempart les appellent.

const Bati := preload("res://app/preshapes/bati.gd")


## Un mur de `a` à `c` (en cases, au sol), `h` de haut, `ep` d'épaisseur ; des créneaux d'une case sur le bord
## extérieur (`creneaux`), un garde-corps intérieur si `ep` ≥ 3 (le chemin de ronde est entre les deux). `vus` évite de
## poser deux fois la même colonne.
static func mur(b: Bati, a: Vector2, c: Vector2, h: int, ep: int, creneaux: bool, role := "pierre",
		exterieur := Vector2.ZERO) -> void:
	var dir := (c - a)
	var L := dir.length()
	if L < 0.01:
		return
	dir /= L
	var nrm := dir.orthogonal()
	if exterieur != Vector2.ZERO and nrm.dot(exterieur) < 0.0:
		nrm = -nrm
	var pas := int(ceil(L * 2.0))
	var vus := {}
	for i in pas + 1:
		var p := a.lerp(c, float(i) / pas)
		for k in range(0, ep * 2):
			var off := k * 0.5 - (ep - 1) * 0.5
			var q := p + nrm * off
			var cle := Vector2i(roundi(q.x), roundi(q.y))
			if vus.has(cle):
				continue
			vus[cle] = true
			for y in h:
				b.case(cle.x, y, cle.y, role)
			# Le bord extérieur porte les créneaux (deux cases pleines, deux vides : une case sur deux ferait des contacts
			# par une arête le long d'un mur en biais), l'intérieur un garde-corps plein.
			if creneaux and off > (ep - 1) * 0.5 - 0.5:
				var s := roundi(float(i) / pas * L)
				if (s / 2) % 2 == 0:
					b.case(cle.x, h, cle.y, role)
			elif ep >= 3 and off < -(ep - 1) * 0.5 + 0.5:
				b.case(cle.x, h, cle.y, role)


## Une tour : ronde (`ronde`) ou carrée, de rayon `r`, `h` de haut, creuse si `paroi` > 0 (une salle au rez-de-chaussée
## et un toit plat), des créneaux, un toit conique (`cone`).
static func tour(b: Bati, cx: float, cz: float, r: float, h: int, ronde: bool, creneaux: bool, cone: bool,
		paroi := 0, role := "pierre") -> void:
	if ronde:
		b.cylindre(cx, cz, r, 0, h - 1, role)
	else:
		b.boite(Vector3i(roundi(cx - r), 0, roundi(cz - r)), Vector3i(roundi(cx + r), h - 1, roundi(cz + r)), role)
	if paroi > 0 and r - paroi >= 1.0:
		var ri := r - paroi
		if ronde:
			b.vider_cylindre(cx, cz, ri, 0, mini(h - 2, 3))
		else:
			b.vider_boite(Vector3i(roundi(cx - ri), 0, roundi(cz - ri)), Vector3i(roundi(cx + ri), mini(h - 2, 3), roundi(cz + ri)))
	if cone:
		var k := 0
		var rr := r + 0.5
		while rr > 0.3:
			if ronde:
				b.cylindre(cx, cz, rr, h + k, h + k, "toit")
			else:
				b.boite(Vector3i(roundi(cx - rr), h + k, roundi(cz - rr)), Vector3i(roundi(cx + rr), h + k, roundi(cz + rr)), "toit")
			rr -= 0.75
			k += 1
	elif creneaux:
		# Le pourtour monte d'une case par segments de deux cases (en damier, ils se toucheraient par une arête).
		for x in range(floori(cx - r) - 1, ceili(cx + r) + 2):
			for z in range(floori(cz - r) - 1, ceili(cz + r) + 2):
				var dedans: bool
				var bord: bool
				var segment: int
				if ronde:
					var d := Vector2(x - cx, z - cz).length()
					dedans = d <= r + 0.01
					bord = d > r - 1.0
					segment = floori((atan2(z - cz, x - cx) + PI) * maxf(r, 1.0) / 2.0)
				else:
					dedans = absf(x - cx) <= r + 0.01 and absf(z - cz) <= r + 0.01
					bord = absf(x - cx) > r - 1.0 or absf(z - cz) > r - 1.0
					segment = floori((x + z) / 2.0)
				if dedans and bord and posmod(segment, 2) == 0:
					b.case(x, h, z, role)
