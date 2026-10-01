# LES ICÔNES DES FICHIERS DE MARCHINGBLOCKS — dessinées depuis l'emblème de l'appli (`icone.png`).
#
# Jordan (30 septembre 2026) : « donner une icône par défaut aux différents fichiers projet que le soft
# crée ». Quatre PNG de 256 px, que l'appli transforme en .ico quand elle s'inscrit dans Windows
# (`app/associations.gd`) :
#   fichier_projet.png   le projet (.mbproj)             — une feuille, l'emblème, une bande OLIVE ;
#   fichier_temoin.png   le témoin d'une couche (.mbtiles) — une feuille, l'emblème, une bande AMBRE ;
#   dossier_tuiles.png   un jeu de tuiles (.mbset/)      — un dossier, l'emblème, onglet AMBRE ;
#   dossier_monde.png    un monde peint (.mbworld/)      — un dossier, l'emblème, onglet OLIVE.
# ⚠ UNE SEULE SOURCE : l'emblème. Le retoucher, c'est relancer ce script — jamais retoucher les PNG à la main.
#
# LANCEMENT :  python MARQUE/generer_icones_fichiers.py
from PIL import Image, ImageDraw
import os

ICI = os.path.dirname(os.path.abspath(__file__))
T = 256
OLIVE = (180, 189, 133, 255)
AMBRE = (242, 202, 121, 255)
PAPIER = (238, 236, 228, 255)
PAPIER_OMBRE = (196, 192, 180, 255)
BORD = (60, 58, 52, 255)
DOSSIER = (70, 74, 84, 255)
DOSSIER_CLAIR = (96, 101, 114, 255)

embleme = Image.open(os.path.join(ICI, "icone.png")).convert("RGBA")


def coller_embleme(img, taille, centre):
    e = embleme.resize((taille, taille), Image.LANCZOS)
    img.alpha_composite(e, (centre[0] - taille // 2, centre[1] - taille // 2))


def feuille(bande):
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    g, h, dr, b, pli = 40, 12, 216, 244, 52
    corps = [(g, h), (dr - pli, h), (dr, h + pli), (dr, b), (g, b)]
    d.polygon(corps, fill=PAPIER, outline=BORD)
    d.line(corps + [corps[0]], fill=BORD, width=5)
    d.polygon([(dr - pli, h), (dr - pli, h + pli), (dr, h + pli)], fill=PAPIER_OMBRE, outline=BORD)
    d.line([(dr - pli, h), (dr - pli, h + pli), (dr, h + pli)], fill=BORD, width=5)
    d.rectangle([g + 3, b - 44, dr - 3, b - 3], fill=bande)
    coller_embleme(img, 150, ((g + dr) // 2, 112))
    return img


def dossier(onglet):
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([14, 40, 118, 80], radius=12, fill=onglet, outline=BORD, width=5)
    d.rounded_rectangle([14, 62, 242, 232], radius=16, fill=DOSSIER, outline=BORD, width=5)
    d.rounded_rectangle([24, 84, 232, 222], radius=12, fill=DOSSIER_CLAIR)
    coller_embleme(img, 132, (128, 152))
    return img


for nom, image in [("fichier_projet", feuille(OLIVE)), ("fichier_temoin", feuille(AMBRE)),
                   ("dossier_tuiles", dossier(AMBRE)), ("dossier_monde", dossier(OLIVE))]:
    chemin = os.path.join(ICI, nom + ".png")
    image.save(chemin)
    print(chemin)
