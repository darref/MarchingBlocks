"""LA SIGNATURE SPANNERGAMES — la même, collée de la même façon sur le splash de chaque logiciel.

    python composer_splash.py FOND.png SORTIE.png [--logo spannergames_detoure.png]
                              [--nom "SpannerGames"] [--coin bas-droite]

Chaque logiciel a son FOND ; la signature, elle, ne varie pas : le logo détouré et le nom de la
compagnie, dans un coin, à une taille et une marge PROPORTIONNELLES à la hauteur de l'image — donc
identiques à l'œil sur un splash de 1080 comme de 2160. Un voile sombre, doux, s'étend sous la
signature : elle reste lisible quel que soit le fond.

⚠ CE FICHIER SE COPIE TEL QUEL D'UN PROJET À L'AUTRE, avec `spannergames_detoure.png`. Le modifier
dans un seul projet, c'est une signature qui diverge (une règle, un endroit).
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))

# Tout est en fraction de la HAUTEUR de l'image.
HAUTEUR_LOGO = 0.075
# ⚠ LA MARGE EST UNE ZONE DE SÛRETÉ, PAS UN GOÛT : le splash est étiré en « Cover » (il remplit la fenêtre
# en rognant ce qui dépasse), et une fenêtre maximisée est plus large que 16:9 — la barre des tâches lui
# prend de la hauteur. Mesuré sur ce PC : une fenêtre de 1920 de large n'y obtient que 1017 px de haut,
# soit ~32 px rognés en haut et en bas d'un splash 1920 × 1080. À 0,035 (38 px), la signature touchait
# le bord.
MARGE = 0.065
TAILLE_NOM = 0.030
ECART = 0.012          # entre le logo et le nom
VOILE = 0.55           # opacité maximale du voile sous la signature
COULEUR_NOM = (236, 226, 204)
POLICES = ["C:/Windows/Fonts/segoeuisl.ttf", "C:/Windows/Fonts/segoeui.ttf"]


def _police(taille):
    for chemin in POLICES:
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default(taille)


def composer(fond, logo, nom, coin="bas-droite"):
    img = fond.convert("RGBA")
    w, h = img.size
    marge = round(MARGE * h)
    hl = round(HAUTEUR_LOGO * h)
    logo = logo.convert("RGBA")
    logo = logo.resize((round(logo.width * hl / logo.height), hl), Image.LANCZOS)
    police = _police(round(TAILLE_NOM * h))
    boite = police.getbbox(nom)
    lt, ht = boite[2] - boite[0], boite[3] - boite[1]
    lg = logo.width + round(ECART * h) + lt

    droite = coin.endswith("droite")
    bas = coin.startswith("bas")
    x = w - marge - lg if droite else marge
    y = h - marge - hl if bas else marge

    # Le voile : une ellipse floue centrée sur la signature, jamais un cadre.
    voile = Image.new("L", (w, h), 0)
    cx, cy = x + lg / 2, y + hl / 2
    rx, ry = lg * 0.85, hl * 1.6
    ImageDraw.Draw(voile).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=round(255 * VOILE))
    voile = voile.filter(ImageFilter.GaussianBlur(hl * 0.9))
    noir = Image.new("RGBA", (w, h), (10, 6, 20, 255))
    noir.putalpha(voile)
    img = Image.alpha_composite(img, noir)

    img.alpha_composite(logo, (x, y))
    texte = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(texte)
    tx = x + logo.width + round(ECART * h) - boite[0]
    ty = round(y + (hl - ht) / 2) - boite[1]
    d.text((tx, ty), nom, font=police, fill=COULEUR_NOM + (255,))
    img = Image.alpha_composite(img, texte)
    return img.convert("RGB")


def main():
    a = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    a.add_argument("fond")
    a.add_argument("sortie")
    a.add_argument("--logo", default=os.path.join(ICI, "spannergames_detoure.png"))
    a.add_argument("--nom", default="SpannerGames")
    a.add_argument("--coin", default="bas-droite",
                   choices=["bas-droite", "bas-gauche", "haut-droite", "haut-gauche"])
    o = a.parse_args()
    composer(Image.open(o.fond), Image.open(o.logo), o.nom, o.coin).save(o.sortie)
    print("splash :", o.sortie)


if __name__ == "__main__":
    main()
